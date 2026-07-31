/**
 * Real-Time Telegram Bot for Cloud Run
 * Sürekli çalışan, kanalları dinleyen bot
 */

const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const { NewMessage } = require('telegram/events');
const { Api } = require('telegram/tl');
const admin = require('firebase-admin');
const { spawnSync } = require('child_process');

// Scraper ve Kategori servisleri
const linkScraperService = require('./link_scraper_service');
const categoryDetectionService = require('./category_detection_service');
const domainAllowlist = require('./domain_allowlist');

// Firebase Admin başlat
// Cloud Run'da otomatik authentication kullanır
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();



// URL parametrelerini temizleyen fonksiyon
function cleanProductUrl(urlStr) {
  if (!urlStr || typeof urlStr !== 'string') return '';
  try {
    const url = new URL(urlStr.trim());
    const host = url.hostname.toLowerCase();

    const majorStores = [
      'amazon',
      'trendyol',
      'hepsiburada',
      'n11',
      'pazarama',
      'pttavm',
      'zara',
      'defacto',
      'mavi',
      'beymen',
      'teknosa',
      'mediamarkt',
      'migros',
      'getir',
      'vatanbilgisayar',
      'idefix',
      'itopya',
      'incehesap',
      'havit'
    ];

    let isMajorStore = false;
    for (const store of majorStores) {
      if (host.includes(store)) {
        isMajorStore = true;
        break;
      }
    }

    if (isMajorStore) {
      // Büyük mağazalar için query parametrelerini tamamen temizle
      url.search = '';
    } else {
      // Diğer mağazalar için sadece ürün kimlik parametrelerini koru, kalanları sil
      const paramsToKeep = ['id', 'productid', 'product_id', 'p', 'item_id', 'itemid', 'sku'];
      const keys = Array.from(url.searchParams.keys());
      for (const key of keys) {
        if (!paramsToKeep.includes(key.toLowerCase())) {
          url.searchParams.delete(key);
        }
      }
    }

    let result = url.toString();
    if (result.endsWith('?')) {
      result = result.substring(0, result.length - 1);
    }
    return result;
  } catch (e) {
    return urlStr;
  }
}

// Environment variables - sanitized to prevent newline/quote issues from Secret Manager
const API_ID = (process.env.TELEGRAM_API_ID || '').trim();
const API_HASH = (process.env.TELEGRAM_API_HASH || '').trim();

let rawSession = process.env.TELEGRAM_SESSION_STRING || '';
rawSession = rawSession.trim();
if ((rawSession.startsWith('"') && rawSession.endsWith('"')) || (rawSession.startsWith("'") && rawSession.endsWith("'"))) {
  rawSession = rawSession.substring(1, rawSession.length - 1);
}
const SESSION_STRING = rawSession;

let CHANNELS = process.env.TELEGRAM_CHANNELS ? process.env.TELEGRAM_CHANNELS.split(',') : [];

// Circular log buffer for admin console view
const botLogs = [];
const MAX_LOGS = 500;

function formatLogLine(level, ...args) {
  const message = args
    .map(a => (typeof a === 'object' ? (a instanceof Error ? a.stack : JSON.stringify(a)) : String(a)))
    .join(' ');
  return {
    timestamp: new Date().toISOString(),
    level: level,
    message: message
  };
}

const originalLog = console.log;
const originalError = console.error;
const originalWarn = console.warn;
const originalInfo = console.info;

console.log = function (...args) {
  originalLog.apply(console, args);
  botLogs.push(formatLogLine('info', ...args));
  if (botLogs.length > MAX_LOGS) botLogs.shift();
};

console.error = function (...args) {
  originalError.apply(console, args);
  botLogs.push(formatLogLine('error', ...args));
  if (botLogs.length > MAX_LOGS) botLogs.shift();
};

console.warn = function (...args) {
  originalWarn.apply(console, args);
  botLogs.push(formatLogLine('warn', ...args));
  if (botLogs.length > MAX_LOGS) botLogs.shift();
};

console.info = function (...args) {
  originalInfo.apply(console, args);
  botLogs.push(formatLogLine('info', ...args));
  if (botLogs.length > MAX_LOGS) botLogs.shift();
};

console.log('🤖 Telegram Bot başlatılıyor...');
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
let isShuttingDown = false;

// Global Haritalar & Polling Değişkenleri
let monitoredMap = new Map();
let lastSeenMessageIds = new Map();
let pollingInterval = null;

// Sayaçlar ve Durum Değişkenleri
let msgCount = 0;
let dealCount = 0;
let dupCount = 0;
let errCount = 0;
let lastMessageTime = null;
let botEnabled = true;
let countersDate = new Date().toDateString();

function checkDateAndResetCounters() {
  const todayStr = new Date().toDateString();
  if (countersDate !== todayStr) {
    msgCount = 0;
    dealCount = 0;
    dupCount = 0;
    errCount = 0;
    countersDate = todayStr;
    console.log('🔄 Yeni gün başladı, in-memory bot sayaçları sıfırlandı.');
  }
}

async function loadCountersFromFirestore() {
  try {
    console.log('🔄 Firestore\'dan günlük sayaçlar yükleniyor...');
    const statusRef = db.collection('settings').doc('telegramBot');
    const doc = await statusRef.get();

    if (doc.exists) {
      const data = doc.data();
      const todayStr = new Date().toDateString();

      // Eğer Firestore'daki countersDate bugünün tarihi ise sayaçları oradan yükle
      if (data.countersDate === todayStr) {
        msgCount = data.msgCount || 0;
        dealCount = data.dealCount || 0;
        dupCount = data.dupCount || 0;
        errCount = data.errCount || 0;
        countersDate = todayStr;
        console.log(`✅ Sayaçlar başarıyla yüklendi: msgCount=${msgCount}, dealCount=${dealCount}, dupCount=${dupCount}, errCount=${errCount}`);
      } else {
        console.log('📅 Firestore\'daki sayaç tarihi eski veya bulunamadı, sayaçlar 0 olarak başlatılıyor.');
        countersDate = todayStr;
        // Firestore'u yeni tarih ve sıfırlanmış sayaçlarla güncelle
        await statusRef.set({
          msgCount: 0,
          dealCount: 0,
          dupCount: 0,
          errCount: 0,
          countersDate: todayStr
        }, { merge: true });
      }
    }
  } catch (error) {
    console.error('❌ Firestore\'dan sayaçları yüklerken hata oluştu:', error.message);
  }
}

