import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/utils/deal_url_detector.dart';

void main() {
  group('DealUrlDetector Testleri', () {
    test('Paylaşılan metinden e-ticaret URL ayıklama (extractUrl)', () {
      // Trendyol metni
      const tyText = 'Harika indirim var, bu ürünü kaçırma: https://ty.gl/abc123xyz mutlaka bak!';
      expect(DealUrlDetector.extractUrl(tyText), 'https://ty.gl/abc123xyz');

      // Hepsiburada metni ve sonundaki nokta temizliği
      const hbText = 'Hepsiburada üzerinden buldum: https://app.hb.biz/xyz456.';
      expect(DealUrlDetector.extractUrl(hbText), 'https://app.hb.biz/xyz456');

      // Amazon metni
      const amznText = 'Amazon Fırsatı: https://amzn.eu/d/1a2b3c';
      expect(DealUrlDetector.extractUrl(amznText), 'https://amzn.eu/d/1a2b3c');

      // Mavi Standart HTTP/HTTPS URL Paylaşımı
      const maviUrl = 'https://www.mavi.com/mavi-logo-baskili-mavi-gomlek/p/0212124-70804';
      expect(DealUrlDetector.extractUrl(maviUrl), maviUrl);

      // Mavi Metin İçerisinde Paylaşım
      const maviInText = 'Mavi gömlek fırsatı: https://www.mavi.com/mavi-logo-baskili-mavi-gomlek/p/0212124-70804 mutlaka bak!';
      expect(DealUrlDetector.extractUrl(maviInText), maviUrl);

      // Boyner Standart HTTP/HTTPS URL Paylaşımı
      const boynerUrl = 'https://www.boyner.com.tr/patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996';
      expect(DealUrlDetector.extractUrl(boynerUrl), boynerUrl);

      // Boyner Metin İçerisinde ve Noktalama İşaretli Paylaşım
      const boynerInText = 'Boyner indiriminde buldum: https://www.boyner.com.tr/patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996.';
      expect(DealUrlDetector.extractUrl(boynerInText), boynerUrl);

      // Şemasız Mağaza Alan Adı (www. veya çıplak domain)
      const bareMavi = 'www.mavi.com/mavi-logo-baskili-mavi-gomlek/p/0212124-70804';
      expect(
        DealUrlDetector.extractUrl(bareMavi),
        'https://www.mavi.com/mavi-logo-baskili-mavi-gomlek/p/0212124-70804',
      );

      const bareBoyner = 'boyner.com.tr/patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996';
      expect(
        DealUrlDetector.extractUrl(bareBoyner),
        'https://boyner.com.tr/patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996',
      );

      // Şemasız subdomain kısa linkleri (app.hb.biz, sl.n11.com, pzrm.me)
      expect(DealUrlDetector.extractUrl('app.hb.biz/xyz456'), 'https://app.hb.biz/xyz456');
      expect(DealUrlDetector.extractUrl('sl.n11.com/n/abc123'), 'https://sl.n11.com/n/abc123');
      expect(DealUrlDetector.extractUrl('pzrm.me/item123'), 'https://pzrm.me/item123');

      // Link içermeyen veya düz yazı metinler (artık URL olarak kabul EDİLMEMELİDİR)
      expect(DealUrlDetector.extractUrl('Bugün hava çok güzel hiçbir link yok.'), isNull);
      expect(DealUrlDetector.extractUrl('/mavi-logo-baskili-mavi-gomlek/p/0212124-70804'), isNull);
      expect(DealUrlDetector.extractUrl('mavi-logo-baskili-mavi-gomlek/p/0212124-70804'), isNull);
      expect(DealUrlDetector.extractUrl('patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996'), isNull);
      expect(DealUrlDetector.extractUrl('/patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996'), isNull);
      expect(DealUrlDetector.extractUrl('Bugün p/ahmet ile buluştuk.'), isNull);
      expect(DealUrlDetector.extractUrl('Toplantı notları 3/p/5 maddesi.'), isNull);
      expect(DealUrlDetector.extractUrl('Sadece rastgele kelime-p-abc.'), isNull);
    });

    test('21+ E-ticaret mağaza tespiti (detectStoreName)', () {
      expect(DealUrlDetector.detectStoreName('https://ty.gl/abc123xyz'), 'Trendyol');
      expect(DealUrlDetector.detectStoreName('https://www.trendyol.com/kadin-elbise-p-123'), 'Trendyol');
      expect(DealUrlDetector.detectStoreName('https://app.hb.biz/xyz456'), 'Hepsiburada');
      expect(DealUrlDetector.detectStoreName('https://www.hepsiburada.com/apple-iphone-15-pm-123'), 'Hepsiburada');
      expect(DealUrlDetector.detectStoreName('https://www.amazon.com.tr/dp/B07X12345'), 'Amazon');
      expect(DealUrlDetector.detectStoreName('https://amzn.to/3abcdef'), 'Amazon');
      expect(DealUrlDetector.detectStoreName('https://www.teknosa.com/apple-iphone-15-p-123'), 'Teknosa');
      expect(DealUrlDetector.detectStoreName('https://www.n11.com/urun/samsung-galaxy-123'), 'N11');
      expect(DealUrlDetector.detectStoreName('https://sl.n11.com/n/abc123'), 'N11');
      expect(DealUrlDetector.detectStoreName('https://www.pazarama.com/laptop-p-123'), 'Pazarama');
      expect(DealUrlDetector.detectStoreName('https://pzrm.me/item123'), 'Pazarama');
      expect(DealUrlDetector.detectStoreName('https://www.idefix.com/kitap-p-123'), 'İdefix');
      expect(DealUrlDetector.detectStoreName('https://www.vatanbilgisayar.com/asus-rog-laptop.html'), 'Vatan Bilgisayar');
      expect(DealUrlDetector.detectStoreName('https://www.mediamarkt.com.tr/tr/product/123.html'), 'MediaMarkt');
      expect(DealUrlDetector.detectStoreName('https://www.itopya.com/hazir-sistemler/'), 'İtopya');
      expect(DealUrlDetector.detectStoreName('https://www.zara.com/tr/tr/gomlek-p123.html'), 'Zara');
      expect(DealUrlDetector.detectStoreName('https://www.boyner.com.tr/ayakkabi-c-123'), 'Boyner');
      expect(DealUrlDetector.detectStoreName('https://www.mavi.com/p/0212124-70804'), 'Mavi');
      expect(DealUrlDetector.detectStoreName('https://fenom.io/amzn-vd612'), 'Amazon');

      // Düz yazı veya göreli yollar artık mağaza olarak tespit EDİLMEMELİDİR (Link değiller)
      expect(DealUrlDetector.detectStoreName('/mavi-logo-baskili-mavi-gomlek/p/0212124-70804'), isNull);
      expect(DealUrlDetector.detectStoreName('patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996'), isNull);

      // Desteklenmeyen / Alakasız link
      expect(DealUrlDetector.detectStoreName('https://google.com/search?q=test'), isNull);
      expect(DealUrlDetector.detectStoreName('https://wikipedia.org/wiki/Turkey'), isNull);
    });

    test('Desteklenen e-ticaret kontrolü (isSupportedEcommerceUrl)', () {
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://ty.gl/123'), isTrue);
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://app.hb.biz/456'), isTrue);
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://pzrm.me/item123'), isTrue);
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://sl.n11.com/n/123'), isTrue);
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://www.mavi.com/mavi-logo-baskili-mavi-gomlek/p/0212124-70804'), isTrue);
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://www.boyner.com.tr/patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996'), isTrue);
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://fenom.io/amzn-vd612'), isTrue);

      // Düz yazı / göreli yollar artık e-ticaret URL'si değildir
      expect(DealUrlDetector.isSupportedEcommerceUrl('/mavi-logo-baskili-mavi-gomlek/p/0212124-70804'), isFalse);
      expect(DealUrlDetector.isSupportedEcommerceUrl('patrizia-pepe-ekru-kadin-deri-loafer-8z0137-p-15871996'), isFalse);
      expect(DealUrlDetector.isSupportedEcommerceUrl('https://google.com'), isFalse);
    });
  });
}
