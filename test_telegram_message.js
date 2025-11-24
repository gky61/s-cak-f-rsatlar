/**
 * Telegram Webhook Test Script
 * Bu script, Telegram webhook'unuzu test etmek için kullanılır
 */

const https = require('https');

// Test mesajı oluştur
function createTestMessage(messageText) {
  return {
    update_id: Date.now(),
    message: {
      message_id: Math.floor(Math.random() * 1000000),
      from: {
        id: 123456789,
        is_bot: false,
        first_name: "Test",
        last_name: "User",
        username: "test_user",
        language_code: "tr"
      },
      chat: {
        id: -123456789, // Negatif sayı = grup
        type: "group",
        title: "Test Grubu"
      },
      date: Math.floor(Date.now() / 1000),
      text: messageText,
      entities: []
    }
  };
}

// Webhook'a POST isteği gönder
function sendToWebhook(webhookUrl, data) {
  return new Promise((resolve, reject) => {
    const url = new URL(webhookUrl);
    const postData = JSON.stringify(data);

    const options = {
      hostname: url.hostname,
      port: url.port || 443,
      path: url.pathname,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      let responseData = '';

      res.on('data', (chunk) => {
        responseData += chunk;
      });

      res.on('end', () => {
        resolve({
          statusCode: res.statusCode,
          headers: res.headers,
          body: responseData
        });
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    req.write(postData);
    req.end();
  });
}

// Ana test fonksiyonu
async function testTelegramWebhook(webhookUrl, messageText) {
  console.log('🧪 Telegram Webhook Test Başlatılıyor...\n');
  
  const testMessage = createTestMessage(messageText);
  
  console.log('📤 Test mesajı oluşturuldu:');
  console.log(JSON.stringify(testMessage, null, 2));
  console.log('\n📡 Webhook\'a gönderiliyor...\n');
  
  try {
    const response = await sendToWebhook(webhookUrl, testMessage);
    
    console.log('✅ Yanıt alındı:');
    console.log(`Status Code: ${response.statusCode}`);
    console.log(`Response: ${response.body}`);
    
    if (response.statusCode === 200) {
      console.log('\n✅ Webhook başarıyla çalışıyor!');
      console.log('💡 Şimdi Firestore\'da deals koleksiyonunu kontrol edin.');
    } else {
      console.log('\n⚠️ Webhook yanıt verdi ama beklenmeyen status code.');
    }
  } catch (error) {
    console.error('\n❌ Hata:', error.message);
    console.error('\nKontrol edin:');
    console.error('• Webhook URL doğru mu?');
    console.error('• Firebase function deploy edildi mi?');
    console.error('• Firebase config ayarlandı mı?');
  }
}

// Komut satırından çalıştırma
if (require.main === module) {
  const args = process.argv.slice(2);
  
  if (args.length < 2) {
    console.log('Kullanım: node test_telegram_message.js <WEBHOOK_URL> <MESSAGE_TEXT>');
    console.log('\nÖrnek:');
    console.log('node test_telegram_message.js "https://us-central1-xxx.cloudfunctions.net/telegramWebhook" "RTX 4090\\nFiyat: 45000 TL\\nhttps://example.com"');
    process.exit(1);
  }
  
  const webhookUrl = args[0];
  const messageText = args.slice(1).join(' ');
  
  testTelegramWebhook(webhookUrl, messageText);
}

module.exports = { testTelegramWebhook, createTestMessage };





