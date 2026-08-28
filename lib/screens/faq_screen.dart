import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final List<FAQCategory> _categories = [
    FAQCategory(
      title: 'Genel & Başlangıç',
      icon: Icons.rocket_launch_rounded,
      items: [
        FAQItem(
          question: 'FırsatKolik nedir ve nasıl çalışır?',
          answer:
              'FırsatKolik; e-ticaret sitelerindeki en avantajlı indirimleri, aktüel ürün kataloglarını ve özel kupon kodlarını topluluk avcıları ve yapay zeka destekli Botkolik ile bir araya getiren bağımsız bir fırsat keşif platformudur.',
        ),
        FAQItem(
          question: 'Uygulamayı kullanmak ve üye olmak ücretli mi?',
          answer:
              'Hayır. FırsatKolik tamamen ücretsizdir. Fırsatları keşfetmek, oylamak, kuponları kullanmak ve bildirim almak için hiçbir ücret talep edilmez.',
        ),
        FAQItem(
          question: 'Misafir olarak neleri yapabilirim, neden üye olmalıyım?',
          answer:
              'Misafir kullanıcılar fırsatları, aktüel katalogları ve kuponları özgürce inceleyebilir. Ancak fırsat paylaşmak, indirimleri oylamak, yorum yazmak, favorilere eklemek ve kelime radarı kurmak için Google hesabınızla tek tıkla ücretsiz üye olabilirsiniz.',
        ),
      ],
    ),
    FAQCategory(
      title: 'Fırsatlar, Kuponlar & Oylama',
      icon: Icons.local_fire_department_rounded,
      items: [
        FAQItem(
          question: 'Nasıl yeni bir fırsat paylaşabilirim?',
          answer:
              'Giriş yaptıktan sonra alt menüdeki "+" (Paylaş) butonuna dokunun. İndirimli ürün linkini yapıştırdığınızda mağaza, başlık ve görsel otomatik algılanır. Fiyat ve kategori bilgilerini onaylayarak fırsatınızı toplulukla paylaşabilirsiniz.',
        ),
        FAQItem(
          question: 'Fırsat Sıcaklığı & Oylama sistemi nasıl işler?',
          answer:
              'Kullanıcılar fırsatın cazibesine göre Sıcak (🔥) veya Soğuk (❄️) oyu verir. Topluluk oyları yükseldikçe fırsat anasayfada öne çıkar. Süresi dolan veya stoğu biten fırsatlar da topluluk oylarıyla güncellenir.',
        ),
        FAQItem(
          question: 'İndirim kuponlarını nasıl kullanırım?',
          answer:
              'Kuponlar sekmesinde yer alan mağaza kupon kodlarına tek dokunuşla kodu kopyalayabilir ve "Mağazaya Git" butonuyla doğrudan ilgili alışveriş sitesinde kullanabilirsiniz.',
        ),
      ],
    ),
    FAQCategory(
      title: 'Radarlar, Bildirimler & Rozetler',
      icon: Icons.notifications_active_rounded,
      items: [
        FAQItem(
          question: 'Kelime Takibi ve bildirimler nasıl çalışır?',
          answer:
              'Aradığınız belirli bir ürün (örn: iPhone, Dyson, Robot Süpürge) veya marka indirime girdiğinde anında bildirim almak için "Kelime Takibi" ekranına anahtar kelimeler ekleyebilirsiniz.',
        ),
        FAQItem(
          question: 'Avcı Puanları ve Seviye Rütbeleri nasıl kazanılır?',
          answer:
              'Fırsat paylaştıkça (+5 puan), paylaşımlarınız sıcak oy aldıkça ve toplulukta aktif oldukça puan kazanırsınız. Puanlarınız arttıkça "Çaylak Avcı"dan başlayıp "Uzman Avcı", "Kozmik Avcı" ve nihai "Fırsat Lordu" rütbelerine kadar yükselirsiniz.',
        ),
      ],
    ),
    FAQCategory(
      title: 'Güvenlik, Gizlilik & Mevzuat',
      icon: Icons.shield_outlined,
      items: [
        FAQItem(
          question: 'Yönlendirilen linkler güvenli mi?',
          answer:
              'Evet. FırsatKolik yalnızca bilinen, yasal ve güvenilir e-ticaret sitelerinin doğrulanmış alan adlarını kabul eder. Şüpheli ve zararlı bağlantılar otomatik güvenlik filtreleri tarafından engellenir.',
        ),
        FAQItem(
          question: 'Fırsatlardaki #tanıtım ibaresi ne anlama gelir?',
          answer:
              'T.C. Ticaret Bakanlığı mevzuatı gereğince, e-ticaret sitelerine yönlendiren bağlantılar içeren paylaşımlarda yasal bir zorunluluk olarak #tanıtım etiketi yer almaktadır. FırsatKolik veya fırsatı paylaşan kullanıcılar ilgili markalarla doğrudan bir ticari ortaklık ya da sponsorluk ilişkisi içerisinde değildir; etiket tamamen yasal mevzuat uyumu ve şeffaflık amacıyla eklenmektedir.',
        ),
        FAQItem(
          question: 'Hesabımı ve verilerimi nasıl silebilirim?',
          answer:
              'Profilim > Ayarlar sekmesindeki "Hesabımı Sil" butonuyla veya kolikfirsat@gmail.com adresine yazarak tüm hesap ve kişisel verilerinizin sistemlerimizden anında kalıcı olarak silinmesini sağlayabilirsiniz.',
        ),
      ],
    ),
  ];

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
          'Sıkça Sorulan Sorular',
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
      body: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        physics: const BouncingScrollPhysics(),
        itemCount: _categories.length,
        itemBuilder: (context, catIndex) {
          final category = _categories[catIndex];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Kategori Başlığı
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 10, top: 8),
                child: Row(
                  children: [
                    Icon(category.icon, size: 18, color: isDark ? accentBlue : primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      category.title,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),

              // Kategori Maddeleri
              ...category.items.map((item) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      dividerColor: Colors.transparent,
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                    ),
                    child: ExpansionTile(
                      tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      collapsedShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      leading: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: (isDark ? accentBlue : primaryColor).withValues(alpha: isDark ? 0.15 : 0.10),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Center(
                          child: Icon(
                            Icons.help_outline_rounded,
                            size: 18,
                            color: isDark ? accentBlue : primaryColor,
                          ),
                        ),
                      ),
                      title: Text(
                        item.question,
                        style: TextStyle(
                          color: textMain,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          letterSpacing: -0.2,
                        ),
                      ),
                      iconColor: textSub,
                      collapsedIconColor: textSub,
                      children: [
                        Text(
                          item.answer,
                          style: TextStyle(
                            color: textSub,
                            fontSize: 13.5,
                            height: 1.55,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}

class FAQCategory {
  final String title;
  final IconData icon;
  final List<FAQItem> items;

  FAQCategory({
    required this.title,
    required this.icon,
    required this.items,
  });
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });
}
