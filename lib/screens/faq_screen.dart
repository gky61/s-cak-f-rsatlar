import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class FAQScreen extends StatefulWidget {
  const FAQScreen({super.key});

  @override
  State<FAQScreen> createState() => _FAQScreenState();
}

class _FAQScreenState extends State<FAQScreen> {
  final List<FAQItem> _faqItems = [
    FAQItem(
      question: 'FIRSATKOLİK nedir?',
      answer: 'FIRSATKOLİK, topluluk temelli bir indirim ve kampanya paylaşım uygulamasıdır. Kullanıcılar en güncel fırsatları paylaşabilir, keşfedebilir ve değerlendirebilir.',
    ),
    FAQItem(
      question: 'Nasıl fırsat paylaşabilirim?',
      answer: 'Ana sayfadaki "+" butonuna tıklayarak fırsat paylaşım ekranına gidebilirsiniz. Link, başlık, fiyat ve kategori bilgilerini girerek fırsatınızı paylaşabilirsiniz. Paylaştığınız fırsat admin onayından sonra yayınlanır.',
    ),
    FAQItem(
      question: 'Fırsat Termometresi ne işe yarar?',
      answer: 'Fırsat Termometresi, topluluğun bir fırsat hakkındaki görüşünü yansıtır. 🔥 (Sıcak) oyları fırsatın iyi olduğunu, ❄️ (Soğuk) oyları ise fırsatın pek cazip olmadığını gösterir.',
    ),
    FAQItem(
      question: 'Anahtar kelime takibi nasıl çalışır?',
      answer: 'Profil > Anahtar Kelime Takibi bölümünden istediğiniz kelimeleri ekleyebilirsiniz. Bu kelimelerle ilgili bir fırsat paylaşıldığında size özel bildirim gönderilir.',
    ),
    FAQItem(
      question: 'Bildirimler nasıl ayarlanır?',
      answer: 'Profil > Bildirimler bölümünden tüm bildirimleri açıp kapatabilir, kategori bazlı bildirim tercihlerinizi ayarlayabilirsiniz.',
    ),
    FAQItem(
      question: 'Puan sistemi nasıl çalışır?',
      answer: 'Fırsat paylaştığınızda, fırsatlarınız beğenildiğinde ve toplulukta aktif olduğunuzda puan kazanırsınız. Puanlarınız arttıkça rozetler kazanabilirsiniz.',
    ),
    FAQItem(
      question: 'Fırsat linki açılmıyor, ne yapmalıyım?',
      answer: 'Bazı linkler zaman içinde geçersiz hale gelebilir veya satıcı tarafından kaldırılabilir. "Süresi Doldu" işaretli fırsatlar artık geçerli olmayabilir.',
    ),
    FAQItem(
      question: 'Paylaştığım fırsat neden görünmüyor?',
      answer: 'Paylaşılan fırsatlar admin onayından geçtikten sonra yayınlanır. Bu işlem genellikle kısa sürer. Onaylanmayan fırsatlar spam veya uygunsuz içerik içerebilir.',
    ),
    FAQItem(
      question: 'Hesabımı nasıl silebilirim?',
      answer: 'Profil > Ayarlar bölümünden "Hesabı Sil" seçeneğini kullanabilirsiniz. Bu işlem geri alınamaz ve tüm verileriniz silinir.',
    ),
    FAQItem(
      question: 'Uygulama güvenli mi?',
      answer: 'Evet, FIRSATKOLİK Firebase altyapısını kullanır ve verileriniz güvenli bir şekilde saklanır. Gizlilik Politikası\'nı inceleyebilirsiniz.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? const Color(0xFF1A1A1A) : Colors.grey[50];
    final cardColor = isDark ? const Color(0xFF2A2A2A) : Colors.white;
    final textColor = isDark ? Colors.white : AppTheme.textPrimary;
    final secondaryTextColor = isDark ? Colors.grey[400] : AppTheme.textSecondary;

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          'Sıkça Sorulan Sorular',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _faqItems.length,
        itemBuilder: (context, index) {
          final item = _faqItems[index];
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                  blurRadius: 10,
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
                tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                collapsedShape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                leading: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: AppTheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                title: Text(
                  item.question,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                iconColor: secondaryTextColor,
                collapsedIconColor: secondaryTextColor,
                children: [
                  Text(
                    item.answer,
                    style: TextStyle(
                      color: secondaryTextColor,
                      fontSize: 14,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class FAQItem {
  final String question;
  final String answer;

  FAQItem({
    required this.question,
    required this.answer,
  });
}

