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
    model = genai.GenerativeModel('gemini-1.5-flash')
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
        if not html: return data
        try:
            soup = BeautifulSoup(html, 'lxml')
            
            # JSON-LD verilerini çek
            for script in soup.find_all('script', type='application/ld+json'):
                try:
                    js = json.loads(script.string)
                    if isinstance(js, dict):
                        if 'offers' in js:
                            price = js['offers'].get('price') or js['offers'].get('lowPrice', 0)
                            if price: data['price'] = self._parse_price(str(price))
                        if 'name' in js and not data['title']:
                            data['title'] = js['name']
                        if 'image' in js and not data['image']:
                            img = js['image']
                            data['image'] = img[0] if isinstance(img, list) else img
                except:
                    continue

            # Görseli çek
            if not data['image']:
                img_tag = soup.find('meta', property='og:image') or soup.find('meta', attrs={'name': 'twitter:image'})
                if img_tag:
                    data['image'] = img_tag.get('content', '')
            
            # Başlığı çek
            if not data['title']:
                title_tag = soup.find('meta', property='og:title') or soup.find('title')
                if title_tag:
                    data['title'] = title_tag.get('content') if title_tag.get('content') else title_tag.get_text()

        except Exception as e:
            logger.error(f"❌ HTML analiz hatası: {e}")
        return data

    async def analyze_deal_with_ai(self, text: str, link: str = "") -> Dict:
        if not model: return {}
        try:
            prompt = f"""Sen bir e-ticaret uzmanısın. Aşağıdaki mesajı analiz et ve SADECE JSON döndür:

Mesaj: {text}
Link: {link}

Döndürülecek JSON formatı:
{{
  "title": "Ürün başlığı (kısa ve net)",
  "price": 0.0,
  "category": "mobil-cihazlar | bilgisayar | ev-yasam | konsol-oyun | diğer",
  "store": "Mağaza adı"
}}

Kurallar:
- Kategori mutlaka yukarıdaki 5 seçenekten biri olmalı
- Fiyat sayısal olmalı (0.0 formatında)
- Başka açıklama ekleme, sadece JSON döndür"""
            
            response = await model.generate_content_async(
                prompt, 
                generation_config=genai.types.GenerationConfig(temperature=0.1)
            )
            return json.loads(response.text.replace('```json', '').replace('```', '').strip())
        except Exception as e:
            logger.error(f"❌ AI hatası: {e}")
            return {}

    async def save_to_firestore(self, deal_data: dict):
        if not db:
            logger.error("❌ Firestore bağlantısı yok! Kayıt yapılamıyor!")
            return False
        try:
            deal_data['createdAt'] = datetime.now()
            deal_data['isApproved'] = False
            deal_data['likes'] = 0
            deal_data['views'] = 0
            deal_data['isEditorPick'] = False
            
            doc_ref = db.collection('deals').document()
            doc_ref.set(deal_data)
            logger.info(f"✅ Firestore'a kaydedildi: {deal_data.get('title')}")
            return True
        except Exception as e:
            logger.error(f"❌ Firestore kayıt hatası: {e}")
            return False

    async def process_message(self, text, chat_id, name):
        logger.info(f"📥 Mesaj İşleniyor... Kanal: {name}")
        urls = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)
        
        if not urls:
            logger.info("ℹ️ Link yok, atlanıyor.")
            return
            
        link = urls[0]
        logger.info(f"🔗 Link: {link}")
        
        # AI ile analiz et
        ai_data = await self.analyze_deal_with_ai(text, link)
        if not ai_data:
            logger.warning("⚠️ AI analizi başarısız, temel veri kullanılıyor")
            ai_data = {
                'title': text[:100],
                'price': 0.0,
                'category': 'diğer',
                'store': 'Bilinmeyen'
            }
        
        # HTML'den veri çek
        html_res = await self.fetch_link_data(link)
        html_data = {}
        if html_res:
            html_data = self.extract_html_data(html_res['html'], html_res['final_url'])
            link = html_res['final_url']
        
        # Verileri birleştir
        final_data = {
            'title': html_data.get('title') or ai_data.get('title', text[:100]),
            'price': html_data.get('price') or ai_data.get('price', 0.0),
            'imageUrl': html_data.get('image', ''),
            'productUrl': link,
            'category': ai_data.get('category', 'diğer'),
            'store': ai_data.get('store', 'Bilinmeyen'),
            'description': text[:500],
        }
        
        logger.info(f"💾 Kaydediliyor: {final_data['title']} | {final_data['price']} TL")
        
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
            
            logger.info(f"📩 MESAJ: [ID: {chat_id}] - {text[:50]}...")

            # Filtrele
            is_target = False
            if str(chat_id) in self.channels or (hasattr(chat, 'username') and f"@{chat.username}" in self.channels):
                is_target = True
            
            if is_target:
                name = getattr(chat, 'username', getattr(chat, 'title', str(chat_id)))
                await self.process_message(text, chat_id, name)

        logger.info("🚀 Bot kullanıcı hesabıyla çalışıyor!")
        await self.client.run_until_disconnected()

if __name__ == '__main__':
    os.makedirs('logs', exist_ok=True)
    asyncio.run(TelegramDealBot().run())
