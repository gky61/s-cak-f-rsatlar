const { execSync } = require('child_process');

async function run() {
  const url = process.argv[2] || 'https://ty.gl/k83n7dcf7zn49';
  console.log(`🚀 Deployed Bot Entegrasyon Test Otomasyonu başlatılıyor...`);
  console.log(`🔗 Test Linki: ${url}`);

  // 1. Get Cloud Run Service URL dynamically
  let serviceUrl = '';
  try {
    serviceUrl = execSync('gcloud run services describe telegram-bot --project=sicak-firsatlar-e6eae --region=us-central1 --format="value(status.url)"').toString().trim();
  } catch (err) {
    console.error('❌ Cloud Run URL\'i alınamadı:', err.message);
    process.exit(1);
  }

  if (!serviceUrl) {
    console.error('❌ Cloud Run servis URL\'i boş döndü!');
    process.exit(1);
  }

  const customText = process.argv[3] || '';
  console.log(`📡 Deployed Bot URL: ${serviceUrl}`);
  if (customText) {
    console.log(`📝 Simüle edilen Mesaj Metni: "${customText}"`);
  }
  console.log(`⏱️ HTTP /simulate isteği gönderiliyor (Bu işlem 5-30 saniye sürebilir)...`);

  let simulateUrl = `${serviceUrl}/simulate?url=${encodeURIComponent(url)}`;
  if (customText) {
    simulateUrl += `&text=${encodeURIComponent(customText)}`;
  }
  let result;
  try {
    const response = await fetch(simulateUrl);
    result = await response.json();
  } catch (e) {
    console.error(`❌ HTTP İstek Hatası:`, e.message);
    process.exit(1);
  }

  if (result && result.success) {
    console.log('\n===========================================');
    console.log('🎉 ENTEGRASYON TESTİ BAŞARILI! DEPLOYED BOT ÇALIŞTI!');
    console.log('===========================================');
    
    const data = result.data || {};
    const title = data.title || 'YOK';
    const price = data.price !== undefined ? data.price : 'YOK';
    const imageUrl = data.imageUrl || 'YOK';
    const category = data.category || 'YOK';
    const store = data.store || 'YOK';
    const postedBy = data.postedBy || 'YOK';
    
    console.log(`📌 Belge ID:    ${result.docId}`);
    console.log(`🏢 Mağaza:      ${store}`);
    console.log(`🏷️ Başlık:      "${title}"`);
    console.log(`💰 Fiyat:       ${price} TL`);
    console.log(`📷 Görsel:      ${imageUrl}`);
    console.log(`📁 Kategori:    ${category}`);
    console.log(`👤 Gönderen:    ${postedBy}`);
    console.log('===========================================\n');
  } else {
    console.error('\n❌ HATA: Deployed bot simülasyonu başarısız sonuçlandı!');
    if (result && result.error) {
      console.error(`Detay: ${result.error}`);
    } else {
      console.error(JSON.stringify(result));
    }
    
    console.log('\n📋 Cloud Run loglarının son 20 satırı çekiliyor...');
    try {
      const logs = execSync(`gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=telegram-bot" --limit=20 --project=sicak-firsatlar-e6eae --format=json`).toString();
      const logsJson = JSON.parse(logs);
      logsJson.reverse().forEach(log => {
        if (log.textPayload) console.log(`👉 ${log.textPayload.trim()}`);
      });
    } catch (e) {
      console.error('Logs error:', e.message);
    }
    process.exit(1);
  }
}

run().catch(console.error);
