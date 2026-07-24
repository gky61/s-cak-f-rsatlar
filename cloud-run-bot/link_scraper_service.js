/**
 * Link Scraper Service (Node.js port)
 * Dart karşılığı: lib/services/link_preview_service.dart
 */

const cheerio = require('cheerio');
const scrapers = require('./scrapers');
const { execSync, spawnSync } = require('child_process');

const DEFAULT_USER_AGENT = 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/118.0.0.0 Safari/537.36';

function getHeadersForUrl(url) {
  const lowerUrl = url.toLowerCase();
  let userAgent = DEFAULT_USER_AGENT;

  if (lowerUrl.includes('n11.com') ||
    lowerUrl.includes('teknosa.com') ||
    lowerUrl.includes('amazon.') ||
    lowerUrl.includes('amzn.') ||
    lowerUrl.includes('link.amazon') ||
    lowerUrl.includes('amzlinks.') ||
    lowerUrl.includes('hepsiburada.com') ||
    lowerUrl.includes('mavi.com') ||
    lowerUrl.includes('defacto.com.tr') ||
    lowerUrl.includes('zara.com') ||
    lowerUrl.includes('mango.com') ||
    lowerUrl.includes('beymen.com') ||
    lowerUrl.includes('hb.biz') ||
    lowerUrl.includes('trendyol.com') ||
    lowerUrl.includes('ty.gl') ||
    lowerUrl.includes('pttavm.com') ||
    lowerUrl.includes('incehesap.com')) {
    userAgent = 'WhatsApp/2.23.4.15 A';
  } else if (lowerUrl.includes('vatanbilgisayar.com') || lowerUrl.includes('pazarama.com')) {
    userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36';
  }

  return {
    'User-Agent': userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
    'Cache-Control': 'max-age=0',
    'Connection': 'keep-alive',
    'Upgrade-Insecure-Requests': '1',
    'Referer': 'https://www.google.com/',
  };
}

/** Adjust deep-link yönlendirmesinden gerçek fallback URL'ini çıkartır */
function extractAdjustFallback(url) {
  try {
    const parsedUrl = new URL(url);
    if (parsedUrl.hostname.includes('adj.st') || parsedUrl.hostname.includes('adjust.com')) {
      const params = ['adjust_redirect', 'adj_redirect', 'adjust_fallback', 'adj_fallback', 'fallback'];
      for (const param of params) {
        const value = parsedUrl.searchParams.get(param);
        if (value) {
          console.log(`[RESOLVE-REDIRECT] 🎯 Adjust URL tespit edildi, ${param} çözülüyor: ${value}`);
          return decodeURIComponent(value);
        }
      }
    }
  } catch (err) {
    console.warn(`[RESOLVE-REDIRECT] ⚠️ Adjust fallback çözme hatası: ${err.message}`);
  }
  return url;
}

/** N11 kısa linklerini (sl.n11.com/n/...) Google Translate Proxy üzerinden uzun ürün linkine çözer */
async function resolveN11ShortLink(url) {
  try {
    let targetUrl = url;
    if (targetUrl.toLowerCase().includes('sl.n11.com/n/')) {
      targetUrl = targetUrl.replace(/sl\.n11\.com/i, 'www.n11.com');
    }
    const parsed = new URL(targetUrl);
    const proxyHostname = parsed.hostname.replace(/\./g, '-') + '.translate.goog';
    const proxyUrl = `https://${proxyHostname}${parsed.pathname}${parsed.search || ''}${parsed.search ? '&' : '?'}_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr`;

    console.log(`[RESOLVE-REDIRECT] Resolving N11 short link via Google Translate Proxy: ${proxyUrl}`);
    const res = await fetch(proxyUrl, {
      method: 'GET',
      headers: {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
      },
      redirect: 'manual'
    });

    const location = res.headers.get('location');
    if (location) {
      console.log(`[RESOLVE-REDIRECT] N11 short link location: ${location}`);
      let cleanUrl = location.replace(/www-n11-com\.translate\.goog/gi, 'www.n11.com');
      const parsedClean = new URL(cleanUrl);
      const paramsToRemove = ['_x_tr_sl', '_x_tr_tl', '_x_tr_hl', '_x_tr_pto', '_x_tr_sch'];
      for (const param of paramsToRemove) {
        parsedClean.searchParams.delete(param);
      }
      return parsedClean.toString();
    }
  } catch (err) {
    console.warn(`[RESOLVE-REDIRECT] ⚠️ N11 short link resolution error: ${err.message}`);
  }
  return url;
}

/** URL yönlendirmelerini çözer ve nihai hedef URL'yi döndürür */
async function resolveUrlRedirects(url) {
  let targetUrl = extractAdjustFallback(url);
  if (targetUrl.toLowerCase().includes('sl.n11.com/n/') || targetUrl.toLowerCase().includes('n11.com/n/')) {
    targetUrl = await resolveN11ShortLink(targetUrl);
  }
  const lowerUrl = targetUrl.toLowerCase();

  const isShortOrRedirect = lowerUrl.includes('amzn.eu') ||
    lowerUrl.includes('amzn.to') ||
    lowerUrl.includes('link.amazon') ||
    lowerUrl.includes('amzlinks.in') ||
    lowerUrl.includes('hb.biz') ||
    lowerUrl.includes('publicis.link') ||
    lowerUrl.includes('bit.ly') ||
    lowerUrl.includes('tinyurl.com') ||
    lowerUrl.includes('t.co') ||
    lowerUrl.includes('rebrand.ly') ||
    lowerUrl.includes('rdrtr.com') ||
    lowerUrl.includes('onelink.me') ||
    lowerUrl.includes('sl.n11.com') ||
    lowerUrl.includes('ty.gl');

  if (!isShortOrRedirect) return targetUrl;

  try {
    console.log(`[RESOLVE-REDIRECT] 🔗 Yönlendirme çözülüyor: ${targetUrl}`);
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 8000);

    // Short link/yönlendirme çözümlerinde Chrome Desktop UA kullanılmalı.
    // WhatsApp UA kullanıldığında amzlinks.in, link.amazon, rdrtr vb. servisler 302 yönlendirmesi yapmak yerine 200 OK önizleme sayfası döndürmektedir.
    const headers = {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7'
    };
    console.log(`[RESOLVE-REDIRECT] Giden User-Agent: "${headers['User-Agent']}"`);

    const response = await fetch(targetUrl, {
      method: 'GET',
      headers: headers,
      redirect: 'follow',
      signal: controller.signal
    });

    clearTimeout(timeoutId);
    console.log(`[RESOLVE-REDIRECT] ✅ Çözülen Hedef URL: ${response.url} (Durum: ${response.status} ${response.statusText})`);

    let resolvedUrl = response.url || targetUrl;
    resolvedUrl = extractAdjustFallback(resolvedUrl);

    return resolvedUrl;
  } catch (err) {
    console.warn(`[RESOLVE-REDIRECT] ⚠️ Yönlendirme çözülemedi (${err.message}), orijinal URL kullanılacak: ${targetUrl}`);
    return targetUrl;
  }
}

