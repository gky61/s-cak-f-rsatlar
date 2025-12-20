import 'dart:convert';
import 'package:http/http.dart' as http;

/// Gemini AI servisi - Ürün kategori ve fiyat tespiti
class AIService {
  static const String _apiKey = 'AIzaSyBFdum6TOlRpMKmOop1pcqBymDopSfZDgM';
  static const String _baseUrl = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent';

  /// Ürün linkinden kategori ve fiyat bilgilerini AI ile tespit et
  static Future<Map<String, dynamic>> analyzeProduct({
    required String url,
    String? title,
    String? description,
  }) async {
    try {
      final prompt = '''
Sen uzman bir e-ticaret asistanısın. Aşağıdaki ürün bilgilerini analiz et.
Bana SADECE geçerli bir JSON objesi döndür. Başka hiçbir metin yazma.

Görevlerin:
1. Ürün adını temizle (reklam, emoji ve gereksiz kelimeleri at).
2. Fiyatları bul:
   - Güncel Fiyat (price): İndirimli, ödenecek son tutar.
   - Eski Fiyat (original_price): Üstü çizili, "önceki fiyat" veya piyasa fiyatı. (Yoksa 0 yaz).
   
   DİKKAT:
   - "X TL x 3 ay" gibi taksit tutarlarını ASLA fiyat olarak alma.
   - Yüzdelik indirim oranlarını (örn: %57) fiyat sanma.
   - Eğer "Sepette X TL" diyorsa, o düşük fiyatı 'price' olarak al.
   
3. Mağazayı bul (Linkten veya metinden).
4. Kategoriyi belirle. Aşağıdaki listeden EN UYGUN olanı seç (ZORUNLU):
   ['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 'spor_outdoor', 'kitap_hobi', 'yapi_oto', 'supermarket']
   
   ÖNEMLİ KATEGORİ KURALLARI:
   - 📱 'elektronik': Telefon, tablet, laptop, bilgisayar, TV, beyaz eşya, küçük ev aletleri, kulaklık, akıllı saat, konsol, oyun, kamera, drone, vantilatör, airfryer (TÜM ELEKTRONİK ÜRÜNLER).
   - 👕 'moda': Kıyafet, ayakkabı, çanta, saat, gözlük, aksesuar, takı, bot, terlik, mont, kazak.
   - 🏠 'ev_yasam': Mobilya, ev tekstili, mutfak gereçleri, aydınlatma, dekorasyon, kırtasiye.
   - 👶 'anne_bebek': Bebek bezi, mama, biberon, emzik, bebek arabası, oto koltuğu, bebek/çocuk oyuncakları, "Baby" geçen ürünler.
   - 💄 'kozmetik': Krem, şampuan, parfüm, makyaj, tıraş, epilasyon, diş bakımı, cilt bakımı, saç bakımı.
   - ⛺ 'spor_outdoor': Kamp malzemesi, spor aleti, bisiklet, fitness ekipmanları, yoga matı, dambıl, termos.
   - 📚 'kitap_hobi': Kitap, roman, dergi, kırtasiye malzemeleri, müzik enstrümanları, sanat malzemeleri, puzzle, kutu oyunu.
   - 🚗 'yapi_oto': Oto lastik, motor yağı, araç aksesuarları, matkap, tornavida, elektrik malzemeleri, bahçe aletleri, banyo/tesisat.
   - 🛒 'supermarket': Gıda, deterjan, temizlik ürünleri, kağıt ürünleri, yiyecek, içecek, kedi/köpek maması, kedi kumu.

İPUCU: 
- "Vantilatör", "Airfryer", "Kahve Makinesi" gibi küçük ev aletleri = 'elektronik'
- Ürün adında "Baby", "Bebek", "Çocuk" geçiyorsa öncelikli olarak 'anne_bebek'

Girdi URL: $url
${title != null ? 'Başlık: $title' : ''}
${description != null ? 'Açıklama: $description' : ''}

İstenen JSON Formatı:
{
  "title": "Temizlenmiş Ürün Adı",
  "price": 1234.50,
  "original_price": 1500.00,
  "store": "Mağaza Adı",
  "category": "kategori_kodu",
  "confidence": "high"
}
''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.2,
            'maxOutputTokens': 1024,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'] ?? '';
        
        // JSON temizleme
        final cleanText = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        
        final result = jsonDecode(cleanText);
        print('🤖 AI Analiz Sonucu: $result');
        
        return {
          'success': true,
          'title': result['title'] ?? '',
          'price': (result['price'] ?? 0.0).toDouble(),
          'originalPrice': (result['original_price'] ?? 0.0).toDouble(),
          'store': result['store'] ?? '',
          'category': result['category'] ?? 'elektronik',
          'confidence': result['confidence'] ?? 'medium',
        };
      } else {
        print('❌ AI API Hatası: ${response.statusCode}');
        return {'success': false, 'error': 'API hatası: ${response.statusCode}'};
      }
    } catch (e) {
      print('❌ AI Analiz Hatası: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  /// Sadece kategori tespiti yap (daha hızlı)
  static Future<String?> detectCategory(String text) async {
    try {
      final prompt = '''
Aşağıdaki ürün adından kategoriyi tespit et. SADECE kategori kodunu yaz, başka hiçbir şey yazma.

Kategoriler: elektronik, moda, ev_yasam, anne_bebek, kozmetik, spor_outdoor, kitap_hobi, yapi_oto, supermarket

KURALLAR:
- Telefon, laptop, TV, kulaklık, vantilatör, airfryer, konsol → elektronik
- Kıyafet, ayakkabı, çanta → moda
- Mobilya, mutfak, dekorasyon → ev_yasam
- Bebek ürünleri, oyuncak → anne_bebek
- Krem, şampuan, makyaj → kozmetik
- Spor aleti, kamp malzemesi → spor_outdoor
- Kitap, müzik enstrümanı → kitap_hobi
- Oto, hırdavat, elektrik → yapi_oto
- Gıda, deterjan, temizlik → supermarket

Ürün: $text

Cevap (sadece kategori kodu):''';

      final response = await http.post(
        Uri.parse('$_baseUrl?key=$_apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 50,
          }
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final category = data['candidates']?[0]?['content']?['parts']?[0]?['text']?.trim() ?? '';
        print('🤖 AI Kategori: $category');
        return category;
      }
      return null;
    } catch (e) {
      print('❌ Kategori tespit hatası: $e');
      return null;
    }
  }
}


