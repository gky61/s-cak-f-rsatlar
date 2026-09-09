/**
 * FırsatKolik Web Admin - Modüler Affiliate Yöneticisi ve Mağaza Adaptörleri
 * Her mağaza kendi izole adaptörüne sahiptir; ortak dosyaları kirletmeden yeni mağaza eklenebilir.
 */

const AffiliateManager = {
    adapters: {
        // Teknosa Paylaş Kazan (Winfluenced / TUNE HasOffers)
        teknosa: {
            name: 'Teknosa',
            canHandle: function(url) {
                const host = url.hostname.toLowerCase();
                return host.includes('teknosa.com') || host.includes('paylaskazan.teknosa.com') || host.includes('btrck.com');
            },
            isAlreadyAffiliate: function(url, config) {
                const host = url.hostname.toLowerCase();
                if (host.includes('paylaskazan.teknosa.com')) return false;
                const userId = (config?.teknosa?.userId || '906bd201-92dc-4898-914a-10309b2cd576').trim().toLowerCase();
                // Yalnızca btrck.com ise VE source/aff_sub adminin kendi userId'si ise hazır sayılır
                if (host.includes('btrck.com')) {
                    const source = (url.searchParams.get('source') || url.searchParams.get('aff_sub') || '').trim().toLowerCase();
                    const isOwner = Boolean(userId && source && source === userId);
                    if (!isOwner) return false;

                    // Normalizasyon kontrolü: Eğer link eski %2F formatında ise, henüz tam normalize edilmemiş say
                    if (url.search.includes('aff_sub3=teknosa.com%2F') || url.search.includes('aff_sub3=teknosa.com%2f')) {
                        return false;
                    }
                    return true;
                }
                return false;
            },
            convert: function(url, config) {
                const cfg = config?.teknosa;
                const userId = (cfg?.userId || '906bd201-92dc-4898-914a-10309b2cd576').trim();
                let targetProductUrl = url;

                // 1. Eğer link bir btrck.com linki ise (eski %2F'li link veya yabancı affiliate), gömülü parametrelerden gerçek ürünü al
                if (url.hostname.toLowerCase().includes('btrck.com')) {
                    const embedded = url.searchParams.get('url');
                    if (embedded) {
                        try {
                            const parsed = new URL(embedded);
                            if (parsed.hostname.toLowerCase().includes('teknosa.com') && !parsed.hostname.toLowerCase().includes('paylaskazan.')) {
                                targetProductUrl = parsed;
                            }
                        } catch (_) {}
                    } else {
                        const affSub3Param = url.searchParams.get('aff_sub3');
                        if (affSub3Param && affSub3Param.includes('teknosa.com')) {
                            try {
                                const decoded = decodeURIComponent(affSub3Param);
                                targetProductUrl = new URL('https://www.' + decoded);
                            } catch (_) {}
                        }
                    }
                }

                // 2. Kill-switch / Fallback kontrolü: Eğer teknosa affiliate kapalıysa (enabled === false) veya userId yoksa temiz ürün linkini döndür
                if (cfg && cfg.enabled === false) {
                    targetProductUrl.searchParams.delete('utm_source');
                    targetProductUrl.searchParams.delete('utm_medium');
                    targetProductUrl.searchParams.delete('utm_campaign');
                    return targetProductUrl.toString();
                }

                try {
                    if (targetProductUrl.hostname.toLowerCase().includes('paylaskazan.teknosa.com')) {
                        return url.toString();
                    }

                    let productPath = targetProductUrl.pathname.startsWith('/') ? targetProductUrl.pathname.substring(1) : targetProductUrl.pathname;
                    if (!productPath) {
                        return targetProductUrl.toString();
                    }
                    try {
                        productPath = decodeURIComponent(productPath).replace(/^\/+/, '');
                    } catch (_) {}

                    if (!productPath) {
                        return targetProductUrl.toString();
                    }

                    const affSub3 = `teknosa.com/${productPath}`;

                    targetProductUrl.searchParams.set('utm_source', 'social_affiliate');
                    targetProductUrl.searchParams.set('utm_medium', 'paylaskazan');
                    targetProductUrl.searchParams.set('utm_campaign', userId);
                    const targetUrlWithUtm = targetProductUrl.toString();

                    // TUNE doğrudan yönlendirme URL'si oluştur (aff_sub3 düz slash formatında)
                    const encodedTargetUrl = encodeURIComponent(targetUrlWithUtm);
                    return `https://rdr.btrck.com/aff_c?offer_id=5&aff_id=1016&source=${userId}&aff_sub=${userId}&aff_sub3=${affSub3}&url=${encodedTargetUrl}`;
                } catch (e) {
                    return targetProductUrl.toString();
                }
            }
        },


        // Trendyol
        trendyol: {
            name: 'Trendyol',
            canHandle: function(url) {
                const host = url.hostname.toLowerCase();
                return host.includes('trendyol.com') || host.includes('ty.gl');
            },
            isAlreadyAffiliate: function(url, config) {
                if (url.hostname.toLowerCase().includes('ty.gl')) return false;
                const boutiqueId = config?.trendyol?.boutiqueId;
                return Boolean(boutiqueId && url.searchParams.get('boutiqueId') === boutiqueId);
            },
            convert: function(url, config) {
                const boutiqueId = config?.trendyol?.boutiqueId;
                url.searchParams.delete('boutiqueId');
                if (boutiqueId) {
                    url.searchParams.set('boutiqueId', boutiqueId);
                }
                return url.toString();
            }
        },

        // Hepsiburada LinkGelir (Adjust 7t4g.adj.st Universal Deep-Link)
        hepsiburada: {
            name: 'Hepsiburada',
            canHandle: function(url) {
                const host = url.hostname.toLowerCase();
                return host.includes('hepsiburada.com') ||
                    host.includes('hb.biz') ||
                    host.includes('7t4g.adj.st') ||
                    (host.includes('adjust.') && url.search.includes('sku='));
            },
            isAlreadyAffiliate: function(url, config) {
                const host = url.hostname.toLowerCase();
                if (host.includes('hb.biz')) return false;

                const cfg = config?.hepsiburada;
                const accountName = cfg?.accountName || 'muratcan gokyokus';

                if (host.includes('7t4g.adj.st') || host.includes('adjust.')) {
                    const adgroup = url.searchParams.get('adj_adgroup');
                    return Boolean(adgroup && adgroup.trim().toLowerCase() === accountName.trim().toLowerCase());
                }
                return false;
            },
            convert: function(url, config) {
                const cfg = config?.hepsiburada;
                const accountName = (cfg?.accountName || 'muratcan gokyokus').trim();
                const trackerToken = cfg?.trackerToken || '10zuiki3_y4q2fze';
                const campaign = cfg?.campaign || 'ux_gelistirmeleri';
                const utmCampaign = 'sc:hb-ecom.sr:influencer.md:linkgelir';

                let targetProductUrl = url;

                // 1. Eğer gelen link bir Adjust linki ise, adj_fallback parametresinden gerçek ürünü al
                if (url.hostname.toLowerCase().includes('7t4g.adj.st') || url.hostname.toLowerCase().includes('adjust.')) {
                    const fallback = url.searchParams.get('adj_fallback');
                    if (fallback) {
                        try {
                            const parsed = new URL(fallback);
                            if (parsed.hostname.toLowerCase().includes('hepsiburada.com')) {
                                targetProductUrl = parsed;
                            }
                        } catch (_) {}
                    }
                }

                // 2. Kill-switch / Fallback kontrolü: Eğer affiliate kapalıysa temiz kanonik ürün linkini döndür
                if (!cfg || cfg.enabled === false || !accountName) {
                    return `${targetProductUrl.protocol}//${targetProductUrl.host}${targetProductUrl.pathname}`;
                }

                try {
                    if (targetProductUrl.hostname.toLowerCase().includes('hb.biz')) {
                        return url.toString();
                    }

                    // SKU ayıkla
                    let sku = targetProductUrl.searchParams.get('sku');
                    if (!sku) {
                        const match = targetProductUrl.pathname.match(/-p[m]?-([a-zA-Z0-9]+)/i);
                        if (match) {
                            sku = match[1];
                        }
                    }

                    if (!sku) {
                        return `${targetProductUrl.protocol}//${targetProductUrl.host}${targetProductUrl.pathname}`;
                    }

                    const merchantName = targetProductUrl.searchParams.get('magaza') || targetProductUrl.searchParams.get('merchantName');

                    const cleanBaseUrl = `${targetProductUrl.protocol}//${targetProductUrl.host}${targetProductUrl.pathname}`;
                    const fallbackUrlObj = new URL(cleanBaseUrl);
                    if (merchantName) fallbackUrlObj.searchParams.set('magaza', merchantName);
                    fallbackUrlObj.searchParams.set('url_src', 'and-product-detail');
                    fallbackUrlObj.searchParams.set('utm_campaign', utmCampaign);
                    fallbackUrlObj.searchParams.set('utm_medium', 'linkgelir');
                    fallbackUrlObj.searchParams.set('utm_source', 'influencer');
                    fallbackUrlObj.searchParams.set('wt_inf', 'affiliate');
                    const finalFallbackUrl = fallbackUrlObj.toString();

                    let hbappDeepLink = `hbapp://product?sku=${sku}&url_src=and-product-detail&utm_source=influencer&utm_medium=linkgelir&utm_campaign=${encodeURIComponent(utmCampaign)}`;
                    if (merchantName) {
                        hbappDeepLink += `&merchantName=${encodeURIComponent(merchantName)}`;
                    }

                    const encodedHbapp = encodeURIComponent(hbappDeepLink);
                    const encodedFallback = encodeURIComponent(finalFallbackUrl);
                    const encodedAdgroup = encodeURIComponent(accountName);
                    const encodedUtmCampaign = encodeURIComponent(utmCampaign);

                    let finalUrl = `https://7t4g.adj.st/product?sku=${sku}`;
                    if (merchantName) {
                        finalUrl += `&merchantName=${encodeURIComponent(merchantName)}`;
                    }
                    finalUrl += `&url_src=and-product-detail&utm_source=influencer&utm_medium=linkgelir&utm_campaign=${encodedUtmCampaign}&adj_t=${trackerToken}&adj_deep_link=${encodedHbapp}&adj_fallback=${encodedFallback}&adj_campaign=${campaign}&adj_adgroup=${encodedAdgroup}&adj_creative=${sku}`;

                    return finalUrl;
                } catch (e) {
                    return targetProductUrl.toString();
                }
            }
        },

        // Amazon Associates
        amazon: {
            name: 'Amazon',
            canHandle: function(url) {
                const host = url.hostname.toLowerCase();
                return host.includes('amazon.') || host.includes('amzn.') || host.includes('link.amazon');
            },
            isAlreadyAffiliate: function(url, config) {
                const host = url.hostname.toLowerCase();
                if (host.includes('amzn.') || host.includes('link.amazon')) return false;
                const tag = config?.amazon?.tag || 'firsatkolik-21';
                return Boolean(tag && url.searchParams.get('tag')?.toLowerCase() === tag.toLowerCase());
            },
            convert: function(url, config) {
                const cfg = config?.amazon;
                const host = url.hostname.toLowerCase();

                // 1. Fallback / Kill-switch: Eğer affiliate kapalıysa temiz kanonik ürün linkini döndür
                if (!cfg || cfg.enabled === false || !cfg.tag) {
                    ['tag', 'ref', 'linkCode', 'ascsubtag', 'social_share', 'creative', 'camp', 'creativeASIN'].forEach(p => url.searchParams.delete(p));
                    return url.toString();
                }

                // 2. Kısa link durumundaysa (amzn.eu / amzn.to) henüz çözülmediği için olduğu gibi dön
                if (host.includes('amzn.') || host.includes('link.amazon')) {
                    return url.toString();
                }

                // 3. ASIN ayıklama
                let asin = null;
                const path = url.pathname;
                const match = path.match(/\/(?:dp|gp\/product|gp\/aw\/d|product)\/([A-Z0-9]{10})(?:[/?]|$)/i) ||
                              path.match(/\/([B0-9][A-Z0-9]{9})(?:[/?]|$)/i);
                if (match) {
                    asin = match[1].toUpperCase();
                }

                // 4. Anti-hijacking: Yabancı takip parametrelerini temizle
                ['tag', 'ref', 'linkCode', 'ascsubtag', 'social_share', 'creative', 'camp', 'creativeASIN'].forEach(p => url.searchParams.delete(p));
                const paramsToDelete = [];
                url.searchParams.forEach((val, key) => {
                    if (key.toLowerCase().startsWith('ref_')) paramsToDelete.push(key);
                });
                paramsToDelete.forEach(p => url.searchParams.delete(p));

                // Resmi tag'i ekle
                url.searchParams.set('tag', cfg.tag.trim());

                if (asin) {
                    url.pathname = `/dp/${asin}`;
                }

                return url.toString();
            }
        },

        // N11
        n11: {
            name: 'N11',
            canHandle: function(url) {
                return url.hostname.toLowerCase().includes('n11.com');
            },
            isAlreadyAffiliate: function(url, config) {
                if (url.hostname.toLowerCase().includes('sl.n11.com')) return false;
                const refId = config?.n11?.refId;
                return Boolean(refId && url.searchParams.get('ref') === refId);
            },
            convert: function(url, config) {
                const refId = config?.n11?.refId;
                url.searchParams.delete('ref');
                if (refId) {
                    url.searchParams.set('ref', refId);
                }
                return url.toString();
            }
        },

        // GittiGidiyor
        gittigidiyor: {
            name: 'GittiGidiyor',
            canHandle: function(url) {
                return url.hostname.toLowerCase().includes('gittigidiyor.com');
            },
            isAlreadyAffiliate: function(url, config) {
                const affId = config?.gittigidiyor?.affiliateId;
                return Boolean(affId && url.searchParams.get('affiliateId') === affId);
            },
            convert: function(url, config) {
                const affId = config?.gittigidiyor?.affiliateId;
                url.searchParams.delete('affiliateId');
                if (affId) {
                    url.searchParams.set('affiliateId', affId);
                }
                return url.toString();
            }
        },

        // İncehesap Paylaştıkça Kazan (/u/{code}/)
        incehesap: {
            name: 'İncehesap',
            extractProductId: function(url) {
                if (!url) return null;
                const path = url.pathname || '';
                const match = path.match(/-fiyati-(\d+)(?:\/|$)/i);
                if (match) return match[1];
                return url.searchParams.get('urunId') || url.searchParams.get('productId') || url.searchParams.get('id') || null;
            },
            canHandle: function(url) {
                const host = url.hostname.toLowerCase();
                return host.contains ? host.contains('incehesap.com') : host.includes('incehesap.com');
            },
            isAlreadyAffiliate: function(url, config) {
                const host = url.hostname.toLowerCase();
                if (!host.includes('incehesap.com')) return false;
                return /^\/u\/[a-zA-Z0-9_-]+\/?$/i.test(url.pathname);
            },
            convert: function(url, config) {
                const cfg = config?.incehesap;
                let targetProductUrl = url;

                // 1. Kill-switch / Fallback kontrolü: Eğer affiliate kapalıysa temiz ürün linkini döndür
                if (cfg && cfg.enabled === false) {
                    targetProductUrl.searchParams.delete('utm_source');
                    targetProductUrl.searchParams.delete('utm_medium');
                    targetProductUrl.searchParams.delete('utm_campaign');
                    targetProductUrl.searchParams.delete('ref');
                    targetProductUrl.search = '';
                    return targetProductUrl.toString();
                }

                // 2. Link zaten bir Paylaştıkça Kazan linki ise aynen koru
                if (/^\/u\/[a-zA-Z0-9_-]+\/?$/i.test(url.pathname)) {
                    let path = url.pathname;
                    if (!path.endsWith('/')) path = `${path}/`;
                    return `${url.protocol}//${url.host}${path}`;
                }

                // 3. Kanonik URL ise takip parametrelerini temizleyerek dön
                targetProductUrl.search = '';
                return targetProductUrl.toString();
            }
        }
    },

    /**
     * Aktif olarak affiliate akışları ve UI/UX görünümü açılmış onaylı mağazalar listesi.
     * Yeni bir mağazanın affiliate entegrasyonu tamamlanıp test edildiğinde bu listeye eklenir.
     */
    activeStores: ['teknosa', 'hepsiburada', 'amazon', 'incehesap'],

    /**
     * Verilen mağaza adı veya URL için affiliate desteğinin aktif olup olmadığını döner.
     * Hem mağazanın sistemde onaylı olması hem de şalterinin AÇIK (enabled !== false) olması gerekir.
     */
    isStoreSupported: function(storeOrUrl, config) {
        if (!storeOrUrl) return false;
        const cfg = config || (typeof affiliateConfig !== 'undefined' ? affiliateConfig : null);
        const str = String(storeOrUrl).trim().toLowerCase();

        // 1. Doğrudan mağaza anahtarı veya adı kontrolü
        for (const key of this.activeStores) {
            if (cfg && cfg[key] && cfg[key].enabled === false) {
                continue;
            }
            if (str === key) return true;
            const adapter = this.adapters[key];
            if (adapter && adapter.name.toLowerCase() === str) return true;
        }

        // 2. URL üzerinden kontrol
        try {
            const urlObj = new URL(str.startsWith('http') ? str : `https://${str}`);
            for (const key of this.activeStores) {
                if (cfg && cfg[key] && cfg[key].enabled === false) {
                    continue;
                }
                const adapter = this.adapters[key];
                if (adapter && adapter.canHandle(urlObj)) {
                    return true;
                }
            }
        } catch (_) {}

        return false;
    },

    /**
     * Verilen linkin admine ait hazır bir affiliate linki olup olmadığını kontrol eder.
     * Şalter kapalıysa bu mağazanın linki 'hazır affiliate' olarak sayılmaz.
     */
    isAlreadyAffiliate: function(originalUrl, config) {
        if (!originalUrl || typeof originalUrl !== 'string') return false;
        const cfg = config || (typeof affiliateConfig !== 'undefined' ? affiliateConfig : null);
        try {
            const urlObj = new URL(originalUrl.trim());
            for (const key of this.activeStores) {
                if (cfg && cfg[key] && cfg[key].enabled === false) {
                    continue;
                }
                const adapter = this.adapters[key];
                if (adapter && adapter.canHandle(urlObj) && typeof adapter.isAlreadyAffiliate === 'function') {
                    if (adapter.isAlreadyAffiliate(urlObj, cfg)) return true;
                }
            }
        } catch (_) {}
        return false;
    },

    /**
     * Orijinal linki uygun mağaza adaptörünü bularak affiliate linkine dönüştürür.
     */
    convert: function(originalUrl, config) {
        if (!originalUrl || typeof originalUrl !== 'string') return originalUrl;

        try {
            const urlObj = new URL(originalUrl.trim());
            for (const key in this.adapters) {
                // Sadece canlı desteği onaylanmış aktif mağazaların adaptörlerini çalıştır
                if (!this.activeStores.includes(key)) {
                    continue;
                }
                const adapter = this.adapters[key];
                if (adapter.canHandle(urlObj)) {
                    if (adapter.isAlreadyAffiliate(urlObj, config)) {
                        console.log(`ℹ️ [AffiliateManager] Link zaten ${adapter.name} affiliate linki:`, originalUrl);
                        return originalUrl;
                    }
                    const converted = adapter.convert(urlObj, config);
                    console.log(`✅ [AffiliateManager] ${adapter.name} affiliate linkine dönüştürüldü:`, converted);
                    return converted;
                }
            }
            return originalUrl;
        } catch (e) {
            console.error('Affiliate dönüştürme hatası:', e);
            return originalUrl;
        }
    },

    /**
     * URL'den mağaza adını tespit eder.
     */
    detectStore: function(originalUrl) {
        if (!originalUrl || typeof originalUrl !== 'string') return 'Bilinmeyen';

        try {
            const urlObj = new URL(originalUrl.trim());
            for (const key in this.adapters) {
                const adapter = this.adapters[key];
                if (adapter.canHandle(urlObj)) {
                    return adapter.name;
                }
            }
            const host = urlObj.hostname.toLowerCase();
            if (host.includes('havitstore.com.tr')) return 'Havit';
            if (host.includes('migros.com.tr')) return 'Migros';
            if (host.includes('getir.com')) return 'Getir';
            if (host.includes('boyner.com.tr')) return 'Boyner';
            return 'Bilinmeyen';
        } catch (_) {
            return 'Bilinmeyen';
        }
    },

    /**
     * URL'deki affiliate ve takip parametrelerini temizleyerek orijinal mağaza linkini döndürür.
     * rdr.btrck.com gibi yönlendirme linklerini de unwrap ederek gerçek ürün linkini çıkarır.
     */
    cleanProductUrl: function(urlStr) {
        if (!urlStr || typeof urlStr !== 'string') return '';
        try {
            let trimmed = urlStr.trim();
            let urlObj = new URL(trimmed);

            // 1. btrck.com gibi affiliate/yönlendirme linklerini unwrap et (Teknosa)
            if (urlObj.hostname.toLowerCase().includes('btrck.com')) {
                const embedded = urlObj.searchParams.get('url');
                if (embedded) {
                    try {
                        const parsed = new URL(decodeURIComponent(embedded));
                        if (!parsed.hostname.toLowerCase().includes('paylaskazan.')) {
                            urlObj = parsed;
                        }
                    } catch (_) {}
                } else {
                    const affSub3 = urlObj.searchParams.get('aff_sub3');
                    if (affSub3 && affSub3.includes('teknosa.com')) {
                        try {
                            const decoded = decodeURIComponent(affSub3);
                            const full = decoded.startsWith('http') ? decoded : 'https://www.' + decoded;
                            urlObj = new URL(full);
                        } catch (_) {}
                    }
                }
            }
            // 2. 7t4g.adj.st veya adjust linklerini unwrap et (Hepsiburada LinkGelir)
            else if (urlObj.hostname.toLowerCase().includes('7t4g.adj.st') ||
                (urlObj.hostname.toLowerCase().includes('adj.st') && urlObj.searchParams.has('adj_fallback')) ||
                (urlObj.hostname.toLowerCase().includes('adjust.') && urlObj.searchParams.has('adj_fallback'))) {
                const fallback = urlObj.searchParams.get('adj_fallback');
                if (fallback) {
                    try {
                        const parsed = new URL(decodeURIComponent(fallback));
                        if (parsed.hostname.toLowerCase().includes('hepsiburada.com')) {
                            urlObj = parsed;
                        }
                    } catch (_) {}
                }
            }

            const host = urlObj.hostname.toLowerCase();

            // Teknosa
            if (host.includes('teknosa.com')) {
                ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'utm_term', 'ref'].forEach(p => urlObj.searchParams.delete(p));
            }
            // Amazon
            else if (host.includes('amazon.') || host.includes('amzn.')) {
                ['tag', 'ref', 'linkCode', 'ascsubtag', 'creative', 'camp'].forEach(p => urlObj.searchParams.delete(p));
            }
            // Trendyol
            else if (host.includes('trendyol.com')) {
                ['boutiqueId', 'merchantId', 'adjust_t', 'utm_source', 'utm_medium', 'utm_campaign'].forEach(p => urlObj.searchParams.delete(p));
            }
            // Hepsiburada
            else if (host.includes('hepsiburada.com')) {
                ['utm_source', 'utm_medium', 'utm_campaign', 'utm_content', 'wt_inf'].forEach(p => urlObj.searchParams.delete(p));
            }
            // N11
            else if (host.includes('n11.com')) {
                ['ref', 'utm_source', 'utm_medium', 'utm_campaign'].forEach(p => urlObj.searchParams.delete(p));
            }
            // İncehesap
            else if (host.includes('incehesap.com')) {
                ['utm_source', 'utm_medium', 'utm_campaign', 'ref', 'affiliate'].forEach(p => urlObj.searchParams.delete(p));
            }

            return urlObj.toString();
        } catch (_) {
            return urlStr;
        }
    }
};

// Node.js veya tarayıcı ortam desteği
if (typeof module !== 'undefined' && module.exports) {
    module.exports = AffiliateManager;
}
