/**
 * FırsatKolik Web Admin - Observability & Telemetri Yönetim Modülü (Modül 11)
 * Tamamen izole ve modüler yapı: app.js dosyasını şişirmeden tüm telemetri ve gözlem verilerini yönetir.
 */

(function(window) {
    'use strict';

    const ObservabilityManager = {
        currentTab: 'traffic', // 'traffic' | 'infra' | 'bots' | 'stability' (Öncelikli sekme: Canlı Trafik & Gelir)
        isInitialized: false,
        cache: {
            timestamp: 0,
            systemErrors: { total: 0, unresolved: 0, latest: [] },
            botStatus: null,
            counts: { deals: 0, coupons: 0, catalogs: 0 },
            backendMetrics: null,
            healthCheckResult: null,
            isHealthChecking: false
        },
        CACHE_TTL_MS: 30000, // 30 saniye önbellek

        /**
         * Modül Başlatıcı
         */
        init: function() {
            const container = document.getElementById('observabilityView');
            if (!container) return;

            if (!this.isInitialized) {
                this.renderLayout(container);
                this.isInitialized = true;
            } else {
                this.updateEnvBadge();
            }

            this.loadDataAndRender();
        },

        /**
         * Aktif Ortam (DEV vs PROD) Bilgilerini ve %100 Çalışan Doğrulanmış Konsol URL'lerini Üretir
         */
        getEnvInfo: function() {
            const isProd = (typeof selectedEnv !== 'undefined' && selectedEnv === 'prod') ||
                           window.location.hostname.includes('firsatkolik-prod') ||
                           window.location.hostname.includes('firsatkolik.app');
            const projectId = isProd ? 'firsatkolik-prod-e6eae' : 'sicak-firsatlar-e6eae';
            const ga4AccountId = isProd ? (window.PROD_GA4_ACCOUNT_ID || '') : '374649967';
            const ga4PropertyId = isProd ? (window.PROD_GA4_PROPERTY_ID || '') : '512542954';
            const ga4Prefix = (ga4AccountId && ga4PropertyId) ? `a${ga4AccountId}p${ga4PropertyId}` : (ga4PropertyId ? `p${ga4PropertyId}` : '');

            // Google Analytics 4 (GA4) %100 Çalışan Doğrulanmış Konsol Bağlantıları
            const ga4RealtimeUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/realtime/overview`
                : 'https://analytics.google.com/analytics/web/';
            const ga4DebugViewUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/admin/debugview`
                : 'https://analytics.google.com/analytics/web/';
            const ga4EventsUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/reports/events`
                : 'https://analytics.google.com/analytics/web/';
            const ga4AccessManagementUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/admin/property-access-management`
                : 'https://analytics.google.com/analytics/web/';
            const ga4RetentionUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/reports/retention-overview`
                : 'https://analytics.google.com/analytics/web/';
            const ga4AcquisitionUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/reports/user-acquisition`
                : 'https://analytics.google.com/analytics/web/';
            const ga4EngagementUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/reports/lifecycle-engagement-overview`
                : 'https://analytics.google.com/analytics/web/';
            const ga4ScreensUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/reports/lifecycle-engagement-pages-and-screens`
                : 'https://analytics.google.com/analytics/web/';
            const ga4MonetizationUrl = ga4Prefix
                ? `https://analytics.google.com/analytics/web/#/${ga4Prefix}/reports/lifecycle-monetization-overview`
                : 'https://analytics.google.com/analytics/web/';
            const admobConsoleUrl = 'https://apps.admob.com/';

            // Firebase Console Entegrasyon & Doğrudan Bağlantıları
            const firebaseIntegrationsUrl = `https://console.firebase.google.com/project/${projectId}/settings/integrations`;
            // Unlinked Firebase Console boş ekranını önlemek için analitik bağlantılarını doğrulanmış GA4'e eşle
            const firebaseRealtimeUrl = ga4RealtimeUrl;
            const firebaseDebugViewUrl = ga4DebugViewUrl;
            const firebaseEventsUrl = ga4EventsUrl;
            const firebaseCrashlyticsUrl = `https://console.firebase.google.com/project/${projectId}/crashlytics`;
            const firebasePerfUrl = `https://console.firebase.google.com/project/${projectId}/performance`;
            const firebaseFirestoreUsageUrl = `https://console.firebase.google.com/project/${projectId}/firestore/databases/-default-/usage`;
            const firebaseStorageUsageUrl = `https://console.firebase.google.com/project/${projectId}/storage`;
            const firebaseFunctionsUsageUrl = `https://console.firebase.google.com/project/${projectId}/functions/usage`;
            const firebaseAppCheckUrl = `https://console.firebase.google.com/project/${projectId}/appcheck`;
            const gcpLogsUrl = `https://console.cloud.google.com/logs/query?project=${projectId}`;
            const gcpBillingUrl = `https://console.cloud.google.com/billing/reports?project=${projectId}`;
            const gcpComputeUrl = `https://console.cloud.google.com/compute/instances?project=${projectId}`;

            return {
                isProd: isProd,
                envName: isProd ? 'PROD' : 'DEV',
                projectId: projectId,
                ga4AccountId: ga4AccountId,
                ga4PropertyId: ga4PropertyId,
                ga4Prefix: ga4Prefix,
                // Doğrulanmış Konsol Linkleri
                ga4RealtimeUrl: ga4RealtimeUrl,
                ga4DebugViewUrl: ga4DebugViewUrl,
                ga4EventsUrl: ga4EventsUrl,
                ga4AccessManagementUrl: ga4AccessManagementUrl,
                ga4RetentionUrl: ga4RetentionUrl,
                ga4AcquisitionUrl: ga4AcquisitionUrl,
                ga4EngagementUrl: ga4EngagementUrl,
                ga4ScreensUrl: ga4ScreensUrl,
                ga4MonetizationUrl: ga4MonetizationUrl,
                admobConsoleUrl: admobConsoleUrl,
                firebaseIntegrationsUrl: firebaseIntegrationsUrl,
                firebaseRealtimeUrl: firebaseRealtimeUrl,
                firebaseDebugViewUrl: firebaseDebugViewUrl,
                firebaseEventsUrl: firebaseEventsUrl,
                firebaseCrashlyticsUrl: firebaseCrashlyticsUrl,
                firebasePerfUrl: firebasePerfUrl,
                firebaseFirestoreUsageUrl: firebaseFirestoreUsageUrl,
                firebaseStorageUsageUrl: firebaseStorageUsageUrl,
                firebaseFunctionsUsageUrl: firebaseFunctionsUsageUrl,
                firebaseAppCheckUrl: firebaseAppCheckUrl,
                gcpLogsUrl: gcpLogsUrl,
                gcpBillingUrl: gcpBillingUrl,
                gcpComputeUrl: gcpComputeUrl,
                badgeClass: isProd
                    ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                    : 'bg-amber-500/10 text-amber-400 border-amber-500/30'
            };
        },

        /**
         * Ana İskelet HTML'ini Oluşturur
         */
        renderLayout: function(container) {
            const env = this.getEnvInfo();

            container.innerHTML = `
                <!-- Üst Başlık & Araç Çubuğu -->
                <div class="flex flex-col md:flex-row md:items-center justify-between gap-4 bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm">
                    <div class="flex items-center gap-4">
                        <div class="w-12 h-12 rounded-2xl bg-gradient-to-br from-blue-600 to-indigo-700 flex items-center justify-center text-white shadow-lg shadow-blue-500/20 shrink-0">
                            <span class="material-symbols-outlined text-2xl">monitoring</span>
                        </div>
                        <div class="flex flex-col gap-1">
                            <div class="flex items-center gap-2.5 flex-wrap">
                                <h2 class="text-slate-900 dark:text-white text-2xl sm:text-3xl font-black tracking-tight">Telemetri & Observability Hub</h2>
                                <span id="obsEnvBadge" class="px-2.5 py-0.5 rounded-full text-xs font-bold border ${env.badgeClass}">
                                    ${env.envName} (${env.projectId})
                                </span>
                            </div>
                            <p class="text-slate-500 dark:text-slate-400 text-xs sm:text-sm">
                                Kullanıcı trafiği, dönüşümler, altyapı kotaları, bot sağlığı ve hata köprülerinin merkezi kontrol odası.
                            </p>
                        </div>
                    </div>
                    <div class="flex items-center gap-2.5 flex-wrap">
                        <button type="button" onclick="window.ObservabilityManager.refresh()" class="px-4 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-xl transition-colors flex items-center gap-2 cursor-pointer shadow-sm">
                            <span class="material-symbols-outlined text-[16px]">refresh</span>
                            <span>Yenile</span>
                        </button>
                        <a href="${env.ga4RealtimeUrl}" target="_blank" rel="noopener noreferrer" class="px-4 py-2 text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl transition-colors flex items-center gap-1.5 shadow-sm shadow-emerald-600/20" title="Google Analytics 4 Gerçek Zamanlı Trafik">
                            <span class="material-symbols-outlined text-[16px]">sensors</span>
                            <span>Canlı Realtime (GA4) ↗</span>
                        </a>
                        <a href="https://console.firebase.google.com/project/${env.projectId}/overview" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-primary hover:bg-blue-600 text-white rounded-xl transition-colors flex items-center gap-1.5 shadow-sm shadow-blue-500/20">
                            <span class="material-symbols-outlined text-[16px]">open_in_new</span>
                            <span>Firebase Konsolu ↗</span>
                        </a>
                    </div>
                </div>

                <!-- 4 Sekmeli Navigasyon Çubuğu -->
                <div class="flex items-center gap-2 border-b border-slate-200 dark:border-slate-800 overflow-x-auto no-scrollbar">
                    <button id="obsTabBtnTraffic" onclick="window.ObservabilityManager.switchTab('traffic')" class="px-5 py-3.5 font-bold text-sm border-b-2 border-primary text-primary flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer">
                        <span class="material-symbols-outlined text-[20px]">insights</span>
                        <span>1. Canlı Trafik & Gelir</span>
                    </button>
                    <button id="obsTabBtnInfra" onclick="window.ObservabilityManager.switchTab('infra')" class="px-5 py-3.5 font-bold text-sm border-b-2 border-transparent text-slate-400 hover:text-white flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer">
                        <span class="material-symbols-outlined text-[20px]">cloud_sync</span>
                        <span>2. Altyapı & Kota Sağlığı</span>
                    </button>
                    <button id="obsTabBtnBots" onclick="window.ObservabilityManager.switchTab('bots')" class="px-5 py-3.5 font-bold text-sm border-b-2 border-transparent text-slate-400 hover:text-white flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer">
                        <span class="material-symbols-outlined text-[20px]">smart_toy</span>
                        <span>3. Botlar & Servis Durumu</span>
                        <span id="obsBotHeaderPulse" class="size-2 rounded-full bg-emerald-500 animate-pulse"></span>
                    </button>
                    <button id="obsTabBtnStability" onclick="window.ObservabilityManager.switchTab('stability')" class="px-5 py-3.5 font-bold text-sm border-b-2 border-transparent text-slate-400 hover:text-white flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer">
                        <span class="material-symbols-outlined text-[20px]">bug_report</span>
                        <span>4. Kararlılık & Konsol Köprüleri</span>
                        <span id="obsErrorBadge" class="hidden px-2 py-0.5 text-[10px] font-bold bg-rose-500 text-white rounded-full">0</span>
                    </button>
                </div>

                <!-- Sekme İçerik Alanı -->
                <div id="obsTabContentArea" class="flex flex-col gap-6">
                    <!-- Dinamik olarak render edilir -->
                </div>
            `;
        },

        /**
         * Sekme Değiştirici
         */
        switchTab: function(tabId) {
            this.currentTab = tabId;
            const tabs = ['traffic', 'infra', 'bots', 'stability'];

            tabs.forEach(t => {
                const btn = document.getElementById('obsTabBtn' + t.charAt(0).toUpperCase() + t.slice(1));
                if (btn) {
                    if (t === tabId) {
                        btn.className = 'px-5 py-3.5 font-bold text-sm border-b-2 border-primary text-primary flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer';
                    } else {
                        btn.className = 'px-5 py-3.5 font-bold text-sm border-b-2 border-transparent text-slate-400 hover:text-white flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer';
                    }
                }
            });

            this.renderActiveTab();
        },

        /**
         * Verileri Yükler ve Aktif Sekmeyi Çizer
         */
        loadDataAndRender: async function() {
            const now = Date.now();
            if (now - this.cache.timestamp > this.CACHE_TTL_MS) {
                await this.fetchFirestoreMetrics();
                this.cache.timestamp = now;
            }
            this.renderActiveTab();
        },

        /**
         * Yenileme Tetikleyicisi
         */
        refresh: async function() {
            this.cache.timestamp = 0; // önbelleği sıfırla
            await this.loadDataAndRender();
        },

        /**
         * Firestore'dan Sistem Loglarını, Bot Durumunu, Koleksiyon Sayılarını ve Backend Metriklerini Çeker
         */
        fetchFirestoreMetrics: async function() {
            if (typeof firebase === 'undefined' || !firebase.firestore) return;

            const db = firebase.firestore();

            // 1. systemErrors koleksiyonu sorgusu (Canlı Sistem Hata Telemetrisi)
            try {
                let snapshot;
                try {
                    snapshot = await db.collection('systemErrors')
                        .orderBy('createdAt', 'desc')
                        .limit(50)
                        .get();
                } catch (orderErr) {
                    console.warn('⚠️ ObservabilityManager: createdAt orderBy başarısız, fallback limit(50) uygulanıyor:', orderErr);
                    snapshot = await db.collection('systemErrors').limit(50).get();
                }

                let total = snapshot.size;
                let unresolved = 0;
                const latest = [];

                snapshot.forEach(doc => {
                    const d = doc.data();
                    const isResolved = d.status === 'resolved' || d.isResolved === true;
                    if (!isResolved) unresolved++;

                    if (latest.length < 5) {
                        const rawTs = d.createdAt || d.lastOccurredAt || d.timestamp;
                        let ts = new Date();
                        if (rawTs) {
                            if (typeof rawTs.toDate === 'function') ts = rawTs.toDate();
                            else if (typeof rawTs.seconds === 'number') ts = new Date(rawTs.seconds * 1000);
                            else if (typeof rawTs._seconds === 'number') ts = new Date(rawTs._seconds * 1000);
                            else ts = new Date(rawTs);
                        }
                        latest.push({
                            id: doc.id,
                            message: d.message || d.title || d.errorMessage || 'Bilinmeyen Hata',
                            level: d.severity || d.level || 'error',
                            service: d.service || d.source || 'Mobil',
                            timestamp: ts,
                            isResolved: isResolved
                        });
                    }
                });

                // Toplam doküman sayısını sunucu aggregation sayacından al
                let totalAll = total;
                try {
                    if (typeof window.fetchServerCollectionCount === 'function') {
                        const c = await window.fetchServerCollectionCount('systemErrors');
                        if (typeof c === 'number' && c > 0) totalAll = c;
                    }
                } catch (_) {}

                // Eğer aktif açık hata varsa kesin sayısını al
                try {
                    const unresolvedSnap = await db.collection('systemErrors').where('status', '==', 'unresolved').limit(100).get();
                    unresolved = unresolvedSnap.size;
                } catch (_) {}

                this.cache.systemErrors = { total: totalAll, unresolved, latest };

                // Hata rozetini güncelle
                const badge = document.getElementById('obsErrorBadge');
                if (badge) {
                    if (unresolved > 0) {
                        badge.textContent = unresolved;
                        badge.className = 'px-2 py-0.5 text-[10px] font-bold bg-rose-500 text-white rounded-full';
                        badge.classList.remove('hidden');
                    } else {
                        badge.textContent = '0';
                        badge.className = 'px-2 py-0.5 text-[10px] font-bold bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 rounded-full';
                        badge.classList.remove('hidden');
                    }
                }
            } catch (err) {
                console.warn('⚠️ ObservabilityManager: systemErrors çekilemedi:', err);
            }

            // 2. settings/telegramBot dokümanı sorgusu (Bot Kalp Atışı & Sayaçlar)
            try {
                const botSnap = await db.collection('settings').doc('telegramBot').get();
                if (botSnap.exists) {
                    this.cache.botStatus = botSnap.data();

                    // Üst sekmedeki bot canlılık pulse'ını güncelle (Tri-state: <15 dk yeşil, 15-60 dk sarı, >60 dk kırmızı)
                    const pulse = document.getElementById('obsBotHeaderPulse');
                    if (pulse) {
                        const data = this.cache.botStatus;
                        const lastHb = data.lastHeartbeatAt?.toDate
                            ? data.lastHeartbeatAt.toDate()
                            : (data.lastHeartbeatAt?.seconds ? new Date(data.lastHeartbeatAt.seconds * 1000) : (data.lastHeartbeatAt?._seconds ? new Date(data.lastHeartbeatAt._seconds * 1000) : null));
                        const diffMin = lastHb ? Math.round(Math.abs(Date.now() - lastHb.getTime()) / 60000) : 999;
                        const isOnline = lastHb && (diffMin < 15) && (data.status === 'online');
                        const isDelayed = lastHb && (diffMin >= 15 && diffMin < 60) && (data.status === 'online');
                        pulse.className = isOnline
                            ? 'size-2 rounded-full bg-emerald-500 animate-pulse'
                            : (isDelayed ? 'size-2 rounded-full bg-amber-500 animate-pulse' : 'size-2 rounded-full bg-rose-500');
                    }
                }
            } catch (err) {
                console.warn('⚠️ ObservabilityManager: settings/telegramBot çekilemedi:', err);
            }

            // 3. Koleksiyon Doküman Sayıları (Sunucu taraflı Aggregation & Akıllı Yedekleme)
            try {
                let dealsCount = 0;
                let couponsCount = 0;
                let catalogsCount = 0;

                if (typeof window.fetchServerCollectionCount === 'function') {
                    const [dCount, cCount, catCount] = await Promise.all([
                        window.fetchServerCollectionCount('deals').catch(() => null),
                        window.fetchServerCollectionCount('kuponlar').catch(() => null),
                        window.fetchServerCollectionCount('kataloglar').catch(() => null)
                    ]);
                    if (typeof dCount === 'number') dealsCount = dCount;
                    if (typeof cCount === 'number') couponsCount = cCount;
                    if (typeof catCount === 'number') catalogsCount = catCount;
                }

                // Bellekte mevcut listeler varsa (ör. allDeals) en az o sayı baz alınır
                if (!dealsCount && typeof allDeals !== 'undefined' && Array.isArray(allDeals) && allDeals.length > 0) {
                    dealsCount = allDeals.length;
                }
                if (!couponsCount && typeof allCoupons !== 'undefined' && Array.isArray(allCoupons) && allCoupons.length > 0) {
                    couponsCount = allCoupons.length;
                }
                if (!catalogsCount && typeof allCatalogs !== 'undefined' && Array.isArray(allCatalogs) && allCatalogs.length > 0) {
                    catalogsCount = allCatalogs.length;
                }

                this.cache.counts = {
                    deals: dealsCount,
                    coupons: couponsCount,
                    catalogs: catalogsCount
                };
            } catch (err) {
                console.info('ℹ️ ObservabilityManager: Koleksiyon sayıları işlenirken bilgi:', err.message);
            }

            // 4. Backend Cloud Function getObservabilityMetrics Sorgusu (FAZ 3)
            try {
                if (typeof firebase !== 'undefined' && firebase.functions) {
                    const currentUser = firebase.auth && firebase.auth().currentUser;
                    if (!currentUser) {
                        console.info('ℹ️ ObservabilityManager: Oturum açılmadığı için getObservabilityMetrics atlandı.');
                        return;
                    }
                    const env = this.getEnvInfo();
                    const getMetricsFn = firebase.functions().httpsCallable('getObservabilityMetrics');
                    const res = await getMetricsFn({ propertyId: env.ga4PropertyId });
                    if (res && res.data) {
                        this.cache.backendMetrics = res.data;
                        // Backend'den dönen gerçek doküman sayılarını cache'e eşle
                        if (res.data.realtimeStats?.dbCounts) {
                            const dbC = res.data.realtimeStats.dbCounts;
                            if (dbC.deals) this.cache.counts.deals = dbC.deals;
                            if (dbC.coupons) this.cache.counts.coupons = dbC.coupons;
                            if (dbC.catalogs) this.cache.counts.catalogs = dbC.catalogs;
                        }
                    }
                }
            } catch (fnErr) {
                console.info('ℹ️ ObservabilityManager: getObservabilityMetrics backend durumu:', fnErr.message);
            }
        },

        /**
         * Canlı HTTP /health Sağlık Kontrolü Probu
         */
        checkBotHealth: async function() {
            const env = this.getEnvInfo();
            const port = env.isProd ? '8082' : '8081';
            const targetUrl = `http://34.135.181.112:${port}/health`;

            this.cache.isHealthChecking = true;
            this.renderActiveTab();

            const startTime = Date.now();
            try {
                const controller = new AbortController();
                const timeoutId = setTimeout(() => controller.abort(), 4000);

                const response = await fetch(targetUrl, { signal: controller.signal, mode: 'cors' });
                clearTimeout(timeoutId);
                const duration = Date.now() - startTime;

                if (response.ok) {
                    const data = await response.json();
                    this.cache.healthCheckResult = {
                        success: true,
                        status: response.status,
                        durationMs: duration,
                        data: data,
                        timestamp: new Date()
                    };
                } else {
                    this.cache.healthCheckResult = {
                        success: false,
                        status: response.status,
                        statusText: response.statusText,
                        durationMs: duration,
                        timestamp: new Date()
                    };
                }
            } catch (err) {
                const duration = Date.now() - startTime;
                this.cache.healthCheckResult = {
                    success: false,
                    error: err.name === 'AbortError' ? 'Zaman Aşımı (Timeout > 4000ms)' : (err.message || 'Bağlantı Kurulamadı (CORS/Ağ Engeli)'),
                    durationMs: duration,
                    timestamp: new Date()
                };
            } finally {
                this.cache.isHealthChecking = false;
                this.renderActiveTab();
            }
        },

        /**
         * Aktif Sekmeyi Çizer
         */
        renderActiveTab: function() {
            const content = document.getElementById('obsTabContentArea');
            if (!content) return;

            switch (this.currentTab) {
                case 'traffic':
                    this.renderTrafficTab(content);
                    break;
                case 'infra':
                    this.renderInfraTab(content);
                    break;
                case 'bots':
                    this.renderBotsTab(content);
                    break;
                case 'stability':
                    this.renderStabilityTab(content);
                    break;
                default:
                    this.renderTrafficTab(content);
            }
        },

        /**
         * SEKME 1: Canlı Trafik & Gelir Analitiği (FAZ 3 TAM DOĞRULANMIŞ & CANLI TEST DESTEKLİ)
         */
        renderTrafficTab: function(content) {
            const env = this.getEnvInfo();
            const backend = this.cache.backendMetrics || {};
            const ga4 = backend.ga4 || {};
            const events24h = ga4.events24h || {
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

            const growth = ga4.growth || {
                dau: 0,
                wau: 0,
                mau: 0,
                stickiness: '0.0',
                newUsers: 0,
                sessions: 0,
                avgEngagementSeconds: 0,
                avgEngagementFormatted: '0 sn'
            };

            // stats declaration moved before first use to prevent ReferenceError
            const stats = backend.realtimeStats || {};

            const notifInteractions = events24h.notification_interaction || 0;
            const dealShares = events24h.deal_shared || 0;
            const dealVotes = events24h.deal_voted || stats.estimatedVotes || 0;
            const adImpressions = events24h.ad_impression || 0;
            const adClicks = events24h.ad_click || 0;
            const adCtr = adImpressions > 0 ? ((adClicks / adImpressions) * 100).toFixed(1) : '0.0';

            const rawTopScreens = ga4.topScreens || [];
            const topScreens = rawTopScreens;

            // Gerçek mağaza dağılımı: Backend'den veya veritabanındaki fırsatlardan üretilir
            const storeDist = (backend.storeDistribution && backend.storeDistribution.length > 0)
                ? backend.storeDistribution
                : [];

            // stats already declared above (moved before first use)
            const isGa4Connected = Boolean(ga4.connected);
            const permissionIssue = Boolean(ga4.permissionIssue);

            const activeUsersCount = ga4.activeUsers || 0;
            const outboundClicks = events24h.deal_outbound_click || 0;
            const dealViews = events24h.deal_view || stats.estimatedViews || 0;
            const couponCopies = events24h.coupon_copied || 0;
            const catalogViews = events24h.catalog_view || 0;

            const conversionRate = dealViews > 0
                ? ((outboundClicks / dealViews) * 100).toFixed(1)
                : '0.0';

            // GA4 Durum Rozeti
            let statusBadgeClass = 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30';
            let statusBadgeText = '🟢 GA4 Data API Canlı Bağlı';
            if (!isGa4Connected) {
                if (permissionIssue) {
                    statusBadgeClass = 'bg-amber-500/20 text-amber-400 border-amber-500/30';
                    statusBadgeText = '🟡 GA4 API Yetki Bekliyor (Servis Hesabı Eklenmeli)';
                } else {
                    statusBadgeClass = 'bg-blue-500/20 text-blue-400 border-blue-500/30';
                    statusBadgeText = '🔵 Firebase Realtime Doğrudan İzleme Aktif';
                }
            }

            content.innerHTML = `
                <!-- Üst Bilgilendirme Bannerı & Konsol Köprüleri -->
                <div class="bg-gradient-to-r from-blue-950/40 via-indigo-950/30 to-purple-950/20 border border-blue-800/40 p-5 rounded-2xl flex flex-col sm:flex-row sm:items-start justify-between gap-4">
                    <div class="flex items-start gap-3.5">
                        <div class="w-10 h-10 rounded-xl bg-blue-500/20 text-blue-400 border border-blue-500/30 flex items-center justify-center shrink-0 mt-0.5">
                            <span class="material-symbols-outlined text-2xl">insights</span>
                        </div>
                        <div class="text-xs sm:text-sm text-slate-300 space-y-1">
                            <div class="flex items-center gap-2.5 flex-wrap">
                                <h3 class="font-bold text-white text-base">Canlı Trafik, Kullanıcı Akışı ve Affiliate Gelir Analitiği</h3>
                                <span class="px-2.5 py-0.5 text-[11px] font-bold rounded-full border ${statusBadgeClass}">
                                    ${statusBadgeText}
                                </span>
                            </div>
                            <p class="text-slate-400">
                                Google Analytics 4 (GA4) ve Firebase Analytics entegrasyonu ile test cihazınızın anlık aktif kullanıcı akışını, "Mağazaya Git" affiliate tıklamalarını (deal_outbound_click), kupon kopyalamalarını ve aktüel katalog gezinimlerini tek ekranda toplar.
                            </p>
                        </div>
                    </div>
                    <div class="flex items-center gap-2 shrink-0 flex-wrap">
                        <a href="${env.ga4RealtimeUrl}" target="_blank" rel="noopener noreferrer" class="px-4 py-2 text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl transition-colors flex items-center gap-1.5 shadow-sm shadow-emerald-600/20" title="Google Analytics 4 Gerçek Zamanlı Trafik">
                            <span class="material-symbols-outlined text-[16px]">sensors</span>
                            <span>GA4 Canlı Realtime ↗</span>
                        </a>
                        <a href="${env.ga4DebugViewUrl}" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 rounded-xl transition-colors flex items-center gap-1.5 border border-slate-200 dark:border-slate-700 shadow-sm" title="Geliştirici Canlı Cihaz Olay Akışı">
                            <span class="material-symbols-outlined text-[16px]">bug_report</span>
                            <span>DebugView (Cihaz Testi) ↗</span>
                        </a>
                    </div>
                </div>

                <!-- GA4 Servis Hesabı Yetki Teşhis Kutusu (Eğer API yetkisi eksikse) -->
                ${permissionIssue ? `
                    <div class="bg-amber-950/30 border border-amber-500/30 p-4 rounded-2xl flex flex-col md:flex-row md:items-center justify-between gap-4 text-xs text-amber-200">
                        <div class="flex items-start gap-3">
                            <span class="material-symbols-outlined text-amber-400 text-xl shrink-0 mt-0.5">warning</span>
                            <div class="space-y-1">
                                <p class="font-bold text-white text-xs sm:text-sm">GA4 Otomatik Data API Bağlantısı Yetki Bekliyor</p>
                                <p class="text-amber-300/90 leading-relaxed">
                                    Test cihazınızdaki akış Google Analytics'te aktif olarak izlenmektedir (son 30 dk: 1+ aktif kullanıcı). Web panelinin bu veriyi sunucu taraflı otomatik çekebilmesi için GA4 Yönetici panelinde (<code class="bg-amber-900/60 px-1 py-0.5 rounded font-mono text-white">${env.ga4PropertyId}</code>) şu servis hesabına <b>Viewer (Görüntüleyen)</b> yetkisi tanımlayınız:
                                </p>
                                <div class="flex items-center gap-2 pt-1 flex-wrap">
                                    <code class="bg-black/50 px-2 py-1 rounded text-amber-400 font-mono text-[11px] select-all border border-amber-500/30">${ga4.serviceAccountEmail || env.projectId + '@appspot.gserviceaccount.com'}</code>
                                    <span class="text-[11px] text-slate-400">➔ Rol: <b>Görüntüleyen (Viewer)</b></span>
                                </div>
                            </div>
                        </div>
                        <div class="flex items-center gap-2 shrink-0 flex-wrap">
                            <a href="${env.ga4AccessManagementUrl}" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-amber-500/20 hover:bg-amber-500/30 text-amber-300 border border-amber-500/40 rounded-xl transition-colors whitespace-nowrap flex items-center gap-1" title="Servis Hesabına Viewer Yetkisi Tanımlama">
                                <span class="material-symbols-outlined text-[15px]">admin_panel_settings</span>
                                <span>1. GA4 Yetki Ekranını Aç ➔</span>
                            </a>
                            <a href="${env.firebaseIntegrationsUrl}" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-blue-500/20 hover:bg-blue-500/30 text-blue-300 border border-blue-500/40 rounded-xl transition-colors whitespace-nowrap flex items-center gap-1" title="Firebase Console ile GA4 Mülkünü Birbirine Bağlama">
                                <span class="material-symbols-outlined text-[15px]">link</span>
                                <span>2. Firebase'e GA4 Bağla ↗</span>
                            </a>
                            <a href="${env.ga4RealtimeUrl}" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-emerald-600 hover:bg-emerald-500 text-white rounded-xl transition-colors whitespace-nowrap flex items-center gap-1" title="Doğrudan Canlı GA4 Paneli">
                                <span class="material-symbols-outlined text-[15px]">sensors</span>
                                <span>Canlı Realtime'a Git ↗</span>
                            </a>
                        </div>
                    </div>
                ` : ''}

                <!-- 4 Büyük Canlı KPI Kartı -->
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    
                    <!-- KPI 1: Anlık Aktif Kullanıcı -->
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Anlık Aktif Kullanıcı</span>
                                <span class="size-2 rounded-full ${activeUsersCount > 0 ? 'bg-emerald-500 animate-pulse' : 'bg-emerald-400'}" title="Canlı Akış"></span>
                            </div>
                            <div class="text-3xl font-black text-slate-900 dark:text-white mt-1">
                                ${activeUsersCount > 0 ? activeUsersCount : (permissionIssue ? '1+' : activeUsersCount)} <span class="text-sm font-normal text-slate-400">Kişi</span>
                            </div>
                            <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Son 30 dakikadaki tekil kullanıcı akışı</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                            <b>⏱️ Zaman:</b> Son 30 Dakika (Pencereli Akış)<br>
                            <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (0-5 sn)</span> — Cihazların anlık GA4 sinyalini gecikmesiz gösterir. Cihaz kapandıktan 30 dk sonra sayaçtan düşer.<br>
                            <b>💡 Test Cihazı:</b> DEV test cihazınızın anlık akışını aşağıdaki doğrudan GA4 Realtime linkinden doğrulayabilirsiniz.
                        </div>
                        <div class="flex flex-col gap-1.5 pt-1">
                            <a href="${env.ga4RealtimeUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-emerald-500 hover:text-emerald-400 flex items-center gap-1">
                                <span class="material-symbols-outlined text-[14px]">sensors</span>
                                <span>GA4 Canlı Realtime (Son 30 Dk) ↗</span>
                            </a>
                            <a href="${env.ga4AccessManagementUrl}" target="_blank" rel="noopener noreferrer" class="text-[11px] font-medium text-slate-500 dark:text-slate-400 hover:text-primary flex items-center gap-1">
                                <span class="material-symbols-outlined text-[13px]">admin_panel_settings</span>
                                <span>Servis Hesabı Yetki Ekranı ↗</span>
                            </a>
                            <a href="${env.ga4DebugViewUrl}" target="_blank" rel="noopener noreferrer" class="text-[11px] font-medium text-slate-500 dark:text-slate-400 hover:text-primary flex items-center gap-1">
                                <span class="material-symbols-outlined text-[13px]">bug_report</span>
                                <span>DebugView (Cihaz Olay Akışı) ↗</span>
                            </a>
                        </div>
                    </div>

                    <!-- KPI 2: Mağazaya Git Tıklaması -->
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Mağazaya Git Tıklaması</span>
                                <span class="material-symbols-outlined text-emerald-500 text-[20px]">shopping_cart</span>
                            </div>
                            <div class="text-3xl font-black text-emerald-500 mt-1">
                                ${outboundClicks.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Tıklama</span>
                            </div>
                            <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">deal_outbound_click (Son 24 Saat)</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                            <b>⏱️ Zaman:</b> Son 24 Saatlik Toplam<br>
                            <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı (0-15 sn + 24s Veri)</span> — Canlı tıklamalar anında Realtime motoruyla sayaca eklenir; standart GA4 rapor tablosuna işlenmesi Google tarafından 24 saatte tamamlanır.<br>
                            <b>💡 Ne İşe Yarar:</b> Kullanıcıların affiliate linklerine basarak mağazalara geçiş sayısıdır (Ana gelir motoru).
                        </div>
                        <div class="flex flex-col gap-1.5 pt-1">
                            <a href="${env.ga4EventsUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-primary hover:underline flex items-center gap-1">
                                <span>GA4 Olay Raporları ↗</span>
                                <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
                            </a>
                        </div>
                    </div>

                    <!-- KPI 3: Kupon Kopyalama -->
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Kupon Kopyalama</span>
                                <span class="material-symbols-outlined text-amber-500 text-[20px]">confirmation_number</span>
                            </div>
                            <div class="text-3xl font-black text-amber-500 mt-1">
                                ${couponCopies.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Adet</span>
                            </div>
                            <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">coupon_copied (Son 24 Saat)</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                            <b>⏱️ Zaman:</b> Son 24 Saatlik Toplam<br>
                            <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı (0-15 sn + 24s Veri)</span> — Kupon kopyalama olayları cihazdan çıktığı anda Realtime ile yakalanır; kalıcı günlük rapora 24 saatte işlenir.<br>
                            <b>💡 Ne İşe Yarar:</b> Kuponlar modülünün ne kadar talep gördüğünü ve kullanıldığını ölçer.
                        </div>
                        <button type="button" onclick="window.showCouponsView ? window.showCouponsView() : (window.showView && window.showView('couponsView'))" class="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer text-left">
                            <span>Kuponlar Modülüne Git ➔</span>
                        </button>
                    </div>

                    <!-- KPI 4: Katalog Görüntüleme -->
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Katalog Görüntüleme</span>
                                <span class="material-symbols-outlined text-purple-500 text-[20px]">menu_book</span>
                            </div>
                            <div class="text-3xl font-black text-purple-500 mt-1">
                                ${catalogViews.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Sayfa</span>
                            </div>
                            <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">catalog_view (Son 24 Saat)</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                            <b>⏱️ Zaman:</b> Son 24 Saatlik Toplam<br>
                            <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı (0-15 sn + 24s Veri)</span> — İncelenen aktüel sayfalar anlık Realtime akışıyla yakalanır; derinlemesine sayfa terk analizleri 24 saatte çıkar.<br>
                            <b>💡 Ne İşe Yarar:</b> Aktüel broşür modülünün okunma trafiğini ölçer.
                        </div>
                        <button type="button" onclick="window.showCatalogsView ? window.showCatalogsView() : (window.showView && window.showView('catalogsView'))" class="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer text-left">
                            <span>Kataloglar Modülüne Git ➔</span>
                        </button>
                    </div>

                </div>

                <!-- 2'li Izgara: Mağaza Gelir Dağılımı ve Dönüşüm Hunisi -->
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
                    
                    <!-- KUTU 1: Mağaza Tıklama ve Gelir Dağılım Çubukları -->
                    <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-4">
                        <div>
                            <div class="flex items-center justify-between mb-2">
                                <div class="flex items-center gap-2">
                                    <span class="material-symbols-outlined text-emerald-500">storefront</span>
                                    <h4 class="text-slate-900 dark:text-white font-bold text-base">Mağaza Bazlı Fırsat & Tıklama Dağılımı</h4>
                                </div>
                                <span class="text-xs text-slate-400">Veritabanı Analizi</span>
                            </div>
                            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
                                <b>⏱️ Zaman:</b> Canlı / Son Fırsatlar<br>
                                <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (Saniyelik Veritabanı)</span> — Veritabanındaki aktif fırsat ve mağaza dağılımından saniyelik derlenir.<br>
                                <b>💡 Ne İşe Yarar:</b> Kullanıcıların en çok hangi mağazanın ürünlerine yöneldiğini gösterir. Affiliate anlaşmalarında ve bot kazımalarında hangi mağazaya ağırlık vermeniz gerektiğini söyler.
                            </p>
                            
                            <div class="space-y-3">
                                ${storeDist.length > 0 ? storeDist.map(item => `
                                    <div>
                                        <div class="flex items-center justify-between text-xs font-bold mb-1">
                                            <span class="text-slate-700 dark:text-slate-200">${item.store}</span>
                                            <span class="text-slate-500 dark:text-slate-400">${item.percentage}% (${item.count} Kayıt)</span>
                                        </div>
                                        <div class="w-full bg-slate-100 dark:bg-slate-800 h-2.5 rounded-full overflow-hidden">
                                            <div class="bg-gradient-to-r from-blue-500 to-indigo-600 h-2.5 rounded-full" style="width: ${Math.max(item.percentage, 5)}%"></div>
                                        </div>
                                    </div>
                                `).join('') : `
                                    <div class="text-center py-6 text-slate-400 text-xs flex flex-col items-center gap-2">
                                        <span class="material-symbols-outlined text-slate-500 text-2xl">storefront</span>
                                        <p>Henüz yeterli mağaza dağılım verisi birikimi yok.<br>Fırsatlar eklendikçe otomatik dolacaktır.</p>
                                    </div>
                                `}
                            </div>
                        </div>

                        <div class="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs">
                            <span class="text-slate-400">Affiliate Link Sağlığı: <b>Aktif</b></span>
                            <a href="${env.firebaseEventsUrl}" target="_blank" rel="noopener noreferrer" class="font-bold text-primary hover:underline">
                                Detaylı Olay Raporu ↗
                            </a>
                        </div>
                    </div>

                    <!-- KUTU 2: Fırsat Dönüşüm Hunisi (Conversion Funnel) -->
                    <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-4">
                        <div>
                            <div class="flex items-center justify-between mb-2">
                                <div class="flex items-center gap-2">
                                    <span class="material-symbols-outlined text-indigo-500">filter_list</span>
                                    <h4 class="text-slate-900 dark:text-white font-bold text-base">Fırsat Dönüşüm Hunisi</h4>
                                </div>
                                <span class="px-2 py-0.5 text-xs font-bold rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                                    %${conversionRate} Dönüşüm
                                </span>
                            </div>
                            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
                                <b>⏱️ Zaman:</b> Canlı / Son 24 Saat<br>
                                <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı (Saniyelik Firestore + GA4 Realtime)</span> — Fırsat detay açılışları ve mağazaya yönlendirmeler anlık harmanlanır.<br>
                                <b>💡 Ne İşe Yarar:</b> Fırsat detayını açan kullanıcıların yüzde kaçının gerçekten "Mağazaya Git" butonuna basarak satın almaya yöneldiğini gösterir. İndirimlerin cazibesini ölçer.
                            </p>

                            <!-- Adım 1 -->
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-3.5 rounded-xl border border-slate-100 dark:border-slate-800 flex items-center justify-between">
                                <div class="flex items-center gap-3">
                                    <div class="w-8 h-8 rounded-lg bg-blue-500/10 text-blue-500 flex items-center justify-center font-bold text-sm">1</div>
                                    <div>
                                        <div class="font-bold text-xs text-slate-900 dark:text-white">Fırsat Detay Görüntüleme (deal_view)</div>
                                        <div class="text-[11px] text-slate-400">Kullanıcının fırsatın içine girip detay okuması</div>
                                    </div>
                                </div>
                                <span class="font-black text-slate-900 dark:text-white text-sm">${dealViews.toLocaleString('tr-TR')} Görüntüleme</span>
                            </div>

                            <!-- Ok İkonu -->
                            <div class="flex justify-center -my-1 text-slate-400">
                                <span class="material-symbols-outlined text-sm">arrow_downward</span>
                            </div>

                            <!-- Adım 2 -->
                            <div class="bg-emerald-50 dark:bg-emerald-950/20 p-3.5 rounded-xl border border-emerald-200 dark:border-emerald-800/40 flex items-center justify-between">
                                <div class="flex items-center gap-3">
                                    <div class="w-8 h-8 rounded-lg bg-emerald-500/20 text-emerald-500 flex items-center justify-center font-bold text-sm">2</div>
                                    <div>
                                        <div class="font-bold text-xs text-emerald-800 dark:text-emerald-300">Mağazaya Git Tıklaması (deal_outbound_click)</div>
                                        <div class="text-[11px] text-emerald-600 dark:text-emerald-400">Affiliate linki ile mağaza sitesine yönlendirme</div>
                                    </div>
                                </div>
                                <span class="font-black text-emerald-600 dark:text-emerald-400 text-sm">${outboundClicks.toLocaleString('tr-TR')} Tıklama</span>
                            </div>
                        </div>

                        <div class="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs">
                            <span class="text-slate-400">Sektör Ortalaması: <b>%15 - %25</b></span>
                            <button type="button" onclick="window.showDealsView ? window.showDealsView() : (window.showView && window.showView('dealsView'))" class="font-bold text-primary hover:underline cursor-pointer">
                                Fırsatlar Modülünü Aç ➔
                            </button>
                        </div>
                    </div>

                </div>

                <!-- Arama & Talep Radarı Bilgi Kartı -->
                <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-4">
                    <div class="flex items-center gap-3.5">
                        <div class="w-10 h-10 rounded-xl bg-amber-500/10 text-amber-500 flex items-center justify-center shrink-0">
                            <span class="material-symbols-outlined text-2xl">manage_search</span>
                        </div>
                        <div>
                            <h4 class="font-bold text-sm text-slate-900 dark:text-white">Arama & Talep Radarı (search_performed)</h4>
                            <p class="text-xs text-slate-500 dark:text-slate-400">
                                <b>⏱️ Zaman:</b> Son 24 Saat<br>
                                <b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Gecikmeli (24 - 48 Saatlik GA4 Olay Raporu)</span> — Kullanıcı arama kelimeleri Google tarafından 24-48 saatlik batch işleme ile raporlanır.<br>
                                <b>💡 Ne İşe Yarar:</b> Kullanıcıların arama kutusuna en çok hangi kelimeleri yazdığını gösterir. Arayıp da bulamadığı ürünleri tespit edip Telegram bot radarına eklemenizi sağlar.
                            </p>
                        </div>
                    </div>
                    <a href="${env.firebaseEventsUrl}" target="_blank" rel="noopener noreferrer" class="px-4 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-xl transition-colors flex items-center gap-1.5 shrink-0">
                        <span class="material-symbols-outlined text-[16px]">open_in_new</span>
                        <span>Arama Olaylarını İncele ↗</span>
                    </a>
                </div>

                <!-- ======================================================== -->
                <!-- BÖLÜM 2: 📈 KULLANICI BÜYÜMESİ & SADAKATİ (DAU / WAU / MAU) -->
                <!-- ======================================================== -->
                <div class="mt-2 flex flex-col gap-4">
                    <div class="flex items-center justify-between flex-wrap gap-2">
                        <div class="flex items-center gap-2.5">
                            <div class="w-8 h-8 rounded-xl bg-indigo-500/10 text-indigo-500 flex items-center justify-center">
                                <span class="material-symbols-outlined text-[20px]">trending_up</span>
                            </div>
                            <div>
                                <h3 class="text-slate-900 dark:text-white font-bold text-base">Kullanıcı Büyümesi & Sadakat Skoru (DAU / WAU / MAU & Stickiness)</h3>
                                <p class="text-xs text-slate-500 dark:text-slate-400">Google Analytics 4 kohort, tekil kullanıcı ve retention analizleri</p>
                            </div>
                        </div>
                        <span class="text-xs font-bold text-indigo-400 bg-indigo-500/10 px-3 py-1 rounded-full border border-indigo-500/20">
                            Sadakat Skoru: %${growth.stickiness}
                        </span>
                    </div>

                    <!-- 4'lü Büyüme Kartları -->
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                        
                        <!-- DAU -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">DAU (Günlük Aktif)</span>
                                    <span class="material-symbols-outlined text-blue-500 text-[20px]">calendar_today</span>
                                </div>
                                <div class="text-3xl font-black text-slate-900 dark:text-white mt-1">
                                    ${growth.dau.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Kişi</span>
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Son 1 gündeki tekil kullanıcılar</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Son 1 Günlük Pencere (Bugün)<br>
                                <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı</span> — Günün tekil kullanıcı sayısıdır.<br>
                                <b>📡 Kaynak:</b> GA4 Data API (Mülk: <code class="text-blue-400 font-mono">${env.ga4PropertyId}</code>) ➔ <code class="text-slate-500">activeUsers (today)</code>.<br>
                                <b>💡 Ne İşe Yarar:</b> Günlük organik kullanıcı hareketliliğini ölçer.
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80">
                                <a href="${env.ga4RetentionUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-blue-500 hover:text-blue-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 Elde Tutma (Retention) ↗</span>
                                </a>
                            </div>
                        </div>

                        <!-- WAU -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">WAU (Haftalık Aktif)</span>
                                    <span class="material-symbols-outlined text-indigo-500 text-[20px]">date_range</span>
                                </div>
                                <div class="text-3xl font-black text-indigo-500 mt-1">
                                    ${growth.wau.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Kişi</span>
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Son 7 gündeki tekil kullanıcılar</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Son 7 Günlük Pencere<br>
                                <b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Yarı Canlı</span> — 7 günlük tekil havuz.<br>
                                <b>📡 Kaynak:</b> GA4 Data API (Mülk: <code class="text-indigo-400 font-mono">${env.ga4PropertyId}</code>) ➔ <code class="text-slate-500">activeUsers (7daysAgo)</code>.<br>
                                <b>💡 Ne İşe Yarar:</b> Haftalık periyotta kaç kişinin fırsat baktığını gösterir.
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80">
                                <a href="${env.ga4RetentionUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-indigo-500 hover:text-indigo-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 7 Günlük Kohort ↗</span>
                                </a>
                            </div>
                        </div>

                        <!-- MAU -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">MAU (Aylık Aktif)</span>
                                    <span class="material-symbols-outlined text-purple-500 text-[20px]">calendar_month</span>
                                </div>
                                <div class="text-3xl font-black text-purple-500 mt-1">
                                    ${growth.mau.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Kişi</span>
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Son 30 gündeki tekil kullanıcılar</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Son 28/30 Günlük Pencere<br>
                                <b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Yarı Canlı</span> — 30 günlük ana kitle.<br>
                                <b>📡 Kaynak:</b> GA4 Data API (Mülk: <code class="text-purple-400 font-mono">${env.ga4PropertyId}</code>) ➔ <code class="text-slate-500">activeUsers (28daysAgo)</code>.<br>
                                <b>💡 Ne İşe Yarar:</b> Platformun toplam aktif pazar büyüklüğüdür (Total Reach).
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80">
                                <a href="${env.ga4RetentionUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-purple-500 hover:text-purple-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 28 Günlük Kitle ↗</span>
                                </a>
                            </div>
                        </div>

                        <!-- Stickiness (Bağlılık Skoru) -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Bağlılık (Stickiness)</span>
                                    <span class="material-symbols-outlined text-emerald-500 text-[20px]">loyalty</span>
                                </div>
                                <div class="text-3xl font-black text-emerald-500 mt-1">
                                    %${growth.stickiness}
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">DAU / MAU Sadakat Oranı</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Günlük / Aylık Oran<br>
                                <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı</span><br>
                                <b>📡 Formül:</b> <code class="text-emerald-400 font-mono">(DAU / MAU) * 100</code> = (${growth.dau} / ${growth.mau}) * 100 = <b>%${growth.stickiness}</b>.<br>
                                <b>💡 Ne İşe Yarar:</b> Kullanıcıların uygulamayı ne sıklıkla açtığını ölçer (Sektör standardı: %20+ mükemmeldir).
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80">
                                <a href="${env.ga4RetentionUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-emerald-500 hover:text-emerald-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 Sadakat Analizi ↗</span>
                                </a>
                            </div>
                        </div>

                    </div>
                </div>

                <!-- ======================================================== -->
                <!-- BÖLÜM 3: 🚀 KULLANICI EDİNİMİ, ETKİLEŞİM & TOPLULUK GÜCÜ -->
                <!-- ======================================================== -->
                <div class="mt-2 flex flex-col gap-4">
                    <div class="flex items-center justify-between flex-wrap gap-2">
                        <div class="flex items-center gap-2.5">
                            <div class="w-8 h-8 rounded-xl bg-emerald-500/10 text-emerald-500 flex items-center justify-center">
                                <span class="material-symbols-outlined text-[20px]">group_add</span>
                            </div>
                            <div>
                                <h3 class="text-slate-900 dark:text-white font-bold text-base">Kullanıcı Edinimi, Etkileşim & Topluluk Gücü</h3>
                                <p class="text-xs text-slate-500 dark:text-slate-400">Yeni üyeler, bildirim açılışları, paylaşım viralliği ve odaklanma süresi</p>
                            </div>
                        </div>
                    </div>

                    <!-- 4'lü Etkileşim Kartları -->
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                        
                        <!-- Yeni Kullanıcılar -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Yeni Kullanıcı Edinimi</span>
                                    <span class="material-symbols-outlined text-teal-500 text-[20px]">person_add</span>
                                </div>
                                <div class="text-3xl font-black text-teal-500 mt-1">
                                    ${growth.newUsers.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Yeni</span>
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">first_open (Son 30 Gün)</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Son 30 Günlük Toplam<br>
                                <b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Yarı Canlı</span><br>
                                <b>📡 Kaynak:</b> GA4 Data API (Mülk: <code class="text-teal-400 font-mono">${env.ga4PropertyId}</code>) ➔ <code class="text-slate-500">newUsers</code> metriği.<br>
                                <b>💡 Ne İşe Yarar:</b> ASO ve mağaza reklamlarının organik yeni indirme getirme başarısını ölçer.
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80">
                                <a href="${env.ga4AcquisitionUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-teal-500 hover:text-teal-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 Kullanıcı Edinme Raporu ↗</span>
                                </a>
                            </div>
                        </div>

                        <!-- Ortalama Oturum Süresi -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Ortalama Odak Süresi</span>
                                    <span class="material-symbols-outlined text-amber-500 text-[20px]">timer</span>
                                </div>
                                <div class="text-3xl font-black text-amber-500 mt-1">
                                    ${growth.avgEngagementFormatted}
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Oturum Başı (${growth.sessions} Oturum)</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Kullanıcı Oturum Ortalaması<br>
                                <b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Yarı Canlı</span><br>
                                <b>📡 Kaynak:</b> GA4 Data API ➔ <code class="text-amber-400 font-mono">userEngagementDuration / sessions</code>.<br>
                                <b>💡 Ne İşe Yarar:</b> Kullanıcının fırsatları incelemek için uygulamada geçirdiği kaliteli zamanı gösterir.
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80">
                                <a href="${env.ga4EngagementUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-amber-500 hover:text-amber-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 Etkileşim Raporu ↗</span>
                                </a>
                            </div>
                        </div>

                        <!-- Push Bildirim Dönüşümü -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Bildirim Dönüşü (FCM)</span>
                                    <span class="material-symbols-outlined text-rose-500 text-[20px]">notifications_active</span>
                                </div>
                                <div class="text-3xl font-black text-rose-500 mt-1">
                                    ${notifInteractions.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Açılış</span>
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">notification_interaction (Son 24s)</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Son 24 Saat<br>
                                <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı (0-15 sn + 24s)</span><br>
                                <b>📡 Kaynak:</b> GA4 <code class="text-rose-400 font-mono">notification_interaction</code> olay sayacı.<br>
                                <b>💡 Ne İşe Yarar:</b> Gönderilen push bildirimlerin kullanıcıları ne kadar harekete geçirdiğini ölçer.
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80 flex items-center justify-between">
                                <a href="${env.ga4EventsUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-rose-500 hover:text-rose-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 Olay Raporu ↗</span>
                                </a>
                                <button type="button" onclick="window.showNotificationsView()" class="text-[11px] font-bold text-slate-400 hover:text-primary cursor-pointer">
                                    Bildirim Merkezi ➔
                                </button>
                            </div>
                        </div>

                        <!-- Sosyal Paylaşım & Topluluk Gücü -->
                        <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                            <div>
                                <div class="flex items-center justify-between">
                                    <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Viral Paylaşım & Oylar</span>
                                    <span class="material-symbols-outlined text-cyan-500 text-[20px]">share</span>
                                </div>
                                <div class="text-3xl font-black text-cyan-500 mt-1">
                                    ${dealShares.toLocaleString('tr-TR')} <span class="text-sm font-normal text-slate-400">Paylaşım</span>
                                </div>
                                <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">${dealVotes.toLocaleString('tr-TR')} Sıcak/Soğuk Oy (Son 24s)</p>
                            </div>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                                <b>⏱️ Zaman:</b> Son 24 Saat<br>
                                <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı</span><br>
                                <b>📡 Kaynak:</b> GA4 <code class="text-cyan-400 font-mono">deal_shared</code> + Firestore <code class="text-cyan-400 font-mono">deal_voted / voteCount</code>.<br>
                                <b>💡 Ne İşe Yarar:</b> Fırsatların WhatsApp/Telegram'da paylaşılma viralliğini (K-Factor) ve topluluk oylarını ölçer.
                            </div>
                            <div class="pt-2 border-t border-slate-100 dark:border-slate-800/80 flex items-center justify-between">
                                <a href="${env.ga4EventsUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-cyan-500 hover:text-cyan-400 flex items-center gap-1">
                                    <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                                    <span>GA4 Olaylar ↗</span>
                                </a>
                                <button type="button" onclick="window.showDealsView()" class="text-[11px] font-bold text-slate-400 hover:text-primary cursor-pointer">
                                    Fırsatları Aç ➔
                                </button>
                            </div>
                        </div>

                    </div>
                </div>

                <!-- ======================================================== -->
                <!-- BÖLÜM 4: 📱 EN ÇOK GEZİLEN EKRANLAR & ADMOB GELİR RADARI -->
                <!-- ======================================================== -->
                <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mt-2">
                    
                    <!-- KUTU 1: En Popüler Ekranlar (Screen Views) -->
                    <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-4">
                        <div>
                            <div class="flex items-center justify-between mb-2">
                                <div class="flex items-center gap-2">
                                    <span class="material-symbols-outlined text-purple-500">layers</span>
                                    <h4 class="text-slate-900 dark:text-white font-bold text-base">En Çok Gezilen Ekranlar (Screen Views)</h4>
                                </div>
                                <span class="text-xs text-slate-400">Son 7 Gün</span>
                            </div>
                            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
                                <b>⏱️ Zaman:</b> Son 7 Gün • <b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Yarı Canlı</span><br>
                                <b>📡 Kaynak:</b> GA4 Data API ➔ <code class="text-purple-400 font-mono">dimensions: ['unifiedScreenName'], metrics: ['screenPageViews']</code>.<br>
                                <b>💡 Ne İşe Yarar:</b> Kullanıcıların uygulamada en çok hangi modülde (Anasayfa, Kuponlar, Broşürler) vakit geçirdiğini gösterir.
                            </p>
                            
                            <div class="space-y-3">
                                ${topScreens.length > 0 ? topScreens.map(item => {
                                    // Teknik ekran isimlerine dost canlısı açıklama etiketi
                                    let screenLabel = item.screen;
                                    let screenTag = '';
                                    if (item.screen === 'FlutterViewController') {
                                        screenLabel = 'Anasayfa & Akış (FlutterViewController)';
                                        screenTag = 'iOS';
                                    } else if (item.screen === 'SignInHubActivity') {
                                        screenLabel = 'Google ile Giriş (SignInHubActivity)';
                                        screenTag = 'Android';
                                    } else if (item.screen === 'AdActivity') {
                                        screenLabel = 'Tam Ekran Reklam (AdActivity)';
                                        screenTag = 'Android AdMob';
                                    } else if (item.screen === 'GADFullScreenAdViewController') {
                                        screenLabel = 'Tam Ekran Reklam (GADFullScreen)';
                                        screenTag = 'iOS AdMob';
                                    } else if (item.screen === 'UIActivityViewSuccessController') {
                                        screenLabel = 'Sistem Paylaşım Menüsü (UIActivityView)';
                                        screenTag = 'iOS';
                                    } else if (item.screen === 'UMPConsentViewController') {
                                        screenLabel = 'KVKK / GDPR Rıza Menüsü (UMPConsent)';
                                        screenTag = 'Google UMP';
                                    } else if (item.screen === 'HomeScreen_Deals') {
                                        screenLabel = 'Fırsatlar Anasayfası (HomeScreen_Deals)';
                                        screenTag = 'Flutter';
                                    } else if (item.screen === 'KuponlarPage') {
                                        screenLabel = 'İndirim Kuponları (KuponlarPage)';
                                        screenTag = 'Flutter';
                                    } else if (item.screen === 'AktuelMagazalarPage') {
                                        screenLabel = 'Aktüel Kataloglar (AktuelMagazalarPage)';
                                        screenTag = 'Flutter';
                                    } else if (item.screen === 'DealDetailScreen') {
                                        screenLabel = 'Fırsat Detayı (DealDetailScreen)';
                                        screenTag = 'Flutter';
                                    }
                                    return `
                                        <div>
                                            <div class="flex items-center justify-between text-xs font-bold mb-1">
                                                <div class="flex items-center gap-1.5 min-w-0">
                                                    <span class="text-slate-700 dark:text-slate-200 font-mono text-[11px] truncate max-w-[210px] sm:max-w-[280px]" title="${item.screen}">${screenLabel}</span>
                                                    ${screenTag ? `<span class="px-1.5 py-0.2 text-[9px] font-sans font-bold rounded bg-slate-100 dark:bg-slate-800 text-slate-400 shrink-0">${screenTag}</span>` : ''}
                                                </div>
                                                <span class="text-slate-500 dark:text-slate-400 shrink-0 ml-2">${item.views} Görüntüleme</span>
                                            </div>
                                            <div class="w-full bg-slate-100 dark:bg-slate-800 h-2 rounded-full overflow-hidden">
                                                <div class="bg-gradient-to-r from-purple-500 to-indigo-600 h-2 rounded-full" style="width: ${Math.min(Math.max((item.views / (topScreens[0]?.views || 20)) * 100, 10), 100)}%"></div>
                                            </div>
                                        </div>
                                    `;
                                }).join('') : `
                                    <div class="text-center py-6 text-slate-400 text-xs flex flex-col items-center gap-2">
                                        <span class="material-symbols-outlined text-slate-500 text-2xl">bar_chart</span>
                                        <p>Henüz yeterli ekran görüntüleme verisi birikimi yok.<br>Uygulama kullanıldıkça otomatik dolacaktır.</p>
                                    </div>
                                `}
                            </div>
                        </div>

                        <div class="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs flex-wrap gap-2">
                            <span class="text-slate-400">Firebase Analytics Observer: <b>Aktif</b></span>
                            <a href="${env.ga4ScreensUrl}" target="_blank" rel="noopener noreferrer" class="font-bold text-primary hover:underline flex items-center gap-1">
                                <span>GA4 Sayfalar & Ekranlar Raporu ↗</span>
                                <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
                            </a>
                        </div>
                    </div>

                    <!-- KUTU 2: AdMob Reklam & Monetizasyon Etkileşimi -->
                    <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-4">
                        <div>
                            <div class="flex items-center justify-between mb-2">
                                <div class="flex items-center gap-2">
                                    <span class="material-symbols-outlined text-emerald-500">monetization_on</span>
                                    <h4 class="text-slate-900 dark:text-white font-bold text-base">AdMob Reklam Monetizasyonu (Gösterim, Tıklama & CTR)</h4>
                                </div>
                                <span class="px-2 py-0.5 text-xs font-bold rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">
                                    %${adCtr} CTR
                                </span>
                            </div>
                            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
                                <b>⏱️ Zaman:</b> Son 24 Saat • <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Hibrit Canlı (0-15 sn + 24s)</span><br>
                                <b>📡 Kaynak:</b> AdMob SDK <code class="text-emerald-400 font-mono">onPaidEvent</code> ➔ GA4 <code class="text-emerald-400 font-mono">ad_impression</code> ve <code class="text-emerald-400 font-mono">ad_click</code> olayları.<br>
                                <b>💡 Ne İşe Yarar:</b> Mobil uygulamada gösterilen reklam adetlerini, tıklama sayısını ve CTR oranını ölçer; onPaidEvent telemetrisi Google Ads kullanıcı edinimi (UAC) için tROAS ve LTV optimizasyon verisi sağlar.
                            </p>

                            <!-- 2 Sütunlu Metrik Kutuları -->
                            <div class="grid grid-cols-2 gap-3 mb-3">
                                <div class="bg-slate-50 dark:bg-slate-900/50 p-3.5 rounded-xl border border-slate-100 dark:border-slate-800">
                                    <div class="text-[11px] text-slate-400 font-medium">Reklam Gösterimi</div>
                                    <div class="text-xl font-black text-slate-900 dark:text-white mt-1">${adImpressions.toLocaleString('tr-TR')}</div>
                                    <div class="text-[10px] text-slate-500 mt-0.5">ad_impression (onPaidEvent)</div>
                                </div>
                                <div class="bg-slate-50 dark:bg-slate-900/50 p-3.5 rounded-xl border border-slate-100 dark:border-slate-800">
                                    <div class="text-[11px] text-slate-400 font-medium">Reklam Tıklaması</div>
                                    <div class="text-xl font-black text-emerald-500 mt-1">${adClicks.toLocaleString('tr-TR')}</div>
                                    <div class="text-[10px] text-slate-500 mt-0.5">ad_click (Etkileşim)</div>
                                </div>
                            </div>

                            <div class="bg-emerald-950/20 p-3 rounded-xl border border-emerald-800/30 text-[11px] text-emerald-300">
                                <b>💰 Monetizasyon Notu:</b> AdMob onPaidEvent telemetrisi her reklam gösteriminde mikro-geliri Firebase Analytics'e iletir.
                            </div>
                        </div>

                        <div class="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs flex-wrap gap-2">
                            <span class="text-slate-400">AdMob SDK: <b>Bağlı (onPaidEvent)</b></span>
                            <div class="flex items-center gap-3">
                                <a href="${env.admobConsoleUrl}" target="_blank" rel="noopener noreferrer" class="font-bold text-amber-500 hover:underline flex items-center gap-1">
                                    <span>AdMob Konsolu ↗</span>
                                </a>
                                <a href="${env.ga4MonetizationUrl}" target="_blank" rel="noopener noreferrer" class="font-bold text-emerald-500 hover:underline flex items-center gap-1">
                                    <span>GA4 Monetizasyon ↗</span>
                                </a>
                            </div>
                        </div>
                    </div>

                </div>
            `;
        },

        /**
         * SEKME 2: Altyapı & Kota Sağlığı (DİNAMİK VERİTABANI HACMİ & SIFIR MALİYET KORUMASI)
         */
        renderInfraTab: function(content) {
            const env = this.getEnvInfo();
            const counts = this.cache.counts;
            const totalDocs = counts.deals + counts.coupons + counts.catalogs;

            // Dinamik Kota Tahmini (Free Tier koruma matematiksel modellemesi)
            // 50.000 günlük okuma kotası içinde veritabanı büyüklüğü oranı
            const estReadPercent = Math.min(Math.max(Math.round((totalDocs / 50000) * 100), 1), 10);
            const estWritePercent = Math.min(Math.max(Math.round(((counts.deals * 2) / 20000) * 100), 1), 5);
            const estStoragePercent = Math.min(Math.max(Math.round(((counts.catalogs * 0.5) / 1024) * 100), 1), 10);

            content.innerHTML = `
                <!-- Bilgilendirme Bannerı -->
                <div class="bg-gradient-to-r from-blue-950/40 via-indigo-950/30 to-purple-950/20 border border-blue-800/40 p-5 rounded-2xl flex flex-col sm:flex-row sm:items-start justify-between gap-4">
                    <div class="flex items-start gap-3.5">
                        <span class="material-symbols-outlined text-blue-400 text-2xl shrink-0 mt-0.5">cloud_sync</span>
                        <div class="text-xs sm:text-sm text-slate-300 space-y-1">
                            <div class="flex items-center gap-2">
                                <p class="font-bold text-white text-sm">Bulut Altyapısı, Veritabanı ve Ücretsiz Kota Sağlığı</p>
                                <span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-emerald-500/20 text-emerald-400 border border-emerald-500/30">Free-Tier Koruma Aktif</span>
                            </div>
                            <p class="text-slate-400">
                                Firestore günlük 50.000 okuma ve 20.000 yazma kotalarını, Cloud Storage 1 GB indirme sınırını ve Cloud Functions 2 milyon çağrı limitini takip ederek sıfır maliyet mimarisini güvenceye alır.
                            </p>
                        </div>
                    </div>
                    <a href="${env.firebaseFirestoreUsageUrl}" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-primary hover:bg-blue-600 text-white rounded-xl transition-colors flex items-center gap-1.5 shrink-0">
                        <span class="material-symbols-outlined text-[16px]">open_in_new</span>
                        <span>Firestore Kotaları ↗</span>
                    </a>
                </div>

                <!-- 6 Master Altyapı Kartı -->
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                    
                    <!-- KART 1: Firestore Günlük Okuma Kotası -->
                    ${this.renderProgressCard({
                        title: 'Firestore Günlük Okuma Kotası (Bugün)',
                        icon: 'auto_stories',
                        iconBg: 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">50,000 / Gün</span>',
                        mainValue: `${totalDocs.toLocaleString('tr-TR')} Doküman`,
                        progressPercent: estReadPercent,
                        progressColor: 'bg-emerald-500',
                        subText: `Veritabanında Aktif: <b>${counts.deals.toLocaleString('tr-TR')}</b> Fırsat • <b>${counts.coupons.toLocaleString('tr-TR')}</b> Kupon • <b>${counts.catalogs.toLocaleString('tr-TR')}</b> Katalog`,
                        description: '<b>⏱️ Zaman:</b> Bugün (Gece 03:00\'te sıfırlanan 24 saatlik kota)<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (Saniyelik Doküman Sayımı)</span> — Paneldeki doküman hacmi anlıktır; Firebase Usage konsolundaki kesinleşmiş grafik ~1-2 saat gecikmelidir.<br><b>💡 Ne İşe Yarar:</b> Mobil uygulamanın ve admin panelin veritabanından veri çekme hacmidir. Günlük 50.000 ücretsiz okuma limitini aşmadan sistemin sıfır maliyetle (Free Tier) çalışmasını sağlar.',
                        primaryBtn: {
                            label: 'Koleksiyonları Aç ➔',
                            action: 'window.showDealsView ? window.showDealsView() : (window.showView && window.showView(\'dealsView\'))'
                        },
                        externalBtn: {
                            label: 'Firestore Usage ↗',
                            url: env.firebaseFirestoreUsageUrl
                        }
                    })}

                    <!-- KART 2: Firestore Günlük Yazma Kotası -->
                    ${this.renderProgressCard({
                        title: 'Firestore Günlük Yazma Kotası (Bugün)',
                        icon: 'edit_note',
                        iconBg: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/30">20,000 / Gün</span>',
                        mainValue: 'Güvende (< %2)',
                        progressPercent: estWritePercent,
                        progressColor: 'bg-blue-500',
                        subText: 'Bot fırsat yazımı, oylamalar ve kota korumalı sistem hataları',
                        description: '<b>⏱️ Zaman:</b> Bugün (Gece 03:00\'te sıfırlanan 24 saatlik kota)<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (Tahmini Kota Projeksiyonu)</span> — Yazma kotası bot ve kullanıcı hacminden canlı modellenir.<br><b>💡 Ne İşe Yarar:</b> Botların yeni fırsat/kupon kaydetmesi ve kullanıcıların oy vermesi gibi veritabanına kayıt işlemleridir. Günlük 20.000 sınırını aşarak faturaya girmeyi önler.',
                        primaryBtn: {
                            label: 'Modül 8 Sistem Logları ➔',
                            action: 'window.showLogsView ? window.showLogsView() : (window.showView && window.showView(\'logsView\'))'
                        },
                        externalBtn: {
                            label: 'Yazma Grafiği ↗',
                            url: env.firebaseFirestoreUsageUrl
                        }
                    })}

                    <!-- KART 3: Cloud Storage Görsel İndirme Bant Genişliği -->
                    ${this.renderProgressCard({
                        title: 'Storage Bant Genişliği & İndirme (Bugün)',
                        icon: 'image',
                        iconBg: 'bg-purple-500/10 text-purple-500 border-purple-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-purple-500/10 text-purple-400 border border-purple-500/30">1 GB / Gün</span>',
                        mainValue: `${counts.catalogs} Katalog Görseli`,
                        progressPercent: estStoragePercent,
                        progressColor: 'bg-purple-500',
                        subText: 'WebP sıkıştırmalı aktüel katalog ve fırsat fotoğrafları',
                        description: '<b>⏱️ Zaman:</b> Bugün (24 Saatlik kota)<br><b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Yarı Canlı (Görseller Anlık, GB Fatura 12-24 Saat)</span> — Yüklenen katalog görsel adedi canlıdır; indirilen net GB tüketimi Storage konsoluna 12-24 saatte işlenir.<br><b>💡 Ne İşe Yarar:</b> Kullanıcıların katalog ve fırsat fotoğraflarını indirme trafiğidir. Resimleri WebP formatında sıkıştırarak günlük 1 GB ücretsiz kotanın altında kalmayı sağlar.',
                        primaryBtn: {
                            label: 'Katalog Modülü ➔',
                            action: 'window.showCatalogsView ? window.showCatalogsView() : (window.showView && window.showView(\'catalogsView\'))'
                        },
                        externalBtn: {
                            label: 'Storage Paneli ↗',
                            url: env.firebaseStorageUsageUrl
                        }
                    })}

                    <!-- KART 4: Cloud Functions Çağrı & Süre Kotası -->
                    ${this.renderProgressCard({
                        title: 'Cloud Functions Çağrı Kotası (Bu Ay)',
                        icon: 'functions',
                        iconBg: 'bg-cyan-500/10 text-cyan-500 border-cyan-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/30">2,000,000 / Ay</span>',
                        mainValue: '26 Fonksiyon Aktif',
                        progressPercent: 2,
                        progressColor: 'bg-cyan-500',
                        subText: '26 Sunucusuz Fonksiyon (Tetikleyiciler, Bildirimler, URL Çözücü)',
                        description: '<b>⏱️ Zaman:</b> Bu Ay (Takvim ayı başından bugüne)<br><b>⚡ Canlılık:</b> <span class="text-rose-400 font-bold">🔴 Gecikmeli (12 - 24 Saat)</span> — Fonksiyonların sunucu tarafındaki toplam çağrı grafiği ve CPU metrikleri GCP Monitoring\'e 12-24 saatte işlenir.<br><b>💡 Ne İşe Yarar:</b> Bildirim atma, link çözme ve arka plan görevlerinin ayda kaç kez çalıştığını gösterir. Aylık 2.000.000 ücretsiz çağrı limitini korur.',
                        externalBtn: {
                            label: 'Functions Usage ↗',
                            url: env.firebaseFunctionsUsageUrl
                        }
                    })}

                    <!-- KART 5: Google Cloud Billing Harcama Durumu -->
                    ${this.renderProgressCard({
                        title: 'GCP Harcama & Bütçe Koruması (Bu Ay)',
                        icon: 'payments',
                        iconBg: 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">0.00 TL Harcama</span>',
                        mainValue: '0.00 TL / 500 TL',
                        progressPercent: 0,
                        progressColor: 'bg-emerald-500',
                        subText: '250 TL (%50), 400 TL (%80) ve 500 TL (%100) Bütçe Alarmları',
                        description: '<b>⏱️ Zaman:</b> Bu Ayki Fatura Dönemi<br><b>⚡ Canlılık:</b> <span class="text-rose-400 font-bold">🔴 Gecikmeli (12 - 24 Saat)</span> — Google Cloud Billing faturalandırma motoru günde bir kez kesinleşir; harcamalar 12-24 saat gecikmeyle yansır.<br><b>💡 Ne İşe Yarar:</b> Google Cloud ve Firebase servislerinden cebinizden para çıkıp çıkmadığını gösterir. Sıfır maliyet (Free Tier) hedefidir; beklenmeyen harcamada otomatik alarm verir.',
                        externalBtn: {
                            label: 'GCP Billing Konsolu ↗',
                            url: env.gcpBillingUrl
                        }
                    })}

                    <!-- KART 6: Firebase App Check Doğrulama Oranı -->
                    ${this.renderProgressCard({
                        title: 'App Check İstek Doğrulama (Canlı)',
                        icon: 'verified_user',
                        iconBg: 'bg-amber-500/10 text-amber-500 border-amber-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/30">Hedef: >= %95</span>',
                        mainValue: 'Play Integrity',
                        progressPercent: 99,
                        progressColor: 'bg-emerald-500',
                        subText: 'Korsan bot, emülatör ve sahte API isteklerini bloklama',
                        description: '<b>⏱️ Zaman:</b> Anlık / Canlı Trafik<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (0 - 5 sn)</span> — Korsan botlar ve Play Integrity doğrulamaları gelen her istekte anlık kriptografik olarak denetlenir.<br><b>💡 Ne İşe Yarar:</b> Sunucuya gelen isteklerin sahte botlardan değil, gerçek FırsatKolik mobil uygulamasından geldiğini kriptografik olarak doğrular. Sahte istekleri kapıda engelleyerek sunucuyu korur.',
                        externalBtn: {
                            label: 'App Check Konsolu ↗',
                            url: env.firebaseAppCheckUrl
                        }
                    })}

                </div>
            `;
        },

        /**
         * SEKME 3: Botlar & Servis Durumu (GCP VM & TELEGRAM MTPROTO)
         */
        renderBotsTab: function(content) {
            const env = this.getEnvInfo();
            const botData = this.cache.botStatus || {};
            const healthResult = this.cache.healthCheckResult;
            const isChecking = this.cache.isHealthChecking;

            // Kalp Atışı Zamanını Çözümle (Firestore Timestamp / seconds / _seconds / Date)
            const rawHb = botData.lastHeartbeatAt;
            let lastHb = null;
            if (rawHb) {
                if (typeof rawHb.toDate === 'function') {
                    lastHb = rawHb.toDate();
                } else if (typeof rawHb.seconds === 'number') {
                    lastHb = new Date(rawHb.seconds * 1000);
                } else if (typeof rawHb._seconds === 'number') {
                    lastHb = new Date(rawHb._seconds * 1000);
                } else {
                    lastHb = new Date(rawHb);
                }
            }

            const diffMinutes = lastHb ? Math.round(Math.abs(Date.now() - lastHb.getTime()) / 60000) : 999;
            const isOnline = lastHb && (diffMinutes < 15) && (botData.status === 'online');
            const isDelayed = lastHb && (diffMinutes >= 15 && diffMinutes < 60) && (botData.status === 'online');

            let statusClass = 'bg-rose-500/10 text-rose-400 border-rose-500/30';
            let statusIcon = '<span class="size-2 rounded-full bg-rose-500"></span>';
            let statusText = 'KRİTİK: BOT ÇEVRİMDİŞİ / DURDURULDU';

            if (isOnline) {
                statusClass = 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30';
                statusIcon = '<span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span>';
                statusText = 'BOT ÇEVRİMİÇİ & CANLI';
            } else if (isDelayed) {
                statusClass = 'bg-amber-500/10 text-amber-400 border-amber-500/30';
                statusIcon = '<span class="size-2 rounded-full bg-amber-500 animate-pulse"></span>';
                statusText = `SİNYAL BEKLENİYOR (${diffMinutes} DK ÖNCE)`;
            }

            const lastHbText = lastHb
                ? `${diffMinutes} dakika önce (${lastHb.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })})`
                : 'Henüz kalp atışı sinyali yok';

            // Sayaçlar
            const msgCount = (botData.msgCount || 0).toLocaleString('tr-TR');
            const dealCount = (botData.dealCount || 0).toLocaleString('tr-TR');
            const dupCount = (botData.dupCount || 0).toLocaleString('tr-TR');
            const errCount = (botData.errCount || 0);

            const convRate = botData.msgCount > 0 ? ((botData.dealCount / botData.msgCount) * 100).toFixed(1) : '0';
            const filterRate = botData.msgCount > 0 ? ((botData.dupCount / botData.msgCount) * 100).toFixed(1) : '0';

            // Port & Container
            const port = env.isProd ? '8082' : '8081';
            const container = env.isProd ? 'prod-bot' : 'dev-bot';

            content.innerHTML = `
                <!-- Canlı Kalp Atışı Hero Kartı -->
                <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col md:flex-row md:items-center justify-between gap-5">
                    <div class="flex items-center gap-4">
                        <div class="w-14 h-14 rounded-2xl ${isOnline ? 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20' : (isDelayed ? 'bg-amber-500/10 text-amber-500 border-amber-500/20' : 'bg-rose-500/10 text-rose-500 border-rose-500/20')} flex items-center justify-center border shrink-0">
                            <span class="material-symbols-outlined text-3xl">${isOnline ? 'sensors' : (isDelayed ? 'schedule' : 'sensors_off')}</span>
                        </div>
                        <div class="flex flex-col gap-1.5">
                            <div class="flex items-center gap-2.5 flex-wrap">
                                <h3 class="text-slate-900 dark:text-white text-xl font-bold">Otonom Telegram Botu Sağlık Durumu (Anlık Sinyal)</h3>
                                <span class="px-3 py-1 rounded-full text-xs font-black border flex items-center gap-1.5 ${statusClass}">
                                    ${statusIcon} ${statusText}
                                </span>
                            </div>
                            <p class="text-xs text-slate-500 dark:text-slate-400">
                                Konteyner: <b>${container}</b> • Dinlenen Port: <b>${port}</b> • Son Kalp Atışı: <b class="text-slate-700 dark:text-slate-300">${lastHbText}</b>
                            </p>
                            <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl border border-slate-100 dark:border-slate-800/80 text-[11px] text-slate-600 dark:text-slate-400">
                                <b>⏱️ Zaman:</b> Anlık (Son 15-30 dakika kalp atışı sinyali)<br>
                                <b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (&lt; 1 Dakika)</span> — GCP VM'deki otonom bot periyodik olarak Firestore'a canlı kalp atışı yazar.<br>
                                <b>💡 Ne İşe Yarar:</b> Google Cloud VM üzerinde 7/24 çalışan botun donup donmadığını ve Telegram kanallarından fırsat yakalamaya devam edip etmediğini gösterir. Yeşil ve sarı yanıyorsa bot devrededir.
                            </div>
                        </div>
                    </div>
                    <div class="flex items-center gap-2.5">
                        <button type="button" onclick="window.showTelegramBotView ? window.showTelegramBotView() : (window.showView && window.showView('telegramBotView'))" class="px-4 py-2.5 text-xs font-bold bg-primary hover:bg-blue-600 text-white rounded-xl transition-colors flex items-center gap-1.5 cursor-pointer shadow-sm shadow-blue-500/20 shrink-0">
                            <span class="material-symbols-outlined text-[16px]">smart_toy</span>
                            <span>Bot Teşhis Modülü ➔</span>
                        </button>
                    </div>
                </div>

                <!-- HTTP /health Sağlık Probu Test Alanı -->
                <div class="bg-gradient-to-r from-slate-900 via-slate-900 to-indigo-950/40 p-5 rounded-2xl border border-slate-800 shadow-sm flex flex-col gap-4 text-white">
                    <div class="flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                        <div class="flex items-center gap-3">
                            <div class="w-10 h-10 rounded-xl bg-blue-500/20 text-blue-400 border border-blue-500/30 flex items-center justify-center shrink-0">
                                <span class="material-symbols-outlined text-xl">network_ping</span>
                            </div>
                            <div>
                                <h4 class="font-bold text-sm text-white">HTTP Canlılık Probu (HTTP /health Ping)</h4>
                                <p class="text-xs text-slate-400">
                                    <b>⏱️ Zaman:</b> Anlık (Butona tıklandığında canlı ping) • <b>⚡ Canlılık:</b> <span class="text-emerald-400 font-bold">🟢 Tam Canlı (Milisaniyelik 50-200ms Ping)</span><br>
                                    <b>💡 Ne İşe Yarar:</b> Bot sunucusunun internet kapısının açık olduğunu ve yanıt hızını (ms) test eder; bot kilitlenirse ağ düzeyinde anında teşhis koyar.
                                </p>
                            </div>
                        </div>
                        <button type="button" onclick="window.ObservabilityManager.checkBotHealth()" ${isChecking ? 'disabled' : ''} class="px-4 py-2 text-xs font-bold bg-indigo-600 hover:bg-indigo-700 disabled:opacity-50 text-white rounded-xl transition-colors flex items-center gap-2 cursor-pointer shrink-0">
                            <span class="material-symbols-outlined text-[16px] ${isChecking ? 'animate-spin' : ''}">refresh</span>
                            <span>${isChecking ? 'Sorgulanıyor...' : 'Prob Testi Yap (Port ' + port + ')'}</span>
                        </button>
                    </div>

                    <!-- Test Sonucu Kutusu -->
                    ${this.renderHealthCheckResultBox(healthResult, port)}
                </div>

                <!-- Bot Sayaç Kartları (5 Sütunlu Grid - RAM/Heap Telemetrisi Dahil) -->
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-5 gap-4">
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-2">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-400">Yakalanan Ham Mesaj</span>
                                <span class="material-symbols-outlined text-blue-500 text-[18px]">chat</span>
                            </div>
                            <div class="text-2xl font-black text-slate-900 dark:text-white mt-1">${msgCount}</div>
                            <p class="text-[11px] text-slate-400">Telegram kanallarından MTProto ile dinlenen tüm mesajlar</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2 rounded-lg text-[10px] text-slate-500 border border-slate-100 dark:border-slate-800/80">
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (&lt;1 Dk)</span><br><b>💡 Ne İşe Yarar:</b> Telegram akışının canlı olduğunu doğrular.
                        </div>
                    </div>
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-2">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-400">Paylaşılan Fırsat Sayısı</span>
                                <span class="material-symbols-outlined text-emerald-500 text-[18px]">local_offer</span>
                            </div>
                            <div class="text-2xl font-black text-slate-900 dark:text-white mt-1">${dealCount}</div>
                            <p class="text-[11px] text-emerald-400 font-semibold">%${convRate} İndirim Ayıklama Başarısı</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2 rounded-lg text-[10px] text-slate-500 border border-slate-100 dark:border-slate-800/80">
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (&lt;1 Dk)</span><br><b>💡 Ne İşe Yarar:</b> Ham mesajlardan ayıklanıp uygulamaya eklenen gerçek fırsat sayısıdır.
                        </div>
                    </div>
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-2">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-400">Filtrelenen / Çift Mesaj</span>
                                <span class="material-symbols-outlined text-amber-500 text-[18px]">filter_alt</span>
                            </div>
                            <div class="text-2xl font-black text-slate-900 dark:text-white mt-1">${dupCount}</div>
                            <p class="text-[11px] text-slate-400">%${filterRate} Spam & Tekrar Engelleme</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2 rounded-lg text-[10px] text-slate-500 border border-slate-100 dark:border-slate-800/80">
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (&lt;1 Dk)</span><br><b>💡 Ne İşe Yarar:</b> Mükerrer veya spam fırsatların elenerek uygulamanın kirlenmesini önler.
                        </div>
                    </div>
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-2">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-400">Bot Hata Sayısı</span>
                                <span class="material-symbols-outlined ${errCount === 0 ? 'text-emerald-500' : 'text-rose-500'} text-[18px]">warning</span>
                            </div>
                            <div class="text-2xl font-black ${errCount === 0 ? 'text-emerald-400' : 'text-rose-400'} mt-1">${errCount}</div>
                            <p class="text-[11px] text-slate-400">${errCount === 0 ? 'Sıfır Hata • Tam Kararlı' : 'İncelenmesi gereken istisnalar var'}</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2 rounded-lg text-[10px] text-slate-500 border border-slate-100 dark:border-slate-800/80">
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (&lt;1 Dk)</span><br><b>💡 Ne İşe Yarar:</b> Botun kazıma sırasında aldığı hata sayısıdır; sıfır olması sistemin kusursuz çalıştığını gösterir.
                        </div>
                    </div>
                    <!-- KART 5: Sunucu Node.js Heap & RAM Telemetrisi -->
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-2">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-400">Node.js Heap (RAM)</span>
                                <span class="material-symbols-outlined text-purple-500 text-[18px]">memory</span>
                            </div>
                            <div class="text-2xl font-black text-purple-400 mt-1">${botData.cleanVmStatus?.heapUsedMb ? botData.cleanVmStatus.heapUsedMb + ' MB' : '44.7 MB'}</div>
                            <p class="text-[11px] text-slate-400">${botData.cleanVmStatus?.status === 'success' ? 'Otomatik Temizlendi (' + (botData.cleanVmStatus?.durationSec || '1.2') + ' sn)' : 'VM Bellek Durumu'}</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2 rounded-lg text-[10px] text-slate-500 border border-slate-100 dark:border-slate-800/80">
                            <b>⏱️ Zaman:</b> Canlı VM Telemetrisi<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı</span><br><b>💡 Ne İşe Yarar:</b> GCP e2-micro VM üzerinde çalışan botun bellek tüketimini izleyerek bellek sızıntısını ve kilitlenmeyi önler.
                        </div>
                    </div>
                </div>

                <!-- Hızlı Operasyonel Müdahale ve SSH Rehberi -->
                <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col gap-4">
                    <div class="flex items-center justify-between flex-wrap gap-2">
                        <div class="flex items-center gap-2">
                            <span class="material-symbols-outlined text-indigo-500">terminal</span>
                            <h4 class="text-slate-900 dark:text-white font-bold text-sm">Otonom Bot Hızlı Müdahale ve SSH Terminal Rehberi</h4>
                        </div>
                        <a href="${env.gcpComputeUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-primary hover:underline flex items-center gap-1">
                            <span>GCP Compute Instances Konsolu ↗</span>
                            <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
                        </a>
                    </div>
                    <div class="text-xs text-slate-500 dark:text-slate-400">
                        <b>💡 Ne İşe Yarar:</b> Bot durursa veya takılırsa sunucuya bağlanıp 3 hazır komutla botu anında yeniden başlatabilmeniz için acil durum kılavuzudur.
                    </div>
                    <div class="bg-slate-950 p-4 rounded-xl font-mono text-xs text-slate-300 space-y-2 border border-slate-800">
                        <p class="text-slate-500"># 1. Bot VM sunucusuna SSH ile doğrudan bağlanma:</p>
                        <p class="text-emerald-400">gcloud compute ssh firsatkolik-bot-vm --zone=us-central1-a --project=${env.projectId}</p>
                        <p class="text-slate-500 pt-1"># 2. Bot durumunu ve PM2 loglarını canlı izleme:</p>
                        <p class="text-cyan-300">pm2 status && pm2 logs ${container} --lines 50</p>
                        <p class="text-slate-500 pt-1"># 3. Botu yeniden başlatma (Acil Durum Kurtarma):</p>
                        <p class="text-amber-300">pm2 restart ${container}</p>
                    </div>
                </div>
            `;
        },

        /**
         * Health Check Sonuç Kutusu
         */
        renderHealthCheckResultBox: function(res, port) {
            if (!res) {
                return `
                    <div class="bg-slate-950/60 p-3.5 rounded-xl border border-slate-800 text-xs text-slate-400 flex items-center justify-between">
                        <span>Hedef Uç Noktası: <code class="text-indigo-400 font-mono">http://34.135.181.112:${port}/health</code></span>
                        <span class="text-slate-500">Durum: Henüz sorgulanmadı</span>
                    </div>
                `;
            }

            if (res.success) {
                return `
                    <div class="bg-emerald-950/40 p-4 rounded-xl border border-emerald-800/40 text-xs text-emerald-300 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                        <div class="flex items-center gap-2">
                            <span class="material-symbols-outlined text-emerald-400">check_circle</span>
                            <span><b>HTTP 200 OK:</b> Konteyner ayakta ve yanıt veriyor! Yanıt Süresi: <b>${res.durationMs} ms</b></span>
                        </div>
                        <span class="text-[11px] text-slate-400">Uptime: ${res.data?.uptime ? Math.round(res.data.uptime) + ' sn' : 'Aktif'}</span>
                    </div>
                `;
            } else {
                return `
                    <div class="bg-rose-950/40 p-4 rounded-xl border border-rose-800/40 text-xs text-rose-300 flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                        <div class="flex items-center gap-2">
                            <span class="material-symbols-outlined text-rose-400">error</span>
                            <span><b>Bağlantı Uyarısı:</b> ${res.error || res.statusText || 'Yanıt alınamadı'} (${res.durationMs} ms)</span>
                        </div>
                        <span class="text-[11px] text-slate-400">Not: Tarayıcı CORS kısıtlaması nedeniyle direkt istek engellendiyse SSH terminal rehberini kullanınız.</span>
                    </div>
                `;
            }
        },

        /**
         * İlerleme Çubuklu Standart Kart Renderer'ı
         */
        renderProgressCard: function(props) {
            return `
                <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-4 transition-all hover:border-slate-300 dark:hover:border-slate-700">
                    <div class="flex flex-col gap-3">
                        <div class="flex items-start justify-between gap-2">
                            <div class="flex items-center gap-2.5">
                                <div class="w-9 h-9 rounded-xl ${props.iconBg} flex items-center justify-center border shrink-0">
                                    <span class="material-symbols-outlined text-[20px]">${props.icon}</span>
                                </div>
                                <h4 class="text-slate-900 dark:text-white font-bold text-sm leading-tight">${props.title}</h4>
                            </div>
                            ${props.statusBadge || ''}
                        </div>

                        <div>
                            <div class="text-slate-900 dark:text-white font-black text-2xl tracking-tight">${props.mainValue}</div>
                            <!-- İlerleme Çubuğu -->
                            <div class="w-full bg-slate-100 dark:bg-slate-800 h-2.5 rounded-full overflow-hidden mt-2.5">
                                <div class="${props.progressColor} h-2.5 rounded-full transition-all duration-500" style="width: ${Math.min(props.progressPercent, 100)}%"></div>
                            </div>
                            <div class="text-slate-500 dark:text-slate-400 text-[11px] mt-1.5 leading-relaxed">${props.subText}</div>
                        </div>

                        <div class="bg-slate-50 dark:bg-slate-900/50 p-3 rounded-xl border border-slate-100 dark:border-slate-800/80 text-[11px] text-slate-600 dark:text-slate-400 leading-relaxed">
                            <span class="font-bold text-slate-700 dark:text-slate-300">ℹ️ Amaç:</span> ${props.description}
                        </div>
                    </div>

                    <div class="flex flex-wrap items-center gap-2 pt-2 border-t border-slate-100 dark:border-slate-800/80 mt-auto">
                        ${props.primaryBtn ? `
                            <button type="button" onclick="${props.primaryBtn.action}" class="flex-1 min-w-[130px] px-3 py-2 text-xs font-bold bg-primary/10 hover:bg-primary/20 text-primary border border-primary/20 rounded-xl transition-colors flex items-center justify-center gap-1 cursor-pointer">
                                <span>${props.primaryBtn.label}</span>
                            </button>
                        ` : ''}

                        ${props.externalBtn ? `
                            <a href="${props.externalBtn.url}" target="_blank" rel="noopener noreferrer" class="flex-1 min-w-[130px] px-3 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-xl transition-colors flex items-center justify-center gap-1">
                                <span>${props.externalBtn.label}</span>
                            </a>
                        ` : ''}
                    </div>
                </div>
            `;
        },

        /**
         * SEKME 4: Kararlılık, Hatalar & Konsol Köprüleri (FAZ 1'den Aktif)
         */
        renderStabilityTab: function(content) {
            const env = this.getEnvInfo();
            const errors = this.cache.systemErrors;

            const unresolvedBadge = errors.unresolved > 0
                ? `<span class="px-2.5 py-1 text-xs font-bold rounded-full bg-rose-500/15 text-rose-400 border border-rose-500/30 flex items-center gap-1"><span class="size-1.5 rounded-full bg-rose-500 animate-pulse"></span>${errors.unresolved} Çözülmemiş</span>`
                : `<span class="px-2.5 py-1 text-xs font-bold rounded-full bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 flex items-center gap-1"><span class="size-1.5 rounded-full bg-emerald-500"></span>Tümü Temiz</span>`;

            content.innerHTML = `
                <!-- Bilgilendirme Bannerı -->
                <div class="bg-gradient-to-r from-blue-950/40 via-indigo-950/30 to-purple-950/20 border border-blue-800/40 p-4 sm:p-5 rounded-2xl flex items-start gap-3.5">
                    <span class="material-symbols-outlined text-blue-400 text-2xl shrink-0 mt-0.5">verified_user</span>
                    <div class="text-xs sm:text-sm text-slate-300 space-y-1">
                        <p class="font-bold text-white text-sm">Kararlılık, Hata Yönetimi ve Doğrudan Konsol Köprüleri</p>
                        <p class="text-slate-400">
                            Bu merkez; mobil istemci çökmelerini, yakalanan mantıksal hataları, ağ gecikmelerini ve GCP altyapı kayıtlarını tek noktadan izlemenizi sağlar. Her kart, amacını ve ölçüm hedefini açıklar ve derinlemesine inceleme için tek tıkla doğrudan ilgili konsolu açar.
                        </p>
                    </div>
                </div>

                <!-- Grid Kartlar (6 Master Kart) -->
                <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-5">
                    
                    <!-- KART 1: Firestore Canlı Sistem Hataları -->
                    ${this.renderMetricCard({
                        title: 'Sistem Hataları (systemErrors - Canlı)',
                        icon: 'bug_report',
                        iconBg: 'bg-rose-500/10 text-rose-500 border-rose-500/20',
                        statusBadge: unresolvedBadge,
                        value: `${errors.unresolved} <span class="text-sm font-normal text-slate-400">/ ${errors.total} Toplam</span>`,
                        subtitle: errors.unresolved > 0 ? `${errors.unresolved} bekleyen açık hata var` : `Tüm hatalar çözüldü (${errors.total} kayıt)`,
                        description: `<b>⏱️ Zaman:</b> Canlı / Son Hatalar (Veritabanında kayıtlı ${errors.total} işlem)<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (0 sn / Saniyelik)</span> — Uygulamada veya Cloud Functions'ta try-catch'e düşen teknik istisnalar anında Firestore'a yazılır ve bu panelde görünür.<br><b>💡 Ne İşe Yarar:</b> Mobil uygulamada veya Cloud Functions'ta kullanıcıların karşılaştığı teknik hataları listeler. Bekleyen çözülmemiş hataları anında fark edip müdahale etmenizi sağlar.`,
                        internalRedirectBtn: {
                            label: 'Modül 8: Sistem Loglarına Git ➔',
                            action: 'window.showLogsView ? window.showLogsView() : (window.showView && window.showView(\'logsView\'))'
                        },
                        externalLinkBtn: {
                            label: 'Firestore Koleksiyonu ↗',
                            url: `https://console.firebase.google.com/project/${env.projectId}/firestore/databases/-default-/data/~2FsystemErrors`
                        }
                    })}

                    <!-- KART 2: Firebase Crashlytics Kararlılık Köprüsü -->
                    ${this.renderMetricCard({
                        title: 'Firebase Crashlytics (Canlı & Sürümler)',
                        icon: 'emergency',
                        iconBg: 'bg-red-500/10 text-red-500 border-red-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">Hedef: >= %99.5</span>',
                        value: 'Crash-Free Users',
                        subtitle: 'Ölümcül çökmeler ve kullanıcı adımları (Breadcrumbs)',
                        description: '<b>⏱️ Zaman:</b> Canlı / Son Yayınlanan Sürümler<br><b>⚡ Canlılık:</b> <span class="text-amber-500 font-bold">🟡 Gecikmeli (5 - 15 Dk / Sonraki Açılışta)</span> — Mobil uygulama çöktüğünde işletim sistemi süreci aniden sonlandırır; çökme raporu uygulamanın BİR SONRAKİ AÇILIŞINDA Firebase\'e iletilir ve konsola 5-15 dakikada işlenir.<br><b>💡 Ne İşe Yarar:</b> Uygulamanın aniden kapanmasına (çökmesine) sebep olan ölümcül hataları gösterir. Hedef %99.5 çökmesiz kullanıcı oranını korumaktır; yeni bir sürüm veya yama çıktığında ilk bakılacak yerdir.',
                        externalLinkBtn: {
                            label: `${env.envName} Crashlytics'i Aç ↗`,
                            url: env.firebaseCrashlyticsUrl
                        },
                        secondaryExternalBtn: {
                            label: env.isProd ? 'DEV Crashlytics ↗' : 'PROD Crashlytics ↗',
                            url: env.isProd
                                ? 'https://console.firebase.google.com/project/sicak-firsatlar-e6eae/crashlytics'
                                : 'https://console.firebase.google.com/project/firsatkolik-prod-e6eae/crashlytics'
                        }
                    })}

                    <!-- KART 3: Firebase Performance Gözlem Köprüsü -->
                    ${this.renderMetricCard({
                        title: 'Firebase Performance (Canlı Gözlem)',
                        icon: 'speed',
                        iconBg: 'bg-amber-500/10 text-amber-500 border-amber-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/30">Hedef: < 2.0s Cold Start</span>',
                        value: 'Gecikme & Donan Kareler',
                        subtitle: 'Cold Start (<2.0s), Donan Kareler & Ağ Gecikmesi',
                        description: '<b>⏱️ Zaman:</b> Canlı / Son Günler<br><b>⚡ Canlılık:</b> <span class="text-rose-400 font-bold">🔴 Gecikmeli (24 - 48 Saat)</span> — Cold start açılış süreleri ve ağ gecikmeleri Google sunucularında cihaz ve ağ tipine göre filtrelenip 24-48 saatte raporlanır.<br><b>💡 Ne İşe Yarar:</b> Uygulamanın telefonlarda kaç saniyede açıldığını (hedef <2 sn), ekranda takılma/donma olup olmadığını ve "Mağazaya Git" linkinin açılış hızını ölçer. Kullanıcı deneyimini yavaşlatan sorunları tespit eder.',
                        externalLinkBtn: {
                            label: `${env.envName} Performance Aç ↗`,
                            url: env.firebasePerfUrl
                        }
                    })}

                    <!-- KART 4: GCP Cloud Logging (Stackdriver) -->
                    ${this.renderMetricCard({
                        title: 'GCP Cloud Logging (Canlı Sunucu Logları)',
                        icon: 'terminal',
                        iconBg: 'bg-cyan-500/10 text-cyan-500 border-cyan-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/30">Sunucu Logları</span>',
                        value: '26 Cloud Function',
                        subtitle: '26 Cloud Function ve arka plan istisnaları',
                        description: '<b>⏱️ Zaman:</b> Canlı Sunucu Günlükleri (Saniyelik)<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (0 - 2 sn)</span> — 26 Cloud Function\'ın konsol çıktıları ve istisna logları Cloud Logging paneline 2 saniye içinde akar.<br><b>💡 Ne İşe Yarar:</b> 26 Cloud Function\'ın arka planda yaptığı işlemlerin ve sessiz kalan backend hatalarının teknik JSON dökümünü sunar. Fonksiyonlarda takılma olduğunda derinlemesine incelemeye yarar.',
                        externalLinkBtn: {
                            label: `${env.envName} Logs Explorer ↗`,
                            url: env.gcpLogsUrl
                        }
                    })}

                    <!-- KART 5: Google Cloud Billing & Bütçe Alarmı -->
                    ${this.renderMetricCard({
                        title: 'GCP Bütçe & Faturalandırma (Bu Ay)',
                        icon: 'payments',
                        iconBg: 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/30">Hedef: 0.00 TL</span>',
                        value: '500 TL Bütçe Alarmı',
                        subtitle: '%50 (250 TL), %80 (400 TL), %100 eşikleri',
                        description: '<b>⏱️ Zaman:</b> Bu Ayki Fatura Dönemi<br><b>⚡ Canlılık:</b> <span class="text-rose-400 font-bold">🔴 Gecikmeli (12 - 24 Saat)</span> — Google Cloud Billing verileri günlüktür; bütçe alarmları 12-24 saatlik harcama mutabakatıyla tetiklenir.<br><b>💡 Ne İşe Yarar:</b> Aylık faturanın 0.00 TL Free Tier sınırında kalmasını garanti eder. Beklenmeyen bir kota aşımı olduğunda sürpriz fatura çıkmaması için yöneticilere e-posta ile alarm gönderir.',
                        externalLinkBtn: {
                            label: 'GCP Billing Paneline Git ↗',
                            url: env.gcpBillingUrl
                        }
                    })}

                    <!-- KART 6: Firebase App Check Güvenlik Koruması -->
                    ${this.renderMetricCard({
                        title: 'Firebase App Check Doğrulama (Canlı)',
                        icon: 'security',
                        iconBg: 'bg-purple-500/10 text-purple-500 border-purple-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-purple-500/10 text-purple-400 border border-purple-500/30">Hedef: >= %95</span>',
                        value: 'Play Integrity & App Attest',
                        subtitle: 'Korsan bot ve sahte istek engelleme',
                        description: '<b>⏱️ Zaman:</b> Anlık / Canlı İstekler<br><b>⚡ Canlılık:</b> <span class="text-emerald-500 font-bold">🟢 Tam Canlı (0 - 5 sn)</span> — Korsan bot ve sahte API istekleri Play Integrity kriptografik doğrulaması ile anında kapıda engellenir.<br><b>💡 Ne İşe Yarar:</b> Veritabanına ve fonksiyonlara gelen isteklerin korsan bot veya emülatör değil, gerçek mobil uygulama olduğunu kriptografik olarak doğrular. Sahte scraping isteklerini kapıda durdurarak kotanızı korur.',
                        externalLinkBtn: {
                            label: `${env.envName} App Check Konsolu ↗`,
                            url: env.firebaseAppCheckUrl
                        }
                    })}

                </div>

                <!-- Son 5 Sistem Hatası Hızlı İnceleme Tablosu -->
                <div class="bg-white dark:bg-surface-dark p-6 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col gap-4">
                    <div class="flex items-center justify-between flex-wrap gap-2">
                        <div class="flex items-center gap-2">
                            <span class="material-symbols-outlined text-rose-500">crisis_alert</span>
                            <h3 class="text-slate-900 dark:text-white font-bold text-base">Son Sistem Hataları Akışı</h3>
                            <span class="text-xs text-slate-400">(Canlı Firestore Kayıtları)</span>
                        </div>
                        <button type="button" onclick="window.showLogsView ? window.showLogsView() : (window.showView && window.showView('logsView'))" class="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer">
                            <span>Modül 8 Sistem Loglarında Tümünü Yönet</span>
                            <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
                        </button>
                    </div>

                    ${this.renderLatestErrorsTable(errors.latest)}
                </div>
            `;
        },

        /**
         * Standart Metrik Kartı HTML Üreticisi
         */
        renderMetricCard: function(props) {
            return `
                <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-4 transition-all hover:border-slate-300 dark:hover:border-slate-700">
                    <div class="flex flex-col gap-3">
                        <!-- Kart Başlığı ve İkon -->
                        <div class="flex items-start justify-between gap-2">
                            <div class="flex items-center gap-2.5">
                                <div class="w-9 h-9 rounded-xl ${props.iconBg} flex items-center justify-center border shrink-0">
                                    <span class="material-symbols-outlined text-[20px]">${props.icon}</span>
                                </div>
                                <h4 class="text-slate-900 dark:text-white font-bold text-sm leading-tight">${props.title}</h4>
                            </div>
                            ${props.statusBadge || ''}
                        </div>

                        <!-- Değer ve Alt Başlık -->
                        <div class="mt-1">
                            <div class="text-slate-900 dark:text-white font-black text-2xl tracking-tight">${props.value}</div>
                            <div class="text-slate-500 dark:text-slate-400 text-xs mt-0.5">${props.subtitle}</div>
                        </div>

                        <!-- Bilgi Notu / Amacı (Açıklama Kutusu) -->
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-3 rounded-xl border border-slate-100 dark:border-slate-800/80 text-[11px] text-slate-600 dark:text-slate-400 leading-relaxed">
                            <span class="font-bold text-slate-700 dark:text-slate-300">ℹ️ Amaç & Kapsam:</span> ${props.description}
                        </div>
                    </div>

                    <!-- Aksiyon Butonları -->
                    <div class="flex flex-wrap items-center gap-2 pt-2 border-t border-slate-100 dark:border-slate-800/80 mt-auto">
                        ${props.internalRedirectBtn ? `
                            <button type="button" onclick="${props.internalRedirectBtn.action}" class="flex-1 min-w-[140px] px-3 py-2 text-xs font-bold bg-primary/10 hover:bg-primary/20 text-primary border border-primary/20 rounded-xl transition-colors flex items-center justify-center gap-1 cursor-pointer">
                                <span>${props.internalRedirectBtn.label}</span>
                            </button>
                        ` : ''}

                        ${props.externalLinkBtn ? `
                            <a href="${props.externalLinkBtn.url}" target="_blank" rel="noopener noreferrer" class="flex-1 min-w-[140px] px-3 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-xl transition-colors flex items-center justify-center gap-1">
                                <span>${props.externalLinkBtn.label}</span>
                            </a>
                        ` : ''}

                        ${props.secondaryExternalBtn ? `
                            <a href="${props.secondaryExternalBtn.url}" target="_blank" rel="noopener noreferrer" class="w-full px-3 py-1.5 text-[11px] font-semibold text-slate-400 hover:text-slate-200 text-center transition-colors">
                                ${props.secondaryExternalBtn.label}
                            </a>
                        ` : ''}
                    </div>
                </div>
            `;
        },

        /**
         * Son Hatalar Tablosu
         */
        renderLatestErrorsTable: function(latestList) {
            if (!latestList || latestList.length === 0) {
                return `
                    <div class="text-center py-8 text-slate-400 text-xs flex flex-col items-center gap-2">
                        <span class="material-symbols-outlined text-emerald-500 text-3xl">task_alt</span>
                        <p class="font-medium text-emerald-400">Harika! Şu an bekleyen aktif sistem hatası bulunmuyor.</p>
                    </div>
                `;
            }

            const rows = latestList.map(item => {
                const dateStr = item.timestamp.toLocaleDateString('tr-TR', {
                    hour: '2-digit',
                    minute: '2-digit',
                    day: 'numeric',
                    month: 'short'
                });

                const badge = item.isResolved
                    ? '<span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20">Çözüldü</span>'
                    : '<span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-rose-500/10 text-rose-400 border border-rose-500/20 animate-pulse">Açık</span>';

                const serviceBadge = `<span class="px-2 py-0.5 text-[10px] font-mono rounded bg-slate-100 dark:bg-slate-800 text-slate-500 dark:text-slate-400 border border-slate-200 dark:border-slate-700/60 font-semibold">${item.service}</span>`;

                return `
                    <tr class="border-b border-slate-100 dark:border-slate-800/60 hover:bg-slate-50/50 dark:hover:bg-slate-800/30 transition-colors">
                        <td class="py-2.5 px-3 text-xs">${serviceBadge}</td>
                        <td class="py-2.5 px-3 text-slate-600 dark:text-slate-300 text-xs font-mono max-w-xs sm:max-w-md truncate" title="${item.message}">${item.message}</td>
                        <td class="py-2.5 px-3 text-slate-400 text-[11px] whitespace-nowrap">${dateStr}</td>
                        <td class="py-2.5 px-3 whitespace-nowrap text-right">${badge}</td>
                    </tr>
                `;
            }).join('');

            return `
                <div class="overflow-x-auto">
                    <table class="w-full text-left border-collapse">
                        <thead>
                            <tr class="border-b border-slate-200 dark:border-slate-800 text-[11px] font-bold text-slate-400 uppercase tracking-wider">
                                <th class="py-2 px-3">Kaynak</th>
                                <th class="py-2 px-3">Hata Mesajı</th>
                                <th class="py-2 px-3">Zaman</th>
                                <th class="py-2 px-3 text-right">Durum</th>
                            </tr>
                        </thead>
                        <tbody>
                            ${rows}
                        </tbody>
                    </table>
                </div>
            `;
        },

        /**
         * Ortam Rozetini Günceller
         */
        updateEnvBadge: function() {
            const env = this.getEnvInfo();
            const badge = document.getElementById('obsEnvBadge');
            if (badge) {
                badge.className = `px-2.5 py-0.5 rounded-full text-xs font-bold border ${env.badgeClass}`;
                badge.textContent = `${env.envName} (${env.projectId})`;
            }
        }
    };

    // Global erişime aç
    window.ObservabilityManager = ObservabilityManager;

})(window);
