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
        """Fiyat metnini sayıya çevir - Gelişmiş Pattern"""
        if not price_str: return 0.0
        try:
            # Para birimlerini ve gereksiz metinleri at
            price_str = price_str.split('TL')[0].split('₺')[0].strip()
            price_str = re.sub(r'[^\d,\.]', '', price_str)
            
            # Format düzeltme (1.250,50 -> 1250.50)
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
            logger.error(f"❌ Link hatası ({url}): {e}")
            return {}

    def extract_html_data(self, html: str, base_url: str) -> dict:
        """HTML'den fiyat ve diğer bilgileri çek - Gelişmiş Site Bazlı Mantık"""
        data = {'price': 0.0, 'original_price': 0.0}
        if not html: return data

        try:
            soup = BeautifulSoup(html, 'lxml')
            parsed_url = urlparse(base_url)
            hostname = parsed_url.hostname.lower() if parsed_url.hostname else ''

            # --- SİTE BAZLI ÖZEL SELECTORLAR ---
            
            # 1. Amazon
            if 'amazon' in hostname:
                selectors = ['#corePriceDisplay_desktop_feature_div .a-price.priceToPay .a-offscreen', '.priceToPay span.a-offscreen', '.a-price-whole']
                for s in selectors:
                    elem = soup.select_one(s)
                    if elem:
                        p = self._parse_price(elem.get_text())
                        if p >= 5: data['price'] = p; break
                return data

            # 2. Marketler (Migros, A101, Şok)
            if any(x in hostname for x in ['migros', 'a101', 'sokmarket']):
                selectors = ['.product-price', '.current-price', 'span[data-price]', 'span[itemprop="price"]']
                for s in selectors:
                    elem = soup.select_one(s)
                    if elem:
                        price_text = elem['data-price'] if elem.has_attr('data-price') else elem.get_text()
                        p = self._parse_price(price_text)
                        if p >= 1: data['price'] = p; return data

            # 3. Trendyol & Hepsiburada & N11
            if any(x in hostname for x in ['trendyol', 'hepsiburada', 'n11.com']):
                selectors = ['span.prc-dsc', 'div[data-bind*="currentPrice"]', '.newPrice ins', '.product-new-price']
                for s in selectors:
                    elem = soup.select_one(s)
                    if elem:
                        p = self._parse_price(elem.get_text())
                        if p >= 5: data['price'] = p; break
                if data['price'] > 0: return data

            # --- GENEL MANTIK (JSON-LD) ---
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

            # --- GENEL MANTIK (Meta Tags) ---
            meta_selectors = [{'property': 'product:price:amount'}, {'property': 'og:price:amount'}, {'name': 'price'}]
            for selector in meta_selectors:
                meta = soup.find('meta', selector)
                if meta and meta.get('content'):
                    p = self._parse_price(meta.get('content'))
                    if p >= 5: data['price'] = p; return data

        except Exception as e:
            logger.error(f"HTML analiz hatası: {e}")
        
        return data

    async def analyze_deal_with_ai(self, text: str, link: str = "") -> Dict:
        """Gemini AI ile mesajı profesyonelce analiz et"""
        if not model: return {}
        try:
            prompt = f"""
            Sen dünyanın en iyi e-ticaret veri analiz uzmanısın. Aşağıdaki mesajı analiz et ve SADECE JSON döndür.
            
            GÖREVLERİN:
            1. Ürün adını temizle (reklam, kanal adı ve emojileri at).
            2. 'price' en düşük indirimli fiyat olsun. (Örn: "Sepette 100 TL" diyorsa fiyat 100'dür).
            3. Mağazayı belirle (Amazon, Trendyol, Hepsiburada vb.).
            4. Kategoriyi şu listeden seç: ['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 'spor_outdoor', 'kitap_hobi', 'yapi_oto', 'supermarket']
            
            GİRDİLER:
            Mesaj: {text}
            Link: {link}
            
            İSTENEN JSON FORMATI:
            {{
                "title": "Temizlenmiş Ürün Adı",
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
        
        # 1. AI ile mesajı anla
        ai_data = await self.analyze_deal_with_ai(text, link)
        if not ai_data: return

        # 2. HTML'den gerçek fiyatı doğrula
        html_res = await self.fetch_link_data(link)
        if html_res:
            html_data = self.extract_html_data(html_res['html'], html_res['final_url'])
            if html_data.get('price', 0) > 0:
                ai_data['price'] = html_data['price']
                logger.info(f"💰 Fiyat HTML'den güncellendi: {ai_data['price']} TL")

        logger.info(f"✅ FIRSAT YAKALANDI: {ai_data.get('title')} | {ai_data.get('price')} TL | Kat: {ai_data.get('category')}")
        # Burada Firestore'a kayıt işlemi eklenebilir.

    async def run(self):
        """Bot'u çalıştır"""
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

        if not resolved_chats:
            logger.error("❌ Hiçbir kanal takip edilemedi! .env dosyasını kontrol edin.")
            return

        @self.client.on(events.NewMessage(chats=resolved_chats))
        async def handler(event):
            chat = await event.get_chat()
            channel_name = getattr(chat, 'username', getattr(chat, 'title', str(chat.id)))
            await self.process_message(event.message, channel_name)

        logger.info("✅ Bot aktif ve dinliyor... (Durdurmak için CTRL+C)")
        await self.client.run_until_disconnected()

async def main():
    # Logs klasörünü oluştur
    os.makedirs('logs', exist_ok=True)
    bot = TelegramDealBot()
    await bot.run()

if __name__ == '__main__':
    asyncio.run(main())
