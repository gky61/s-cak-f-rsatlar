/**
 * Real-Time Telegram Bot for Cloud Run - History Fetcher
 * Belirli sayıda geçmiş mesajı çekip Firestore'a kaydeden script
 */

const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const { Api } = require('telegram/tl');
const admin = require('firebase-admin');

// Scraper ve Kategori servisleri
const linkScraperService = require('./link_scraper_service');
const categoryDetectionService = require('./category_detection_service');

// Firebase Admin başlat
// Cloud Run'da otomatik authentication kullanır
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

// Environment variables - sanitized to prevent newline/quote issues from Secret Manager
const API_ID = (process.env.TELEGRAM_API_ID || '').trim();
const API_HASH = (process.env.TELEGRAM_API_HASH || '').trim();

let rawSession = process.env.TELEGRAM_SESSION_STRING || '';
rawSession = rawSession.trim();
if ((rawSession.startsWith('"') && rawSession.endsWith('"')) || (rawSession.startsWith("'") && rawSession.endsWith("'"))) {
  rawSession = rawSession.substring(1, rawSession.length - 1);
}
const SESSION_STRING = rawSession;

const CHANNELS = process.env.TELEGRAM_CHANNELS ? process.env.TELEGRAM_CHANNELS.split(',') : [];

console.log('🤖 Telegram Bot (History Fetcher) başlatılıyor...');
console.log('🔑 Environment Variables Kontrolü:');
console.log(`   API_ID: ${API_ID ? 'Set ✅' : 'Missing ❌'}`);
console.log(`   API_HASH: ${API_HASH ? 'Set ✅' : 'Missing ❌'}`);
console.log(`   SESSION: ${SESSION_STRING ? 'Set ✅' : 'Missing ❌'}`);
console.log(`   CHANNELS: ${CHANNELS.length} kanal`);
console.log(`📡 Dinlenecek kanallar:`, CHANNELS.join(', '));

// Global Telegram client
let client = null;
let isRunning = false;
let isStarting = false;

/**
 * Firestore bağlantısını test et
 */
async function testFirestore() {
  try {
    console.log('🔍 Firestore bağlantısı test ediliyor...');
    const testDoc = db.collection('system').doc('bot_test');
    await testDoc.set({
      last_check: admin.firestore.FieldValue.serverTimestamp(),
      status: 'ok'
    }, { merge: true });
    console.log('✅ Firestore bağlantısı başarılı!');
    return true;
  } catch (error) {
    console.error('❌ Firestore bağlantı hatası:', error.message);
    return false;
  }
}

/**
 * Mesajdaki tüm linkleri çıkar (Metin, Gizli Linkler, Butonlar)
 * WhatsApp, Telegram ve diğer sosyal medya linklerini filtreler
 */
function getAllLinks(message) {
  const links = new Set();
  const text = message.message || '';

  // 1. Regex ile metin içindeki açık linkler
  const urlRegex = /(https?:\/\/[^\s]+)/g;
  const textMatches = text.match(urlRegex);
  if (textMatches) {
    textMatches.forEach(link => links.add(link));
  }

  // 2. Text Entities (Metin içi gizli linkler [Link](url))
  if (message.entities) {
    message.entities.forEach(entity => {
      if (entity.url) {
        links.add(entity.url);
      }
    });
  }

  // 3. Reply Markup (Butonlar - "Fırsata Git" vb.)
  if (message.replyMarkup && message.replyMarkup.rows) {
    message.replyMarkup.rows.forEach(row => {
      if (row.buttons) {
        row.buttons.forEach(btn => {
          if (btn.url) {
            links.add(btn.url);
          }
        });
      }
    });
  }

  // 4. 🚫 ÜRÜN LİNKİ OLMAYAN LİNKLERİ FİLTRELE
  const excludedDomains = [
    'whatsapp.com',
    'wa.me',
    'api.whatsapp.com',
    't.me',
    'telegram.me',
    'telegram.org',
    'discord.gg',
    'discord.com',
    'twitter.com',
    'x.com',
    'facebook.com',
    'fb.me',
    'instagram.com',
    'instagr.am',
    'tiktok.com',
    'youtube.com',
    'youtu.be',
  ];

  const filteredLinks = Array.from(links).filter(link => {
    let hostname;
    try {
      hostname = new URL(link).hostname.toLowerCase();
    } catch (_) {
      hostname = link.toLowerCase();
    }
    for (const domain of excludedDomains) {
      // hostname'in tam olarak domain ile eşleşmesini ya da .domain ile bitmesini kontrol et
      // Bu sayede 'idefix.com' içindeki 'x.com' yanlış eşleşmez
      if (hostname === domain || hostname.endsWith('.' + domain)) {
        console.log(`⏩ Filtrelendi (${domain}): ${link.substring(0, 50)}...`);
        return false;
      }
    }
    return true;
  });

  return filteredLinks;
}

