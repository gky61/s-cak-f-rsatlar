/**
 * Real-Time Telegram Bot for Cloud Run
 * Sürekli çalışan, kanalları dinleyen bot
 */

const { TelegramClient } = require('telegram');
const { StringSession } = require('telegram/sessions');
const { NewMessage } = require('telegram/events');
const { Api } = require('telegram/tl');
const admin = require('firebase-admin');
const { GoogleGenerativeAI } = require('@google/generative-ai');

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

let rawGeminiKey = process.env.GEMINI_API_KEY || '';
rawGeminiKey = rawGeminiKey.trim();
if ((rawGeminiKey.startsWith('"') && rawGeminiKey.endsWith('"')) || (rawGeminiKey.startsWith("'") && rawGeminiKey.endsWith("'"))) {
  rawGeminiKey = rawGeminiKey.substring(1, rawGeminiKey.length - 1);
}
const GEMINI_API_KEY = rawGeminiKey;

// Gemini AI initialization
const genAI = new GoogleGenerativeAI(GEMINI_API_KEY);

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
      // MessageEntityTextUrl kontrolü
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
          // KeyboardButtonUrl kontrolü
          if (btn.url) {
            links.add(btn.url);
          }
        });
      }
    });
  }

  // 4. 🚫 ÜRÜN LİNKİ OLMAYAN LİNKLERİ FİLTRELE
  const excludedDomains = [
    // Mesajlaşma uygulamaları
    'whatsapp.com',
    'wa.me',
    'api.whatsapp.com',
    't.me',
    'telegram.me',
    'telegram.org',
    'discord.gg',
    'discord.com',
    // Sosyal medya
    'twitter.com',
    'x.com',
    'facebook.com',
    'fb.me',
    'instagram.com',
    'instagr.am',
    'tiktok.com',
    'youtube.com',
    'youtu.be',
    // Kısa link servisleri (ürün linki olabilir ama riskli)
    // 'bit.ly', 'goo.gl', 'tinyurl.com' // bunları şimdilik tutuyoruz
  ];

  const filteredLinks = Array.from(links).filter(link => {
    const lowerLink = link.toLowerCase();

    // Hariç tutulan domain'leri kontrol et
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
 * Gemini AI ile görsel analizi 🤖
 */
async function analyzeImageWithGemini(imageBuffer, messageText) {
  try {
    console.log('🤖 Gemini AI görsel analizi başlıyor...');
    const startTime = Date.now();

    // Gemini 2.0 Flash (Hızlı ve Multimodal) ve responseSchema
    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            title: { type: "string", description: "Ürün Adı (Marka Model)" },
            price: { type: "number", description: "Ürünün indirimli fiyatı (Sadece sayı, para birimi yok)" },
            category: {
              type: "string",
              description: "Ürünün ait olduğu en uygun kategori: " +
                           "Elektronik (Telefon, Bilgisayar, TV, Kulaklık, Hoparlör, Beyaz Eşya, Ev Aletleri vb.); " +
                           "Moda & Giyim (Kıyafet, Ayakkabı, Saat, Çanta, Gözlük vb.); " +
                           "Ev, Yaşam & Ofis (Mobilya, Ev Tekstili, Mutfak Gereçleri, Aydınlatma, Kırtasiye vb.); " +
                           "Anne & Bebek (Bebek Bezi, Oyuncak, Bebek Arabası, Beslenme vb.); " +
                           "Kozmetik & Bakım (Parfüm, Makyaj, Cilt Bakımı, Şampuan, Diş Bakımı vb.); " +
                           "Spor & Outdoor (Spor Giyim, Fitness, Kamp, Bisiklet vb.); " +
                           "Süpermarket (Gıda, İçecek, Deterjan, Temizlik, Kağıt Ürünleri, Evcil Hayvan vb.); " +
                           "Yapı Market & Oto (Hırdavat, Matkap, Oto Aksesuarı, Lastik vb.); " +
                           "Kitap, Müzik & Hobi (Kitap, Oyun Konsolu, Oyunlar, Müzik Aletleri, Lego, Hobi vb.); " +
                           "Diğer (Hiçbirine uymayanlar)",
              enum: [
                "Elektronik",
                "Moda & Giyim",
                "Ev, Yaşam & Ofis",
                "Anne & Bebek",
                "Kozmetik & Bakım",
                "Spor & Outdoor",
                "Süpermarket",
                "Yapı Market & Oto",
                "Kitap, Müzik & Hobi",
                "Diğer"
              ]
            },
            store: { type: "string", description: "Fırsatın satıldığı mağaza (Trendyol, Hepsiburada, Amazon, N11, Migros, Şok, A101, Bim vb.)" }
          },
          required: ["title", "price", "category", "store"]
        }
      }
    });

    const base64Image = imageBuffer.toString('base64');

    // Prompt - Türkçe ve detaylı
    const prompt = `
    Sen uzman bir e-ticaret editörüsün. Bu görseli ve mesajı analiz et.
    
    MESAJ METNİ: "${messageText}"
    
    Lütfen şu bilgileri çıkar ve verilen JSON şemasına uygun olarak yanıtla:
    - title: Ürün Adı (Marka Model)
    - price: Sadece sayı (Para birimi yok)
    - category: Kategori. Ürünün tipine göre en uygun olanı seç. Pepsi, yiyecek, içecek, temizlik malzemeleri "Süpermarket" kategorisindedir.
    - store: Mağaza Adı
    `;

    const result = await model.generateContent([
      prompt,
      {
        inlineData: {
          mimeType: 'image/jpeg',
          data: base64Image
        }
      }
    ]);

    const response = result.response;
    const text = response.text();

    const analysisTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`✅ Gemini analizi tamamlandı! Süre: ${analysisTime}s`);
    console.log(`📊 Gemini yanıtı: ${text}`);

    // JSON temizleme ve parse
    let analysis;
    try {
      const cleanText = text.replace(/```json/g, '').replace(/```/g, '').trim();
      analysis = JSON.parse(cleanText);
    } catch (e) {
      console.warn('⚠️ JSON parse hatası, regex deneniyor...');
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        analysis = JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('JSON bulunamadı');
      }
    }

    console.log(`🎯 Analiz sonucu:`, analysis);

    // Eski formatla uyumlu döndür
    return {
      fiyat: analysis.price,
      kategori: analysis.category,
      magaza: analysis.store,
      urun: analysis.title
    };

  } catch (error) {
    console.error('❌ Gemini analiz hatası:', error.message);
    return null;
  }
}