/**
 * Bot engelleyici ve WAF block sayfalarını kontrol eder.
 */
function isBotBlocked(htmlText) {
  if (!htmlText || htmlText.length < 100) return false;
  const lowerHtml = htmlText.toLowerCase();
  const blockSignatures = [
    '<title>just a moment...</title>', 'cf-challenge', 'checking your browser...',
    'px-captcha', 'captcha-delivery.net',
    'blocked by distil', 'distil_ident_cookie',
    'access denied', "you don't have permission to access",
    'access forbidden', 'ip blocked', 'request blocked', 'unauthorized access',
    'human verification', 'awswafcookie'
  ];
  return blockSignatures.some(sig => lowerHtml.includes(sig));
}

/**
 * Microlink API'si ile HTML çeker.
 * Pttavm gibi hem Node.js fetch hem de curl isteklerini datacenter IP'sinden dolayı 403/WAF ile engellemektedir.
 * Microlink premium proxy altyapısı sayesinde bu WAF engellerini aşabilir.
 */
async function microlinkFetchHtml(targetUrl, originalUrl, fetchStartTime, prerender = false) {
  console.log(`[FETCH-HTML] 🔧 Microlink API ile çekiliyor: ${targetUrl} (Prerender: ${prerender})`);
  try {
    let microUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
    if (prerender) {
      microUrl += '&prerender=true';
    }
    const r = await fetch(microUrl, { signal: AbortSignal.timeout(18000) });
    const duration = Date.now() - fetchStartTime;
    console.log(`[FETCH-HTML] ⚡ Microlink cevabı geldi! Süre: ${duration}ms, Durum Kodu: ${r.status}`);

    if (r.ok) {
      const data = await r.json();
      const htmlText = data.data?.html || '';
      console.log(`[FETCH-HTML] Microlink HTML boyutu: ${htmlText.length} karakter`);
      if (htmlText.length > 1000) {
        if (isBotBlocked(htmlText)) {
          console.warn(`[FETCH-HTML] ❌ Microlink cevabı bot engelleyici/WAF sayfası içeriyor: ${originalUrl}`);
          checkForBotBlockers(htmlText, originalUrl);
          return null;
        }
        checkForBotBlockers(htmlText, originalUrl);
        return htmlText;
      }
    }
    console.error(`[FETCH-HTML] ❌ Microlink Başarısız. Durum Kodu: ${r.status}`);
    return null;
  } catch (e) {
    console.error(`[FETCH-HTML] ❌ Microlink Hatası: ${e.message}`);
    return null;
  }
}


/**
 * curl ile HTML çeker. Node.js fetch() TLS fingerprint'i (JA3/JA4) Cloudflare
 * tarafından bot olarak algılanıyor. curl farklı bir TLS stack (libcurl/OpenSSL)
 * kullandığı için Cloudflare WAF'ı aşabiliyor.
 * Bu fonksiyon özellikle Teknosa gibi agresif Cloudflare koruması olan siteler için.
 */
function curlFetchHtml(targetUrl, originalUrl, fetchStartTime) {
  if (targetUrl.includes('hepsiburada.com') || targetUrl.includes('trendyol.com') || targetUrl.includes('ty.gl') || targetUrl.includes('n11.com') || targetUrl.includes('vatanbilgisayar.com') || targetUrl.includes('pazarama.com') || targetUrl.includes('idefix.com') || targetUrl.includes('mediamarkt.com.tr') || targetUrl.includes('teknosa.com') || targetUrl.includes('incehesap.com') || targetUrl.includes('pttavm.com')) {
    try {
      console.log(`[FETCH-HTML] 🔧 curl (Clean headers) ile çekiliyor: ${targetUrl}`);
      let userAgent = 'WhatsApp/2.23.4.15 A';
      if (targetUrl.includes('incehesap.com')) {
        userAgent = 'Mozilla/5.0 (iPhone; CPU iPhone OS 16_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.6 Mobile/15E148 Safari/604.1';
      }
      const hbArgs = [
        '-sL',
        '-H', `User-Agent: ${userAgent}`,
        '-H', 'Accept-Language: tr-TR,tr;q=0.9',
        '--compressed',
        '-w', '\n---CURL_HTTP_STATUS:%{http_code}---',
        '--max-time', '15',
        targetUrl
      ];
      const hbRes = spawnSync('curl', hbArgs, {
        encoding: 'utf-8',
        timeout: 18000,
        maxBuffer: 10 * 1024 * 1024
      });
      if (!hbRes.error) {
        const output = hbRes.stdout || '';
        const statusMatch = output.match(/---CURL_HTTP_STATUS:(\d+)---/);
        const httpStatus = statusMatch ? parseInt(statusMatch[1]) : 0;
        const htmlText = output.replace(/\n---CURL_HTTP_STATUS:\d+---$/, '');
        const duration = Date.now() - fetchStartTime;
        console.log(`[FETCH-HTML] ⚡ curl (Hepsiburada) cevabı geldi! Süre: ${duration}ms, Durum Kodu: ${httpStatus}, Boyut: ${htmlText.length}`);
        if (httpStatus === 200 && htmlText.length > 1000) {
          return htmlText;
        }
      }
    } catch (e) {
      console.error(`[FETCH-HTML] ❌ Hepsiburada curl hatası: ${e.message}`);
    }
  }

  const headers = getHeadersForUrl(originalUrl);
  try {
    console.log(`[FETCH-HTML] 🔧 curl ile çekiliyor: ${targetUrl}`);
    const curlArgs = [
      '-sL',
      '-H', `User-Agent: ${headers['User-Agent']}`,
      '-H', `Accept: ${headers['Accept']}`,
      '-H', `Accept-Language: ${headers['Accept-Language']}`,
      '-H', 'Accept-Encoding: gzip, deflate, br',
      '-H', `Referer: ${headers['Referer']}`,
      '-H', 'Connection: keep-alive',
      '-H', 'Upgrade-Insecure-Requests: 1',
      '-H', 'Sec-Fetch-Dest: document',
      '-H', 'Sec-Fetch-Mode: navigate',
      '-H', 'Sec-Fetch-Site: cross-site',
      '--compressed',
      '-w', '\n---CURL_HTTP_STATUS:%{http_code}---',
      '--max-time', '12'
    ];

    // Trendyol ülke kısıtlamalı butik indirimlerini bypass etmek için TR çerezlerini ekle
    if (targetUrl.includes('trendyol.com')) {
      curlArgs.push('-H', 'Cookie: storefrontId=1; countryCode=TR; language=tr');
    }

    curlArgs.push(targetUrl);

    const result = spawnSync('curl', curlArgs, {
      encoding: 'utf-8',
      timeout: 15000,
      maxBuffer: 10 * 1024 * 1024
    });

    if (result.error) {
      console.error(`[FETCH-HTML] ❌ curl spawnSync hatası: ${result.error.message}`);
      return null;
    }

    const output = result.stdout || '';
    const statusMatch = output.match(/---CURL_HTTP_STATUS:(\d+)---/);
    const httpStatus = statusMatch ? parseInt(statusMatch[1]) : 0;
    const htmlText = output.replace(/\n---CURL_HTTP_STATUS:\d+---$/, '');
    const duration = Date.now() - fetchStartTime;

    console.log(`[FETCH-HTML] ⚡ curl cevabı geldi! Süre: ${duration}ms, Durum Kodu: ${httpStatus}`);
    console.log(`[FETCH-HTML] curl HTML boyutu: ${htmlText.length} karakter`);

    if (httpStatus === 200 && htmlText.length > 1000) {
      if (isBotBlocked(htmlText)) {
        console.warn(`[FETCH-HTML] ❌ curl cevabı bot engelleyici/WAF sayfası içeriyor: ${originalUrl}`);
        checkForBotBlockers(htmlText, originalUrl);
        return null;
      }
      checkForBotBlockers(htmlText, originalUrl);
      return htmlText;
    } else {
      console.error(`[FETCH-HTML] ❌ curl Hata Kodu (${httpStatus}): ${originalUrl}`);
      console.error(`[FETCH-HTML] curl Hata Cevap Gövdesi (ilk 500): ${htmlText.substring(0, 500).replace(/\s+/g, ' ')}`);
      if (result.stderr) {
        console.error(`[FETCH-HTML] curl stderr: ${result.stderr}`);
      }
      return null;
    }
  } catch (err) {
    console.error(`[FETCH-HTML] ❌ curl Hatası: ${err.message}`);
    return null;
  }
}