async function loadChannelsFromFirestore() {
  try {
    const docRef = db.collection('settings').doc('telegramBot');
    const snap = await docRef.get();
    if (snap.exists) {
      const data = snap.data();
      if (data.monitoredChannels && Array.isArray(data.monitoredChannels) && data.monitoredChannels.length > 0) {
        CHANNELS = data.monitoredChannels.map(c => c.trim()).filter(Boolean);
        console.log(`📋 Firestore'dan ${CHANNELS.length} dinlenen kanal yüklendi:`, CHANNELS.join(', '));
        return;
      }
    }
  } catch (e) {
    console.warn('⚠️ Firestore\'dan kanallar yüklenemedi, varsayılan env kullanılacak:', e.message);
  }

  CHANNELS = process.env.TELEGRAM_CHANNELS ? process.env.TELEGRAM_CHANNELS.split(',').map(c => c.trim()).filter(Boolean) : [];
  console.log(`📋 ENV dosyasından ${CHANNELS.length} varsayılan kanal yüklendi:`, CHANNELS.join(', '));
}

async function sendHeartbeat() {
  try {
    checkDateAndResetCounters();
    const statusRef = db.collection('settings').doc('telegramBot');
    const environment = (process.env.PROJECT_ID || '').includes('prod') ? 'PROD' : 'DEV';
    await statusRef.set({
      lastHeartbeatAt: admin.firestore.FieldValue.serverTimestamp(),
      status: 'online',
      environment: environment,
      lastMessageTime: lastMessageTime ? admin.firestore.Timestamp.fromDate(lastMessageTime) : null,
      msgCount: msgCount,
      dealCount: dealCount,
      dupCount: dupCount,
      errCount: errCount,
      botEnabled: botEnabled,
      countersDate: countersDate,
      monitoredChannels: CHANNELS
    }, { merge: true });
    console.log('💓 Heartbeat sent successfully!');
  } catch (err) {
    console.error('❌ Heartbeat gönderim hatası:', err.message);
  }
}

let settingsUnsubscribe = null;

function initSettingsListener() {
  console.log('👂 Firestore settings/telegramBot real-time dinleyicisi başlatılıyor...');
  if (settingsUnsubscribe) {
    settingsUnsubscribe();
  }

  settingsUnsubscribe = db.collection('settings').doc('telegramBot').onSnapshot(async (snapshot) => {
    if (snapshot.exists) {
      const data = snapshot.data();
      botEnabled = data.botEnabled !== false;
      console.log(`⚙️ Firestore Ayarları: botEnabled = ${botEnabled}`);

      // Dinamik Kanal Yönetimi Kontrolü
      if (data.monitoredChannels && Array.isArray(data.monitoredChannels)) {
        const newChannels = data.monitoredChannels.map(c => c.trim()).filter(Boolean);
        const currentChannelsStr = JSON.stringify([...CHANNELS].sort());
        const newChannelsStr = JSON.stringify([...newChannels].sort());

        if (currentChannelsStr !== newChannelsStr) {
          console.log(`🔄 Monitored channels listesi değişti:`, newChannels);
          CHANNELS = newChannels;
          if (isRunning && client) {
            await subscribeToChannels();
          }
        }
      }
    } else {
      botEnabled = true;
    }
  }, (error) => {
    console.error('❌ Settings dinleyici hatası:', error.message);
    errCount++;
  });
}

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
 * Fiyat çıkar (Mesaj metninden fallback için)
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
/**
 * Fırsat başlığını temizle ve sadeleştir
 */