/**
 * Gemini AI ile metin analizi (Görsel yoksa) 📝
 */
async function analyzeTextWithGemini(messageText) {
  try {
    console.log('🤖 Gemini AI metin analizi başlıyor...');
    const startTime = Date.now();

    const model = genAI.getGenerativeModel({
      model: "gemini-2.0-flash",
      generationConfig: {
        responseMimeType: "application/json",
        responseSchema: {
          type: "object",
          properties: {
            title: { type: "string", description: "Ürün Adı (Marka Model)" },
            price: { type: "number", description: "Ürünün indirimli fiyatı (Sadece sayı, para birimi yok)" },
            category: {
              type: "string",
              description: "Ürünün ait olduğu en uygun kategori: " +
                           "Elektronik (Telefon, Bilgisayar, TV, Kulaklık, Hoparlör, Beyaz Eşya, Ev Aletleri vb.); " +
                           "Moda & Giyim (Kıyafet, Ayakkabı, Saat, Çanta, Gözlük vb.); " +
                           "Ev, Yaşam & Ofis (Mobilya, Ev Tekstili, Mutfak Gereçleri, Aydınlatma, Kırtasiye vb.); " +
                           "Anne & Bebek (Bebek Bezi, Oyuncak, Bebek Arabası, Beslenme vb.); " +
                           "Kozmetik & Bakım (Parfüm, Makyaj, Cilt Bakımı, Şampuan, Diş Bakımı vb.); " +
                           "Spor & Outdoor (Spor Giyim, Fitness, Kamp, Bisiklet vb.); " +
                           "Süpermarket (Gıda, İçecek, Deterjan, Temizlik, Kağıt Ürünleri, Evcil Hayvan vb.); " +
                           "Yapı Market & Oto (Hırdavat, Matkap, Oto Aksesuarı, Lastik vb.); " +
                           "Kitap, Müzik & Hobi (Kitap, Oyun Konsolu, Oyunlar, Müzik Aletleri, Lego, Hobi vb.); " +
                           "Diğer (Hiçbirine uymayanlar)",
              enum: [
                "Elektronik",
                "Moda & Giyim",
                "Ev, Yaşam & Ofis",
                "Anne & Bebek",
                "Kozmetik & Bakım",
                "Spor & Outdoor",
                "Süpermarket",
                "Yapı Market & Oto",
                "Kitap, Müzik & Hobi",
                "Diğer"
              ]
            },
            store: { type: "string", description: "Fırsatın satıldığı mağaza (Trendyol, Hepsiburada, Amazon, N11, Migros, Şok, A101, Bim vb.)" }
          },
          required: ["title", "price", "category", "store"]
        }
      }
    });

    const prompt = `
    Sen uzman bir e-ticaret editörüsün. Bu mesaj metnini analiz et.
    
    MESAJ METNİ: "${messageText}"
    
    Lütfen şu bilgileri çıkar ve verilen JSON şemasına uygun olarak yanıtla:
    - title: Ürün Adı (Marka Model)
    - price: Sadece sayı (Para birimi yok). Fiyat yoksa 0 yaz.
    - category: Kategori. Ürünün tipine göre en uygun olanı seç. Pepsi, yiyecek, içecek, temizlik malzemeleri "Süpermarket" kategorisindedir.
    - store: Mağaza Adı
    `;

    const result = await model.generateContent(prompt);
    const response = result.response;
    const text = response.text();

    const analysisTime = ((Date.now() - startTime) / 1000).toFixed(2);
    console.log(`✅ Gemini metin analizi tamamlandı! Süre: ${analysisTime}s`);

    // JSON temizleme ve parse
    let analysis;
    try {
      const cleanText = text.replace(/```json/g, '').replace(/```/g, '').trim();
      analysis = JSON.parse(cleanText);
    } catch (e) {
      console.warn('⚠️ JSON parse hatası, regex deneniyor...');
      const jsonMatch = text.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        analysis = JSON.parse(jsonMatch[0]);
      } else {
        console.warn('❌ JSON bulunamadı, varsayılanlar kullanılacak');
        return null;
      }
    }

    console.log(`🎯 Metin Analiz sonucu:`, analysis);

    return {
      fiyat: analysis.price,
      kategori: analysis.category,
      magaza: analysis.store,
      urun: analysis.title
    };

  } catch (error) {
    console.error('❌ Gemini metin analiz hatası:', error.message);
    return null;
  }
}