/**
 * Minimal headers ile curl üzerinden çekim yapar. Google Translate Proxy
 * gibi harici proxy servisleri üzerinden istek atarken boş veya minimal header seti
 * daha iyi çalışır. Fazla header (Sec-Fetch, WhatsApp UA vs.) 403'e sebep olabilir.
 */
function curlFetchHtmlMinimal(targetUrl, originalUrl, fetchStartTime) {
  try {
    console.log(`[FETCH-HTML] 🔧 curl (minimal headers) ile çekiliyor: ${targetUrl}`);
    const curlArgs = [
      '-sL',
      '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36',
      '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      '-H', 'Accept-Language: tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      '--compressed',
      '-w', '\n---CURL_HTTP_STATUS:%{http_code}---',
      '--max-time', '15',
      targetUrl
    ];

    const result = spawnSync('curl', curlArgs, {
      encoding: 'utf-8',
      timeout: 18000,
      maxBuffer: 10 * 1024 * 1024
    });

    if (result.error) {
      console.error(`[FETCH-HTML] ❌ curl (minimal) spawnSync hatası: ${result.error.message}`);
      return null;
    }

    const output = result.stdout || '';
    const statusMatch = output.match(/---CURL_HTTP_STATUS:(\d+)---/);
    const httpStatus = statusMatch ? parseInt(statusMatch[1]) : 0;
    const htmlText = output.replace(/\n---CURL_HTTP_STATUS:\d+---$/, '');
    const duration = Date.now() - fetchStartTime;

    console.log(`[FETCH-HTML] ⚡ curl (minimal) cevabı geldi! Süre: ${duration}ms, Durum Kodu: ${httpStatus}`);
    console.log(`[FETCH-HTML] curl (minimal) HTML boyutu: ${htmlText.length} karakter`);

    if (httpStatus === 200 && htmlText.length > 1000) {
      if (isBotBlocked(htmlText)) {
        console.warn(`[FETCH-HTML] ❌ curl (minimal) cevabı bot engelleyici/WAF sayfası içeriyor: ${originalUrl}`);
        checkForBotBlockers(htmlText, originalUrl);
        return null;
      }
      checkForBotBlockers(htmlText, originalUrl);
      return htmlText;
    } else if (httpStatus === 403 && htmlText.length > 50000 && !isBotBlocked(htmlText)) {
      // Google Translate Proxy bazen 403 döndürür ama gerçek sayfa içeriğini proxy'ler (80K+ karakter).
      // Bu durumda HTML parse edilebilir. Gerçek engel sayfaları genellikle < 5000 karakter olur.
      console.log(`[FETCH-HTML] ⚠️ curl (minimal) 403 ama büyük HTML (${htmlText.length} karakter) — gerçek sayfa olarak kabul ediliyor.`);
      checkForBotBlockers(htmlText, originalUrl);
      return htmlText;
    } else {
      console.error(`[FETCH-HTML] ❌ curl (minimal) Hata Kodu (${httpStatus}): ${originalUrl}`);
      if (htmlText.length > 0) {
        console.error(`[FETCH-HTML] curl (minimal) Hata Cevap Gövdesi (ilk 500): ${htmlText.substring(0, 500).replace(/\s+/g, ' ')}`);
      }
      if (result.stderr) {
        console.error(`[FETCH-HTML] curl (minimal) stderr: ${result.stderr}`);
      }
      return null;
    }
  } catch (err) {
    console.error(`[FETCH-HTML] ❌ curl (minimal) Hatası: ${err.message}`);
    return null;
  }
}

/**
 * Getir için özel curl çekim fonksiyonu.
 * Getir'in CloudFront WAF'ı:
 * - WhatsApp UA → 403 (doğrudan engel)
 * - Chrome UA (cookie'siz) → 405 captcha (depo-genel ürünler hariç)
 * - Chrome UA + lokasyon cookie'leri → 200 OK (tüm ürünler, __NEXT_DATA__ dahil)
 * 
 * Lokasyon cookie'leri olmadan depo-özel ürünler (sandviç, dondurma vb.) 404 döner
 * çünkü sunucu hangi depodan ürün sunacağını bilemez.
 */
