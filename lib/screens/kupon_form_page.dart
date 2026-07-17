import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/kupon.dart';
import '../services/kupon_service.dart';
import '../theme/app_theme.dart';

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

  Future<void> _kuponuPaylas() async {
    if (!_formKey.currentState!.validate()) return;

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
          kuponKodu: _kodController.text.trim().toUpperCase(),
          bitisTarihi: _secilenBitisTarihi,
        );
      } else {
        // Kullanıcı adını Firestore'dan çek
        String kullaniciAdi = '';
        try {
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(widget.userId)
              .get();
          if (userDoc.exists) {
            kullaniciAdi = userDoc.data()?['username'] ?? '';
          }
        } catch (_) {}

        await _kuponService.shareKupon(
          magazaAdi: _secilenMagaza,
          baslik: _baslikController.text.trim(),
          aciklama: _aciklamaController.text.trim(),
          kuponKodu: _kodController.text.trim().toUpperCase(),
          paylasanKullaniciId: widget.userId,
          paylasanKullaniciAdi: kullaniciAdi,
          bitisTarihi: _secilenBitisTarihi,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.kupon != null
                ? 'Kupon başarıyla güncellendi! 🎉'
                : 'Kupon başarıyla paylaşıldı! 🎉'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context); // KuponlarPage'e geri dön
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Kupon paylaşılırken hata oluştu: $e'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
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

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.kupon != null ? 'Kupon Düzenle' : 'Kupon Paylaş', style: const TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Mağaza Seçimi dropdown
              Text(
                'Mağaza Seçimi',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _secilenMagaza,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : Colors.grey[50],
                ),
                dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
                items: _populerMagazalar.map((magaza) {
                  return DropdownMenuItem(
                    value: magaza,
                    child: Text(magaza),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _secilenMagaza = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 20),

              // Kupon Başlığı
              Text(
                'Kupon Başlığı',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _baslikController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen kupon başlığını girin.';
                  }
                  return null;
                },
                decoration: InputDecoration(
                  hintText: 'Örn: 150 TL İndirim',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              // Kupon Açıklaması
              Text(
                'Kupon Açıklaması (Opsiyonel)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _aciklamaController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Örn: Alt limit 500 TL ve üzeri alışverişlerde geçerlidir.',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              // Kupon Kodu
              Text(
                'Kupon Kodu',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _kodController,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Lütfen kupon kodunu girin.';
                  }
                  return null;
                },
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'Örn: TREND150',
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurface : Colors.grey[50],
                ),
              ),
              const SizedBox(height: 20),

              // Son Kullanma Tarihi (DatePicker)
              Text(
                'Son Kullanma Tarihi (Opsiyonel)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              InkWell(
                onTap: () async {
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
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                    ),
                    color: isDark ? AppTheme.darkSurface : Colors.grey[50],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _secilenBitisTarihi == null
                            ? 'Tarih Seçilmedi'
                            : '${_secilenBitisTarihi!.day}.${_secilenBitisTarihi!.month}.${_secilenBitisTarihi!.year}',
                        style: TextStyle(
                          color: _secilenBitisTarihi == null
                              ? (isDark ? Colors.grey[500] : Colors.grey[600])
                              : (isDark ? Colors.white : AppTheme.textPrimary),
                          fontSize: 14,
                        ),
                      ),
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 18,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ],
                  ),
                ),
              ),
              if (_secilenBitisTarihi != null) ...[
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      setState(() {
                        _secilenBitisTarihi = null;
                      });
                    },
                    style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                    child: const Text('Temizle', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ),
              ],
              const SizedBox(height: 36),

              // Gönder Butonu
              ElevatedButton(
                onPressed: _isLoading ? null : _kuponuPaylas,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  elevation: 2,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        widget.kupon != null ? 'Kuponu Güncelle' : 'Kuponu Paylaş',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
