/**
 * FırsatKolik — Deals cleanUrl Veri Göçü (Migration) Betiği
 * 
 * Bu betik, Firestore veritabanındaki deals koleksiyonunu tarayarak,
 * her belgenin 'link' (veya 'url') alanını temizler ve 'cleanUrl' alanı oluşturur.
 * 
 * Çalıştırmak için: node functions/tests/migrate_deals_clean_url.js
 */

const admin = require('firebase-admin');
const isProd = process.argv.includes('--prod') || process.env.FIREBASE_ENV === 'prod';
const keyPath = isProd ? '../../cloud-run-bot/prod_firebase_key.json' : '../../cloud-run-bot/dev_firebase_key.json';
console.log(`🔌 Bağlanılan Ortam: ${isProd ? 'PROD (Canlı)' : 'DEV (Geliştirme)'}`);
const serviceAccount = require(keyPath);

// Firebase Admin initialization
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}
const db = admin.firestore();

// URL parametrelerini temizleyen fonksiyon
function cleanProductUrl(urlStr) {
  if (!urlStr || typeof urlStr !== 'string') return '';
  try {
    const url = new URL(urlStr.trim());
    const host = url.hostname.toLowerCase();
    
    const majorStores = [
      'amazon',
      'trendyol',
      'hepsiburada',
      'n11',
      'pazarama',
      'pttavm',
      'zara',
      'defacto',
      'mavi',
      'beymen',
      'teknosa',
      'mediamarkt',
      'migros',
      'getir',
      'vatanbilgisayar',
      'idefix',
      'itopya',
      'incehesap',
      'havit'
    ];
    
    let isMajorStore = false;
    for (const store of majorStores) {
      if (host.includes(store)) {
        isMajorStore = true;
        break;
      }
    }
    
    if (isMajorStore) {
      // Büyük mağazalar için query parametrelerini tamamen temizle
      url.search = '';
    } else {
      // Diğer mağazalar için sadece ürün kimlik parametrelerini koru, kalanları sil
      const paramsToKeep = ['id', 'productid', 'product_id', 'p', 'item_id', 'itemid', 'sku'];
      const keys = Array.from(url.searchParams.keys());
      for (const key of keys) {
        if (!paramsToKeep.includes(key.toLowerCase())) {
          url.searchParams.delete(key);
        }
      }
    }
    
    let result = url.toString();
    if (result.endsWith('?')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  } catch (e) {
    return urlStr;
  }
}

async function runMigration() {
  console.log('🚀 Fırsatlar için cleanUrl veri göçü başlatılıyor...');
  
  try {
    const dealsSnap = await db.collection('deals').get();
    console.log(`📊 Toplam ${dealsSnap.size} adet fırsat belgesi bulundu.`);

    let migratedCount = 0;
    let skippedCount = 0;
    let batch = db.batch();
    let opCount = 0;

    for (const doc of dealsSnap.docs) {
      const data = doc.data();
      const rawUrl = data.link || data.url || '';
      
      const newCleanUrl = cleanProductUrl(rawUrl);
      
      if (data.cleanUrl !== newCleanUrl) {
        batch.update(doc.ref, {
          cleanUrl: newCleanUrl,
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        });
        
        migratedCount++;
        opCount++;
        
        // Firestore batch sınırı 500
        if (opCount === 400) {
          console.log(`💾 400 belgelik kısmi göç kaydediliyor...`);
          await batch.commit();
          batch = db.batch();
          opCount = 0;
        }
      } else {
        skippedCount++;
      }
    }

    // Kalan işlemleri kaydet
    if (opCount > 0) {
      await batch.commit();
    }

    console.log(`\n🎉 Göç tamamlandı!`);
    console.log(`   ✅ Güncellenen Belge Sayısı: ${migratedCount}`);
    console.log(`   ⏭️ Atlanan/Zaten Güncel Olan Belge Sayısı: ${skippedCount}`);

  } catch (err) {
    console.error('❌ Göç sırasında hata oluştu:', err);
  } finally {
    process.exit(0);
  }
}

runMigration();
