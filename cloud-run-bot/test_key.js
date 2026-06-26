const admin = require('firebase-admin');

const credPath = "/Users/gokayalemdar/Desktop/SICAK FIRSATLAR/firebase_key.json";
if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(credPath)
  });
}
const db = admin.firestore();

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
  const supermarketKeywords = ['deterjan', 'yumuşatıcı', 'şampuan', 'sabun', 'ıslak mendil', 'tuvalet kağıdı', 'kağıt havlu', 'deterjanı', 'omo', 'ariel', 'domestos', 'fairy', 'finish', 'gıda', 'yağ', 'zeytinyağı', 'sıvı yağ', 'pirinç', 'makarna', 'çay', 'kahve', 'şeker', 'tuz', 'çikolata', 'bisküvi', 'atıştırmalık', 'peynir', 'zeytin', 'süt', 'salça', 'un'];
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

async function run() {
  const snapshot = await db.collection('deals').get();
  console.log(`Veritabanındaki ${snapshot.docs.length} eski fırsat taranıyor...`);
  
  const batch = db.batch();
  let count = 0;
  
  snapshot.docs.forEach(doc => {
    const data = doc.data();
    const link = data.link;
    const title = data.title;
    const desc = data.description || data.rawMessage || '';
    
    const store = extractStoreFromLink(link, desc);
    let category = data.category;
    if (!category || category === 'diger') {
      category = detectCategoryFromText(title, desc);
    }
    
    if (data.store !== store || data.category !== category) {
      const ref = db.collection('deals').doc(doc.id);
      batch.update(ref, { store, category });
      console.log(`Güncelleniyor [ID: ${doc.id}]:`);
      console.log(`  Mağaza:   "${data.store}" -> "${store}"`);
      console.log(`  Kategori: "${data.category}" -> "${category}"`);
      count++;
    }
  });
  
  if (count > 0) {
    await batch.commit();
    console.log(`✅ ${count} eski fırsat başarıyla güncellendi!`);
  } else {
    console.log('Güncelleme gerekmiyor, tüm veriler güncel.');
  }
  
  process.exit(0);
}

run().catch(err => {
  console.error(err);
  process.exit(1);
});
