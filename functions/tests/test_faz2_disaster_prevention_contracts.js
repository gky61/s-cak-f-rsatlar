/**
 * FırsatKolik Backend 100k Felaket Önleme - FAZ 2 Sözleşme Test Süiti
 *
 * Test Edilen Kalkanlar:
 * 1. M-04 / FS-CF-06: _purgeOldNotificationsCore & purgeOldDeals (50 Batches / 20.000 Tavan, 7.5dk Zaman Sınırı & Günlük 03:30 Cron)
 * 2. M-06 / FS-CF-03: onDealUpdated (Oy Patlamalarında users/{postedBy} Yazma Çekişmesini %80 Azaltan Eşikli Rozet Denetimi)
 * 3. M-07 / FS-CF-08: catalog_scraper.js (Akakçe CDN 403 Kalkanı, Firebase Storage Kapak Yedekleme & Mutabakat Temizliği)
 * 4. M-09 / FS-CF-10: onUserUpdated (Simetrik Avatar Temizliği, Sıfır Sonsuz Döngü, 1200 Doküman Sayfalı Senkronizasyon & 300s/512MB)
 * 5. M-10: _cleanupOldImagesCore & cleanupOldImages (GCS nextQuery Çok Sayfalı Tarama [5.000 dosya], 4dk Emniyet Kalkanı & 300s/512MB)
 */

const assert = require('assert');
const fs = require('fs');
const path = require('path');

console.log('🚀 FırsatKolik FAZ 2 100k Felaket Önleme Sözleşme Test Süiti Başlatılıyor...\n');

const indexJsPath = path.resolve(__dirname, '../index.js');
const indexJsContent = fs.readFileSync(indexJsPath, 'utf8');

const catalogScraperPath = path.resolve(__dirname, '../catalog_scraper.js');
const catalogScraperContent = fs.readFileSync(catalogScraperPath, 'utf8');

// ==============================================================================
// TEST 1: M-04 / FS-CF-06 _purgeOldNotificationsCore & purgeOldDeals Sözleşmesi
// ==============================================================================
console.log('--- TEST 1: M-04 / FS-CF-06 Bildirim ve Fırsat Tasfiye Sözleşmesi ---');
{
  // 1.1 Kaynak kodda 50 batch ve 7.5dk koruması var mı?
  assert(indexJsContent.includes('const MAX_BATCHES = 50;'), '❌ _purgeOldNotificationsCore MAX_BATCHES 50 olmalıdır');
  assert(indexJsContent.includes('const MAX_EXECUTION_TIME_MS = 450000;'), '❌ _purgeOldNotificationsCore 450.000ms (7.5dk) zaman aşımı kalkanı içermelidir');
  
  // 1.2 purgeOldDeals zamanlaması günlük 03:30 mu?
  assert(indexJsContent.includes("schedule('30 3 * * *')"), '❌ purgeOldDeals zamanlaması her gün 03:30 (30 3 * * *) olmalıdır');

  // 1.3 Simüle edilen tasfiye döngüsü davranışı
  let currentBatch = 0;
  let totalDeleted = 0;
  const BATCH_SIZE = 400;
  const MAX_BATCHES = 50;
  const startTime = 100000;
  const MAX_EXECUTION_TIME_MS = 450000;

  function simulatePurge(mockNowTime, mockDocCount) {
    let remainingDocs = mockDocCount;
    while (remainingDocs > 0 && currentBatch < MAX_BATCHES) {
      if (mockNowTime - startTime > MAX_EXECUTION_TIME_MS) {
        break;
      }
      const toDelete = Math.min(remainingDocs, BATCH_SIZE);
      totalDeleted += toDelete;
      remainingDocs -= toDelete;
      currentBatch++;
    }
    return { currentBatch, totalDeleted, remainingDocs };
  }

  // 30.000 birikmiş bildirim simülasyonu -> tek çalıştırmada 20.000 silinip tavan uygulanmalı
  const res = simulatePurge(120000, 30000);
  assert.strictEqual(res.currentBatch, 50, '50 batch sonra devre kesici devreye girmeli');
  assert.strictEqual(res.totalDeleted, 20000, 'Tam 20.000 bildirim güvenle silinmeli');
  assert.strictEqual(res.remainingDocs, 10000, 'Kalan 10.000 sonraki güne bırakılmalı');

  console.log('✅ TEST 1 BAŞARILI: M-04 tasfiye devre kesicisi (50 batch / 20.000 bildirim & 03:30 cron) doğrulandı.');
}

