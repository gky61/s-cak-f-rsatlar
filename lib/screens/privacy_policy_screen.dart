import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';
import '../services/theme_service.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeService = ThemeService();
    
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: AppBar(
        title: const Text(
          'Gizlilik Politikası',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: isDark ? Colors.white : AppTheme.textPrimary,
        elevation: 0,
        iconTheme: IconThemeData(
          color: isDark ? Colors.white : AppTheme.textPrimary,
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              context,
              'Gizlilik Politikası',
              'Bu gizlilik politikası, Gökay Alemdar (bundan böyle "Hizmet Sağlayıcı" olarak anılacaktır) tarafından mobil cihazlar için oluşturulan FIRSAT KOLİK uygulaması (bundan böyle "Uygulama" olarak anılacaktır) için geçerlidir. Bu hizmet "OLDUĞU GİBİ" kullanım için tasarlanmış Ücretsiz bir hizmettir.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Bilgi Toplama ve Kullanım',
              'Uygulama, indirdiğinizde ve kullandığınızda bilgi toplar. Bu bilgiler şunları içerebilir:',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildBulletPoint(context, 'Cihazınızın İnternet Protokol adresi (örn. IP adresi)', isDark),
            _buildBulletPoint(context, 'Ziyaret ettiğiniz uygulama sayfaları, ziyaret zamanı ve tarihi, bu sayfalarda geçirdiğiniz süre', isDark),
            _buildBulletPoint(context, 'Uygulamada geçirdiğiniz süre', isDark),
            _buildBulletPoint(context, 'Mobil cihazınızda kullandığınız işletim sistemi', isDark),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Üçüncü Taraf Erişimi',
              'Hizmet Sağlayıcı\'nın uygulamayı ve hizmetlerini iyileştirmesine yardımcı olmak için yalnızca toplu, anonimleştirilmiş veriler periyodik olarak harici hizmetlere iletilir. Hizmet Sağlayıcı, bilgilerinizi bu gizlilik beyanında açıklandığı şekilde üçüncü taraflarla paylaşabilir.',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildText(
              context,
              'Lütfen Uygulamanın, verileri işleme konusunda kendi Gizlilik Politikalarına sahip üçüncü taraf hizmetler kullandığını unutmayın. Aşağıda, Uygulama tarafından kullanılan üçüncü taraf hizmet sağlayıcıların Gizlilik Politikalarına bağlantılar bulunmaktadır:',
              isDark,
            ),
            const SizedBox(height: 12),
            _buildLink(context, 'Google Play Services', 'https://www.google.com/policies/privacy/', isDark),
            _buildLink(context, 'AdMob', 'https://support.google.com/admob/answer/6128543?hl=en', isDark),
            _buildLink(context, 'Google Analytics for Firebase', 'https://firebase.google.com/support/privacy', isDark),
            _buildLink(context, 'Firebase Crashlytics', 'https://firebase.google.com/support/privacy/', isDark),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Yapay Zeka Kullanımı',
              'Uygulama, kullanıcı deneyimini geliştirmek ve belirli özellikler sağlamak için Yapay Zeka (AI) teknolojileri kullanır. AI bileşenleri, kişiselleştirilmiş içerik, öneriler veya otomatik işlevler sunmak için kullanıcı verilerini işleyebilir. Tüm AI işleme, bu gizlilik politikası ve geçerli yasalar uyarınca gerçekleştirilir.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Vazgeçme Hakları',
              'Uygulamayı kaldırarak uygulama tarafından tüm bilgi toplama işlemini kolayca durdurabilirsiniz. Mobil cihazınızın bir parçası olarak mevcut olan veya mobil uygulama mağazası veya ağ aracılığıyla standart kaldırma işlemlerini kullanabilirsiniz.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Veri Saklama Politikası',
              'Hizmet Sağlayıcı, Uygulamayı kullandığınız sürece ve makul bir süre sonrasına kadar Kullanıcı Tarafından Sağlanan verileri saklayacaktır. Uygulama aracılığıyla sağladığınız Kullanıcı Tarafından Sağlanan Verilerin silinmesini isterseniz, lütfen kolikfirsat@gmail.com adresinden onlarla iletişime geçin ve makul bir süre içinde yanıt vereceklerdir.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Çocuklar',
              'Hizmet Sağlayıcı, Uygulamayı 13 yaşın altındaki çocuklardan bilerek veri talep etmek veya pazarlama yapmak için kullanmaz. Uygulama 13 yaşın altındaki hiç kimseye hitap etmez. Hizmet Sağlayıcı, 13 yaşın altındaki çocuklardan bilerek kişisel olarak tanımlanabilir bilgi toplamaz. Hizmet Sağlayıcı, 13 yaşın altındaki bir çocuğun kişisel bilgi sağladığını keşfederse, bunu sunucularından derhal silecektir. Eğer bir ebeveyn veya vasi iseniz ve çocuğunuzun bize kişisel bilgi sağladığını biliyorsanız, lütfen Hizmet Sağlayıcı (kolikfirsat@gmail.com) ile iletişime geçin, böylece gerekli işlemleri yapabileceklerdir.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Güvenlik',
              'Hizmet Sağlayıcı, bilgilerinizin gizliliğini koruma konusunda endişelidir. Hizmet Sağlayıcı, işlediği ve koruduğu bilgileri korumak için fiziksel, elektronik ve prosedürel güvenlik önlemleri sağlar.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Değişiklikler',
              'Bu Gizlilik Politikası, herhangi bir nedenle zaman zaman güncellenebilir. Hizmet Sağlayıcı, bu sayfayı yeni Gizlilik Politikası ile güncelleyerek Gizlilik Politikasındaki değişikliklerden sizi haberdar edecektir. Devam eden kullanım, tüm değişikliklerin onayı olarak kabul edildiğinden, herhangi bir değişiklik için bu Gizlilik Politikasını düzenli olarak kontrol etmeniz önerilir.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildText(
              context,
              'Bu gizlilik politikası 2025-12-22 tarihinden itibaren geçerlidir.',
              isDark,
              isBold: true,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Onayınız',
              'Uygulamayı kullanarak, şimdi ve bizim tarafımızdan değiştirildiği şekliyle bu Gizlilik Politikasında belirtildiği gibi bilgilerinizin işlenmesine onay veriyorsunuz.',
              isDark,
            ),
            const SizedBox(height: 24),
            _buildSection(
              context,
              'Bize Ulaşın',
              'Uygulamayı kullanırken gizlilik konusunda sorularınız varsa veya uygulamalar hakkında sorularınız varsa, lütfen Hizmet Sağlayıcı ile kolikfirsat@gmail.com adresinden e-posta yoluyla iletişime geçin.',
              isDark,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Bu gizlilik politikası sayfası App Privacy Policy Generator tarafından oluşturulmuştur.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(BuildContext context, String title, String content, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        _buildText(context, content, isDark),
      ],
    );
  }

  Widget _buildText(BuildContext context, String text, bool isDark, {bool isBold = false}) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 14,
        height: 1.6,
        color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
        fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildBulletPoint(BuildContext context, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLink(BuildContext context, String text, String url, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8),
      child: InkWell(
        onTap: () async {
          try {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Link açılamadı: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        child: Row(
          children: [
            Text(
              '• ',
              style: TextStyle(
                fontSize: 16,
                color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
              ),
            ),
            Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.6,
                color: AppTheme.primary,
                decoration: TextDecoration.underline,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.open_in_new,
              size: 14,
              color: AppTheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