function curlFetchGetir(targetUrl, originalUrl, fetchStartTime) {
  try {
    console.log(`[FETCH-HTML] 🔧 curl (Getir Chrome UA + cookie) ile çekiliyor: ${targetUrl}`);
    const curlArgs = [
      '-sL',
      '-H', 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      '-H', 'Accept: text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
      '-H', 'Accept-Language: tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7',
      '-H', 'Cookie: locale=tr; language=tr; countryCode=TR; appType=GETIR',
      '--compressed',
      '-w', '\n---CURL_HTTP_STATUS:%{http_code}---',
      '--max-time', '15',
      targetUrl
    ];

    const result = spawnSync('curl', curlArgs, {
      encoding: 'utf-8',
      timeout: 18000,
      maxBuffer: 10 * 1024 * 1024
    });

    if (!result.error) {
      const output = result.stdout || '';
      const statusMatch = output.match(/---CURL_HTTP_STATUS:(\d+)---/);
      const httpStatus = statusMatch ? parseInt(statusMatch[1]) : 0;
      const htmlText = output.replace(/\n---CURL_HTTP_STATUS:\d+---$/, '');
      const duration = Date.now() - fetchStartTime;

      console.log(`[FETCH-HTML] ⚡ curl (Getir) cevabı geldi! Süre: ${duration}ms, Durum Kodu: ${httpStatus}`);
      console.log(`[FETCH-HTML] curl (Getir) HTML boyutu: ${htmlText.length} karakter`);
      console.log(`[FETCH-HTML] curl (Getir) __NEXT_DATA__ var mı: ${htmlText.includes('__NEXT_DATA__')}`);

      if (httpStatus === 200 && htmlText.length > 1000) {
        if (isBotBlocked(htmlText)) {
          console.warn(`[FETCH-HTML] ❌ curl (Getir) cevabı bot engelleyici/WAF sayfası içeriyor. Yandex Translate fallback deneniyor...`);
        } else {
          checkForBotBlockers(htmlText, originalUrl);
          return htmlText;
        }
      } else {
        console.error(`[FETCH-HTML] ❌ curl (Getir) Hata Kodu (${httpStatus}). Yandex Translate fallback deneniyor...`);
      }
    } else {
      console.error(`[FETCH-HTML] ❌ curl (Getir) spawnSync hatası: ${result.error.message}. Yandex Translate fallback deneniyor...`);
    }

    // ── Yandex Translate Fallback (Canlı Fiyat Çekebilmek İçin) ──
    // Yandex Translate, Getir WAF (CloudFront/AWS WAF) engeline takılmadan sayfaları çekebiliyor.
    // Ekmek gibi genel/bölgesel kısıtlaması olmayan ürünlerde güncel, canlı fiyat ve görselleri çekebiliriz.
    return curlFetchGetirYandexTranslate(targetUrl, originalUrl, fetchStartTime);
  } catch (err) {
    console.error(`[FETCH-HTML] ❌ curl (Getir) Hatası: ${err.message}`);
    return null;
  }
}

/**
 * Yandex Translate Proxy'si kullanarak Getir ürününü çeker.
 * Bu yöntem, genel Getir ürünlerinde CloudFront WAF engelini aşarak canlı fiyat verisini çekmemizi sağlar.
 */
function curlFetchGetirYandexTranslate(targetUrl, originalUrl, fetchStartTime) {
  try {
    const yandexUrl = `https://translate.yandex.ru/translate?url=${encodeURIComponent(targetUrl)}&lang=tr-tr`;
    console.log(`[FETCH-HTML] 🔧 Yandex Translate fallback çekiliyor: ${yandexUrl}`);

    const result = spawnSync('curl', [
      '-sL',
      '-H', 'User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      '--compressed',
      '-w', '\n---CURL_HTTP_STATUS:%{http_code}---',
      '--max-time', '20',
      yandexUrl
    ], {
      encoding: 'utf-8',
      timeout: 25000,
      maxBuffer: 10 * 1024 * 1024
    });

    if (result.error) {
      console.error(`[FETCH-HTML] ❌ Yandex Translate spawnSync hatası: ${result.error.message}. Wayback Machine deneniyor...`);
      return curlFetchGetirWayback(targetUrl, originalUrl, fetchStartTime);
    }

    const output = result.stdout || '';
    const statusMatch = output.match(/---CURL_HTTP_STATUS:(\d+)---/);
    const httpStatus = statusMatch ? parseInt(statusMatch[1]) : 0;
    const htmlText = output.replace(/\n---CURL_HTTP_STATUS:\d+---$/, '');
    const duration = Date.now() - fetchStartTime;

    console.log(`[FETCH-HTML] ⚡ Yandex Translate cevabı geldi! Süre: ${duration}ms, Durum Kodu: ${httpStatus}`);
    console.log(`[FETCH-HTML] Yandex HTML boyutu: ${htmlText.length} karakter`);
    console.log(`[FETCH-HTML] Yandex __NEXT_DATA__ var mı: ${htmlText.includes('__NEXT_DATA__')}`);

    if (httpStatus === 200 && htmlText.length > 1000 && htmlText.includes('__NEXT_DATA__')) {
      console.log(`[FETCH-HTML] ✅ Yandex Translate üzerinden canlı Getir verisi başarıyla çekildi!`);
      return htmlText;
    } else {
      console.warn(`[FETCH-HTML] ❌ Yandex Translate başarısız (Status: ${httpStatus}, Size: ${htmlText.length}). Wayback Machine deneniyor...`);
      return curlFetchGetirWayback(targetUrl, originalUrl, fetchStartTime);
    }
  } catch (err) {
    console.error(`[FETCH-HTML] ❌ Yandex Translate Hatası: ${err.message}. Wayback Machine deneniyor...`);
    return curlFetchGetirWayback(targetUrl, originalUrl, fetchStartTime);
  }
}

/**
 * Wayback Machine üzerinden Getir ürün sayfasını çeker.
 * Getir CloudFront WAF, GCP datacenter IP'lerini engelliyor.
 * Wayback Machine arşivi __NEXT_DATA__ JSON'u içerir ve:
 * - Ürün adı, açıklama, görseller güncel kalır (CDN URL'leri sabittir)
 * - Fiyat eski olabilir (arşiv zamanına ait)
 * Wayback URL prefix'leri HTML'den temizlenerek orijinal CDN URL'leri korunur.
 */
