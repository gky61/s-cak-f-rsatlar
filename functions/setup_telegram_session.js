/**
 * Telegram Session String Oluşturma Script'i
 *
 * Kullanım:
 * 1. API ID ve API Hash'i my.telegram.org'dan alın
 * 2. Bu dosyadaki API_ID ve API_HASH değerlerini güncelleyin
 * 3. node setup_telegram_session.js komutunu çalıştırın
 * 4. Telefon numaranızı ve Telegram'dan gelen kodu girin
 * 5. Session string'i kopyalayın ve Firebase config'e ekleyin
 */

const {TelegramClient} = require('telegram');
const {StringSession} = require('telegram/sessions');
const readline = require('readline');

// ⚠️ BURAYI GÜNCELLEYİN: my.telegram.org/apps'den alın
const API_ID = '37462587'; // my.telegram.org'dan aldığınız API ID
const API_HASH = '35c8bc7cd010dd61eb5a123e2722be41'; // my.telegram.org'dan aldığınız API Hash

const stringSession = new StringSession(''); // Boş string ile başla

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(query) {
  return new Promise((resolve) => rl.question(query, resolve));
}

(async () => {
  if (API_ID === 'YOUR_API_ID' || API_HASH === 'YOUR_API_HASH') {
    console.error('❌ HATA: API_ID ve API_HASH değerlerini güncelleyin!');
    console.error('my.telegram.org/apps adresinden alabilirsiniz.');
    process.exit(1);
  }

  console.log('📱 Telegram Session Oluşturma');
  console.log('==============================\n');

  const client = new TelegramClient(stringSession, parseInt(API_ID), API_HASH, {
    connectionRetries: 5,
  });

  try {
    await client.start({
      phoneNumber: async () => await question('📞 Telefon numaranızı girin (örn: +905551234567): '),
      password: async () => await question('🔒 2FA şifreniz varsa girin (yoksa Enter): '),
      phoneCode: async () => await question('🔐 Telegram\'dan gelen kodu girin: '),
      onError: (err) => {
        console.error('Giriş hatası:', err);
        throw err;
      },
    });

    console.log('\n✅ Giriş başarılı!\n');
    console.log('📋 Session String (Bunu kopyalayın):');
    console.log('='.repeat(50));
    console.log(client.session.save());
    console.log('='.repeat(50));
    console.log('\n💡 Bu string\'i Firebase config\'e ekleyin:');
    console.log('firebase functions:config:set telegram.session_string="SESSION_STRING_BURAYA"\n');

    await client.disconnect();
    rl.close();
  } catch (error) {
    console.error('\n❌ Hata:', error.message);
    await client.disconnect();
    rl.close();
    process.exit(1);
  }
})();

