import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/content_moderation_service.dart';

void main() {
  group('ContentModerationService Tests', () {
    test('Meşru e-ticaret ve günlük ürün başlıkları asla küfür olarak algılanmamalı', () {
      final safeTitles = [
        'Şık Bayan Elbise S Beden',
        'Taze Kaşar Peyniri 500g',
        'Eski Kaşar Peyniri 250g',
        'Dik Süpürge 1200W Şarjlı',
        'Cif Krem Temizleyici 750ml',
        'ASUS B550 Oyuncu Anakart',
        'Buharlı Kazanlı Ütü 2400W',
        'İzmir Bombası Çikolatalı Tatlı',
        'Medikal Basur Krem 50ml',
        'Manyak İndirimli Akıllı Telefon',
        'Bebek Ana Kucağı Kırmızı',
        'İthal Kakao Tozu 100g',
      ];

      for (final title in safeTitles) {
        final result = ContentModerationService.moderateContent(
          title: title,
          description: 'Geniş ürün açıklaması ve kampanya detayı.',
        );
        expect(result.isSafe, isTrue, reason: 'Ürün başlığı yanlışlıkla engellendi: "$title"');
      }
    });

    test('Gerçek ve net ağır küfürler başarıyla engellenmeli', () {
      final unsafeTexts = [
        'Bu ne amk ya',
        'Böyle orospu çocuğu bir satıcı görmedim',
        'Siktir git buradan pezevenk',
        'Tam bir yavşak ve gavat',
      ];

      for (final text in unsafeTexts) {
        final result = ContentModerationService.moderateComment(text);
        expect(result.isSafe, isFalse, reason: 'Gerçek küfür tespit edilemedi: "$text"');
      }
    });
  });
}
