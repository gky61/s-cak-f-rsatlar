/**
 * Telegram Function'ı Manuel Test Etme
 * Bu script, fetchChannelMessages function'ını manuel olarak tetikler
 */

const admin = require('firebase-admin');
const {fetchChannelMessages} = require('./functions/telegram_client');

// Firebase Admin'i başlat
if (!admin.apps.length) {
  admin.initializeApp();
}

async function testFunction() {
  console.log('🧪 Telegram Function Test Başlatılıyor...\n');

  // Config'den bilgileri al
  const apiId = process.env.TELEGRAM_API_ID || '37462587';
  const apiHash = process.env.TELEGRAM_API_HASH || '35c8bc7cd010dd61eb5a123e2722be41';
  const sessionString = process.env.TELEGRAM_SESSION_STRING || 
    '1BAAOMTQ5LjE1NC4xNjcuOTEAUH1G1uC4mMdqGaXNOcR065VVmuGzwx+XcMAriyt1/m2H0GjGlcxiOPQ1a84arWKw3s7u5SwFKYRDwDSDTFz5r0pNUcYKAxQ/WwPJ9cJ2NaiVVWYjlkJ06nPzL1V6gC5XOn4+7Qvx2c1eeIggi4UmgpS5n1HyTWVYF0SxnM9o9fSR+KolzCxy8154MAG4GnBUG18LGSjLr6/MvB9FDpf+/uWsIy24h6Pj4SPad9Vd1FJGycla9ZKTXA5ipKWrjJmBLOzycAY43VSl5xVFBO5MDdlAgb+QtPTR3WfF6HX+CeFmWPAyOgpaZz1l094XAk6NPMpxxX2OrXztpi6pUoVWQeg=';
  
  const channels = process.env.TELEGRAM_CHANNELS || 
    '@donanimhabersicakfirsatlar,-3371238729';
  const channelList = channels.split(',').map(ch => ch.trim());

  console.log('📋 Test Edilecek Kanallar/Gruplar:');
  channelList.forEach(ch => console.log(`  - ${ch}`));
  console.log('');

  let totalDeals = 0;

  for (const channelIdentifier of channelList) {
    try {
      console.log(`\n🔍 ${channelIdentifier} kontrol ediliyor...`);
      const newDeals = await fetchChannelMessages(
        channelIdentifier,
        apiId,
        apiHash,
        sessionString
      );
      console.log(`✅ ${channelIdentifier}: ${newDeals.length} yeni deal bulundu`);
      totalDeals += newDeals.length;
    } catch (error) {
      console.error(`❌ ${channelIdentifier} için hata:`, error.message);
    }
  }

  console.log(`\n🎉 Test tamamlandı! Toplam ${totalDeals} yeni deal bulundu.`);
  process.exit(0);
}

testFunction().catch(error => {
  console.error('❌ Test hatası:', error);
  process.exit(1);
});