function cleanFallbackTitle(rawTitle) {
  if (!rawTitle) return 'Fırsat Ürünü';

  let title = rawTitle.trim();

  // Invalid / Generic titles (Google Search, Captcha, Just a moment, etc.)
  const invalidTitles = ['google search', 'google', 'just a moment...', 'attention required!', 'access denied', 'robot check', 'security check', 'cloudflare', '404 not found', 'error 404', 'fırsat ürünü'];
  if (invalidTitles.includes(title.toLowerCase())) {
    return 'Fırsat Ürünü';
  }

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

  // 5. Mağaza eki suffix'lerini temizle (örn: ": Amazon.com.tr: Kozmetik", ": Hepsiburada", "- Trendyol")
  title = title.replace(/:\s*Amazon\.com\.tr.*$/gi, '');
  title = title.replace(/:\s*Hepsiburada.*$/gi, '');
  title = title.replace(/:\s*Trendyol.*$/gi, '');
  title = title.replace(/:\s*N11.*$/gi, '');
  title = title.replace(/:\s*Pazarama.*$/gi, '');

  // 6. Eğer iki nokta (:) varsa ve parçalara ayrılıyorsa:
  // Eğer ilk parça 3 karakterden uzunsa ve sadece mağaza/reklam kelimesi değilse ilk parçayı ürün adı olarak koru!
  if (title.includes(':')) {
    const parts = title.split(':');
    const firstPart = parts[0].trim();
    const secondPart = parts[1] ? parts[1].trim() : '';

    if (firstPart.length >= 3 && !firstPart.toLowerCase().includes('fırsat') && !firstPart.toLowerCase().includes('indirim')) {
      title = firstPart;
    } else if (secondPart.length > 5) {
      title = secondPart;
    } else {
      title = firstPart;
    }
  }

  // 7. Ortak reklam ve mağaza kelimelerini temizle
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

  // 8. Sınır boşlukları ve sembolleri temizle
  title = title.trim()
    .replace(/^[-:,\s!📣🚨🔥.*_]+/g, '')
    .replace(/[-:,\s!📣🚨🔥.*_]+$/g, '')
    .trim();

  // 9. Çift boşlukları temizle
  title = title.replace(/\s+/g, ' ');

  // 10. Baş harfi büyüt
  if (title.length > 0) {
    title = title.charAt(0).toUpperCase() + title.slice(1);
  }

  // 11. Karakter sınırı (max 80)
  if (title.length > 80) {
    title = title.substring(0, 80).trim() + '...';
  }

  const lowerTitle = title.toLowerCase();
  if (lowerTitle === 'com.tr' || lowerTitle === 'com' || lowerTitle === 'net' || lowerTitle === 'org' || invalidTitles.includes(lowerTitle)) {
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
  let hostname = '';
  if (link) {
    try {
      hostname = new URL(link).hostname.toLowerCase();
    } catch (_) {
      hostname = lowerLink;
    }
  }

  if (hostname.includes('getir') || lowerLink.includes('getir.com') || lowerLink.includes('getir.onelink.me') || lowerLink.includes('onelink.me')) store = 'Getir';
  else if (hostname.includes('migros') || lowerLink.includes('migros.com')) store = 'Migros';
  else if (hostname.includes('trendyol') || lowerLink.includes('trendyol.com') || lowerLink.includes('ty.gl')) store = 'Trendyol';
  else if (hostname.includes('hepsiburada') || lowerLink.includes('hepsiburada.com') || lowerLink.includes('hb.biz')) store = 'Hepsiburada';
  else if (hostname.includes('amazon') || lowerLink.includes('amazon.') || lowerLink.includes('amzn.') || lowerLink.includes('amzlinks.')) store = 'Amazon';
  else if (hostname.includes('n11') || lowerLink.includes('n11.com')) store = 'N11';
  else if (hostname.includes('a101') || lowerLink.includes('a101.com')) store = 'A101';
  else if (hostname.includes('bim.com') || lowerLink.includes('bim.com.tr')) store = 'Bim';
  else if (hostname.includes('sokmarket') || hostname.includes('ceptesok')) store = 'Şok';
  else if (hostname.includes('pazarama') || lowerLink.includes('pazarama.com')) store = 'Pazarama';
  else if (hostname.includes('watsons') || lowerLink.includes('watsons.com')) store = 'Watsons';
  else if (hostname.includes('gratis') || lowerLink.includes('gratis.com')) store = 'Gratis';
  else if (hostname.includes('ikea') || lowerLink.includes('ikea.com')) store = 'Ikea';
  else if (hostname.includes('boyner') || lowerLink.includes('boyner.com')) store = 'Boyner';
  else if (hostname.includes('decathlon') || lowerLink.includes('decathlon.com')) store = 'Decathlon';
  else if (hostname.includes('mediamarkt') || lowerLink.includes('mediamarkt.com')) store = 'MediaMarkt';
  else if (hostname.includes('vatanbilgisayar') || lowerLink.includes('vatanbilgisayar')) store = 'Vatan Bilgisayar';
  else if (hostname.includes('teknosa') || lowerLink.includes('teknosa.com')) store = 'Teknosa';

  // Eğer linkten bulunamadıysa veya Google gibi arama linkiyse, metinden aramaya çalış
  if ((store === 'Diğer' || lowerLink.includes('google.')) && text) {
    const lowerText = text.toLowerCase();
    if (lowerText.includes('getir')) return 'Getir';
    if (lowerText.includes('migros')) return 'Migros';
    if (lowerText.includes('trendyol')) return 'Trendyol';
    if (lowerText.includes('hepsiburada')) return 'Hepsiburada';
    if (lowerText.includes('amazon')) return 'Amazon';
    if (lowerText.includes('n11')) return 'N11';
    if (lowerText.includes('a101')) return 'A101';
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
 * Açıklama metninden Editör, Yazar, Paylaşan, Admin vb. footer satırlarını ve sonrasını temizler.
 */
function truncateEditorAndFooterInfo(rawText) {
  if (!rawText) return '';

  const lines = rawText.split(/\r?\n/);
  const cleanLines = [];

  const forbiddenKeywords = [
    'editör',
    'editor',
    'yazar',
    'paylaşan',
    'paylasan',
    'hazırlayan',
    'hazirlayan',
    'ekleyen',
    'yayınlayan',
    'yayinlayan',
    'gönderen',
    'gonderen',
    'moderatör',
    'moderator',
    'admin',
    'kaynak:',
    'kanalımız',
    'kanalimiz',
    'grubumuz',
    'takip edin',
    'takipedin',
    'katılın',
    'katilin',
    'sponsorlu',
    'işbirliği',
    'isbirligi',
    'reklam içerir',
    'reklam icerir'
  ];

  for (const line of lines) {
    const trimmedLine = line.trim();
    if (!trimmedLine) {
      cleanLines.push(line);
      continue;
    }

    const lowerStandard = trimmedLine.toLowerCase();
    const lowerTurkish = trimmedLine.toLocaleLowerCase('tr-TR');

    const hasForbiddenWord = forbiddenKeywords.some(keyword => 
      lowerStandard.includes(keyword) || lowerTurkish.includes(keyword)
    );

    if (hasForbiddenWord) {
      console.log(`✂️ [AÇIKLAMA FİLTRESİ] Editör/Yazar/Footer satırı tespit edildi ("${trimmedLine}"), bu satırdan sonrası kesildi.`);
      break;
    }

    cleanLines.push(line);
  }

  return cleanLines.join('\n').trim();
}

/**
 * Mesaj metninden linkleri çıkartarak temiz bir açıklama metni hazırlar
 */
function getDescriptionWithoutLinks(messageText, links) {
  if (!messageText) return '';
  let text = messageText;
  if (Array.isArray(links)) {
    for (const link of links) {
      text = text.replace(link, '');
    }
  }

  text = truncateEditorAndFooterInfo(text);

  return text.trim().substring(0, 2000);
}

/**
 * Mesajı Firebase'e kaydet
 */
async function saveDealToFirebase(message, chatInfo, isTest = false) {
  try {
    const messageText = message.message || '';
    const rawLinks = getAllLinks(message);

    if (!rawLinks.length) {
      console.log('ℹ️ Mesajda link bulunamadı (Metin veya Buton)');
      return false;
    }

    // 🎯 DOMAIN ALLOWLIST İLE DESTEKLENEN MAĞAZA ÜRÜN LİNKİNİ TESPİT ET
    let mainLink = null;
    for (const rawLink of rawLinks) {
      // 1. Doğrudan allowlist'te var mı kontrol et (Ağ isteği atmadan instant eşleşme)
      if (domainAllowlist.isDomainAllowed(rawLink)) {
        mainLink = rawLink;
        console.log(`🎯 [ALLOWLIST MATCH] Desteklenen mağaza ürün linki bulundu: ${mainLink}`);
        break;
      }

      // 2. Kısa link veya yönlendirme varsa çöz ve tekrar kontrol et
      const resolvedLink = await linkScraperService.resolveUrlRedirects(rawLink);
      if (domainAllowlist.isDomainAllowed(resolvedLink)) {
        mainLink = resolvedLink;
        console.log(`🎯 [ALLOWLIST MATCH] Desteklenen mağaza ürün linki bulundu (Çözülen): ${mainLink} (Orijinal: ${rawLink})`);
        break;
      } else {
        console.log(`⏩ [ALLOWLIST SKIP] Allowlist dışı link atlandı: ${resolvedLink} (Orijinal: ${rawLink})`);
      }
    }

    if (!mainLink) {
      console.log('ℹ️ Mesajdaki hiçbir link desteklenen mağaza allowlist\'inde yer almadı. İşlem iptal ediliyor.');
      return false;
    }

    const messageId = message.id;
    const chatIdentifier = chatInfo.username ? `@${chatInfo.username}` : chatInfo.id.toString();
    const uniqueDocId = `telegram_${chatInfo.id}_${messageId}`;

    console.log(`🚀 [${uniqueDocId}] Scrape işlemi başlatılıyor: ${mainLink}`);

    // ========================================
    // ⚡ SCRAPING VE KATEGORİ TESPİTİ
    // ========================================
    const scrapeResult = await linkScraperService.scrapeProductFromUrl(mainLink);

    // Telegram WebPage Link Önizlemesini (Akamai Bypass) kontrol et
    let currentMessage = message;
    const hasWebpageMedia = (msg) => msg && msg.media && (msg.media.className === 'MessageMediaWebpage' || msg.media.className === 'MessageMediaWebPage') && msg.media.webpage;

    // Eğer scraper hem görsel hem başlık hem fiyat bulabildiyse bekleme yapmaya gerek yok!
    const needsWebpageMedia = !scrapeResult.imageUrl || !scrapeResult.title || !scrapeResult.price;
    if (!hasWebpageMedia(currentMessage) && needsWebpageMedia) {
      const waitTime = mainLink.includes('getir.com') || mainLink.includes('onelink.me') ? 8000 : 2500;
      console.log(`⏱️ [${uniqueDocId}] Scraper görsel/bilgi eksiğini tamamlama amacıyla Telegram önizlemesi için ${waitTime / 1000} saniye bekleniyor...`);
      await new Promise(resolve => setTimeout(resolve, waitTime));
      try {
        const refreshedMsgs = await client.getMessages(chatInfo.id, { ids: messageId });
        if (refreshedMsgs && refreshedMsgs.length > 0 && refreshedMsgs[0]) {
          currentMessage = refreshedMsgs[0];
          console.log(`🔄 [${uniqueDocId}] Mesaj yeniden çekildi. Yeni medya durumu: ${currentMessage.media ? currentMessage.media.className : 'Yok'}`);
        }
      } catch (err) {
        console.warn(`⚠️ [${uniqueDocId}] Mesaj yeniden çekilemedi: ${err.message}`);
      }
    }

    let webpageTitle = '';
    let webpageDescription = '';
    let webpageHasPhoto = false;
    let webpagePhotoObj = null;

    if (currentMessage.media && (currentMessage.media.className === 'MessageMediaWebpage' || currentMessage.media.className === 'MessageMediaWebPage') && currentMessage.media.webpage) {
      const wp = currentMessage.media.webpage;
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

    const isInvalidTitle = (t) => {
      if (!t) return true;
      const lower = t.trim().toLowerCase();
      const invalidList = ['google search', 'google', 'just a moment...', 'attention required!', 'access denied', 'robot check', 'security check', 'cloudflare', '404 not found', 'error 404', 'fırsat ürünü'];
      return invalidList.some(inv => lower.includes(inv));
    };

    if (isInvalidTitle(scrapeResult.title) && webpageTitle && !isInvalidTitle(webpageTitle)) {
      console.log(`💡 [${uniqueDocId}] Scraper başlık çekemedi (Akamai 403 vb.). Telegram önizleme başlığı kullanılıyor: ${webpageTitle}`);
      scrapeResult.title = webpageTitle;
      titleSource = "Telegram Link Önizleme";
    } else if (isInvalidTitle(scrapeResult.title)) {
      scrapeResult.title = null;
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

    const storeFromLink = extractStoreFromLink(scrapeResult.url || mainLink, messageText);
    const categoryResult = categoryDetectionService.detectCategory(
      cleanedTitle,
      scrapeResult.breadcrumbs || [],
      scrapeResult.url || mainLink,
      storeFromLink
    );
    const finalCategory = categoryResult.categoryId || 'diger';

    const finalDescription = getDescriptionWithoutLinks(messageText, rawLinks);

    // ========================================
    // 📷 GÖRSEL KONTROLÜ VE YÜKLEME
    // ========================================
    let imageUrl = scrapeResult.imageUrl || '';
    let photoSource = "Bulunamadı";

    if (imageUrl) {
      photoSource = "Scraper (Siteden)";
    }

    // Görsel var mı kontrol et (Telegram mesajında veya Link önizlemesinde)
    const hasPhoto = (currentMessage.media && (
      currentMessage.media.photo ||
      (currentMessage.media.document && currentMessage.media.document.mimeType && currentMessage.media.document.mimeType.startsWith('image/'))
    )) || webpageHasPhoto;

    // Eğer scraper görsel bulamadıysa fakat Telegram mesajında/önizlemesinde görsel varsa Telegram görselini kullan
    if (!imageUrl && hasPhoto) {
      if (currentMessage.media && currentMessage.media.photo) {
        photoSource = "Mesaj Görseli";
      } else if (webpageHasPhoto) {
        photoSource = "Telegram Link Önizleme Görseli (Storage'a Yüklendi)";
      }

      console.log(`📷 [${uniqueDocId}] Scraper görsel bulamadı fakat Telegram'da görsel/önizleme var. Yükleniyor...`);
      try {
        let mediaToDownload = currentMessage.media;
        if (!currentMessage.media.photo && webpagePhotoObj) {
          mediaToDownload = webpagePhotoObj;
        }

        const buffer = await client.downloadMedia(mediaToDownload, {
          workers: 4,
          progressCallback: (downloaded, total) => {
            const percent = Math.round((downloaded / total) * 100);
            if (percent % 25 === 0) {
              console.log(`📊 [${uniqueDocId}] İndirme: %${percent} (${downloaded}/${total})`);
            }
          }
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
    // Deal onay gereksinimini Firestore settings/app belgesinden kontrol et
    let dealApprovalRequired = true;
    try {
      const settingsDoc = await db.collection('settings').doc('app').get();
      if (settingsDoc.exists) {
        dealApprovalRequired = settingsDoc.data().dealApprovalRequired !== false;
      }
    } catch (e) {
      console.log('⚠️ Settings yüklenemedi, varsayılan olarak onay beklenecek:', e.message);
    }

    const origPrice = scrapeResult.originalPrice || scrapeResult.original_price || null;
    let discountRate = null;
    if (origPrice && finalPrice && origPrice > finalPrice && finalPrice > 0) {
      discountRate = Math.round(((origPrice - finalPrice) / origPrice) * 100);
    }

    // Deal objesi
    const deal = {
      title: cleanedTitle,
      description: truncateEditorAndFooterInfo(finalDescription || scrapeResult.description || 'Fırsat Ürünü Detayları'),
      link: scrapeResult.url || mainLink,
      price: finalPrice,
      originalPrice: origPrice,
      discountRate: discountRate,
      discount: (scrapeResult.discount || null),
      imageUrl: imageUrl,
      store: storeFromLink,
      category: finalCategory,
      isApproved: !dealApprovalRequired,
      isUserSubmitted: false,
      isActive: true,
      isExpired: false,
      isFeatured: false,
      cleanUrl: cleanProductUrl(scrapeResult.url || mainLink),
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
      isTest: isTest,
      priceLabel: scrapeResult.priceLabel || null,
      ratingValue: scrapeResult.ratingValue || null,
      ratingCount: scrapeResult.ratingCount || null,
      brand: scrapeResult.brand || null,
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

async function subscribeToChannels() {
  if (!client) return;

  console.log('🧹 Tüm event handler\'lar kaldırılıyor...');
  try {
    client.removeEventHandler();
  } catch (e) {
    console.warn('⚠️ Event handler kaldırma hatası:', e.message);
  }

  console.log(`🔊 ${CHANNELS.length} kanal için dinleyiciler başlatılıyor...`);
  const monitoredChannelsMeta = [];
  monitoredMap.clear();

  for (const channelUsername of CHANNELS) {
    try {
      const trimmedChannel = channelUsername.trim();
      if (!trimmedChannel) continue;

      let channel;
      if (trimmedChannel.startsWith('@')) {
        console.log(`🔍 Username ile aranıyor: ${trimmedChannel}`);
        channel = await client.getEntity(trimmedChannel);
      } else {
        console.log(`🔍 ID ile aranıyor: ${trimmedChannel}`);
        const channelId = trimmedChannel.startsWith('-100')
          ? trimmedChannel.substring(4)
          : (trimmedChannel.startsWith('-') ? trimmedChannel.substring(1) : trimmedChannel);

        try {
          const peer = new Api.PeerChannel({ channelId: BigInt(channelId) });
          channel = await client.getEntity(peer);
        } catch (e1) {
          try {
            channel = await client.getEntity(BigInt(channelId));
          } catch (e2) {
            console.error(`❌ Kanal bulunamadı: ${trimmedChannel}`, e2.message);
            monitoredChannelsMeta.push({
              input: trimmedChannel,
              title: 'Bilinmeyen Kanal / Bulunamadı',
              username: trimmedChannel,
              id: trimmedChannel,
              subscribers: null,
              type: 'Unknown',
              status: 'error'
            });
            continue;
          }
        }
      }

      console.log(`✅ Kanal bulundu: ${channel.title || channel.firstName} (${trimmedChannel})`);

      let subscriberCount = null;
      try {
        if (channel.id && channel.accessHash) {
          const inputChannel = new Api.InputPeerChannel({
            channelId: BigInt(channel.id.toString()),
            accessHash: BigInt(channel.accessHash.toString())
          });
          const fullInfo = await client.invoke(new Api.channels.GetFullChannel({ channel: inputChannel }));
          if (fullInfo && fullInfo.fullChat && fullInfo.fullChat.participantsCount != null) {
            subscriberCount = fullInfo.fullChat.participantsCount;
          }
        }
      } catch (eFull) {
        console.log(`ℹ️ GetFullChannel (${trimmedChannel}):`, eFull.message);
      }

      // Otomatik Kanala Katılım Kontrolü
      if (channel.id && channel.accessHash) {
        try {
          const inputChannel = new Api.InputPeerChannel({
            channelId: BigInt(channel.id.toString()),
            accessHash: BigInt(channel.accessHash.toString())
          });
          await client.invoke(new Api.channels.JoinChannel({ channel: inputChannel }));
          console.log(`🎉 Kanala katılım / abonelik doğrulandı: ${channel.title || trimmedChannel}`);
        } catch (eJoin) {
          if (!eJoin.message.includes('USER_ALREADY_PARTICIPANT')) {
            console.log(`ℹ️ JoinChannel (${trimmedChannel}):`, eJoin.message);
          }
        }
      }

      const isPublic = !!channel.username;
      const isChannel = channel.broadcast !== false;
      const cleanId = channel.id ? channel.id.toString().replace(/^-100/, '').replace(/^-/, '') : trimmedChannel.replace(/^-100/, '').replace(/^-/, '');

      const channelInfo = {
        id: channel.id ? channel.id.toString() : cleanId,
        cleanId: cleanId,
        title: channel.title || channel.firstName || trimmedChannel,
        username: channel.username ? `@${channel.username}` : null,
        input: trimmedChannel,
        broadcast: channel.broadcast
      };

      // Map'e ekle (temiz ID, ham ID ve username bazlı)
      monitoredMap.set(cleanId, channelInfo);
      if (channel.username) {
        monitoredMap.set(`@${channel.username.toLowerCase()}`, channelInfo);
        monitoredMap.set(channel.username.toLowerCase(), channelInfo);
      }
      monitoredMap.set(trimmedChannel.toLowerCase(), channelInfo);

      monitoredChannelsMeta.push({
        input: trimmedChannel,
        title: channelInfo.title,
        username: channelInfo.username || (isPublic ? channelInfo.username : 'Özel Kanal'),
        id: channelInfo.id,
        subscribers: subscriberCount,
        type: isChannel ? (isPublic ? 'Kamuya Açık Kanal' : 'Özel Kanal') : 'Grup / Süpergrup',
        isPublic: isPublic,
        status: 'active'
      });

      console.log(`👂 ${channelInfo.title} (ID: ${cleanId}) dinlemeye eklendi.`);
    } catch (error) {
      errCount++;
      console.error(`❌ Kanal bulunamadı: ${channelUsername}`, error.message);
    }
  }

  // Real-Time MTProto Push Olay Dinleyicisi
  client.addEventHandler(handleTelegramMessageEvent, new NewMessage({}));

  try {
    const statusRef = db.collection('settings').doc('telegramBot');
    await statusRef.set({
      monitoredChannelsMeta: monitoredChannelsMeta
    }, { merge: true });
    console.log(`✅ ${monitoredChannelsMeta.length} kanalın detaylı metadataları Firestore'a kaydedildi.`);
  } catch (e) {
    console.error('❌ Kanal metadataları kaydedilemedi:', e.message);
  }
}

// Standalone Gelen Mesaj Olay İşleyicisi
async function handleTelegramMessageEvent(event) {
  try {
    checkDateAndResetCounters();

    if (!botEnabled) {
      console.log('⏸️ Bot pasif durumda, mesaj atlandı.');
      return;
    }

    const message = event.message;
    if (!message) return;

    // Mesajın geldiği sohbet ID'sini al ve temizle
    const rawChatId = event.chatId ? event.chatId.toString() : (message.peerId?.channelId ? message.peerId.channelId.toString() : '');
    const cleanChatId = rawChatId.replace(/^-100/, '').replace(/^-/, '');

    let matchedChannel = monitoredMap.get(cleanChatId) || monitoredMap.get(rawChatId);
    if (!matchedChannel && message.chat?.username) {
      matchedChannel = monitoredMap.get(`@${message.chat.username.toLowerCase()}`);
    }

    if (!matchedChannel) {
      return;
    }

    console.log(`📩 [${matchedChannel.title}] Mesaj yakalandı! (Chat ID: ${rawChatId})`);
    msgCount++;
    lastMessageTime = new Date();

    const links = getAllLinks(message);
    if (!links.length) {
      console.log(`⏩ [${matchedChannel.title}] Mesajda link yok, atlanıyor.`);
      return;
    }

    const mainLink = links[0];
    // MÜKERRER (DUPLICATE) KONTROLÜ
    console.log(`🔍 [${matchedChannel.title}] Mükerrer link kontrolü yapılıyor: ${mainLink}`);
    let resolvedLink = mainLink;
    try {
      resolvedLink = await linkScraperService.resolveUrlRedirects(mainLink);
    } catch (e) {
      console.warn(`[DUPLICATE-CHECK] ⚠️ Yönlendirme çözülemedi: ${e.message}`);
    }
    const cleanUrl = cleanProductUrl(resolvedLink);
    let isDuplicate = false;
    if (cleanUrl) {
      const querySnapshot = await db.collection('deals')
        .where('cleanUrl', '==', cleanUrl)
        .where('isApproved', '==', true)
        .get();

      if (!querySnapshot.empty) {
        for (const doc of querySnapshot.docs) {
          const dealData = doc.data();

          const isExpired = dealData.isExpired === true;
          const expiredVotes = dealData.expiredVotes || 0;
          if (isExpired || expiredVotes >= 15) {
            continue;
          }

          const hotVotes = dealData.hotVotes || 0;
          const coldVotes = dealData.coldVotes || 0;
          const totalVotes = hotVotes + coldVotes;
          if (totalVotes >= 5) {
            const hotPercentage = (hotVotes / totalVotes * 100);
            if (hotPercentage < 20) {
              continue;
            }
          }
          if (hotVotes - coldVotes <= -5) {
            continue;
          }

          isDuplicate = true;
          break;
        }
      }
    }

    if (isDuplicate) {
      console.log(`⏩ [${matchedChannel.title}] Aynı link zaten aktif olarak kayıtlı, mükerrer atlanıyor: ${mainLink}`);
      dupCount++;
      return;
    }

    console.log(`📝 Mesaj içeriği: ${message.message?.substring(0, 100)}...`);

    const success = await saveDealToFirebase(message, matchedChannel);
    if (success) {
      dealCount++;
    }
  } catch (error) {
    errCount++;
    console.error(`❌ Mesaj işleme hatası:`, error.message);
  }
}

// Kamusal (Yönetici Olunmayan) Kanallar İçin 5 Saniyelik Canlı Mesaj Polling Döngüsü
async function pollMonitoredChannels() {
  if (!client || !isRunning || !botEnabled) return;

  const processedInputs = new Set();

  for (const [key, channelInfo] of monitoredMap.entries()) {
    if (!channelInfo || processedInputs.has(channelInfo.input)) continue;
    processedInputs.add(channelInfo.input);

    try {
      const cleanId = channelInfo.cleanId;
      const messages = await client.getMessages(channelInfo.input, { limit: 2 });
      if (!messages || !messages.length) continue;

      const lastSeenId = lastSeenMessageIds.get(cleanId) || 0;

      // Bot ilk başladığında mevcut en son mesaj ID'sini kaydet
      if (lastSeenId === 0) {
        lastSeenMessageIds.set(cleanId, messages[0].id);
        continue;
      }

      // Yeni gelen mesajları eskiden yeniye doğru sırayla işle
      const newMessages = messages.filter(m => m.id > lastSeenId).sort((a, b) => a.id - b.id);

      for (const msg of newMessages) {
        lastSeenMessageIds.set(cleanId, Math.max(lastSeenMessageIds.get(cleanId) || 0, msg.id));
        console.log(`⚡ [${channelInfo.title}] Yeni mesaj yakalandı! (ID: ${msg.id} via 5s Polling)`);

        const fakeEvent = {
          message: msg,
          chatId: msg.peerId?.channelId ? `-100${msg.peerId.channelId}` : channelInfo.id
        };
        await handleTelegramMessageEvent(fakeEvent);
      }
    } catch (ePoll) {
      // Polling hataları yutulur
    }
  }
}

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
      if (!isShuttingDown) {
        console.log('🔄 10 saniye sonra yeniden bağlanmaya çalışılacak...');
        setTimeout(startBot, 10000);
      }
    });

    await client.connect();
    console.log('✅ Telegram Client bağlandı!');

    try {
      console.log('🔄 Telegram diyalogları ve sohbet akışları senkronize ediliyor...');
      await client.getDialogs({ limit: 100 });
      console.log('✅ Telegram diyalog akışı başarıyla başlatıldı!');
    } catch (eDialogs) {
      console.warn('⚠️ getDialogs uyarısı:', eDialogs.message);
    }

    await subscribeToChannels();

    isRunning = true;
    isStarting = false;
    console.log('🎉 Bot başarıyla başlatıldı! Kanallar dinleniyor...');

    // 5 Saniyelik Polling Döngüsü (Yönetici olunmayan kamusal kanallar için)
    if (pollingInterval) clearInterval(pollingInterval);
    pollingInterval = setInterval(pollMonitoredChannels, 5000);
    console.log('⚡ 5 saniyelik kanal mesaj takip döngüsü (Polling) başlatıldı!');

    // Keep-alive
    setInterval(() => {
      if (isRunning) {
        console.log(`💓 Bot çalışıyor... (${new Date().toISOString()})`);
      }
    }, 60000);

  } catch (error) {
    console.error('❌ Bot başlatma hatası:', error);
    await logErrorToFirestore('bot', 'Bot Start Error', error.message, error.stack);
    isRunning = false;
    isStarting = false;
    console.log('🔄 30 saniye sonra yeniden denenecek...');
    setTimeout(startBot, 30000);
  }
}

async function stopBot() {
  if (client && isRunning) {
    console.log('🛑 Bot durduruluyor...');
    await client.disconnect();
    isRunning = false;
    console.log('✅ Bot durduruldu');
  }
}

// Graceful shutdown
process.on('SIGTERM', async () => {
  console.log('⚠️ SIGTERM alındı, bot kapatılıyor...');
  isShuttingDown = true;
  await stopBot();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('⚠️ SIGINT alındı, bot kapatılıyor...');
  isShuttingDown = true;
  await stopBot();
  process.exit(0);
});

// Bot'u başlat
(async () => {
  const isDbOk = await testFirestore();
  if (!isDbOk) {
    console.warn('⚠️ Firestore testi başarısız oldu, ancak bot başlatılmaya çalışılıyor...');
  }

  await loadCountersFromFirestore();
  await loadChannelsFromFirestore();
  await startBot();
  await sendHeartbeat();
  setInterval(sendHeartbeat, 5 * 60 * 1000);
  initSettingsListener();
})().catch(console.error);

// Health check endpoint için basit HTTP server
const http = require('http');
const PORT = process.env.PORT || 8080;

const server = http.createServer(async (req, res) => {
  const parsedUrl = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

  // Helper to send JSON responses safely with CORS
  const sendJson = (statusCode, data) => {
    res.writeHead(statusCode, {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    res.end(JSON.stringify(data));
  };

  // Helper to send text/empty responses safely with CORS
  const sendText = (statusCode, text = '') => {
    res.writeHead(statusCode, {
      'Content-Type': 'text/plain',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type'
    });
    res.end(text);
  };

  if (req.method === 'OPTIONS') {
    sendText(200);
    return;
  }

  if (parsedUrl.pathname === '/health' || parsedUrl.pathname === '/') {
    sendJson(200, {
      status: 'ok',
      bot_running: isRunning,
      channels: CHANNELS,
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    });
  } else if (parsedUrl.pathname === '/bot-logs') {
    const limit = parseInt(parsedUrl.searchParams.get('limit') || '100');
    const startTime = parsedUrl.searchParams.get('startTime');
    let logsToReturn = botLogs;
    if (startTime) {
      const parsedTime = new Date(startTime).getTime();
      if (!isNaN(parsedTime)) {
        logsToReturn = botLogs.filter(log => new Date(log.timestamp).getTime() >= parsedTime);
      }
    }
    sendJson(200, { success: true, logs: logsToReturn.slice(-limit) });
    return;
  } else if (parsedUrl.pathname === '/test-bypass') {
    const targetUrl = parsedUrl.searchParams.get('url') || 'https://www.hepsiburada.com/gamepower-skadi-round-240-argb-240mm-sivi-islemci-sogutucu-am5-ve-lga1700-uyumlu-p-HBCV000064LQCT';
    const results = {};

    // 1. Direct Curl
    try {
      const curl = spawnSync('curl', [
        '-sL',
        '-H', 'User-Agent: WhatsApp/2.23.4.15 A',
        '--compressed',
        '-w', '\n---STATUS:%{http_code}---',
        targetUrl
      ], { encoding: 'utf-8', timeout: 8000 });
      const output = curl.stdout || '';
      const statusMatch = output.match(/---STATUS:(\d+)---/);
      const status = statusMatch ? parseInt(statusMatch[1]) : 0;
      results.direct_curl = { status, size: output.replace(/\n---STATUS:\d+---$/, '').length };
    } catch (e) { results.direct_curl = { error: e.message }; }

    // 2. Translate Proxy
    try {
      const parsed = new URL(targetUrl);
      const baseUrl = 'https://' + parsed.hostname.replace(/\./g, '-') + '.translate.goog' + parsed.pathname;
      const ua = { 'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36' };

      // Test 1: No params
      const r1 = await fetch(baseUrl + '?_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr', { headers: ua });
      const size1 = r1.ok ? (await r1.text()).length : 0;

      // Test 2: magaza=incehesap
      const r2 = await fetch(baseUrl + '?magaza=incehesap&_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr', { headers: ua });
      const size2 = r2.ok ? (await r2.text()).length : 0;

      // Test 3: magaza=İncehesap
      const r3 = await fetch(baseUrl + '?magaza=İncehesap&_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr', { headers: ua });
      const size3 = r3.ok ? (await r3.text()).length : 0;

      // Test 4: magaza=%C4%B0ncehesap
      const r4 = await fetch(baseUrl + '?magaza=%C4%B0ncehesap&_x_tr_sl=auto&_x_tr_tl=tr&_x_tr_hl=tr', { headers: ua });
      const size4 = r4.ok ? (await r4.text()).length : 0;

      results.translate_proxy = {
        test1_no_param: { status: r1.status, size: size1 },
        test2_incehesap: { status: r2.status, size: size2 },
        test3_raw_incehesap: { status: r3.status, size: size3 },
        test4_encoded_incehesap: { status: r4.status, size: size4 }
      };
    } catch (e) { results.translate_proxy = { error: e.message }; }

    // 3. Microlink HTML
    try {
      const microUrl = `https://api.microlink.io/?url=${encodeURIComponent(targetUrl)}&data.html.selector=html&data.html.type=html`;
      const r = await fetch(microUrl);
      if (r.ok) {
        const data = await r.json();
        const html = data.data?.html || '';
        results.microlink = {
          status: r.status,
          size: html.length
        };
      } else {
        results.microlink = { status: r.status };
      }
    } catch (e) { results.microlink = { error: e.message }; }

    sendJson(200, results);
    return;
  } else if (parsedUrl.pathname === '/simulate') {
    const urlToScrape = parsedUrl.searchParams.get('url');
    const customText = parsedUrl.searchParams.get('text');
    if (!urlToScrape) {
      sendJson(400, { error: 'url parameter is required' });
      return;
    }

    if (!isRunning || !client) {
      sendJson(503, { error: 'Telegram bot is not running or client is not connected' });
      return;
    }

    try {
      console.log(`[SIMULATE] Simüle edilen url işleniyor: ${urlToScrape}${customText ? ` ile mesaj metni: "${customText}"` : ''}`);

      // 1. Telegram'dan link önizlemesini doğrudan isteyelim
      let previewMedia = null;
      try {
        console.log(`[SIMULATE] Telegram'dan web sayfası önizlemesi alınıyor...`);
        previewMedia = await client.invoke(
          new Api.messages.GetWebPagePreview({
            message: urlToScrape,
          })
        );
        console.log(`[SIMULATE] Telegram önizleme sonucu: ${previewMedia ? previewMedia.className : 'Yok'}`);
      } catch (previewErr) {
        console.warn(`[SIMULATE] Telegram önizleme alma hatası: ${previewErr.message}`);
      }

      // 2. Dummy mesaj ve chatInfo nesnesi oluşturalım
      const mockMessageId = Math.floor(Math.random() * 1000000);
      const dummyMessage = {
        id: mockMessageId,
        message: customText || urlToScrape,
        entities: [],
        media: previewMedia ? previewMedia.media : null
      };

      const dummyChatInfo = {
        id: 3423704050, // Test kanalımızın temiz ID'si
        title: 'Simulation Test Channel',
        username: 'simulation_test',
        broadcast: true
      };

      const docId = `telegram_${dummyChatInfo.id}_${mockMessageId}`;
      console.log(`[SIMULATE] saveDealToFirebase çağrılıyor. Beklenen Belge ID: ${docId}`);

      const success = await saveDealToFirebase(dummyMessage, dummyChatInfo, true);

      if (success) {
        // Firestore'dan belgenin güncel halini okuyalım
        const docRef = db.collection('deals').doc(docId);
        const docSnap = await docRef.get();
        if (docSnap.exists) {
          sendJson(200, { success: true, docId, data: docSnap.data() });
          return;
        }
      }

      sendJson(500, { success: false, error: 'Failed to process deal or save to Firestore', docId });

    } catch (err) {
      console.error('[SIMULATE] Simülasyon hatası:', err);
      sendJson(500, { error: err.message, stack: err.stack });
    }
  } else {
    sendText(404, 'Not Found');
  }
});

server.listen(PORT, () => {
  console.log(`🌐 HTTP Server listening on port ${PORT}`);
  console.log(`📡 Health check: http://localhost:${PORT}/health`);
});

async function logErrorToFirestore(service, errorType, message, stack, severity = 'error') {
  try {
    await db.collection('systemErrors').add({
      service: service,
      errorType: errorType,
      message: message,
      stack: stack || null,
      status: 'unresolved',
      severity: severity,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log(`💾 Bot logu Firestore'a kaydedildi: [${service}] (${severity}) ${errorType}`);
  } catch (err) {
    console.error('❌ Bot logu Firestore\'a kaydedilemedi:', err.message);
  }
}

// Global Uncaught Error Handlers
process.on('uncaughtException', async (err) => {
  console.error('🔥 Bot Uncaught Exception:', err);
  const exitTimer = setTimeout(() => {
    process.exit(1);
  }, 3000);

  try {
    await logErrorToFirestore('bot', 'Uncaught Exception (Fatal)', err.message, err.stack, 'fatal');
  } catch (logErr) {
    console.error('❌ Failed to log global exception to Firestore:', logErr);
  } finally {
    clearTimeout(exitTimer);
    process.exit(1);
  }
});

process.on('unhandledRejection', async (reason, promise) => {
  console.error('🔥 Bot Unhandled Rejection:', reason);
  const msg = reason instanceof Error ? reason.message : String(reason);
  const stack = reason instanceof Error ? reason.stack : null;

  const exitTimer = setTimeout(() => {
    process.exit(1);
  }, 3000);

  try {
    await logErrorToFirestore('bot', 'Unhandled Rejection (Fatal)', msg, stack, 'fatal');
  } catch (logErr) {
    console.error('❌ Failed to log global rejection to Firestore:', logErr);
  } finally {
    clearTimeout(exitTimer);
    process.exit(1);
  }
});