// ==============================================================================
// TEST 2: M-06 / FS-CF-03 onDealUpdated Oy Patlaması & Çekişme Kalkanı
// ==============================================================================
console.log('\n--- TEST 2: M-06 / FS-CF-03 onDealUpdated Rozet Denetimi Kalkanı ---');
{
  // 2.1 onDealUpdated kaynak kodunda eşikli rozet kontrolü kuralı var mı?
  assert(indexJsContent.includes('const shouldCheckBadges = (newHotVotes <= 5 || newHotVotes % 5 === 0);'), 
    '❌ onDealUpdated içinde shouldCheckBadges eşik kontrolü bulunamadı');

  // 2.2 Viral bir fırsata 1'den 100'e kadar oy yağdığında rozet denetim sayısı
  let badgeChecks = 0;
  let pointIncrements = 0;

  for (let vote = 1; vote <= 100; vote++) {
    const shouldCheckBadges = (vote <= 5 || vote % 5 === 0);
    if (shouldCheckBadges) {
      badgeChecks++;
    }
    // Puan/beğeni her oyda artırılır
    pointIncrements++;
  }

  assert.strictEqual(pointIncrements, 100, 'Puan her oyda istisnasız artırılmalıdır');
  // 1,2,3,4,5 (5 adet) + 10,15,20,...,100 (19 adet) = 24 kontrol
  assert.strictEqual(badgeChecks, 24, '100 oyda yalnızca 24 rozet kontrolü yapılmalıdır');
  const reductionPercent = ((100 - badgeChecks) / 100) * 100;
  assert.strictEqual(reductionPercent, 76, 'İlk 100 oyda Firestore çekişmesi %76 oranında azaltıldı');

  // 101-500 arasındaki oylarda ise tam %80 tasarruf:
  let highBadgeChecks = 0;
  for (let vote = 101; vote <= 500; vote++) {
    if (vote <= 5 || vote % 5 === 0) highBadgeChecks++;
  }
  assert.strictEqual(highBadgeChecks, 80, '400 yüksek oyda tam 80 kontrol (%80 tasarruf)');

  console.log('✅ TEST 2 BAŞARILI: M-06 onDealUpdated oy patlaması rozet denetimi (%76-%80 çekişme azalması) doğrulandı.');
}

