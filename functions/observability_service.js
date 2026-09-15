const admin = require('firebase-admin');
const functions = require('firebase-functions');
let BetaAnalyticsDataClient;
try {
  BetaAnalyticsDataClient = require('@google-analytics/data').BetaAnalyticsDataClient;
} catch (_) {
  BetaAnalyticsDataClient = null;
}

/**
 * FırsatKolik Observability Backend Servisi (Modül 11)
 * GA4 Data API ve Firestore verilerini güvenli bir şekilde Web Admin için birleştirir.
 */
async function getObservabilityMetricsHandler(data = {}, context = {}) {
  // 1. Admin Yetki Doğrulaması
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Bu verileri görüntülemek için giriş yapmalısınız.');
  }

  const callerUid = context.auth.uid;
  const userDoc = await admin.firestore().collection('users').doc(callerUid).get();
  const userData = userDoc.exists ? userDoc.data() : {};
  const isAdmin = userData.role === 'admin' || userData.isAdmin === true || context.auth.token?.admin === true;

  if (!isAdmin) {
    throw new functions.https.HttpsError('permission-denied', 'Bu işlem için süper yönetici (admin) yetkisi gereklidir.');
  }

  const projectId = admin.app().options.projectId || process.env.GCLOUD_PROJECT || '';
  const isProd = projectId.includes('prod');
  const environment = isProd ? 'prod' : 'dev';

  // 2. GA4 Data API Sorguları (Opsiyonel / Graceful Fallback Korumalı)
  const ga4PropertyId = (data && data.propertyId) || process.env.GA4_PROPERTY_ID || '';
  let ga4Result = {
    connected: false,
    propertyId: ga4PropertyId,
    activeUsers: 0,
    realtimeEvents: [],
    events24h: {
      deal_outbound_click: 0,
      deal_view: 0,
      coupon_copied: 0,
      catalog_view: 0,
      search_performed: 0
    },
    message: 'GA4 Property ID henüz tanımlanmadı veya API yetkisi bekleniyor.'
  };

  if (BetaAnalyticsDataClient && ga4PropertyId) {
    try {
      const analyticsClient = new BetaAnalyticsDataClient();

      // Anlık Gerçek Zamanlı Rapor (Son 30 dakika)
      const [realtimeResponse] = await analyticsClient.runRealtimeReport({
        property: `properties/${ga4PropertyId}`,
        metrics: [{ name: 'activeUsers' }, { name: 'eventCount' }],
        dimensions: [{ name: 'eventName' }]
      });

      let totalActive = 0;
      const realtimeEvents = [];

      if (realtimeResponse && realtimeResponse.rows) {
        realtimeResponse.rows.forEach(row => {
          const eventName = row.dimensionValues?.[0]?.value || '';
          const users = parseInt(row.metricValues?.[0]?.value || '0', 10);
          const count = parseInt(row.metricValues?.[1]?.value || '0', 10);
          totalActive = Math.max(totalActive, users);
          realtimeEvents.push({ eventName, users, count });
        });
      }

      // Son 24 Saatlik Olay Toplamları
      const [eventsResponse] = await analyticsClient.runReport({
        property: `properties/${ga4PropertyId}`,
        dateRanges: [{ startDate: 'yesterday', endDate: 'today' }],
        dimensions: [{ name: 'eventName' }],
        metrics: [{ name: 'eventCount' }]
      });

      const events24h = {
        deal_outbound_click: 0,
        deal_view: 0,
        coupon_copied: 0,
        catalog_view: 0,
        search_performed: 0
      };

      if (eventsResponse && eventsResponse.rows) {
        eventsResponse.rows.forEach(row => {
          const name = row.dimensionValues?.[0]?.value;
          const count = parseInt(row.metricValues?.[0]?.value || '0', 10);
          if (events24h[name] !== undefined) {
            events24h[name] = count;
          }
        });
      }

      ga4Result = {
        connected: true,
        propertyId: ga4PropertyId,
        activeUsers: totalActive,
        realtimeEvents,
        events24h,
        message: 'GA4 Data API canlı olarak bağlandı.'
      };
    } catch (ga4Error) {
      functions.logger.warn('⚠️ GA4 Data API çağrısı uyarı verdi:', ga4Error.message);
      ga4Result = {
        connected: false,
        propertyId: ga4PropertyId,
        activeUsers: 0,
        realtimeEvents: [],
        events24h: {
          deal_outbound_click: 0,
          deal_view: 0,
          coupon_copied: 0,
          catalog_view: 0,
          search_performed: 0
        },
        message: `GA4 Bağlantı Notu: ${ga4Error.message}`
      };
    }
  }

  // 3. Firestore Gerçek Zamanlı Veri Özeti (Tamamlayıcı & Yedek Canlı Veri)
  const db = admin.firestore();

  // Son 50 fırsattan mağaza dağılımı ve ortalama istatistikler
  let storeCounts = {};
  let totalSampleDeals = 0;
  let totalDealViews = 0;
  let totalDealVotes = 0;

  try {
    const dealsSnapshot = await db.collection('deals')
      .orderBy('createdAt', 'desc')
      .limit(60)
      .get();

    dealsSnapshot.forEach(doc => {
      const deal = doc.data();
      totalSampleDeals++;
      const store = (deal.store || deal.magaza || 'Diğer').trim();
      const normalizedStore = store.charAt(0).toUpperCase() + store.slice(1).toLowerCase();
      storeCounts[normalizedStore] = (storeCounts[normalizedStore] || 0) + 1;
      totalDealViews += Number(deal.viewCount || deal.views || 0);
      totalDealVotes += Number(deal.voteCount || deal.votes || 0);
    });
  } catch (dealErr) {
    functions.logger.warn('⚠️ Fırsat mağaza istatistikleri çekilemedi:', dealErr.message);
  }

  // Mağaza dağılım listesi
  const storeDistribution = Object.keys(storeCounts)
    .map(store => ({
      store,
      count: storeCounts[store],
      percentage: totalSampleDeals > 0 ? Math.round((storeCounts[store] / totalSampleDeals) * 100) : 0
    }))
    .sort((a, b) => b.count - a.count)
    .slice(0, 6);

  // Toplam koleksiyon sayaçları (Hafif aggregation)
  let dbCounts = { deals: totalSampleDeals, coupons: 0, catalogs: 0 };
  try {
    const [dealsSnap, cSnap, catSnap] = await Promise.allSettled([
      db.collection('deals').count().get(),
      db.collection('kuponlar').count().get(),
      db.collection('kataloglar').count().get()
    ]);
    dbCounts.deals = dealsSnap.status === 'fulfilled' ? dealsSnap.value.data().count : totalSampleDeals;
    dbCounts.coupons = cSnap.status === 'fulfilled' ? cSnap.value.data().count : 0;
    dbCounts.catalogs = catSnap.status === 'fulfilled' ? catSnap.value.data().count : 0;
  } catch (_) {}

  return {
    success: true,
    environment,
    projectId,
    timestamp: new Date().toISOString(),
    ga4: ga4Result,
    storeDistribution,
    realtimeStats: {
      sampleDeals: totalSampleDeals,
      estimatedViews: totalDealViews,
      estimatedVotes: totalDealVotes,
      dbCounts
    }
  };
}

module.exports = { getObservabilityMetricsHandler };
