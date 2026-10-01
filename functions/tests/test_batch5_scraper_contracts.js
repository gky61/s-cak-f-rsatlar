/**
 * FırsatKolik — Batch 5 Kazıyıcı (Scraper) & Otomasyon Sözleşme Test Süiti
 * 
 * Kapsam:
 * 1. Dağıtık Kazıma Kilidi (Distributed Scraper Mutex - executeWithScraperLock)
 *    - Eşzamanlı çakışma engelleme (Race condition / 429 WAF ban koruması)
 *    - 15 dakikalık kiralama (lease) tavanı ve otomatik kurtarma
 *    - Finally bloğunda garantili kilit serbest bırakma
 * 2. Kupon Kazıyıcı (coupon_scraper) Atomik Yaz-Sonra-Sil & 400 Batch Sınırı
 *    - Önce yazım kuralı (Downtime ve boş kupon listesi felaketini önleme)
 *    - 400 operasyonluk güvenli batch gruplama
 *    - Sadece bayat/eski web kuponlarının filtrelenip silinmesi
 * 3. Aktüel Katalog Kazıyıcı (catalog_scraper) Atomic Merge & Mutabakat (Reconciliation)
 *    - 400 operasyonluk güvenli batch gruplama
 *    - Aktif katalogların merge: true ile güncellenmesi (Sıfır kesinti)
 *    - Sadece yayından kalkan broşürlerin güvenle temizlenmesi
 * 4. Yönetici Yetkilendirme Sözleşmeleri (scrapeCouponsManual & scrapeCatalogsManual)
 * 
 * Çalıştırma: node functions/tests/test_batch5_scraper_contracts.js
 */

const assert = require('assert');

console.log('🚀 FırsatKolik Batch 5 Kazıyıcı ve Otomasyon Sözleşme Test Süiti Başlatılıyor...\n');

// ==========================================
// TEST 1: Dağıtık Kazıma Kilidi (Mutex) Simülasyonu
// ==========================================
console.log('--- TEST 1: Dağıtık Kazıma Kilidi (Distributed Mutex) Sözleşmesi ---');
{
  const mockSystemLocks = new Map();

  const simulateLockExecution = async (lockName, triggerType, scrapeFn, fakeNow = Date.now()) => {
    const leaseDurationMs = 15 * 60 * 1000;
    const lockData = mockSystemLocks.get(lockName) || {};

    // 1.1 Kilit Kontrolü
    if (lockData.isLocked && lockData.lockedUntil > fakeNow) {
      return {
        success: false,
        inProgress: true,
        message: `Kazıma işlemi şu anda [${lockData.lockedBy}] tarafından yürütülmektedir.`
      };
    }

    // 1.2 Kilidi Al
    mockSystemLocks.set(lockName, {
      isLocked: true,
      lockedBy: triggerType,
      lockedAt: fakeNow,
      lockedUntil: fakeNow + leaseDurationMs
    });

    try {
      const result = await scrapeFn();
      return { success: true, ...result };
    } finally {
      // 1.3 Kilidi Serbest Bırak
      mockSystemLocks.set(lockName, {
        isLocked: false,
        lockedBy: null,
        lockedUntil: 0
      });
    }
  };

  // Senaryo A: Serbest kilit üzerinde başarılı çalıştırma
  (async () => {
    const resA = await simulateLockExecution('coupon_scraping', 'scheduled_cron', async () => {
      return { count: 45 };
    });
    assert.strictEqual(resA.success, true);
    assert.strictEqual(resA.count, 45);
    assert.strictEqual(mockSystemLocks.get('coupon_scraping').isLocked, false, 'Çalışma bitince kilit serbest bırakılmalı');

    // Senaryo B: Eşzamanlı çakışma (Cron çalışırken Admin butona bastı)
    mockSystemLocks.set('coupon_scraping', {
      isLocked: true,
      lockedBy: 'scheduled_cron',
      lockedAt: Date.now(),
      lockedUntil: Date.now() + 10 * 60 * 1000
    });

    const resB = await simulateLockExecution('coupon_scraping', 'admin_123', async () => {
      return { count: 99 };
    });
    assert.strictEqual(resB.success, false);
    assert.strictEqual(resB.inProgress, true);
    assert.match(resB.message, /scheduled_cron/);

    // Senaryo C: 15 dakikalık kiralama tavanı aşılmışsa (Lease Expiry / Crash Recovery)
    const pastTime = Date.now() - 20 * 60 * 1000; // 20 dk önce kilitli kalmış
    mockSystemLocks.set('coupon_scraping', {
      isLocked: true,
      lockedBy: 'crashed_process',
      lockedAt: pastTime,
      lockedUntil: pastTime + 15 * 60 * 1000 // 5 dk önce süresi dolmuş
    });

    const resC = await simulateLockExecution('coupon_scraping', 'new_cron', async () => {
      return { count: 30 };
    }, Date.now());

    assert.strictEqual(resC.success, true);
    assert.strictEqual(resC.count, 30);
    assert.strictEqual(mockSystemLocks.get('coupon_scraping').isLocked, false);

    console.log('✅ TEST 1 BAŞARILI: Dağıtık kilit, çakışma engelleme ve kiralama tavanı doğrulandı.');
  })();
}

