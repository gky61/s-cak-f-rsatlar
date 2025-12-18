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
        raw_channels = os.getenv("SOURCE_CHANNELS") or os.getenv("TELEGRAM_CHANNELS") or ""
        self.channels = [c.strip() for c in raw_channels.split(',') if c.strip()]
        self.client = TelegramClient('bot_session', self.api_id, self.api_hash)

    async def initialize(self):
        if not self.api_id or not self.api_hash or not self.bot_token:
            logger.error("❌ Yapılandırma eksik!")
            return False
        await self.client.start(bot_token=self.bot_token)
        me = await self.client.get_me()
        logger.info(f"✅ Bot bağlandı! Kullanıcı Adı: @{me.username} | ID: {me.id}")
        return True

    async def analyze_deal_with_ai(self, text: str, link: str = "") -> Dict:
        if not model: return {}
        try:
            prompt = f"E-ticaret uzmanı olarak şu mesajı analiz et ve SADECE JSON döndür. Başka metin ekleme:\n{text}\nLink: {link}"
            response = await model.generate_content_async(prompt, generation_config=genai.types.GenerationConfig(temperature=0.1))
            return json.loads(response.text.replace('```json', '').replace('```', '').strip())
        except: return {}

    async def process_message(self, text, chat_id, name):
        logger.info(f"⚙️ Mesaj İşleniyor... Kanal: {name} ({chat_id})")
        urls = re.findall(r'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+', text)
        
        if not urls:
            logger.info("ℹ️ Link bulunmadı, işlem iptal.")
            return

        # AI ve Veri Çekme Simülasyonu (Hızlı test için)
        ai_data = await self.analyze_deal_with_ai(text, urls[0])
        title = ai_data.get('title', text[:50])
        logger.info(f"✅ BAŞARI: Ürün Yakalandı -> {title}")

    async def run(self):
        if not await self.initialize(): return
        
        logger.info(f"📡 Dinlenen Kanallar: {self.channels}")

        @self.client.on(events.NewMessage())
        async def handler(event):
            chat = await event.get_chat()
            chat_id = chat.id
            text = event.message.message or ""
            
            # KRİTİK DEBUG: Botun duyduğu her şeyi yaz
            logger.info(f"📩 DUYULAN MESAJ: [ID: {chat_id}] - İçerik: {text[:30]}...")

            # Eğer kullanıcı bota özelden bir şey yazarsa ID'sini söyle
            if event.is_private:
                await event.reply(f"Selam! Bu sohbetin ID'si: `{chat_id}`\nBunu .env dosyasına ekleyebilirsin.")

            # Kanal/Grup Filtreleme
            is_target = False
            if str(chat_id) in self.channels or (hasattr(chat, 'username') and f"@{chat.username}" in self.channels):
                is_target = True
            
            if is_target:
                name = getattr(chat, 'username', getattr(chat, 'title', str(chat_id)))
                await self.process_message(text, chat_id, name)

        logger.info("🚀 Bot şu an her şeyi dinliyor! Lütfen mesaj atın...")
        await self.client.run_until_disconnected()

if __name__ == '__main__':
    os.makedirs('logs', exist_ok=True)
    asyncio.run(TelegramDealBot().run())
