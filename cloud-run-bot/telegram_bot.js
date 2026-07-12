/**
 * Real-Time Telegram Bot for Cloud Run
 * Sürekli çalışan, kanalları dinleyen bot
 */

const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const { NewMessage } = require('telegram/events');
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

let CHANNELS = process.env.TELEGRAM_CHANNELS ? process.env.TELEGRAM_CHANNELS.split(',') : [];

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
      countersDate: countersDate
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
    const lowerLink = link.toLowerCase();
    for (const domain of excludedDomains) {
      if (lowerLink.includes(domain)) {
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
    /(\d{1,3}(?:\.\d{3})+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    /(\d+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    /(?:TL|₺)\s*(\d{1,3}(?:\.\d{3})+(?:,\d{2})?)/gi,
    /(?:TL|₺)\s*(\d+(?:,\d{2})?)/gi
  ];

  for (const pattern of pricePatterns) {
    const match = text.match(pattern);
    if (match) {
      let cleanNum = match[0].replace(/[^\d,.]/g, '');
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
 * Gemini AI ile metinden ürün bilgisi çıkar (Fallback olarak kullanılır)
 */
async function analyzeTextWithGemini(messageText) {
  const apiKey = process.env.GEMINI_API_KEY;
  if (!apiKey) {
    console.warn('⚠️ GEMINI_API_KEY bulunamadı, AI fallback atlanıyor.');
    return null;
  }

  const url = `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent?key=${apiKey}`;

  const prompt = `Aşağıdaki Telegram mesajından ürün adı, indirimli fiyatı, mağazası ve en uygun kategoriyi tespit et.
Eğer mesajda fiyat belirtilmemişse veya birden fazla fiyat varsa, indirimli ana fiyatı seçmeye çalış.

Mesaj:
${messageText}`;

  try {
    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        contents: [{
          parts: [{
            text: prompt
          }]
        }],
        generationConfig: {
          responseMimeType: "application/json",
          responseSchema: {
            type: "object",
            properties: {
              title: { type: "string", description: "Ürün Adı (Marka Model)" },
              price: { type: "number", description: "Ürünün indirimli fiyatı (Sadece sayı, para birimi yok)" },
              category: {
                type: "string",
                description: "Ürünün kategorisi",
                enum: ["Elektronik", "Moda", "Ev_Yasam", "Anne_Bebek", "Kozmetik", "Spor_Outdoor", "Supermarket", "Yapi_Oto", "Kitap_Hobi", "Diger"]
              },
              store: { type: "string", description: "Mağaza adı" }
            },
            required: ["title", "price", "category", "store"]
          }
        }
      })
    });

    if (!response.ok) {
      console.error(`❌ Gemini API HTTP Hatası: ${response.status} ${response.statusText}`);
      return null;
    }

    const data = await response.json();
    const text = data.candidates?.[0]?.content?.parts?.[0]?.text;
    if (text) {
      return JSON.parse(text.trim());
    }
  } catch (err) {
    console.error('❌ analyzeTextWithGemini hatası:', err.message);
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
  else if (lowerLink.includes('amazon.') || lowerLink.includes('amzn.to') || lowerLink.includes('/amzn')) store = 'Amazon';
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
    } catch (e) {}
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
    
    let title = scrapeResult.title;
    let price = scrapeResult.price;
    let finalCategory = 'diger';

    // Eğer scraper başarısız olduysa (örneğin engellendiyse veya eksik veri döndürdüyse) Gemini AI ile metinden çıkarım yap
    if ((!title || !price || price === 0) && process.env.GEMINI_API_KEY) {
      console.log(`🤖 [${uniqueDocId}] Scraper engellenmiş veya eksik bilgi döndü. Gemini AI ile metin analizi deneniyor...`);
      try {
        const aiAnalysis = await analyzeTextWithGemini(messageText);
        if (aiAnalysis) {
          if (!title && aiAnalysis.title) {
            title = aiAnalysis.title;
          }
          if ((!price || price === 0) && aiAnalysis.price) {
            price = aiAnalysis.price;
          }
          
          // Kategori mapping (AI -> App Category ID)
          const categoryMapping = {
            'Elektronik': 'elektronik',
            'Moda': 'moda',
            'Ev_Yasam': 'ev_yasam',
            'Anne_Bebek': 'anne_bebek',
            'Kozmetik': 'kozmetik',
            'Spor_Outdoor': 'spor_outdoor',
            'Supermarket': 'supermarket',
            'Yapi_Oto': 'yapi_oto',
            'Kitap_Hobi': 'kitap_hobi',
            'Diger': 'diger'
          };
          if (aiAnalysis.category && categoryMapping[aiAnalysis.category]) {
            finalCategory = categoryMapping[aiAnalysis.category];
          }
          console.log(`🤖 [${uniqueDocId}] Gemini AI analizi tamamlandı: Başlık="${title}", Fiyat=${price}, Kategori=${finalCategory}`);
        }
      } catch (aiError) {
        console.error(`❌ [${uniqueDocId}] Gemini AI analiz hatası:`, aiError.message);
      }
    }

    // Eğer hala kategori belirlenmediyse (veya scraper başarılı olduysa) yerel kural motoru ile tespit et
    if (finalCategory === 'diger') {
      const categoryResult = categoryDetectionService.detectCategory(
        title || messageText, 
        scrapeResult.breadcrumbs || [], 
        scrapeResult.url || mainLink
      );
      finalCategory = categoryResult.categoryId || 'diger';
    }

    const cleanedTitle = cleanFallbackTitle(title || messageText);
    const finalPrice = price || extractPrice(messageText) || 0;
    
    const storeFromLink = extractStoreFromLink(scrapeResult.url || mainLink, messageText);
    const finalDescription = getDescriptionWithoutLinks(messageText, links);

    // ========================================
    // 📷 GÖRSEL KONTROLÜ VE YÜKLEME
    // ========================================
    let imageUrl = scrapeResult.imageUrl || '';

    // Görsel var mı kontrol et (Telegram mesajında)
    const hasPhoto = message.media && (
      message.media.photo ||
      (message.media.document && message.media.document.mimeType && message.media.document.mimeType.startsWith('image/'))
    );

    // Eğer scraper görsel bulamadıysa fakat Telegram mesajında görsel varsa Telegram görselini kullan
    if (!imageUrl && hasPhoto) {
      console.log(`📷 [${uniqueDocId}] Scraper görsel bulamadı fakat Telegram'da görsel var. Yükleniyor...`);
      try {
        const buffer = await client.downloadMedia(message.media, {
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

    // Deal objesi
    const deal = {
      title: cleanedTitle,
      description: finalDescription || 'Fırsat Ürünü Detayları',
      link: scrapeResult.url || mainLink,
      price: finalPrice,
      originalPrice: finalPrice ? finalPrice * 1.2 : 0,
      discount: finalPrice ? 20 : 0,
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

async function subscribeToChannels() {
  if (!client) return;
  
  console.log('🧹 Tüm event handler\'lar kaldırılıyor...');
  try {
    client.removeEventHandler();
  } catch (e) {
    console.warn('⚠️ Event handler kaldırma hatası:', e.message);
  }
  
  console.log(`🔊 ${CHANNELS.length} kanal için dinleyiciler başlatılıyor...`);
  
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
      
      client.addEventHandler(async (event) => {
        try {
          checkDateAndResetCounters();
          
          if (!botEnabled) {
            console.log('⏸️ Bot pasif durumda, mesaj atlandı.');
            return;
          }
          
          const message = event.message;
          if (!message) return;
          
          msgCount++;
          lastMessageTime = new Date();
          
          const links = getAllLinks(message);
          if (!links.length) {
            console.log(`⏩ [${channelInfo.title}] Mesajda link yok, atlanıyor.`);
            return;
          }
          
          const mainLink = links[0];
          
          // MÜKERRER (DUPLICATE) KONTROLÜ
          console.log(`🔍 [${channelInfo.title}] Mükerrer link kontrolü yapılıyor: ${mainLink}`);
          const dupCheckLink = await db.collection('deals')
            .where('link', '==', mainLink)
            .limit(1)
            .get();
          
          let dupCheckUrl = { empty: true };
          if (dupCheckLink.empty) {
            dupCheckUrl = await db.collection('deals')
              .where('url', '==', mainLink)
              .limit(1)
              .get();
          }
          
          if (!dupCheckLink.empty || !dupCheckUrl.empty) {
            console.log(`⏩ [${channelInfo.title}] Aynı link zaten kayıtlı, mükerrer atlanıyor: ${mainLink}`);
            dupCount++;
            return;
          }
          
          console.log(`📝 Mesaj içeriği: ${message.message?.substring(0, 100)}...`);
          
          const success = await saveDealToFirebase(message, channelInfo);
          if (success) {
            dealCount++;
          }
        } catch (error) {
          errCount++;
          console.error(`❌ Mesaj işleme hatası (${channelInfo.title}):`, error.message);
        }
      }, new NewMessage({ chats: [channel.id] }));
      
      console.log(`👂 ${channel.title} dinleniyor...`);
    } catch (error) {
      errCount++;
      console.error(`❌ Kanal bulunamadı: ${channelUsername}`, error.message);
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
    });

    await client.connect();
    console.log('✅ Telegram Client bağlandı!');

    await subscribeToChannels();

    isRunning = true;
    isStarting = false;
    console.log('🎉 Bot başarıyla başlatıldı! Kanallar dinleniyor...');

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
  await stopBot();
  process.exit(0);
});

process.on('SIGINT', async () => {
  console.log('⚠️ SIGINT alındı, bot kapatılıyor...');
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
  await startBot();
  await sendHeartbeat();
  setInterval(sendHeartbeat, 5 * 60 * 1000);
  initSettingsListener();
})().catch(console.error);

// Health check endpoint için basit HTTP server
const http = require('http');
const PORT = process.env.PORT || 8080;

const server = http.createServer((req, res) => {
  if (req.url === '/health' || req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      status: 'ok',
      bot_running: isRunning,
      channels: CHANNELS,
      uptime: process.uptime(),
      timestamp: new Date().toISOString(),
    }));
  } else {
    res.writeHead(404);
    res.end('Not Found');
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
