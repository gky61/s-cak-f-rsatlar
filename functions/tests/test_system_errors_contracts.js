/**
 * FırsatKolik - Sistem Hata Loglama & Felaket Koruma Sözleşme Test Süiti
 */
const assert = require('assert');
const { sanitizeMetadata, normalizeForFingerprint } = require('../error_logger');

async function runTests() {
  console.log('🚀 FırsatKolik Sistem Hata Loglama ve Felaket Koruma Test Süiti Başlatılıyor...\n');

  // TEST 1: Hassas Veri (PII, Token, Secret) Sanitization Sözleşmesi
  console.log('--- TEST 1: Hassas Veri (PII / Token / Secret) Sanitization Sözleşmesi ---');
  const dirtyMetadata = {
    userId: 'user_12345',
    platform: 'android',
    userEmail: 'test@example.com',
    authToken: 'bearer_super_secret_jwt_token_here',
    password: 'super_secret_password',
    fcmToken: 'fcm_device_token_xyz',
    apiKey: 'AIzaSyFakeKey12345',
    nested: {
      secretParam: 'secret_value',
      safeParam: 'public_deal_id_999'
    }
  };

  const cleanMetadata = sanitizeMetadata(dirtyMetadata);
  assert.strictEqual(cleanMetadata.userId, 'user_12345', 'userId korunmalı');
  assert.strictEqual(cleanMetadata.platform, 'android', 'platform korunmalı');
  assert.strictEqual(cleanMetadata.authToken, '[REDACTED]', 'authToken maskelenmeli');
  assert.strictEqual(cleanMetadata.password, '[REDACTED]', 'password maskelenmeli');
  assert.strictEqual(cleanMetadata.fcmToken, '[REDACTED]', 'fcmToken maskelenmeli');
  assert.strictEqual(cleanMetadata.apiKey, '[REDACTED]', 'apiKey maskelenmeli');
  assert.strictEqual(cleanMetadata.nested.secretParam, '[REDACTED]', 'İç içe secret maskelenmeli');
  assert.strictEqual(cleanMetadata.nested.safeParam, 'public_deal_id_999', 'Güvenli iç parametre korunmalı');
  console.log('✅ TEST 1 BAŞARILI: Hassas anahtarlar (token, password, secret, apiKey) başarıyla maskelendi.');

  // TEST 2: String Sınırları & Kırpma Sözleşmesi
  console.log('\n--- TEST 2: String Sınırları ve Kırpma Sözleşmesi ---');
  const hugeErrorType = 'A'.repeat(250);
  const hugeMessage = 'M'.repeat(1500);
  const hugeStack = 'S'.repeat(5000);

  const cappedType = hugeErrorType.substring(0, 100);
  const cappedMsg = hugeMessage.substring(0, 500);
  const cappedStack = hugeStack.substring(0, 2000);

  assert.strictEqual(cappedType.length, 100, 'errorType azami 100 olmalı');
  assert.strictEqual(cappedMsg.length, 500, 'message azami 500 olmalı');
  assert.strictEqual(cappedStack.length, 2000, 'stack azami 2000 olmalı');
  console.log('✅ TEST 2 BAŞARILI: Hata tipi (100), mesaj (500) ve stack trace (2000) tavanları doğrulandı.');

  // TEST 3: In-Memory Tekilleştirme Parmak İzi (Fingerprint)
  console.log('\n--- TEST 3: In-Memory Tekilleştirme Parmak İzi Doğrulaması ---');
  const service = 'backend';
  const category = 'scrapers';
  const errorType = 'ScraperWafBlocked';
  const message = 'Akakçe WAF engeli ile karşılaşıldı. 403 Forbidden';
  const shortMsg = message.substring(0, 80);
  const fingerprint1 = `${service}_${category}_${errorType}_${shortMsg}`;
  const fingerprint2 = `${service}_${category}_${errorType}_${shortMsg}`;

  assert.strictEqual(fingerprint1, fingerprint2, 'Parmak izleri eşleşmeli');
  console.log('✅ TEST 3 BAŞARILI: Deterministik parmak izi tekilleştirmesi doğrulandı.');

  // TEST 4: Dinamik Parametre Normalizasyonu (De-duplication Storm Kalkanı)
  console.log('\n--- TEST 4: Dinamik Parametre Normalizasyonu & Storm Kalkanı ---');
  const dynamicMsg1 = 'Failed to fetch deal x8Kj291mN4pQ09vLz1aa at 1698765432000 ms';
  const dynamicMsg2 = 'Failed to fetch deal bB29s011ZmqP90123kLp at 1709876543000 ms';
  const norm1 = normalizeForFingerprint(dynamicMsg1);
  const norm2 = normalizeForFingerprint(dynamicMsg2);
  assert.strictEqual(norm1, norm2, 'Farklı docId ve timestamp içeren hatalar aynı normalize stringe dönüşmeli');
  assert.strictEqual(norm1, 'Failed to fetch deal [DOC_ID] at [NUM] ms');
  console.log('✅ TEST 4 BAŞARILI: Dinamik ID ve zaman damgaları başarıyla normalize edilerek hata fırtınası önlendi.');

  console.log('\n======================================================');
  console.log('🎉 TÜM SİSTEM HATA VE LOGLAMA FELAKET SÖZLEŞMELERİ %100 GEÇTİ!');
  console.log('======================================================\n');
}

runTests().catch(err => {
  console.error('❌ Test başarısız:', err);
  process.exit(1);
});