function curlFetchGetirWayback(targetUrl, originalUrl, fetchStartTime) {
  try {
    const waybackUrl = `https://web.archive.org/web/2024/${targetUrl}`;
    console.log(`[FETCH-HTML] 🔧 Wayback Machine fallback çekiliyor: ${waybackUrl}`);

    const result = spawnSync('curl', [
      '-sL',
      '-H', 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
      '--compressed',
      '-w', '\n---CURL_HTTP_STATUS:%{http_code}---',
      '--max-time', '20',
      waybackUrl
    ], {
      encoding: 'utf-8',
      timeout: 25000,
      maxBuffer: 10 * 1024 * 1024
    });

    if (result.error) {
      console.error(`[FETCH-HTML] ❌ Wayback Machine spawnSync hatası: ${result.error.message}`);
      return null;
    }

    const output = result.stdout || '';
    const statusMatch = output.match(/---CURL_HTTP_STATUS:(\d+)---/);
    const httpStatus = statusMatch ? parseInt(statusMatch[1]) : 0;
    let htmlText = output.replace(/\n---CURL_HTTP_STATUS:\d+---$/, '');
    const duration = Date.now() - fetchStartTime;

    console.log(`[FETCH-HTML] ⚡ Wayback Machine cevabı geldi! Süre: ${duration}ms, Durum Kodu: ${httpStatus}`);
    console.log(`[FETCH-HTML] Wayback HTML boyutu: ${htmlText.length} karakter`);
    console.log(`[FETCH-HTML] Wayback __NEXT_DATA__ var mı: ${htmlText.includes('__NEXT_DATA__')}`);

    if (httpStatus === 200 && htmlText.length > 1000 && htmlText.includes('__NEXT_DATA__')) {
      // Wayback Machine, URL'lere /web/YYYYMMDD/ prefix'i ekler.
      // CDN URL'lerini orijinal hallerine geri çevir.
      htmlText = htmlText.replace(/https?:\/\/web\.archive\.org\/web\/\d+\/(https?:\/\/)/gi, '$1');
      // Wayback toolbar scriptlerini kaldır
      htmlText = htmlText.replace(/<!-- BEGIN WAYBACK TOOLBAR INSERT -->[\s\S]*?<!-- END WAYBACK TOOLBAR INSERT -->/gi, '');

      console.log(`[FETCH-HTML] ✅ Wayback Machine'den Getir ürün verisi başarıyla çekildi!`);
      return htmlText;
    } else {
      console.error(`[FETCH-HTML] ❌ Wayback Machine'de Getir verisi bulunamadı (Status: ${httpStatus}, Size: ${htmlText.length})`);
      return null;
    }
  } catch (err) {
    console.error(`[FETCH-HTML] ❌ Wayback Machine Hatası: ${err.message}`);
    return null;
  }
}