/**
 * Fiyat çıkar
 */
function extractPrice(text) {
  if (!text) return null;

  // Türkçe fiyat formatları: 1.234,56 TL, 1234 TL veya ₺1.234,56, ₺1234
  const pricePatterns = [
    // 1. Fiyat sonda, binlik noktalı: "1.234,56 TL"
    /(\d{1,3}(?:\.\d{3})+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    // 2. Fiyat sonda, düz saylı: "1234 TL" veya "1234,56 TL"
    /(\d+(?:,\d{2})?)\s*(?:TL|₺|Lira)/gi,
    // 3. Fiyat başta, binlik noktalı: "₺1.234,56"
    /(?:TL|₺)\s*(\d{1,3}(?:\.\d{3})+(?:,\d{2})?)/gi,
    // 4. Fiyat başta, düz saylı: "₺1234" veya "₺1234,56"
    /(?:TL|₺)\s*(\d+(?:,\d{2})?)/gi
  ];

  for (const pattern of pricePatterns) {
    const match = text.match(pattern);
    if (match) {
      // Sayı dışındaki karakterleri temizle
      let cleanNum = match[0].replace(/[^\d,.]/g, '');
      
      // Eğer hem nokta hem virgül varsa (örn 1.234,56)
      if (cleanNum.includes('.') && cleanNum.includes(',')) {
        cleanNum = cleanNum.replace(/\./g, '').replace(',', '.');
      } else if (cleanNum.includes(',')) {
        // Sadece virgül varsa (örn 1234,56 veya 12,50)
        cleanNum = cleanNum.replace(',', '.');
      } else if (cleanNum.includes('.')) {
        // Sadece nokta varsa ve noktadan sonra tam 3 hane varsa (örn: 12.499 veya 3.450)
        // Bu durum Türkçe formatta binlik ayracıdır.
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

  return title || 'Fırsat Ürünü';
}

/**
 * Başlık ve açıklamadan yerel olarak kategori tahmini yapar
 */
function detectCategoryFromText(title, description) {
  const text = ((title || '') + ' ' + (description || '')).toLowerCase();
  
  // 1. Elektronik
  const elektronikKeywords = ['telefon', 'bilgisayar', 'laptop', 'notebook', 'monitör', 'ekran', 'mouse', 'klavye', 'kulaklık', 'hoparlör', 'tv', 'televizyon', 'tablet', 'şarj', 'adaptör', 'kablo', 'ssd', 'ram', 'ekran kartı', 'işlemci', 'anakart', 'powerbank', 'yazıcı', 'kamera', 'süpürge', 'robot süpürge', 'airfryer', 'kettle', 'çay makinesi', 'kahve makinesi', 'tost makinesi', 'ütü', 'klima', 'kombi', 'vantilatör', 'fön', 'tıraş makinesi'];
  for (const kw of elektronikKeywords) {
    if (text.includes(kw)) return 'elektronik';
  }
  
  // 2. Moda & Giyim
  const modaKeywords = ['elbise', 'ayakkabı', 'sneaker', 'bot', 'çizme', 'mont', 'ceket', 'kaban', 'hırka', 'tişör', 'tisort', 't-shirt', 'pantolon', 'sweatshirt', 'sweat', 'kazak', 'gömlek', 'yelek', 'çanta', 'cüzdan', 'saat', 'gözlük', 'çorap', 'iç giyim', 'pijama', 'şort', 'kemer', 'taki', 'kolye', 'küpe', 'yüzük'];
  for (const kw of modaKeywords) {
    if (text.includes(kw)) return 'moda';
  }
  
  // 3. Süpermarket (Temizlik & Gıda)
  const supermarketKeywords = ['deterjan', 'yumuşatıcı', 'şampuan', 'sabun', 'ıslak mendil', 'tuvalet kağıdı', 'kağıt havlu', 'deterjanı', 'omo', 'ariel', 'domestos', 'fairy', 'finish', 'gıda', 'yağ', 'zeytinyağı', 'sıvı yağ', 'pirinç', 'makarna', 'çay', 'kahve', 'şeker', 'tuz', 'çikolata', 'bisküvi', 'atıştırmalık', 'peynir', 'zeytin', 'süt', 'salça', 'un', 'pepsi', 'kola', 'cola', 'içecek', 'icecek', 'soda', 'gazoz', 'fanta', 'sprite', 'su', 'meyve suyu', 'nescafe', 'red bull', 'enerji içeceği', 'enerji icecegi'];
  for (const kw of supermarketKeywords) {
    if (text.includes(kw)) return 'supermarket';
  }
  
  // 4. Kozmetik & Bakım
  const kozmetikKeywords = ['parfüm', 'parfum', 'deodorant', 'krem', 'nemlendirici', 'serum', 'makyaj', 'ruj', 'fondöten', 'rimel', 'maskara', 'cilt bakım', 'şampuan', 'duş jeli', 'saç kremi', 'güneş kremi', 'kolonya', 'diş macunu', 'diş fırçası'];
  for (const kw of kozmetikKeywords) {
    if (text.includes(kw)) return 'kozmetik';
  }
  
  // 5. Ev, Yaşam & Ofis
  const evKeywords = ['tava', 'tencere', 'mutfak', 'tabak', 'çatal', 'kaşık', 'bıçak', 'kupa', 'bardak', 'yemek takımı', 'nevresim', 'perde', 'yastık', 'yorgan', 'çarşaf', 'halı', 'kilim', 'koltuk', 'sandalye', 'masa', 'sehpa', 'dolap', 'gardırop', 'yatak', 'ayna', 'avize', 'lamba', 'dekorasyon', 'tablo', 'saksı', 'ofis', 'kalem', 'defter'];
  for (const kw of evKeywords) {
    if (text.includes(kw)) return 'ev_yasam';
  }
  
  // 6. Anne & Bebek
  const bebekKeywords = ['bebek', 'oyuncak', 'bebek bezi', 'bez', 'mama', 'biberon', 'emzik', 'puset', 'bebek arabası', 'oto koltuğu', 'ıslak mendil', 'beşik', 'mama sandalyesi', 'çıngırak'];
  for (const kw of bebekKeywords) {
    if (text.includes(kw)) return 'anne_bebek';
  }
  
  // 7. Spor & Outdoor
  const sporKeywords = ['spor', 'fitness', 'dambıl', 'pilates', 'mat', 'bisiklet', 'koşu', 'yürüyüş', 'kamp', 'çadır', 'uyku tulumu', 'termos', 'outdoor', 'forma', 'raket', 'top', 'futbol', 'basketbol', 'tenis', 'kask', 'bisikleti'];
  for (const kw of sporKeywords) {
    if (text.includes(kw)) return 'spor_outdoor';
  }
  
  // 8. Yapı Market & Oto
  const yapiKeywords = ['matkap', 'tornavida', 'hırdavat', 'alet', 'pense', 'anahtar takımı', 'vida', 'boya', 'fırça', 'oto', 'araba', 'araç', 'lastik', 'motor yağı', 'antifriz', 'silecek', 'kılıf', 'aksesuar', 'ampul', 'şerit led'];
  for (const kw of yapiKeywords) {
    if (text.includes(kw)) return 'yapi_oto';
  }
  
  // 9. Kitap, Müzik & Hobi
  const kitapKeywords = ['kitap', 'roman', 'hikaye', 'dergi', 'kırtasiye', 'lego', 'yapboz', 'puzzle', 'kutu oyunu', 'oyun konsolu', 'playstation', 'ps5', 'xbox', 'nintendo', ' switch', 'gitar', 'saz', 'keman', 'piyano', 'enstrüman', 'org', 'hobi', 'boyama'];
  for (const kw of kitapKeywords) {
    if (text.includes(kw)) return 'kitap_hobi';
  }
  
  return 'diger';
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
 * Mesajı Firebase'e kaydet
 */
async function saveDealToFirebase(message, chatInfo) {
  try {
    const messageText = message.message || '';
    // GÜNCELLEME: Tüm link kaynaklarını tara (Text, Entity, Button)
    const links = getAllLinks(message);

    if (!links.length) {
      console.log('ℹ️ Mesajda link bulunamadı (Metin veya Buton)');
      return false;
    }

    const mainLink = links[0];
    const messageId = message.id;
    const chatIdentifier = chatInfo.username ? `@${chatInfo.username}` : chatInfo.id.toString();
    const uniqueDocId = `telegram_${chatInfo.id}_${messageId}`;

    // Başlık ve açıklama
    const lines = messageText.split('\n').filter(l => l.trim());
    const title = lines[0] || 'Fırsat';

    // Fiyat
    const price = extractPrice(messageText);

    // ========================================
    // ÖNEMLİ: GÖRSELİ ÖNCE YÜKLEYECEĞİZ! 🎯
    // ========================================
    let imageUrl = ''; // Başlangıçta boş
    let aiAnalysis = null; // AI analizi sonucu (scope dışında tanımla!)

    // Görsel var mı kontrol et
    const hasPhoto = message.media && (
      message.media.photo ||
      (message.media.document && message.media.document.mimeType && message.media.document.mimeType.startsWith('image/'))
    );

    if (hasPhoto) {
      const mediaType = message.media.photo ? 'photo' : 'document';
      console.log(`📷 [${uniqueDocId}] GÖRSEL VAR! Tip: ${mediaType}`);
      console.log(`⚡ [${uniqueDocId}] ÖNCE GÖRSELI YÜKLEYECEĞİZ, SONRA DEAL OLUŞTURACAĞIZ!`);

      try {
        // GÖRSEL İNDİR
        console.log(`📥 [${uniqueDocId}] Telegram'dan görsel indiriliyor...`);
        const downloadStartTime = Date.now();
        const buffer = await client.downloadMedia(message.media, {
          workers: 4,
          progressCallback: (downloaded, total) => {
            const percent = Math.round((downloaded / total) * 100);
            if (percent % 25 === 0) {
              console.log(`📊 [${uniqueDocId}] İndirme: %${percent} (${downloaded}/${total})`);
            }
          }
        });
        const downloadTime = ((Date.now() - downloadStartTime) / 1000).toFixed(2);
        console.log(`✅ [${uniqueDocId}] Görsel indirildi! Süre: ${downloadTime}s, Boyut: ${buffer ? buffer.length : 0} bytes`);

        if (!buffer || buffer.length === 0) {
          console.error(`❌ [${uniqueDocId}] Buffer boş! Görsel indirilemedi.`);
        } else {
          // 🤖 AI ANALİZİ VE UPLOAD - TAM PARALEL! ⚡⚡⚡
          // GCP ortamından veya fallback olarak prod projesinden bucket adını oluştur
          const projectId = process.env.PROJECT_ID || process.env.GCP_PROJECT || process.env.GCLOUD_PROJECT || 'firsatkolik-prod-e6eae';
          const bucketName = `${projectId}.firebasestorage.app`;
          const bucket = admin.storage().bucket(bucketName);
          const filename = `deals/${chatInfo.id}_${messageId}.jpg`;
          const file = bucket.file(filename);

          console.log(`🚀 [${uniqueDocId}] AI analizi ve upload paralel başlıyor!`);
          const parallelStartTime = Date.now();

          // PARALEL: AI analizi + Upload
          const [aiResult, uploadResult] = await Promise.all([
            // AI Analizi
            analyzeImageWithGemini(buffer, messageText).catch(err => {
              console.error('❌ AI analiz hatası:', err.message);
              return null;
            }),
            // Upload
            (async () => {
              const uploadStartTime = Date.now();
              console.log(`📤 [${uniqueDocId}] Firebase Storage'a yükleniyor (${buffer.length} bytes)...`);
              await file.save(buffer, {
                metadata: {
                  contentType: 'image/jpeg',
                  cacheControl: 'public, max-age=31536000'
                },
                resumable: false,
                public: false
              });
              const uploadTime = ((Date.now() - uploadStartTime) / 1000).toFixed(2);
              console.log(`✅ [${uniqueDocId}] Storage'a yüklendi! Upload: ${uploadTime}s`);
              return uploadTime;
            })()
          ]);

          const parallelTime = ((Date.now() - parallelStartTime) / 1000).toFixed(2);
          const totalTime = ((Date.now() - downloadStartTime) / 1000).toFixed(2);
          console.log(`✅ [${uniqueDocId}] PARALEL İŞLEM TAMAM! AI+Upload: ${parallelTime}s, Toplam: ${totalTime}s`);

          // AI sonucunu kaydet
          aiAnalysis = aiResult;

          // imageUrl HAZIR!
          imageUrl = `https://firebasestorage.googleapis.com/v0/b/${bucketName}/o/${encodeURIComponent(filename)}?alt=media`;
          console.log(`🎉 [${uniqueDocId}] imageUrl HAZIR! ${imageUrl.substring(0, 80)}...`);

          if (aiAnalysis) {
            console.log(`✅ [${uniqueDocId}] AI analizi tamamlandı! Fiyat: ${aiAnalysis.fiyat}, Kategori: ${aiAnalysis.kategori}, Mağaza: ${aiAnalysis.magaza}`);
          } else {
            console.warn(`⚠️ [${uniqueDocId}] AI analizi başarısız, manuel veriler kullanılacak`);
          }
        }
      } catch (imageError) {
        console.error(`❌ [${uniqueDocId}] Görsel yükleme hatası:`, imageError.message);
      }
    } else {
      console.log(`ℹ️ [${uniqueDocId}] Mesajda görsel yok`);
    }

    // EĞER GÖRSEL ANALİZİ YOKSA VEYA BAŞARISIZSA METİN ANALİZİ YAP 📝
    if (!aiAnalysis) {
      console.log(`🤖 [${uniqueDocId}] Görsel analizi yok, metin analizi deneniyor...`);
      // Eğer mesaj çok kısaysa (sadece link vs) analiz etmeye değmeyebilir ama yine de deneyelim
      if (messageText && messageText.length > 5) {
        aiAnalysis = await analyzeTextWithGemini(messageText);
      }
    }

    // 🤖 AI VERİLERİNİ KULLAN! ✨

    // Kategori Mapping (AI Metni -> Uygulama ID'si)
    const categoryMap = {
      'Elektronik': 'elektronik',
      'Moda & Giyim': 'moda',
      'Ev, Yaşam & Ofis': 'ev_yasam',
      'Anne & Bebek': 'anne_bebek',
      'Kozmetik & Bakım': 'kozmetik',
      'Spor & Outdoor': 'spor_outdoor',
      'Süpermarket': 'supermarket',
      'Yapı Market & Oto': 'yapi_oto',
      'Kitap, Müzik & Hobi': 'kitap_hobi',
      'Diğer': 'diger'
    };

    const rawAiCategory = aiAnalysis?.kategori || 'Diğer';

    // Kategori eşleştirme - Daha esnek
    let mappedCategory = 'diger';

    // 1. Tam eşleşme
    if (categoryMap[rawAiCategory]) {
      mappedCategory = categoryMap[rawAiCategory];
    } else {
      // 2. İçeriyor mu? (Örn: "Elektronik Ürünler" -> "Elektronik")
      const rawLower = rawAiCategory.toLowerCase();
      // Tersine mapping yapıp kontrol et
      for (const [key, val] of Object.entries(categoryMap)) {
        // İlk kelimeyi al (noktalama işaretlerini temizle ve küçük harfe çevir)
        const firstWord = key.split(/[\s,&]+/)[0].toLowerCase();
        if (key !== 'Diğer' && rawLower.includes(firstWord)) {
          mappedCategory = val;
          break;
        }
      }
    }

    const aiPrice = aiAnalysis?.fiyat || price || 0;
    const rawTitle = aiAnalysis?.urun || title;
    const cleanedTitle = cleanFallbackTitle(rawTitle);

    // Fırsat Mağazası: Linkten otomatik çıkartılır
    const storeFromLink = extractStoreFromLink(mainLink, messageText);

    // Fırsat Kategorisi: Eğer yapay zeka bulamadıysa veya 'diger' ise yerel analizle tahmin et
    let finalCategory = mappedCategory;
    if (finalCategory === 'diger') {
      finalCategory = detectCategoryFromText(cleanedTitle, messageText);
    }

    // Deal objesi (GELİŞMİŞ VERİLERLE!)
    const deal = {
      title: cleanedTitle,
      description: messageText.substring(0, 2000),
      link: mainLink,
      price: aiPrice,
      originalPrice: aiPrice ? aiPrice * 1.2 : 0,
      discount: aiPrice ? 20 : 0,
      imageUrl: imageUrl, // ZATEN DOLU! 🎉
      store: storeFromLink,
      category: finalCategory, // ARTIK ID OLARAK KAYDEDİLİYOR! ✅
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
    console.log(`✅ Deal kaydedildi: ${uniqueDocId} (imageUrl: ${imageUrl ? 'DOLU ✅' : 'BOŞ ❌'})`);

    return true;
  } catch (error) {
    console.error('❌ Firebase kayıt hatası:', error.message);
    return false;
  }
}

/**
 * Telegram Client'ı başlat
 */
async function startBot() {
  if (isRunning || isStarting) {
    console.log('⚠️ Bot zaten çalışıyor veya başlatılıyor!');
    return;
  }

  isStarting = true;
  try {
    console.log('🔄 Telegram Client bağlanıyor...');

    // ESKİ CLIENT'I TAMAMEN TEMİZLE! ⚡
    if (client) {
      try {
        console.log('🧹 Eski client temizleniyor...');
        // Tüm event handler'ları kaldır
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
      connectionRetries: 100, // Daha fazla deneme
      autoReconnect: true,
      useWSS: false,
      timeout: 60, // 60 saniye timeout (önceden 30)
      requestRetries: 10, // Request retry sayısı
      floodSleepThreshold: 60, // Flood wait süresini otomatik bekle (60 saniye)
      deviceModel: 'Cloud Run Bot',
      systemVersion: '1.0',
      appVersion: '1.0',
    });

    // Bağlantı koptuğunda logla
    client.on('disconnected', () => {
      console.warn('⚠️ Telegram bağlantısı koptu!');
      isRunning = false;
    });

    await client.connect();
    console.log('✅ Telegram Client bağlandı!');

    // Her kanal için event handler ekle
    for (const channelUsername of CHANNELS) {
      try {
        const trimmedChannel = channelUsername.trim();
        let channel;

        // Username ile mi yoksa ID ile mi?
        if (trimmedChannel.startsWith('@')) {
          // Public kanal - username ile
          console.log(`🔍 Username ile aranıyor: ${trimmedChannel}`);
          channel = await client.getEntity(trimmedChannel);
        } else {
          // Private kanal/grup - ID ile
          console.log(`🔍 ID ile aranıyor: ${trimmedChannel}`);

          // Negatif ID'yi pozitife çevir
          const channelId = trimmedChannel.startsWith('-')
            ? trimmedChannel.substring(1)
            : trimmedChannel;

          // PeerChannel ile dene
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
              console.error(`   Hata: ${e2.message}`);
              continue;
            }
          }
        }

        console.log(`✅ Kanal bulundu: ${channel.title} (${trimmedChannel})`);

        // Kanal bilgilerini sakla (closure için)
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
          const messageText = message.message || '';
          
          // Link kontrolü
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
