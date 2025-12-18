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
        self.api_id = os.getenv("TELEGRAM_API_ID")
        self.api_hash = os.getenv("TELEGRAM_API_HASH")
        self.bot_token = os.getenv("TELEGRAM_BOT_TOKEN")
        self.channels = os.getenv("SOURCE_CHANNELS", "").split(',')
        self.client = TelegramClient('bot_session', self.api_id, self.api_hash)

    async def initialize(self):
        """Bot'u başlat"""
        if not self.api_id or not self.api_hash or not self.bot_token:
            logger.error("❌ .env dosyasında eksik bilgiler var!")
            return False
        await self.client.start(bot_token=self.bot_token)
        logger.info("✅ Bot başarıyla başlatıldı!")
        return True

    def _parse_price(self, price_str: str) -> float:
        """Fiyat metnini sayıya çevir"""
        if not price_str: return 0.0
        try:
            price_str = price_str.split('TL')[0].split('₺')[0].strip()
            price_str = re.sub(r'[^\d,\.]', '', price_str)
            if ',' in price_str and '.' in price_str:
                if price_str.find('.') < price_str.find(','):
                    price_str = price_str.replace('.', '').replace(',', '.')
                else:
                    price_str = price_str.replace(',', '').replace('.', '.')
            elif ',' in price_str:
                parts = price_str.split(',')
                if len(parts[-1]) <= 2: price_str = price_str.replace(',', '.')
                else: price_str = price_str.replace(',', '')
            return float(price_str)
        except: return 0.0

    async def fetch_link_data(self, url: str) -> Dict:
        """Linkten HTML içeriğini çek"""
        try:
            response = curl_requests.get(url, impersonate="chrome110", timeout=30, allow_redirects=True)
            if response.status_code == 200:
                return {'html': response.text, 'final_url': response.url}
            return {}
        except Exception as e:
            logger.error(f"❌ Link hatası ({url}): {e}")
            return {}

    def extract_html_data(self, html: str, base_url: str) -> dict:
        """Sitelerden özel fiyat çekme mantığı"""
        data = {'price': 0.0, 'original_price': 0.0}
        if not html: return data
        try:
            soup = BeautifulSoup(html, 'lxml')
            parsed_url = urlparse(base_url)
            hostname = parsed_url.hostname.lower() if parsed_url.hostname else ''

            if any(x in hostname for x in ['migros', 'a101', 'sokmarket']):
                selectors = ['.product-price', '.current-price', 'span[data-price]']
                for s in selectors:
                    elem = soup.select_one(s)
                    if elem:
                        price_text = elem['data-price'] if elem.has_attr('data-price') else elem.get_text()
                        p = self._parse_price(price_text)
                        if p >= 1: data['price'] = p; return data

            for script in soup.find_all('script', type='application/ld+json'):
                try:
                    js = json.loads(script.string)
                    def find_p(obj):
                        if isinstance(obj, dict):
                            if 'price' in obj: return self._parse_price(str(obj['price']))
                            if 'offers' in obj: return find_p(obj['offers'])
                            if 'lowPrice' in obj: return self._parse_price(str(obj['lowPrice']))
                        elif isinstance(obj, list):
                            for i in obj:
                                r = find_p(i)
                                if r: return r
                        return None
                    p = find_p(js)
                    if p and p >= 5: data['price'] = p; return data
                except: continue
        except Exception as e:
            logger.error(f"HTML analiz hatası: {e}")
        return data

    async def analyze_deal_with_ai(self, text: str, link: str = "") -> Dict:
        """Gemini AI ile mesajı analiz et"""
        if not model: return {}
        try:
            prompt = f"Sen bir e-ticaret uzmanısın. Şu mesajı analiz et ve SADECE JSON döndür:\n{text}\nLink: {link}\n\nİstenen JSON: {{\"title\": \"...\", \"price\": 0.0, \"category\": \"...\"}}"
            response = await model.generate_content_async(prompt, generation_config=genai.types.GenerationConfig(temperature=0.1))
            return json.loads(response.text.replace('```json', '').replace('```', '').strip())
        except Exception as e:
            logger.error(f"❌ AI hatası: {e}")
            return {}

    async def process_message(self, message, channel_name):
        """Mesajı işle ve fırsatı kaydet"""
        text = message.message or ""
        logger.info(f"📩 YENİ MESAJ GELDİ (Kanal: {channel_name}) -> İçerik: {text[:50]}...")
        
        urls = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)
        if not urls:
            logger.warning("⚠️ Mesajda link bulunamadı, atlanıyor.")
            return

        link = urls[0]
        logger.info(f"🔗 Link algılandı: {link}")
        
        # 1. AI ile mesajı anla
        ai_data = await self.analyze_deal_with_ai(text, link)
        
        # Eğer AI başarısız olursa varsayılan değerlerle devam et
        if not ai_data:
            logger.warning("⚠️ AI analizi yapılamadı, temel bilgilerle devam ediliyor.")
            ai_data = {
                "title": text[:100].replace("\n", " ") + "...",
                "price": 0.0,
                "category": "diğer",
                "store": "Bilinmeyen"
            }
        
        # 2. HTML'den gerçek fiyatı doğrula (AI başarısız olsa bile linkten fiyat çekmeye çalış)
        html_res = await self.fetch_link_data(link)
        if html_res:
            html_data = self.extract_html_data(html_res['html'], html_res['final_url'])
            if html_data.get('price', 0) > 0:
                ai_data['price'] = html_data['price']
                logger.info(f"💰 Fiyat HTML'den çekildi: {ai_data['price']} TL")

        logger.info(f"✅ SONUÇ: {ai_data.get('title')} | {ai_data.get('price')} TL | Kat: {ai_data.get('category')}")
        # İleride buraya Firestore kayıt kodu gelecek.

    async def run(self):
        if not await self.initialize(): return
        
        target_channels = [c.strip() for c in self.channels if c.strip()]
        resolved_chats = []
        for channel in target_channels:
            try:
                entity = channel
                if channel.startswith('-'):
                    try: entity = int(channel)
                    except: pass
                await self.client.get_input_entity(entity)
                resolved_chats.append(entity)
                logger.info(f"✅ Takipte: {channel}")
            except Exception as e:
                logger.error(f"❌ Kanal hatası ({channel}): {e}")

        if not resolved_chats: return

        @self.client.on(events.NewMessage(chats=resolved_chats))
        async def handler(event):
            chat = await event.get_chat()
            name = getattr(chat, 'username', getattr(chat, 'title', str(chat.id)))
            await self.process_message(event.message, name)

        logger.info("✅ Bot aktif ve dinliyor... (Durdurmak için CTRL+C)")
        await self.client.run_until_disconnected()

async def main():
    os.makedirs('logs', exist_ok=True)
    bot = TelegramDealBot()
    await bot.run()

if __name__ == '__main__':
    asyncio.run(main())
