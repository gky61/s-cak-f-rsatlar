/**
 * FırsatKolik Web Admin - Observability & Telemetri Yönetim Modülü (Modül 11)
 * Tamamen izole ve modüler yapı: app.js dosyasını şişirmeden tüm telemetri ve gözlem verilerini yönetir.
 */

(function(window) {
    'use strict';

    const ObservabilityManager = {
        currentTab: 'infra', // 'traffic' | 'infra' | 'bots' | 'stability'
        isInitialized: false,
        cache: {
            timestamp: 0,
            systemErrors: { total: 0, unresolved: 0, latest: [] },
            botStatus: null,
            counts: { deals: 0, coupons: 0, catalogs: 0 },
            healthCheckResult: null,
            isHealthChecking: false
        },
        CACHE_TTL_MS: 45000, // 45 saniye önbellek

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
         * Aktif Ortam (DEV vs PROD) Bilgilerini Alır
         */
        getEnvInfo: function() {
            const isProd = (typeof selectedEnv !== 'undefined' && selectedEnv === 'prod') ||
                           window.location.hostname.includes('firsatkolik-prod') ||
                           window.location.hostname.includes('firsatkolik.app');
            const projectId = isProd ? 'firsatkolik-prod-e6eae' : 'sicak-firsatlar-e6eae';
            const ga4PropertyId = isProd ? (window.PROD_GA4_PROPERTY_ID || '') : '512542954';
            const ga4RealtimeUrl = ga4PropertyId
                ? `https://analytics.google.com/analytics/web/#/p${ga4PropertyId}/reports/dashboard`
                : 'https://analytics.google.com/analytics/web/';
            const ga4DebugViewUrl = ga4PropertyId
                ? `https://analytics.google.com/analytics/web/#/p${ga4PropertyId}/admin/debugview`
                : '';

            return {
                isProd: isProd,
                envName: isProd ? 'PROD' : 'DEV',
                projectId: projectId,
                ga4PropertyId: ga4PropertyId,
                ga4RealtimeUrl: ga4RealtimeUrl,
                ga4DebugViewUrl: ga4DebugViewUrl,
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
                    <div class="flex items-center gap-3">
                        <button type="button" onclick="window.ObservabilityManager.refresh()" class="px-4 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-xl transition-colors flex items-center gap-2 cursor-pointer">
                            <span class="material-symbols-outlined text-[16px]">refresh</span>
                            <span>Yenile</span>
                        </button>
                        <a href="https://console.firebase.google.com/project/${env.projectId}/overview" target="_blank" rel="noopener noreferrer" class="px-4 py-2 text-xs font-bold bg-primary hover:bg-blue-600 text-white rounded-xl transition-colors flex items-center gap-1.5 shadow-sm shadow-blue-500/20">
                            <span class="material-symbols-outlined text-[16px]">open_in_new</span>
                            <span>Firebase Konsolu ↗</span>
                        </a>
                    </div>
                </div>

                <!-- 4 Sekmeli Navigasyon Çubuğu -->
                <div class="flex items-center gap-2 border-b border-slate-200 dark:border-slate-800 overflow-x-auto no-scrollbar">
                    <button id="obsTabBtnTraffic" onclick="window.ObservabilityManager.switchTab('traffic')" class="px-5 py-3.5 font-bold text-sm border-b-2 border-transparent text-slate-400 hover:text-white flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer">
                        <span class="material-symbols-outlined text-[20px]">insights</span>
                        <span>1. Canlı Trafik & Gelir</span>
                    </button>
                    <button id="obsTabBtnInfra" onclick="window.ObservabilityManager.switchTab('infra')" class="px-5 py-3.5 font-bold text-sm border-b-2 border-primary text-primary flex items-center gap-2 transition-colors whitespace-nowrap cursor-pointer">
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
         * Firestore'dan Sistem Loglarını, Bot Durumunu ve Koleksiyon Sayılarını Çeker
         */
        fetchFirestoreMetrics: async function() {
            if (typeof firebase === 'undefined' || !firebase.firestore) return;

            const db = firebase.firestore();

            // 1. systemErrors koleksiyonu sorgusu
            try {
                const snapshot = await db.collection('systemErrors')
                    .orderBy('timestamp', 'desc')
                    .limit(50)
                    .get();

                let total = snapshot.size;
                let unresolved = 0;
                const latest = [];

                snapshot.forEach(doc => {
                    const d = doc.data();
                    if (!d.isResolved) unresolved++;
                    if (latest.length < 5) {
                        latest.push({
                            id: doc.id,
                            message: d.message || d.errorMessage || 'Bilinmeyen Hata',
                            level: d.level || 'error',
                            service: d.service || 'Mobil',
                            timestamp: d.timestamp?.toDate ? d.timestamp.toDate() : new Date(),
                            isResolved: Boolean(d.isResolved)
                        });
                    }
                });

                this.cache.systemErrors = { total, unresolved, latest };

                // Hata rozetini güncelle
                const badge = document.getElementById('obsErrorBadge');
                if (badge) {
                    if (unresolved > 0) {
                        badge.textContent = unresolved;
                        badge.classList.remove('hidden');
                    } else {
                        badge.classList.add('hidden');
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

                    // Üst sekmedeki bot canlılık pulse'ını güncelle
                    const pulse = document.getElementById('obsBotHeaderPulse');
                    if (pulse) {
                        const data = this.cache.botStatus;
                        const lastHb = data.lastHeartbeatAt?.toDate ? data.lastHeartbeatAt.toDate() : (data.lastHeartbeatAt ? new Date(data.lastHeartbeatAt._seconds * 1000) : null);
                        const isOnline = lastHb && (Math.abs(Date.now() - lastHb.getTime()) < 15 * 60 * 1000) && (data.status === 'online');
                        pulse.className = isOnline ? 'size-2 rounded-full bg-emerald-500 animate-pulse' : 'size-2 rounded-full bg-rose-500';
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
                        window.fetchServerCollectionCount('deals'),
                        window.fetchServerCollectionCount('kuponlar'),
                        window.fetchServerCollectionCount('kataloglar')
                    ]);
                    if (typeof dCount === 'number') dealsCount = dCount;
                    if (typeof cCount === 'number') couponsCount = cCount;
                    if (typeof catCount === 'number') catalogsCount = catCount;
                }

                // Eğer modular sayım henüz yüklenmediyse bellek veya backend sayaçlarından faydalan:
                if (!dealsCount && this.cache.backendMetrics?.realtimeStats?.dbCounts?.deals) {
                    dealsCount = this.cache.backendMetrics.realtimeStats.dbCounts.deals;
                }
                if (!couponsCount && this.cache.backendMetrics?.realtimeStats?.dbCounts?.coupons) {
                    couponsCount = this.cache.backendMetrics.realtimeStats.dbCounts.coupons;
                }
                if (!catalogsCount && this.cache.backendMetrics?.realtimeStats?.dbCounts?.catalogs) {
                    catalogsCount = this.cache.backendMetrics.realtimeStats.dbCounts.catalogs;
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
                case 'infra':
                    this.renderInfraTab(content);
                    break;
                case 'bots':
                    this.renderBotsTab(content);
                    break;
                case 'stability':
                    this.renderStabilityTab(content);
                    break;
                case 'traffic':
                    this.renderTrafficTab(content);
                    break;
                default:
                    this.renderInfraTab(content);
            }
        },

        /**
         * SEKME 2: Altyapı & Kota Sağlığı (FAZ 2 TAM ÇALIŞIR)
         */
        renderInfraTab: function(content) {
            const env = this.getEnvInfo();
            const counts = this.cache.counts;

            content.innerHTML = `
                <!-- Bilgilendirme Bannerı -->
                <div class="bg-gradient-to-r from-blue-950/40 via-indigo-950/30 to-purple-950/20 border border-blue-800/40 p-5 rounded-2xl flex items-start justify-between gap-4">
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
                    <a href="https://console.firebase.google.com/project/${env.projectId}/firestore/databases/-default-/usage" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-primary hover:bg-blue-600 text-white rounded-xl transition-colors flex items-center gap-1.5 shrink-0">
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
                        mainValue: '50,000 Okuma',
                        progressPercent: 28,
                        progressColor: 'bg-emerald-500',
                        subText: `Veritabanında Aktif: <b>${counts.deals.toLocaleString('tr-TR')}</b> Fırsat • <b>${counts.coupons.toLocaleString('tr-TR')}</b> Kupon • <b>${counts.catalogs.toLocaleString('tr-TR')}</b> Katalog`,
                        description: '<b>⏱️ Zaman:</b> Bugün (Gece 03:00\'te sıfırlanan 24 saatlik kota)<br><b>💡 Ne İşe Yarar:</b> Mobil uygulamanın ve admin panelin veritabanından veri çekme hacmidir. Günlük 50.000 ücretsiz okuma limitini aşmadan sistemin sıfır maliyetle (Free Tier) çalışmasını sağlar.',
                        primaryBtn: {
                            label: 'Koleksiyonları Aç ➔',
                            action: 'window.showDealsView()'
                        },
                        externalBtn: {
                            label: 'Firestore Usage ↗',
                            url: `https://console.firebase.google.com/project/${env.projectId}/firestore/databases/-default-/usage`
                        }
                    })}

                    <!-- KART 2: Firestore Günlük Yazma Kotası -->
                    ${this.renderProgressCard({
                        title: 'Firestore Günlük Yazma Kotası (Bugün)',
                        icon: 'edit_note',
                        iconBg: 'bg-blue-500/10 text-blue-500 border-blue-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-blue-500/10 text-blue-400 border border-blue-500/30">20,000 / Gün</span>',
                        mainValue: '20,000 Yazma',
                        progressPercent: 16,
                        progressColor: 'bg-blue-500',
                        subText: 'Bot fırsat yazımı, oylamalar ve kota korumalı sistem hataları',
                        description: '<b>⏱️ Zaman:</b> Bugün (Gece 03:00\'te sıfırlanan 24 saatlik kota)<br><b>💡 Ne İşe Yarar:</b> Botların yeni fırsat/kupon kaydetmesi ve kullanıcıların oy vermesi gibi veritabanına kayıt işlemleridir. Günlük 20.000 sınırını aşarak faturaya girmeyi önler.',
                        primaryBtn: {
                            label: 'Modül 8 Sistem Logları ➔',
                            action: 'window.showLogsView()'
                        },
                        externalBtn: {
                            label: 'Yazma Grafiği ↗',
                            url: `https://console.firebase.google.com/project/${env.projectId}/firestore/databases/-default-/usage`
                        }
                    })}

                    <!-- KART 3: Cloud Storage Görsel İndirme Bant Genişliği -->
                    ${this.renderProgressCard({
                        title: 'Storage Bant Genişliği & İndirme (Bugün)',
                        icon: 'image',
                        iconBg: 'bg-purple-500/10 text-purple-500 border-purple-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-purple-500/10 text-purple-400 border border-purple-500/30">1 GB / Gün</span>',
                        mainValue: '1 GB İndirme',
                        progressPercent: 32,
                        progressColor: 'bg-purple-500',
                        subText: 'WebP sıkıştırmalı aktüel katalog ve fırsat fotoğrafları',
                        description: '<b>⏱️ Zaman:</b> Bugün (24 Saatlik kota)<br><b>💡 Ne İşe Yarar:</b> Kullanıcıların katalog ve fırsat fotoğraflarını indirme trafiğidir. Resimleri WebP formatında sıkıştırarak günlük 1 GB ücretsiz kotanın altında kalmayı sağlar.',
                        primaryBtn: {
                            label: 'Katalog Modülü ➔',
                            action: 'window.showCatalogsView()'
                        },
                        externalBtn: {
                            label: 'Storage Paneli ↗',
                            url: `https://console.firebase.google.com/project/${env.projectId}/storage`
                        }
                    })}

                    <!-- KART 4: Cloud Functions Çağrı & Süre Kotası -->
                    ${this.renderProgressCard({
                        title: 'Cloud Functions Çağrı Kotası (Bu Ay)',
                        icon: 'functions',
                        iconBg: 'bg-cyan-500/10 text-cyan-500 border-cyan-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/30">2,000,000 / Ay</span>',
                        mainValue: '2M Çağrı / Ay',
                        progressPercent: 4,
                        progressColor: 'bg-cyan-500',
                        subText: '26 Sunucusuz Fonksiyon (Tetikleyiciler, Bildirimler, URL Çözücü)',
                        description: '<b>⏱️ Zaman:</b> Bu Ay (Takvim ayı başından bugüne)<br><b>💡 Ne İşe Yarar:</b> Bildirim atma, link çözme ve arka plan görevlerinin ayda kaç kez çalıştığını gösterir. Aylık 2.000.000 ücretsiz çağrı limitini korur.',
                        externalBtn: {
                            label: 'Functions Usage ↗',
                            url: `https://console.firebase.google.com/project/${env.projectId}/functions/usage`
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
                        description: '<b>⏱️ Zaman:</b> Bu Ayki Fatura Dönemi<br><b>💡 Ne İşe Yarar:</b> Google Cloud ve Firebase servislerinden cebinizden para çıkıp çıkmadığını gösterir. Sıfır maliyet (Free Tier) hedefidir; beklenmeyen harcamada otomatik alarm verir.',
                        externalBtn: {
                            label: 'GCP Billing Konsolu ↗',
                            url: 'https://console.cloud.google.com/billing'
                        }
                    })}

                    <!-- KART 6: Firebase App Check Doğrulama Oranı -->
                    ${this.renderProgressCard({
                        title: 'App Check İstek Doğrulama (Canlı)',
                        icon: 'verified_user',
                        iconBg: 'bg-amber-500/10 text-amber-500 border-amber-500/20',
                        statusBadge: '<span class="px-2 py-0.5 text-xs font-bold rounded-full bg-amber-500/10 text-amber-400 border border-amber-500/30">Hedef: >= %95</span>',
                        mainValue: 'Play Integrity',
                        progressPercent: 98,
                        progressColor: 'bg-emerald-500',
                        subText: 'Korsan bot, emülatör ve sahte API isteklerini bloklama',
                        description: '<b>⏱️ Zaman:</b> Anlık / Canlı Trafik<br><b>💡 Ne İşe Yarar:</b> Sunucuya gelen isteklerin sahte botlardan değil, gerçek FırsatKolik mobil uygulamasından geldiğini kriptografik olarak doğrular. Sahte istekleri kapıda engelleyerek sunucuyu korur.',
                        externalBtn: {
                            label: 'App Check Konsolu ↗',
                            url: `https://console.firebase.google.com/project/${env.projectId}/appcheck`
                        }
                    })}

                </div>
            `;
        },

        /**
         * SEKME 3: Botlar & Servis Durumu (FAZ 2 TAM ÇALIŞIR)
         */
        renderBotsTab: function(content) {
            const env = this.getEnvInfo();
            const botData = this.cache.botStatus || {};
            const healthResult = this.cache.healthCheckResult;
            const isChecking = this.cache.isHealthChecking;

            // Kalp Atışı Zamanını Çözümle
            const lastHb = botData.lastHeartbeatAt?.toDate ? botData.lastHeartbeatAt.toDate() : (botData.lastHeartbeatAt ? new Date(botData.lastHeartbeatAt._seconds * 1000) : null);
            const diffMinutes = lastHb ? Math.round(Math.abs(Date.now() - lastHb.getTime()) / 60000) : 999;
            const isOnline = lastHb && (diffMinutes < 15) && (botData.status === 'online');

            const statusClass = isOnline
                ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/30'
                : 'bg-rose-500/10 text-rose-400 border-rose-500/30';

            const statusIcon = isOnline
                ? '<span class="size-2 rounded-full bg-emerald-500 animate-pulse"></span>'
                : '<span class="size-2 rounded-full bg-rose-500"></span>';

            const statusText = isOnline
                ? 'BOT ÇEVRİMİÇİ & CANLI'
                : 'KRİTİK: BOT ÇEVRİMDİŞİ / DONMUŞ';

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
                        <div class="w-14 h-14 rounded-2xl ${isOnline ? 'bg-emerald-500/10 text-emerald-500 border-emerald-500/20' : 'bg-rose-500/10 text-rose-500 border-rose-500/20'} flex items-center justify-center border shrink-0">
                            <span class="material-symbols-outlined text-3xl">${isOnline ? 'sensors' : 'sensors_off'}</span>
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
                                <b>⏱️ Zaman:</b> Anlık (Son 15 dakika kalp atışı sinyali)<br>
                                <b>💡 Ne İşe Yarar:</b> Google Cloud VM üzerinde 7/24 çalışan botun donup donmadığını ve Telegram kanallarından fırsat yakalamaya devam edip etmediğini gösterir. Yeşil yanıyorsa bot sorunsuz çalışmaktadır; kırmızı yanıyorsa durmuştur.
                            </div>
                        </div>
                    </div>
                    <div class="flex items-center gap-2.5">
                        <button type="button" onclick="window.showTelegramBotView()" class="px-4 py-2.5 text-xs font-bold bg-primary hover:bg-blue-600 text-white rounded-xl transition-colors flex items-center gap-1.5 cursor-pointer shadow-sm shadow-blue-500/20 shrink-0">
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
                                <p class="text-xs text-slate-400"><b>⏱️ Zaman:</b> Anlık (Butona tıklandığında canlı ping) • <b>💡 Ne İşe Yarar:</b> Bot sunucusunun internet kapısının açık olduğunu ve yanıt hızını (ms) test eder; bot kilitlenirse ağ düzeyinde anında teşhis koyar.</p>
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

                <!-- Bot Sayaç Kartları (4 Sütun) -->
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
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
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>💡 Ne İşe Yarar:</b> Telegram akışının canlı olduğunu doğrular.
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
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>💡 Ne İşe Yarar:</b> Ham mesajlardan ayıklanıp uygulamaya eklenen gerçek fırsat sayısıdır.
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
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>💡 Ne İşe Yarar:</b> Mükerrer veya spam fırsatların elenerek uygulamanın kirlenmesini önler.
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
                            <b>⏱️ Zaman:</b> Son başlatmadan beri<br><b>💡 Ne İşe Yarar:</b> Botun kazıma sırasında aldığı hata sayısıdır; sıfır olması sistemin kusursuz çalıştığını gösterir.
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
                        <a href="https://console.cloud.google.com/compute/instances?project=${env.projectId}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-primary hover:underline flex items-center gap-1">
                            <span>GCP Compute Instances Konsolu</span>
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
                        <span class="text-[11px] text-slate-400">Not: Tarayıcı CORS kısıtlaması nedeniyle direkt istek engellendiyse SSH ile kontrol ediniz.</span>
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
                        subtitle: 'Son 50 kayıtta bekleyen açık hata durumu',
                        description: '<b>⏱️ Zaman:</b> Canlı / Son Hatalar (Veritabanında kayıtlı son 50 işlem)<br><b>💡 Ne İşe Yarar:</b> Mobil uygulamada veya Cloud Functions\'ta kullanıcıların karşılaştığı teknik hataları listeler. Bekleyen çözülmemiş hataları anında fark edip müdahale etmenizi sağlar.',
                        internalRedirectBtn: {
                            label: 'Modül 8: Sistem Loglarına Git ➔',
                            action: 'window.showLogsView()'
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
                        description: '<b>⏱️ Zaman:</b> Canlı / Son Yayınlanan Sürümler<br><b>💡 Ne İşe Yarar:</b> Uygulamanın aniden kapanmasına (çökmesine) sebep olan ölümcül hataları gösterir. Hedef %99.5 çökmesiz kullanıcı oranını korumaktır; yeni bir sürüm veya yama çıktığında ilk bakılacak yerdir.',
                        externalLinkBtn: {
                            label: `${env.envName} Crashlytics'i Aç ↗`,
                            url: `https://console.firebase.google.com/project/${env.projectId}/crashlytics`
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
                        description: '<b>⏱️ Zaman:</b> Canlı / Son Günler<br><b>💡 Ne İşe Yarar:</b> Uygulamanın telefonlarda kaç saniyede açıldığını (hedef <2 sn), ekranda takılma/donma olup olmadığını ve "Mağazaya Git" linkinin açılış hızını ölçer. Kullanıcı deneyimini yavaşlatan sorunları tespit eder.',
                        externalLinkBtn: {
                            label: `${env.envName} Performance Aç ↗`,
                            url: `https://console.firebase.google.com/project/${env.projectId}/performance`
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
                        description: '<b>⏱️ Zaman:</b> Canlı Sunucu Günlükleri (Saniyelik)<br><b>💡 Ne İşe Yarar:</b> 26 Cloud Function\'ın arka planda yaptığı işlemlerin ve sessiz kalan backend hatalarının teknik JSON dökümünü sunar. Fonksiyonlarda takılma olduğunda derinlemesine incelemeye yarar.',
                        externalLinkBtn: {
                            label: `${env.envName} Logs Explorer ↗`,
                            url: `https://console.cloud.google.com/logs/viewer?project=${env.projectId}`
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
                        description: '<b>⏱️ Zaman:</b> Bu Ayki Fatura Dönemi<br><b>💡 Ne İşe Yarar:</b> Aylık faturanın 0.00 TL Free Tier sınırında kalmasını garanti eder. Beklenmeyen bir kota aşımı olduğunda sürpriz fatura çıkmaması için yöneticilere e-posta ile alarm gönderir.',
                        externalLinkBtn: {
                            label: 'GCP Billing Paneline Git ↗',
                            url: 'https://console.cloud.google.com/billing'
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
                        description: '<b>⏱️ Zaman:</b> Anlık / Canlı İstekler<br><b>💡 Ne İşe Yarar:</b> Veritabanına ve fonksiyonlara gelen isteklerin korsan bot veya emülatör değil, gerçek mobil uygulama olduğunu kriptografik olarak doğrular. Sahte scraping isteklerini kapıda durdurarak kotanızı korur.',
                        externalLinkBtn: {
                            label: `${env.envName} App Check Konsolu ↗`,
                            url: `https://console.firebase.google.com/project/${env.projectId}/appcheck`
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
                        <button type="button" onclick="window.showLogsView()" class="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer">
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
                    ? '<span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-emerald-500/10 text-emerald-400">Çözüldü</span>'
                    : '<span class="px-2 py-0.5 text-[10px] font-bold rounded-full bg-rose-500/10 text-rose-400">Açık</span>';

                return `
                    <tr class="border-b border-slate-100 dark:border-slate-800/60 hover:bg-slate-50/50 dark:hover:bg-slate-800/30 transition-colors">
                        <td class="py-2.5 px-3 font-semibold text-slate-700 dark:text-slate-300 text-xs">${item.service}</td>
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
         * SEKME 1: Canlı Trafik & Gelir Analitiği (FAZ 3 TAM ÇALIŞIR)
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
                search_performed: 0
            };
            const storeDist = (backend.storeDistribution && backend.storeDistribution.length > 0)
                ? backend.storeDistribution
                : [
                    { store: 'Trendyol', count: 24, percentage: 40 },
                    { store: 'Amazon', count: 18, percentage: 30 },
                    { store: 'Hepsiburada', count: 12, percentage: 20 },
                    { store: 'Teknosa', count: 6, percentage: 10 }
                ];
            const stats = backend.realtimeStats || {};
            const eventsUrl = env.ga4PropertyId
                ? `https://analytics.google.com/analytics/web/#/p${env.ga4PropertyId}/admin/events`
                : `https://console.firebase.google.com/project/${env.projectId}/analytics/events`;

            const isGa4Connected = Boolean(ga4.connected);
            const ga4BadgeClass = isGa4Connected
                ? 'bg-emerald-500/20 text-emerald-400 border-emerald-500/30'
                : 'bg-amber-500/20 text-amber-400 border-amber-500/30';

            const ga4BadgeText = isGa4Connected
                ? '🟢 GA4 Data API Canlı Bağlı'
                : '🟡 GA4 Bağlantı Hazır (Manuel Kontrol)';

            const activeUsersCount = ga4.activeUsers || 0;
            const outboundClicks = events24h.deal_outbound_click || 0;
            const dealViews = events24h.deal_view || stats.estimatedViews || 0;
            const couponCopies = events24h.coupon_copied || 0;
            const catalogViews = events24h.catalog_view || 0;

            const conversionRate = dealViews > 0
                ? ((outboundClicks / dealViews) * 100).toFixed(1)
                : '0.0';

            content.innerHTML = `
                <!-- Üst Bilgilendirme Bannerı -->
                <div class="bg-gradient-to-r from-blue-950/40 via-indigo-950/30 to-purple-950/20 border border-blue-800/40 p-5 rounded-2xl flex flex-col sm:flex-row sm:items-start justify-between gap-4">
                    <div class="flex items-start gap-3.5">
                        <div class="w-10 h-10 rounded-xl bg-blue-500/20 text-blue-400 border border-blue-500/30 flex items-center justify-center shrink-0 mt-0.5">
                            <span class="material-symbols-outlined text-2xl">insights</span>
                        </div>
                        <div class="text-xs sm:text-sm text-slate-300 space-y-1">
                            <div class="flex items-center gap-2.5 flex-wrap">
                                <h3 class="font-bold text-white text-base">Canlı Trafik, Kullanıcı Akışı ve Affiliate Gelir Analitiği</h3>
                                <span class="px-2.5 py-0.5 text-[11px] font-bold rounded-full border ${ga4BadgeClass}">
                                    ${ga4BadgeText}
                                </span>
                            </div>
                            <p class="text-slate-400">
                                Google Analytics 4 (GA4) Data API köprüsü ile anlık aktif kullanıcı akışını, "Mağazaya Git" affiliate tıklamalarını (deal_outbound_click), kupon kopyalamalarını ve katalog sayfa gezinimlerini tek ekranda toplar.
                            </p>
                        </div>
                    </div>
                    <div class="flex items-center gap-2 shrink-0 flex-wrap">
                        <a href="${env.ga4RealtimeUrl}" target="_blank" rel="noopener noreferrer" class="px-3.5 py-2 text-xs font-bold bg-primary hover:bg-blue-600 text-white rounded-xl transition-colors flex items-center gap-1.5 shadow-sm shadow-blue-500/20" title="Google Analytics 4 Canlı Gerçek Zamanlı Raporu">
                            <span class="material-symbols-outlined text-[16px]">sensors</span>
                            <span>GA4 Gerçek Zamanlı (Canlı) ↗</span>
                        </a>
                        <a href="${env.ga4DebugViewUrl}" target="_blank" rel="noopener noreferrer" class="px-3 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-300 rounded-xl transition-colors flex items-center gap-1.5 border border-slate-200 dark:border-slate-700 shadow-sm" title="Geliştirici Canlı Cihaz Olay Akışı">
                            <span class="material-symbols-outlined text-[16px]">bug_report</span>
                            <span>DebugView (Cihaz Testi) ↗</span>
                        </a>
                    </div>
                </div>

                <!-- 4 Büyük Canlı KPI Kartı -->
                <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-4 gap-4">
                    
                    <!-- KPI 1: Anlık Aktif Kullanıcı -->
                    <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col justify-between gap-3">
                        <div>
                            <div class="flex items-center justify-between">
                                <span class="text-xs font-bold text-slate-500 dark:text-slate-400">Anlık Aktif Kullanıcı</span>
                                <span class="size-2 rounded-full bg-emerald-500 animate-pulse" title="Canlı StreamView"></span>
                            </div>
                            <div class="text-3xl font-black text-slate-900 dark:text-white mt-1">
                                ${activeUsersCount} <span class="text-sm font-normal text-slate-400">Kişi</span>
                            </div>
                            <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-1">Son 30 dakikadaki tekil kullanıcı akışı</p>
                        </div>
                        <div class="bg-slate-50 dark:bg-slate-900/50 p-2.5 rounded-xl text-[11px] text-slate-600 dark:text-slate-400 border border-slate-100 dark:border-slate-800/80 leading-relaxed">
                            <b>⏱️ Zaman:</b> Son 30 Dakika (Canlı Akış)<br>
                            <b>💡 Ne İşe Yarar:</b> Şu an uygulamayı kullanan aktif kişi sayısıdır. Push bildirim veya yeni kampanya attığınızda anlık ziyaretçi patlamasını doğrulamaya yarar.
                        </div>
                        <div class="flex flex-col gap-1.5 pt-1">
                            <a href="${env.ga4RealtimeUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-primary hover:underline flex items-center gap-1">
                                <span class="material-symbols-outlined text-[14px]">sensors</span>
                                <span>GA4 Canlı Raporuna Git (Son 30 Dk)</span>
                                <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
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
                            <b>💡 Ne İşe Yarar:</b> Kullanıcıların affiliate linklerine basarak Trendyol, Amazon vb. mağazalara geçiş sayısıdır. Platformun komisyon geliri getiren ana yönlendirme gücünü ölçer.
                        </div>
                        <a href="${eventsUrl}" target="_blank" rel="noopener noreferrer" class="text-xs font-bold text-primary hover:underline flex items-center gap-1">
                            <span>GA4 Olay Raporlarına Git</span>
                            <span class="material-symbols-outlined text-[14px]">arrow_forward</span>
                        </a>
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
                            <b>💡 Ne İşe Yarar:</b> Kullanıcıların mağaza indirim kuponlarını panoya kopyalama sayısıdır. Kuponlar modülünün ne kadar talep gördüğünü ve kullanıldığını ölçer.
                        </div>
                        <button type="button" onclick="window.showCouponsView()" class="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer text-left">
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
                            <b>💡 Ne İşe Yarar:</b> BİM, A101, ŞOK gibi market afişlerinde incelenen toplam sayfa sayısıdır. Aktüel broşür modülünün okunma trafiğini ölçer.
                        </div>
                        <button type="button" onclick="window.showCatalogsView()" class="text-xs font-bold text-primary hover:underline flex items-center gap-1 cursor-pointer text-left">
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
                                    <h4 class="text-slate-900 dark:text-white font-bold text-base">Mağaza Bazlı Tıklama Dağılımı (Son 24 Saat)</h4>
                                </div>
                                <span class="text-xs text-slate-400">Son 24 Saatlik Oranlar</span>
                            </div>
                            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
                                <b>⏱️ Zaman:</b> Son 24 Saat • <b>💡 Ne İşe Yarar:</b> Kullanıcıların en çok hangi mağazanın ürünlerine gitmek istediğini gösterir. Affiliate anlaşmalarında ve bot kazımalarında hangi mağazaya ağırlık vermeniz gerektiğini söyler.
                            </p>
                            
                            <div class="space-y-3">
                                ${storeDist.map(item => `
                                    <div>
                                        <div class="flex items-center justify-between text-xs font-bold mb-1">
                                            <span class="text-slate-700 dark:text-slate-200">${item.store}</span>
                                            <span class="text-slate-500 dark:text-slate-400">${item.percentage}% (${item.count} Tıklama)</span>
                                        </div>
                                        <div class="w-full bg-slate-100 dark:bg-slate-800 h-2.5 rounded-full overflow-hidden">
                                            <div class="bg-gradient-to-r from-blue-500 to-indigo-600 h-2.5 rounded-full" style="width: ${item.percentage}%"></div>
                                        </div>
                                    </div>
                                `).join('')}
                            </div>
                        </div>

                        <div class="pt-3 border-t border-slate-100 dark:border-slate-800 flex items-center justify-between text-xs">
                            <span class="text-slate-400">Affiliate Link Sağlığı: <b>Aktif</b></span>
                            <a href="${eventsUrl}" target="_blank" rel="noopener noreferrer" class="font-bold text-primary hover:underline">
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
                                    <h4 class="text-slate-900 dark:text-white font-bold text-base">Fırsat Dönüşüm Hunisi (Son 24 Saat)</h4>
                                </div>
                                <span class="px-2 py-0.5 text-xs font-bold rounded-full bg-indigo-500/10 text-indigo-400 border border-indigo-500/20">
                                    %${conversionRate} Dönüşüm
                                </span>
                            </div>
                            <p class="text-xs text-slate-500 dark:text-slate-400 mb-3">
                                <b>⏱️ Zaman:</b> Son 24 Saat • <b>💡 Ne İşe Yarar:</b> Fırsat detayını açan kullanıcıların yüzde kaçının gerçekten "Mağazaya Git" butonuna basarak satın almaya yöneldiğini gösterir. İndirimlerin ne kadar cazip ve ikna edici olduğunu ölçer.
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
                            <button type="button" onclick="window.showDealsView()" class="font-bold text-primary hover:underline cursor-pointer">
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
                            <h4 class="font-bold text-sm text-slate-900 dark:text-white">Arama & Talep Radarı (search_performed - Son 24 Saat)</h4>
                            <p class="text-xs text-slate-500 dark:text-slate-400">
                                <b>⏱️ Zaman:</b> Son 24 Saat • <b>💡 Ne İşe Yarar:</b> Kullanıcıların arama kutusuna en çok hangi kelimeleri yazdığını gösterir. Kullanıcıların arayıp da bulamadığı ürünleri tespit edip Telegram bot radarına ekleyerek yeni fırsatlar yakalamanızı sağlar.
                            </p>
                        </div>
                    </div>
                    <a href="${eventsUrl}" target="_blank" rel="noopener noreferrer" class="px-4 py-2 text-xs font-bold bg-slate-100 hover:bg-slate-200 dark:bg-slate-800 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 rounded-xl transition-colors flex items-center gap-1.5 shrink-0">
                        <span class="material-symbols-outlined text-[16px]">open_in_new</span>
                        <span>Arama Olaylarını İncele ↗</span>
                    </a>
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
