import os
import json
import re
import asyncio
import logging
from typing import List, Dict, Optional, Any, Union
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

# Gemini AI Yapılandırması
try:
    genai.configure(api_key=os.getenv("GEMINI_API_KEY"))
    model = genai.GenerativeModel('gemini-1.5-flash')
except Exception as e:
    logger.error(f"❌ Gemini AI başlatılamadı: {e}")
    model = None

class TelegramDealBot:
    def __init__(self):
        # Telegram API Ayarları
        self.api_id = os.getenv("TELEGRAM_API_ID")
        self.api_hash = os.getenv("TELEGRAM_API_HASH")
        self.bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
        
        # Dinlenecek Kanallar (ID veya Username)
        self.channels = os.getenv("SOURCE_CHANNELS", "").split(',')
        
        # Firestore URL (Opsiyonel)
        self.firestore_url = os.getenv("FIRESTORE_URL")
        
        # Telegram Client
        self.client = TelegramClient('bot_session', self.api_id, self.api_hash)
        
        # Kategori anahtar kelimeleri (Yedek olarak)
        self.category_keywords = {
            'elektronik': ['telefon', 'laptop', 'bilgisayar', 'tv', 'kulaklık', 'mouse', 'klavye', 'monitör', 'tablet', 'iphone', 'samsung', 'xiaomi', 'huawei', 'asus', 'lenovo', 'hp', 'dell', 'msi', 'acer', 'lg', 'philips', 'sony', 'playstation', 'xbox', 'nintendo', 'airfryer', 'vantilatör', 'kahve makinesi', 'beyaz eşya', 'çamaşır makinesi', 'bulaşık makinesi', 'buzdolabı', 'fırın', 'mikrodalga', 'ütü', 'süpürge', 'tost makinesi', 'kettle', 'robot süpürge', 'akıllı saat', 'kamera', 'drone'],
            'moda': ['ayakkabı', 'kıyafet', 'tişört', 'pantolon', 'elbise', 'mont', 'ceket', 'çanta', 'saat', 'gözlük', 'aksesuar', 'takı', 'parfüm', 'kozmetik', 'bakım', 'şampuan', 'sabun', 'diş macunu', 'fırça', 'krem', 'makyaj', 'ruj', 'fondöten', 'rimel', 'maskara', 'allık', 'pudra', 'oje'],
            'ev_yasam': ['mobilya', 'dekorasyon', 'mutfak', 'banyo', 'yatak', 'yorgan', 'yastık', 'çarşaf', 'battaniye', 'havlu', 'perde', 'halı', 'kilim', 'aydınlatma', 'lamba', 'avize', 'tablo', 'saat', 'ayna', 'çiçek', 'saksı', 'bahçe', 'deterjan', 'temizlik', 'yumuşatıcı', 'bulaşık', 'çamaşır', 'kağıt', 'peçete', 'havlu'],
            'anne_bebek': ['bebek', 'çocuk', 'anne', 'mama', 'bez', 'oyuncak', 'araba', 'koltuk', 'biberon', 'emzik', 'beşik'],
            'supermarket': ['market', 'gıda', 'içecek', 'atıştırmalık', 'kahvaltılık', 'süt', 'peynir', 'yoğurt', 'yumurta', 'et', 'tavuk', 'balık', 'meyve', 'sebze', 'ekmek', 'un', 'şeker', 'tuz', 'yağ', 'bakliyat', 'makarna', 'kedi', 'köpek', 'mama']
        }

    async def initialize(self):
        """Bot'u başlat"""
        if not self.api_id or not self.api_hash or not self.bot_token:
            logger.error("❌ HATA: .env dosyasında TELEGRAM_API_ID, TELEGRAM_API_HASH veya TELEGRAM_BOT_TOKEN eksik!")
            raise ValueError("Eksik Telegram yapılandırması!")
            
        try:
            await self.client.start(bot_token=self.bot_token)
            logger.info("✅ Bot başarıyla başlatıldı!")
        except Exception as e:
            logger.error(f"❌ Bot başlatılırken hata oluştu: {e}")
            raise e

    def _parse_price(self, price_str: str) -> float:
        """Fiyat metnini sayıya çevir"""
        if not price_str:
            return 0.0
        try:
            # Sadece sayıları, virgülü ve noktayı tut
            price_str = re.sub(r'[^\d,\.]', '', price_str)
            
            # Format: 1.859,12 veya 174,900
            if ',' in price_str and '.' in price_str:
                if price_str.find('.') < price_str.find(','):
                    price_str = price_str.replace('.', '').replace(',', '.')
                else:
                    price_str = price_str.replace(',', '').replace('.', '.')
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
        """Linkten ürün bilgilerini çek"""
        try:
            response = curl_requests.get(
                url, 
                impersonate="chrome110",
                timeout=30,
                allow_redirects=True
            )
            if response.status_code == 200:
                return {'html': response.text, 'final_url': response.url}
            return {}
        except Exception as e:
            logger.error(f"❌ Link çekme hatası ({url}): {e}")
            return {}

    def extract_html_data(self, html: str, base_url: str) -> dict:
        """HTML'den fiyat ve diğer bilgileri çek"""
        data = {'price': 0.0, 'original_price': 0.0}
        if not html: return data

        try:
            soup = BeautifulSoup(html, 'lxml')
            parsed_url = urlparse(base_url)
            hostname = parsed_url.hostname.lower() if parsed_url.hostname else ''

            # 1. Amazon
            if 'amazon' in hostname:
                price_selectors = [
                    ('#corePriceDisplay_desktop_feature_div .a-price.priceToPay .a-offscreen', 'Ana fiyat'),
                    ('.priceToPay span.a-offscreen', 'PriceToPay gizli')
                ]
                for selector, desc in price_selectors:
                    elem = soup.select_one(selector)
                    if elem:
                        price = self._parse_price(elem.get_text(strip=True))
                        if price >= 5:
                            data['price'] = price
                            break
                return data

            # 2. JSON-LD
            json_ld_scripts = soup.find_all('script', type='application/ld+json')
            for script in json_ld_scripts:
                try:
                    if not script.string: continue
                    js_data = json.loads(script.string)
                    
                    def find_price_recursive(obj):
                        if isinstance(obj, dict):
                            if 'price' in obj:
                                p = self._parse_price(str(obj['price']))
                                if p >= 5: return p
                            if 'offers' in obj:
                                return find_price_recursive(obj['offers'])
                            if 'lowPrice' in obj:
                                return self._parse_price(str(obj['lowPrice']))
                        elif isinstance(obj, list):
                            for item in obj:
                                res = find_price_recursive(item)
                                if res: return res
                        return None

                    p = find_price_recursive(js_data)
                    if p and p >= 5:
                        data['price'] = p
                        return data
                except: continue

            # 3. Meta tags
            meta_selectors = [{'property': 'product:price:amount'}, {'property': 'og:price:amount'}, {'name': 'price'}]
            for selector in meta_selectors:
                meta = soup.find('meta', selector)
                if meta and meta.get('content'):
                    p = self._parse_price(meta.get('content'))
                    if p >= 5:
                        data['price'] = p
                        return data

        except Exception as e:
            logger.error(f"HTML analiz hatası: {e}")
        return data

    async def analyze_deal_with_ai(self, text: str, link: str = "") -> Dict:
        """Gemini AI ile fırsat metnini analiz et"""
        if not model: return {}
        try:
            prompt = f"""
            Sen dünyanın en iyi e-ticaret veri analiz uzmanısın. Aşağıdaki mesajı analiz et ve SADECE JSON döndür.
            Ürün adını temizle. En düşük fiyatı 'price' olarak al.
            
            Kategoriler: ['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 'spor_outdoor', 'kitap_hobi', 'yapi_oto', 'supermarket']
            
            Mesaj: {text}
            Link: {link}
            
            İstenen JSON:
            {{
                "title": "Ürün Adı",
                "price": 123.45,
                "original_price": 0.0,
                "store": "Mağaza Adı",
                "category": "kategori_adi",
                "confidence": "high"
            }}
            """
            response = await model.generate_content_async(
                prompt,
                generation_config=genai.types.GenerationConfig(temperature=0.1)
            )
            json_text = response.text.replace('```json', '').replace('```', '').strip()
            return json.loads(json_text)
        except Exception as e:
            logger.error(f"❌ AI Analiz Hatası: {e}")
            return {}

    async def process_message(self, message, channel_name):
        """Mesajı işle ve fırsatı kaydet"""
        text = message.message or ""
        urls = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)
        if not urls: return

        link = urls[0]
        logger.info(f"🔗 İşleniyor: {link} (Kanal: {channel_name})")
        
        # AI Analizi
        ai_data = await self.analyze_deal_with_ai(text, link)
        if not ai_data: return

        # HTML Analizi (Fiyatı doğrulamak için)
        html_res = await self.fetch_link_data(link)
        if html_res:
            html_data = self.extract_html_data(html_res['html'], html_res['final_url'])
            if html_data.get('price', 0) > 0:
                ai_data['price'] = html_data['price']

        logger.info(f"✅ Fırsat Yakalandı: {ai_data.get('title')} - {ai_data.get('price')} TL")

    async def run(self):
        """Bot'u çalıştır"""
        await self.initialize()
        
        target_channels = [c.strip() for c in self.channels if c.strip()]
        if not target_channels:
            logger.error("❌ Kanal listesi boş!")
            return

        resolved_chats = []
        for channel in target_channels:
            try:
                if channel.startswith('-100'): entity = int(channel)
                else: entity = channel
                await self.client.get_input_entity(entity)
                resolved_chats.append(entity)
                logger.info(f"✅ Takipte: {channel}")
            except Exception as e:
                logger.error(f"❌ Kanal hatası ({channel}): {e}")

        if not resolved_chats:
            logger.error("❌ Hiçbir kanal takip edilemedi!")
            return

        @self.client.on(events.NewMessage(chats=resolved_chats))
        async def handler(event):
            chat = await event.get_chat()
            channel_name = getattr(chat, 'username', getattr(chat, 'title', str(chat.id)))
            await self.process_message(event.message, channel_name)

        logger.info("✅ Bot aktif ve dinliyor... (Durdurmak için CTRL+C)")
        await self.client.run_until_disconnected()

async def main():
    os.makedirs('logs', exist_ok=True)
    bot = TelegramDealBot()
    await bot.run()

if __name__ == '__main__':
    asyncio.run(main())