/** URL'den HTML çekerek Cheerio DOM nesnesi döndürür */
async function fetchHtml(url) {
  const fetchStartTime = Date.now();
  let targetUrl = url;
  let isProxy = false;
  let isMediamarkt = false;
  let isTeknosa = false;
  let isMavi = false;
  let isPttavm = false;
  let isHepsiburada = false;
  let isTrendyol = false;
  let isAmazon = false;
  let isGetir = false;
  let isIncehesap = false;

  try {
    const parsed = new URL(url);

    if (parsed.hostname.includes('hepsiburada.com')) {
      // Hepsiburada Akamai koruması altında — Node.js fetch() TLS fingerprint'i engelleniyor.
      // curl farklı TLS stack (libcurl/OpenSSL) kullandığı için ve WhatsApp User-Agent taklidiyle doğrudan çekebiliyoruz.
      const keepParams = ['magaza'];
      const cleaned = new URL(parsed.pathname, parsed.origin);
      for (const key of keepParams) {
        if (parsed.searchParams.has(key)) {
          cleaned.searchParams.set(key, parsed.searchParams.get(key));
        }
      }
      targetUrl = cleaned.toString();
      isHepsiburada = true;
      console.log(`[FETCH-HTML] 🔄 Hepsiburada linki tespit edildi. Tracking params temizlendi. curl ile doğrudan çekilecek: ${targetUrl}`);

    } else if (parsed.hostname.includes('trendyol.com')) {
      // Tracking/affiliate parametrelerini temizle — bu parametreler Trendyol'un
      // farklı (hafif/mobil) sayfa sunmasına neden oluyor ve JSON-LD kalkmış oluyor.
      // Sadece ürün/kampanya ile ilgili parametreleri koru.
      const keepParams = ['boutiqueId', 'merchantId', 'storefrontId'];
      const cleaned = new URL(parsed.pathname, parsed.origin);
      for (const key of keepParams) {
        if (parsed.searchParams.has(key)) {
          cleaned.searchParams.set(key, parsed.searchParams.get(key));
        }
      }
      targetUrl = cleaned.toString();
      isTrendyol = true;
      console.log(`[FETCH-HTML] 🔄 Trendyol linki tespit edildi. Tracking params temizlendi. curl ile doğrudan çekilecek: ${targetUrl}`);

    } else if (parsed.hostname.includes('n11.com')) {
      // N11 de Cloudflare bot koruması altında — aynı Google Translate proxy yaklaşımı.
      // Sadece mağaza bilgisi olan 'magaza' parametresini koru, geri kalanları temizle.
      const keepParams = ['magaza'];
      const cleaned = new URL(parsed.pathname, parsed.origin);
      for (const key of keepParams) {
        if (parsed.searchParams.has(key)) {
          cleaned.searchParams.set(key, parsed.searchParams.get(key));
        }
      }
      const proxyHostname = cleaned.hostname.replace(/\./g, '-') + '.translate.goog';
      cleaned.hostname = proxyHostname;
      cleaned.searchParams.set('_x_tr_sl', 'auto');
      cleaned.searchParams.set('_x_tr_tl', 'tr');
      cleaned.searchParams.set('_x_tr_hl', 'tr');
      targetUrl = cleaned.toString();
      isProxy = true;
      console.log(`[FETCH-HTML] 🔄 N11 linki tespit edildi. Tracking params temizlendi. Google Translate Proxy kullanılıyor: ${targetUrl}`);

    } else if (parsed.hostname.includes('mediamarkt.com.tr')) {
      // MediaMarkt Cloudflare, Googlebot UA'ya izin veriyor.
      // Tracking parametrelerini temizle, URL'yi sadeleştir.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      targetUrl = cleaned.toString();
      isMediamarkt = true;
      console.log(`[FETCH-HTML] 🔄 MediaMarkt linki tespit edildi. Tracking params temizlendi. Googlebot UA kullanılacak: ${targetUrl}`);
    } else if (parsed.hostname.includes('itopya.com')) {
      // Itopya da Cloudflare bot koruması altında — aynı Google Translate proxy yaklaşımı.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      const proxyHostname = cleaned.hostname.replace(/\./g, '-') + '.translate.goog';
      cleaned.hostname = proxyHostname;
      cleaned.searchParams.set('_x_tr_sl', 'auto');
      cleaned.searchParams.set('_x_tr_tl', 'tr');
      cleaned.searchParams.set('_x_tr_hl', 'tr');
      targetUrl = cleaned.toString();
      isProxy = true;
      console.log(`[FETCH-HTML] 🔄 Itopya linki tespit edildi. Tracking params temizlendi. Google Translate Proxy kullanılıyor: ${targetUrl}`);
    } else if (parsed.hostname.includes('vatanbilgisayar.com')) {
      // Vatan Bilgisayar da Cloudflare bot koruması altında — aynı Google Translate proxy yaklaşımı.
      // Tracking parametrelerini temizle, URL'yi sadeleştir.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      const proxyHostname = cleaned.hostname.replace(/\./g, '-') + '.translate.goog';
      cleaned.hostname = proxyHostname;
      cleaned.searchParams.set('_x_tr_sl', 'auto');
      cleaned.searchParams.set('_x_tr_tl', 'tr');
      cleaned.searchParams.set('_x_tr_hl', 'tr');
      targetUrl = cleaned.toString();
      isProxy = true;
      console.log(`[FETCH-HTML] 🔄 Vatan Bilgisayar linki tespit edildi. Tracking params temizlendi. Google Translate Proxy kullanılıyor: ${targetUrl}`);
    } else if (parsed.hostname.includes('teknosa.com')) {
      // Teknosa Cloudflare, Node.js fetch TLS fingerprint'ini engelliyor.
      // curl farklı TLS stack kullandığı için Cloudflare'i geçebiliyor.
      // Tracking parametrelerini temizle, URL'yi sadeleştir.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      if (parsed.searchParams.has('shopId')) {
        cleaned.searchParams.set('shopId', parsed.searchParams.get('shopId'));
      }
      targetUrl = cleaned.toString();
      isTeknosa = true;
      console.log(`[FETCH-HTML] 🔄 Teknosa linki tespit edildi. Tracking params temizlendi. curl ile çekilecek: ${targetUrl}`);
    } else if (parsed.hostname.includes('incehesap.com')) {
      const cleaned = new URL(parsed.pathname, parsed.origin);
      targetUrl = cleaned.toString();
      isIncehesap = true;
      console.log(`[FETCH-HTML] 🔄 İncehesap linki tespit edildi. Tracking params temizlendi. iPhone UA ile curl kullanılacak: ${targetUrl}`);
    } else if (parsed.hostname.includes('mavi.com')) {
      // Mavi Cloudflare, Node.js fetch TLS fingerprint'ini engelliyor.
      // curl ile doğrudan çekim 200 OK alıyor.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      targetUrl = cleaned.toString();
      isMavi = true;
      console.log(`[FETCH-HTML] 🔄 Mavi linki tespit edildi. Tracking params temizlendi. curl ile çekilecek: ${targetUrl}`);
    } else if (parsed.hostname.includes('pttavm.com')) {
      // Pttavm Cloudflare, Node.js fetch TLS fingerprint'ini engelliyor.
      // curl ile doğrudan çekim 200 OK alıyor.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      targetUrl = cleaned.toString();
      isPttavm = true;
      console.log(`[FETCH-HTML] 🔄 Pttavm linki tespit edildi. Tracking params temizlendi. curl ile çekilecek: ${targetUrl}`);
    } else if (parsed.hostname.includes('amazon.') || parsed.hostname.includes('link.amazon') || parsed.hostname.includes('amzlinks.') || parsed.hostname.includes('amzn.')) {
      // Amazon linklerinde satıcı (smid) ve varyant (th, psc, m, isIsap) parametrelerini koru.
      // Aksi takdirde varsayılan farklı bir satıcının indirimsiz yüksek fiyatı çekilmektedir.
      const keepParams = ['smid', 'th', 'psc', 'm', 'isIsap', 'tag'];
      const cleaned = new URL(parsed.pathname, parsed.origin);
      for (const key of keepParams) {
        if (parsed.searchParams.has(key)) {
          cleaned.searchParams.set(key, parsed.searchParams.get(key));
        }
      }
      targetUrl = cleaned.toString();
      isAmazon = true;
      console.log(`[FETCH-HTML] 🔄 Amazon linki tespit edildi. Satıcı/varyant parametreleri korundu: ${targetUrl}`);
    } else if (parsed.hostname.includes('havitstore.com.tr')) {
      // Havit Store: Herhangi bir bot engeli bulunmuyor, doğrudan fetch ile çekilir.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      targetUrl = cleaned.toString();
      console.log(`[FETCH-HTML] 🔄 Havit Store linki tespit edildi. Standart Fetch kullanılacak: ${targetUrl}`);
    } else if (parsed.hostname.includes('migros.com.tr')) {
      // Migros: Herhangi bir bot engeli bulunmuyor, doğrudan fetch ile çekilir.
      const cleaned = new URL(parsed.pathname, parsed.origin);
      targetUrl = cleaned.toString();
      console.log(`[FETCH-HTML] 🔄 Migros linki tespit edildi. Standart Fetch kullanılacak: ${targetUrl}`);
    } else if (parsed.hostname.includes('getir.com')) {
      // Getir CloudFront, WhatsApp UA'yı 403 ile engelliyor ancak
      // Chrome UA + lokasyon cookie'leri ile 200 OK dönüyor.
      // Lokasyon cookie'leri olmadan depo-özel ürünler (sandviç, dondurma vb.) 404 döner.
      // curl ile Chrome UA + cookie kombinasyonu kullanarak bypass ediyoruz.
      let pathname = parsed.pathname;
      if (!pathname.endsWith('/')) {
        pathname += '/';
      }
      const cleaned = new URL(pathname, parsed.origin);
      targetUrl = cleaned.toString();
      isGetir = true;
      console.log(`[FETCH-HTML] 🔄 Getir linki tespit edildi. curl (Chrome UA + cookie) ile çekilecek: ${targetUrl}`);
    }
  } catch (e) {
    console.error(`[FETCH-HTML] URL parse hatası: ${e.message}`);
  }

  console.log(`[FETCH-HTML] 📥 İstek başlatılıyor: ${targetUrl}`);

  // ── Hepsiburada, Trendyol, Teknosa, İncehesap, Mavi, PttAVM & Amazon: curl ile çek (Node.js fetch TLS fingerprint'i veya ülke yönlendirmesine takıldığı için) ──
  if (isHepsiburada || isTrendyol || isTeknosa || isIncehesap || isMavi || isPttavm || isAmazon) {
    const html = curlFetchHtml(targetUrl, url, fetchStartTime);
    if (html && html.length > 1000) {
      return html;
    }
    if (isAmazon) {
      console.warn(`[FETCH-HTML] ⚠️ Amazon curl çekimi başarısız/boş, Microlink fallback deneniyor...`);
      return microlinkFetchHtml(targetUrl, url, fetchStartTime, false);
    }
    return html;
  }

  // ── Getir: curl minimal (Chrome UA + lokasyon cookie'leri) ile çek ──
  // Getir CloudFront, WhatsApp UA'yı engeller. Chrome UA + cookie ile tüm ürünler çekilir.
  if (isGetir) {
    return curlFetchGetir(targetUrl, url, fetchStartTime);
  }

  // ── Pttavm: Microlink API ile çek (Cloud Run IP engeline takıldığı için) ──
  if (isPttavm) {
    return microlinkFetchHtml(targetUrl, url, fetchStartTime, false);
  }

  try {
    const controller = new AbortController();
    const timeoutId = setTimeout(() => controller.abort(), 12000);

    let headers = getHeadersForUrl(targetUrl);
    // MediaMarkt: Cloudflare Googlebot UA'ya izin veriyor
    if (isMediamarkt) {
      headers['User-Agent'] = 'Googlebot/2.1 (+http://www.google.com/bot.html)';
    }
    // Google Translate Proxy istekleri için sadece minimal headers gönderilmeli (Akamai/Cloudflare 403 engeli almamak için)
    if (isProxy) {
      headers = {
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/122.0.0.0 Safari/537.36'
      };
    }
    console.log(`[FETCH-HTML] Giden İstek Başlıkları:`, JSON.stringify(headers));

    let response = await fetch(targetUrl, {
      headers: headers,
      signal: controller.signal
    });

    // Cloudflare / Akamai 403/401 Bot Engeli Durumunda Alternatif User-Agent ile Yeniden Dene
    if (!isProxy && (response.status === 403 || response.status === 401) && headers['User-Agent'].includes('WhatsApp')) {
      console.warn(`[FETCH-HTML] ⚠️ ${response.status} Bot engeli algılandı (WhatsApp UA). Standart Tarayıcı User-Agent ile yeniden deneniyor...`);
      headers['User-Agent'] = DEFAULT_USER_AGENT;
      response = await fetch(targetUrl, {
        headers: headers,
        signal: controller.signal
      });
    }

    clearTimeout(timeoutId);

    const duration = Date.now() - fetchStartTime;
    console.log(`[FETCH-HTML] ⚡ Cevap geldi! Süre: ${duration}ms, Durum Kodu: ${response.status} ${response.statusText}`);

    // Response Header'larını logla (Hata çözümü için kritik)
    const respHeaders = {};
    response.headers.forEach((val, key) => {
      respHeaders[key] = val;
    });
    console.log(`[FETCH-HTML] Gelen Cevap Başlıkları:`, JSON.stringify(respHeaders));

    if (response.ok) {
      const htmlText = await response.text();
      console.log(`[FETCH-HTML] Başarılı! Okunan HTML boyutu: ${htmlText.length} karakter.`);

      // Sayfa içeriğinde engelleyici imzaları ara
      checkForBotBlockers(htmlText, url);

      return htmlText;
    } else {
      console.error(`[FETCH-HTML] ❌ Sunucu Hata Kodu Döndürdü (${response.status}): ${url}`);
      return null;
    }
  } catch (err) {
    console.error(`[FETCH-HTML] ❌ HTML Çekme Hatası: ${err.message}`);
    return null;
  }
}

