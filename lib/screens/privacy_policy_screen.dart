import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../firebase_options.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final primaryColor = isDark ? const Color(0xFFEA580C) : const Color(0xFFFF6B35);
    final accentBlue = isDark ? const Color(0xFF38BDF8) : const Color(0xFF004E92);
    final textMain = isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
    final textSub = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Gizlilik Politikası',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
        ),
        backgroundColor: surfaceColor,
        foregroundColor: textMain,
        elevation: 0,
        scrolledUnderElevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(
            color: borderColor,
            height: 1,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: surfaceColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor, width: 1.1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: (isDark ? accentBlue : primaryColor).withValues(alpha: isDark ? 0.16 : 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.verified_user_outlined,
                      color: isDark ? accentBlue : primaryColor,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'FırsatKolik Gizlilik Beyanı',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Son Güncelleme: 2026-08-21 (v1.2.4)',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 1. Genel Bilgilendirme
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('1. Giriş ve Hizmet Kapsamı', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'FırsatKolik (bundan böyle "Uygulama" olarak anılacaktır), kullanıcılara e-ticaret indirimleri, aktüel ürün katalogları ve kampanya kuponları hakkında topluluk destekli bilgi ve yönlendirme sağlayan ücretsiz bir mobil platformdur.',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Kişisel verilerinizin güvenliği ve gizliliği bizim için en üst önceliktir. Bu metin; hangi verilerin ne amaçla toplandığını, nasıl işlendiğini ve haklarınızı şeffaf bir şekilde açıklar.',
                    textSub,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 2. Toplanan Veriler
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('2. Toplanan Veriler ve Kullanım Amaçları', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Uygulamayı kullandığınızda aşağıdaki temel veriler işlenebilir:',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildBullet(
                    'Hesap Bilgileri:',
                    'Google ile giriş yapıldığında ad, e-posta adresi ve profil fotoğrafı (Kimlik doğrulama ve kullanıcı profili için).',
                    textMain,
                    textSub,
                  ),
                  _buildBullet(
                    'Uygulama İçi Tercihler:',
                    'Fırsat oyları, kelime radarları, favoriler ve kategori tercihleri (Kişiselleştirilmiş akış ve bildirimler için).',
                    textMain,
                    textSub,
                  ),
                  _buildBullet(
                    'Teknik Teşhis ve FCM Token:',
                    'Cihaz bildirim anahtarı (FCM Token), çökme logları ve performans metrikleri (Uygulama kararlılığını sağlamak için).',
                    textMain,
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    '⚠️ FırsatKolik hiçbir zaman kredi kartı, banka bilgisi veya hassas ödeme verilerini talep etmez, işlemez veya saklamaz.',
                    textSub,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 3. Reklam ve Ticari Uyum
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('3. Ticari Reklam Mevzuatı & Şeffaflık', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'FırsatKolik bağımsız bir fırsat paylaşım ve topluluk platformudur. Listelenen mağazalarla doğrudan bir ticari ortaklık veya sponsorluk anlaşması bulunmamaktadır. T.C. Ticaret Bakanlığı mevzuatı uyarınca üçüncü taraf e-ticaret sitelerine yönlendiren tüm bağlantılarda yasal zorunluluk gereği #tanıtım etiketi yer almaktadır.',
                    textSub,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 4. Üçüncü Taraf Altyapı
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('4. Güvenilir Altyapı Sağlayıcıları', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Uygulama, endüstri standardı güvenlik ve analiz altyapılarını kullanmaktadır:',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildServiceLink('Google Firebase (Auth, Firestore, FCM)', 'https://firebase.google.com/support/privacy', accentBlue),
                  _buildServiceLink('Google Play Services', 'https://policies.google.com/privacy', accentBlue),
                  _buildServiceLink('Firebase Crashlytics & Performance', 'https://firebase.google.com/support/privacy', accentBlue),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 5. Hesap ve Veri Silme Hakları
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('5. Hesap ve Veri Silme Hakları', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Kullanıcılar diledikleri an hesaplarını ve sistemdeki tüm kişisel verilerini kalıcı olarak silme hakkına sahiptir:',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildBullet(
                    'Uygulama İçi Silme:',
                    'Giriş yaptıktan sonra Profil > Ayarlar menüsünden "Hesabımı Sil" seçeneğini kullanarak verilerinizi anında silebilirsiniz.',
                    textMain,
                    textSub,
                  ),
                  _buildBullet(
                    'Web Talebi & Destek:',
                    'Uygulama erişiminiz yoksa kolikfirsat@gmail.com adresine yazarak veya web sayfamızdan silme talebi gönderebilirsiniz.',
                    textMain,
                    textSub,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _launchUrl('https://${DefaultFirebaseOptions.flavorProjectId}.web.app/delete-account.html');
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Web Hesap Silme Talebi Formu'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: isDark ? accentBlue : primaryColor,
                        side: BorderSide(color: isDark ? accentBlue.withValues(alpha: 0.5) : primaryColor.withValues(alpha: 0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 6. İletişim ve Destek
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('6. İletişim ve Destek', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Gizlilik politikamız, kişisel verileriniz veya uygulama deneyiminizle ilgili her türlü soru, öneri ve talepleriniz için bizimle doğrudan iletişime geçebilirsiniz:',
                    textSub,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(Icons.email_outlined, size: 18, color: isDark ? accentBlue : primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'kolikfirsat@gmail.com',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required Color surfaceColor,
    required Color borderColor,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.2,
        color: textColor,
      ),
    );
  }

  Widget _buildParagraph(String text, Color textColor) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        height: 1.55,
        color: textColor,
      ),
    );
  }

  Widget _buildBullet(String title, String desc, Color titleColor, Color descColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '• ',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: titleColor),
          ),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 13.5, height: 1.5, color: descColor),
                children: [
                  TextSpan(
                    text: '$title ',
                    style: TextStyle(fontWeight: FontWeight.w700, color: titleColor),
                  ),
                  TextSpan(text: desc),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceLink(String name, String url, Color linkColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: InkWell(
        onTap: () => _launchUrl(url),
        child: Row(
          children: [
            Icon(Icons.arrow_right_rounded, size: 20, color: linkColor),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: linkColor,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
