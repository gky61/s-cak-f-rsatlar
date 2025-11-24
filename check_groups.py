
import os
from telethon import TelegramClient
from dotenv import load_dotenv
import asyncio

load_dotenv()

api_id = os.getenv('TELEGRAM_API_ID')
api_hash = os.getenv('TELEGRAM_API_HASH')
session_name = 'telegram_session_new'  # Mevcut session'ı kullan

async def main():
    print("🔍 Grup/Kanal Tarayıcı")
    print("----------------------")
    
    client = TelegramClient(session_name, int(api_id), api_hash)
    await client.start()
    
    print("✅ Bağlandı. Gruplar taranıyor...\n")
    
    async for dialog in client.iter_dialogs():
        # Sadece grupları ve kanalları göster
        if dialog.is_group or dialog.is_channel:
            print(f"📌 Ad: {dialog.name}")
            print(f"   ID: {dialog.id}")
            print(f"   Tip: {'Kanal' if dialog.is_channel else 'Grup'}")
            print("-" * 30)

if __name__ == '__main__':
    asyncio.run(main())