/** Sayfa içeriğinde bot engelleyici/Cloudflare imzası kontrolü */
function checkForBotBlockers(htmlText, url) {
  const lowerHtml = htmlText.toLowerCase();

  const blockSignatures = {
    'Cloudflare Challenge': ['<title>just a moment...</title>', 'cf-challenge', 'checking your browser...'],
    'PerimeterX/Human Challenge': ['px-captcha', 'captcha-delivery.net'],
    'Distil Networks Blocker': ['blocked by distil', 'distil_ident_cookie'],
    'Akamai Edge Shield': ['access denied', 'you don\'t have permission to access'],
    'Generic Firewall Block': ['access forbidden', 'ip blocked', 'request blocked', 'unauthorized access']
  };

  for (const [blockType, keywords] of Object.entries(blockSignatures)) {
    for (const keyword of keywords) {
      if (lowerHtml.includes(keyword)) {
        console.warn(`[BOT ENGELİ TESPİTİ] ⚠️⚠️⚠️ ENGEL ALGINLANDI! ⚠️⚠️⚠️`);
        console.warn(`   Tip        : ${blockType}`);
        console.warn(`   Anahtar Kelime: "${keyword}"`);
        console.warn(`   Link       : ${url}`);
        console.warn(`   Not        : Mağaza IP adresimizi engelledi veya Cloudflare/Akamai doğrulaması gösterdi. Bu yüzden DOM seçicileri çalışmayacaktır.`);

        // HTML içeriğinden bir kesit gösterelim (İlk 300 karakter)
        const preview = htmlText.substring(0, 300).replace(/\s+/g, ' ').trim();
        console.warn(`   HTML Kesit : "${preview}..."`);
        return; // İlk eşleşmede dur
      }
    }
  }
}

