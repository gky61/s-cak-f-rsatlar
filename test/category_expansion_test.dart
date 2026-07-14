import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/category_detection_service.dart';

void main() {
  group('Category Detection Service Expansion Tests', () {
    void verifyMapping(String text, String expectedCategoryId, String expectedSubCategory) {
      final result = CategoryDetectionService.detectCategory(text);
      expect(result, isNotNull, reason: 'Failed to detect category for: "$text"');
      expect(result!['categoryId'], expectedCategoryId, reason: 'Wrong category ID for: "$text"');
      expect(result['subCategory'], expectedSubCategory, reason: 'Wrong subcategory for: "$text"');
    }

    test('1. Dijital & Hizmetler Mappings', () {
      verifyMapping('Netflix 3 Aylık Hediye Kartı Abonelik', 'dijital_hizmetler', 'Abonelik & Yazılım');
      verifyMapping('Spotify Premium Aile Paketi İndirimi', 'dijital_hizmetler', 'Abonelik & Yazılım');
      verifyMapping('ExpressVPN 1 Yıllık Yazılım Lisans Key', 'dijital_hizmetler', 'Abonelik & Yazılım');
      
      verifyMapping('Yemeksepeti Restoran Burger King Fırsatı', 'dijital_hizmetler', 'Yemek & Restoran');
      verifyMapping('Getiryemek 1 alana 1 bedava pizza menüsü', 'dijital_hizmetler', 'Yemek & Restoran');
      verifyMapping('Starbucks Kahve Dünyası Fırsat Menü', 'dijital_hizmetler', 'Yemek & Restoran');
      
      verifyMapping('Pegasus Uçak Bileti Kampanyası Thy Yurtdışı', 'dijital_hizmetler', 'Seyahat & Eğlence');
      verifyMapping('Antalya Jolly Tur Otel Rezervasyon Fırsatı', 'dijital_hizmetler', 'Seyahat & Eğlence');
      verifyMapping('Biletix Konser ve Sinema Bileti İndirimi', 'dijital_hizmetler', 'Seyahat & Eğlence');
      
      verifyMapping('Steam 100 TL Cüzdan Kodu Epin', 'dijital_hizmetler', 'Dijital Kod & Oyun Pinleri');
      verifyMapping('Valorant 2200 VP Points Satın Al', 'dijital_hizmetler', 'Dijital Kod & Oyun Pinleri');
      verifyMapping('Xbox Game Pass Ultimate Kod', 'dijital_hizmetler', 'Dijital Kod & Oyun Pinleri');
    });

    test('2. Finans & Kampanyalar Mappings', () {
      verifyMapping('Akbank Axess Kredi Kartı 200 TL Chip-Para', 'finans_kampanyalar', 'Banka Kampanyaları');
      verifyMapping('Nays ile Kampanya %10 Cashback Hediye Para', 'finans_kampanyalar', 'Banka Kampanyaları');
      verifyMapping('Garanti Bonus Fırsat Kampanyası Taksit', 'finans_kampanyalar', 'Banka Kampanyaları');
      verifyMapping('Faizsiz Masrafsız Nakit Avans Kampanyası', 'finans_kampanyalar', 'Banka Kampanyaları');
      
      verifyMapping('24 Ayar Has Külçe Altın Sarrafiye', 'finans_kampanyalar', 'Yatırım & Değerli Metaller');
      verifyMapping('Yeni Tarihli Ata Çeyrek Altın Ziynet', 'finans_kampanyalar', 'Yatırım & Değerli Metaller');
      verifyMapping('1 Gram Altın Harem Altın 22 Ayar', 'finans_kampanyalar', 'Yatırım & Değerli Metaller');
      verifyMapping('Külçe Gümüş 1000 Gr Yatırım', 'finans_kampanyalar', 'Yatırım & Değerli Metaller');
    });

    test('3. New Subcategories & Updated Keywords Mappings', () {
      // Smart Home (Elektronik -> Akıllı Ev & Güvenlik)
      verifyMapping('Xiaomi Akıllı Priz Smart Home', 'elektronik', 'Akıllı Ev & Güvenlik');
      verifyMapping('TP-Link Tapo Akıllı Ampul Lamba', 'elektronik', 'Akıllı Ev & Güvenlik');
      verifyMapping('Tapo IP Güvenlik Kamerası Gece Görüşlü', 'elektronik', 'Akıllı Ev & Güvenlik');
      
      // Personal Care Electronics (Elektronik -> Beyaz Eşya & Küçük Ev Aletleri)
      verifyMapping('Braun Tıraş Makinesi Islak Kuru Şarjlı', 'elektronik', 'Beyaz Eşya & Küçük Ev Aletleri');
      verifyMapping('Philips Lumea Epilatör Epilasyon Cihazı', 'elektronik', 'Beyaz Eşya & Küçük Ev Aletleri');
      verifyMapping('Dyson Airwrap Saç Şekillendirici Fön Makinesi', 'elektronik', 'Beyaz Eşya & Küçük Ev Aletleri');
      
      // Sports (Spor & Outdoor -> Bireysel & Takım Sporları)
      verifyMapping('Nike Futbol Topu Halı Saha Uyumlu', 'spor_outdoor', 'Bireysel & Takım Sporları');
      verifyMapping('Adidas Basketbol Topu Deri No 7', 'spor_outdoor', 'Bireysel & Takım Sporları');
      verifyMapping('Arena Yüzme Gözlüğü Buğu Yapmaz Bone', 'spor_outdoor', 'Bireysel & Takım Sporları');
      
      // Paint/Building (Yapı Market & Oto -> Banyo, Tesisat & Yapı)
      verifyMapping('Filli Boya Silikonlu İç Cephe Boyası 15 L', 'yapi_oto', 'Banyo, Tesisat & Yapı');
      verifyMapping('Kalekim Derz Dolgu 5 Kg Beyaz', 'yapi_oto', 'Banyo, Tesisat & Yapı');
      verifyMapping('Sprey Boya Siyah Mat Akrilik', 'yapi_oto', 'Banyo, Tesisat & Yapı');
      
      // Work Safety (Yapı Market & Oto -> Elektrikli Aletler, Hırdavat & İş Güvenliği)
      verifyMapping('İş Eldiveni Nitril Kaplı 12li Paket', 'yapi_oto', 'Elektrikli Aletler, Hırdavat & İş Güvenliği');
      verifyMapping('3M Koruyucu Gözlük İş Güvenliği bareti', 'yapi_oto', 'Elektrikli Aletler, Hırdavat & İş Güvenliği');
      
      // Board Games / Toys (Kitap, Müzik & Hobi -> Kutu Oyunları & Oyuncaklar)
      verifyMapping('Lego Star Wars Millennium Falcon Seti', 'kitap_hobi', 'Kutu Oyunları & Oyuncaklar');
      verifyMapping('Monopoly Türkiye Kutu Oyunu Board Game', 'kitap_hobi', 'Kutu Oyunları & Oyuncaklar');
      verifyMapping('Tabu Kelime Tahmin Oyunu Hasbro', 'kitap_hobi', 'Kutu Oyunları & Oyuncaklar');
    });

    test('4. Cross-Category / Negative Exclusions Mappings', () {
      // Gold Jewelry (Moda -> Saat, Aksesuar & Takı) vs Investment Gold (Finans -> Yatırım & Değerli Metaller)
      verifyMapping('14 Ayar Altın Kolye Zincir Uçlu', 'moda', 'Saat, Aksesuar & Takı');
      verifyMapping('925 Ayar Gümüş Kadın Bileklik Zincir', 'moda', 'Saat, Aksesuar & Takı');
      verifyMapping('Tektaş Pırlanta Altın Yüzük Evlilik', 'moda', 'Saat, Aksesuar & Takı');
      
      verifyMapping('24 Ayar Gram Altın Has Külçe', 'finans_kampanyalar', 'Yatırım & Değerli Metaller');
      verifyMapping('Yeni Tarihli Çeyrek Altın Sarrafiye', 'finans_kampanyalar', 'Yatırım & Değerli Metaller');
      
      // Baby Shampoo (Kozmetik) vs Baby Diapers (Anne Bebek) vs Baby Detergent (Supermarket)
      verifyMapping('Uni Baby Bebek Şampuanı Göz Yakmaz', 'kozmetik', 'Saç Bakımı');
      verifyMapping('Dalin Bebek Yağı Nemlendirici Krem', 'kozmetik', 'Cilt & Yüz Bakımı');
      
      verifyMapping('Prima Aktif Bebek Bezi Fırsat Paketi', 'anne_bebek', 'Bebek Bezi & Islak Mendil');
      
      verifyMapping('Sleepy Bebek Deterjanı Sıvı 1500 ml', 'supermarket', 'Deterjan & Temizlik');

      // Lego (Kitap & Hobi) vs Duplo (Anne Bebek) vs Adult Toys/Puzzles (Kitap & Hobi)
      verifyMapping('Lego Technic Bugatti Chiron Yetişkin Seti', 'kitap_hobi', 'Kutu Oyunları & Oyuncaklar');
      verifyMapping('Lego Duplo İlk Yapım Parçalarım Bebek Oyuncağı', 'kitap_hobi', 'Kutu Oyunları & Oyuncaklar');
      verifyMapping('1000 Parça Yetişkin Puzzle Manzara Yapboz Maketi', 'kitap_hobi', 'Kutu Oyunları & Oyuncaklar');
      verifyMapping('18+ Koleksiyonluk Model Kit Araba Maketi', 'kitap_hobi', 'Hobi & Sanat Malzemeleri');

      // Gendered pajamas (Erkek Giyim vs Kadın Giyim)
      verifyMapping('Koza İç Giyim Erkek Pijama Takımı', 'moda', 'Erkek Giyim');
      verifyMapping('Kadın Pamuklu Pijama Takımı', 'moda', 'Kadın Giyim');
    });

    test('5. Thermos Mappings', () {
      verifyMapping('Schafer Kitchen House 2 Litre Çelik Termos Inox (Sıcak ve Soğuk İçecekler İçin 12 Saat Koruma)', 'ev_yasam', 'Mutfak Gereçleri');
      verifyMapping('Stanley Klasik Vakumlu Çelik Kamp Termosu 1 L', 'spor_outdoor', 'Kamp & Doğa Malzemeleri');
    });
  });
}
