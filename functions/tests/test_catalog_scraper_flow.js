const admin = require('firebase-admin');
const { scrapeAndSaveCatalogs } = require('../catalog_scraper');

if (!admin.apps.length) {
  admin.initializeApp();
}

async function runTest() {
  console.log('🧪 Starting test for scrapeAndSaveCatalogs()...');
  try {
    const result = await scrapeAndSaveCatalogs();
    console.log('RESULT:', JSON.stringify(result, null, 2));
  } catch (err) {
    console.error('TEST ERROR:', err);
  }
}

runTest();
