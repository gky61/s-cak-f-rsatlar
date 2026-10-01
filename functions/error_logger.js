const admin = require('firebase-admin');
const functions = require('firebase-functions');

// In-Memory Deduplication Cache (Fingerprint -> Timestamp)
// Aynı Cloud Function instance'ı içinde 2 dakika içinde gelen aynı hatayı tekilleştirir
const _dedupCache = new Map();
const DEDUP_TTL_MS = 120000; // 2 dakika

// Konteyner başına dakikalık Firestore log yazma tavanı (Kota ve Fatura Kalkanı)
let _writeWindowStart = Date.now();
let _writeCountInWindow = 0;
const MAX_WRITES_PER_WINDOW = 30; // Dakikada azami 30 Firestore yazması
const WINDOW_DURATION_MS = 60000;

/**
 * Dinamik parametreleri (UUID, Firestore ID, Sayılar) normalize ederek
 * deterministik ve mükerrer hatayı yakalayan parmak izi metni üretir.
 */
function normalizeForFingerprint(text) {
  if (!text) return '';
  return String(text)
    .replace(/[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}/g, '[UUID]')
    .replace(/\b[0-9a-zA-Z]{20}\b/g, '[DOC_ID]')
    .replace(/\b\d{4,}\b/g, '[NUM]')
    .trim();
}

/**
 * Metadata nesnesindeki gizli/hassas anahtarları maskeler
 */
const SENSITIVE_KEYS = new Set([
  'password', 'token', 'secret', 'authorization', 'cookie', 
  'apikey', 'api_key', 'accesstoken', 'idtoken', 'refreshtoken',
  'credential', 'bearer', 'privatekey', 'fcmtoken'
]);

/**
 * Metadata nesnesindeki gizli/hassas anahtarları maskeler
 */
function sanitizeMetadata(obj, depth = 0) {
  if (!obj || typeof obj !== 'object' || depth > 4) return obj;
  if (Array.isArray(obj)) {
    return obj.map(item => sanitizeMetadata(item, depth + 1));
  }
  const clean = {};
  for (const [key, value] of Object.entries(obj)) {
    const lowerKey = key.toLowerCase().replace(/[^a-z0-9]/g, '');
    let isSensitive = false;
    for (const sKey of SENSITIVE_KEYS) {
      if (lowerKey.includes(sKey)) {
        isSensitive = true;
        break;
      }
    }
    if (isSensitive) {
      clean[key] = '[REDACTED]';
    } else if (value && typeof value === 'object') {
      clean[key] = sanitizeMetadata(value, depth + 1);
    } else {
      clean[key] = value;
    }
  }
  return clean;
}

/**
 * Merkezi Cloud Functions Hata Kaydedici
 * Ortam bazlı (DEV vs PROD), kategorili, tekilleştirilmiş ve sıfır maliyet korumalı log kaydı üretir.
 */
async function logErrorToFirestore(service, errorType, message, stack, severity = 'error', options = {}) {
  try {
    const projectId = admin.app().options.projectId || process.env.GCLOUD_PROJECT || '';
    const environment = projectId.includes('prod') ? 'prod' : 'dev';
    
    const category = options.category || (service === 'functions' ? 'backend' : service);
    const subCategory = options.subCategory || null;
    const rawMetadata = options.metadata || {};
    const sanitizedMeta = sanitizeMetadata(rawMetadata);
    const userId = options.userId || sanitizedMeta.userId || sanitizedMeta.uid || options.uid || null;
    const userEmail = options.userEmail || sanitizedMeta.userEmail || sanitizedMeta.email || null;
    const VALID_SEVERITIES = new Set(['info', 'warning', 'error', 'fatal']);
    let safeSeverity = severity === 'critical' ? 'fatal' : (severity || 'error');
    if (!VALID_SEVERITIES.has(safeSeverity)) safeSeverity = 'error';

    const VALID_PLATFORMS = new Set(['android', 'ios', 'web', 'backend', 'bot']);
    let safePlatform = options.platform || sanitizedMeta.platform || (service === 'bot' ? 'bot' : (service === 'web' ? 'web' : 'backend'));
    if (!VALID_PLATFORMS.has(safePlatform)) safePlatform = 'backend';
    
    // 1. Konteyner Düzeyi Oran Sınırlaması (Rate Limiter - Fatura & Kota Kalkanı)
    const now = Date.now();
    if (now - _writeWindowStart > WINDOW_DURATION_MS) {
      _writeWindowStart = now;
      _writeCountInWindow = 0;
    }
    if (_writeCountInWindow >= MAX_WRITES_PER_WINDOW) {
      functions.logger.warn(`⚠️ [RateLimit] Cloud Function instance systemErrors kota kalkanı devrede (${_writeCountInWindow}/${MAX_WRITES_PER_WINDOW}). Firestore yazması atlandı.`);
      return;
    }

    // 2. Dinamik Parametreleri (UUID, ID, Sayılar) Normalize Edilmiş Parmak İzi
    const normalizedMsg = normalizeForFingerprint(message);
    const shortMsg = normalizedMsg.substring(0, 80);
    const fingerprint = `${service}_${category}_${errorType}_${shortMsg}`;
    
    // In-Memory Tekilleştirme Kontrolü (Kota ve Fatura Kalkanı)
    // Zamanı geçmiş kayıtları ara sıra temizle
    if (_dedupCache.size > 200) {
      for (const [fp, ts] of _dedupCache.entries()) {
        if (now - ts > DEDUP_TTL_MS) _dedupCache.delete(fp);
      }
      // Aşırı çeşitlilikte bellek sızıntısını (OOM) önleyici sert tavan (500)
      if (_dedupCache.size > 500) {
        const keys = Array.from(_dedupCache.keys()).slice(0, 250);
        keys.forEach(k => _dedupCache.delete(k));
      }
    }
    
    const lastLogged = _dedupCache.get(fingerprint);
    if (lastLogged && (now - lastLogged) < DEDUP_TTL_MS) {
      functions.logger.info(`ℹ️ Mükerrer hata Cloud Function önbelleğinde tekilleştirildi (Atlandı): ${fingerprint}`);
      return;
    }
    _dedupCache.set(fingerprint, now);
    _writeCountInWindow++;
    
    const writePromise = admin.firestore().collection('systemErrors').add({
      environment,
      service,
      category,
      ...(subCategory ? { subCategory } : {}),
      ...(userId ? { userId } : {}),
      ...(userEmail ? { userEmail } : {}),
      platform: safePlatform,
      errorType: String(errorType || 'UnknownError').substring(0, 100),
      message: String(message || '').substring(0, 500),
      stack: stack ? String(stack).substring(0, 2000) : null,
      status: 'unresolved',
      severity: safeSeverity,
      fingerprint,
      occurrenceCount: 1,
      metadata: {
        projectId,
        ...(userId ? { userId } : {}),
        ...(userEmail ? { userEmail } : {}),
        platform: safePlatform,
        ...sanitizedMeta
      },
      lastOccurredAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });

    const timeoutPromise = new Promise((_, reject) => 
      setTimeout(() => reject(new Error('systemErrors write timed out after 5s')), 5000)
    );

    await Promise.race([writePromise, timeoutPromise]);
    functions.logger.info(`💾 Log Firestore'a kaydedildi [${environment}]: [${service}] (${safeSeverity}) ${errorType}`);
  } catch (err) {
    functions.logger.error('❌ Log Firestore\'a kaydedilemedi:', err.message);
  }
}

module.exports = { logErrorToFirestore, sanitizeMetadata, normalizeForFingerprint };
