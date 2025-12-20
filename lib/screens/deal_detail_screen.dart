import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import '../models/deal.dart';
import '../models/comment.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_selector_widget.dart';

class DealDetailScreen extends StatefulWidget {
  final String dealId;

  const DealDetailScreen({
    super.key,
    required this.dealId,
  });

  @override
  State<DealDetailScreen> createState() => _DealDetailScreenState();
}

class _DealDetailScreenState extends State<DealDetailScreen> {
  String? _fetchedImageUrl;
  bool _isFetchingImage = false;
  bool _hasTriedFetching = false;
  bool _originalImageFailed = false; // Orijinal görsel yüklenemedi mi?
  Deal? _currentDeal;
  final LinkPreviewService _linkPreviewService = LinkPreviewService();
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isAdmin = false;
  bool _isFavorite = false;
  bool _isLoadingFavorite = false;
  bool _hasVotedHot = false;
  bool _hasVotedCold = false;
  bool _hasVotedExpired = false;
  bool _isHotVoting = false;
  bool _isColdVoting = false;
  bool _isExpiredVoting = false;
  int _hotVotes = 0;
  int _coldVotes = 0;
  int _expiredVotes = 0;
  bool _isEditingPrice = false;
  final TextEditingController _priceEditController = TextEditingController();
  bool _isEditingCategory = false;

  @override
  void initState() {
    super.initState();
    _loadDeal();
    _checkAdminStatus();
    _checkFavoriteStatus();
    _checkUserVote();
  }

  @override
  void dispose() {
    _priceEditController.dispose();
    super.dispose();
  }

  Future<void> _checkFavoriteStatus() async {
    final user = _authService.currentUser;
    if (user == null) return;
    
    final isFavorite = await _firestoreService.isFavorite(user.uid, widget.dealId);
    if (mounted) {
      setState(() {
        _isFavorite = isFavorite;
      });
    }
  }

  Future<void> _checkUserVote() async {
    final user = _authService.currentUser;
    if (user == null || _currentDeal == null) return;
    
    final vote = await _firestoreService.getUserVote(_currentDeal!.id, user.uid);
    if (mounted) {
      setState(() {
        _hasVotedHot = vote == 'hot';
        _hasVotedCold = vote == 'cold';
        _hasVotedExpired = vote == 'expired';
      });
    }
  }