/**
 * Fiyat çıkar
 */
function extractPrice(text) {
  if (!text) return null;

  const pricePatterns = [
    /(\d+(?:\.\d{3})+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    /(\d+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    /(?:TL|₺)\s*(\d+(?:\.\d{3})+(?:,\d{2})?)/gi,
    /(?:TL|₺)\s*(\d+(?:,\d{2})?)/gi,
    /(?:fiyat|fiyatı|fiyat bilgisi)\s*(?:bilgisi)?\s*(?::|is|=)?\s*(\d+(?:\.\d{3})*(?:,\d{2})?)/gi
  ];

  for (const pattern of pricePatterns) {
    const match = text.match(pattern);
    if (match) {
      pattern.lastIndex = 0;
      const cleanMatch = pattern.exec(text);
      let cleanNum = '';
      if (cleanMatch && cleanMatch[1]) {
        cleanNum = cleanMatch[1];
      } else {
        cleanNum = match[0].replace(/[^\d,.]/g, '');
      }

      pattern.lastIndex = 0; // reset index

      if (cleanNum.includes('.') && cleanNum.includes(',')) {
        cleanNum = cleanNum.replace(/\./g, '').replace(',', '.');
      } else if (cleanNum.includes(',')) {
        cleanNum = cleanNum.replace(',', '.');
      } else if (cleanNum.includes('.')) {
        const parts = cleanNum.split('.');
        if (parts[parts.length - 1].length === 3) {
          cleanNum = cleanNum.replace(/\./g, '');
        }
      }
      const parsed = parseFloat(cleanNum);
      if (!isNaN(parsed)) return parsed;
    }
  }

  return null;
}

/**
 * Fırsat başlığını temizle ve sadeleştir
 */
function cleanFallbackTitle(rawTitle) {
  if (!rawTitle) return 'Fırsat';

  let title = rawTitle.trim();

  // 1. Emojileri ve UTF-8 dışı sembolleri temizle
  title = title.replace(/[\u{1F300}-\u{1F9FF}]|[\u{2700}-\u{27BF}]|[\u{2600}-\u{26FF}]/gu, '');
  title = title.replace(/[^\x00-\x7F\u00C0-\u017F]/g, '');

  // 2. Slaş karakterlerini boşlukla değiştir
  title = title.replace(/\//g, ' ');

  // 3. Fiyat kalıplarını temizle
  title = title.replace(/(\d{1,3}(?:\.\d{3})*(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi, '');
  title = title.replace(/\b\d+\s*(?:TL|₺)/gi, '');
  title = title.replace(/\b\d+\s*lira/gi, '');
  title = title.replace(/₺\s*\d+(?:\.\d{3})*(?:,\d{2})?/g, '');

  // 4. Yüzdelik indirimleri temizle
  title = title.replace(/%\d+\s*(?:indirim)?/gi, '');

  // 5. Ortak reklam ve mağaza kelimelerini temizle
  const promoWords = [
    /hepsiburada(?:'da|da)?/gi,
    /trendyol(?:'da|da)?/gi,
    /amazon(?:'da|da)?/gi,
    /n11(?:'de|de)?/gi,
    /a101(?:'de|de)?/gi,
    /bim(?:'de|de)?/gi,
    /şok(?:'ta|ta)?/gi,
    /migros(?:'ta|ta)?/gi,
    /günün fırsatı/gi,
    /fırsat/gi,
    /indirim(?:li)?/gi,
    /kaçırma(?:yın)?/gi,
    /büyük indirim/gi,
    /süper fiyat/gi,
    /şok fiyat/gi,
    /çok iyi fiyat/gi,
    /kaçırılmayacak/gi,
    /koşun/gi,
    /sepette/gi,
    /ücretsiz kargo/gi,
    /kargo bedava/gi,
    /dev indirim/gi,
    /efsane indirim/gi,
    /kampanya/gi,
    /sadece/gi,
    /bugüne özel/gi,
    /yerine/gi,
    /fiyatıyla/gi,
    /fiyat/gi
  ];

  for (const regex of promoWords) {
    title = title.replace(regex, '');
  }

  // 6. İki nokta varsa sonrasını al
  if (title.includes(':')) {
    const parts = title.split(':');
    const afterColon = parts[1].trim();
    if (afterColon.length > 5) {
      title = afterColon;
    } else {
      title = parts[0].trim();
    }
  }

  // 7. Sınır boşlukları ve sembolleri temizle
  title = title.trim()
    .replace(/^[-:,\s!📣🚨🔥.*_]+/g, '')
    .replace(/[-:,\s!📣🚨🔥.*_]+$/g, '')
    .trim();

  // 8. Çift boşlukları temizle
  title = title.replace(/\s+/g, ' ');

  // 9. Baş harfi büyüt
  if (title.length > 0) {
    title = title.charAt(0).toUpperCase() + title.slice(1);
  }

  // 10. Karakter sınırı (max 80)
  if (title.length > 80) {
    title = title.substring(0, 80).trim() + '...';
  }

  const lowerTitle = title.toLowerCase();
  if (lowerTitle === 'com.tr' || lowerTitle === 'com' || lowerTitle === 'net' || lowerTitle === 'org') {
    return 'Fırsat Ürünü';
  }

  return title || 'Fırsat Ürünü';
}

/**
 * Fırsat linkinden mağaza platformunu bulur
 */
function extractStoreFromLink(link, text) {
  let store = 'Diğer';
  const lowerLink = link ? link.toLowerCase() : '';

  if (lowerLink.includes('trendyol.com') || lowerLink.includes('ty.gl')) store = 'Trendyol';
  else if (lowerLink.includes('hepsiburada.com') || lowerLink.includes('hb.biz')) store = 'Hepsiburada';
  else if (lowerLink.includes('amazon.') || lowerLink.includes('amzn.') || lowerLink.includes('link.amazon') || lowerLink.includes('amzlinks.') || lowerLink.includes('/amzn')) store = 'Amazon';
  else if (lowerLink.includes('n11.com')) store = 'N11';
  else if (lowerLink.includes('a101.com') || lowerLink.includes('a101')) store = 'A101';
  else if (lowerLink.includes('migros.com') || lowerLink.includes('migros')) store = 'Migros';
  else if (lowerLink.includes('bim.com') || lowerLink.includes('bim')) store = 'Bim';
  else if (lowerLink.includes('sokmarket') || lowerLink.includes('ceptesok') || lowerLink.includes('sok')) store = 'Şok';
  else if (lowerLink.includes('pazarama.com') || lowerLink.includes('pazarama')) store = 'Pazarama';
  else if (lowerLink.includes('watsons.com') || lowerLink.includes('watsons')) store = 'Watsons';
  else if (lowerLink.includes('gratis.com') || lowerLink.includes('gratis')) store = 'Gratis';
  else if (lowerLink.includes('ikea.com') || lowerLink.includes('ikea')) store = 'Ikea';
  else if (lowerLink.includes('boyner.com') || lowerLink.includes('boyner')) store = 'Boyner';
  else if (lowerLink.includes('decathlon.com') || lowerLink.includes('decathlon')) store = 'Decathlon';
  else if (lowerLink.includes('mediamarkt.com') || lowerLink.includes('mediamarkt')) store = 'MediaMarkt';
  else if (lowerLink.includes('vatanbilgisayar') || lowerLink.includes('vatan')) store = 'Vatan Bilgisayar';
  else if (lowerLink.includes('teknosa.com') || lowerLink.includes('teknosa')) store = 'Teknosa';

  // Eğer linkten bulunamadıysa veya Google gibi arama linkiyse, metinden aramaya çalış
  if ((store === 'Diğer' || lowerLink.includes('google.')) && text) {
    const lowerText = text.toLowerCase();
    if (lowerText.includes('trendyol')) return 'Trendyol';
    if (lowerText.includes('hepsiburada')) return 'Hepsiburada';
    if (lowerText.includes('amazon')) return 'Amazon';
    if (lowerText.includes('n11')) return 'N11';
    if (lowerText.includes('a101')) return 'A101';
    if (lowerText.includes('migros')) return 'Migros';
    if (lowerText.includes('bim')) return 'Bim';
    if (lowerText.includes('şok') || lowerText.includes('sokmarket')) return 'Şok';
    if (lowerText.includes('pazarama')) return 'Pazarama';
    if (lowerText.includes('watsons')) return 'Watsons';
    if (lowerText.includes('gratis')) return 'Gratis';
    if (lowerText.includes('ikea')) return 'Ikea';
    if (lowerText.includes('boyner')) return 'Boyner';
    if (lowerText.includes('decathlon')) return 'Decathlon';
    if (lowerText.includes('mediamarkt')) return 'MediaMarkt';
    if (lowerText.includes('vatan')) return 'Vatan Bilgisayar';
    if (lowerText.includes('teknosa')) return 'Teknosa';
  }

  // Eğer hala Diğer ise ve link varsa, host ismini kullan
  if (store === 'Diğer' && link) {
    try {
      const url = new URL(link);
      const host = url.hostname.replace('www.', '');
      const parts = host.split('.');
      if (parts.length > 0) {
        const name = parts[0];
        return name.charAt(0).toUpperCase() + name.slice(1);
      }
    } catch (e) { }
  }

  return store === 'Diğer' ? 'Telegram' : store;
}

/**
 * Mesaj metninden linkleri çıkartarak temiz bir açıklama metni hazırlar
 */
function getDescriptionWithoutLinks(messageText, links) {
  if (!messageText) return '';
  let text = messageText;
  for (const link of links) {
    text = text.replace(link, '');
  }
  return text.trim().substring(0, 2000);
}

/**
 * Mesajı Firebase'e kaydet
 */
async function saveDealToFirebase(message, chatInfo) {
  try {
    const messageText = message.message || '';
    const links = getAllLinks(message);

    if (!links.length) {
      console.log('ℹ️ Mesajda link bulunamadı (Metin veya Buton)');
      return false;
    }

    const mainLink = links[0];
    const messageId = message.id;
    const chatIdentifier = chatInfo.username ? `@${chatInfo.username}` : chatInfo.id.toString();
    const uniqueDocId = `telegram_${chatInfo.id}_${messageId}`;

    console.log(`🚀 [${uniqueDocId}] Scrape işlemi başlatılıyor: ${mainLink}`);

    // ========================================
    // ⚡ SCRAPING VE KATEGORİ TESPİTİ
    // ========================================
    const scrapeResult = await linkScraperService.scrapeProductFromUrl(mainLink);

    // Telegram WebPage Link Önizlemesini (Akamai Bypass) kontrol et
    let webpageTitle = '';
    let webpageDescription = '';
    let webpageHasPhoto = false;
    let webpagePhotoObj = null;

    if (message.media && (message.media.className === 'MessageMediaWebpage' || message.media.className === 'MessageMediaWebPage') && message.media.webpage) {
      const wp = message.media.webpage;
      if (wp.className === 'WebPage') {
        webpageTitle = wp.title || '';
        webpageDescription = wp.description || '';
        if (wp.photo) {
          webpageHasPhoto = true;
          webpagePhotoObj = wp.photo;
        }
        console.log(`🤖 [Telegram Link Preview] Başlık: "${webpageTitle}"`);
        console.log(`🤖 [Telegram Link Preview] Açıklama: "${webpageDescription}"`);
      }
    }

    let titleSource = "Mesaj Metni";
    let descSource = "Mesaj Metni";
    let priceSource = "Bulunamadı (0)";

    if (scrapeResult.title) {
      titleSource = "Scraper (Siteden)";
    }
    if (scrapeResult.description) {
      descSource = "Scraper (Siteden)";
    }
    if (scrapeResult.price) {
      priceSource = "Scraper (Siteden)";
    } else if (extractPrice(messageText)) {
      priceSource = "Mesaj Metni";
    }

    if (!scrapeResult.title && webpageTitle) {
      console.log(`💡 [${uniqueDocId}] Scraper başlık çekemedi (Akamai 403 vb.). Telegram önizleme başlığı kullanılıyor: ${webpageTitle}`);
      scrapeResult.title = webpageTitle;
      titleSource = "Telegram Link Önizleme";
    }
    if (!scrapeResult.description && webpageDescription) {
      console.log(`💡 [${uniqueDocId}] Scraper açıklama çekemedi. Telegram önizleme açıklaması kullanılıyor`);
      scrapeResult.description = webpageDescription;
      descSource = "Telegram Link Önizleme";
    }

    const cleanedTitle = cleanFallbackTitle(scrapeResult.title || messageText);
    let finalPrice = scrapeResult.price || extractPrice(messageText) || 0;

    // Eğer fiyat hala bulunamadıysa (sadece link atılmış ve scraper engellenmiş olabilir),
    // Telegram önizlemesindeki açıklama veya başlıktan fiyat çıkarmayı deneyelim
    if (finalPrice === 0 && (webpageTitle || webpageDescription)) {
      const priceFromWpDesc = extractPrice(webpageDescription);
      if (priceFromWpDesc && priceFromWpDesc > 0) {
        console.log(`💡 [${uniqueDocId}] Fiyat Telegram önizleme açıklamasından çıkarıldı: ${priceFromWpDesc} TL`);
        finalPrice = priceFromWpDesc;
        priceSource = "Telegram Link Önizleme (Açıklama)";
      } else {
        const priceFromWpTitle = extractPrice(webpageTitle);
        if (priceFromWpTitle && priceFromWpTitle > 0) {
          console.log(`💡 [${uniqueDocId}] Fiyat Telegram önizleme başlığından çıkarıldı: ${priceFromWpTitle} TL`);
          finalPrice = priceFromWpTitle;
          priceSource = "Telegram Link Önizleme (Başlık)";
        }
      }
    }

    const categoryResult = categoryDetectionService.detectCategory(
      cleanedTitle,
      scrapeResult.breadcrumbs || [],
      scrapeResult.url || mainLink
    );
    const finalCategory = categoryResult.categoryId || 'diger';

    const storeFromLink = extractStoreFromLink(scrapeResult.url || mainLink, messageText);
    const finalDescription = getDescriptionWithoutLinks(messageText, links);

    // ========================================
    // 📷 GÖRSEL KONTROLÜ VE YÜKLEME
    // ========================================
    let imageUrl = scrapeResult.imageUrl || '';
    let photoSource = "Bulunamadı";

    if (imageUrl) {
      photoSource = "Scraper (Siteden)";
    }

    // Görsel var mı kontrol et (Telegram mesajında veya Link önizlemesinde)
    const hasPhoto = (message.media && (
      message.media.photo ||
      (message.media.document && message.media.document.mimeType && message.media.document.mimeType.startsWith('image/'))
    )) || webpageHasPhoto;

    // Eğer scraper görsel bulamadıysa fakat Telegram mesajında/önizlemesinde görsel varsa Telegram görselini kullan
    if (!imageUrl && hasPhoto) {
      if (message.media && message.media.photo) {
        photoSource = "Mesaj Görseli";
      } else if (webpageHasPhoto) {
        photoSource = "Telegram Link Önizleme Görseli (Storage'a Yüklendi)";
      }

      console.log(`📷 [${uniqueDocId}] Scraper görsel bulamadı fakat Telegram'da görsel/önizleme var. Yükleniyor...`);
      try {
        let mediaToDownload = message.media;
        if (!message.media.photo && webpagePhotoObj) {
          mediaToDownload = webpagePhotoObj;
        }

        const buffer = await client.downloadMedia(mediaToDownload, {
          workers: 4
        });

        if (buffer && buffer.length > 0) {
          const projectId = process.env.PROJECT_ID || process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'firsatkolik-prod-e6eae';
          const bucketName = `${projectId}.firebasestorage.app`;
          const bucket = admin.storage().bucket(bucketName);
          const filename = `deals/${chatInfo.id}_${messageId}.jpg`;
          const file = bucket.file(filename);

          console.log(`📤 [${uniqueDocId}] Firebase Storage'a yükleniyor (${buffer.length} bytes)...`);
          await file.save(buffer, {
            metadata: {
              contentType: 'image/jpeg',
              cacheControl: 'public, max-age=31536000'
            },
            resumable: false,
            public: false
          });

          imageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(filename)}?alt=media`;
          console.log(`🎉 [${uniqueDocId}] Telegram görseli Storage'a yüklendi!`);
        }
      } catch (imageError) {
        console.error(`❌ [${uniqueDocId}] Telegram görsel yükleme hatası:`, imageError.message);
      }
    }

    // ========================================
    // 📊 VERİ ÇEKME RAPORU (LOGLAMA)
    // ========================================
    console.log(`
🎯 ====================================================
🎯 [VERİ ÇEKME RAPORU] - [${uniqueDocId}]
🎯 ====================================================
🔗 Link: ${mainLink}
🔍 Detaylar:
   - Başlık: "${cleanedTitle}"
     ↳ [Kaynak: ${titleSource}]
   - Fiyat: ${finalPrice} TL
     ↳ [Kaynak: ${priceSource}]
   - Açıklama: "${finalDescription.substring(0, 60)}${finalDescription.length > 60 ? '...' : ''}"
     ↳ [Kaynak: ${descSource}]
   - Görsel: ${imageUrl ? imageUrl.substring(0, 85) + '...' : 'Yok'}
     ↳ [Kaynak: ${photoSource}]
   - Kategori: ${finalCategory}
     ↳ [Kategori Tespit Servisi]
🎯 ====================================================
    `);

    // Deal objesi
    const deal = {
      title: cleanedTitle,
      description: finalDescription || 'Fırsat Ürünü Detayları',
      link: scrapeResult.url || mainLink,
      price: finalPrice,
      originalPrice: (scrapeResult.originalPrice || scrapeResult.original_price || null),
      discount: (scrapeResult.discount || null),
      imageUrl: imageUrl,
      store: storeFromLink,
      category: finalCategory,
      isApproved: false,
      isUserSubmitted: false,
      isActive: true,
      isExpired: false,
      isFeatured: false,
      viewCount: 0,
      hotVotes: 0,
      coldVotes: 0,
      commentCount: 0,
      postedBy: `telegram_${chatIdentifier.replace('@', '')}`,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isEditorPick: false,
      tags: [],
      hotVoters: [],
      coldVoters: [],
      source: 'telegram',
      telegramMessageId: messageId,
      telegramChatId: chatInfo.id.toString(),
      telegramChatType: chatInfo.broadcast ? 'channel' : 'group',
      telegramChatTitle: chatInfo.title || chatIdentifier,
      telegramChatUsername: chatIdentifier,
      rawMessage: messageText,
    };

    console.log(`💾 Kaydediliyor: ${uniqueDocId} (imageUrl: ${imageUrl ? 'VAR ✅' : 'YOK ❌'})`);
    const dealRef = db.collection('deals').doc(uniqueDocId);

    // Direkt Firestore'a kaydet
    await dealRef.set(deal, { merge: true });
    console.log(`✅ Deal kaydedildi: ${uniqueDocId}`);

    return true;
  } catch (error) {
    console.error('❌ Firebase kayıt hatası:', error.message);
    return false;
  }
}

/**
 * Telegram Client'ı başlat ve geçmişi çek
 */
async function startBot() {
  if (isRunning || isStarting) {
    console.log('⚠️ Bot zaten çalışıyor veya başlatılıyor!');
    return;
  }

  isStarting = true;
  try {
    console.log('🔄 Telegram Client bağlanıyor...');

    if (client) {
      try {
        console.log('🧹 Eski client temizleniyor...');
        client.removeEventHandler();
        await client.disconnect();
        client = null;
        console.log('✅ Eski client temizlendi!');
      } catch (e) {
        console.error('⚠️ Client temizleme hatası:', e.message);
      }
    }

    const stringSession = new StringSession(SESSION_STRING);
    client = new TelegramClient(stringSession, parseInt(API_ID), API_HASH, {
      connectionRetries: 100,
      autoReconnect: true,
      useWSS: false,
      timeout: 60,
      requestRetries: 10,
      floodSleepThreshold: 60,
      deviceModel: 'Cloud Run Bot',
      systemVersion: '1.0',
      appVersion: '1.0',
    });

    client.on('disconnected', () => {
      console.warn('⚠️ Telegram bağlantısı koptu!');
      isRunning = false;
    });

    await client.connect();
    console.log('✅ Telegram Client bağlandı!');

    // Her kanal için geçmişi tara
    for (const channelUsername of CHANNELS) {
      try {
        const trimmedChannel = channelUsername.trim();
        let channel;

        if (trimmedChannel.startsWith('@')) {
          console.log(`🔍 Username ile aranıyor: ${trimmedChannel}`);
          channel = await client.getEntity(trimmedChannel);
        } else {
          console.log(`🔍 ID ile aranıyor: ${trimmedChannel}`);
          const channelId = trimmedChannel.startsWith('-')
            ? trimmedChannel.substring(1)
            : trimmedChannel;

          try {
            const peer = new Api.PeerChannel({
              channelId: BigInt(channelId)
            });
            channel = await client.getEntity(peer);
            console.log(`✅ PeerChannel ile bulundu: ${channel.title}`);
          } catch (e1) {
            console.log(`⚠️ PeerChannel ile bulunamadı (${e1.message}), BigInt deniyor...`);
            try {
              channel = await client.getEntity(BigInt(channelId));
              console.log(`✅ BigInt ile bulundu: ${channelId}`);
            } catch (e2) {
              console.error(`❌ Kanal bulunamadı: ${trimmedChannel}`);
              continue;
            }
          }
        }

        console.log(`✅ Kanal bulundu: ${channel.title} (${trimmedChannel})`);

        const channelInfo = {
          id: channel.id,
          title: channel.title,
          username: channel.username,
          broadcast: channel.broadcast,
        };

        // Son 15 mesajı çek
        console.log(`📥 [${channelInfo.title}] Son 15 mesaj çekiliyor...`);
        const messages = await client.getMessages(channel, { limit: 15 });
        console.log(`📊 Son ${messages.length} mesaj çekildi. İşleniyor...`);

        for (const message of messages) {
          const messageId = message.id;
          const links = getAllLinks(message);
          if (!links.length) {
            console.log(`⏩ [ID: ${messageId}] Link yok, atlanıyor.`);
            continue;
          }

          console.log(`📝 [ID: ${messageId}] Fırsat işleniyor...`);
          try {
            await saveDealToFirebase(message, channelInfo);
            console.log(`✅ [ID: ${messageId}] Fırsat işlendi.`);
          } catch (err) {
            console.error(`❌ [ID: ${messageId}] Hata:`, err.message);
          }
        }
      } catch (error) {
        console.error(`❌ Kanal bulunamadı: ${channelUsername}`, error.message);
      }
    }

    console.log('🎉 Tüm kanallar tarandı. Oturum sonlandırılıyor...');
    await client.disconnect();
    process.exit(0);
  } catch (error) {
    console.error('❌ Hata:', error);
    process.exit(1);
  }
}

// Bot'u başlat
(async () => {
  const isDbOk = await testFirestore();
  if (!isDbOk) {
    console.warn('⚠️ Firestore testi başarısız oldu, çıkılıyor...');
    process.exit(1);
  }
  await startBot();
})();