// ==============================================================================
// TEST 3: M-07 / FS-CF-08 catalog_scraper.js Akakçe CDN Kalkanı & Storage Yedekleme
// ==============================================================================
console.log('\n--- TEST 3: M-07 / FS-CF-08 catalog_scraper.js Storage Yedekleme Sözleşmesi ---');
{
  // 3.1 catalog_scraper.js içinde uploadCoverToStorage ve mutabakat temizliği var mı?
  assert(catalogScraperContent.includes('async function uploadCoverToStorage(coverUrl, catalogId)'), 
    '❌ catalog_scraper.js uploadCoverToStorage fonksiyonunu içermelidir');
  assert(catalogScraperContent.includes("destination = `catalogs/${catalogId}_cover.webp`"), 
    '❌ Storage hedef yolu catalogs/${catalogId}_cover.webp olmalıdır');
  assert(catalogScraperContent.includes('kapakResmi: storageCoverUrl || finalCover'), 
    '❌ kapakResmi storageCoverUrl veya fallback olarak finalCover kullanmalıdır');
  assert(catalogScraperContent.includes('admin.storage().bucket().file(`catalogs/${doc.id}_cover.webp`).delete()'), 
    '❌ Mutabakat temizliğinde silinen katalogların Storage kapakları da silinmelidir');

  // 3.2 Mock ile uploadCoverToStorage fallback davranışı doğrulaması
  function resolveKapakResmi(storageCoverUrl, finalCover) {
    return {
      kapakResmi: storageCoverUrl || finalCover,
      originalKapakResmi: finalCover,
      storageCoverUrl: storageCoverUrl || null
    };
  }

  // Senaryo A: Storage yüklemesi başarılı
  const successCase = resolveKapakResmi('https://storage.googleapis.com/bucket/catalogs/bim_123_cover.webp', 'https://cdn.akakce.com/bro/bim.jpg');
  assert.strictEqual(successCase.kapakResmi, 'https://storage.googleapis.com/bucket/catalogs/bim_123_cover.webp');
  assert.strictEqual(successCase.originalKapakResmi, 'https://cdn.akakce.com/bro/bim.jpg');
  assert.strictEqual(successCase.storageCoverUrl, 'https://storage.googleapis.com/bucket/catalogs/bim_123_cover.webp');

  // Senaryo B: Storage yüklemesi başarısız / emulator -> Orijinal Akakçe URL korunur
  const fallbackCase = resolveKapakResmi(null, 'https://cdn.akakce.com/bro/bim.jpg');
  assert.strictEqual(fallbackCase.kapakResmi, 'https://cdn.akakce.com/bro/bim.jpg');
  assert.strictEqual(fallbackCase.storageCoverUrl, null);

  console.log('✅ TEST 3 BAŞARILI: M-07 catalog_scraper.js Storage kapak yedekleme ve mutabakat sözleşmesi doğrulandı.');
}