  Future<void> _handleVote(bool isHot) async {
    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oy vermek için giriş yapmalısınız'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_currentDeal == null) return;

    // Eğer zaten aynı oya basılmışsa, işlem yapma
    if ((isHot && _hasVotedHot) || (!isHot && _hasVotedCold)) {
      return;
    }

    // Loading state
    setState(() {
      if (isHot) {
        _isHotVoting = true;
      } else {
        _isColdVoting = true;
      }
    });

    // Önceki oy durumunu kaydet
    final previousHotVote = _hasVotedHot;
    final previousColdVote = _hasVotedCold;
    final previousHotVotes = _hotVotes;
    final previousColdVotes = _coldVotes;

    // Optimistic UI update
    setState(() {
      if (isHot) {
        // Eğer daha önce cold vermişse, cold'u kaldır
        if (_hasVotedCold) {
          _hasVotedCold = false;
          _coldVotes = _coldVotes > 0 ? _coldVotes - 1 : 0;
        }
        _hasVotedHot = true;
        _hotVotes += 1;
      } else {
        // Eğer daha önce hot vermişse, hot'u kaldır
        if (_hasVotedHot) {
          _hasVotedHot = false;
          _hotVotes = _hotVotes > 0 ? _hotVotes - 1 : 0;
        }
        _hasVotedCold = true;
        _coldVotes += 1;
      }
    });

    // Firestore'a kaydet
    final success = isHot
        ? await _firestoreService.addHotVote(_currentDeal!.id, user.uid)
        : await _firestoreService.addColdVote(_currentDeal!.id, user.uid);

    if (!success && mounted) {
      // Hata durumunda önceki duruma geri dön
      setState(() {
        _hasVotedHot = previousHotVote;
        _hasVotedCold = previousColdVote;
        _hotVotes = previousHotVotes;
        _coldVotes = previousColdVotes;
        if (isHot) {
          _isHotVoting = false;
        } else {
          _isColdVoting = false;
        }
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oy gönderilirken bir hata oluştu. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Deal'i yeniden yükle
    _loadDeal();
    _checkUserVote();

    if (!mounted) return;

    setState(() {
      if (isHot) {
        _isHotVoting = false;
      } else {
        _isColdVoting = false;
      }
    });
  }

  Future<void> _toggleFavorite() async {
    final user = _authService.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingFavorite = true;
      _isFavorite = !_isFavorite; // Optimistic update
    });

    final success = _isFavorite
        ? await _firestoreService.addToFavorites(user.uid, widget.dealId)
        : await _firestoreService.removeFromFavorites(user.uid, widget.dealId);

    if (!success && mounted) {
      setState(() {
        _isFavorite = !_isFavorite; // Revert on error
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Favorilere eklenemedi' : 'Favorilerden çıkarılamadı'),
          backgroundColor: Colors.red,
        ),
      );
    }

    if (mounted) {
      setState(() {
        _isLoadingFavorite = false;
      });
    }
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  Future<void> _loadDeal() async {
    final firestoreService = FirestoreService();
    try {
      final deal = await firestoreService.getDeal(widget.dealId);
      if (mounted && deal != null) {
        setState(() {
          _currentDeal = deal;
          _hotVotes = deal.hotVotes;
          _coldVotes = deal.coldVotes;
          _expiredVotes = deal.expiredVotes;
          _isEditingPrice = false; // Deal yüklendiğinde editing state'ini sıfırla
        });
        _checkUserVote();
        // Eğer görsel yoksa, linkten çekmeyi dene
        if (deal.imageUrl.isEmpty && deal.link.isNotEmpty && !_hasTriedFetching) {
          _fetchImageFromLink(deal.link);
        }
      }
    } catch (e) {
      print('Deal yükleme hatası: $e');
    }
  }

  Future<void> _fetchImageFromLink(String link) async {
    if (_isFetchingImage || _hasTriedFetching) return;
    
    setState(() {
      _isFetchingImage = true;
    });
    
    try {
      final preview = await _linkPreviewService.fetchMetadata(link);
      if (mounted && preview != null) {
        final imageUrl = preview.imageUrl;
        if (imageUrl != null && imageUrl.isNotEmpty) {
          setState(() {
            _fetchedImageUrl = imageUrl;
            _isFetchingImage = false;
            _hasTriedFetching = true;
          });
        } else {
          setState(() {
            _isFetchingImage = false;
            _hasTriedFetching = true;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isFetchingImage = false;
            _hasTriedFetching = true;
          });
        }
      }
    } catch (e) {
      print('Görsel çekme hatası: $e');
      if (mounted) {
        setState(() {
          _isFetchingImage = false;
          _hasTriedFetching = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // _currentDeal null ise loading göster
    if (_currentDeal == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return _buildDealDetail(context, _currentDeal!);
  }

  Widget _buildDealDetail(BuildContext context, Deal deal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currencyFormat = NumberFormat.currency(symbol: '₺', decimalDigits: 0);
    // Bot'tan gelen kategori ID olarak geliyor ("elektronik", "moda" vb.)
    // Önce ID olarak kontrol et, bulunamazsa name olarak dene
    Category category;
    final normalizedCategory = deal.category.trim().toLowerCase();
    try {
      category = Category.categories.firstWhere(
        (cat) => cat.id.toLowerCase() == normalizedCategory && cat.id != 'tumu',
        orElse: () => Category.categories.first,
      );
    } catch (e) {
      // ID bulunamazsa, name olarak dene
      final categoryId = Category.getIdByName(deal.category);
      category = categoryId != null && categoryId != 'tumu' 
          ? Category.getById(categoryId) 
          : Category.categories.first;
    }

    return PopScope(
      canPop: true,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          return;
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        body: Stack(
          children: [
          // Main Content
          Column(
            children: [
              // Fixed Header
              Container(
                padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
                child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: (isDark ? AppTheme.darkBackground : AppTheme.background).withValues(alpha: 0.85),
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                        width: 1,
                      ),
                    ),
                  ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                      // Geri butonu
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.black.withValues(alpha: 0.2) 
                              : Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => Navigator.of(context).pop(),
                            child: Icon(
                              Icons.arrow_back,
                              size: 20,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ),
                      // Başlık (merkezde)
                      Expanded(
                        child: Text(
                          'ÜRÜN DETAYI',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            letterSpacing: 4,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        ),
                      // Paylaş butonu
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark 
                              ? Colors.black.withValues(alpha: 0.2) 
                              : Colors.white.withValues(alpha: 0.5),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                            width: 0.5,
                          ),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(20),
                            onTap: () => _showShareOptions(context, deal),
                            child: Icon(
                              Icons.share,
                              size: 20,
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                          ),
                        ),
                  ),
                      // Admin düzenle butonu
                      if (_isAdmin) ...[
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.2),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3),
                              width: 0.5,
                            ),
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(20),
                              onTap: () => _showAdminEditDialog(deal),
                              child: Icon(
                                Icons.edit,
                                size: 20,
                                color: primaryColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                ],
              ),
            ),
              ),
              // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                      // Hero Image (4/3 aspect ratio)
                      AspectRatio(
                        aspectRatio: 4 / 3,
                      child: Stack(
                        children: [
                            // Image
                          GestureDetector(
                            onTap: () {
                              // Görsel URL'ini belirle
                              String? imageUrl;
                              if (!_originalImageFailed && deal.imageUrl.isNotEmpty) {
                                imageUrl = deal.imageUrl;
                              } else if (_fetchedImageUrl != null && _fetchedImageUrl!.isNotEmpty) {
                                imageUrl = _fetchedImageUrl;
                              }
                              // Görsel varsa göster
                              if (imageUrl != null && imageUrl.isNotEmpty) {
                                _showFullScreenImage(imageUrl);
                              }
                            },
                              child: Container(
                                width: double.infinity,
                                color: isDark ? Colors.grey[900] : Colors.white,
                                child: _buildDetailImage(deal),
                              ),
                            ),
                            // Gradient overlay
                            Positioned.fill(
                              child: IgnorePointer(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Colors.transparent,
                                        Colors.black.withValues(alpha: 0.2),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            // Discount Badge (sağ altta)
                          if (deal.discountRate != null && deal.discountRate! > 0)
                            Positioned(
                                bottom: 40,
                                right: 20,
                                child: Transform.rotate(
                                  angle: 0.21, // ~12 degrees
                              child: Container(
                                    width: 64,
                                    height: 64,
                                decoration: BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDark ? AppTheme.darkSurface : Colors.white,
                                        width: 2,
                                      ),
                                  boxShadow: [
                                    BoxShadow(
                                          color: primaryColor.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                  '%${deal.discountRate}',
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                            height: 1,
                                  ),
                                ),
                                        const Text(
                                          'İNDİRİM',
                                          style: TextStyle(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.black,
                                            height: 1,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Content Sheet (rounded-t-3xl, -mt-6)
                      Transform.translate(
                        offset: const Offset(0, -24),
                              child: Container(
                                decoration: BoxDecoration(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                                  boxShadow: [
                                    BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                                blurRadius: 40,
                                offset: const Offset(0, -10),
                                    ),
                                  ],
                            border: Border(
                              top: BorderSide(
                                color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                                width: 1,
                              ),
                            ),
                                ),
                          child: Column(
                                  children: [
                              // Handle indicator
                              Padding(
                                padding: const EdgeInsets.only(top: 12, bottom: 8),
                                child: Container(
                                  width: 48,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.1),
                                    borderRadius: BorderRadius.circular(2),
                                    ),
                                ),
                              ),
                    Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                      child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Store + Category
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                color: isDark 
                                                    ? Colors.white.withValues(alpha: 0.05) 
                                                    : Colors.white,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                                                  width: 0.5,
                                                ),
                                              ),
                                              child: Icon(
                                                Icons.storefront,
                                                size: 20,
                                                color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                                                  'Satıcı',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                                    letterSpacing: 1.2,
                            ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                                    height: 1,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                            InkWell(
                              onTap: _isAdmin ? () => _showCategoryEditDialog(deal) : null,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: primaryColor.withValues(alpha: _isAdmin ? 0.5 : 0.2),
                                    width: _isAdmin ? 1.5 : 0.5,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      category.name.toUpperCase(),
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? primaryColor : Colors.black,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                    if (_isAdmin) ...[
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.edit,
                                        size: 12,
                                        color: primaryColor,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                                      ],
                            ),
                                    const SizedBox(height: 24),
                                    // Editör Seçimi Badge
                                    if (deal.isEditorPick)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 12),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [Colors.orange[700]!, Colors.orange[500]!],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(8),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.orange.withValues(alpha: 0.3),
                                                    blurRadius: 4,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ],
                                              ),
                                              child: const Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.star,
                                                    color: Colors.white,
                                                    size: 14,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    'Editörün Seçimi',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      letterSpacing: 0.5,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    // Title
                                    Text(
                                      deal.title,
                                      style: TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppTheme.textPrimary,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Price Card
                                    InkWell(
                                      onTap: _isAdmin ? () => _showPriceEditDialog(deal) : null,
                                      borderRadius: BorderRadius.circular(16),
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: isDark ? AppTheme.darkBackground : AppTheme.background,
                                          borderRadius: BorderRadius.circular(16),
                                          border: Border.all(
                                            color: _isAdmin 
                                                ? primaryColor.withValues(alpha: 0.3)
                                                : Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                                            width: _isAdmin ? 1.5 : 0.5,
                                          ),
                                        ),
                                      child: Stack(
                                        children: [
                                          // Background icon (opacity 0.05)
                                          Positioned(
                                            top: 0,
                                            right: 0,
                                            child: Opacity(
                                              opacity: 0.05,
                                              child: Icon(
                                                Icons.sell,
                                                size: 64,
                                                color: isDark ? Colors.white : Colors.black,
                                              ),
                                            ),
                                            ),
                                          // Prices
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              if (deal.originalPrice != null && deal.originalPrice! > deal.price)
                                                Text(
                                                  currencyFormat.format(deal.originalPrice),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? Colors.grey[500] : AppTheme.textSecondary,
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationThickness: 1,
                                                  ),
                                                ),
                                              Text(
                                                currencyFormat.format(deal.price),
                                                style: TextStyle(
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.w900,
                                                  color: isDark ? Colors.white : Colors.black,
                                                  height: 1,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    // Stats Grid (3 columns)
                                    Row(
                                    children: [
                                        Expanded(
                                          child: _buildStatButton(
                                            icon: Icons.favorite,
                                            count: _hotVotes > 0 ? _hotVotes : deal.hotVotes,
                                            label: 'Beğeni',
                                          color: Colors.red,
                                            onTap: () => _handleVote(true),
                                            isSelected: _hasVotedHot,
                                            isDark: isDark,
                                  ),
                                ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _buildStatButton(
                                            icon: Icons.chat_bubble_outline,
                                            count: deal.commentCount,
                                            label: 'Yorum',
                                            color: Colors.blue,
                                            onTap: () => _showCommentsBottomSheet(context, deal),
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                              Expanded(
                                child: Container(
                                            padding: const EdgeInsets.symmetric(vertical: 12),
                                  decoration: BoxDecoration(
                                              color: isDark 
                                                  ? Colors.white.withValues(alpha: 0.05) 
                                                  : AppTheme.background,
                                              borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                                color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                                                width: 0.5,
                                    ),
                                  ),
                                            child: Column(
                                    children: [
                                      Icon(
                                                  Icons.visibility,
                                                  size: 24,
                                                  color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                      ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  '1.2k', // TODO: Gerçek görünüm sayısı
                                          style: TextStyle(
                                                    fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                                  ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Görünüm',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                                    const SizedBox(height: 32),
                                    // Description
                          Row(
                            children: [
                          Container(
                                          width: 6,
                                          height: 6,
                            decoration: BoxDecoration(
                                            color: primaryColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'ÜRÜN DETAYLARI',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: isDark ? Colors.white : AppTheme.textPrimary,
                                            letterSpacing: 2,
                                          ),
                                ),
                              ],
                            ),
                                    const SizedBox(height: 16),
                                    if (deal.description.isNotEmpty) ...[
                                      Text(
                                        deal.description,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                                          height: 1.6,
                                    ),
                                  ),
                                      const SizedBox(height: 12),
                                    ],
                                    // Read more button
                                    TextButton.icon(
                                      onPressed: () {
                                        // TODO: Tam açıklama göster
                                      },
                                      icon: Icon(
                                        Icons.arrow_forward,
                                        size: 16,
                                        color: isDark ? primaryColor : Colors.black,
                                      ),
                                      label: Text(
                                        'Tamamını oku',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? primaryColor : Colors.black,
                                ),
                                      ),
                                    ),
                                    const SizedBox(height: 80), // Bottom nav için padding
                                  ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Sticky Bottom Nav
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
              ),
              decoration: BoxDecoration(
                color: isDark ? AppTheme.darkSurface : Colors.white,
                border: Border(
                  top: BorderSide(
                    color: Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
                    width: 1,
                                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.1),
                    blurRadius: 30,
                    offset: const Offset(0, -5),
                                        ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Fırsat Fiyatı',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currencyFormat.format(deal.price),
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : Colors.black,
                              height: 1,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openLink(context, deal.link),
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: const Text(
                            'Mağazaya Git',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark ? Colors.grey[800] : const Color(0xFF2D3142),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                            shadowColor: Colors.black.withValues(alpha: 0.25),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Admin için onay/red butonları (onaylanmamış deal'ler için)
                  if (_isAdmin && !deal.isApproved)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _rejectDeal(deal.id),
                              icon: const Icon(Icons.close, size: 20),
                              label: const Text(
                                'Reddet',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.red,
                                side: const BorderSide(color: Colors.red, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _confirmApproval(deal.id),
                              icon: const Icon(Icons.check, size: 20),
                              label: const Text(
                                'Onayla',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 0,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
                          ],
      ),
      ),
    );
  }

  Widget _buildStatButton({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    bool isSelected = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : AppTheme.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected 
                  ? color.withValues(alpha: 0.3) 
                  : Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
              width: 0.5,
                              ),
                            ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 24,
                color: color,
                          ),
              const SizedBox(height: 6),
              Text(
                count.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
              ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  void _showAdminEditSheet(Deal deal) {
    if (!_isAdmin) return;

    final titleController = TextEditingController(text: deal.title);
    final descriptionController = TextEditingController(text: deal.description);
    final storeController = TextEditingController(text: deal.store);
    final linkController = TextEditingController(text: deal.link);
    final priceController = TextEditingController(text: deal.price.toStringAsFixed(0));
    final originalPriceController = TextEditingController(
      text: deal.originalPrice != null ? deal.originalPrice!.toStringAsFixed(0) : '',
    );
    final discountController = TextEditingController(
      text: deal.discountRate != null ? deal.discountRate!.toString() : '',
    );

    // Eğer kategori "Tümü" ise, varsayılan olarak "elektronik" kullan
    String initialCategoryId = Category.getIdByName(deal.category) ?? 'elektronik';
    if (initialCategoryId == 'tumu') {
      initialCategoryId = 'elektronik'; // "Tümü" seçilemez, varsayılan kategori kullan
    }

    // State değişkenleri closure içinde tutulmalı (StatefulBuilder dışında)
    String selectedCategoryId = initialCategoryId;
    String? selectedSubCategory = deal.subCategory;
    bool isEditorPick = deal.isEditorPick;
    bool isApproved = deal.isApproved;
    bool isExpired = deal.isExpired;
    bool isSaving = false;
    String? errorText;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> handleSave() async {
              double? parseDouble(String input) {
                final cleaned = input.replaceAll(RegExp('[^0-9,\\.]'), '').replaceAll(',', '.');
                if (cleaned.isEmpty) return null;
                return double.tryParse(cleaned);
              }

              final price = parseDouble(priceController.text);
              if (price == null || price <= 0) {
                setSheetState(() => errorText = 'Lütfen geçerli bir fiyat girin.');
                return;
              }

              final originalPrice = parseDouble(originalPriceController.text);
              final discountRate = int.tryParse(discountController.text.trim());

              setSheetState(() {
                isSaving = true;
                errorText = null;
              });

              final updates = {
                'title': titleController.text.trim(),
                'description': descriptionController.text.trim(),
                'store': storeController.text.trim(),
                'category': Category.getNameById(selectedCategoryId) ?? deal.category,
                'subCategory': selectedSubCategory,
                'link': linkController.text.trim(),
                'price': price,
                'originalPrice': (originalPrice ?? 0) > 0 ? originalPrice : null,
                'discountRate': (discountRate ?? 0) > 0 ? discountRate : null,
                'isEditorPick': isEditorPick,
                'isApproved': isApproved,
                'isExpired': isExpired,
              };

              final success = await _firestoreService.updateDeal(deal.id, updates);

              if (!mounted) return;

              if (success) {
                await _loadDeal();
                Navigator.of(sheetContext).pop();
                ScaffoldMessenger.of(this.context).showSnackBar(
                  const SnackBar(
                    content: Text('Fırsat bilgileri güncellendi'),
                    backgroundColor: Colors.green,
                  ),
                );
              } else {
                setSheetState(() {
                  isSaving = false;
                  errorText = 'Güncelleme sırasında hata oluştu. Tekrar deneyin.';
                });
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 24,
              ),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 20,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Fırsatı Düzenle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => Navigator.of(sheetContext).pop(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Divider(),
                        const SizedBox(height: 12),
                        _buildAdminTextField('Başlık', titleController),
                        _buildAdminTextField('Açıklama', descriptionController, maxLines: 3),
                        _buildAdminTextField('Mağaza', storeController),
                        // Kategori Seçimi
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Kategori',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  showModalBottomSheet(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.transparent,
                                    builder: (selectorContext) {
                                      return CategorySelectorWidget(
                                        selectedCategoryId: selectedCategoryId,
                                        selectedSubCategory: selectedSubCategory,
                                        onCategorySelected: (categoryId, subCategory) {
                                          // StatefulBuilder içindeki değişkenleri güncelle
                                          setSheetState(() {
                                            selectedCategoryId = categoryId;
                                            selectedSubCategory = subCategory;
                                          });
                                          // CategorySelectorWidget kendisi kapanacağı için burada pop çağrısı yok
                                        },
                                      );
                                    },
                                  );
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.category,
                                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _getCategoryDisplayText(selectedCategoryId, selectedSubCategory),
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 16,
                                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        _buildAdminTextField('Bağlantı', linkController),
                        Row(
                          children: [
                            Expanded(child: _buildAdminTextField('Fiyat', priceController, keyboardType: TextInputType.number)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildAdminTextField('Eski Fiyat', originalPriceController, keyboardType: TextInputType.number)),
                          ],
                        ),
                        _buildAdminTextField('İndirim Oranı (%)', discountController, keyboardType: TextInputType.number),
                        const SizedBox(height: 12),
                        SwitchListTile(
                          value: isEditorPick,
                          title: const Text('Editörün Seçimi'),
                          onChanged: (val) => setSheetState(() => isEditorPick = val),
                        ),
                        SwitchListTile(
                          value: isApproved,
                          title: const Text('Onaylı Fırsat'),
                          onChanged: (val) => setSheetState(() => isApproved = val),
                        ),
                        SwitchListTile(
                          value: isExpired,
                          title: const Text('Fırsat Bitti'),
                          onChanged: (val) => setSheetState(() => isExpired = val),
                        ),
                        if (errorText != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            errorText!,
                            style: const TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
                          ),
                        ],
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: isSaving ? null : handleSave,
                          icon: isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(isSaving ? 'Kaydediliyor...' : 'Kaydet'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _getCategoryDisplayText(String categoryId, String? subCategory) {
    final category = Category.getById(categoryId);
    if (subCategory != null) {
      return '${category.icon} ${category.name} > $subCategory';
    }
    return '${category.icon} ${category.name}';
  }

  String _getCategoryDisplayTextForDeal(Deal deal) {
    // Kategori değerini kontrol et (bot'tan ID olarak geliyor: "elektronik", "moda" vb.)
    final categoryValue = deal.category.trim();
    
    // Eğer kategori "Tümü" ise veya boşsa, varsayılan göster
    if (categoryValue.isEmpty || categoryValue == 'Tümü' || categoryValue == 'tumu') {
      return '🔥 Tümü';
    }
    
    // Önce ID olarak kontrol et (bot'tan ID geliyor: "elektronik", "moda" vb.)
    final normalizedValue = categoryValue.toLowerCase();
    for (final cat in Category.categories) {
      if (cat.id.toLowerCase() == normalizedValue && cat.id != 'tumu') {
        if (deal.subCategory != null && deal.subCategory!.isNotEmpty) {
          return '${cat.icon} ${cat.name} > ${deal.subCategory}';
        }
        return '${cat.icon} ${cat.name}';
      }
    }
    
    // ID bulunamazsa, name olarak kontrol et (eski veriler için)
    for (final cat in Category.categories) {
      if (cat.name.toLowerCase() == normalizedValue && cat.id != 'tumu') {
        if (deal.subCategory != null && deal.subCategory!.isNotEmpty) {
          return '${cat.icon} ${cat.name} > ${deal.subCategory}';
        }
        return '${cat.icon} ${cat.name}';
      }
    }
    
    // Hiçbir şey bulunamazsa, varsayılan olarak "Tümü" döndür
    return '🔥 Tümü';
  }

  Widget _buildAdminTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: TextStyle(
              color: isDark ? AppTheme.darkTextPrimary : Colors.black87,
            ),
            decoration: InputDecoration(
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: primaryColor,
                  width: 2,
                ),
              ),
              filled: true,
              fillColor: isDark ? AppTheme.darkBackground : Colors.white,
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassButton({
    required BuildContext context,
    required IconData icon,
    required VoidCallback? onPressed,
    Color? color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppTheme.darkSurface.withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.4)
                : Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: color ?? (isDark ? AppTheme.darkTextPrimary : AppTheme.accent),
        ),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCompactInfoChip({
    bool showEditIcon = false,
    required IconData icon,
    required String label,
    required Color color,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? AppTheme.darkTextPrimary : Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (showEditIcon) ...[
            const SizedBox(width: 6),
            Icon(
              Icons.edit,
              size: 14,
              color: color.withValues(alpha: 0.7),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCompactStat({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    bool isSelected = false,
    bool isLoading = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (isLoading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          )
        else
          Icon(
            icon,
            color: isSelected ? color : color.withValues(alpha: 0.7),
            size: 20,
          ),
        const SizedBox(height: 4),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w900,
            color: isSelected
                ? color
                : (isDark ? AppTheme.darkTextPrimary : AppTheme.accent),
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected
                ? color
                : (isDark ? AppTheme.darkTextSecondary : Colors.grey[600]),
          ),
        ),
      ],
    );
  }

  Widget _buildEditorTag(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: primaryColor, size: 20),
          const SizedBox(width: 6),
          Text(
            'Editörün Seçimi',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection(Deal deal, Color primaryColor) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Sıcak Oylar',
            icon: Icons.local_fire_department_rounded,
            color: primaryColor,
            count: deal.hotVotes,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Soğuk Oylar',
            icon: Icons.ac_unit_rounded,
            color: const Color(0xFF3A86FF),
            count: deal.coldVotes,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildStatCard(
            title: 'Yorumlar',
            icon: Icons.chat_rounded,
            color: Colors.grey[700] ?? Colors.grey,
            count: deal.commentCount,
          ),
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String title,
    required IconData icon,
    required Color color,
    required int count,
  }) {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLinkCard(BuildContext context, Deal deal) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.link_rounded, color: primaryColor),
              const SizedBox(width: 10),
              Text(
                'Fırsat Bağlantısı',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.accent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            deal.link.isNotEmpty ? deal.link : 'Bağlantı yakında eklenecek',
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: deal.link.isNotEmpty
                      ? () => _copyLinkToClipboard(context, deal.link)
                      : null,
                  icon: const Icon(Icons.copy_rounded),
                  label: const Text('Bağlantıyı Kopyala'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(ThemeData theme) {
    final primaryColor = theme.colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.notifications_active_rounded,
              color: primaryColor,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Alarm kurmayı unutma',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.accent,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Takip ettiğin kategoriler için bildirimleri açarak yeni fırsatlardan hemen haberdar ol.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
          return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.redAccent,
              size: 48,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Fırsat bulunamadı',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Fırsat kaldırılmış veya bağlantı hatalı olabilir.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Geri dön'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmApproval(String id) async {
    await _showApproveOptions(id);
  }

  Future<void> _showApproveOptions(String id) async {
    final option = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
        title: const Text('Onaylama Seçeneği'),
        content: const Text('Bu fırsatı nasıl onaylamak istersiniz?'),
          actions: [
            TextButton(
            onPressed: () => Navigator.pop(context, 'normal'),
            child: const Text('Normal Onayla'),
            ),
            TextButton(
            onPressed: () => Navigator.pop(context, 'editor'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.orange[700],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star, size: 18),
                SizedBox(width: 4),
                Text('Editörün Seçimi'),
              ],
            ),
            ),
          ],
        ),
      );

    if (option == null) return;

    if (option == 'normal') {
      await _approveDeal(id, isEditorPick: false);
    } else if (option == 'editor') {
      await _approveDeal(id, isEditorPick: true);
    }
  }

  Future<void> _approveDeal(String id, {bool isEditorPick = false}) async {
    await _firestoreService.updateDeal(id, {
      'isApproved': true,
      'isEditorPick': isEditorPick,
    });
    if (mounted) {
      await _loadDeal();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isEditorPick
                ? 'Fırsat Editörün Seçimi olarak onaylandı ⭐'
                : 'Fırsat Onaylandı ✅',
          ),
          backgroundColor: isEditorPick ? Colors.orange[700] : Colors.green,
        ),
      );
    }
  }

  Future<void> _showCategorySelector(Deal deal) async {
    if (_currentDeal == null) return;

    // Mevcut kategoriyi al
    String initialCategoryId = Category.getIdByName(deal.category) ?? 'elektronik';
    if (initialCategoryId == 'tumu') {
      initialCategoryId = 'elektronik';
    }
    String selectedCategoryId = initialCategoryId;
    String? selectedSubCategory = deal.subCategory;

    final result = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.7,
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Başlık
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kategori Seç',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ),
                  // Kategori Seçici
                  Expanded(
                    child: CategorySelectorWidget(
                      selectedCategoryId: selectedCategoryId,
                      selectedSubCategory: selectedSubCategory,
                      onCategorySelected: (categoryId, subCategory) {
                        setSheetState(() {
                          selectedCategoryId = categoryId;
                          selectedSubCategory = subCategory;
                        });
                        Navigator.pop(context, {
                          'categoryId': categoryId,
                          'subCategory': subCategory,
                        });
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    if (result != null && _currentDeal != null) {
      final categoryId = result['categoryId']!;
      final subCategory = result['subCategory'];
      final categoryName = Category.getNameById(categoryId) ?? deal.category;

      // Firestore'da güncelle
      final success = await _firestoreService.updateDeal(deal.id, {
        'category': categoryName,
        'subCategory': subCategory,
      });

        if (mounted) {
          if (success) {
          await _loadDeal();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
              content: Text('Kategori güncellendi ✅'),
              backgroundColor: Colors.green,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
              content: Text('Kategori güncellenirken hata oluştu'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
  }

  Future<void> _savePrice(String dealId) async {
    final priceText = _priceEditController.text.trim();
    if (priceText.isEmpty) {
      setState(() {
        _isEditingPrice = false;
      });
      return;
    }

    // Fiyatı parse et
    final cleaned = priceText.replaceAll(RegExp('[^0-9,\\.]'), '').replaceAll(',', '.');
    final price = double.tryParse(cleaned);
      
    if (price == null || price <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Geçerli bir fiyat girin'),
            backgroundColor: Colors.red,
          ),
        );
      }
        return;
      }

    setState(() {
      _isEditingPrice = false;
    });

    // Firestore'da güncelle
    final success = await _firestoreService.updateDeal(dealId, {
      'price': price,
    });

    if (mounted) {
      if (success) {
        await _loadDeal();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fiyat güncellendi ✅'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fiyat güncellenirken hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _rejectDeal(String id) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
        title: const Text('Fırsatı Reddet'),
        content: const Text('Bu fırsatı reddetmek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Evet, Reddet'),
            ),
          ],
        ),
      );

    if (confirm != true) return;

    await _firestoreService.updateDeal(id, {'isExpired': true});
        if (mounted) {
      await _loadDeal();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fırsat Reddedildi ❌'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _markDealAsExpired(BuildContext context, Deal deal) async {
    final user = _authService.currentUser;
    if (user == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
          content: Text('Oy vermek için giriş yapmalısınız'),
          backgroundColor: Colors.orange,
              ),
            );
      return;
    }

    // Eğer zaten expired vote vermişse, işlem yapma
    if (_hasVotedExpired) {
      return;
    }

    // Loading state
    setState(() {
      _isExpiredVoting = true;
    });

    // Optimistic UI update
    final previousExpiredVotes = _expiredVotes;
    setState(() {
      _hasVotedExpired = true;
      _expiredVotes += 1;
    });

    // Firestore'a kaydet
    final success = await _firestoreService.addExpiredVote(deal.id, user.uid);

    if (!success && mounted) {
      // Hata durumunda önceki duruma geri dön
      setState(() {
        _hasVotedExpired = false;
        _expiredVotes = previousExpiredVotes;
        _isExpiredVoting = false;
      });

            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
          content: Text('Oy gönderilirken bir hata oluştu. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Deal'i yeniden yükle
    await _loadDeal();
    _checkUserVote();

    if (mounted) {
      setState(() {
        _isExpiredVoting = false;
      });

      // Eğer 10 oya ulaştıysa bildirim göster
      if (_expiredVotes >= 10) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fırsat bitmiş olarak işaretlendi ✅'),
                backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
              ),
            );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Fırsat bitti oyunuz kaydedildi. ${10 - _expiredVotes} oy daha gerekiyor.'),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _openLink(BuildContext context, String link) async {
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı henüz eklenmedi'),
        ),
      );
      return;
    }

    try {
      // URL'yi düzelt - http:// veya https:// yoksa ekle
      String url = link.trim();
      if (!url.startsWith('http://') && !url.startsWith('https://')) {
        url = 'https://$url';
      }
      
      final uri = Uri.parse(url);
      
      // canLaunchUrl kontrolü yapmadan direkt açmayı dene
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      
      if (!launched && context.mounted) {
        // Eğer açılamadıysa, platform varsayılan modunu dene
        await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı açılamadı: ${e.toString()}'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _showShareOptions(BuildContext context, Deal deal) async {
    final link = deal.link;
    if (link.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı henüz eklenmedi'),
        ),
      );
      return;
    }

    final shareText = '${deal.title} - ${deal.store} - ${deal.link}';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Paylaş',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareOption(
                  context,
                  icon: Icons.content_copy_rounded,
                  label: 'Kopyala',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _copyLinkToClipboard(context, link);
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.chat_rounded,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onTap: () {
                    Navigator.pop(context);
                    _shareToWhatsApp(shareText);
                  },
                ),
                _buildShareOption(
                  context,
                  icon: Icons.chat_bubble_outline_rounded,
                  label: 'Twitter',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _shareToTwitter(shareText);
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _showDeleteDialog(BuildContext context, Deal deal) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Sil'),
        content: Text('Bu fırsatı kalıcı olarak silmek istediğinize emin misiniz?\n\n"${deal.title}"\n\nBu işlem geri alınamaz.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.red,
            ),
            child: const Text('Evet, Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    final success = await _firestoreService.deleteDeal(deal.id);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fırsat silindi 🗑️'),
            backgroundColor: Colors.red,
          ),
        );
        // Silme işlemi başarılıysa geri dön
        Navigator.of(context).pop();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Silme işlemi başarısız ❌'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareToWhatsApp(String text) async {
    final uri = Uri.parse('https://wa.me/?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('WhatsApp açılamadı')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım hatası: $e')),
      );
    }
  }

  Future<void> _shareToTwitter(String text) async {
    final uri = Uri.parse('https://twitter.com/intent/tweet?text=${Uri.encodeComponent(text)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Twitter açılamadı')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Paylaşım hatası: $e')),
      );
    }
  }

  void _copyLinkToClipboard(BuildContext context, String link) {
    Clipboard.setData(ClipboardData(text: link));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bağlantı kopyalandı!'),
      ),
    );
  }

  String _formatPostedBy(String postedBy) {
    if (postedBy.isEmpty) {
      return 'Topluluk Üyesi';
    }

    final safeLength = postedBy.length >= 6 ? 6 : postedBy.length;
    return '#${postedBy.substring(0, safeLength).toUpperCase()}';
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    }

    return DateFormat('d MMM').format(date);
  }

  String _getVoteCountText(Deal deal) {
    if (deal.expiredVotes >= 10) {
      return '10/10';
    } else {
      final remaining = 10 - deal.expiredVotes;
      return '$remaining oy daha';
    }
  }

  Widget _buildDetailImage(Deal deal) {
    // Eğer görsel yoksa ve henüz çekilmeye çalışılmadıysa, çekmeyi dene
    if (deal.imageUrl.isEmpty && !_hasTriedFetching && !_isFetchingImage && deal.link.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _fetchImageFromLink(deal.link);
        }
      });
    }
    
    // Görsel seçim mantığı:
    // 1. Önce orijinal görseli dene (eğer başarısız olmadıysa)
    // 2. Orijinal görsel yoksa veya başarısız olduysa, linkten çekileni kullan
    
    String? imageUrl;
    final fetchedUrl = _fetchedImageUrl;
    
    // Önce orijinal görseli kontrol et
    if (!_originalImageFailed && deal.imageUrl.isNotEmpty) {
      imageUrl = deal.imageUrl;
    } 
    // Orijinal görsel yoksa veya başarısız olduysa, linkten çekileni kullan
    else if (fetchedUrl != null && fetchedUrl.isNotEmpty) {
      imageUrl = fetchedUrl;
    }
    
    // Görsel yükleniyorsa loading göster
    if (_isFetchingImage && imageUrl == null) {
      return Container(
        color: Colors.grey[200],
        child: const Center(
          child: CircularProgressIndicator(
            strokeWidth: 3,
          ),
        ),
      );
    }
    
    // Görsel varsa göster - Contain fit ile tam görünsün
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return Container(
        color: Colors.grey[100], // Arka plan rengi
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain, // Görseli çerçeveye sığdır, tam görünsün
            width: double.infinity,
            height: double.infinity,
            placeholder: (context, url) => Container(
              color: Colors.grey[200],
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                ),
              ),
            ),
            errorWidget: (context, url, error) {
              // Eğer orijinal görsel yüklenemediyse
              if (!_originalImageFailed && imageUrl == deal.imageUrl && deal.imageUrl.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) {
                    setState(() {
                      _originalImageFailed = true;
                    });
                    // Linkten çekmeyi dene
                    if (!_hasTriedFetching && deal.link.isNotEmpty) {
                      _fetchImageFromLink(deal.link);
                    }
                  }
                });
              }
              // Eğer linkten çekilen görsel varsa, onu göster
              final currentFetchedUrl = _fetchedImageUrl;
              if (currentFetchedUrl != null && currentFetchedUrl.isNotEmpty && currentFetchedUrl != imageUrl) {
                return Container(
                  color: Colors.grey[100],
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: currentFetchedUrl,
                      fit: BoxFit.contain, // Contain fit
                      width: double.infinity,
                      height: double.infinity,
                      errorWidget: (context, url, error) => _buildImageFallback(),
                    ),
                  ),
                );
              }
              return _buildImageFallback();
            },
          ),
        ),
      );
    }
    
    // Görsel yoksa fallback göster
    return _buildImageFallback();
  }

  Widget _buildImageFallback() {
    return Container(
      color: Colors.grey[200],
      child: const Icon(
        Icons.image_outlined,
        size: 80,
        color: Colors.grey,
      ),
    );
  }


  void _showCommentsBottomSheet(BuildContext context, Deal deal) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsBottomSheet(deal: deal),
    );
  }

  Future<void> _showAdminEditDialog(Deal deal) async {
    final titleController = TextEditingController(text: deal.title);
    final descriptionController = TextEditingController(text: deal.description);
    final priceController = TextEditingController(text: deal.price.toStringAsFixed(2));
    final originalPriceController = TextEditingController(
      text: deal.originalPrice?.toStringAsFixed(2) ?? '',
    );

    String? selectedCategoryId = Category.getIdByName(deal.category);
    // "tumu" kategorisi dropdown'da olmadığı için null yap
    if (selectedCategoryId == 'tumu') {
      selectedCategoryId = null;
    }
    String? selectedSubCategory = deal.subCategory;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Ürün Bilgilerini Düzenle'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          decoration: const InputDecoration(
                            labelText: 'Fiyat (₺)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: originalPriceController,
                          decoration: const InputDecoration(
                            labelText: 'Eski Fiyat (₺)',
                            border: OutlineInputBorder(),
                            hintText: 'Opsiyonel',
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: selectedCategoryId,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: Category.categories
                        .where((cat) => cat.id != 'tumu')
                        .map((category) => DropdownMenuItem(
                              value: category.id,
                              child: Text('${category.icon} ${category.name}'),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        selectedCategoryId = value;
                        selectedSubCategory = null;
                      });
                    },
                  ),
                  if (selectedCategoryId != null) ...[
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: selectedSubCategory,
                      decoration: const InputDecoration(
                        labelText: 'Alt Kategori',
                        border: OutlineInputBorder(),
                        hintText: 'Opsiyonel',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('Alt kategori seçiniz (opsiyonel)'),
                        ),
                        ...Category.categories
                            .firstWhere((cat) => cat.id == selectedCategoryId)
                            .subcategories
                            .map((sub) => DropdownMenuItem(
                                  value: sub,
                                  child: Text(sub),
                                )),
                      ],
                      onChanged: (value) {
                        setState(() {
                          selectedSubCategory = value;
                        });
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Başlık boş olamaz')),
                  );
                  return;
                }

                final price = double.tryParse(priceController.text.replaceAll(',', '.'));
                if (price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Geçerli bir fiyat giriniz')),
                  );
                  return;
                }

                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kategori seçiniz')),
                  );
                  return;
                }

                final updates = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'description': descriptionController.text.trim(),
                  'price': price,
                  'category': Category.getById(selectedCategoryId!).name,
                };

                final originalPrice = originalPriceController.text.trim();
                if (originalPrice.isNotEmpty) {
                  final origPrice = double.tryParse(originalPrice.replaceAll(',', '.'));
                  if (origPrice != null && origPrice > price) {
                    updates['originalPrice'] = origPrice;
                    final discountRate = ((origPrice - price) / origPrice * 100).round();
                    updates['discountRate'] = discountRate;
                  } else {
                    updates['originalPrice'] = null;
                    updates['discountRate'] = null;
                  }
                } else {
                  updates['originalPrice'] = null;
                  updates['discountRate'] = null;
                }

                if (selectedSubCategory != null && selectedSubCategory!.isNotEmpty) {
                  updates['subCategory'] = selectedSubCategory;
                } else {
                  updates['subCategory'] = null;
                }

                final success = await _firestoreService.updateDeal(widget.dealId, updates);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    await _loadDeal();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Ürün bilgileri güncellendi ✅'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPriceEditDialog(Deal deal) async {
    final priceController = TextEditingController(text: deal.price.toStringAsFixed(2));
    final originalPriceController = TextEditingController(
      text: deal.originalPrice?.toStringAsFixed(2) ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fiyat Düzenle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: 'Güncel Fiyat (₺)',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: originalPriceController,
              decoration: const InputDecoration(
                labelText: 'Eski Fiyat (₺)',
                border: OutlineInputBorder(),
                hintText: 'Opsiyonel',
              ),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final price = double.tryParse(priceController.text.replaceAll(',', '.'));
              if (price == null || price <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Geçerli bir fiyat giriniz')),
                );
                return;
              }

              final updates = <String, dynamic>{'price': price};

              final originalPrice = originalPriceController.text.trim();
              if (originalPrice.isNotEmpty) {
                final origPrice = double.tryParse(originalPrice.replaceAll(',', '.'));
                if (origPrice != null && origPrice > price) {
                  updates['originalPrice'] = origPrice;
                  final discountRate = ((origPrice - price) / origPrice * 100).round();
                  updates['discountRate'] = discountRate;
                } else {
                  updates['originalPrice'] = null;
                  updates['discountRate'] = null;
                }
              } else {
                updates['originalPrice'] = null;
                updates['discountRate'] = null;
              }

              final success = await _firestoreService.updateDeal(widget.dealId, updates);
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  await _loadDeal();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Fiyat güncellendi ✅'),
                      backgroundColor: Colors.green,
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryEditDialog(Deal deal) async {
    String? selectedCategoryId = Category.getIdByName(deal.category);
    // "tumu" kategorisi dropdown'da olmadığı için null yap
    if (selectedCategoryId == 'tumu') {
      selectedCategoryId = null;
    }
    String? selectedSubCategory = deal.subCategory;

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Kategori Düzenle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: selectedCategoryId,
                decoration: const InputDecoration(
                  labelText: 'Kategori',
                  border: OutlineInputBorder(),
                ),
                items: Category.categories
                    .where((cat) => cat.id != 'tumu')
                    .map((category) => DropdownMenuItem(
                          value: category.id,
                          child: Text('${category.icon} ${category.name}'),
                        ))
                    .toList(),
                onChanged: (value) {
                  setState(() {
                    selectedCategoryId = value;
                    selectedSubCategory = null;
                  });
                },
              ),
              if (selectedCategoryId != null) ...[
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  value: selectedSubCategory,
                  decoration: const InputDecoration(
                    labelText: 'Alt Kategori',
                    border: OutlineInputBorder(),
                    hintText: 'Opsiyonel',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Alt kategori seçiniz (opsiyonel)'),
                    ),
                    ...Category.categories
                        .firstWhere((cat) => cat.id == selectedCategoryId)
                        .subcategories
                        .map((sub) => DropdownMenuItem(
                              value: sub,
                              child: Text(sub),
                            )),
                  ],
                  onChanged: (value) {
                    setState(() {
                      selectedSubCategory = value;
                    });
                  },
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedCategoryId == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Kategori seçiniz')),
                  );
                  return;
                }

                final updates = <String, dynamic>{
                  'category': Category.getById(selectedCategoryId!).name,
                };

                if (selectedSubCategory != null && selectedSubCategory!.isNotEmpty) {
                  updates['subCategory'] = selectedSubCategory;
                } else {
                  updates['subCategory'] = null;
                }

                final success = await _firestoreService.updateDeal(widget.dealId, updates);
                if (context.mounted) {
                  Navigator.pop(context);
                  if (success) {
                    await _loadDeal();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Kategori güncellendi ✅'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  void _showFullScreenImage(String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.9),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            // Görsel - Pinch to zoom özelliği ile
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                  placeholder: (context, url) => const Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Colors.white,
                    ),
                  ),
                  errorWidget: (context, url, error) => const Center(
                    child: Icon(
                      Icons.error_outline,
                      color: Colors.white,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            // Kapat butonu
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.close,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CommentsBottomSheet extends StatefulWidget {
  final Deal deal;

  const _CommentsBottomSheet({required this.deal});

  @override
  State<_CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<_CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isSubmitting = false;
  bool _isAdmin = false;
  Comment? _replyingTo; // Cevap verilen yorum

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir yorum yazın')),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum yapmak için giriş yapmalısınız')),
      );
      return;
    }

    // Engellenen kullanıcı kontrolü
    final isBlocked = await _firestoreService.isUserBlocked(user.uid);
    if (isBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesabınız engellenmiş. Yorum yapamazsınız.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Kullanıcının nickname'ini ve profil resmini al
    String displayName = user.displayName ?? 'Kullanıcı';
    String profileImageUrl = '';
    try {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        displayName = userData.displayName;
        profileImageUrl = userData.profileImageUrl;
      }
    } catch (e) {
      print('Kullanıcı bilgisi alınamadı: $e');
    }

    final success = await _firestoreService.addComment(
      dealId: widget.deal.id,
      userId: user.uid,
      userName: displayName,
      userEmail: user.email ?? '',
      text: _commentController.text.trim(),
      parentCommentId: _replyingTo?.id,
      replyToUserName: _replyingTo?.userName,
      userProfileImageUrl: profileImageUrl,
    );

    setState(() {
      _isSubmitting = false;
      _replyingTo = null; // Cevap verme durumunu sıfırla
    });

    if (success && mounted) {
      _commentController.clear();
      // Yorum eklendikten sonra state'i güncellemek için kısa bir bekleme
      await Future.delayed(const Duration(milliseconds: 500));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yorumunuz eklendi'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Yorum eklenirken bir hata oluştu'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackground : AppTheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      'Yorumlar',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.accent,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Yorum listesi
              Expanded(
                child: StreamBuilder<List<Comment>>(
                  stream: _firestoreService.getCommentsStream(widget.deal.id),
                  builder: (context, snapshot) {
                    // İlk yükleme sırasında loading göster
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    // Hata durumu
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Hata: ${snapshot.error}',
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
            );
          }

                    // Yorumları al
                    final comments = snapshot.data ?? [];

                    // Yorumlar boşsa
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz yorum yok',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppTheme.darkTextPrimary : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'İlk yorumu siz yapın!',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Yorum listesi
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _buildCommentItem(comment, _isAdmin, comments, scrollController);
                      },
                    );
                  },
                ),
              ),

              // Yorum ekleme formu
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  border: Border(
                    top: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
                    ),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                          child: TextField(
                          controller: _commentController,
                          style: TextStyle(
                            color: isDark ? AppTheme.darkTextPrimary : Colors.black,
                          ),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null 
                                ? '@${_replyingTo!.userName} kullanıcısına cevap verin...' 
                                : 'Yorumunuzu yazın...',
                            hintStyle: TextStyle(
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey[500],
                            ),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkBackground : Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: primaryColor,
                                width: 2,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _submitComment(),
                        ),
                      ),
                      if (_replyingTo != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _replyingTo = null;
                              _commentController.clear();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkBorder : Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 20,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: IconButton(
                          icon: _isSubmitting
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : const Icon(Icons.send_rounded, color: Colors.white),
                          onPressed: _isSubmitting ? null : _submitComment,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(Comment comment, bool isAdmin, List<Comment> allComments, ScrollController scrollController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isReply = comment.parentCommentId != null;
    return Container(
      margin: EdgeInsets.only(
        bottom: 8,
        left: isReply ? 32 : 0, // Cevaplar için sol margin
      ),
      padding: EdgeInsets.all(isReply ? 8 : 10),
      decoration: BoxDecoration(
        color: isReply
            ? (isDark ? AppTheme.darkBackground : Colors.grey[50])
            : (isDark ? AppTheme.darkSurface : Colors.white), // Cevaplar için farklı arka plan
        borderRadius: BorderRadius.circular(12),
        border: isReply
            ? Border.all(
                color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                width: 1,
              )
            : null, // Cevaplar için border
        boxShadow: isReply
            ? null
            : [
                // Cevaplar için shadow yok
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.3)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Cevap göstergesi
              if (isReply) ...[
                Icon(
                  Icons.reply_rounded,
                  size: 12,
                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey[400],
                ),
                const SizedBox(width: 6),
              ],
              comment.userProfileImageUrl.isNotEmpty
                  ? CircleAvatar(
                      radius: isReply ? 10 : 14,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: comment.userProfileImageUrl.startsWith('assets/')
                          ? AssetImage(comment.userProfileImageUrl) as ImageProvider
                          : CachedNetworkImageProvider(comment.userProfileImageUrl),
                      onBackgroundImageError: (exception, stackTrace) {
                        // Hata durumunda harf göster
                      },
                      child: comment.userProfileImageUrl.startsWith('assets/')
                          ? null
                          : null, // Network image için child gerekmez
                    )
                  : CircleAvatar(
                      radius: isReply ? 10 : 14,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                          color: primaryColor,
                    fontWeight: FontWeight.w700,
                    fontSize: isReply ? 11 : 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            comment.userName.isNotEmpty
                                ? comment.userName
                                : 'Kullanıcı',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: isReply ? 12 : 13,
                              color: isDark ? AppTheme.darkTextPrimary : AppTheme.accent,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isReply && comment.replyToUserName != null) ...[
                          const SizedBox(width: 3),
                          Icon(Icons.arrow_forward_rounded, size: 11, color: Colors.grey[500]),
                          const SizedBox(width: 3),
                          Flexible(
                            child: Text(
                              comment.replyToUserName!,
                              style: TextStyle(
                                fontSize: 12,
                                color: primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatCommentTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppTheme.darkTextSecondary : Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Admin butonları
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
                    size: 16,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteComment(comment);
                    } else if (value == 'block') {
                      _blockUser(comment.userId, comment.userName);
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                          SizedBox(width: 8),
                          Text('Yorumu Sil'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'block',
                      child: Row(
                        children: [
                          Icon(Icons.block_rounded, color: Colors.orange, size: 20),
                          SizedBox(width: 8),
                          Text('Kullanıcıyı Engelle'),
                        ],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.text,
            style: TextStyle(
              fontSize: isReply ? 13 : 14,
              color: isDark ? AppTheme.darkTextPrimary : AppTheme.accent,
              fontWeight: FontWeight.w500,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 6),
          // Cevap verme butonu (sadece ana yorumlar için)
          if (!isReply)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _replyingTo = comment;
                });
                // TextField'a focus ver
                FocusScope.of(context).requestFocus(FocusNode());
                // Scroll'u en alta kaydır
                Future.delayed(const Duration(milliseconds: 300), () {
                  if (scrollController.hasClients) {
                    scrollController.animateTo(
                      scrollController.position.maxScrollExtent,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                });
              },
              icon: Icon(Icons.reply_rounded, size: 13, color: primaryColor),
              label: Text(
                'Cevap Ver',
                style: TextStyle(color: primaryColor, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorumu Sil'),
        content: const Text('Bu yorumu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _firestoreService.deleteComment(comment.id, widget.deal.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Yorum silindi' : 'Yorum silinirken hata oluştu'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Engelle'),
        content: Text('$userName kullanıcısını engellemek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _firestoreService.blockUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Kullanıcı engellendi' : 'Kullanıcı engellenirken hata oluştu'),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
      }
    }
  }

  String _formatCommentTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    }

    return DateFormat('d MMM yyyy').format(date);
  }
}



