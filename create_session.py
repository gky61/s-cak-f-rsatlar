#!/usr/bin/env python3
"""
Telegram session dosyası oluşturma scripti
Bu script interaktif modda çalıştırılmalı (Docker dışında)
"""
import asyncio
import os
from telethon import TelegramClient
from dotenv import load_dotenv

load_dotenv()

api_id = os.getenv('TELEGRAM_API_ID')
api_hash = os.getenv('TELEGRAM_API_HASH')
phone = os.getenv('TELEGRAM_PHONE')

async def main():
    print(f"📞 Telegram'a bağlanılıyor... (ID: {api_id})")
    print(f"📱 Telefon: {phone}")
    
    # Session dosyasını sessions dizininde oluştur
    os.makedirs('sessions', exist_ok=True)
    client = TelegramClient('sessions/user_session', api_id, api_hash)
    
    await client.start(phone=phone)
    me = await client.get_me()
    print(f"✅ BAŞARILI! Giriş yapılan hesap: {me.first_name} ({me.phone})")
    print(f"✅ Session dosyası oluşturuldu: sessions/user_session.session")
    await client.disconnect()

if __name__ == '__main__':
    asyncio.run(main())