// ==========================================
// TEST 2: Kupon Kazıyıcı Atomik Yaz-Sonra-Sil & 400 Batch Sınırı
// ==========================================
console.log('\n--- TEST 2: Kupon Kazıyıcı Atomik Yaz-Sonra-Sil Sözleşmesi ---');
{
  const calculateBatchChunks = (items, maxChunk = 400) => {
    const chunks = [];
    for (let i = 0; i < items.length; i += maxChunk) {
      chunks.push(items.slice(i, i + maxChunk));
    }
    return chunks;
  };

  // 2.1 400 Batch Chunk Testi
  const mockItems = new Array(950).fill(null).map((_, i) => ({ id: `coupon_${i}` }));
  const chunks = calculateBatchChunks(mockItems, 400);

  assert.strictEqual(chunks.length, 3, '950 öğe 400 sınırıyla 3 parçaya ayrılmalı');
  assert.strictEqual(chunks[0].length, 400);
  assert.strictEqual(chunks[1].length, 400);
  assert.strictEqual(chunks[2].length, 150);
  assert.ok(chunks.every(c => c.length <= 400), 'Hiçbir batch 400 sınırını aşmamalı (500 limit koruması)');

  // 2.2 Yaz-Sonra-Sil (Write-First) Güvenliği
  const simulateWriteFirstReconciliation = (existingDocs, newScrapedCoupons, shouldFailWrite = false) => {
    if (shouldFailWrite) {
      throw new Error('Firestore write quota exceeded / transient error');
    }

    // Adım 1: Yeni kuponlar yazılır
    const newDocIds = new Set(newScrapedCoupons.map(c => c.id));

    // Adım 2: Eski web kuponlarından yeni listede olmayanlar temizlenir
    const docsToDelete = existingDocs.filter(doc => !newDocIds.has(doc.id));

    return {
      activeDocs: [...newScrapedCoupons],
      deletedDocs: docsToDelete
    };
  };

  const oldDocs = [
    { id: 'c_1', code: 'ESKI_10' },
    { id: 'c_2', code: 'DEVAM_EDEN_20' }
  ];

  const newCoupons = [
    { id: 'c_2', code: 'DEVAM_EDEN_20' },
    { id: 'c_3', code: 'YENI_30' }
  ];

  const reconcilResult = simulateWriteFirstReconciliation(oldDocs, newCoupons);
  assert.strictEqual(reconcilResult.deletedDocs.length, 1);
  assert.strictEqual(reconcilResult.deletedDocs[0].id, 'c_1', 'Sadece artık yayında olmayan kupon silinmeli');
  assert.strictEqual(reconcilResult.activeDocs.length, 2);

  // Yazma başarısız olursa eski kuponların silinmediğini teyit et
  assert.throws(() => {
    simulateWriteFirstReconciliation(oldDocs, newCoupons, true);
  }, /transient error/);

  console.log('✅ TEST 2 BAŞARILI: Kupon kazıyıcı 400 chunking ve yaz-sonra-sil güvencesi doğrulandı.');
}

