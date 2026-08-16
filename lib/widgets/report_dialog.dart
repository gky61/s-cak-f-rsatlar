import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'guest_login_bottom_sheet.dart';

class ReportDialog extends StatefulWidget {
  final String reportedId;
  final String type; // 'deal', 'comment', 'user', 'message'
  final String? targetDealId;
  final String? targetContent;
  final String? targetAuthor;
  final String? targetAuthorId;

  const ReportDialog({
    super.key,
    required this.reportedId,
    required this.type,
    this.targetDealId,
    this.targetContent,
    this.targetAuthor,
    this.targetAuthorId,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final ReportService _reportService = ReportService();
  final AuthService _authService = AuthService();
  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedReason;
  bool _isLoading = false;

  List<String> get _reasons {
    switch (widget.type) {
      case 'deal':
        return [
          'Spam veya Yanıltıcı',
          'Hatalı / Geçersiz Fiyat',
          'Uygunsuz İçerik / Görsel',
          'Sahte Kampanya / Dolandırıcılık',
          'Yasadışı Ürün / Hizmet',
          'Diğer',
        ];
      case 'comment':
        return [
          'Hakaret veya Saldırgan Dil',
          'Spam / Reklam',
          'Nefret Söylemi',
          'Yanıltıcı Bilgi',
          'Kişisel Veri Paylaşımı',
          'Diğer',
        ];
      case 'user':
        return [
          'Kural Dışı Davranış',
          'Sürekli Spam / Sahte Fırsat',
          'Hakaret veya Taciz',
          'Dolandırıcılık Şüphesi',
          'Sahte Profil',
          'Diğer',
        ];
      case 'message':
        return [
          'Spam / İstenmeyen Mesaj',
          'Hakaret veya Taciz',
          'Tehdit / Zorbalık',
          'Dolandırıcılık / Yanıltıcı',
          'Uygunsuz İçerik',
          'Diğer',
        ];
      default:
        return [
          'Spam veya yanıltıcı',
          'Uygunsuz içerik',
          'Hakaret veya zorbalık',
          'Nefret söylemi',
          'Diğer',
        ];
    }
  }

  String get _title {
    switch (widget.type) {
      case 'deal':
        return 'Fırsatı Raporla';
      case 'comment':
        return 'Yorumu Raporla';
      case 'user':
        return 'Kullanıcıyı Şikayet Et';
      case 'message':
        return 'Mesajı Şikayet Et';
      default:
        return 'İçeriği Raporla';
    }
  }

  String get _subTitle {
    switch (widget.type) {
      case 'deal':
        return 'Fırsatla ilgili hatalı, yanıltıcı veya uygunsuz durumu moderatörlere bildirin.';
      case 'comment':
        return 'Topluluk kurallarını ihlal eden yorumu moderatörlere bildirin.';
      case 'user':
        return 'Topluluk huzurunu bozan bu kullanıcıyı şikayet edin.';
      case 'message':
        return 'Rahatsız edici veya kural dışı mesajı moderasyon ekibimize bildirin.';
      default:
        return 'Lütfen bu içeriği neden raporladığınızı belirtin. Bildiriminiz anonim tutulacaktır.';
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    final user = _authService.currentUser;
    if (user == null) {
      Navigator.pop(context);
      showGuestLoginBottomSheet(
        context,
        title: 'Şikayet Bildirimi',
        message: 'İçerikleri raporlamak ve topluluk güvenliğini korumak için lütfen giriş yapın.',
      );
      return;
    }

    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir şikayet sebebi seçiniz.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _reportService.submitReport(
      reportedId: widget.reportedId,
      type: widget.type,
      reason: _selectedReason!,
      description: _descriptionController.text.trim(),
      targetDealId: widget.targetDealId,
      targetContent: widget.targetContent,
      targetAuthor: widget.targetAuthor,
      targetAuthorId: widget.targetAuthorId,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context); // Dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Expanded(child: Text('Bildiriminiz incelenmek üzere alındı. Teşekkür ederiz.')),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildirim gönderilirken bir hata oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.redAccent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: isDark ? 0.2 : 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.flag_rounded, color: Colors.redAccent, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _title,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _subTitle,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Sebepler Listesi
                Wrap(
                  spacing: 8,
                  runSpacing: 10,
                  children: _reasons.map((reason) {
                    final isSelected = _selectedReason == reason;
                    return ChoiceChip(
                      label: Text(reason),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedReason = selected ? reason : null;
                        });
                      },
                      selectedColor: primaryColor.withValues(alpha: isDark ? 0.25 : 0.15),
                      backgroundColor: isDark ? Colors.grey[850] : const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        color: isSelected 
                            ? primaryColor 
                            : (isDark ? Colors.white : Colors.black87),
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                      side: BorderSide(
                        color: isSelected ? primaryColor : (isDark ? Colors.white.withValues(alpha: 0.1) : const Color(0xFFCBD5E1)),
                        width: 0.9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 16),

                // Açıklama Alanı
                TextField(
                  controller: _descriptionController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: 'Ek açıklama (isteğe bağlı)...',
                    hintStyle: TextStyle(color: isDark ? Colors.grey[500] : const Color(0xFF94A3B8), fontSize: 13),
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: primaryColor, width: 1.2),
                    ),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 13),
                ),

                const SizedBox(height: 20),

                // Gönder Butonu
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitReport,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[600],
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Şikayeti Gönder',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(
                      'İptal',
                      style: TextStyle(
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Helper function to show the report dialog
void showReportDialog(
  BuildContext context, {
  required String reportedId,
  required String type,
  String? targetDealId,
  String? targetContent,
  String? targetAuthor,
  String? targetAuthorId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReportDialog(
      reportedId: reportedId,
      type: type,
      targetDealId: targetDealId,
      targetContent: targetContent,
      targetAuthor: targetAuthor,
      targetAuthorId: targetAuthorId,
    ),
  );
}
