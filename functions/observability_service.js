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
  
  const defaultEvents24h = {
    deal_outbound_click: 0,
    deal_view: 0,
    coupon_copied: 0,
    catalog_view: 0,
    search_performed: 0,
    notification_interaction: 0,
    deal_shared: 0,
    deal_voted: 0,
    ad_impression: 0,
    ad_click: 0
  };

  const defaultGrowth = {
    dau: 0,
    wau: 0,
    mau: 0,
    stickiness: '0.0',
    newUsers: 0,
    sessions: 0,
    avgEngagementSeconds: 0,
    avgEngagementFormatted: '0 sn'
  };

  let ga4Result = {
    connected: false,
    propertyId: ga4PropertyId,
    activeUsers: 0,
    realtimeEvents: [],
    events24h: { ...defaultEvents24h },
    growth: { ...defaultGrowth },
    topScreens: [],
    message: 'GA4 Property ID henüz tanımlanmadı veya API yetkisi bekleniyor.'
  };

  if (BetaAnalyticsDataClient && ga4PropertyId) {
    try {
      const analyticsClient = new BetaAnalyticsDataClient();

      // 1. Toplam Anlık Aktif Kullanıcı Sorgusu (Son 30 dakika - Boyutsuz)
      let totalActive = 0;
      try {
        const [realtimeUserResponse] = await analyticsClient.runRealtimeReport({
          property: `properties/${ga4PropertyId}`,
          metrics: [{ name: 'activeUsers' }]
        });
        if (realtimeUserResponse && realtimeUserResponse.rows && realtimeUserResponse.rows.length > 0) {
          totalActive = parseInt(realtimeUserResponse.rows[0].metricValues?.[0]?.value || '0', 10);
        }
      } catch (userQueryErr) {
        functions.logger.warn('⚠️ GA4 Realtime activeUsers sorgu hatası:', userQueryErr.message);
      }

      // 2. Anlık Olay Sayıları (Son 30 dakika - eventName ile gruplanmış)
      const realtimeEvents = [];
      try {
        const [realtimeEventResponse] = await analyticsClient.runRealtimeReport({
          property: `properties/${ga4PropertyId}`,
          dimensions: [{ name: 'eventName' }],
          metrics: [{ name: 'eventCount' }]
        });
        if (realtimeEventResponse && realtimeEventResponse.rows) {
          realtimeEventResponse.rows.forEach(row => {
            const eventName = row.dimensionValues?.[0]?.value || '';
            const count = parseInt(row.metricValues?.[0]?.value || '0', 10);
            realtimeEvents.push({ eventName, count });
          });
        }
      } catch (evtQueryErr) {
        functions.logger.warn('⚠️ GA4 Realtime eventCount sorgu hatası:', evtQueryErr.message);
      }

      // 3. Son 24 Saatlik / Son 1 Günlük Olay Toplamları (runReport)
      const events24h = { ...defaultEvents24h };

      try {
        const [eventsResponse] = await analyticsClient.runReport({
          property: `properties/${ga4PropertyId}`,
          dateRanges: [{ startDate: 'yesterday', endDate: 'today' }],
          dimensions: [{ name: 'eventName' }],
          metrics: [{ name: 'eventCount' }]
        });

        if (eventsResponse && eventsResponse.rows) {
          eventsResponse.rows.forEach(row => {
            const name = row.dimensionValues?.[0]?.value;
            const count = parseInt(row.metricValues?.[0]?.value || '0', 10);
            if (events24h[name] !== undefined) {
              events24h[name] = count;
            }
          });
        }
      } catch (reportErr) {
        functions.logger.warn('⚠️ GA4 runReport (24h) sorgu hatası:', reportErr.message);
      }

      // 4. GA4 24h Tablo Gecikmesi Köprüsü (Realtime Event Fusion):
      if (realtimeEvents.length > 0) {
        realtimeEvents.forEach(re => {
          if (events24h[re.eventName] !== undefined) {
            events24h[re.eventName] = Math.max(events24h[re.eventName], re.count);
          }
        });
      }

      // 5. Büyüme & Sadakat Metrikleri (DAU, WAU, MAU, Stickiness, New Users, Engagement)
      // Her metrik kendi doğru penceresiyle sorgulanır — tek sorgu + 30 gün hatalıydı.
      let growthMetrics = { ...defaultGrowth };
      try {
        const prop = `properties/${ga4PropertyId}`;

        // 3 paralel sorgu: DAU (bugün), WAU (7 gün), MAU+extras (28 gün)
        const [dauRes, wauRes, mauRes] = await Promise.allSettled([
          // DAU: Bugünün tekil aktif kullanıcısı
          analyticsClient.runReport({
            property: prop,
            dateRanges: [{ startDate: 'today', endDate: 'today' }],
            metrics: [
              { name: 'activeUsers' },
              { name: 'sessions' },
              { name: 'userEngagementDuration' }
            ]
          }),
          // WAU: Son 7 günün tekil aktif kullanıcısı
          analyticsClient.runReport({
            property: prop,
            dateRanges: [{ startDate: '7daysAgo', endDate: 'today' }],
            metrics: [{ name: 'activeUsers' }]
          }),
          // MAU: Son 28 günün tekil aktif kullanıcısı + yeni kullanıcılar
          analyticsClient.runReport({
            property: prop,
            dateRanges: [{ startDate: '28daysAgo', endDate: 'today' }],
            metrics: [
              { name: 'activeUsers' },
              { name: 'newUsers' }
            ]
          })
        ]);

        // DAU sonuçlarını parse et
        let dau = 0, sessions = 0, totalEngSeconds = 0;
        if (dauRes.status === 'fulfilled') {
          const rows = dauRes.value[0]?.rows;
          if (rows && rows.length > 0) {
            dau = parseInt(rows[0].metricValues?.[0]?.value || '0', 10);
            sessions = parseInt(rows[0].metricValues?.[1]?.value || '0', 10);
            totalEngSeconds = parseFloat(rows[0].metricValues?.[2]?.value || '0');
          }
        }

        // WAU sonucunu parse et
        let wau = 0;
        if (wauRes.status === 'fulfilled') {
          const rows = wauRes.value[0]?.rows;
          if (rows && rows.length > 0) {
            wau = parseInt(rows[0].metricValues?.[0]?.value || '0', 10);
          }
        }

        // MAU sonucunu parse et
        let mau = 0, newUsers = 0;
        if (mauRes.status === 'fulfilled') {
          const rows = mauRes.value[0]?.rows;
          if (rows && rows.length > 0) {
            mau = parseInt(rows[0].metricValues?.[0]?.value || '0', 10);
            newUsers = parseInt(rows[0].metricValues?.[1]?.value || '0', 10);
          }
        }

        // Realtime aktif kullanıcı ile tabanı garanti et
        const finalDau = Math.max(dau, totalActive > 0 ? totalActive : 0);
        const finalWau = Math.max(wau, finalDau);
        const finalMau = Math.max(mau, finalWau);
        const stickiness = finalMau > 0 ? ((finalDau / finalMau) * 100).toFixed(1) : (finalDau > 0 ? '100.0' : '0.0');
        const avgEng = sessions > 0 ? Math.round(totalEngSeconds / sessions) : Math.round(totalEngSeconds);
        const avgEngagementFormatted = avgEng >= 60 ? `${Math.floor(avgEng / 60)} dk ${avgEng % 60} sn` : `${avgEng} sn`;

        growthMetrics = {
          dau: finalDau,
          wau: finalWau,
          mau: finalMau,
          stickiness,
          newUsers,
          sessions,
          avgEngagementSeconds: avgEng,
          avgEngagementFormatted
        };

        // Hepsinden veri gelmediyse ama canlı cihaz varsa asgari taban
        if (finalDau === 0 && finalWau === 0 && finalMau === 0 && totalActive > 0) {
          growthMetrics.dau = totalActive;
          growthMetrics.wau = totalActive;
          growthMetrics.mau = totalActive;
          growthMetrics.stickiness = '100.0';
        }
      } catch (growthErr) {
        functions.logger.warn('⚠️ GA4 Growth metrics sorgu hatası:', growthErr.message);
      }

      // 6. En Çok Ziyaret Edilen Ekranlar (Son 7 Gün)
      // Flutter uygulamalarında asıl ekran adları unifiedScreenName (firebase_screen) içinde yer alır.
      // unifiedScreenClass Android'de genellikle MainActivity döner, bu yüzden unifiedScreenName önceliklidir.
      let topScreens = [];
      try {
        const [screenResponse] = await analyticsClient.runReport({
          property: `properties/${ga4PropertyId}`,
          dateRanges: [{ startDate: '7daysAgo', endDate: 'today' }],
          dimensions: [{ name: 'unifiedScreenName' }],
          metrics: [{ name: 'screenPageViews' }],
          limit: 10,
          orderBys: [{ metric: { metricName: 'screenPageViews' }, desc: true }]
        });
        if (screenResponse && screenResponse.rows) {
          screenResponse.rows.forEach(r => {
            const screen = r.dimensionValues?.[0]?.value || '';
            const views = parseInt(r.metricValues?.[0]?.value || '0', 10);
            // Anlamsız "/", "MainActivity", boş ve (not set) isimleri filtrele
            if (screen && screen !== '(not set)' && screen !== '/' && screen !== '' && !screen.startsWith('//') && screen !== 'MainActivity' && screen !== 'FlutterActivity') {
              topScreens.push({ screen, views });
            }
          });
        }
        // Eğer unifiedScreenName ile 0 sonuç kaldıysa alternatif olarak unifiedScreenClass dene
        if (topScreens.length === 0) {
          const [altResponse] = await analyticsClient.runReport({
            property: `properties/${ga4PropertyId}`,
            dateRanges: [{ startDate: '7daysAgo', endDate: 'today' }],
            dimensions: [{ name: 'unifiedScreenClass' }],
            metrics: [{ name: 'screenPageViews' }],
            limit: 10,
            orderBys: [{ metric: { metricName: 'screenPageViews' }, desc: true }]
          });
          if (altResponse && altResponse.rows) {
            altResponse.rows.forEach(r => {
              const screen = r.dimensionValues?.[0]?.value || '';
              const views = parseInt(r.metricValues?.[0]?.value || '0', 10);
              if (screen && screen !== '(not set)' && screen !== '/' && screen !== '' && !screen.startsWith('//') && screen !== 'MainActivity' && screen !== 'FlutterActivity') {
                topScreens.push({ screen, views });
              }
            });
          }
        }
      } catch (screenErr) {
        functions.logger.warn('⚠️ GA4 topScreens sorgu hatası:', screenErr.message);
      }

      ga4Result = {
        connected: true,
        propertyId: ga4PropertyId,
        activeUsers: totalActive,
        realtimeEvents,
        events24h,
        growth: growthMetrics,
        topScreens,
        message: 'GA4 Data API canlı olarak bağlandı.'
      };
    } catch (ga4Error) {
      functions.logger.warn('⚠️ GA4 Data API çağrısı uyarı verdi:', ga4Error.message);
      const isPermissionDenied = ga4Error.message && ga4Error.message.includes('PERMISSION_DENIED');
      ga4Result = {
        connected: false,
        propertyId: ga4PropertyId,
        serviceAccountEmail: `${projectId}@appspot.gserviceaccount.com`,
        permissionIssue: isPermissionDenied,
        activeUsers: 0,
        realtimeEvents: [],
        events24h: { ...defaultEvents24h },
        growth: { ...defaultGrowth },
        topScreens: [],
        message: isPermissionDenied
          ? `GA4 Yetki Eksik: ${projectId}@appspot.gserviceaccount.com servis hesabına GA4 mülkünde Viewer yetkisi verilmelidir.`
          : `GA4 Bağlantı Notu: ${ga4Error.message}`
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
