
import os
from telethon import TelegramClient
from dotenv import load_dotenv
import asyncio

load_dotenv()

api_id = os.getenv('TELEGRAM_API_ID')
api_hash = os.getenv('TELEGRAM_API_HASH')
session_name = 'telegram_session_new'

async def main():
    print("🔐 Telegram Oturum Açma Sihirbazı")
    print("--------------------------------")
    
    if not api_id or not api_hash:
        print("❌ .env dosyasında TELEGRAM_API_ID veya TELEGRAM_API_HASH eksik!")
        return

    client = TelegramClient(session_name, int(api_id), api_hash)
    
    print("🔄 Telegram sunucularına bağlanılıyor...")
    await client.start()
    
    print("\n✅ Oturum başarıyla açıldı!")
    print(f"📄 Session dosyası oluşturuldu: {session_name}.session")
    print("Şimdi bu dosyayı Oracle sunucusuna gönderebiliriz.")
    
    # Kendine test mesajı at
    me = await client.get_me()
    print(f"👋 Hoşgeldin: {me.first_name} (ID: {me.id})")
    await client.send_message('me', '🤖 Oracle Bot kurulumu için yeni oturum oluşturuldu!')

if __name__ == '__main__':
    asyncio.run(main())

