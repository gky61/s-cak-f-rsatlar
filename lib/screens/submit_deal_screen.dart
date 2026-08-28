import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:shimmer/shimmer.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/category_detection_service.dart';
import '../services/ai_service.dart';
import '../services/link_preview_service.dart';
import '../services/domain_allowlist_service.dart';
import '../services/advertising_compliance_service.dart';
import '../models/category.dart';
import '../models/deal.dart';
import '../widgets/category_selector_widget.dart';
import '../theme/app_theme.dart';
import '../utils/store_asset_helper.dart';
import '../utils/asset_path_migration.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../widgets/store_price_badge.dart';
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
  String? _detectedPriceLabel;
  bool _isSpecialBadgeEnabled = false;
  double? _scrapedOriginalPrice;
  bool _hidePrice = false;
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
    'Boyner',
    'Diğer',
  ];

  String _getStoreAsset(String storeName) {
    return StoreAssetHelper.getStoreAsset(storeName);
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
    } else if (lowerName.contains('boyner')) {
      matchedStore = 'Boyner';
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

      if (matchedStore == 'Getir' || matchedStore == 'Migros') {
        _selectedCategory = 'supermarket';
        _selectedSubCategory ??= 'Gıda Ürünleri';
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
  bool _isAmazonWarehouse = false;
  bool _showInfoBanner = true;
  bool _showManualImageInput = false;

  String _lastProcessedUrl = '';
  String _lastProcessedTitle = '';
  String _lastProcessedDescription = '';
  String _lastProcessedImageUrl = '';

  @override
  void initState() {
    super.initState();

    _titleController.addListener(_onTextChanged);
    _descriptionController.addListener(_onTextChanged);
    _urlController.addListener(_onUrlChanged);
    _imageUrlController.addListener(_onImageUrlChanged);
    _priceController.addListener(() => setState(() {}));
    _checkDealSharingStatus();

    if (widget.initialUrl != null) {
      _isAutoDetecting = true;
      _isLoadingImage = true;
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
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: backgroundColor,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        elevation: 6,
        action: action,
      ),
    );
  }

  void _showUrlValidationErrorDialog(UrlValidationResult result) {
    if (!mounted) return;

    String titleText = 'Geçersiz Link';
    String messageText = 'Girdiğiniz link geçerli bir ürün sayfası değildir.';
    IconData icon = Icons.warning_amber_rounded;
    Color iconColor = const Color(0xFFEF6C00);

    switch (result) {
      case UrlValidationResult.invalidFormat:
        titleText = 'Geçersiz Link Formatı';
        messageText = 'Girdiğiniz link geçerli bir URL formatında değildir. Lütfen kontrol edip tekrar deneyin.';
        icon = Icons.error_outline_rounded;
        iconColor = const Color(0xFFC62828);
        break;
      case UrlValidationResult.domainNotAllowed:
        titleText = 'Desteklenmeyen Mağaza';
        messageText = 'Girdiğiniz ürün linki topluluk tarafından desteklenen mağazalardan birine ait değildir.';
        icon = Icons.storefront_outlined;
        iconColor = const Color(0xFFE65100);
        break;
      case UrlValidationResult.notProductUrl:
        titleText = 'Ürün Sayfası Değil';
        messageText = 'Girdiğiniz link desteklenen bir mağazaya ait ancak bir ürün detay sayfası değildir. Kampanya, arama veya kategori sayfaları yerine doğrudan satın alma yapılabilecek ürün sayfasının linkini paylaşmalısınız.';
        icon = Icons.shopping_bag_outlined;
        iconColor = const Color(0xFF2E7D32);
        break;
      case UrlValidationResult.valid:
        return;
    }

    showDialog(
      context: context,
      builder: (BuildContext ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(icon, color: iconColor, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titleText,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                messageText,
                style: const TextStyle(fontSize: 13.5, height: 1.4),
              ),
              if (_urlController.text.trim().isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  '🔗 URL: ${_urlController.text.trim()}',
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontStyle: FontStyle.italic),
                ),
              ]
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text(
                'Anladım',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primary),
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
      return;
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

  bool _isFetchingActive = false;

  Future<void> _onUrlChanged() async {
    final url = _urlController.text.trim();

    if (url == _lastProcessedUrl) {
      return;
    }

    _lastProcessedUrl = url;

    if (url.isEmpty || !url.startsWith('http')) {
      _urlDebounceTimer?.cancel();
      setState(() {
        _isAutoDetecting = false;
        _isLoadingImage = false;
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
        _isCategoryLockedByScraper = false;
        _isAmazonWarehouse = false;
        _scrapedOriginalPrice = null;
        _scrapedRatingValue = null;
        _scrapedRatingCount = null;
        _scrapedBrand = null;
        _priceLabel = null;
        _detectedPriceLabel = null;
        _isSpecialBadgeEnabled = false;
      });
      return;
    }

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
      _detectedPriceLabel = null;
      _isSpecialBadgeEnabled = false;
      _isAmazonWarehouse = false;
      _scrapedOriginalPrice = null;
      _scrapedRatingValue = null;
      _scrapedRatingCount = null;
      _scrapedBrand = null;
    });

    _urlDebounceTimer?.cancel();
    _urlDebounceTimer = Timer(const Duration(milliseconds: 400), () {
      if (!mounted) return;
      _autoFetchProductData(url);
    });
  }

  Future<void> _pasteFromClipboard() async {
    HapticFeedback.lightImpact();
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      if (clipboardData?.text != null && clipboardData!.text!.trim().isNotEmpty) {
        final text = clipboardData.text!.trim();
        _urlController.text = text;
        _urlController.selection = TextSelection.fromPosition(TextPosition(offset: text.length));
        _formKey.currentState?.validate();
        setState(() {});
      } else {
        _showCustomSnackBar(
          message: 'Panoda yapıştırılacak link bulunamadı.',
          icon: Icons.content_paste_off_rounded,
          backgroundColor: Colors.grey[800]!,
        );
      }
    } catch (_) {}
  }

  Future<void> _autoFetchProductData(String url) async {
    if (_isFetchingActive) return;
    _isFetchingActive = true;

    try {
      if (!_isAutoDetecting && mounted) {
        setState(() {
          _isAutoDetecting = true;
          _isLoadingImage = true;
        });
      }

      final validationResult = await DomainAllowlistService.validateUrl(url);
      if (validationResult != UrlValidationResult.valid) {
        if (mounted) {
          setState(() {
            _isAutoDetecting = false;
            _isLoadingImage = false;
          });
          _showUrlValidationErrorDialog(validationResult);
        }
        return;
      }

      _log('🔄 Otomatik ürün bilgisi çekme başlatıldı: $url');

      bool hasImage = false;
      bool hasTitle = false;
      bool hasStore = false;
      bool hasCategory = false;
      bool hasPrice = false;

      // 1. AMAZON ASIN CHECK
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

      // 2. CLIENT-SIDE SCRAPING
      LinkPreviewResult? preview;
      try {
        preview = await _linkPreviewService.fetchMetadata(url)
            .timeout(const Duration(seconds: 10), onTimeout: () {
          _log('⏱️ LinkPreview timeout');
          return null;
        });

        final cleanPreview = preview;
        if (cleanPreview != null && mounted) {
          final cleanImage = _cleanScrapedString(cleanPreview.imageUrl);
          if (!hasImage && cleanImage != null && _isValidImageUrl(cleanImage)) {
            setState(() {
              _imageUrlController.text = cleanImage;
              _previewImageUrl = cleanImage;
              _isLoadingImage = false;
            });
            hasImage = true;
          }

          final cleanTitle = _cleanScrapedString(cleanPreview.title);
          if (_titleController.text.trim().isEmpty && cleanTitle != null) {
            _titleController.text = cleanTitle;
            hasTitle = true;
          }

          final cleanProvider = _cleanScrapedString(cleanPreview.provider);
          if (_storeController.text.trim().isEmpty && cleanProvider != null) {
            _updateStoreSelection(cleanProvider);
            hasStore = true;
          }

          if (_priceController.text.trim().isEmpty && cleanPreview.price != null && cleanPreview.price! > 0) {
            final doubleVal = cleanPreview.price!;
            if (doubleVal == doubleVal.toInt()) {
              _priceController.text = doubleVal.toInt().toString();
            } else {
              _priceController.text = doubleVal.toString();
            }
            hasPrice = true;
          }

          final cleanDesc = _cleanScrapedString(cleanPreview.description);
          if (_descriptionController.text.trim().isEmpty && cleanDesc != null) {
            _descriptionController.text = AdvertisingComplianceService.ensureDisclosure(cleanDesc);
          }

          final label = cleanPreview.priceLabel;
          if (label != null && label.isNotEmpty) {
            final isClubMembership = _isMembershipBadgeLabel(label);
            setState(() {
              _detectedPriceLabel = label;
              _priceLabel = label;
              _isSpecialBadgeEnabled = isClubMembership;
            });
            _log('🏷️ Scraper fiyat etiketi tespiti: $_priceLabel (Rozet switch: $isClubMembership)');
          }

          if (cleanPreview.ratingValue != null || cleanPreview.ratingCount != null || cleanPreview.brand != null || cleanPreview.originalPrice != null) {
            setState(() {
              _scrapedRatingValue = cleanPreview.ratingValue;
              _scrapedRatingCount = cleanPreview.ratingCount;
              _scrapedBrand = cleanPreview.brand;
              _scrapedOriginalPrice = cleanPreview.originalPrice;
            });
          }

          if (cleanPreview.isAmazonWarehouse || Deal.checkIsAmazonWarehouse(url)) {
            setState(() {
              _isAmazonWarehouse = true;
            });
          }

          if (cleanPreview.breadcrumbs != null && cleanPreview.breadcrumbs!.isNotEmpty) {
            final joinedBreadcrumbs = cleanPreview.breadcrumbs!.join(' ');
            final cleanT = _cleanScrapedString(cleanPreview.title) ?? '';
            final textToClassify = '$joinedBreadcrumbs $cleanT';
            final result = CategoryDetectionService.detectCategory(
              textToClassify,
              url: url,
              store: _selectedStore,
            );
            if (result != null) {
              setState(() {
                _selectedCategory = result['categoryId']!;
                _selectedSubCategory = result['subCategory'];
                _isCategoryLockedByScraper = true;
              });
              hasCategory = true;
            }
          }
        }
      } catch (e) {
        _log('❌ LinkPreview metadata çekme hatası: $e');
      }

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

          final isGetirOrMigros = url.contains('getir') || url.contains('migros') ||
              (_selectedStore != null && (_selectedStore! == 'Getir' || _selectedStore! == 'Migros'));

          if (aiResult['category'] != null && !_isCategoryLockedByScraper && !isGetirOrMigros) {
            setState(() {
              _selectedCategory = aiResult['category'];
              _selectedSubCategory = null;
            });
            hasCategory = true;
          }
        }
      } catch (e) {
        _log('❌ AI Analiz sırasında hata: $e');
      }

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
          if (!_hidePrice && _priceController.text.trim().isEmpty) missingFields.add('Fiyat');
          if (_storeController.text.trim().isEmpty) missingFields.add('Mağaza');

          String msg;
          if (missingFields.isEmpty) {
            msg = '✨ Ürün bilgileri Botkolik tarafından başarıyla dolduruldu!';
          } else {
            msg = '✨ Bilgiler kısmen çekildi. Lütfen eksik alanları (${missingFields.join(", ")}) tamamlayın.';
          }

          _showCustomSnackBar(
            message: msg,
            icon: Icons.auto_awesome_rounded,
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 3),
          );
        } else {
          _showCustomSnackBar(
            message: 'Ürün bilgileri otomatik çekilemedi, lütfen bilgileri elle doldurun.',
            icon: Icons.info_outline_rounded,
            backgroundColor: const Color(0xFF546E7A),
            duration: const Duration(seconds: 3),
          );
        }
      }
    } finally {
      _isFetchingActive = false;
      if (mounted && _isAutoDetecting) {
        setState(() {
          _isAutoDetecting = false;
          _isLoadingImage = false;
        });
      }
    }
  }

  void _onImageUrlChanged() {
    final imageUrl = _imageUrlController.text.trim();

    if (imageUrl == _lastProcessedImageUrl) {
      return;
    }

    _lastProcessedImageUrl = imageUrl;

    if (imageUrl.isEmpty) {
      setState(() {
        _previewImageUrl = null;
        _isLoadingImage = false;
      });
      return;
    }

    if (_isValidImageUrl(imageUrl)) {
      setState(() {
        _previewImageUrl = imageUrl;
        _isLoadingImage = false;
      });
      return;
    }

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
        return null;
      });

      if (mounted && preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
        if (_isValidImageUrl(preview.imageUrl!)) {
          setState(() {
            _previewImageUrl = preview.imageUrl;
            _imageUrlController.text = preview.imageUrl!;
            _isLoadingImage = false;
          });
        } else {
          setState(() {
            _previewImageUrl = null;
            _isLoadingImage = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _previewImageUrl = null;
            _isLoadingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _previewImageUrl = null;
          _isLoadingImage = false;
        });
      }
    }
  }

  bool _isValidImageUrl(String url) {
    if (url.isEmpty) return false;
    if (!url.startsWith('http://') && !url.startsWith('https://')) return false;

    final lowerUrl = url.toLowerCase();

    try {
      final uri = Uri.parse(url);
      final path = uri.path.toLowerCase();
      const imageExtensions = ['.jpg', '.jpeg', '.png', '.webp', '.gif', '.bmp', '.svg', '.avif', '.heic'];
      if (imageExtensions.any((ext) => path.endsWith(ext) || path.contains('$ext?') || path.contains('$ext&') || path.contains(ext))) {
        return true;
      }
    } catch (_) {}

    if (lowerUrl.contains('/is/image/') || lowerUrl.contains('/images/') || lowerUrl.contains('/image/')) {
      const htmlPagePatterns = ['/urun/', '-p-', '/item/', '/detail/', '.html', '.htm', '.php'];
      if (!htmlPagePatterns.any((pattern) => lowerUrl.contains(pattern))) {
        return true;
      }
    }

    const imageCdnPatterns = [
      'assets.mmsrg.com',
      'img.pzrmcdn.com',
      'cdn.dsmcdn.com',
      'hepsiburada.net',
      'images-amazon.com',
      'images-na.ssl-images-amazon.com',
      'media-amazon.com',
      'm.media-amazon.com',
      'ssl-images-amazon.com',
      'n11scdn.akamaized.net',
      'cdn.vatanbilgisayar.com',
      'yenieera22.com',
      'teknosa-cloud-prod.mncdn.com',
      'sky-static.mavi.com',
      'dfcdn.net',
      'static.zara.net',
      'media.mango.com',
      'st.mango.com',
      'st-mango.mncdn.com',
      'cdn.beymen.com',
      'cdn-s3.pttavm.com',
      'images.migrosone.com',
      'cdn.getir.com',
      'cdn.boyner.com.tr',
      'cdn03.ciceksepeti.net',
      'imgbb.co',
      'imgur.com',
      'i.ibb.co',
      'images.unsplash.com',
      'i.imgur.com',
      'cloudinary.com',
      'cloudfront.net',
    ];
    if (imageCdnPatterns.any((pattern) => lowerUrl.contains(pattern))) {
      const htmlPagePatterns = ['/urun/', '-p-', '/item/', '/detail/', '.html', '.htm', '.php'];
      if (!htmlPagePatterns.any((pattern) => lowerUrl.contains(pattern)) || lowerUrl.contains('.jpg') || lowerUrl.contains('.png') || lowerUrl.contains('.webp')) {
        return true;
      }
    }

    return false;
  }

  void _detectCategory() {
    if (_isCategoryLockedByScraper) return;

    final title = _titleController.text.trim();
    final description = _descriptionController.text.trim();

    if (title.isEmpty && description.isEmpty) return;

    final combinedText = '$title $description';
    final result = CategoryDetectionService.detectCategory(
      combinedText,
      url: _urlController.text.trim(),
      store: _selectedStore,
    );

    if (result != null && mounted) {
      final categoryId = result['categoryId'];
      final subCategory = result['subCategory'];

      if (categoryId != null && categoryId != _selectedCategory) {
        _isAutoDetecting = true;
        setState(() {
          _selectedCategory = categoryId;
          _selectedSubCategory = subCategory;
        });
        _isAutoDetecting = false;
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
      return '${category.name} › $_selectedSubCategory';
    }
    return category.name;
  }

  void _showCategorySelector() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CategorySelectorWidget(
        selectedCategoryId: _selectedCategory,
        selectedSubCategory: _selectedSubCategory,
        onCategorySelected: (categoryId, subCategory) {
          setState(() {
            _isCategoryLockedByScraper = false;
            _isAutoDetecting = false;
            _selectedCategory = categoryId;
            _selectedSubCategory = subCategory;
          });

          final category = Category.getById(categoryId);
          _showCustomSnackBar(
            message: 'Kategori: ${category.name}${subCategory != null ? " › $subCategory" : ""}',
            icon: Icons.check_circle_rounded,
            backgroundColor: const Color(0xFF2E7D32),
            duration: const Duration(seconds: 2),
          );
        },
      ),
    );
  }

  Future<void> _submitDeal() async {
    HapticFeedback.mediumImpact();
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
      _showCustomSnackBar(
        message: 'Lütfen zorunlu alanları eksiksiz doldurun.',
        icon: Icons.error_outline_rounded,
        backgroundColor: const Color(0xFFC62828),
      );
      return;
    }

    final urlControllerText = _urlController.text.trim();
    final validationResult = await DomainAllowlistService.validateUrl(urlControllerText);
    if (validationResult != UrlValidationResult.valid) {
      _showUrlValidationErrorDialog(validationResult);
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
      final categoryId = _selectedCategory;
      final subCategoryName = _selectedSubCategory;

      String imageUrl = _imageUrlController.text.trim();
      final isValidImageUrl = imageUrl.isNotEmpty && _isValidImageUrl(imageUrl);

      if ((imageUrl.isEmpty || !isValidImageUrl) && urlControllerText.isNotEmpty) {
        try {
          final preview = await _linkPreviewService.fetchMetadata(urlControllerText)
              .timeout(const Duration(seconds: 10), onTimeout: () => null);

          if (preview?.imageUrl != null && preview!.imageUrl!.isNotEmpty) {
            imageUrl = preview.imageUrl!;
            if (mounted) {
              _imageUrlController.text = imageUrl;
            }
          }
        } catch (_) {}
      }

      try {
        await _firestoreService.createDeal(
          title: _titleController.text.trim(),
          description: AdvertisingComplianceService.ensureDisclosure(_descriptionController.text.trim()),
          price: double.tryParse(_priceController.text.trim()) ?? 0.0,
          store: _storeController.text.trim(),
          category: categoryId,
          subCategory: subCategoryName,
          imageUrl: imageUrl,
          url: _urlController.text.trim(),
          userId: user.uid,
          postedByName: user.displayName,
          postedByAvatar: user.photoURL != null ? migrateAssetPath(user.photoURL!) : null,
          originalPrice: _scrapedOriginalPrice,
          priceLabel: _priceLabel,
          ratingValue: _scrapedRatingValue,
          ratingCount: _scrapedRatingCount,
          brand: _scrapedBrand,
          isAmazonWarehouse: _isAmazonWarehouse,
          hidePrice: _hidePrice,
        );

        if (mounted) {
          Navigator.pop(context);
          _showCustomSnackBar(
            message: '🎉 Fırsat başarıyla paylaşıldı!',
            icon: Icons.check_circle_rounded,
            backgroundColor: AppTheme.primary,
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
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(
                Icons.info_outline_rounded,
                color: AppTheme.primary,
                size: 26,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Bu Ürün Zaten Paylaşıldı',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          content: const Text(
            'Paylaşmaya çalıştığınız ürünün aktif bir paylaşımı zaten mevcut. '
            'Yeni bir mükerrer konu açmak yerine, mevcut fırsata giderek oy verebilir veya yorum yazabilirsiniz.',
            style: TextStyle(fontSize: 13.5, height: 1.4),
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
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: () {
                Navigator.pop(context);
                if (mounted) {
                  Navigator.pop(context);
                }
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DealDetailScreen(dealId: dealId),
                  ),
                );
              },
              child: const Text('Fırsata Git ↗', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  // --- UI ROOT BUILDER ---

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = _authService.currentUser;

    if (currentUser == null) {
      return _buildGuestLoginView(isDark);
    }

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Fırsat Paylaş',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 19,
            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Geri',
        ),
      ),
      bottomNavigationBar: _buildStickySubmitBar(isDark),
      body: StreamBuilder<bool>(
        stream: _firestoreService.dealSharingEnabledStream(),
        builder: (context, snapshot) {
          final isEnabled = snapshot.data ?? true;

          return Form(
            key: _formKey,
            child: ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 36),
              children: [
                // 1. Paylaşım Durduruldu Bildirimi
                if (!isEnabled) _buildSharingDisabledAlert(isDark),

                // 2. Sihirli Link & Otomatik Tarama Alanı
                _buildMagicLinkSection(isDark),

                const SizedBox(height: 20),

                // 3. Canlı Fırsat Vitrini (Hero Live Preview)
                _buildLiveHeroPreviewCard(isDark),

                const SizedBox(height: 20),

                // 4. Form Alanları (Skeleton Loader veya Kartlar - Akıcı Geçiş)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 550),
                  reverseDuration: const Duration(milliseconds: 250),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    final offsetAnimation = Tween<Offset>(
                      begin: const Offset(0.0, 0.05),
                      end: Offset.zero,
                    ).animate(CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ));

                    return FadeTransition(
                      opacity: CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOut,
                      ),
                      child: SlideTransition(
                        position: offsetAnimation,
                        child: child,
                      ),
                    );
                  },
                  child: _isAutoDetecting
                      ? KeyedSubtree(
                          key: const ValueKey('form_skeleton'),
                          child: _buildModernSkeletonLoader(isDark),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('form_loaded'),
                          child: _buildFormSections(isDark),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  // --- GUEST LOGIN PROMPT ---
  Widget _buildGuestLoginView(bool isDark) {
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Fırsat Paylaş',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_fire_department_rounded,
                  size: 40,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'Fırsat Paylaşmak İçin Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                  letterSpacing: -0.4,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Yakaladığınız indirimleri FırsatKolik topluluğuyla paylaşarak sıcak fırsatları herkese duyurun.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showGuestLoginBottomSheet(
                      context,
                      title: 'Fırsat Paylaşmak İçin Giriş Yap! 🚀',
                      message: 'Yakaladığın harika fırsatı tüm toplulukla paylaşmak için hızlıca giriş yap.',
                      primaryButtonText: '🚀 Google ile Giriş Yap',
                      onLoginSuccess: () => setState(() {}),
                    );
                  },
                  icon: const Icon(Icons.login_rounded, size: 18),
                  label: const Text(
                    'Giriş Yap ve Paylaş',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- SHARING DISABLED ALERT ---
  Widget _buildSharingDisabledAlert(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF451A03).withValues(alpha: 0.6) : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? const Color(0xFFB45309) : const Color(0xFFF59E0B),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pause_circle_filled_rounded,
            color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Fırsat paylaşımı şu anda bakım nedeniyle geçici olarak durdurulmuştur.',
              style: TextStyle(
                color: isDark ? const Color(0xFFFDE68A) : const Color(0xFF92400E),
                fontWeight: FontWeight.w700,
                fontSize: 12.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 1: MAGIC LINK & BOTKOLIK BAR (SPACIOUS NOTCHED BORDER DESIGN) ---
  Widget _buildMagicLinkSection(bool isDark) {
    final isUrlFilled = _urlController.text.isNotEmpty;
    final pageBgColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final borderColor = isUrlFilled
        ? AppTheme.primary.withValues(alpha: 0.6)
        : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0));

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(16, 26, 16, 18),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                controller: _urlController,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                style: TextStyle(
                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                minLines: 1,
                decoration: InputDecoration(
                  hintText: 'https://www.trendyol.com/... veya https://ty.gl/...',
                  hintStyle: TextStyle(
                    color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                    fontSize: 12.5,
                  ),
                  filled: true,
                  fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.transparent,
                      width: 1,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                  ),
                  suffixIcon: _urlController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.cancel_rounded, size: 18),
                          color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            _urlController.clear();
                            _formKey.currentState?.validate();
                          },
                          tooltip: 'Temizle',
                        )
                      : null,
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Ürün linki boş bırakılamaz';
                  }
                  if (!value.trim().startsWith('http')) {
                    return 'Geçerli bir web linki (http/https) giriniz';
                  }
                  return null;
                },
              ),
              if (_showInfoBanner) ...[
                const SizedBox(height: 14),
                _BotkolikAnimatedAttentionBanner(
                  isDark: isDark,
                  onClose: () => setState(() => _showInfoBanner = false),
                ),
              ],
            ],
          ),
        ),

        // Embedded Notched Title on top border line
        Positioned(
          top: 0,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
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
                    const Icon(Icons.link_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Ürün Linki (URL)',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (_urlController.text.isEmpty)
                InkWell(
                  onTap: _pasteFromClipboard,
                  borderRadius: BorderRadius.circular(8),
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
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.content_paste_rounded, size: 13, color: AppTheme.primary),
                        SizedBox(width: 5),
                        Text(
                          'Yapıştır',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  // --- SECTION 2: HERO LIVE DEAL PREVIEW CARD (SPACIOUS NOTCHED BORDER & ANIMATED TRANSITIONS) ---
  Widget _buildLiveHeroPreviewCard(bool isDark) {
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim();
    final price = double.tryParse(priceText) ?? 0.0;
    final store = _selectedStore ?? _storeController.text.trim();

    final bool hasData = _previewImageUrl != null || title.isNotEmpty || price > 0 || _isAutoDetecting;

    if (!hasData) {
      return const SizedBox.shrink();
    }

    final shimmerBase = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE2E8F0);
    final shimmerHighlight = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF8FAFC);
    final pageBgColor = isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC);
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 14),
          padding: const EdgeInsets.fromLTRB(14, 26, 14, 14),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.035),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: borderColor,
              width: 1.2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Content with Fluid Animated Switcher
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 500),
                reverseDuration: const Duration(milliseconds: 250),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.04),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                      child: child,
                    ),
                  );
                },
                child: _isAutoDetecting
                    ? _buildPreviewShimmerBody(isDark, shimmerBase, shimmerHighlight)
                    : _buildPreviewLoadedBody(isDark, title, price, store),
              ),

              // Expandable Image URL editing bar
              if (_showManualImageInput) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageUrlController,
                  style: TextStyle(color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A), fontSize: 12),
                  decoration: InputDecoration(
                    labelText: 'Görsel URL Bağlantısı',
                    hintText: 'https://.../resim.jpg',
                    isDense: true,
                    filled: true,
                    fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: isDark ? AppTheme.darkBorder : Colors.transparent),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
                    ),
                    prefixIcon: const Icon(Icons.image_outlined, size: 16),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Embedded Notched Title on top border line
        Positioned(
          top: 0,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
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
                    const Icon(Icons.remove_red_eye_rounded, size: 14, color: AppTheme.primary),
                    const SizedBox(width: 6),
                    Text(
                      'Canlı Fırsat Önizlemesi',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation), child: child),
                ),
                child: _isAutoDetecting
                    ? Container(
                        key: const ValueKey('scanning_tag'),
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: pageBgColor,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.primary.withValues(alpha: 0.6),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: AppTheme.primary, width: 1),
                              ),
                              child: ClipOval(
                                child: Image.asset('assets/botkolik.webp', fit: BoxFit.cover),
                              ),
                            ),
                            const SizedBox(width: 5),
                            const Text(
                              'Botkolik tarıyor...',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                      )
                    : (title.isNotEmpty || price > 0)
                        ? Container(
                            key: const ValueKey('ready_tag'),
                            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                            decoration: BoxDecoration(
                              color: pageBgColor,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: const Color(0xFF16A34A).withValues(alpha: 0.6),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle_rounded, size: 13, color: Color(0xFF16A34A)),
                                SizedBox(width: 5),
                                Text(
                                  'Bilgiler Hazır',
                                  style: TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF16A34A),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('empty_tag')),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Preview Shimmer Body
  Widget _buildPreviewShimmerBody(bool isDark, Color shimmerBase, Color shimmerHighlight) {
    return KeyedSubtree(
      key: const ValueKey('preview_shimmer_body'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Shimmer
          Shimmer.fromColors(
            baseColor: shimmerBase,
            highlightColor: shimmerHighlight,
            child: Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: isDark ? Colors.grey[700] : Colors.grey[400],
                  size: 24,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Text Shimmers
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges Shimmer
                Shimmer.fromColors(
                  baseColor: shimmerBase,
                  highlightColor: shimmerHighlight,
                  child: Row(
                    children: [
                      Container(
                        height: 16,
                        width: 75,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        height: 16,
                        width: 55,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Title Shimmer
                Shimmer.fromColors(
                  baseColor: shimmerBase,
                  highlightColor: shimmerHighlight,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        height: 12,
                        width: 110,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Price Shimmer
                Shimmer.fromColors(
                  baseColor: shimmerBase,
                  highlightColor: shimmerHighlight,
                  child: Container(
                    height: 15,
                    width: 75,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Loaded Preview Body
  Widget _buildPreviewLoadedBody(
    bool isDark,
    String title,
    double price,
    String store,
  ) {
    return KeyedSubtree(
      key: const ValueKey('preview_loaded_body'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image Box with Tap-to-edit
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _showManualImageInput = !_showManualImageInput);
            },
            child: Stack(
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: (_previewImageUrl != null && _previewImageUrl!.isNotEmpty)
                        ? CachedNetworkImage(
                            imageUrl: _previewImageUrl!,
                            fit: BoxFit.contain,
                            fadeInDuration: const Duration(milliseconds: 450),
                            fadeInCurve: Curves.easeOutCubic,
                            errorWidget: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image_rounded, color: Colors.grey, size: 24),
                            ),
                          )
                        : Center(
                            child: Icon(
                              Icons.add_photo_alternate_rounded,
                              size: 28,
                              color: isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1),
                            ),
                          ),
                  ),
                ),
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    padding: const EdgeInsets.all(3.5),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
                    ),
                    child: const Icon(Icons.edit_rounded, size: 9.5, color: AppTheme.primary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),

          // Product Info Column
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badges Wrap (Zero Overflow)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    if (store.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Image.asset(
                              _getStoreAsset(store),
                              width: 13,
                              height: 13,
                              errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 13),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              store,
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                              ),
                            ),
                            if (_isSpecialBadgeEnabled && _priceLabel != null && _priceLabel!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              StorePriceBadge(
                                label: _priceLabel,
                                store: store,
                                compact: true,
                                compactSize: 13.0,
                              ),
                            ],
                          ],
                        ),
                      ),
                    if (_scrapedBrand != null && _scrapedBrand!.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _scrapedBrand!,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                      ),
                    if (_isAmazonWarehouse)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          '📦 Amazon Depo',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFFD97706),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),

                // Title
                Text(
                  title.isNotEmpty ? title : 'Ürün Başlığı',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 5),

                // Price Wrap
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 6,
                  runSpacing: 3,
                  children: [
                    if (_hidePrice)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFE2E8F0),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'Fiyatsız Kampanya',
                          style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      )
                    else ...[
                      Text(
                        price > 0 ? '${price.toStringAsFixed(price.truncateToDouble() == price ? 0 : 2)} ₺' : '0 ₺',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      if (_scrapedOriginalPrice != null && _scrapedOriginalPrice! > price) ...[
                        Text(
                          '${_scrapedOriginalPrice!.toStringAsFixed(0)} ₺',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark ? const Color(0xFF71717A) : const Color(0xFF94A3B8),
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            '%${(((_scrapedOriginalPrice! - price) / _scrapedOriginalPrice!) * 100).round()} İndirim',
                            style: const TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 3: SKELETON LOADER ---
  Widget _buildModernSkeletonLoader(bool isDark) {
    final baseColor = isDark ? const Color(0xFF1C1C1C) : const Color(0xFFE2E8F0);
    final highlightColor = isDark ? const Color(0xFF2C2C2C) : const Color(0xFFF1F5F9);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Column(
        children: [
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 130,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
          ),
        ],
      ),
    );
  }

  // --- SECTION 4: FORM FIELDS CONTAINER (SPACIOUS & REORDERED LAYOUT) ---
  Widget _buildFormSections(bool isDark) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. KART: ÜRÜN VE KATEGORİ BİLGİLERİ (ÖNEMLİ BİLGİLER EN ÜSTTE)
        _buildNotchedCardContainer(
          isDark: isDark,
          title: 'Ürün ve Kategori Bilgileri',
          icon: Icons.category_rounded,
          children: [
            // Başlık
            TextFormField(
              controller: _titleController,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w600, fontSize: 13.5),
              decoration: InputDecoration(
                labelText: 'Fırsat Başlığı *',
                hintText: 'Örn: Sony WH-1000XM5 Kablosuz Kulaklık',
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
              ),
              maxLines: 2,
              minLines: 1,
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Başlık zorunludur';
                }
                if (val.trim().length < 5) {
                  return 'Başlık en az 5 karakter olmalıdır';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Kategori Seçici
            InkWell(
              onTap: _showCategorySelector,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      Category.getById(_selectedCategory).icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kategori *',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _getCategoryDisplayText(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: Colors.grey),
                  ],
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 20),

        // 2. KART: FİYAT VE MAĞAZA BİLGİLERİ
        _buildNotchedCardContainer(
          isDark: isDark,
          title: 'Fiyat ve Mağaza Bilgileri',
          icon: Icons.payments_rounded,
          children: [
            // Fiyat Girişi
            TextFormField(
              controller: _priceController,
              enabled: !_hidePrice,
              style: TextStyle(color: textColor, fontWeight: FontWeight.w700, fontSize: 15),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Fiyat (₺) *',
                hintText: '0.00',
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                prefixIcon: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    '₺',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.primary),
                  ),
                ),
                prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
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
              ),
              validator: (value) {
                if (_hidePrice) return null;
                if (value == null || value.trim().isEmpty) {
                  return 'Lütfen bir fiyat giriniz';
                }
                if (double.tryParse(value.trim()) == null) {
                  return 'Geçerli bir sayı giriniz';
                }
                return null;
              },
            ),

            const SizedBox(height: 16),

            // Mağaza Seçimi
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _selectedStore,
              menuMaxHeight: 300,
              isExpanded: true,
              dropdownColor: isDark ? AppTheme.darkSurface : Colors.white,
              style: TextStyle(color: textColor, fontSize: 13.5, fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                labelText: 'Satıcı / Mağaza *',
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
              items: _stores.map((store) {
                return DropdownMenuItem<String>(
                  value: store,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Image.asset(
                        _getStoreAsset(store),
                        width: 18,
                        height: 18,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const Icon(Icons.store, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        store,
                        style: TextStyle(color: textColor, fontSize: 13.5),
                      ),
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
                  return 'Lütfen mağaza seçiniz';
                }
                return null;
              },
            ),

            if (_selectedStore == 'Diğer') ...[
              const SizedBox(height: 14),
              TextFormField(
                controller: _customStoreController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: 'Özel Mağaza Adı *',
                  hintText: 'Örn: CarrefourSA, MediaMarkt vb.',
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
                  prefixIcon: const Icon(Icons.edit_note_rounded),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                ),
                onChanged: (val) => _storeController.text = val.trim(),
                validator: (val) {
                  if (_selectedStore == 'Diğer' && (val == null || val.trim().isEmpty)) {
                    return 'Mağaza adını giriniz';
                  }
                  return null;
                },
              ),
            ],

            const SizedBox(height: 12),

            // Minimalist Ayırıcı & İkincil Seçenekler
            Divider(
              height: 1,
              thickness: 0.8,
              color: isDark ? AppTheme.darkBorder.withValues(alpha: 0.6) : const Color(0xFFE2E8F0),
            ),

            const SizedBox(height: 6),

            // 1. Fiyatı Gizle (Fiyatsız Kampanya)
            _buildMinimalToggleRow(
              isDark: isDark,
              icon: Icons.visibility_off_outlined,
              title: 'Fiyatsız kampanya veya duyuru',
              value: _hidePrice,
              onChanged: (val) => setState(() => _hidePrice = val),
            ),

            // 2. Amazon Depo Ürünü (Yalnızca Amazon Seçildiğinde)
            if (_selectedStore == 'Amazon') ...[
              _buildMinimalToggleRow(
                isDark: isDark,
                icon: Icons.inventory_2_outlined,
                title: 'Amazon Depo ürünü (2. El / Açık kutu)',
                value: _isAmazonWarehouse,
                activeColor: const Color(0xFFD97706),
                onChanged: (val) => setState(() => _isAmazonWarehouse = val),
              ),
            ],

            // 3. Özel Üyelik / Fiyat Rozeti (Prime, Plus, Premium, Money vb.)
            if (_hasStoreBadgeSupport(_selectedStore ?? _storeController.text) || (_detectedPriceLabel != null && _detectedPriceLabel!.isNotEmpty) || (_priceLabel != null && _priceLabel!.isNotEmpty)) ...[
              _buildSpecialBadgeToggleRow(isDark),
            ],
          ],
        ),

        const SizedBox(height: 20),

        // 3. KART: FIRSAT DETAYLARI & NOTLAR (EN ALTTA)
        _buildNotchedCardContainer(
          isDark: isDark,
          title: 'Fırsat Detayları & Notlar',
          icon: Icons.notes_rounded,
          children: [
            TextFormField(
              controller: _descriptionController,
              style: TextStyle(color: textColor, fontSize: 13, height: 1.45),
              maxLines: 4,
              minLines: 3,
              decoration: InputDecoration(
                labelText: 'Fırsat Detayları *',
                hintText: 'İndirimin geçerli olduğu koşullar, sepet indirimleri, kupon detayları...',
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
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Açıklama alanı zorunludur';
                }
                return null;
              },
            ),
          ],
        ),
      ],
    );
  }

  // Helper notched card container builder (Fieldset / Legend style with generous breathing room)
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
        // Main Outlined Box
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

        // Notched Title Badge (Embedded directly on top border line with crisp border & padding)
        Positioned(
          top: 0,
          left: 16,
          right: trailing != null ? 16 : null,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
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
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B),
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ],
    );
  }

  // Helper minimalist toggle row for secondary options (consistent switch/label layout)
  Widget _buildMinimalToggleRow({
    required bool isDark,
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    Color? activeColor,
  }) {
    final effectiveActiveColor = activeColor ?? AppTheme.primary;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onChanged(!value);
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          children: [
            Icon(
              icon,
              size: 17,
              color: value ? effectiveActiveColor : secondaryTextColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: value ? FontWeight.w700 : FontWeight.w500,
                  color: value ? (isDark ? Colors.white : const Color(0xFF0F172A)) : textColor.withValues(alpha: 0.85),
                ),
              ),
            ),
            Transform.scale(
              scale: 0.78,
              child: Switch(
                value: value,
                activeTrackColor: effectiveActiveColor,
                activeThumbColor: Colors.white,
                onChanged: (val) {
                  HapticFeedback.selectionClick();
                  onChanged(val);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _hasStoreBadgeSupport(String? store) {
    if (store == null) return false;
    final lower = store.toLowerCase();
    return lower.contains('amazon') ||
        lower.contains('trendyol') ||
        lower.contains('hepsiburada') ||
        lower.contains('pazarama') ||
        lower.contains('migros');
  }

  bool _isMembershipBadgeLabel(String label) {
    final upper = label.trim().toUpperCase();
    // Çoklu alım / sepet / hediye / TL üzeri kampanyaları üyelik rozeti switch'i değildir
    if (upper.contains('AL') ||
        upper.contains('HEDİYE') ||
        upper.contains('HEDIYE') ||
        upper.contains('SEPETTE') ||
        upper.contains('ÖDE') ||
        upper.contains('ODE') ||
        upper.contains('ADET') ||
        upper.contains('TL ÜZERİ')) {
      return false;
    }
    return upper == 'MONEY İLE' ||
        upper == 'MONEY ILE' ||
        upper == 'MONEY KART İLE' ||
        upper == 'MONEY KART ILE' ||
        upper == 'MONEY İNDİRİMLİ' ||
        upper == 'MONEY INDIRIMLI' ||
        upper == 'MONEY' ||
        upper.contains('PRIME') ||
        upper.contains('PLUS') ||
        upper.contains('PREMIUM');
  }

  String _getDefaultPriceLabelForStore(String? store) {
    if (store == null) return 'Özel Fiyat';
    final lower = store.toLowerCase();
    if (lower.contains('amazon')) return 'Prime Fırsatı';
    if (lower.contains('trendyol')) return "Plus'a Özel";
    if (lower.contains('hepsiburada')) return 'Premium ile';
    if (lower.contains('pazarama')) return 'Plus ile';
    if (lower.contains('migros')) return 'Money ile';
    return 'Özel Fiyat';
  }

  String _getStoreBadgeTitle(String? store, String? priceLabel) {
    if (priceLabel != null && priceLabel.isNotEmpty && _isMembershipBadgeLabel(priceLabel)) {
      return priceLabel;
    }
    return _getDefaultPriceLabelForStore(store);
  }

  void _onToggleSpecialBadge(bool val) {
    HapticFeedback.selectionClick();
    setState(() {
      _isSpecialBadgeEnabled = val;
      if (val) {
        _priceLabel = (_detectedPriceLabel != null && _isMembershipBadgeLabel(_detectedPriceLabel!))
            ? _detectedPriceLabel
            : _getDefaultPriceLabelForStore(_selectedStore ?? _storeController.text);
      } else {
        // Eğer detectedPriceLabel genel kampanya metni ise (örn: 3 Al 2 Öde) onu koru, değilse null yap
        if (_detectedPriceLabel != null && !_isMembershipBadgeLabel(_detectedPriceLabel!)) {
          _priceLabel = _detectedPriceLabel;
        } else {
          _priceLabel = null;
        }
      }
    });
  }

  // Özel Fiyat & Üyelik Rozeti Minimalist Toggle Satırı (Prime, Plus, Premium vb.)
  Widget _buildSpecialBadgeToggleRow(bool isDark) {
    final effectiveStore = _selectedStore ?? _storeController.text.trim();
    final effectiveLabel = (_priceLabel != null && _isMembershipBadgeLabel(_priceLabel!))
        ? _priceLabel!
        : (_detectedPriceLabel != null && _isMembershipBadgeLabel(_detectedPriceLabel!))
            ? _detectedPriceLabel!
            : _getDefaultPriceLabelForStore(effectiveStore);
    final badgeTitle = _getStoreBadgeTitle(effectiveStore, effectiveLabel);

    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    // Amblem harfi tespiti
    String emblem = 'P';
    final lblUpper = effectiveLabel.toUpperCase();
    final strLower = effectiveStore.toLowerCase();
    if (lblUpper.contains('MONEY') || strLower.contains('migros')) {
      emblem = 'M';
    } else if (lblUpper.contains('PLUS') || strLower.contains('trendyol') || strLower.contains('pazarama')) {
      emblem = '+';
    }

    return InkWell(
      onTap: () => _onToggleSpecialBadge(!_isSpecialBadgeEnabled),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Row(
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: Tween<double>(begin: 0.85, end: 1.0).animate(animation),
                  child: child,
                ),
              ),
              child: _isSpecialBadgeEnabled
                  ? StorePriceBadge(
                      key: const ValueKey('active_badge_icon'),
                      label: effectiveLabel,
                      store: effectiveStore,
                      compact: true,
                      compactSize: 17,
                    )
                  : Container(
                      key: const ValueKey('inactive_badge_icon'),
                      width: 17,
                      height: 17,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                        border: Border.all(
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          emblem,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: secondaryTextColor,
                            height: 1.0,
                          ),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                badgeTitle,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: _isSpecialBadgeEnabled ? FontWeight.w700 : FontWeight.w500,
                  color: _isSpecialBadgeEnabled
                      ? (isDark ? Colors.white : const Color(0xFF0F172A))
                      : textColor.withValues(alpha: 0.85),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Transform.scale(
              scale: 0.78,
              child: Switch(
                value: _isSpecialBadgeEnabled,
                activeTrackColor: const Color(0xFF8B5CF6),
                activeThumbColor: Colors.white,
                onChanged: _onToggleSpecialBadge,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- STICKY FLOATING SUBMIT BAR ---
  Widget _buildStickySubmitBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface.withValues(alpha: 0.95) : Colors.white.withValues(alpha: 0.95),
        border: Border(
          top: BorderSide(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: (_isLoading || !_dealSharingEnabled) ? null : _submitDeal,
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
                : const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.rocket_launch_rounded, size: 18),
                      SizedBox(width: 8),
                      Text(
                        'Fırsatı Toplulukla Paylaş',
                        style: TextStyle(
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

// ─────────────────────────────────────────────────────────────────────────────
// 🌟 BOTKOLIK ANIMATED ATTENTION BANNER (MINIMALIST & RADIANT MICRO-INTERACTION)
// ─────────────────────────────────────────────────────────────────────────────

class _BotkolikAnimatedAttentionBanner extends StatefulWidget {
  final bool isDark;
  final VoidCallback onClose;

  const _BotkolikAnimatedAttentionBanner({
    required this.isDark,
    required this.onClose,
  });

  @override
  State<_BotkolikAnimatedAttentionBanner> createState() =>
      _BotkolikAnimatedAttentionBannerState();
}

class _BotkolikAnimatedAttentionBannerState
    extends State<_BotkolikAnimatedAttentionBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _glowAnimation;
  late final Animation<double> _shimmerAngleAnimation;
  late final Animation<double> _breatheAnimation;

  @override
  void initState() {
    super.initState();
    // 3.5 saniyelik akıcı ve göz alıcı mikro-animasyon
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // Işıma / Gradient Parlaklık Eğrisi (Zarifçe parlar, döner ve son 1.5 saniyede ipeksi bir şekilde sönümlenir)
    _glowAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 15, // 0 - 525ms
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 42, // 525ms - 2000ms
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeInOutCubic)),
        weight: 43, // 2000ms - 3500ms (1.5 sn ultra yumuşak sönümleme)
      ),
    ]).animate(_controller);

    // Shimmer / Gradient rotasyon açısı
    _shimmerAngleAnimation = Tween<double>(begin: 0.0, end: 1.6).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic),
    );

    // Botkolik avatar hafif nabız (pulse) efekti
    _breatheAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.16)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.16, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.10)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 25,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.10, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 25,
      ),
    ]).animate(_controller);

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDark;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glow = _glowAnimation.value;
        final angle = _shimmerAngleAnimation.value;
        final breathe = _breatheAnimation.value;

        // Canlı ve Zengin Gradient Renkleri (FırsatKolik Turuncu + Altın Amber + Parlak Mavi)
        final gradientColors = isDark
            ? [
                const Color(0xFFFF6B35),
                const Color(0xFFFBBF24),
                const Color(0xFF38BDF8),
                const Color(0xFFFF6B35),
              ]
            : [
                const Color(0xFFFF4500),
                const Color(0xFFF59E0B),
                const Color(0xFF0284C7),
                const Color(0xFFFF4500),
              ];

        // Sönümlenmiş durağan sınır rengi (Aydınlık modda sıcak ve belirgin şeftali tonu)
        final settledBorderColor = isDark
            ? AppTheme.primary.withValues(alpha: 0.25)
            : const Color(0xFFFFD5C0);

        // Dinamik Zemin Rengi
        final baseBgColor = isDark
            ? AppTheme.darkSurfaceElevated
            : Colors.white;

        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              // Taban yumuşak kart gölgesi
              BoxShadow(
                color: Colors.black.withValues(
                    alpha: isDark ? 0.20 : 0.05 * (1.0 - 0.5 * glow)),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
              // Animasyonlu canlı dış ışıma (glow)
              if (glow > 0.01) ...[
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFFFF6B35)
                          : const Color(0xFFFF5722))
                      .withValues(alpha: (isDark ? 0.22 : 0.28) * glow),
                  blurRadius: (isDark ? 12.0 : 15.0) * glow,
                  spreadRadius: (isDark ? 1.0 : 1.5) * glow,
                  offset: const Offset(0, 2),
                ),
                BoxShadow(
                  color: (isDark
                          ? const Color(0xFF38BDF8)
                          : const Color(0xFF0284C7))
                      .withValues(alpha: (isDark ? 0.12 : 0.16) * glow),
                  blurRadius: 18 * glow,
                  offset: const Offset(0, 3),
                ),
              ],
            ],
          ),
          child: CustomPaint(
            painter: _GradientBorderPainter(
              borderRadius: 14,
              borderWidth: 1.1 + (0.7 * glow),
              gradientColors: gradientColors,
              glowProgress: glow,
              rotationTurns: angle,
              settledBorderColor: settledBorderColor,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
              decoration: BoxDecoration(
                color: baseBgColor,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Botkolik AI Avatar (Nefes Alma & Işıma Efekti)
                  Transform.scale(
                    scale: breathe,
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: glow > 0.01
                            ? [
                                BoxShadow(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.40 * glow),
                                  blurRadius: 8 * glow,
                                  spreadRadius: 1 * glow,
                                ),
                              ]
                            : null,
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/botkolik.webp',
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.smart_toy_rounded,
                            size: 20,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),

                  // 2. Metin Alanı
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 🌟 "Bot" + "kolik" + " Akıllı Asistan" Tipografisi
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Bot',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                              const TextSpan(
                                text: 'kolik',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -0.2,
                                  color: AppTheme.primary,
                                ),
                              ),
                              TextSpan(
                                text: ' Akıllı Asistan',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.2,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF334155),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        RichText(
                          text: TextSpan(
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.38,
                              color: isDark
                                  ? const Color(0xFFCBD5E1)
                                  : const Color(0xFF334155),
                            ),
                            children: const [
                              TextSpan(
                                  text:
                                      'Linki yapıştırdığınızda ürün detayları yapay zeka ile otomatik çekilir. İnceleyip eksikleri tamamlayabilirsiniz.'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),

                  // 3. Kapatma Butonu
                  InkWell(
                    onTap: widget.onClose,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(3.0),
                      child: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: isDark
                            ? AppTheme.darkTextSecondary
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _GradientBorderPainter extends CustomPainter {
  final double borderRadius;
  final double borderWidth;
  final List<Color> gradientColors;
  final double glowProgress;
  final double rotationTurns;
  final Color settledBorderColor;

  _GradientBorderPainter({
    required this.borderRadius,
    required this.borderWidth,
    required this.gradientColors,
    required this.glowProgress,
    required this.rotationTurns,
    required this.settledBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(borderRadius));

    // 1. Zemin Durağan Çerçeveyi Çiz (Sürekli ve Kesintisiz)
    final basePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..color = settledBorderColor;
    canvas.drawRRect(rrect, basePaint);

    // 2. Canlı Dönen Gradient Katmanı (glowProgress ile kusursuz alfa çarpımı)
    if (glowProgress > 0.001) {
      // Renklerin şeffaflığı glowProgress ile pürüzsüzce sıfıra iner
      final activeColors = gradientColors
          .map((c) => c.withValues(alpha: c.a * glowProgress))
          .toList();

      final angle = rotationTurns * math.pi * 2;
      final gradient = SweepGradient(
        colors: activeColors,
        transform: GradientRotation(angle),
      );

      final glowPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = borderWidth
        ..shader = gradient.createShader(rect);

      canvas.drawRRect(rrect, glowPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GradientBorderPainter oldDelegate) {
    return oldDelegate.glowProgress != glowProgress ||
        oldDelegate.rotationTurns != rotationTurns ||
        oldDelegate.settledBorderColor != settledBorderColor;
  }
}
