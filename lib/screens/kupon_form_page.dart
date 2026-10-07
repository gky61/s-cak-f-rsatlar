import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kupon.dart';
import '../services/kupon_service.dart';
import '../theme/app_theme.dart';
import '../utils/store_asset_helper.dart';
import '../widgets/app_snack_bar.dart';

class KuponFormPage extends StatefulWidget {
  final String userId;
  final Kupon? kupon;

  const KuponFormPage({super.key, required this.userId, this.kupon});

  @override
  State<KuponFormPage> createState() => _KuponFormPageState();
}

class _KuponFormPageState extends State<KuponFormPage> {
  final KuponService _kuponService = KuponService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _baslikController = TextEditingController();
  final TextEditingController _aciklamaController = TextEditingController();
  final TextEditingController _kodController = TextEditingController();

  String _secilenMagaza = 'Trendyol';
  DateTime? _secilenBitisTarihi;
  bool _isLoading = false;

  final List<String> _populerMagazalar = [
    'Trendyol',
    'Hepsiburada',
    'N11',
    'Amazon',
    'Pazarama',
    'MediaMarkt',
    'Teknosa',
    'Mavi',
    'DeFacto',
    'Zara',
    'Mango',
    'Beymen',
    'PttAVM',
    'İncehesap',
    'Idefix',
    'Havit',
    'Migros',
    'Getir',
    'Boyner',
    'Gamer Gen',
    'Gaming Gen',
    'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.kupon != null) {
      _baslikController.text = widget.kupon!.baslik;
      _aciklamaController.text = widget.kupon!.aciklama;
      _kodController.text = widget.kupon!.kuponKodu;
      _secilenBitisTarihi = widget.kupon!.bitisTarihi;
      if (_populerMagazalar.contains(widget.kupon!.magazaAdi)) {
        _secilenMagaza = widget.kupon!.magazaAdi;
      } else {
        _secilenMagaza = 'Diğer';
      }
    }
  }

  @override
  void dispose() {
    _baslikController.dispose();
    _aciklamaController.dispose();
    _kodController.dispose();
    super.dispose();
  }

  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;

    AppSnackBar.show(
      context: context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  Future<void> _pasteKuponKoduFromClipboard() async {
    HapticFeedback.lightImpact();
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (!mounted) return;
      if (clipboardData?.text != null && clipboardData!.text!.trim().isNotEmpty) {
        final text = clipboardData.text!.trim();
        _kodController.text = text;
        _kodController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
        _formKey.currentState?.validate();
        FocusScope.of(context).unfocus();
        setState(() {});
      } else {
        _showCustomSnackBar(
          message: 'Panoda yapıştırılacak kupon kodu bulunamadı.',
          icon: Icons.content_paste_off_rounded,
          backgroundColor: Colors.grey[800]!,
        );
      }
    } catch (_) {}
  }

  Future<void> _kuponuPaylas() async {
    if (_isLoading) return;
    HapticFeedback.mediumImpact();
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      _showCustomSnackBar(
        message: 'Lütfen zorunlu alanları doldurun.',
        icon: Icons.error_outline_rounded,
        backgroundColor: const Color(0xFFC62828),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (widget.kupon != null) {
        await _kuponService.updateKupon(
          kuponId: widget.kupon!.id,
          magazaAdi: _secilenMagaza,
          baslik: _baslikController.text.trim(),
          aciklama: _aciklamaController.text.trim(),
          kuponKodu: _kodController.text.trim(),
          bitisTarihi: _secilenBitisTarihi,
        );
      } else {
        // Kullanıcı adını Firestore'dan zaman aşımı korumalı çek
        String kullaniciAdi = '';
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get()
              .timeout(const Duration(seconds: 4));
          if (userDoc.exists) {
            final val = userDoc.data()?['username']?.toString();
            if (val != null && val.trim().isNotEmpty) {
              kullaniciAdi = val.trim();
            }
          }
        } catch (_) {}

        await _kuponService.shareKupon(
          magazaAdi: _secilenMagaza,
          baslik: _baslikController.text.trim(),
          aciklama: _aciklamaController.text.trim(),
          kuponKodu: _kodController.text.trim(),
          paylasanKullaniciId: widget.userId,
          paylasanKullaniciAdi: kullaniciAdi,
          bitisTarihi: _secilenBitisTarihi,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showPostPop(
          message: widget.kupon != null
              ? '🎉 Kupon başarıyla güncellendi!'
              : '🎟️ Kuponunuz onaya gönderildi! İncelemeden sonra yayına alınacaktır.',
          icon: Icons.check_circle_rounded,
          backgroundColor: AppTheme.primary,
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
        _showCustomSnackBar(
          message: 'Kupon kaydedilirken hata oluştu: $cleanMsg',
          icon: Icons.error_outline_rounded,
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);

    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        resizeToAvoidBottomInset: true,
        appBar: AppBar(
          title: Text(
            widget.kupon != null ? 'Kupon Düzenle' : 'Kupon Paylaş',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 18,
              letterSpacing: -0.3,
              color: textColor,
            ),
          ),
          centerTitle: true,
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 19,
              color: textColor,
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Geri',
          ),
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.opaque,
          child: Column(
            children: [
              Expanded(
                child: Form(
                  key: _formKey,
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
                    children: [
                      // 1. KART: MAĞAZA VE KUPON BİLGİLERİ
                      _buildNotchedCardContainer(
                        isDark: isDark,
                        title: 'Mağaza ve Kupon Bilgileri',
                        icon: Icons.storefront_rounded,
                        children: [
                          // Mağaza Dropdown
                          DropdownButtonFormField<String>(
                            // ignore: deprecated_member_use
                            value: _secilenMagaza,
                            menuMaxHeight: 300,
                            isExpanded: true,
                            dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                            style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w600),
                            decoration: InputDecoration(
                              labelText: 'Mağaza / Satıcı *',
                              filled: true,
                              fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              prefixIcon: const Icon(Icons.storefront_rounded, size: 20),
                            ),
                            items: _populerMagazalar.map((magaza) {
                              return DropdownMenuItem<String>(
                                value: magaza,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Image.asset(
                                      StoreAssetHelper.getStoreAsset(magaza),
                                      width: 18,
                                      height: 18,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 18),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      magaza,
                                      style: TextStyle(color: textColor, fontSize: 13.5),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                HapticFeedback.selectionClick();
                                FocusScope.of(context).unfocus();
                                setState(() {
                                  _secilenMagaza = val;
                                });
                              }
                            },
                          ),

                          const SizedBox(height: 16),

                          // Kupon Başlığı
                          TextFormField(
                            controller: _baslikController,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                            style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13.5),
                            decoration: InputDecoration(
                              labelText: 'Kupon Başlığı *',
                              hintText: 'Örn: 150 TL İndirim veya %20 Sepet İndirimi',
                              hintStyle: TextStyle(
                                color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                                fontSize: 12.5,
                              ),
                              filled: true,
                              fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              prefixIcon: const Icon(Icons.title_rounded, size: 20),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Lütfen kupon başlığını girin.';
                              }
                              if (val.trim().length < 3) {
                                return 'Başlık en az 3 karakter olmalıdır.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 2. KART: KUPON KODU VE GEÇERLİLİK
                      _buildNotchedCardContainer(
                        isDark: isDark,
                        title: 'Kupon Kodu ve Geçerlilik',
                        icon: Icons.vpn_key_rounded,
                        trailing: InkWell(
                          onTap: _pasteKuponKoduFromClipboard,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.08),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppTheme.primary.withValues(alpha: 0.35),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.content_paste_rounded, size: 12, color: AppTheme.primary),
                                SizedBox(width: 4),
                                Text(
                                  'Panodan Yapıştır',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        children: [
                          // Kupon Kodu
                          TextFormField(
                            controller: _kodController,
                            textCapitalization: TextCapitalization.characters,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => FocusScope.of(context).unfocus(),
                            style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                              letterSpacing: 0.8,
                            ),
                            decoration: InputDecoration(
                              labelText: 'Kupon Kodu *',
                              hintText: 'Örn: TREND150 veya SEPET20',
                              hintStyle: TextStyle(
                                color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                                fontSize: 12.5,
                                letterSpacing: 0,
                              ),
                              filled: true,
                              fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              prefixIcon: const Icon(Icons.discount_outlined, size: 20),
                              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                                valueListenable: _kodController,
                                builder: (context, value, _) {
                                  return value.text.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(Icons.clear_rounded, size: 18),
                                          tooltip: 'Temizle',
                                          onPressed: () {
                                            HapticFeedback.lightImpact();
                                            _kodController.clear();
                                          },
                                        )
                                      : IconButton(
                                          icon: const Icon(Icons.content_paste_rounded, size: 18),
                                          tooltip: 'Panodan Yapıştır',
                                          onPressed: _pasteKuponKoduFromClipboard,
                                        );
                                },
                              ),
                            ),
                            validator: (val) {
                              if (val == null || val.trim().isEmpty) {
                                return 'Lütfen kupon kodunu girin.';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // Son Kullanma Tarihi Seçici Hücresi
                          InkWell(
                            onTap: () async {
                              HapticFeedback.selectionClick();
                              FocusScope.of(context).unfocus();
                              final secilen = await showDatePicker(
                                context: context,
                                initialDate: _secilenBitisTarihi ?? DateTime.now().add(const Duration(days: 7)),
                                firstDate: DateTime.now().subtract(const Duration(days: 1)),
                                lastDate: DateTime.now().add(const Duration(days: 365)),
                              );
                              if (secilen != null) {
                                setState(() {
                                  _secilenBitisTarihi = secilen;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                              decoration: BoxDecoration(
                                color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded, size: 18, color: AppTheme.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Son Kullanma Tarihi (Opsiyonel)',
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          _secilenBitisTarihi == null
                                              ? 'Belirtilmedi (Süresiz / Bilinmiyor)'
                                              : '${_secilenBitisTarihi!.day}.${_secilenBitisTarihi!.month}.${_secilenBitisTarihi!.year}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: _secilenBitisTarihi == null
                                                ? (isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8))
                                                : textColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (_secilenBitisTarihi != null)
                                    InkWell(
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        setState(() {
                                          _secilenBitisTarihi = null;
                                        });
                                      },
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                        padding: const EdgeInsets.all(4.0),
                                        child: Icon(
                                          Icons.close_rounded,
                                          size: 16,
                                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                                        ),
                                      ),
                                    )
                                  else
                                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      // 3. KART: KUPON KOŞULLARI VE NOTLAR
                      _buildNotchedCardContainer(
                        isDark: isDark,
                        title: 'Kupon Koşulları & Notlar',
                        icon: Icons.notes_rounded,
                        children: [
                          TextFormField(
                            controller: _aciklamaController,
                            style: TextStyle(color: textColor, fontSize: 13, height: 1.45),
                            maxLines: 4,
                            minLines: 3,
                            decoration: InputDecoration(
                              labelText: 'Kupon Detayları (Opsiyonel)',
                              hintText: 'Örn: Alt limit 500 TL üzeri alışverişlerde ve seçili kategorilerde geçerlidir...',
                              hintStyle: TextStyle(
                                color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                                fontSize: 12.5,
                              ),
                              alignLabelWithHint: true,
                              filled: true,
                              fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                              ),
                              contentPadding: const EdgeInsets.all(14),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              _buildStickySubmitBar(isDark),
            ],
          ),
        ),
      ),
    );
  }

  // Helper Notched Card Container (Fieldset Style)
  Widget _buildNotchedCardContainer({
    required bool isDark,
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    final bgColor = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final pageBgColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 18),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.025),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),

        // Embedded Notched Title on top border line
        Positioned(
          top: 0,
          left: 16,
          right: trailing != null ? 16 : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: pageBgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor.withValues(alpha: 0.85),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: AppTheme.primary),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 8),
                trailing,
              ],
            ],
          ),
        ),
      ],
    );
  }

  // Sticky Floating Action Bar
  Widget _buildStickySubmitBar(bool isDark) {
    final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = keyboardHeight > 0;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 8, 16, isKeyboardOpen ? 8 : 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.98) : Colors.white.withValues(alpha: 0.98),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.06),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: !isKeyboardOpen,
        child: SizedBox(
          width: double.infinity,
          height: 46,
          child: ElevatedButton(
            onPressed: _isLoading ? null : _kuponuPaylas,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primary,
              foregroundColor: Colors.white,
              disabledBackgroundColor: isDark ? const Color(0xFF2C2C2C) : Colors.grey[700],
              elevation: 2,
              shadowColor: AppTheme.primary.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        widget.kupon != null ? Icons.save_rounded : Icons.rocket_launch_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.kupon != null ? 'Kuponu Güncelle' : 'Kuponu Toplulukla Paylaş',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
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
