/**
 * Telegram Session String Oluşturucu
 * Local'de çalıştır, session string'i al, Cloud Run'a ekle
 */

const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const readline = require('readline');

const API_ID = 37462587;
const API_HASH = '35c8bc7cd010dd61eb5a123e2722be41';

const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

function question(prompt) {
  return new Promise((resolve) => {
    rl.question(prompt, resolve);
  });
}

(async () => {
  console.log('🔐 Telegram Session Oluşturucu');
  console.log('═════════════════════════════════════════');
  console.log('');
  
  const stringSession = new StringSession('');
  const client = new TelegramClient(stringSession, API_ID, API_HASH, {
    connectionRetries: 5,
  });

  await client.start({
    phoneNumber: async () => await question('📱 Telefon numaranız (+90...): '),
    password: async () => await question('🔒 2FA şifreniz (varsa): '),
    phoneCode: async () => await question('📲 Telegram\'dan gelen kod: '),
    onError: (err) => console.log('❌ Hata:', err),
  });

  console.log('');
  console.log('✅ Giriş başarılı!');
  console.log('');
  console.log('📝 SESSION STRING:');
  console.log('═════════════════════════════════════════');
  console.log(client.session.save());
  console.log('═════════════════════════════════════════');
  console.log('');
  console.log('👆 Bu string\'i kopyalayın ve env.yaml dosyasına ekleyin!');
  console.log('');
  
  await client.disconnect();
  rl.close();
  process.exit(0);
})();
