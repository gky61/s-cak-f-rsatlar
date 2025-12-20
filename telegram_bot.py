import os
import json
import re
import asyncio
import logging
from typing import List, Dict
from urllib.parse import urlparse
from datetime import datetime, timedelta

import aiohttp
from bs4 import BeautifulSoup
from telethon import TelegramClient, events
from curl_cffi import requests as curl_requests
import google.generativeai as genai
from dotenv import load_dotenv

# .env dosyasını yükle
load_dotenv()

# Logging yapılandırması
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s',
    handlers=[
        logging.FileHandler("logs/bot.log", encoding='utf-8'),
        logging.StreamHandler()
    ]
)
logger = logging.getLogger("TelegramDealBot")

# Firebase Admin başlat
db = None
try:
    import firebase_admin
    from firebase_admin import credentials, firestore
    import os as os_check
    service_account_path = 'serviceAccountKey.json'
    if os_check.path.exists(service_account_path):
        if not firebase_admin._apps:
            cred = credentials.Certificate(service_account_path)
            firebase_admin.initialize_app(cred)
        db = firestore.client()
        logger.info("✅ Firebase bağlantısı kuruldu")
    else:
        logger.error("❌ serviceAccountKey.json bulunamadı! Firebase kayıtları yapılamayacak!")
        logger.error("❌ Lütfen serviceAccountKey.json dosyasını bot klasörüne ekleyin!")
except Exception as e:
    logger.error(f"❌ Firebase başlatılamadı: {e}")
    db = None

# Gemini AI Yapılandırması
try:
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    # Model adlarını sırayla dene - önce en stabil olanı
    model_names = ['gemini-pro', 'gemini-1.5-flash', 'gemini-1.5-pro']
    model = None
    for model_name in model_names:
        try:
            model = genai.GenerativeModel(model_name)
            logger.info(f"✅ Gemini AI modeli yüklendi: {model_name}")
            break
        except Exception as e:
            logger.warning(f"⚠️ Model {model_name} yüklenemedi: {e}")
            continue
    if not model:
        raise Exception("Hiçbir Gemini modeli yüklenemedi!")
except Exception as e:
    logger.error(f"❌ Gemini AI başlatılamadı: {e}")
    model = None

