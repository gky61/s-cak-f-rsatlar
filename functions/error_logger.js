const admin = require('firebase-admin');
const functions = require('firebase-functions');

/**
 * Merkezi Cloud Functions Hata Kaydedici
 * Ortam bazlı (DEV vs PROD), kategorili ve sıfır maliyet korumalı log kaydı üretir.
 */
async function logErrorToFirestore(service, errorType, message, stack, severity = 'error', options = {}) {
  try {
    const projectId = admin.app().options.projectId || process.env.GCLOUD_PROJECT || '';
    const environment = projectId.includes('prod') ? 'prod' : 'dev';
    
    const category = options.category || (service === 'functions' ? 'backend' : service);
    const subCategory = options.subCategory || null;
    const metadata = options.metadata || {};
    const userId = options.userId || metadata.userId || metadata.uid || options.uid || null;
    const userEmail = options.userEmail || metadata.userEmail || metadata.email || null;
    const platform = options.platform || metadata.platform || (service === 'bot' ? 'bot' : (service === 'web' ? 'web' : 'backend'));
    
    const shortMsg = (message || '').substring(0, 80);
    const fingerprint = `${service}_${category}_${errorType}_${shortMsg}`;
    
    await admin.firestore().collection('systemErrors').add({
      environment,
      service,
      category,
      ...(subCategory ? { subCategory } : {}),
      ...(userId ? { userId } : {}),
      ...(userEmail ? { userEmail } : {}),
      platform,
      errorType: String(errorType || 'UnknownError'),
      message: String(message || '').substring(0, 500),
      stack: stack ? String(stack).substring(0, 2000) : null,
      status: 'unresolved',
      severity: severity || 'error',
      fingerprint,
      occurrenceCount: 1,
      metadata: {
        projectId,
        ...(userId ? { userId } : {}),
        ...(userEmail ? { userEmail } : {}),
        platform,
        ...metadata
      },
      lastOccurredAt: admin.firestore.FieldValue.serverTimestamp(),
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    functions.logger.info(`💾 Log Firestore'a kaydedildi [${environment}]: [${service}] (${severity}) ${errorType}`);
  } catch (err) {
    functions.logger.error('❌ Log Firestore\'a kaydedilemedi:', err.message);
  }
}

module.exports = { logErrorToFirestore };
