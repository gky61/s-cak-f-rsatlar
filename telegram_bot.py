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
    # Doğru model adı: gemini-1.5-flash veya gemini-pro
    try:
        model = genai.GenerativeModel('gemini-1.5-flash')
        logger.info("✅ Gemini AI modeli yüklendi: gemini-1.5-flash")
    except:
        model = genai.GenerativeModel('gemini-pro')
        logger.info("✅ Gemini AI modeli yüklendi: gemini-pro")
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
            price_str = price_str.split('TL')[0].split('₺')[0].strip()
            price_str = re.sub(r'[^\d,\.]', '', price_str)
            if ',' in price_str and '.' in price_str:
                if price_str.find('.') < price_str.find(','):
                    price_str = price_str.replace('.', '').replace(',', '.')
                else:
                    price_str = price_str.replace(',', '')
            elif ',' in price_str:
                parts = price_str.split(',')
                if len(parts[-1]) <= 2:
                    price_str = price_str.replace(',', '.')
                else:
                    price_str = price_str.replace(',', '')
            return float(price_str)
        except:
            return 0.0

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

            if html_text:
                analysis_text += f"""

HTML İçeriği (ürün sayfasından):
{html_text[:2000]}"""  # HTML'den önemli kısımları al (fiyat, başlık vb.)

            prompt = f"""Sen bir e-ticaret uzmanısın. Aşağıdaki bilgileri analiz et ve fiyatı bul.

{analysis_text}

GÖREV:
1. Görselde (eğer varsa) fiyat yazıyorsa onu oku
2. Mesaj metninde fiyat ara
3. HTML içeriğinde fiyat ara
4. Tüm kaynaklardan en doğru fiyatı bul

MUTLAKA şu JSON formatını döndür (başka hiçbir şey yazma):
{{
  "title": "ürün başlığı",
  "price": 1234.50,
  "category": "elektronik|moda|ev_yasam|anne_bebek|kozmetik|spor_outdoor|supermarket|yapi_oto|kitap_hobi|diğer",
  "store": "mağaza adı"
}}

KURALLAR:
1. Kategori MUTLAKA şunlardan biri olmalı: elektronik, moda, ev_yasam, anne_bebek, kozmetik, spor_outdoor, supermarket, yapi_oto, kitap_hobi, diğer
2. Fiyat ÇOK ÖNEMLİ - Görselde, mesajda veya HTML'de fiyat varsa MUTLAKA bulmalısın. TL, ₺, lira, fiyat gibi kelimelerin yanındaki sayıları bul. Örnekler: "5999 TL" -> 5999.0, "1.299,99 ₺" -> 1299.99, "2.500 lira" -> 2500.0
3. Görselde fiyat yazıyorsa (örneğin ürün etiketi, fiyat etiketi) onu oku
4. Title kısa ve net olsun (maksimum 100 karakter)
5. Store adını mesajdan veya link'ten çıkar
6. SADECE JSON döndür, başka hiçbir açıklama yazma

Örnek çıktı:
{{"title": "iPhone 15 Pro Max", "price": 59999.0, "category": "elektronik", "store": "Apple Store"}}"""
            
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
            # Markdown code block'ları temizle
            if '```json' in response_text:
                response_text = response_text.split('```json')[1].split('```')[0].strip()
            elif '```' in response_text:
                response_text = response_text.split('```')[1].split('```')[0].strip()
            
            ai_result = json.loads(response_text)
            logger.info(f"✅ AI analizi tamamlandı: {ai_result}")
            return ai_result
        except json.JSONDecodeError as e:
            logger.error(f"❌ AI JSON parse hatası: {e} | Response: {response.text[:200] if 'response' in locals() else 'N/A'}")
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
        
        # HTML'den veri çek (AI'ye de göndereceğiz)
        logger.info(f"🌐 HTML scraping başlatılıyor: {link}")
        html_res = await self.fetch_link_data(link)
        html_data = {}
        html_text_for_ai = ""  # AI'ye göndermek için HTML metni
        if html_res:
            logger.info("✅ HTML içeriği alındı, veri çıkarılıyor...")
            html_data = self.extract_html_data(html_res['html'], html_res['final_url'])
            link = html_res['final_url']
            logger.info(f"📊 HTML'den çıkarılan: Fiyat={html_data.get('price', 0.0)}, Görsel={'Var' if html_data.get('image') else 'Yok'}, Başlık={'Var' if html_data.get('title') else 'Yok'}")
            
            # HTML'den önemli metni çıkar (fiyat, başlık vb. için AI'ye göndermek üzere)
            try:
                from bs4 import BeautifulSoup
                soup = BeautifulSoup(html_res['html'], 'html.parser')
                # Script ve style tag'lerini kaldır
                for script in soup(["script", "style"]):
                    script.decompose()
                html_text_for_ai = soup.get_text()[:2000]  # İlk 2000 karakter
            except:
                html_text_for_ai = ""
        else:
            logger.warning("⚠️ HTML içeriği alınamadı")
        
        # AI ile analiz et - görseli ve HTML'i de gönder
        ai_data = await self.analyze_deal_with_ai(text, link, telegram_image_bytes, html_text_for_ai)
        if not ai_data:
            logger.warning("⚠️ AI analizi başarısız, temel veri kullanılıyor")
            ai_data = {
                'title': text[:100],
                'price': 0.0,
                'category': 'diğer',
                'store': 'Bilinmeyen'
            }
        
        # Verileri birleştir - Öncelik sırası:
        # Görsel: Telegram fotoğrafı > HTML scraping > Boş
        # Başlık: HTML > AI > Mesaj (ilk 100 karakter)
        # Fiyat: HTML > AI > 0.0
        # Kategori: AI (mutlaka olmalı)
        # Store: AI > 'Bilinmeyen'
        
        image_url = telegram_image_url or html_data.get('image', '') or ''
        title = html_data.get('title') or ai_data.get('title') or text[:100]
        price = html_data.get('price', 0.0) if html_data.get('price', 0.0) > 0 else (ai_data.get('price', 0.0) or 0.0)
        category = ai_data.get('category', 'diğer')
        store = ai_data.get('store', 'Bilinmeyen')
        
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
            chat = await event.get_chat()
            chat_id = chat.id
            text = event.message.message or ""
            
            # Önce link kontrolü yap - link yoksa hiçbir şey yapma
            urls = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)
            if not urls:
                return  # Link yoksa işleme
            
            # Filtrele - hem pozitif hem negatif ID'leri kontrol et
            is_target = False
            chat_id_str = str(chat_id)
            chat_id_neg = f"-{chat_id_str}"
            
            if (chat_id_str in self.channels or 
                chat_id_neg in self.channels or 
                (hasattr(chat, 'username') and f"@{chat.username}" in self.channels)):
                is_target = True
                logger.info(f"✅ Hedef kanal bulundu: {chat_id_str} / {chat_id_neg}")
                logger.info(f"📩 MESAJ (Link içeriyor): [ID: {chat_id}] - {text[:50]}...")
            
            if is_target:
                name = getattr(chat, 'username', getattr(chat, 'title', str(chat_id)))
                await self.process_message(text, chat_id, name, event)

        logger.info("🚀 Bot kullanıcı hesabıyla çalışıyor!")
        await self.client.run_until_disconnected()

if __name__ == '__main__':
    os.makedirs('logs', exist_ok=True)
    asyncio.run(TelegramDealBot().run())