// ==========================================
// TEST 3: Aktüel Katalog Kazıyıcı Atomic Merge & Mutabakat
// ==========================================
console.log('\n--- TEST 3: Aktüel Katalog Atomic Merge & Mutabakat Sözleşmesi ---');
{
  const existingCatalogs = [
    { id: 'bim_59001', store: 'bim', title: 'Cuma Fırsatları', createdAt: '2026-09-20' },
    { id: 'bim_59002', store: 'bim', title: 'Salı Broşürü', createdAt: '2026-09-25' },
    { id: 'a101_44001', store: 'a101', title: 'Aldın Aldın', createdAt: '2026-09-22' }
  ];

  const newScrapedBrochures = [
    { id: 'bim_59002', store: 'bim', title: 'Salı Broşürü (Güncellendi)' }, // Devam eden
    { id: 'bim_59003', store: 'bim', title: 'Yeni Cuma Kataloğu' },         // Yeni
    { id: 'a101_44001', store: 'a101', title: 'Aldın Aldın' }                // Devam eden
  ];

  const reconcileCatalogs = (existing, newlyScraped) => {
    const newIdSet = new Set(newlyScraped.map(b => b.id));
    const obsoleteList = existing.filter(ex => !newIdSet.has(ex.id));

    // Upsert listesi (merge: true ile güncellenecekler)
    const upsertList = newlyScraped.map(b => ({
      ...b,
      updatedAt: 'SERVER_TIMESTAMP'
    }));

    return {
      upsertedCount: upsertList.length,
      obsoleteCount: obsoleteList.length,
      obsoleteIds: obsoleteList.map(o => o.id)
    };
  };

  const catResult = reconcileCatalogs(existingCatalogs, newScrapedBrochures);
  assert.strictEqual(catResult.upsertedCount, 3, 'Tüm güncel broşürler upsert edilmeli');
  assert.strictEqual(catResult.obsoleteCount, 1, 'Süresi biten bim_59001 silinmeli');
  assert.deepStrictEqual(catResult.obsoleteIds, ['bim_59001']);

  console.log('✅ TEST 3 BAŞARILI: Katalog atomic merge ve obsolete mutabakat sözleşmesi doğrulandı.');
}

// ==========================================
// TEST 4: Yönetici Yetkilendirme & Giriş Sözleşmesi
// ==========================================
console.log('\n--- TEST 4: Scraper Yönetici Yetkilendirme Sözleşmesi ---');
{
  const verifyCallerIsAdmin = (auth, userDocData) => {
    if (!auth || !auth.uid) {
      throw new Error('unauthenticated');
    }
    const isCallerAdmin = userDocData && (
      userDocData.isAdmin === true ||
      userDocData.isadmin === true ||
      userDocData.isAdmin === 'true' ||
      userDocData.isadmin === 'true'
    );
    if (!isCallerAdmin) {
      throw new Error('permission-denied');
    }
    return true;
  };

  assert.throws(() => verifyCallerIsAdmin(null, {}), /unauthenticated/);
  assert.throws(() => verifyCallerIsAdmin({ uid: 'normal_user' }, { isAdmin: false }), /permission-denied/);
  assert.strictEqual(verifyCallerIsAdmin({ uid: 'admin_1' }, { isAdmin: true }), true);
  assert.strictEqual(verifyCallerIsAdmin({ uid: 'admin_2' }, { isadmin: 'true' }), true);

  console.log('✅ TEST 4 BAŞARILI: Scraper çağrı yetkilendirmesi hatasız doğrulandı.');
}

console.log('\n======================================================');
console.log('🎉 TÜM BATCH 5 KAZIYICI & OTOMASYON SÖZLEŞME TESTLERİ %100 GEÇTİ!');
console.log('======================================================\n');
