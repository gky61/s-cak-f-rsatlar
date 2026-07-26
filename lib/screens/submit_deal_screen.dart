import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'package:shimmer/shimmer.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/category_detection_service.dart';
import '../services/ai_service.dart';
import '../services/link_preview_service.dart';
import '../services/domain_allowlist_service.dart';
import '../models/category.dart';
import '../widgets/category_selector_widget.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class SubmitDealScreen extends StatefulWidget {
  final String? initialUrl;
  const SubmitDealScreen({super.key, this.initialUrl});

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
  final _customStoreController = TextEditingController();
  
  String? _selectedStore;
  String? _priceLabel;
  double? _scrapedOriginalPrice;
  final List<String> _stores = [
    'Trendyol',
    'Hepsiburada',
    'N11',
    'Amazon',
    'Pazarama',
    'Vatan Bilgisayar',
    'MediaMarkt',
    'İtopya',
    'İdefix',
    'Teknosa',
    'Mavi',
    'DeFacto',
    'Zara',
    'Mango',
    'Beymen',
    'PttAVM',
    'İncehesap',
    'Havit',
    'Migros',
    'Getir',
    'Diğer',
  ];

  String _getStoreAsset(String storeName) {
    switch (storeName) {
      case 'Trendyol':
        return 'assets/trendyol.jpg';
      case 'Hepsiburada':
        return 'assets/hepsiburada.jpg';
      case 'N11':
        return 'assets/n11.jpg';
      case 'Amazon':
        return 'assets/amazon.jpg';
      case 'Pazarama':
        return 'assets/pazarama.jpg';
      case 'Vatan Bilgisayar':
        return 'assets/vatan.jpg';
      case 'MediaMarkt':
        return 'assets/mediamarkt.jpg';
      case 'İtopya':
        return 'assets/itopya.jpg';
      case 'İdefix':
        return 'assets/idefix.jpg';
      case 'Teknosa':
        return 'assets/teknosa.jpg';
      case 'Mavi':
        return 'assets/mavi.jpg';
      case 'DeFacto':
        return 'assets/defacto.jpg';
      case 'Zara':
        return 'assets/zara.jpg';
      case 'Mango':
        return 'assets/mango.jpg';
      case 'Beymen':
        return 'assets/beymen.jpg';
      case 'PttAVM':
        return 'assets/pttavm.jpg';
      case 'İncehesap':
        return 'assets/incehesap.jpg';
      case 'Havit':
        return 'assets/havit.jpg';
      case 'Migros':
        return 'assets/migros.jpg';
      case 'Getir':
        return 'assets/getir.jpg';
      default:
        return 'assets/store-icon.png';
    }
  }

  void _updateStoreSelection(String storeName) {
    if (!mounted) return;
    
    final lowerName = storeName.toLowerCase();
    String? matchedStore;
    
    if (lowerName.contains('trendyol') || lowerName.contains('ty.gl')) {
      matchedStore = 'Trendyol';
    } else if (lowerName.contains('hepsiburada') || lowerName.contains('hb.biz')) {
      matchedStore = 'Hepsiburada';
    } else if (lowerName.contains('n11')) {
      matchedStore = 'N11';
    } else if (lowerName.contains('amazon') || lowerName.contains('amzn')) {
      matchedStore = 'Amazon';
    } else if (lowerName.contains('pazarama') || lowerName.contains('pzrm')) {
      matchedStore = 'Pazarama';
    } else if (lowerName.contains('vatan')) {
      matchedStore = 'Vatan Bilgisayar';
    } else if (lowerName.contains('mediamarkt') || lowerName.contains('media markt')) {
      matchedStore = 'MediaMarkt';
    } else if (lowerName.contains('itopya')) {
      matchedStore = 'İtopya';
    } else if (lowerName.contains('idefix')) {
      matchedStore = 'İdefix';
    } else if (lowerName.contains('teknosa')) {
      matchedStore = 'Teknosa';
    } else if (lowerName.contains('mavi')) {
      matchedStore = 'Mavi';
    } else if (lowerName.contains('defacto')) {
      matchedStore = 'DeFacto';
    } else if (lowerName.contains('zara')) {
      matchedStore = 'Zara';
    } else if (lowerName.contains('mango')) {
      matchedStore = 'Mango';
    } else if (lowerName.contains('beymen')) {
      matchedStore = 'Beymen';
    } else if (lowerName.contains('pttavm')) {
      matchedStore = 'PttAVM';
    } else if (lowerName.contains('incehesap')) {
      matchedStore = 'İncehesap';
    } else if (lowerName.contains('havit')) {
      matchedStore = 'Havit';
    } else if (lowerName.contains('migros')) {
      matchedStore = 'Migros';
    } else if (lowerName.contains('getir')) {
      matchedStore = 'Getir';
    }
    
    setState(() {
      if (matchedStore != null) {
        _selectedStore = matchedStore;
        _storeController.text = matchedStore;
      } else {
        _selectedStore = 'Diğer';
        _customStoreController.text = storeName;
        _storeController.text = storeName;
      }
    });
  }

  String _selectedCategory = 'elektronik';
  String? _selectedSubCategory;
  bool _isLoading = false;
  bool _isAutoDetecting = false;
  bool _isLoadingImage = false;
  String? _previewImageUrl;
  bool _dealSharingEnabled = true;
  Timer? _urlDebounceTimer;
  Timer? _textDebounceTimer;
  bool _isCategoryLockedByScraper = false;
  double? _scrapedRatingValue;
  int? _scrapedRatingCount;
  String? _scrapedBrand;
  
  String _lastProcessedUrl = '';
  String _lastProcessedTitle = '';
  String _lastProcessedDescription = '';
  String _lastProcessedImageUrl = '';

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

    if (widget.initialUrl != null) {
      _urlController.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _autoFetchProductData(widget.initialUrl!);
      });
    }
  }

  Future<void> _checkDealSharingStatus() async {
    final enabled = await _firestoreService.isDealSharingEnabled();
    if (mounted) {
      setState(() {
        _dealSharingEnabled = enabled;
      });
    }
  }

  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarAction? action,
  }) {
    if (!mounted) return;
    
    // Clear any active SnackBars immediately so they don't pile up
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(12),
        elevation: 4,
        action: action,
      ),
    );
  }

  void _showUnsupportedStoreDialog() {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFEF6C00), size: 28),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Desteklenmeyen Mağaza Linki',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Girdiğiniz ürün linki topluluk tarafından desteklenen 20 mağazadan birine ait değildir.',
                style: TextStyle(fontSize: 14, height: 1.4),
              ),
              SizedBox(height: 12),
              Text(
                'Güvenli bir topluluk için sadece aşağıdaki desteklenen mağazalara ait geçerli ürün linkleri paylaşılabilir:\n\n'
                '• Trendyol, Hepsiburada, Amazon TR, N11, Pazarama, Idefix, PttAVM\n'
                '• Teknosa, MediaMarkt, Vatan Bilgisayar, İtopya, İncehesap\n'
                '• Mavi, DeFacto, Zara, Mango, Beymen\n'
                '• Migros, Getir, Havit',
                style: TextStyle(fontSize: 12, color: Colors.grey, height: 1.3),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Anladım',
                style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFFF6B35)),
              ),
            ),
          ],
        );
      },
    );
  }

  String? _cleanScrapedString(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (trimmed.toLowerCase() == 'null') return null;
    return trimmed;
  }

  void _onTextChanged() {
    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();
    
    if (title == _lastProcessedTitle && description == _lastProcessedDescription) {
      return; // Değişiklik yoksa boşuna tetikleme
    }
    
    _lastProcessedTitle = title;
    _lastProcessedDescription = description;
    
    if (title.isEmpty && description.isEmpty) return;
    
    _textDebounceTimer?.cancel();
    _textDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      if (!mounted || _isAutoDetecting) return;
      _detectCategory();
    });
  }

  Future<void> _onUrlChanged() async {
    final url = _urlController.text.trim();
    
    if (url == _lastProcessedUrl) {
      return; // Değişiklik yoksa boşuna tetikleme
    }
    
    _lastProcessedUrl = url;
    
    if (url.isEmpty || !url.startsWith('http')) {
      // URL boşsa veya geçersizse, otomatik doldurulan tüm alanları temizle
      setState(() {
        _titleController.clear();
        _descriptionController.clear();
        _priceController.clear();
        _storeController.clear();
        _customStoreController.clear();
        _selectedStore = null;
        _imageUrlController.clear();
        _previewImageUrl = null;
        _selectedCategory = 'elektronik';
        _selectedSubCategory = null;
        _isLoadingImage = false;
        _isCategoryLockedByScraper = false;
      });
      return;
    }
    
    // Debounce: Yazma bittikten 600ms sonra verileri otomatik çek
    _urlDebounceTimer?.cancel();
    _urlDebounceTimer = Timer(const Duration(milliseconds: 600), () {
      if (!mounted) return;
      _autoFetchProductData(url);
    });
  }
  
  Future<void> _autoFetchProductData(String url) async {
    if (_isAutoDetecting || _isLoadingImage) return;

    // Domain Allowlist Kontrolü
    final isAllowed = await DomainAllowlistService.isResolvedUrlAllowed(url);
    if (!isAllowed) {
      if (mounted) {
        setState(() {
          _isAutoDetecting = false;
          _isLoadingImage = false;
        });
        _showUnsupportedStoreDialog();
      }
      return;
    }

    // Yeni URL analizine başlamadan önce eski verileri temizle
    setState(() {
      _isAutoDetecting = true;
      _isLoadingImage = true;
      _previewImageUrl = null;
      _titleController.clear();
      _descriptionController.clear();
      _priceController.clear();
      _storeController.clear();
      _customStoreController.clear();
      _selectedStore = null;
      _imageUrlController.clear();
      _selectedCategory = 'elektronik';
      _selectedSubCategory = null;
      _isCategoryLockedByScraper = false;
      _priceLabel = null;
    });

    _log('🔄 Otomatik ürün bilgisi çekme başlatıldı: $url');

    bool hasImage = false;
    bool hasTitle = false;
    bool hasStore = false;
    bool hasCategory = false;
    bool hasPrice = false;

    // 1. AMAZON ÖZEL KONTROLÜ
    String? amazonImage;
    if (url.contains("amazon") || url.contains("amzn")) {
      try {
        amazonImage = await _linkPreviewService.getAmazonImageSmart(url);
        if (amazonImage != null) {
          _log('✅ Amazon görsel ASIN yöntemiyle bulundu: $amazonImage');
          if (mounted) {
            setState(() {
              _imageUrlController.text = amazonImage!;
              _previewImageUrl = amazonImage;
              _isLoadingImage = false;
            });
          }
          hasImage = true;
        }
      } catch (e) {
        _log('❌ Amazon görsel çekme hatası: $e');
      }
    }

    // 2. LİNK PREVIEW (CLIENT-SIDE SCRAPING)
    LinkPreviewResult? preview;
    try {
      preview = await _linkPreviewService.fetchMetadata(url)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        _log('⏱️ LinkPreview timeout');
        return null;
      });
      
      if (preview != null && mounted) {
        // Görseli al
        final cleanImage = _cleanScrapedString(preview.imageUrl);
        if (!hasImage && cleanImage != null && _isValidImageUrl(cleanImage)) {
          setState(() {
            _imageUrlController.text = cleanImage;
            _previewImageUrl = cleanImage;
            _isLoadingImage = false;
          });
          hasImage = true;
        }
        
        // Başlığı al (boşsa)
        final cleanTitle = _cleanScrapedString(preview.title);
        if (_titleController.text.trim().isEmpty && cleanTitle != null) {
          _titleController.text = cleanTitle;
          hasTitle = true;
        }

        // Mağazayı al (boşsa)
        final cleanProvider = _cleanScrapedString(preview.provider);
        if (_storeController.text.trim().isEmpty && cleanProvider != null) {
          _updateStoreSelection(cleanProvider);
          hasStore = true;
        }

        // Fiyatı al (boşsa)
        if (_priceController.text.trim().isEmpty && preview.price != null && preview.price! > 0) {
          final doubleVal = preview.price!;
          if (doubleVal == doubleVal.toInt()) {
            _priceController.text = doubleVal.toInt().toString();
          } else {
            _priceController.text = doubleVal.toString();
          }
          hasPrice = true;
        }


        // Açıklamayı al (boşsa)
        final cleanDesc = _cleanScrapedString(preview.description);
        if (_descriptionController.text.trim().isEmpty && cleanDesc != null) {
          _descriptionController.text = cleanDesc;
        }

        // Fiyat Etiketini al (kampanya/CRM)
        final label = preview.priceLabel;
        if (label != null && label.isNotEmpty) {
          setState(() {
            _priceLabel = label;
          });
          _log('🏷️ Scraper fiyat etiketi tespiti: $_priceLabel');
        }

        // Rating & Marka & İndirimsiz Fiyat verilerini al
        if (preview?.ratingValue != null || preview?.ratingCount != null || preview?.brand != null || preview?.originalPrice != null) {
          setState(() {
            _scrapedRatingValue = preview?.ratingValue;
            _scrapedRatingCount = preview?.ratingCount;
            _scrapedBrand = preview?.brand;
            _scrapedOriginalPrice = preview?.originalPrice;
          });
          _log('⭐ Scraper rating/marka/eskiFiyat tespiti: Rating=$_scrapedRatingValue ($_scrapedRatingCount), Brand=$_scrapedBrand, OriginalPrice=$_scrapedOriginalPrice');
        }

        // Kategori ekmek kırıntılarını (breadcrumbs) ve başlığı birleştirip sınıflandır
        if (preview.breadcrumbs != null && preview.breadcrumbs!.isNotEmpty) {
          final joinedBreadcrumbs = preview.breadcrumbs!.join(' ');
          final cleanTitle = _cleanScrapedString(preview.title) ?? '';
          final textToClassify = '$joinedBreadcrumbs $cleanTitle';
          _log('🔍 Scraper kırıntıları ve başlık ile kategori tespiti yapılıyor: $textToClassify');
          final result = CategoryDetectionService.detectCategory(textToClassify);
          if (result != null) {
            setState(() {
              _selectedCategory = result['categoryId']!;
              _selectedSubCategory = result['subCategory'];
              _isCategoryLockedByScraper = true;
            });
            hasCategory = true;
            _log('✅ Scraper kategori tespiti başarılı: $_selectedCategory -> $_selectedSubCategory (Kilitlendi)');
          }
        }
      }
    } catch (e) {
      _log('❌ LinkPreview metadata çekme hatası: $e');
    }

    // Görsel yükleniyor durumunu kapat
    if (mounted) {
      setState(() {
        _isLoadingImage = false;
      });
    }

    // 3. GEMINI AI ANALİZİ
    try {
      _log('🤖 Gemini AI ürün analizi başlatılıyor...');
      final aiResult = await AIService.analyzeProduct(
        url: url,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      );

      if (aiResult['success'] == true && mounted) {
        // AI'dan gelen verileri ata (eğer alanlar boşsa)
        final aiTitle = _cleanScrapedString(aiResult['title']?.toString());
        if (_titleController.text.trim().isEmpty && aiTitle != null) {
          _titleController.text = aiTitle;
          hasTitle = true;
        }

        if (_priceController.text.trim().isEmpty && aiResult['price'] != null && aiResult['price'] > 0) {
          _priceController.text = aiResult['price'].toString();
          hasPrice = true;
        }

        final aiStore = _cleanScrapedString(aiResult['store']?.toString());
        if (_storeController.text.trim().isEmpty && aiStore != null) {
          _updateStoreSelection(aiStore);
          hasStore = true;
        }

        if (aiResult['category'] != null && !_isCategoryLockedByScraper) {
          setState(() {
            _selectedCategory = aiResult['category'];
            _selectedSubCategory = null;
          });
          hasCategory = true;
        }
      } else {
        _log('⚠️ AI Analiz başarısız veya proxy hatası verdi.');
      }
    } catch (e) {
      _log('❌ AI Analiz sırasında hata oluştu: $e');
    }

    // İşlem bitti
    if (mounted) {
      setState(() {
        _isAutoDetecting = false;
      });
    }

    // 4. KULLANICI BİLGİLENDİRME (SNACKBAR)
    if (mounted) {
      final anySuccess = hasImage || hasTitle || hasStore || hasCategory || hasPrice;
      
      if (anySuccess) {
        final List<String> missingFields = [];
        if (_imageUrlController.text.trim().isEmpty) missingFields.add('Görsel');
        if (_titleController.text.trim().isEmpty) missingFields.add('Başlık');
        if (_priceController.text.trim().isEmpty) missingFields.add('Fiyat');
        if (_storeController.text.trim().isEmpty) missingFields.add('Mağaza');

        String msg;
        if (missingFields.isEmpty) {
          msg = '✨ Ürün bilgileri otomatik olarak başarıyla çekildi!';
        } else {
          msg = '✨ Ürün bilgileri kısmen çekildi. Eksik alanları (${missingFields.join(", ")}) lütfen elle tamamlayın.';
        }

        _showCustomSnackBar(
          message: msg,
          icon: Icons.check_circle_rounded,
          backgroundColor: const Color(0xFF2E7D32),
          duration: const Duration(seconds: 3),
        );
      } else {
        _showCustomSnackBar(
          message: 'Ürün bilgileri otomatik çekilemedi, lütfen elle doldurun.',
          icon: Icons.info_outline_rounded,
          backgroundColor: const Color(0xFF546E7A),
          duration: const Duration(seconds: 3),
        );
      }
    }
  }

  void _onImageUrlChanged() {
    final imageUrl = _imageUrlController.text.trim();
    
    if (imageUrl == _lastProcessedImageUrl) {
      return; // Değişiklik yoksa boşuna tetikleme
    }
    
    _lastProcessedImageUrl = imageUrl;
    
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
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;
    
    final lowerUrl = url.toLowerCase();
    
    // Görsel CDN'leri (Bu alan adlarından gelenler kesinlikle görseldir)
    final imageCdnPatterns = [
      'assets.mmsrg.com',      // MediaMarkt CDN
      'img.pzrmcdn.com',       // Pazarama CDN
      'cdn.dsmcdn.com',        // Trendyol CDN
      'hepsiburada.net',       // Hepsiburada CDN
      'images-amazon.com',     // Amazon CDN
      'images-na.ssl-images-amazon.com',
      'n11scdn.akamaized.net',  // N11 CDN
      'cdn.vatanbilgisayar.com', // Vatan Bilgisayar CDN
      'idefix.com',             // Idefix CDN
      'itopya.com',             // Itopya CDN
      'yenieera22.com',          // Itopya Image CDN
      'teknosa.com',            // Teknosa CDN
      'teknosa-cloud-prod.mncdn.com', // Teknosa Image CDN
      'sky-static.mavi.com',    // Mavi CDN
      'mavi.com',               // Mavi Domain
      'dfcdn.net',              // DeFacto CDN
      'defacto.com.tr',         // DeFacto Domain
      'static.zara.net',        // Zara CDN
      'zara.com',               // Zara Domain
      'st.mango.com',           // Mango CDN
      'st-mango.mncdn.com',     // Mango Alternative CDN
      'mango.com',              // Mango Domain
      'cdn.beymen.com',         // Beymen CDN
      'beymen.com',             // Beymen Domain
      'cdn-s3.pttavm.com',      // PttAVM CDN
      'pttavm.com',             // PttAVM Domain
      'incehesap.com',          // İncehesap Domain
      'imgbb.co',
      'imgur.com',
      'i.ibb.co',
      'images.unsplash.com',
      'i.imgur.com',
    ];
    if (imageCdnPatterns.any((pattern) => lowerUrl.contains(pattern))) {
      return true;
    }
    
    // URI analizi ile uzantı kontrolü (Sorgu parametrelerini ayıklayarak)
    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      final imageExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp', '.bmp', '.svg'];
      if (imageExtensions.any((ext) => path.endsWith(ext) || path.contains(ext))) {
        return true;
      }
    } catch (_) {}
    
    // HTML sayfası pattern'leri
    final htmlPagePatterns = ['/product/', '/urun/', '/p-', '/item/', '/detail/'];
    if (htmlPagePatterns.any((pattern) => lowerUrl.contains(pattern))) {
      return false;
    }
    
    // Genel uzunluk kontrolü (Daha esnek limit)
    if (url.length > 250) {
      return false;
    }
    
    return true;
  }



  void _detectCategory() {
    if (_isCategoryLockedByScraper) {
      _log('ℹ️ Kategori scraper kırıntısı (breadcrumbs) tarafından kilitlendiği için otomatik eşleştirme atlanıyor.');
      return;
    }

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
      }
    }
  }

  @override
  void dispose() {
    _urlDebounceTimer?.cancel();
    _textDebounceTimer?.cancel();
    _titleController.removeListener(_onTextChanged);
    _descriptionController.removeListener(_onTextChanged);
    _imageUrlController.removeListener(_onImageUrlChanged);
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _storeController.dispose();
    _customStoreController.dispose();
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
            _isCategoryLockedByScraper = false; // Manuel seçim yapıldı, kilidi kaldır
            _isAutoDetecting = false; // Manuel seçim yapıldı, otomatik tespiti durdur
            _selectedCategory = categoryId;
            _selectedSubCategory = subCategory; // Alt kategori bilgisi de kaydediliyor
          });
          
          // Seçimi doğrulama için log
          final category = Category.getById(categoryId);
          _log('✅ Kategori seçildi: ${category.name}${subCategory != null ? " > $subCategory" : ""}');
          
          // Kullanıcıya bilgi ver (modal widget tarafından zaten kapatılıyor)
          _showCustomSnackBar(
            message: 'Kategori seçildi: ${category.name}${subCategory != null ? " > $subCategory" : ""}',
            icon: Icons.check_circle_rounded,
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 2),
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
        _showCustomSnackBar(
          message: 'Fırsat paylaşımı şu anda geçici olarak durdurulmuştur. Lütfen daha sonra tekrar deneyin.',
          icon: Icons.warning_amber_rounded,
          backgroundColor: const Color(0xFFEF6C00),
          duration: const Duration(seconds: 4),
        );
      }
      return;
    }
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final urlControllerText = _urlController.text.trim();
    final isAllowed = await DomainAllowlistService.isResolvedUrlAllowed(urlControllerText);
    if (!isAllowed) {
      _showUnsupportedStoreDialog();
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      _showCustomSnackBar(
        message: 'Fırsat paylaşmak için giriş yapmalısınız',
        icon: Icons.lock_outline_rounded,
        backgroundColor: const Color(0xFFC62828),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Kategori bilgilerini doğru şekilde al
      // Kategori ID'sini direkt kaydet (kategori adı yerine)
      final categoryId = _selectedCategory;
      final subCategoryName = _selectedSubCategory;
      final categoryName = Category.getNameById(_selectedCategory);
      
      _log('📝 Deal kaydediliyor:');
      _log('   Ana Kategori ID: $categoryId');
      _log('   Ana Kategori Adı: $categoryName');
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
      
      try {
        await _firestoreService.createDeal(
          title: _titleController.text.trim(),
          description: _descriptionController.text.trim(),
          price: double.parse(_priceController.text.trim()),
          store: _storeController.text.trim(),
          category: categoryId, // Kategori ID'si kaydediliyor (kategori adı yerine)
          subCategory: subCategoryName, // Alt kategori adı (varsa)
          imageUrl: imageUrl, // Linkten çekilen veya kullanıcının girdiği görsel
          url: _urlController.text.trim(),
          userId: user.uid,
          originalPrice: _scrapedOriginalPrice,
          priceLabel: _priceLabel,
          ratingValue: _scrapedRatingValue,
          ratingCount: _scrapedRatingCount,
          brand: _scrapedBrand,
        );

        if (mounted) {
          Navigator.pop(context);
          _showCustomSnackBar(
            message: 'Fırsat başarıyla paylaşıldı!',
            icon: Icons.check_circle_rounded,
            backgroundColor: const Color(0xFFFF6B35), // Primary orange accent
          );
        }
      } catch (e) {
        if (mounted) {
          final errorMsg = e.toString();
          if (errorMsg.contains('already_shared:')) {
            final dealId = errorMsg.split('already_shared:')[1].trim();
            _showAlreadySharedDialog(context, dealId);
          } else {
            _showCustomSnackBar(
              message: errorMsg.replaceAll('Exception: ', ''),
              icon: Icons.error_outline_rounded,
              backgroundColor: const Color(0xFFC62828),
              duration: const Duration(seconds: 4),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar(
          message: 'Hata: $e',
          icon: Icons.error_outline_rounded,
          backgroundColor: const Color(0xFFC62828),
          duration: const Duration(seconds: 4),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showAlreadySharedDialog(BuildContext context, String dealId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.info_outline_rounded,
                color: Color(0xFFFF6B35),
                size: 28,
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Bu Ürün Zaten Paylaşıldı',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Paylaşmaya çalıştığınız ürünün aktif ve sıcak bir fırsat paylaşımı zaten mevcut. '
            'Yeni bir mükerrer konu açmak yerine, mevcut fırsata giderek oy verebilir veya yorum yazabilirsiniz.',
            style: TextStyle(fontSize: 14, height: 1.4),
          ),
          actionsPadding: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Kapat',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF6B35),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(context); // Diyalogu kapat
                if (mounted) {
                  Navigator.pop(context); // Paylaşım formunu kapat
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DealDetailScreen(dealId: dealId),
                  ),
                );
              },
              child: const Text('Fırsata Git'),
            ),
          ],
        );
      },
    );
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

                // Ürün URL (En üstte olması daha iyi bir kullanıcı deneyimi sağlar)
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
                    suffixIcon: _urlController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey[600],
                              size: 20,
                            ),
                            onPressed: () {
                              setState(() {
                                _urlController.clear();
                              });
                            },
                            tooltip: 'Linki Temizle',
                          )
                        : null,
                  ),
                  onChanged: (value) {
                    setState(() {}); // Clear butonu görünürlüğü için yeniden çiz
                  },
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

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  switchInCurve: Curves.easeInOut,
                  switchOutCurve: Curves.easeInOut,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.04),
                          end: Offset.zero,
                        ).animate(animation),
                        child: child,
                      ),
                    );
                  },
                  child: _isAutoDetecting
                      ? _buildSkeletonLoader(isDark)
                      : _buildFormFields(isDark, isEnabled, textColor),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    final baseColor = isDark ? Colors.grey[850]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    
    return Shimmer.fromColors(
      key: const ValueKey('skeleton_loader'),
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Loader status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 180,
                        height: 12,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 120,
                        height: 8,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Title skeleton
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Category skeleton
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Price skeleton
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Store skeleton
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Description skeleton
          Container(
            height: 110,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Image URL skeleton
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 16),
          // Image preview box skeleton
          Container(
            height: 200,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildFormFields(bool isDark, bool isEnabled, Color textColor) {
    return Column(
      key: const ValueKey('form_fields'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
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

        // Mağaza (Dropdown)
        DropdownButtonFormField<String>(
          value: _selectedStore,
          menuMaxHeight: 250,
          dropdownColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            labelText: 'Mağaza *',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            prefixIcon: const Icon(Icons.store),
          ),
          items: _stores.map((store) {
            return DropdownMenuItem<String>(
              value: store,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image.asset(
                    _getStoreAsset(store),
                    width: 20,
                    height: 20,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.store, size: 20);
                    },
                  ),
                  const SizedBox(width: 10),
                  Text(store, style: TextStyle(color: textColor)),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            setState(() {
              _selectedStore = value;
              if (value != 'Diğer') {
                _storeController.text = value ?? '';
              } else {
                _storeController.text = _customStoreController.text;
              }
            });
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Mağaza gerekli';
            }
            if (value == 'Diğer' && _customStoreController.text.trim().isEmpty) {
              return 'Özel mağaza adı girilmelidir';
            }
            return null;
          },
        ),
        
        if (_selectedStore == 'Diğer') ...[
          const SizedBox(height: 16),
          TextFormField(
            controller: _customStoreController,
            style: TextStyle(color: textColor),
            decoration: InputDecoration(
              labelText: 'Özel Mağaza Adı *',
              hintText: 'Örn: CarrefourSA, MediaMarkt vb.',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              prefixIcon: const Icon(Icons.edit),
            ),
            onChanged: (value) {
              _storeController.text = value.trim();
            },
            validator: (value) {
              if (_selectedStore == 'Diğer' && (value == null || value.trim().isEmpty)) {
                return 'Mağaza adı boş bırakılamaz';
              }
              return null;
            },
          ),
        ],
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
        if (_previewImageUrl != null || _isLoadingImage) const SizedBox(height: 24),

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
    );
  }
}
