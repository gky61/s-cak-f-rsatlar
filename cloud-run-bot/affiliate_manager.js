/**
 * FırsatKolik Cloud Run Telegram Bot - Modüler Affiliate Yöneticisi
 * Telegram scraper botları ve geçmiş çekme servisleri için merkezi gelir ortaklığı motoru.
 * Dart istemcisi (AffiliateService) ve Web Admin (AffiliateManager) ile %100 senkronize çalışır.
 */

const AffiliateManager = {
  adapters: {
    // 1. Amazon Associates TR (amazon.com.tr)
    amazon: {
      name: 'Amazon',
      canHandle: function(url) {
        const host = url.hostname.toLowerCase();
        return host.includes('amazon.') || host.includes('amzn.') || host.includes('link.amazon');
      },
      isAlreadyAffiliate: function(url, config) {
        const host = url.hostname.toLowerCase();
        if (host.includes('amzn.') || host.includes('link.amazon')) return false;
        const tag = (config?.amazonAffiliateTag || config?.amazon?.tag || 'firsatkolik-21').trim().toLowerCase();
        const currentTag = url.searchParams.get('tag')?.trim()?.toLowerCase();
        return Boolean(tag && currentTag === tag);
      },
      convert: function(url, config) {
        const isEnabled = config?.amazonAffiliateEnabled !== false && config?.amazon?.enabled !== false;
        const tag = (config?.amazonAffiliateTag || config?.amazon?.tag || 'firsatkolik-21').trim();
        const host = url.hostname.toLowerCase();

        // 1. Fallback / Kill-switch: Eğer affiliate kapalıysa veya tag boşsa temiz kanonik linki döndür
        if (!isEnabled || !tag) {
          ['tag', 'ref', 'linkCode', 'ascsubtag', 'social_share', 'creative', 'camp', 'creativeASIN'].forEach(p => url.searchParams.delete(p));
          const toDelete = [];
          url.searchParams.forEach((val, key) => {
            if (key.toLowerCase().startsWith('ref_')) toDelete.push(key);
          });
          toDelete.forEach(p => url.searchParams.delete(p));
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

        // 4. Anti-hijacking: Yabancı takip parametrelerini ve rakip tag'lerini temizle
        ['tag', 'ref', 'linkCode', 'ascsubtag', 'social_share', 'creative', 'camp', 'creativeASIN'].forEach(p => url.searchParams.delete(p));
        const paramsToDelete = [];
        url.searchParams.forEach((val, key) => {
          if (key.toLowerCase().startsWith('ref_')) paramsToDelete.push(key);
        });
        paramsToDelete.forEach(p => url.searchParams.delete(p));

        // Resmi takip kimliğimizi (Tracking ID) ekle
        url.searchParams.set('tag', tag);

        if (asin) {
          url.pathname = `/dp/${asin}`;
        }

        return url.toString();
      }
    },

    // 2. Hepsiburada LinkGelir (Adjust DeepLink)
    hepsiburada: {
      name: 'Hepsiburada',
      canHandle: function(url) {
        const host = url.hostname.toLowerCase();
        return host.includes('hepsiburada.com') ||
               host.includes('hb.biz') ||
               host.includes('app.hb.biz') ||
               host.includes('7t4g.adj.st') ||
               (host.includes('adjust.') && url.search.includes('sku='));
      },
      isAlreadyAffiliate: function(url, config) {
        const host = url.hostname.toLowerCase();
        if (host.includes('hb.biz') || host.includes('app.hb.biz')) return false;
        const accountName = (config?.hepsiburadaAccountName || config?.hepsiburada?.accountName || 'muratcan gokyokus').trim().toLowerCase();
        if (host.includes('7t4g.adj.st') || host.includes('adjust.')) {
          let adgroup = url.searchParams.get('adj_adgroup');
          if (adgroup) {
            try {
              if (adgroup.includes('%')) adgroup = decodeURIComponent(adgroup);
            } catch (_) {}
            return Boolean(accountName && adgroup.trim().toLowerCase() === accountName);
          }
        }
        return false;
      },
      convert: function(url, config) {
        const isEnabled = config?.hepsiburadaAffiliateEnabled !== false && config?.hepsiburada?.enabled !== false;
        const accountName = (config?.hepsiburadaAccountName || config?.hepsiburada?.accountName || 'muratcan gokyokus').trim();
        const trackerToken = (config?.hepsiburadaTrackerToken || config?.hepsiburada?.trackerToken || '10zuiki3_y4q2fze').trim();
        const campaign = (config?.hepsiburadaCampaign || config?.hepsiburada?.campaign || 'ux_gelistirmeleri').trim();
        const utmCampaign = 'sc:hb-ecom.sr:influencer.md:linkgelir';
        const utmSource = 'influencer';
        const utmMedium = 'linkgelir';
        const wtInf = 'affiliate';

        let targetProductUrl = url;

        // 1. Eğer gelen link bir Adjust linki ise, adj_fallback parametresinden gerçek ürünü al (0 ms unwrap)
        if (url.hostname.toLowerCase().includes('7t4g.adj.st') || url.hostname.toLowerCase().includes('adjust.')) {
          let fallback = url.searchParams.get('adj_fallback') || url.searchParams.get('fallback');
          if (fallback) {
            try {
              if (fallback.includes('%')) {
                try { fallback = decodeURIComponent(fallback); } catch (_) {}
              }
              const parsed = new URL(fallback);
              if (parsed.hostname.toLowerCase().includes('hepsiburada.com')) {
                targetProductUrl = parsed;
              }
            } catch (_) {}
          }
        }

        // 2. Kill-switch / Fallback kontrolü: Eğer affiliate kapalıysa temiz kanonik ürün linkini döndür
        if (!isEnabled || !accountName) {
          return `${targetProductUrl.protocol}//${targetProductUrl.host}${targetProductUrl.pathname}`;
        }

        try {
          if (targetProductUrl.hostname.toLowerCase().includes('hb.biz')) {
            return url.toString();
          }

          // SKU ayıkla (-p- veya -pm- veya query)
          let sku = targetProductUrl.searchParams.get('sku') || targetProductUrl.searchParams.get('productId');
          if (!sku) {
            const match = targetProductUrl.pathname.match(/-p[m]?-([a-zA-Z0-9]+)/i);
            if (match) {
              sku = match[1].toUpperCase();
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
          fallbackUrlObj.searchParams.set('utm_medium', utmMedium);
          fallbackUrlObj.searchParams.set('utm_source', utmSource);
          fallbackUrlObj.searchParams.set('wt_inf', wtInf);
          const finalFallbackUrl = fallbackUrlObj.toString();

          let hbappDeepLink = `hbapp://product?sku=${sku}&url_src=and-product-detail&utm_source=${utmSource}&utm_medium=${utmMedium}&utm_campaign=${encodeURIComponent(utmCampaign)}`;
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
          finalUrl += `&url_src=and-product-detail&utm_source=${utmSource}&utm_medium=${utmMedium}&utm_campaign=${encodedUtmCampaign}&adj_t=${trackerToken}&adj_deep_link=${encodedHbapp}&adj_fallback=${encodedFallback}&adj_campaign=${campaign}&adj_adgroup=${encodedAdgroup}&adj_creative=${sku}`;

          return finalUrl;
        } catch (_) {
          return targetProductUrl.toString();
        }
      }
    },

    // 3. Teknosa Paylaş Kazan (Winfluenced / TUNE HasOffers)
    teknosa: {
      name: 'Teknosa',
      canHandle: function(url) {
        const host = url.hostname.toLowerCase();
        return host.includes('teknosa.com') || host.includes('paylaskazan.teknosa.com') || host.includes('btrck.com');
      },
      isAlreadyAffiliate: function(url, config) {
        const host = url.hostname.toLowerCase();
        if (host.includes('paylaskazan.teknosa.com')) return false;

        const userId = (config?.teknosaUserId || config?.teknosa?.userId || '906bd201-92dc-4898-914a-10309b2cd576').trim().toLowerCase();
        if (host.includes('btrck.com')) {
          const source = (url.searchParams.get('source') || url.searchParams.get('aff_sub') || '').trim().toLowerCase();
          const isOwner = Boolean(userId && source && source === userId);
          if (!isOwner) return false;

          // Normalizasyon kontrolü: Eğer link eski %2F formatında ise (aff_sub3=teknosa.com%2F...),
          // henüz normalize edilmemiş kabul et ki convert() onu Teknosa'nın yerel düz slash standardına yükseltsin.
          const rawSearch = url.search || '';
          if (rawSearch.includes('aff_sub3=teknosa.com%2F') || rawSearch.includes('aff_sub3=teknosa.com%2f')) {
            return false;
          }
          return true;
        }
        return false;
      },
      convert: function(url, config) {
        const isEnabled = config?.teknosaAffiliateEnabled !== false && config?.teknosa?.enabled !== false;
        const userId = (config?.teknosaUserId || config?.teknosa?.userId || '906bd201-92dc-4898-914a-10309b2cd576').trim();
        const offerId = (config?.teknosaOfferId || config?.teknosa?.offerId || '5').trim();
        const affId = (config?.teknosaAffId || config?.teknosa?.affId || '1016').trim();

        let targetProductUrl = url;

        // 1. btrck.com unwrap (url veya aff_sub3 parametresi)
        if (url.hostname.toLowerCase().includes('btrck.com')) {
          const embedded = url.searchParams.get('url');
          if (embedded) {
            try {
              const parsed = new URL(decodeURIComponent(embedded));
              if (parsed.hostname.toLowerCase().includes('teknosa.com') && !parsed.hostname.toLowerCase().includes('paylaskazan.')) {
                targetProductUrl = parsed;
              }
            } catch (_) {}
          } else {
            const affSub3Param = url.searchParams.get('aff_sub3');
            if (affSub3Param && affSub3Param.includes('teknosa.com')) {
              try {
                const decoded = decodeURIComponent(affSub3Param);
                targetProductUrl = new URL(decoded.startsWith('http') ? decoded : 'https://www.' + decoded);
              } catch (_) {}
            }
          }
        }

        // 2. Kill-switch / Fallback kontrolü: Kapalıysa veya userId yoksa temiz ürün linkine fallback yap
        if (!isEnabled || !userId) {
          targetProductUrl.searchParams.delete('utm_source');
          targetProductUrl.searchParams.delete('utm_medium');
          targetProductUrl.searchParams.delete('utm_campaign');
          return targetProductUrl.toString();
        }

        try {
          // Eğer hala paylaskazan.teknosa.com gibi bir kısa link ise unshorten edilmeden dönüştürülemez
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

          // Teknosa yerel Paylaş Kazan yönlendirmesiyle birebir aynı formatta (düz slash standardı):
          const affSub3 = `teknosa.com/${productPath}`;

          // Hedef linke UTM parametrelerini enjekte et (varsa shopId gibi pazaryeri parametreleri korunur)
          targetProductUrl.searchParams.set('utm_source', 'social_affiliate');
          targetProductUrl.searchParams.set('utm_medium', 'paylaskazan');
          targetProductUrl.searchParams.set('utm_campaign', userId);
          const targetUrlWithUtm = targetProductUrl.toString();

          const encodedTargetUrl = encodeURIComponent(targetUrlWithUtm);
          return `https://rdr.btrck.com/aff_c?offer_id=${offerId}&aff_id=${affId}&source=${userId}&aff_sub=${userId}&aff_sub3=${affSub3}&url=${encodedTargetUrl}`;
        } catch (_) {
          return targetProductUrl.toString();
        }
      }
    },

    // 4. İncehesap Paylaştıkça Kazan (/u/{code}/)
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
        return host.includes('incehesap.com');
      },
      isAlreadyAffiliate: function(url, config) {
        const host = url.hostname.toLowerCase();
        if (!host.includes('incehesap.com')) return false;
        return /^\/u\/[a-zA-Z0-9_-]+\/?$/i.test(url.pathname);
      },
      convert: function(url, config) {
        const isEnabled = config?.incehesapAffiliateEnabled !== false && config?.incehesap?.enabled !== false;
        let targetProductUrl = url;

        // 1. Kill-switch / Fallback kontrolü: Eğer affiliate kapalıysa temiz ürün linkini döndür
        if (!isEnabled) {
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
      },
      generateAffiliateLink: async function(productId, config) {
        if (!productId) return null;

        const cookie = (config?.incehesapSessionCookie && String(config.incehesapSessionCookie).trim()) ||
          'PHPSESSID=4jcp9cn663qg4mah0vqd3a1rkb; cki1=ao2er02bt4kj918fssb3i16svn;';

        try {
          const https = require('https');
          const postData = JSON.stringify({
            action: 'getSingleProductLink',
            urunId: Number(productId)
          });

          const options = {
            hostname: 'www.incehesap.com',
            port: 443,
            path: '/uye/paylastikca-kazan/ajax/update.php',
            method: 'POST',
            headers: {
              'Accept': 'application/json, text/plain, */*',
              'Content-Type': 'application/json;charset=UTF-8',
              'User-Agent': 'WhatsApp/2.23.4.15 A',
              'Origin': 'https://www.incehesap.com',
              'Referer': 'https://www.incehesap.com/',
              'Cookie': cookie,
              'Content-Length': Buffer.byteLength(postData)
            },
            timeout: 10000
          };

          const responseJson = await new Promise((resolve, reject) => {
            const apiReq = https.request(options, (apiRes) => {
              let body = '';
              apiRes.on('data', (chunk) => { body += chunk; });
              apiRes.on('end', () => {
                try {
                  resolve(JSON.parse(body));
                } catch (err) {
                  resolve({ error: 'Parse error', raw: body });
                }
              });
            });
            apiReq.on('error', (e) => reject(e));
            apiReq.write(postData);
            apiReq.end();
          });

          if (responseJson && responseJson.url && responseJson.url.includes('/u/')) {
            const match = responseJson.url.match(/\/u\/([a-zA-Z0-9_-]+)\/?/i);
            const code = match ? match[1] : null;
            if (code) {
              return {
                success: true,
                affiliateUrl: responseJson.url,
                code: code,
                earningText: responseJson.text || '',
                fromCache: false
              };
            }
          }
        } catch (e) {
          console.warn('Node generateAffiliateLink error:', e.message);
        }
        return null;
      }
    }
  },

  activeStores: ['amazon', 'hepsiburada', 'teknosa', 'incehesap'],

  isStoreSupported: function(storeOrUrl, config) {
    if (!storeOrUrl) return false;
    const str = String(storeOrUrl).trim().toLowerCase();

    for (const key of this.activeStores) {
      if (config && typeof config === 'object') {
        const isEnabled = config[`${key}AffiliateEnabled`] !== false && config[key]?.enabled !== false;
        if (!isEnabled) continue;
      }
      if (str === key) return true;
      const adapter = this.adapters[key];
      if (adapter && adapter.name.toLowerCase() === str) return true;
    }

    try {
      const urlObj = new URL(str.startsWith('http') ? str : `https://${str}`);
      for (const key of this.activeStores) {
        if (config && typeof config === 'object') {
          const isEnabled = config[`${key}AffiliateEnabled`] !== false && config[key]?.enabled !== false;
          if (!isEnabled) continue;
        }
        const adapter = this.adapters[key];
        if (adapter && adapter.canHandle(urlObj)) {
          return true;
        }
      }
    } catch (_) {}

    return false;
  },

  canHandle: function(storeOrUrl, config) {
    return this.isStoreSupported(storeOrUrl, config);
  },

  isAlreadyAffiliate: function(originalUrl, config) {
    if (!originalUrl || typeof originalUrl !== 'string') return false;
    const cfg = typeof config === 'string'
      ? { hepsiburadaAccountName: config, amazonAffiliateTag: config, teknosaUserId: config }
      : config;
    try {
      const urlObj = new URL(originalUrl.trim());
      for (const key of this.activeStores) {
        if (cfg && typeof cfg === 'object') {
          const isEnabled = cfg[`${key}AffiliateEnabled`] !== false && cfg[key]?.enabled !== false;
          if (!isEnabled) continue;
        }
        const adapter = this.adapters[key];
        if (adapter && adapter.canHandle(urlObj) && typeof adapter.isAlreadyAffiliate === 'function') {
          if (adapter.isAlreadyAffiliate(urlObj, cfg)) return true;
        }
      }
    } catch (_) {}
    return false;
  },

  convert: function(originalUrl, config) {
    if (!originalUrl || typeof originalUrl !== 'string') return originalUrl;

    try {
      const urlObj = new URL(originalUrl.trim());
      for (const key of this.activeStores) {
        const adapter = this.adapters[key];
        if (adapter && adapter.canHandle(urlObj)) {
          if (adapter.isAlreadyAffiliate(urlObj, config)) {
            return originalUrl;
          }
          return adapter.convert(urlObj, config);
        }
      }
      return originalUrl;
    } catch (e) {
      return originalUrl;
    }
  },

  resolveAndConvertToAffiliate: async function(originalUrl, config) {
    if (!originalUrl || typeof originalUrl !== 'string') return originalUrl;

    try {
      const urlObj = new URL(originalUrl.trim());

      // İncehesap kanonik ürün linki için dinamik canlı AJAX üretimi
      const incehesapAdapter = this.adapters.incehesap;
      if (incehesapAdapter && incehesapAdapter.canHandle(urlObj)) {
        const isEnabled = config?.incehesapAffiliateEnabled !== false && config?.incehesap?.enabled !== false;
        if (isEnabled) {
          if (incehesapAdapter.isAlreadyAffiliate(urlObj, config)) {
            return originalUrl;
          }
          const productId = incehesapAdapter.extractProductId(urlObj);
          if (productId) {
            const genRes = await incehesapAdapter.generateAffiliateLink(productId, config);
            if (genRes && genRes.affiliateUrl) {
              return genRes.affiliateUrl;
            }
          }
        }
      }

      return this.convert(originalUrl, config);
    } catch (e) {
      return this.convert(originalUrl, config);
    }
  },

  cleanProductUrl: function(urlStr) {
    if (!urlStr || typeof urlStr !== 'string') return '';
    try {
      let trimmed = urlStr.trim();
      let urlObj = new URL(trimmed);

      // btrck.com gibi yönlendirme linklerini unwrap et
      if (urlObj.hostname.toLowerCase().includes('btrck.com')) {
        const embedded = urlObj.searchParams.get('url');
        if (embedded) {
          try {
            const parsed = new URL(decodeURIComponent(embedded));
            if (parsed.hostname.toLowerCase().includes('teknosa.com') && !parsed.hostname.toLowerCase().includes('paylaskazan.')) {
              urlObj = parsed;
            }
          } catch (_) {}
        } else {
          const affSub3 = urlObj.searchParams.get('aff_sub3');
          if (affSub3 && affSub3.includes('teknosa.com')) {
            try {
              const decoded = decodeURIComponent(affSub3);
              urlObj = new URL(decoded.startsWith('http') ? decoded : 'https://www.' + decoded);
            } catch (_) {}
          }
        }
      } else if (urlObj.hostname.toLowerCase().includes('7t4g.adj.st') || urlObj.hostname.toLowerCase().includes('adj.st')) {
        const fallback = urlObj.searchParams.get('adj_fallback');
        if (fallback) {
          try {
            urlObj = new URL(decodeURIComponent(fallback));
          } catch (_) {}
        }
      }

      const host = urlObj.hostname.toLowerCase();
      if (host.includes('hepsiburada')) {
        const magaza = urlObj.searchParams.get('magaza');
        urlObj.search = '';
        if (magaza) {
          urlObj.searchParams.set('magaza', magaza);
        }
      } else if (host.includes('teknosa')) {
        const shopId = urlObj.searchParams.get('shopId');
        urlObj.search = '';
        if (shopId) {
          urlObj.searchParams.set('shopId', shopId);
        }
      } else {
        const majorStores = [
          'amazon', 'trendyol', 'n11', 'pazarama', 'pttavm',
          'zara', 'defacto', 'mavi', 'beymen', 'mediamarkt',
          'migros', 'getir', 'vatanbilgisayar', 'idefix', 'itopya', 'incehesap', 'havit'
        ];

        let isMajorStore = majorStores.some(store => host.includes(store));
        if (isMajorStore) {
          urlObj.search = '';
        } else {
          const paramsToKeep = ['id', 'productid', 'product_id', 'p', 'item_id', 'itemid', 'sku'];
          const keys = Array.from(urlObj.searchParams.keys());
          for (const key of keys) {
            if (!paramsToKeep.includes(key.toLowerCase())) {
              urlObj.searchParams.delete(key);
            }
          }
        }
      }

      let result = urlObj.toString();
      if (result.endsWith('?')) {
        result = result.substring(0, result.length - 1);
      }
      return result;
    } catch (_) {
      return urlStr;
    }
  }
};

module.exports = AffiliateManager;