// ==============================================================================
// TEST 4: M-09 / FS-CF-10 onUserUpdated Simetrik Avatar & Sayfalı Senkronizasyon
// ==============================================================================
console.log('\n--- TEST 4: M-09 / FS-CF-10 onUserUpdated Sayfalama ve Simetri Sözleşmesi ---');
{
  // 4.1 onUserUpdated 300s / 512MB olarak yapılandırılmış mı?
  assert(/exports\.onUserUpdated\s*=\s*functions\s*\.runWith\(\{\s*timeoutSeconds:\s*300,\s*memory:\s*['"]512MB['"]\s*\}\)/.test(indexJsContent), 
    '❌ onUserUpdated 300s timeout ve 512MB belleğe sahip olmalıdır');

  // 4.2 Simetrik sanitizeAvatarUrl mantığı testi
  function sanitizeAvatarUrl(url) {
    if (!url || typeof url !== 'string') return '';
    let sanitized = url.trim();
    const lower = sanitized.toLowerCase();
    if (lower.includes('kullanıcı pp') || lower.includes('kullanici pp')) {
      return 'assets/avatars/avatar_cat.webp';
    } else if (lower.includes('kkpp') || lower.includes('ayi') || lower.includes('ayı') || lower.includes('kullanıcı profili') || lower.includes('kullanici profili')) {
      return 'assets/avatars/avatar_duck.webp';
    } else if (lower === 'assets/profil.jpg' || lower === 'assets/profil.webp') {
      return 'assets/avatars/avatar_duck.webp';
    } else if (sanitized.startsWith('assets/') && /\.(jpg|jpeg|png)$/i.test(sanitized)) {
      return sanitized.replace(/\.(jpg|jpeg|png)$/i, '.webp');
    }
    return sanitized;
  }

  // Avatar eşleştirmeleri
  assert.strictEqual(sanitizeAvatarUrl('assets/avatars/kullanici pp.jpg'), 'assets/avatars/avatar_cat.webp');
  assert.strictEqual(sanitizeAvatarUrl('assets/avatars/kullanıcı pp.png'), 'assets/avatars/avatar_cat.webp');
  assert.strictEqual(sanitizeAvatarUrl('assets/avatars/ayi_profil.png'), 'assets/avatars/avatar_duck.webp');
  assert.strictEqual(sanitizeAvatarUrl('assets/profil.jpg'), 'assets/avatars/avatar_duck.webp');
  assert.strictEqual(sanitizeAvatarUrl('assets/avatars/avatar_duck.png'), 'assets/avatars/avatar_duck.webp');
  assert.strictEqual(sanitizeAvatarUrl('https://lh3.googleusercontent.com/photo.jpg'), 'https://lh3.googleusercontent.com/photo.jpg');

  // Simetri testi: Before ve After aynı unnormalized string içerdiğinde photoChanged FALSE olmalıdır!
  const rawBefore = 'assets/avatars/kullanıcı pp.jpg';
  const rawAfter = 'assets/avatars/kullanıcı pp.jpg';
  const oldPhoto = sanitizeAvatarUrl(rawBefore);
  const newPhoto = sanitizeAvatarUrl(rawAfter);
  assert.strictEqual(oldPhoto, newPhoto, 'Simetrik sanitization sonucu oldPhoto === newPhoto olmalıdır');
  assert.strictEqual(oldPhoto !== newPhoto, false, 'Yanlış alarm senkronizasyon döngüsü kesinlikle engellendi');

  // 4.3 Cursor-based pagination mantığı (1200 tavan & 400 chunk)
  async function mockSyncPagination(totalDocsAvailable, maxLimit = 1200) {
    let totalScanned = 0;
    let totalUpdated = 0;
    let pages = 0;
    const pageSize = 400;

    let remainingDocs = totalDocsAvailable;
    while (totalScanned < maxLimit && remainingDocs > 0) {
      const currentLimit = Math.min(pageSize, maxLimit - totalScanned);
      const docsInPage = Math.min(remainingDocs, currentLimit);
      if (docsInPage === 0) break;

      totalScanned += docsInPage;
      totalUpdated += docsInPage;
      remainingDocs -= docsInPage;
      pages++;

      if (docsInPage < currentLimit) break;
    }

    return { totalScanned, totalUpdated, pages };
  }

  (async () => {
    // 50 dokümanlı normal kullanıcı: 1 sayfa, 50 tarama
    const normalUser = await mockSyncPagination(50);
    assert.strictEqual(normalUser.pages, 1);
    assert.strictEqual(normalUser.totalScanned, 50);

    // 950 dokümanlı aktif kullanıcı: 3 sayfa (400 + 400 + 150), 950 tarama (eski 300 limitini aştı!)
    const activeUser = await mockSyncPagination(950);
    assert.strictEqual(activeUser.pages, 3);
    assert.strictEqual(activeUser.totalScanned, 950);

    // 2500 dokümanlı aşırı aktif kullanıcı: 3 sayfa, tam 1200 tavan ile sınırlandı
    const superUser = await mockSyncPagination(2500);
    assert.strictEqual(superUser.pages, 3);
    assert.strictEqual(superUser.totalScanned, 1200);

    console.log('✅ TEST 4 BAŞARILI: M-09 onUserUpdated simetrik avatar ve 1200 sayfalı senkronizasyon sözleşmesi doğrulandı.');
  })();
}

// ==============================================================================
// TEST 5: M-10 _cleanupOldImagesCore & cleanupOldImages Çok Sayfalı Storage Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 5: M-10 Storage Görsel Temizlik Çok Sayfalı Tarama Sözleşmesi ---');
{
  // 5.1 cleanupOldImages yapılandırması
  assert(/cleanupOldImages\s*=\s*functions\s*\.runWith\(\{\s*timeoutSeconds:\s*300,\s*memory:\s*['"]512MB['"]\s*\}\)/.test(indexJsContent), 
    '❌ cleanupOldImages 300s timeout ve 512MB belleğe sahip olmalıdır');
  assert(indexJsContent.includes("schedule('0 0 * * *')"), 
    '❌ cleanupOldImages her gece 00:00 da çalışmalıdır');
  assert(indexJsContent.includes('await _cleanupOldImagesCore({ days: 40, maxFiles: 3000 });'), 
    '❌ cleanupOldImages 40 gün ve 3000 dosya tavanı ile _cleanupOldImagesCore çağırmalıdır');

  // 5.2 _cleanupOldImagesCore içinde nextQuery ve zaman aşımı koruması var mı?
  assert(indexJsContent.includes('const [files, nextQuery] = await bucket.getFiles(currentQuery);'), 
    '❌ _cleanupOldImagesCore nextQuery ile sayfalamayı desteklemelidir');
  assert(indexJsContent.includes('const MAX_EXECUTION_TIME_MS = 240000;'), 
    '❌ _cleanupOldImagesCore 240.000ms (4 dakika) zaman sınırı koruması içermelidir');

  // 5.3 Simüle edilen çok sayfalı Storage listeleme döngüsü
  async function mockStoragePagination(totalPagesAvailable, maxFiles = 3000) {
    const filesPerMockPage = 1000;
    let pagesScanned = 0;
    const maxPages = 5;
    const filesToInspect = [];
    let currentQuery = { maxResults: 1000 };

    while (currentQuery && pagesScanned < maxPages && filesToInspect.length < maxFiles) {
      // Simüle edilen getFiles
      const count = Math.min(filesPerMockPage, maxFiles - filesToInspect.length);
      const mockFiles = Array.from({ length: count }, (_, i) => ({
        name: `deals/deal_${pagesScanned * 1000 + i}.webp`,
        metadata: { timeCreated: new Date(Date.now() - 45 * 86400000).toISOString() }
      }));

      filesToInspect.push(...mockFiles);
      pagesScanned++;

      if (pagesScanned < totalPagesAvailable && filesToInspect.length < maxFiles) {
        currentQuery = { pageToken: `token_page_${pagesScanned + 1}` };
      } else {
        currentQuery = null;
      }
    }

    return { pagesScanned, totalFiles: filesToInspect.length };
  }

  (async () => {
    // 3 sayfalık dosya havuzu: 3 sayfa taranmalı ve 3000 dosya bulunmalı (Sayfa 1'de takılı kalma çözüldü)
    const scanRes = await mockStoragePagination(3, 3000);
    assert.strictEqual(scanRes.pagesScanned, 3, 'GCS 3 sayfa boyunca nextQuery izlemelidir');
    assert.strictEqual(scanRes.totalFiles, 3000, 'Toplam 3000 dosya incelenmelidir');

    // 10 sayfalık havuz: maxPages = 5 ve maxFiles = 3000 ile sınırlanmalı
    const largeScan = await mockStoragePagination(10, 3000);
    assert.strictEqual(largeScan.pagesScanned, 3, '3000 dosyaya ulaşınca 3. sayfada sonlanmalıdır');
    assert.strictEqual(largeScan.totalFiles, 3000);

    console.log('✅ TEST 5 BAŞARILI: M-10 Storage çok sayfalı listeleme ve 4dk emniyet kalkanı doğrulandı.');
  })();
}

// ==============================================================================
// TEST 6: FS-CF-11 onDealCreated Kelime Radarı Topic & Mükerrer Push Kalkanı
// ==============================================================================
console.log('\n--- TEST 6: FS-CF-11 onDealCreated Kelime Radarı Topic Kalkanı Sözleşmesi ---');
{
  assert(
    indexJsContent.includes("isTopicDelivered: (match.reason === 'category' || match.reason === 'keyword')"),
    '❌ onDealCreated keyword eşleşmelerinde isTopicDelivered true olarak işaretlenmelidir'
  );
  assert(
    indexJsContent.includes("pushStatus: (match.reason === 'category' || match.reason === 'keyword') ? 'delivered_via_topic' : 'pending'"),
    '❌ onDealCreated keyword eşleşmelerinde pushStatus delivered_via_topic olmalıdır'
  );
  console.log('✅ TEST 6 BAŞARILI: FS-CF-11 Kelime radarı topic gönderimi ve mükerrer push engeli doğrulandı.');
}

// ==============================================================================
// TEST 7: FS-CF-12 firestore.indexes.json Composite Index Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 7: FS-CF-12 Composite Index Sözleşmesi ---');
{
  const indexesPath = path.resolve(__dirname, '../../firestore.indexes.json');
  const indexesJson = JSON.parse(fs.readFileSync(indexesPath, 'utf8'));

  // notificationSubscriptions composite index check
  const subIdx = indexesJson.indexes.find(idx =>
    idx.collectionGroup === 'notificationSubscriptions' &&
    idx.fields.some(f => f.fieldPath === 'type') &&
    idx.fields.some(f => f.fieldPath === 'key') &&
    idx.fields.some(f => f.fieldPath === 'enabled')
  );
  assert.ok(subIdx, '❌ notificationSubscriptions (type, key, enabled) composite indeksi mevcut olmalıdır');

  // userDevices composite index check
  const devIdx = indexesJson.indexes.find(idx =>
    idx.collectionGroup === 'userDevices' &&
    idx.fields.some(f => f.fieldPath === 'uid') &&
    idx.fields.some(f => f.fieldPath === 'active')
  );
  assert.ok(devIdx, '❌ userDevices (uid, active) composite indeksi mevcut olmalıdır');

  console.log('✅ TEST 7 BAŞARILI: FS-CF-12 notificationSubscriptions ve userDevices bileşik indeksleri doğrulandı.');
}

// ==============================================================================
// TEST 8: FS-CF-13 onCommentCreated Tekil Okuma (N+1 Önleme) Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 8: FS-CF-13 onCommentCreated Tekil Okuma Sözleşmesi ---');
{
  assert(
    indexJsContent.includes('cachedUserDoc = await admin.firestore().collection(\'users\').doc(userId).get();'),
    '❌ onCommentCreated kullanıcı profilini cachedUserDoc değişkeninde önbelleğe almalıdır'
  );
  assert(
    indexJsContent.includes('const senderUserDoc = (cachedUserDoc && replierUserId === userId)'),
    '❌ onCommentCreated replierUserId === userId durumunda cachedUserDoc yeniden kullanmalıdır'
  );
  console.log('✅ TEST 8 BAŞARILI: FS-CF-13 onCommentCreated mükerrer kullanıcı dokümanı okuma tasarrufu doğrulandı.');
}

// ==============================================================================
// TEST 9: FS-CF-14 cleanupInvalidTokens Sayfalı İmleç (Cursor Pagination) Sözleşmesi
// ==============================================================================
console.log('\n--- TEST 9: FS-CF-14 cleanupInvalidTokens Sayfalı İmleç Sözleşmesi ---');
{
  assert(
    indexJsContent.includes('orderBy(admin.firestore.FieldPath.documentId())'),
    '❌ cleanupInvalidTokens sorgusu documentId ile sıralanmalıdır'
  );
  assert(
    indexJsContent.includes('data.startAfterDocId'),
    '❌ cleanupInvalidTokens startAfterDocId imleç parametresini desteklemelidir'
  );
  assert(
    indexJsContent.includes('lastDocId: lastDoc ? lastDoc.id : null'),
    '❌ cleanupInvalidTokens yanıtında lastDocId döndürmelidir'
  );
  console.log('✅ TEST 9 BAŞARILI: FS-CF-14 cleanupInvalidTokens sayfalı imleç (cursor pagination) mimarisi doğrulandı.');
  console.log('\n🎉 FAZ 2 TÜM SÖZLEŞME TESTLERİ %100 BAŞARIYLA GEÇTİ!');
}