class TelegramDealBot:
    def __init__(self):
        self.api_id = os.getenv("TELEGRAM_API_ID")
        self.api_hash = os.getenv("TELEGRAM_API_HASH")
        self.phone = os.getenv("TELEGRAM_PHONE")
        raw_channels = os.getenv("SOURCE_CHANNELS") or os.getenv("TELEGRAM_CHANNELS") or ""
        self.channels = [c.strip() for c in raw_channels.split(',') if c.strip()]
        self.client = TelegramClient('user_session', self.api_id, self.api_hash)
        self.last_message_time = {}  # Rate limiting için
        self.min_delay_seconds = 3  # Mesajlar arası minimum bekleme süresi (saniye) - Telegram yakalanmaması için artırıldı

    async def initialize(self):
        if not self.api_id or not self.api_hash or not self.phone:
            logger.error("❌ .env dosyasında eksik bilgiler var!")
            return False
        await self.client.start(phone=self.phone)
        me = await self.client.get_me()
        logger.info(f"✅ Kullanıcı olarak bağlandı! İsim: {me.first_name} | Telefon: {me.phone}")
        return True

    def _parse_price(self, price_str: str) -> float:
        if not price_str: return 0.0
        try:
            # Önce TL, ₺, lira gibi kelimeleri temizle
            price_str = price_str.split('TL')[0].split('₺')[0].split('lira')[0].strip()
            # Sadece sayı, nokta ve virgül bırak
            price_str = re.sub(r'[^\d,\.]', '', price_str)
            
            # Türk formatı: 1.234,56 veya 1234,56
            if ',' in price_str and '.' in price_str:
                if price_str.find('.') < price_str.find(','):
                    # 1.234,56 formatı - binlik ayırıcı nokta, ondalık virgül
                    price_str = price_str.replace('.', '').replace(',', '.')
                else:
                    # 1234,56.789 gibi garip format - virgülü kaldır
                    price_str = price_str.replace(',', '')
            elif ',' in price_str:
                # Virgül var, nokta yok
                parts = price_str.split(',')
                if len(parts[-1]) <= 2:
                    # Son kısım 2 haneden az - muhtemelen ondalık (1234,50)
                    price_str = price_str.replace(',', '.')
                else:
                    # Son kısım 3+ hane - muhtemelen binlik ayırıcı (1,234)
                    price_str = price_str.replace(',', '')
            return float(price_str)
        except:
            return 0.0
    
    def _extract_price_from_text(self, text: str) -> float:
        """Mesaj metninden fiyat çıkarmaya çalış"""
        if not text:
            return 0.0
        
        # Fiyat desenleri: "950 TL", "1.234,56 ₺", "2.500 lira", "₺950", "950,00 TL" vb.
        patterns = [
            r'(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)\s*(?:TL|₺|lira|fiyat|Fiyat)',
            r'(?:TL|₺|lira|fiyat|Fiyat):?\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)',
            r'₺\s*(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)',
            r'(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)\s*TL',
            r'(\d+(?:,\d{2})?)\s*(?:TL|₺)',
            r'fiyat[:\s]+(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)',
            r'(\d{1,3}(?:\.\d{3})*)\s*(?:TL|₺)',
            r'(\d+)\s*(?:TL|₺)',
        ]
        
        for pattern in patterns:
            matches = re.findall(pattern, text, re.IGNORECASE)
            if matches:
                price_str = matches[0]
                parsed = self._parse_price(price_str)
                if parsed > 0:
                    logger.info(f"💰 Regex ile fiyat bulundu: {price_str} -> {parsed} TL")
                    return parsed
        
        return 0.0
    
    def _extract_store_from_url(self, url: str) -> str:
        """Link'ten site/mağaza adını çıkar"""
        try:
            parsed = urlparse(url)
            domain = parsed.netloc.lower()
            
            # www. ve diğer prefix'leri kaldır
            domain = domain.replace('www.', '').replace('m.', '')
            
            # Türkçe e-ticaret siteleri mapping
            store_mapping = {
                'amazon.com.tr': 'Amazon',
                'amazon.tr': 'Amazon',
                'trendyol.com': 'Trendyol',
                'trendyol.com.tr': 'Trendyol',
                'hepsiburada.com': 'Hepsiburada',
                'n11.com': 'N11',
                'gittigidiyor.com': 'GittiGidiyor',
                'teknosa.com': 'Teknosa',
                'mediamarkt.com.tr': 'MediaMarkt',
                'vatanbilgisayar.com': 'Vatan Bilgisayar',
                'ciceksepeti.com': 'ÇiçekSepeti',
                'kitapyurdu.com': 'Kitap Yurdu',
                'd&r.com.tr': 'D&R',
                'migros.com.tr': 'Migros',
                'carrefoursa.com.tr': 'CarrefourSA',
            }
            
            # Mapping'de varsa döndür
            if domain in store_mapping:
                return store_mapping[domain]
            
            # Domain'in ilk kısmını al (örn: amazon.com.tr -> amazon)
            domain_parts = domain.split('.')
            if domain_parts:
                store_name = domain_parts[0].capitalize()
                return store_name
            
            return 'Bilinmeyen'
        except:
            return 'Bilinmeyen'

    async def fetch_link_data(self, url: str) -> Dict:
        try:
            response = curl_requests.get(url, impersonate="chrome110", timeout=30, allow_redirects=True)
            if response.status_code == 200:
                return {'html': response.text, 'final_url': response.url}
            return {}
        except Exception as e:
            logger.error(f"❌ Link hatası: {e}")
            return {}

    def extract_html_data(self, html: str, base_url: str) -> dict:
        data = {'price': 0.0, 'image': '', 'title': ''}
        if not html: 
            logger.warning("⚠️ HTML boş, veri çıkarılamıyor")
            return data
        try:
            soup = BeautifulSoup(html, 'html.parser')  # lxml yerine html.parser daha güvenilir
            from urllib.parse import urljoin
            
            def make_absolute_url(url):
                if not url or not url.strip():
                    return ''
                url = url.strip()
                if url.startswith('http://') or url.startswith('https://'):
                    return url
                if url.startswith('//'):
                    return 'https:' + url
                return urljoin(base_url, url)
            
            # 1. Görseli çek - Önce og:image (en yaygın)
            if not data['image']:
                img_tag = soup.find('meta', property='og:image')
                if img_tag:
                    img_url = img_tag.get('content', '').strip()
                    if img_url:
                        data['image'] = make_absolute_url(img_url)
                        logger.info(f"✅ Görsel bulundu (og:image): {data['image'][:80]}")
            
            # 2. Twitter image fallback
            if not data['image']:
                img_tag = soup.find('meta', attrs={'name': 'twitter:image'})
                if img_tag:
                    img_url = img_tag.get('content', '').strip()
                    if img_url:
                        data['image'] = make_absolute_url(img_url)
                        logger.info(f"✅ Görsel bulundu (twitter:image): {data['image'][:80]}")
            
            # 3. JSON-LD'den görsel çek
            if not data['image']:
                for script in soup.find_all('script', type='application/ld+json'):
                    try:
                        js = json.loads(script.string)
                        if isinstance(js, list) and js:
                            js = js[0]
                        if isinstance(js, dict):
                            img = js.get('image', '')
                            if img:
                                if isinstance(img, list) and img:
                                    img = img[0]
                                if isinstance(img, str) and img.strip():
                                    data['image'] = make_absolute_url(img.strip())
                                    logger.info(f"✅ Görsel bulundu (JSON-LD): {data['image'][:80]}")
                                    break
                    except:
                        continue
            
            # 4. İlk img tag'i (son çare)
            if not data['image']:
                img_tag = soup.find('img', src=True)
                if img_tag:
                    img_url = img_tag.get('src', '').strip() or img_tag.get('data-src', '').strip()
                    if img_url:
                        data['image'] = make_absolute_url(img_url)
                        logger.info(f"✅ Görsel bulundu (img tag): {data['image'][:80]}")
            
            # Başlık çek
            if not data['title']:
                title_tag = soup.find('meta', property='og:title')
                if title_tag:
                    data['title'] = title_tag.get('content', '').strip()
                if not data['title']:
                    title_tag = soup.find('title')
                    if title_tag:
                        data['title'] = title_tag.get_text().strip()
            
            # Fiyat çek - JSON-LD'den
            if not data['price']:
                for script in soup.find_all('script', type='application/ld+json'):
                    try:
                        js = json.loads(script.string)
                        if isinstance(js, list) and js:
                            js = js[0]
                        if isinstance(js, dict):
                            # Product tipini kontrol et
                            if js.get('@type') == 'Product' or 'Product' in str(js.get('@type', [])):
                                offers = js.get('offers', {})
                                if isinstance(offers, dict):
                                    price = offers.get('price') or offers.get('lowPrice') or offers.get('highPrice', 0)
                                    if price:
                                        parsed = self._parse_price(str(price))
                                        if parsed > 0:
                                            data['price'] = parsed
                                            logger.info(f"✅ Fiyat bulundu (JSON-LD Product): {data['price']} TL")
                                            break
                                elif isinstance(offers, list) and offers:
                                    price = offers[0].get('price', 0) if isinstance(offers[0], dict) else 0
                                    if price:
                                        parsed = self._parse_price(str(price))
                                        if parsed > 0:
                                            data['price'] = parsed
                                            logger.info(f"✅ Fiyat bulundu (JSON-LD Product list): {data['price']} TL")
                                            break
                            else:
                                # Genel offers kontrolü
                                offers = js.get('offers', {})
                                if isinstance(offers, dict):
                                    price = offers.get('price') or offers.get('lowPrice', 0)
                                    if price:
                                        parsed = self._parse_price(str(price))
                                        if parsed > 0:
                                            data['price'] = parsed
                                            logger.info(f"✅ Fiyat bulundu (JSON-LD): {data['price']} TL")
                                            break
                    except Exception as e:
                        logger.debug(f"JSON-LD price parse hatası: {e}")
                        continue
            
            # Fiyat bulunamadıysa log
            if not data['price']:
                logger.warning("⚠️ HTML'den fiyat bulunamadı, AI'den gelecek")
            if not data['image']:
                logger.warning("⚠️ Görsel bulunamadı")

        except Exception as e:
            logger.error(f"❌ HTML analiz hatası: {e}", exc_info=True)
        return data

    async def analyze_deal_with_ai(self, text: str, link: str = "", image_bytes: bytes = None, html_text: str = "") -> Dict:
        if not model: 
            logger.warning("⚠️ AI modeli yok, analiz yapılamıyor")
            return {}
        try:
            # Fiyat bulmak için tüm kaynakları kullan
            analysis_text = f"""Telegram Mesajı:
{text}

Link: {link}"""

            # Görsel varsa özel prompt, yoksa normal prompt
            if image_bytes:
                prompt = f"""Sen bir görsel okuma (OCR) uzmanısın. Görseldeki TÜM YAZILARI okumanda çok başarılısın.

GÖREV:
Aşağıdaki görseli DİKKATLE incele ve tüm yazıları oku. Özellikle FİYAT'a çok dikkat et!

GÖRSEL ANALİZİ - ADIM ADIM:
1. ÖNCE TÜM YAZILARI OKU: Görseldeki her yazıyı, her sayıyı oku. Büyük, küçük, renkli, siyah-beyaz fark etmez - HEPSİNİ OKU.

2. FİYAT BULMA (ÇOK ÖNEMLİ):
   - Görselde en BÜYÜK, EN BELİRGİN sayıları ara - bunlar genellikle fiyattır
   - "TL", "₺" sembolleri yanındaki sayıları oku
   - Türk formatında fiyatlar: "15.499 TL" veya "1.234,56 ₺" gibi
   - Örnekler:
     * "15.499 TL" -> price: 15499.0 (nokta binlik ayırıcıdır, virgül atılır)
     * "1.234,56 ₺" -> price: 1234.56 (nokta binlik, virgül ondalık)
     * "950 TL" -> price: 950.0
     * Görseldeki EN BÜYÜK sayı genellikle fiyattır - onu kullan!
   - Fiyatı MUTLAKA sayı olarak döndür (string değil!)

3. ÜRÜN ADI: Görseldeki ürün başlığını, marka ve model bilgisini oku (büyük yazılar genellikle başlıktır)

4. KATEGORİ BELİRLEME:
   - Görseldeki ürünü GÖR ve kategori seç
   - Monitör, TV, telefon, bilgisayar -> "elektronik"
   - Gaming monitör, oyuncu monitörü -> "elektronik"
   - Giyim, ayakkabı -> "moda"
   - Mobilya, ev eşyası -> "ev_yasam"
   - Gıda, market ürünü -> "supermarket"
   - vb.

5. MAĞAZA: Görseldeki mağaza logosu/yazısı varsa oku, yoksa mesajdan çıkar

MESAJ BİLGİLERİ:
{analysis_text}

KATEGORİ SEÇENEKLERİ (mutlaka bunlardan birini seç):
- elektronik: Telefon, bilgisayar, tablet, TV, hoparlör, kulaklık, elektronik cihazlar, teknoloji ürünleri
- moda: Giyim, ayakkabı, saat, çanta, cüzdan, takı, aksesuar, kıyafet
- ev_yasam: Mobilya, ev tekstili, yatak, yorgan, mutfak gereçleri, dekorasyon, zeytinyağı, gıda, ev eşyası
- anne_bebek: Bebek ürünleri, bebek bezi, bebek giysisi, oyuncak, mama, bebek arabası
- kozmetik: Parfüm, makyaj, ruj, fondöten, cilt bakımı, saç bakımı, temizlik ürünleri (kişisel bakım)
- spor_outdoor: Spor giyim, ayakkabı, fitness ekipmanı, kamp malzemeleri, bisiklet, spor aksesuar
- supermarket: Gıda, temizlik ürünleri, kağıt ürünleri, içecek, atıştırmalık, market ürünleri
- yapi_oto: Hırdavat, oto aksesuar, boya, bahçe malzemeleri, inşaat malzemeleri
- kitap_hobi: Kitap, dergi, müzik enstrümanı, oyun konsolu, oyun, hobi malzemeleri
- diğer: Yukarıdaki kategorilerden hiçbiri uymuyorsa

ÇIKTI FORMATI (MUTLAKA SADECE JSON, BAŞKA HİÇBİR ŞEY YAZMA):
{{
  "title": "ürün adı (görselden veya mesajdan)",
  "price": 1234.50,
  "category": "elektronik",
  "store": "mağaza adı (görselden, mesajdan veya link'ten)"
}}

ÖNEMLİ KURALLAR:
- FİYAT: Görselde fiyat varsa MUTLAKA görselden oku! En büyük, en belirgin sayıyı bul!
- Fiyat formatı: "15.499 TL" -> 15499.0 (nokta binlik ayırıcı, virgül atılır)
- Kategori: Görseldeki ürünü GÖR ve kategori seç (mutlaka yukarıdaki seçeneklerden birini kullan)
- Mağaza: Görseldeki logodan oku veya mesajdan çıkar
- MUTLAKA GEÇERLİ BİR JSON döndür, başka açıklama yazma!

ÖRNEK 1: Görselde "GIGABYTE M27UP Gaming Monitör - 15.499 TL" yazıyorsa:
{{"title": "GIGABYTE M27UP Gaming Monitör", "price": 15499.0, "category": "elektronik", "store": "Bilinmeyen"}}

ÖRNEK 2: Görselde "Komili Riviera Zeytinyağı 5 Lt - 950 TL" yazıyorsa:
{{"title": "Komili Riviera Zeytinyağı 5 Lt", "price": 950.0, "category": "supermarket", "store": "Amazon"}}"""
            else:
                prompt = f"""Sen bir Türk e-ticaret uzmanısın. Aşağıdaki Telegram mesajını DİKKATLE analiz et.

MESAJ:
{analysis_text}

GÖREV:
1. ÜRÜN ADI: Mesajdaki ürün başlığını, marka ve model bilgisini çıkar
2. FİYAT BULMA: Mesajda "950 TL", "1.234,56 ₺", "2.500 lira" gibi fiyat formatlarını ara
   - "950 TL" -> 950.0
   - "1.234,56 ₺" -> 1234.56
   - Sadece sayıyı döndür, TL/₺ sembollerini dahil etme
3. KATEGORİ: Ürün açıklamasına göre en uygun kategoriyi seç
4. MAĞAZA: Link'teki domain adından veya mesajdan mağaza adını çıkar

KATEGORİ SEÇENEKLERİ (mutlaka bunlardan birini seç):
- elektronik: Telefon, bilgisayar, tablet, TV, hoparlör, kulaklık, elektronik cihazlar
- moda: Giyim, ayakkabı, saat, çanta, takı, aksesuar, kıyafet
- ev_yasam: Mobilya, ev tekstili, mutfak gereçleri, dekorasyon, zeytinyağı, gıda, ev eşyası
- anne_bebek: Bebek ürünleri, bebek bezi, oyuncak, mama
- kozmetik: Parfüm, makyaj, cilt bakımı, saç bakımı
- spor_outdoor: Spor giyim, fitness, kamp malzemeleri
- supermarket: Gıda, temizlik ürünleri, kağıt ürünleri
- yapi_oto: Hırdavat, oto aksesuar, bahçe malzemeleri
- kitap_hobi: Kitap, müzik enstrümanı, oyun konsolu
- diğer: Yukarıdakilerden hiçbiri değilse

ÇIKTI FORMATI (MUTLAKA SADECE JSON, BAŞKA HİÇBİR ŞEY YAZMA):
{{
  "title": "ürün başlığı",
  "price": 1234.50,
  "category": "elektronik",
  "store": "mağaza adı"
}}

ÖNEMLİ KURALLAR:
- Fiyat mutlaka sayı olarak döndür (string değil, örn: 950.0)
- Kategori mutlaka yukarıdaki seçeneklerden birini kullan (elektronik, moda, ev_yasam, vb.)
- MUTLAKA GEÇERLİ BİR JSON döndür, başka açıklama, yorum veya markdown ekleme!
- JSON formatında hata olursa bot çalışmayacak, dikkatli ol!"""
            
            logger.info("🤖 AI analizi başlatılıyor (görsel ve metin analizi)...")
            
            # Eğer görsel varsa, görseli de gönder
            if image_bytes:
                try:
                    # Gemini API'ye görsel göndermek için PIL Image kullan
                    try:
                        from PIL import Image
                        import io
                        # Bytes'tan Image oluştur
                        image = Image.open(io.BytesIO(image_bytes))
                        logger.info("📸 Görsel AI'ye gönderiliyor (OCR ile fiyat okuma)...")
                        # Hem görsel hem metin gönder
                        response = await model.generate_content_async(
                            [image, prompt],
                            generation_config=genai.types.GenerationConfig(temperature=0.1)
                        )
                    except ImportError:
                        logger.warning("⚠️ PIL (Pillow) yüklü değil, görsel analizi yapılamıyor. 'pip install Pillow' çalıştırın.")
                        # Pillow yoksa sadece metin gönder
                        response = await model.generate_content_async(
                            prompt, 
                            generation_config=genai.types.GenerationConfig(temperature=0.1)
                        )
                except Exception as img_error:
                    logger.warning(f"⚠️ Görsel işleme hatası, sadece metin analizi yapılıyor: {img_error}")
                    # Görsel işlenemezse sadece metin gönder
                    response = await model.generate_content_async(
                        prompt, 
                        generation_config=genai.types.GenerationConfig(temperature=0.1)
                    )
            else:
                # Sadece metin gönder
                response = await model.generate_content_async(
                    prompt, 
                    generation_config=genai.types.GenerationConfig(temperature=0.1)
                )
            
            # Response'tan JSON çıkar
            response_text = response.text.strip()
            logger.info(f"📝 AI response (ilk 500 karakter): {response_text[:500]}")
            
            # Markdown code block'ları temizle
            if '```json' in response_text:
                response_text = response_text.split('```json')[1].split('```')[0].strip()
            elif '```' in response_text:
                response_text = response_text.split('```')[1].split('```')[0].strip()
            
            # JSON'u parse et
            try:
                ai_result = json.loads(response_text)
                logger.info(f"✅ AI analizi tamamlandı: {ai_result}")
                
                # Fiyat kontrolü - eğer string ise parse et
                if 'price' in ai_result:
                    if isinstance(ai_result['price'], str):
                        try:
                            ai_result['price'] = float(ai_result['price'].replace(',', '.').replace(' TL', '').replace('₺', '').strip())
                        except:
                            ai_result['price'] = 0.0
                    elif ai_result['price'] is None:
                        ai_result['price'] = 0.0
                
                # Kategori kontrolü - eğer yoksa veya geçersizse 'diğer' yap
                if 'category' not in ai_result or not ai_result['category']:
                    ai_result['category'] = 'diğer'
                    logger.warning("⚠️ AI kategori döndürmedi, 'diğer' kullanılıyor")
                
                return ai_result
            except json.JSONDecodeError as json_err:
                logger.error(f"❌ AI JSON parse hatası: {json_err}")
                logger.error(f"📝 Parse edilemeyen response: {response_text[:500]}")
                
                # JSON parse edilemezse, response'tan manuel olarak çıkarmaya çalış
                # Örneğin: "price": 950.0 gibi pattern'leri ara
                fallback_result = {}
                try:
                    price_match = re.search(r'"price"\s*:\s*(\d+(?:\.\d+)?)', response_text)
                    if price_match:
                        fallback_result['price'] = float(price_match.group(1))
                    
                    category_match = re.search(r'"category"\s*:\s*"([^"]+)"', response_text)
                    if category_match:
                        fallback_result['category'] = category_match.group(1)
                    else:
                        fallback_result['category'] = 'diğer'
                    
                    title_match = re.search(r'"title"\s*:\s*"([^"]+)"', response_text)
                    if title_match:
                        fallback_result['title'] = title_match.group(1)
                    
                    store_match = re.search(r'"store"\s*:\s*"([^"]+)"', response_text)
                    if store_match:
                        fallback_result['store'] = store_match.group(1)
                    
                    if fallback_result:
                        logger.warning(f"⚠️ JSON parse başarısız, fallback ile çıkarıldı: {fallback_result}")
                        return fallback_result
                except:
                    pass
                
                return {}
        except Exception as e:
            logger.error(f"❌ AI hatası: {e}", exc_info=True)
            return {}

    async def save_to_firestore(self, deal_data: dict):
        if not db:
            logger.error("❌ Firestore bağlantısı yok! Kayıt yapılamıyor!")
            return False
        try:
            deal_data['createdAt'] = datetime.now()
            # Admin onayı bekliyor - admin sayfasında görünecek
            deal_data['isApproved'] = False
            deal_data['isExpired'] = False  # Admin sayfasında görünmesi için gerekli
            deal_data['hotVotes'] = 0
            deal_data['coldVotes'] = 0
            deal_data['expiredVotes'] = 0
            deal_data['commentCount'] = 0
            deal_data['postedBy'] = 'telegram_bot'  # Bot tarafından gönderildi
            deal_data['views'] = 0
            deal_data['isEditorPick'] = False
            
            doc_ref = db.collection('deals').document()
            doc_ref.set(deal_data)
            logger.info(f"✅ Firestore'a kaydedildi: {deal_data.get('title')}")
            return True
        except Exception as e:
            logger.error(f"❌ Firestore kayıt hatası: {e}")
            return False

    async def process_message(self, text, chat_id, name, event=None):
        logger.info(f"📥 Mesaj İşleniyor... Kanal: {name}")
        # Telegram spam algılamasından kaçınmak için random delay (1-3 saniye arası)
        import random
        delay = random.uniform(1.0, 3.0)
        await asyncio.sleep(delay)
        urls = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)
        
        if not urls:
            return  # Link yoksa işleme (güvenlik kontrolü)
            
        link = urls[0]
        logger.info(f"🔗 Link: {link}")
        
        # Telegram'dan görsel varsa öncelik ver - direkt download_media kullan
        telegram_image_url = None
        telegram_image_bytes = None  # AI analizi için görsel bytes'ı sakla
        if event and event.message and hasattr(event.message, 'photo') and event.message.photo:
            try:
                logger.info("📸 Telegram mesajında fotoğraf bulundu, indiriliyor...")
                # Fotoğrafı bytes olarak indir
                photo_bytes = await event.client.download_media(event.message.photo, file=bytes)
                if photo_bytes:
                    logger.info(f"✅ Telegram fotoğrafı indirildi ({len(photo_bytes)} bytes)")
                    telegram_image_bytes = photo_bytes  # AI analizi için sakla
                    
                    # Fotoğrafı imgbb API'ye upload et (Firestore'a kaydetmek için)
                    imgbb_api_key = os.getenv("IMGBB_API_KEY", "")
                    if imgbb_api_key:
                        try:
                            import base64
                            photo_b64 = base64.b64encode(photo_bytes).decode('utf-8')
                            
                            async with aiohttp.ClientSession() as session:
                                data = aiohttp.FormData()
                                data.add_field('key', imgbb_api_key)
                                data.add_field('image', photo_b64)
                                
                                async with session.post('https://api.imgbb.com/1/upload', data=data) as resp:
                                    if resp.status == 200:
                                        result = await resp.json()
                                        if result.get('success'):
                                            telegram_image_url = result['data']['url']
                                            logger.info(f"✅ Telegram fotoğrafı imgbb'ye yüklendi: {telegram_image_url[:80]}")
                        except Exception as e2:
                            logger.warning(f"⚠️ imgbb upload hatası: {e2}")
                    else:
                        logger.info("ℹ️ IMGBB_API_KEY yok, Telegram fotoğrafı imgbb'ye yüklenemedi ama AI analizi için kullanılacak")
            except Exception as e:
                logger.error(f"❌ Telegram fotoğraf indirme hatası: {e}")
        
        # HTML scraping'i minimalize et - sadece görsel için (opsiyonel)
        # Görsel yoksa HTML scraping'i atla, AI'ya güven
        html_data = {}
        if not telegram_image_url:
            logger.info(f"🌐 Görsel yok, HTML scraping deneniyor (sadece görsel için): {link}")
            html_res = await self.fetch_link_data(link)
            if html_res:
                logger.info("✅ HTML içeriği alındı, sadece görsel çıkarılıyor...")
                html_data = self.extract_html_data(html_res['html'], html_res['final_url'])
                link = html_res['final_url']
                if html_data.get('image'):
                    logger.info(f"✅ HTML'den görsel bulundu: {html_data.get('image')[:80]}")
            else:
                logger.info("⚠️ HTML içeriği alınamadı, AI'ya güveniliyor")
        else:
            logger.info("✅ Telegram görseli mevcut, HTML scraping atlanıyor")
        
        # AI ile analiz et - görsel varsa görseli gönder, HTML gönderme
        ai_data = await self.analyze_deal_with_ai(text, link, telegram_image_bytes, "")
        if not ai_data:
            logger.warning("⚠️ AI analizi başarısız, temel veri kullanılıyor")
            ai_data = {
                'title': text[:100],
                'price': 0.0,
                'category': 'diğer',
                'store': 'Bilinmeyen'
            }
        
        # Verileri birleştir - AI odaklı yaklaşım
        # Görsel: Telegram fotoğrafı > HTML scraping > Boş
        # Başlık: AI > Mesaj (ilk 100 karakter)
        # Fiyat: Mesajdan direkt > AI > 0.0 (HTML'yi kaldırdık)
        # Kategori: AI (mutlaka olmalı)
        # Store: Link domain > AI > Bilinmeyen
        
        image_url = telegram_image_url or html_data.get('image', '') or ''
        title = ai_data.get('title') or text[:100]
        
        # Fiyat çıkarma önceliği: Mesajdan direkt (en güvenilir) > AI > 0.0
        price_from_text = self._extract_price_from_text(text)
        if price_from_text > 0:
            price = price_from_text
            logger.info(f"💰 Fiyat mesajdan (regex) çıkarıldı: {price} TL")
        elif ai_data.get('price', 0.0) > 0:
            price = ai_data.get('price', 0.0)
            logger.info(f"💰 Fiyat AI'dan çıkarıldı: {price} TL")
        else:
            price = 0.0
            logger.warning(f"⚠️ Fiyat bulunamadı!")
        
        # Kategori: Tamamen AI'ya güven
        category = ai_data.get('category', 'diğer')
        if not category or category.strip() == '':
            category = 'diğer'
            logger.warning("⚠️ AI kategori döndürmedi veya boş, 'diğer' kullanılıyor")
        else:
            category = category.strip().lower()
            if telegram_image_bytes:
                logger.info(f"📂 Kategori görselden (AI) çıkarıldı: {category}")
            else:
                logger.info(f"📂 Kategori mesajdan (AI) çıkarıldı: {category}")
        
        # Store: Link'ten domain çıkar > AI > Bilinmeyen
        store_from_link = self._extract_store_from_url(link)
        if store_from_link != 'Bilinmeyen':
            store = store_from_link
            logger.info(f"🏪 Mağaza link'ten çıkarıldı: {store}")
        elif ai_data.get('store') and ai_data.get('store') != 'Bilinmeyen':
            store = ai_data.get('store')
            logger.info(f"🏪 Mağaza AI'dan çıkarıldı: {store}")
        else:
            store = 'Bilinmeyen'
            logger.warning(f"⚠️ Mağaza bulunamadı!")
        
        # Kategori validasyonu - eğer AI yanlış kategori verirse 'diğer' kullan
        valid_categories = ['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 
                           'spor_outdoor', 'supermarket', 'yapi_oto', 'kitap_hobi', 'diğer']
        if category not in valid_categories:
            logger.warning(f"⚠️ Geçersiz kategori '{category}', 'diğer' kullanılıyor")
            category = 'diğer'
        
        final_data = {
            'title': title,
            'price': price,
            'imageUrl': image_url,
            'link': link,  # Deal modelinde 'link' field'i var
            'category': category,
            'store': store,
            'description': text[:500],
        }
        
        logger.info(f"💾 Kaydediliyor: {final_data['title']} | Fiyat: {final_data['price']} TL | Görsel: {'Var' if final_data['imageUrl'] else 'Yok'} | Kategori: {final_data['category']} | Mağaza: {final_data['store']}")
        
        # Firestore'a kaydet
        await self.save_to_firestore(final_data)

    async def run(self):
        if not await self.initialize(): return
        
        logger.info(f"📡 Dinlenen Kanallar: {self.channels}")

        @self.client.on(events.NewMessage())
        async def handler(event):
            try:
                chat = await event.get_chat()
                chat_id = chat.id
                text = event.message.message or ""
                
                # Debug: Her mesajı logla
                logger.info(f"📩 MESAJ ALINDI: [Kanal ID: {chat_id}] - {text[:100]}...")
                
                # Önce link kontrolü yap - link yoksa hiçbir şey yapma
                urls = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)
                if not urls:
                    logger.debug(f"🔗 Link yok, atlanıyor: [ID: {chat_id}]")
                    return  # Link yoksa işleme
                
                logger.info(f"🔗 Link bulundu: {urls[0]}")
                
                # Filtrele - hem pozitif hem negatif ID'leri kontrol et
                is_target = False
                chat_id_str = str(chat_id)
                chat_id_neg = f"-{chat_id_str}"
                
                logger.debug(f"🔍 Kanal kontrolü: {chat_id_str} / {chat_id_neg} | Hedef kanallar: {self.channels}")
                
                if (chat_id_str in self.channels or 
                    chat_id_neg in self.channels or 
                    (hasattr(chat, 'username') and f"@{chat.username}" in self.channels)):
                    is_target = True
                    logger.info(f"✅ Hedef kanal bulundu: {chat_id_str} / {chat_id_neg}")
                    logger.info(f"📩 MESAJ İŞLENİYOR (Link içeriyor): [ID: {chat_id}] - {text[:50]}...")
                else:
                    logger.debug(f"⏭️ Hedef kanal değil, atlanıyor: {chat_id_str}")
                
                if is_target:
                    # Rate limiting - aynı kanaldan çok hızlı mesaj gelirse bekle
                    now = datetime.now()
                    if chat_id_str in self.last_message_time:
                        time_diff = (now - self.last_message_time[chat_id_str]).total_seconds()
                        if time_diff < self.min_delay_seconds:
                            wait_time = self.min_delay_seconds - time_diff
                            logger.debug(f"⏳ Rate limiting: {wait_time:.1f} saniye bekleniyor...")
                            await asyncio.sleep(wait_time)
                    self.last_message_time[chat_id_str] = datetime.now()
                    
                    name = getattr(chat, 'username', getattr(chat, 'title', str(chat_id)))
                    await self.process_message(text, chat_id, name, event)
            except Exception as e:
                logger.error(f"❌ Handler hatası: {e}", exc_info=True)

        logger.info("🚀 Bot kullanıcı hesabıyla çalışıyor!")
        await self.client.run_until_disconnected()

if __name__ == '__main__':
    os.makedirs('logs', exist_ok=True)
    asyncio.run(TelegramDealBot().run())
