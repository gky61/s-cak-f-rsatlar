import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/category_detection_service.dart';
import '../services/ai_service.dart';
import '../services/link_preview_service.dart';
import '../models/category.dart';
import '../widgets/category_selector_widget.dart';
import '../theme/app_theme.dart';

void _log(String message) {
  if (kDebugMode) _log(message);
}

class SubmitDealScreen extends StatefulWidget {
  const SubmitDealScreen({super.key});

  @override
  State<SubmitDealScreen> createState() => _SubmitDealScreenState();
}

class _SubmitDealScreenState extends State<SubmitDealScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final LinkPreviewService _linkPreviewService = LinkPreviewService();
  
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _storeController = TextEditingController();
  final _imageUrlController = TextEditingController();
  final _urlController = TextEditingController();
  
  String _selectedCategory = 'elektronik';
  String? _selectedSubCategory;
  bool _isLoading = false;
  bool _isAutoDetecting = false;
  bool _isLoadingImage = false;
  String? _previewImageUrl;
  bool _dealSharingEnabled = true;

  @override
  void initState() {
    super.initState();
    // Başlık veya açıklama değiştiğinde kategori tespit et
    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
    // URL değiştiğinde AI analizi yap
    _urlController.addListener(_onUrlChanged);
    // Görsel URL değiştiğinde otomatik görsel çek
    _imageUrlController.addListener(_onImageUrlChanged);
    // Deal paylaşım durumunu kontrol et
    _checkDealSharingStatus();
  }

  Future<void> _checkDealSharingStatus() async {
    final enabled = await _firestoreService.isDealSharingEnabled();
    if (mounted) {
      setState(() {
        _dealSharingEnabled = enabled;
      });
    }
  }

  void _onTextChanged() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title.isEmpty && description.isEmpty) return;
    
    // Kısa bir gecikme ile tespit yap (kullanıcı yazmayı bitirsin)
    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted || _isAutoDetecting) return;
      _detectCategory();
    });
  }

  Future<void> _onUrlChanged() async {
    final url = _urlController.text.trim();
    
    if (url.isEmpty || !url.startsWith('http')) {
      // URL boşsa veya geçersizse, görsel URL'sini de temizle
      if (_imageUrlController.text.trim().isEmpty || 
          !_isValidImageUrl(_imageUrlController.text.trim())) {
        setState(() {
          _previewImageUrl = null;
          _isLoadingImage = false;
        });
      }
      return;
    }
    
    // --- AMAZON ÖZEL KONTROLÜ BAŞLANGIÇ ---
    // Amazon linki mi? (Hem kısa hem uzun hem mobil linkleri kapsar)
    if (url.contains("amazon") || url.contains("amzn")) {
      setState(() {
        _isLoadingImage = true;
      });
      
      // Akıllı Amazon görsel çekme fonksiyonunu çağır
      try {
        final amazonImage = await _linkPreviewService.getAmazonImageSmart(url);
        
        if (amazonImage != null && mounted) {
          _log('✅ Amazon görsel bulundu (ASIN yöntemi), direkt atanıyor: $amazonImage');
          setState(() {
            _imageUrlController.text = amazonImage; // Görseli bulduk!
            _previewImageUrl = amazonImage;
            _isLoadingImage = false;
          });
          
          // AI analizi yap (görsel zaten bulundu, sadece AI analizi gerekli)
          Future.delayed(const Duration(milliseconds: 1500), () {
            if (!mounted || _isAutoDetecting) return;
            _analyzeProductWithAI();
          });
          return; // Amazon görseli bulundu, scraper'a gerek yok
        } else {
          // ASIN bulunamazsa, normal scraper yöntemi ile devam et
          _log('⚠️ Amazon ASIN bulunamadı, normal scraper yöntemi deneniyor...');
          if (mounted) {
            setState(() {
              _isLoadingImage = false;
            });
          }
        }
      } catch (error) {
        _log('❌ Amazon görsel çekme hatası: $error');
        // Hata olursa normal scraper yöntemi ile devam et
        if (mounted) {
          setState(() {
            _isLoadingImage = false;
          });
        }
      }
    }
    // --- AMAZON ÖZEL KONTROLÜ BİTİŞ ---
    
    // URL girildiğinde otomatik görsel çek (debounce ile)
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (!mounted) return;
      final currentUrl = _urlController.text.trim();
      if (currentUrl.isEmpty || !currentUrl.startsWith('http')) return;
      
      // Eğer görsel URL alanı boşsa veya geçersiz bir URL ise, ürün linkinden görsel çek
      final currentImageUrl = _imageUrlController.text.trim();
      if (currentImageUrl.isEmpty || !_isValidImageUrl(currentImageUrl)) {
        _fetchImageFromProductUrl(currentUrl);
      }
    });
    
    // URL girildiğinde AI analizi yap (debounce ile)
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted || _isAutoDetecting) return;
      _analyzeProductWithAI();
    });
  }
  
  Future<void> _fetchImageFromProductUrl(String productUrl) async {
    if (_isLoadingImage) return;
    
    setState(() {
      _isLoadingImage = true;
      _previewImageUrl = null;
    });
    
    try {
      _log('🔄 Ürün linkinden görsel çekiliyor: $productUrl');
      final preview = await _linkPreviewService.fetchMetadata(productUrl)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        _log('⏱️ Görsel çekme timeout (10 saniye)');
        return null;
      });
      
      if (mounted && preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
        // Görsel URL'sinin geçerli olup olmadığını kontrol et
        if (_isValidImageUrl(preview.imageUrl!)) {
          setState(() {
            _previewImageUrl = preview.imageUrl;
            _imageUrlController.text = preview.imageUrl!;
            _isLoadingImage = false;
          });
          _log('✅ Ürün linkinden görsel bulundu ve Resim Linki alanına yazıldı: ${preview.imageUrl}');
          
          // Kullanıcıya bilgi ver
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.check_circle, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Görsel otomatik olarak bulundu ve eklendi'),
                  ],
                ),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
        } else {
          setState(() {
            _previewImageUrl = null;
            _isLoadingImage = false;
          });
          _log('⚠️ Bulunan URL geçerli bir görsel URL\'si değil: ${preview.imageUrl}');
        }
      } else {
        if (mounted) {
          setState(() {
            _previewImageUrl = null;
            _isLoadingImage = false;
          });
        }
        _log('⚠️ Ürün linkinden görsel bulunamadı');
      }
    } catch (e, stackTrace) {
      _log('❌ Ürün linkinden görsel çekme hatası: $e');
      _log('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _previewImageUrl = null;
          _isLoadingImage = false;
        });
      }
    }
  }
  
  void _onImageUrlChanged() {
    final imageUrl = _imageUrlController.text.trim();
    
    // Eğer boşsa veya geçerli bir görsel URL'si ise, preview'ı güncelle
    if (imageUrl.isEmpty) {
      setState(() {
        _previewImageUrl = null;
        _isLoadingImage = false;
      });
      return;
    }
    
    // Eğer geçerli bir görsel URL'si ise, direkt kullan
    if (_isValidImageUrl(imageUrl)) {
      setState(() {
        _previewImageUrl = imageUrl;
        _isLoadingImage = false;
      });
      return;
    }
    
    // Eğer geçersiz bir URL ise (ürün sayfası gibi), linkten görsel çek
    if (imageUrl.startsWith('http') && !_isValidImageUrl(imageUrl)) {
      _fetchImageFromUrl(imageUrl);
    }
  }
  
  Future<void> _fetchImageFromUrl(String url) async {
    if (_isLoadingImage) return;
    
    setState(() {
      _isLoadingImage = true;
      _previewImageUrl = null;
    });
    
    try {
      final preview = await _linkPreviewService.fetchMetadata(url)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        _log('⏱️ Görsel çekme timeout (10 saniye)');
        return null;
      });
      
      if (mounted && preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
        // Görsel URL'sinin geçerli olup olmadığını kontrol et
        if (_isValidImageUrl(preview.imageUrl!)) {
          setState(() {
            _previewImageUrl = preview.imageUrl;
            _imageUrlController.text = preview.imageUrl!;
            _isLoadingImage = false;
          });
          _log('✅ Görsel bulundu ve güncellendi: ${preview.imageUrl}');
        } else {
          setState(() {
            _previewImageUrl = null;
            _isLoadingImage = false;
          });
          _log('⚠️ Bulunan URL geçerli bir görsel URL\'si değil: ${preview.imageUrl}');
        }
      } else {
        if (mounted) {
          setState(() {
            _previewImageUrl = null;
            _isLoadingImage = false;
          });
        }
        _log('⚠️ Linkten görsel bulunamadı');
      }
    } catch (e, stackTrace) {
      _log('❌ Görsel çekme hatası: $e');
      _log('❌ Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _previewImageUrl = null;
          _isLoadingImage = false;
        });
      }
    }
  }
  
  // URL'nin görsel URL'si olup olmadığını kontrol et
  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    final lowerUrl = url.toLowerCase();
    
    // Yaygın görsel uzantıları
    final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
    if (imageExtensions.any((ext) => lowerUrl.contains(ext))) {
      return true;
    }
    
    // Görsel CDN'leri
    final imageCdnPatterns = [
      'imgbb.co',
      'imgur.com',
      'i.ibb.co',
      'cdn.dsmcdn.com',
      'images.unsplash.com',
      'i.imgur.com',
      '/images/',
      '/img/',
      '/image/',
    ];
    if (imageCdnPatterns.any((pattern) => lowerUrl.contains(pattern))) {
      return true;
    }
    
    // HTML sayfası pattern'leri
    final htmlPagePatterns = ['/product/', '/urun/', '/p-', '/item/', '/detail/', '?', '#'];
    if (htmlPagePatterns.any((pattern) => lowerUrl.contains(pattern))) {
      return false;
    }
    
    // Uzun URL'ler genellikle HTML sayfasıdır
    if (url.length > 100) {
      return false;
    }
    
    return true;
  }

  Future<void> _analyzeProductWithAI() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;

    setState(() {
      _isAutoDetecting = true;
    });

    try {
      final result = await AIService.analyzeProduct(
        url: url,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (result['success'] == true && mounted) {
        // Başlık boşsa AI'dan geleni kullan
        if (_titleController.text.trim().isEmpty && result['title'] != null) {
          _titleController.text = result['title'];
        }

        // Fiyat boşsa AI'dan geleni kullan
        if (_priceController.text.trim().isEmpty && result['price'] != null && result['price'] > 0) {
          _priceController.text = result['price'].toString();
        }

        // Mağaza boşsa AI'dan geleni kullan
        if (_storeController.text.trim().isEmpty && result['store'] != null) {
          _storeController.text = result['store'];
        }

        // Kategoriyi ayarla
        if (result['category'] != null) {
          setState(() {
            _selectedCategory = result['category'];
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white),
                  const SizedBox(width: 8),
                  Text('🤖 AI ile otomatik tespit: ${result['category']} kategorisi'),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      _log('AI analiz hatası: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isAutoDetecting = false;
        });
      }
    }
  }

  void _detectCategory() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title.isEmpty && description.isEmpty) return;
    
    // Başlık ve açıklamayı birleştir
    final combinedText = '$title $description';
    
    _log('🔍 Kategori tespiti yapılıyor: $combinedText');
    final result = CategoryDetectionService.detectCategory(combinedText);
    _log('✅ Tespit sonucu: $result');
    
    if (result != null && mounted) {
      final categoryId = result['categoryId'];
      final subCategory = result['subCategory'];
      
      if (categoryId != null && categoryId != _selectedCategory) {
        _log('📝 Kategori güncelleniyor: $categoryId, alt kategori: $subCategory');
        _isAutoDetecting = true;
        setState(() {
          _selectedCategory = categoryId;
          _selectedSubCategory = subCategory;
        });
        _isAutoDetecting = false;
        
        _log('✅ Kategori güncellendi: ${Category.getById(categoryId).name}');
        
        // Kullanıcıya bildirim göster
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Kategori otomatik tespit edildi: ${Category.getById(categoryId).name}${subCategory != null ? " > $subCategory" : ""}',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Değiştir',
                textColor: Colors.white,
                onPressed: () => _showCategorySelector(),
              ),
            ),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _imageUrlController.removeListener(_onImageUrlChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _storeController.dispose();
    _imageUrlController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  String _getCategoryDisplayText() {
    final category = Category.getById(_selectedCategory);
    if (_selectedSubCategory != null && _selectedSubCategory!.isNotEmpty) {
      return '${category.icon} ${category.name} > $_selectedSubCategory';
    }
    return '${category.icon} ${category.name}';
  }

  void _showCategorySelector() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategorySelectorWidget(
        selectedCategoryId: _selectedCategory,
        selectedSubCategory: _selectedSubCategory,
        onCategorySelected: (categoryId, subCategory) {
          setState(() {
            _isAutoDetecting = false; // Manuel seçim yapıldı, otomatik tespiti durdur
            _selectedCategory = categoryId;
            _selectedSubCategory = subCategory; // Alt kategori bilgisi de kaydediliyor
          });
          
          // Seçimi doğrulama için log
          final category = Category.getById(categoryId);
          _log('✅ Kategori seçildi: ${category.name}${subCategory != null ? " > $subCategory" : ""}');
          
          // Kullanıcıya bilgi ver (modal widget tarafından zaten kapatılıyor)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Kategori seçildi: ${category.name}${subCategory != null ? " > $subCategory" : ""}',
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        },
      ),
    );
  }

  Future<void> _submitDeal() async {
    // Deal paylaşım durumunu kontrol et
    final isEnabled = await _firestoreService.isDealSharingEnabled();
    if (!isEnabled) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Fırsat paylaşımı şu anda geçici olarak durdurulmuştur. Lütfen daha sonra tekrar deneyin.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat paylaşmak için giriş yapmalısınız'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Kategori bilgilerini doğru şekilde al
      final categoryName = Category.getNameById(_selectedCategory);
      final subCategoryName = _selectedSubCategory;
      
      _log('📝 Deal kaydediliyor:');
      _log('   Ana Kategori: $categoryName (ID: $_selectedCategory)');
      _log('   Alt Kategori: ${subCategoryName ?? "Yok"}');
      
      // Eğer görsel URL boşsa veya geçersiz bir URL ise (ürün sayfası gibi), linkten görsel çek
      String imageUrl = _imageUrlController.text.trim();
      final urlControllerText = _urlController.text.trim();
      
      // Görsel URL'sinin geçerli olup olmadığını kontrol et
      final isValidImageUrl = imageUrl.isNotEmpty && _isValidImageUrl(imageUrl);
      
      if ((imageUrl.isEmpty || !isValidImageUrl) && urlControllerText.isNotEmpty) {
        _log('🖼️ Görsel URL boş veya geçersiz, linkten görsel çekiliyor...');
        _log('🔗 URL: $urlControllerText');
        _log('📸 Mevcut imageUrl: ${imageUrl.isEmpty ? "BOŞ" : imageUrl}');
        try {
          final preview = await _linkPreviewService.fetchMetadata(urlControllerText)
              .timeout(const Duration(seconds: 10), onTimeout: () {
            _log('⏱️ Görsel çekme timeout (10 saniye)');
            return null;
          });
          
          if (preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
            imageUrl = preview.imageUrl!;
            _log('✅ Görsel bulundu ve kaydediliyor: $imageUrl');
            // UI'da da güncelle
            if (mounted) {
              _imageUrlController.text = imageUrl;
            }
          } else {
            _log('⚠️ Linkten görsel bulunamadı (preview: ${preview?.imageUrl ?? "null"})');
          }
        } catch (e, stackTrace) {
          _log('❌ Görsel çekme hatası: $e');
          _log('❌ Stack trace: $stackTrace');
          // Hata olsa bile devam et
        }
      } else if (imageUrl.isNotEmpty && isValidImageUrl) {
        _log('✅ Kullanıcının girdiği görsel URL kullanılıyor: $imageUrl');
      } else if (imageUrl.isNotEmpty && !isValidImageUrl) {
        _log('⚠️ Kullanıcının girdiği URL geçersiz (ürün sayfası olabilir): $imageUrl');
        // Geçersiz URL'yi temizle, linkten çekmeyi dene
        imageUrl = '';
      }
      
      _log('📸 Final imageUrl: ${imageUrl.isEmpty ? "BOŞ" : imageUrl}');
      
      await _firestoreService.createDeal(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        price: double.parse(_priceController.text.trim()),
        store: _storeController.text.trim(),
        category: categoryName, // Ana kategori adı
        subCategory: subCategoryName, // Alt kategori adı (varsa)
        imageUrl: imageUrl, // Linkten çekilen veya kullanıcının girdiği görsel
        url: _urlController.text.trim(),
        userId: user.uid,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fırsat başarıyla paylaşıldı!'),
            backgroundColor: Color(0xFFFF6B35),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Hata: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Fırsat Paylaş',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      ),
      body: StreamBuilder<bool>(
        stream: _firestoreService.dealSharingEnabledStream(),
        builder: (context, snapshot) {
          final isEnabled = snapshot.data ?? true;
          
          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Paylaşım durduruldu uyarısı
                if (!isEnabled)
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange, width: 2),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.orange[700]),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Fırsat paylaşımı şu anda geçici olarak durdurulmuştur.',
                            style: TextStyle(
                              color: Colors.orange[900],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                // Başlık
                TextFormField(
              controller: _titleController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Başlık *',
                hintText: 'Örn: iPhone 15 Pro Max',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.title),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Başlık gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Kategori Seçimi
            InkWell(
              onTap: () => _showCategorySelector(),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                ),
                        child: Row(
                          children: [
                    Icon(Icons.category, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kategori *',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                        ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getCategoryDisplayText(),
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.arrow_forward_ios, size: 16, color: isDark ? AppTheme.darkTextSecondary : Colors.grey),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Fiyat
            TextFormField(
              controller: _priceController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Fiyat (₺) *',
                hintText: 'Örn: 999.99',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.attach_money),
              ),
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Fiyat gerekli';
                }
                if (double.tryParse(value) == null) {
                  return 'Geçerli bir fiyat girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Mağaza
            TextFormField(
              controller: _storeController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Mağaza *',
                hintText: 'Örn: Trendyol, Hepsiburada',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.store),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Mağaza gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Açıklama
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Açıklama *',
                hintText: 'Fırsat hakkında detaylar',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.description),
              ),
              maxLines: 4,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Açıklama gerekli';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Ürün URL
            TextFormField(
              controller: _urlController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Ürün Linki *',
                hintText: 'https://...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.link),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ürün linki gerekli';
                }
                if (!value.startsWith('http')) {
                  return 'Geçerli bir URL girin';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Resim URL
            TextFormField(
              controller: _imageUrlController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Resim Linki',
                hintText: 'https://...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                prefixIcon: const Icon(Icons.image),
                suffixIcon: _isLoadingImage
                    ? const Padding(
                        padding: EdgeInsets.all(12.0),
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 16),
            
            // Görsel Önizleme
            if (_previewImageUrl != null || _isLoadingImage)
              Container(
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: _isLoadingImage
                      ? Container(
                          color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[100],
                          child: const Center(
                            child: CircularProgressIndicator(),
                          ),
                        )
                      : _previewImageUrl != null
                          ? Padding(
                              padding: const EdgeInsets.all(24.0),
                              child: CachedNetworkImage(
                                imageUrl: _previewImageUrl!,
                                fit: BoxFit.contain,
                                placeholder: (context, url) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                                errorWidget: (context, url, error) {
                                  return Container(
                                    color: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[100],
                                    child: Center(
                                      child: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                            size: 48,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Görsel yüklenemedi',
                                            style: TextStyle(
                                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            )
                          : null,
                ),
              ),
            const SizedBox(height: 24),

            // Gönder butonu
            ElevatedButton(
              onPressed: (_isLoading || !isEnabled) ? null : _submitDeal,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
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
                  : const Text(
                      'Fırsatı Paylaş',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
              ],
            ),
          );
        },
      ),
    );
  }
}
