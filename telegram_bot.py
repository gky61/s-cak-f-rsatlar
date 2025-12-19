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

# Firebase Admin başlat (Opsiyonel)
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
        logger.warning("⚠️ serviceAccountKey.json bulunamadı - Firestore kayıtları yapılmayacak")
except Exception as e:
    logger.warning(f"⚠️ Firebase başlatılamadı: {e} - Bot çalışmaya devam ediyor")
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

    async def save_to_firestore(self, deal_data: dict):
        if not db:
            logger.warning("⚠️ Firestore bağlantısı yok - kayıt yapılmadı")
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
        logger.info(f"🔗 Link bulundu: {link}")
        
        # Basit veri oluştur
        final_data = {
            'title': text[:100] if text else 'Ürün',
            'price': 0.0,
            'imageUrl': '',
            'productUrl': link,
            'category': 'diğer',
            'store': 'Bilinmeyen',
            'description': text[:500] if text else '',
        }
        
        logger.info(f"💾 İşlenen ürün: {final_data['title']}")
        
        # Firestore'a kaydet (eğer bağlantı varsa)
        if db:
            await self.save_to_firestore(final_data)
        else:
            logger.info("ℹ️ Firebase olmadan çalışıyor - sadece log'a yazıldı")

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
