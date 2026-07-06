import 'dart:convert';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:http/http.dart' as http;
import 'package:firebase_app_check/firebase_app_check.dart';
import '../firebase_options.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

/// Gemini AI Proxy servisi - Ürün kategori ve fiyat tespiti
class AIService {
  static String get _proxyUrl {
    final projectId = DefaultFirebaseOptions.flavorProjectId;
    return 'https://us-central1-$projectId.cloudfunctions.net/analyzeProductProxy';
  }

  
  static Future<Map<String, String>> _getHeaders() async {
    String? token;
    try {
      token = await FirebaseAppCheck.instance.getToken();
    } catch (e) {
      _log('⚠️ App Check token alınamadı: $e');
    }
    return {
      'Content-Type': 'application/json',
      if (token != null) 'X-Firebase-AppCheck': token,
    };
  }
  
  /// API bağlantısını test et (proxy üzerinden)
  static Future<bool> testConnection() async {
    try {
      final endpoint = _proxyUrl;
      _log('🔄 Test ediliyor: $endpoint');
      final headers = await _getHeaders();
      
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers,
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Test mesajı. Sadece "OK" yaz.'}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.1,
            'maxOutputTokens': 10,
          }
        }),
      ).timeout(const Duration(seconds: 10));
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == false) {
          _log('❌ API Test Hatası: ${data['error']}');
          return false;
        }
        _log('✅ Gemini API Proxy bağlantısı başarılı');
        return true;
      } else {
        _log('❌ API Test Hatası (${response.statusCode}): $endpoint');
        return false;
      }
    } catch (e) {
      _log('❌ API Test Exception: $e');
      return false;
    }
  }

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

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(_proxyUrl),
        headers: headers,
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
        
        if (data['success'] == false) {
          final errorMsg = data['error'] ?? 'Bilinmeyen proxy hatası';
          _log('❌ AI API Error Response: $errorMsg');
          return {'success': false, 'error': errorMsg};
        }
        
        final text = data['text'] ?? '';
        
        if (text.isEmpty) {
          _log('❌ AI API: Boş yanıt');
          return {'success': false, 'error': 'AI boş yanıt döndürdü'};
        }
        
        final cleanText = text
            .replaceAll('```json', '')
            .replaceAll('```', '')
            .trim();
        
        try {
          final result = jsonDecode(cleanText);
          _log('🤖 AI Analiz Sonucu: $result');
          
          return {
            'success': true,
            'title': result['title'] ?? '',
            'price': (result['price'] ?? 0.0).toDouble(),
            'originalPrice': (result['original_price'] ?? 0.0).toDouble(),
            'store': result['store'] ?? '',
            'category': result['category'] ?? 'elektronik',
            'confidence': result['confidence'] ?? 'medium',
          };
        } catch (jsonError) {
          _log('❌ AI JSON Parse Hatası: $jsonError');
          _log('❌ AI Ham Yanıt: $cleanText');
          return {'success': false, 'error': 'AI yanıtı parse edilemedi: $jsonError'};
        }
      } else {
        String errorMessage = 'API hatası: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData['error'] != null) {
            errorMessage = errorData['error'] ?? errorMessage;
          }
        } catch (_) {}
        
        _log('❌ AI API Hatası: ${response.statusCode} - $errorMessage');
        return {'success': false, 'error': errorMessage};
      }
    } catch (e) {
      _log('❌ AI Analiz Hatası: $e');
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

      final headers = await _getHeaders();
      final response = await http.post(
        Uri.parse(_proxyUrl),
        headers: headers,
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
        
        if (data['success'] == false) {
          _log('❌ AI Kategori Tespit Hatası: ${data['error']}');
          return null;
        }
        
        final category = data['text']?.trim() ?? '';
        _log('🤖 AI Kategori: $category');
        return category.isNotEmpty ? category : null;
      } else {
        _log('❌ AI Kategori API Hatası: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      _log('❌ Kategori tespit hatası: $e');
      return null;
    }
  }
}
