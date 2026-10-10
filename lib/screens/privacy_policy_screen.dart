import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

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
    final backgroundColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    const primaryColor = AppTheme.primary;
    final accentBlue = isDark ? const Color(0xFF38BDF8) : const Color(0xFF004E92);
    final textMain = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final textSub = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

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
                          'Son Güncelleme: 2026-10-04 (v1.3.0)',
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

            // 1. Genel Bilgilendirme ve Veri Sorumlusu
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
                    'FırsatKolik (bundan böyle "Uygulama" veya "Platform" olarak anılacaktır), kullanıcılara e-ticaret indirimleri, aktüel ürün katalogları ve kampanya kuponları hakkında topluluk destekli bilgi ve yönlendirme sağlayan tamamen ücretsiz bir mobil platformdur.',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    '6698 sayılı Kişisel Verilerin Korunması Kanunu ("KVKK"), Google Play Geliştirici Politikaları ve Apple App Store İnceleme Kılavuzları uyarınca kişisel verilerinizin gizliliği en üst önceliğimizdir. Platformumuzdaki veri sorumlusu Muratcan Gökyokuş / FırsatKolik ekibidir.',
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
                    'Uygulamayı kullandığınızda aşağıdaki sınırlı veriler işlenebilir:',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildBullet(
                    'Hesap ve Kimlik Bilgileri:',
                    'Google ile giriş yapıldığında ad, e-posta adresi ve profil fotoğrafı; Apple ile giriş yapıldığında (Sign in with Apple) ad ve e-posta adresi işlenir. Apple\'ın "E-postamı Gizle" (Private Relay) gizlilik seçeneği tam olarak desteklenir.',
                    textMain,
                    textSub,
                  ),
                  _buildBullet(
                    'Uygulama İçi Tercihler & Radar:',
                    'Fırsat oyları, Fırsat Radarı alarmları, favoriler, kuponlar ve kategori tercihleri (Kişiselleştirilmiş akış ve ilgili bildirimleri ulaştırmak için).',
                    textMain,
                    textSub,
                  ),
                  _buildBullet(
                    'Teknik Teşhis ve FCM Token:',
                    'Cihaz bildirim belirteci (FCM Token), çökme logları (Crashlytics) ve ağ performans metrikleri (Uygulama kararlılığını ve güvenliğini sağlamak için).',
                    textMain,
                    textSub,
                  ),
                  _buildBullet(
                    'Reklam ve Cihaz Tanımlayıcıları:',
                    'Google AdMob reklamlarının sunumu için Google Advertising ID (GAID) veya Apple IDFA (kullanıcı izin verirse) işlenebilir. Kişiselleştirilmiş reklam onayları Google UMP ve Apple ATT akışlarıyla yönetilir.',
                    textMain,
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    '🛡️ FırsatKolik hiçbir zaman kredi kartı, banka bilgisi veya hassas ödeme verilerini talep etmez, işlemez veya saklamaz.',
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
                  _buildSectionTitle('3. Ticari Reklam Mevzuatı & Gelir Ortaklığı', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'FırsatKolik bağımsız bir fırsat paylaşım ve topluluk platformudur. T.C. Ticaret Bakanlığı 6563 sayılı Kanun ve mevzuat uyarınca üçüncü taraf e-ticaret sitelerine yönlendiren tüm bağlantılarda yasal zorunluluk gereği #tanıtım etiketi yer almaktadır.',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Amazon Associates ve mağaza gelir ortaklığı (affiliate) programları kapsamında, yönlendirilen bağlantılardan gerçekleştirilen alışverişlerden platformumuz komisyon elde edebilir. Bu yönlendirmeler kullanıcılara hiçbir ek maliyet oluşturmaz.',
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
                  _buildServiceLink('Apple Inc. (Sign in with Apple)', 'https://www.apple.com/legal/privacy/tr/', accentBlue),
                  _buildServiceLink('Google AdMob (Mobil Reklam)', 'https://support.google.com/admob/answer/6128543', accentBlue),
                  _buildServiceLink('Firebase Crashlytics & Performance', 'https://firebase.google.com/support/privacy', accentBlue),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 5. Yapay Zeka ve Botkolik
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('5. Yapay Zeka ve Algoritmik Süreçler', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Uygulama, indirimleri taramak ve katalogları kategorize etmek için "Botkolik" algoritmik servislerini kullanır. Bu sistemler yalnızca kamuya açık mağaza fiyatlarını analiz eder; kullanıcıların kişisel profilleri veya özel verileri hiçbir yapay zeka modelinin eğitiminde kullanılmaz.',
                    textSub,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 6. Hesap ve Veri Silme Hakları
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('6. Hesap ve Veri Silme Hakları', textMain),
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
                    'Uygulama cihazınızda yüklü olmasa dahi firsatkolik.app/delete-account.html sayfasından veya destek@firsatkolik.app adresine yazarak silme talebi gönderebilirsiniz.',
                    textMain,
                    textSub,
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        _launchUrl('https://firsatkolik.app/delete-account.html');
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 16),
                      label: const Text('Web Hesap Silme Talebi Sayfası'),
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

            // 7. KVKK Kapsamında Yasal Haklar
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('7. KVKK Kapsamındaki Yasal Haklarınız', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    '6698 sayılı KVKK\'nın 11. maddesi uyarınca; verilerinizin işlenip işlenmediğini öğrenme, bilgi talep etme, amacına uygun kullanılıp kullanılmadığını denetleme, eksik/yanlışsa düzeltilmesini isteme, silinmesini/yok edilmesini talep etme ve kanuna aykırı işleme nedeniyle oluşan zararın giderilmesini talep etme haklarına sahipsiniz.',
                    textSub,
                  ),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'Taleplerinizi resmi destek kanalımız olan destek@firsatkolik.app adresine iletebilirsiniz.',
                    textSub,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 8. Çocukların Gizliliği
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('8. Çocukların Gizliliği (13 Yaş Sınırı)', textMain),
                  const SizedBox(height: 8),
                  _buildParagraph(
                    'FırsatKolik genel kullanıcı kitlesine (13 yaş ve üzeri) yöneliktir. 13 yaşın altındaki çocuklardan bilerek veri toplanmaz. Ebeveyn veya yasal vasisi olunan bir çocuğun veri paylaştığı fark edilirse destek@firsatkolik.app üzerinden bildirim yapıldığında kayıtlar derhal silinir.',
                    textSub,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // 9. İletişim ve Destek
            _buildCard(
              surfaceColor: surfaceColor,
              borderColor: borderColor,
              isDark: isDark,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionTitle('9. İletişim ve Destek', textMain),
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
                        'destek@firsatkolik.app',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(Icons.language_rounded, size: 18, color: isDark ? accentBlue : primaryColor),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _launchUrl('https://firsatkolik.app'),
                        child: Text(
                          'https://firsatkolik.app',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? accentBlue : primaryColor,
                            decoration: TextDecoration.underline,
                          ),
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
      padding: const EdgeInsets.only(bottom: 8),
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