/** Verilen URL için ürün bilgilerini çeker */
async function scrapeProductFromUrl(url) {
  const startTime = Date.now();
  console.log(`\n============================================================`);
  console.log(`[SCRAPE-SERVICE] 🚀 Ürün Scrape Başlatıldı: ${url}`);
  console.log(`============================================================`);

  try {
    // 1. Kısa veya yönlendirmeli linkleri çöz
    const targetUrl = await resolveUrlRedirects(url);

    // 2. Scraper bul
    let matchedScraper = null;
    for (const scraper of scrapers) {
      if (scraper.canHandle(targetUrl)) {
        matchedScraper = scraper;
        break;
      }
    }

    if (!matchedScraper) {
      console.log(`[SCRAPE-SERVICE] ℹ️ Eşleşen özel scraper bulunamadı, genel Open Graph parser kullanılacak: ${targetUrl}`);
    } else {
      console.log(`[SCRAPE-SERVICE] ⚡ Özel Scraper eşleşti: "${matchedScraper.constructor.name}" -> ${targetUrl}`);
    }

    // 3. HTML içeriğini çek
    const html = await fetchHtml(targetUrl);
    if (!html) {
      console.error(`[SCRAPE-SERVICE] ❌ HTML içeriği boş veya çekilemedi! Boş veri döndürülüyor.`);
      return { url: targetUrl, title: null, price: null, imageUrl: null, breadcrumbs: [] };
    }

    const $ = cheerio.load(html);

    if (matchedScraper) {
      console.log(`[SCRAPE-SERVICE] Özel Scraper akışı başlıyor...`);

      // 1. Başlık Çekimi
      console.log(`[SCRAPE-SERVICE] [TITLE] Başlık çekiliyor...`);
      const title = matchedScraper.scrapeTitle($);
      console.log(`[SCRAPE-SERVICE] [TITLE] Sonuç: "${title || 'BULUNAMADI'}"`);

      // 2. Fiyat Çekimi
      console.log(`[SCRAPE-SERVICE] [PRICE] Fiyat çekiliyor...`);
      const price = await matchedScraper.scrapePrice($);
      console.log(`[SCRAPE-SERVICE] [PRICE] Sonuç: "${price != null ? price + ' TL' : 'BULUNAMADI'}"`);

      // 2b. İndirimsiz (Eski) Fiyat Çekimi
      console.log(`[SCRAPE-SERVICE] [ORIGINAL-PRICE] İndirimsiz fiyat çekiliyor...`);
      const originalPrice = matchedScraper.scrapeOriginalPrice ? matchedScraper.scrapeOriginalPrice($, price) : null;
      console.log(`[SCRAPE-SERVICE] [ORIGINAL-PRICE] Sonuç: "${originalPrice != null ? originalPrice + ' TL' : 'BULUNAMADI'}"`);

      // 3. Görsel Çekimi
      console.log(`[SCRAPE-SERVICE] [IMAGE] Görsel çekiliyor...`);
      const rawImage = matchedScraper.scrapeImage($, targetUrl);
      console.log(`[SCRAPE-SERVICE] [IMAGE] Ham Görsel Alanı: "${rawImage || 'BULUNAMADI'}"`);
      const imageUrl = matchedScraper.resolveImageUrl(rawImage, targetUrl);
      console.log(`[SCRAPE-SERVICE] [IMAGE] Mutlak Görsel URL'i: "${imageUrl || 'BULUNAMADI'}"`);

      // 4. Kırıntı Çekimi (Breadcrumbs)
      console.log(`[SCRAPE-SERVICE] [BREADCRUMBS] Kırıntı listesi çekiliyor...`);
      const breadcrumbs = matchedScraper.scrapeBreadcrumbs($) || [];
      console.log(`[SCRAPE-SERVICE] [BREADCRUMBS] Sonuç: ${JSON.stringify(breadcrumbs)}`);

      // 5. Açıklama Çekimi
      console.log(`[SCRAPE-SERVICE] [DESCRIPTION] Açıklama çekiliyor...`);
      const description = matchedScraper.scrapeDescription ? await matchedScraper.scrapeDescription($) : null;
      console.log(`[SCRAPE-SERVICE] [DESCRIPTION] Sonuç: "${description || 'BULUNAMADI'}"`);

      // 6. Fiyat Etiketi / CRM Bilgisi Çekimi
      console.log(`[SCRAPE-SERVICE] [PRICE-LABEL] Kampanya etiketi çekiliyor...`);
      const priceLabel = matchedScraper.scrapePriceLabel ? await matchedScraper.scrapePriceLabel($) : null;
      console.log(`[SCRAPE-SERVICE] [PRICE-LABEL] Sonuç: "${priceLabel || 'BULUNAMADI'}"`);

      // 7. Rating ve Marka Bilgisi Çekimi
      console.log(`[SCRAPE-SERVICE] [RATING & BRAND] Rating ve Marka bilgisi çekiliyor...`);
      const rating = matchedScraper.scrapeRating ? matchedScraper.scrapeRating($) : { ratingValue: null, ratingCount: null };
      const brand = matchedScraper.scrapeBrand ? matchedScraper.scrapeBrand($) : null;
      console.log(`[SCRAPE-SERVICE] [RATING & BRAND] Rating: ${JSON.stringify(rating)}, Brand: "${brand || 'BULUNAMADI'}"`);

      const totalDuration = Date.now() - startTime;
      console.log(`============================================================`);
      console.log(`[SCRAPE-SERVICE] ✅ Scrape tamamlandı! Toplam süre: ${totalDuration}ms`);
      console.log(`============================================================\n`);

      return {
        url: targetUrl,
        title: title || null,
        price: price || null,
        originalPrice: originalPrice || null,
        imageUrl: imageUrl || null,
        description: description || null,
        breadcrumbs: breadcrumbs,
        priceLabel: priceLabel || null,
        ratingValue: rating?.ratingValue || null,
        ratingCount: rating?.ratingCount || null,
        brand: brand || null,
      };
    } else {
      console.log(`[SCRAPE-SERVICE] Genel Fallback akışı (Open Graph) başlıyor...`);

      const title = $('meta[property="og:title"]').attr('content') || $('title').text();
      console.log(`[SCRAPE-SERVICE] [TITLE] (Fallback) Sonuç: "${title ? title.trim() : 'BULUNAMADI'}"`);

      const rawImage = $('meta[property="og:image"]').attr('content') || $('link[rel="image_src"]').attr('href');
      console.log(`[SCRAPE-SERVICE] [IMAGE] (Fallback) Ham Görsel: "${rawImage || 'BULUNAMADI'}"`);

      let imageUrl = null;
      if (rawImage && !rawImage.startsWith('data:')) {
        if (rawImage.startsWith('http://') || rawImage.startsWith('https://')) {
          imageUrl = rawImage;
        } else {
          try {
            const base = new URL(targetUrl);
            imageUrl = new URL(rawImage, base).toString();
          } catch (_) { }
        }
      }
      console.log(`[SCRAPE-SERVICE] [IMAGE] (Fallback) Mutlak Görsel URL'i: "${imageUrl || 'BULUNAMADI'}"`);

      // Fallback fiyat tespiti
      let price = null;
      const priceMeta = $('meta[property="product:price:amount"]').attr('content') ||
        $('meta[property="og:price:amount"]').attr('content') ||
        $('meta[name="twitter:data1"]').attr('content');
      console.log(`[SCRAPE-SERVICE] [PRICE] (Fallback) Fiyat meta verisi: "${priceMeta || 'YOK'}"`);

      if (priceMeta) {
        const cleaned = priceMeta.replace(/[^0-9.,]/g, '').replace(',', '.');
        const parsed = parseFloat(cleaned);
        if (!isNaN(parsed)) price = parsed;
      }
      console.log(`[SCRAPE-SERVICE] [PRICE] (Fallback) Parsed Fiyat: "${price != null ? price + ' TL' : 'BULUNAMADI'}"`);
      const description = $('meta[property="og:description"]').attr('content') || $('meta[name="description"]').attr('content') || null;
      console.log(`[SCRAPE-SERVICE] [DESCRIPTION] (Fallback) Sonuç: "${description || 'BULUNAMADI'}"`);

      const totalDuration = Date.now() - startTime;
      console.log(`============================================================`);
      console.log(`[SCRAPE-SERVICE] ✅ Fallback Scrape tamamlandı! Toplam süre: ${totalDuration}ms`);
      console.log(`============================================================\n`);

      return {
        url: targetUrl,
        title: title ? title.trim() : null,
        price: price,
        imageUrl: imageUrl,
        description: description ? description.trim() : null,
        breadcrumbs: []
      };
    }
  } catch (err) {
    console.error(`[SCRAPE-SERVICE] ❌ Scrape işleminde beklenmeyen hata: ${err.message}`, err.stack);
    return { url, title: null, price: null, imageUrl: null, breadcrumbs: [] };
  }
}

module.exports = {
  scrapeProductFromUrl,
  resolveUrlRedirects,
  getHeadersForUrl
};
