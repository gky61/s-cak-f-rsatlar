import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'dart:ui';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import '../models/deal.dart';
import '../models/comment.dart';
import '../models/category.dart';
import '../models/user.dart' as app_user;
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/link_preview_service.dart';
import '../services/notification_service.dart';
import '../utils/badge_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/category_selector_widget.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // navigatorKey için
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import '../firebase_options.dart';

import '../widgets/report_dialog.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/deal_thermometer.dart';
import '../widgets/link_card.dart';
void _log(String message) {
  if (kDebugMode) print(message);
}

class DealDetailScreen extends StatefulWidget {
  final String dealId;
  final String? scrollToCommentId; // Belirli bir yoruma scroll etmek için

  const DealDetailScreen({
    super.key,
    required this.dealId,
    this.scrollToCommentId,
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

    // Eğer zaten hot vote verilmişse ve tekrar hot'a basılırsa, geri al
    if (isHot && _hasVotedHot) {
      await _removeHotVote();
      return;
    }
    
    // Eğer zaten cold vote verilmişse, işlem yapma
    if (!isHot && _hasVotedCold) {
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

    // Eğer hot vote ise, favorilere de ekle
    if (isHot && success) {
      await _firestoreService.addToFavorites(user.uid, _currentDeal!.id);
      // Favori durumunu güncelle
      if (mounted) {
        setState(() {
          _isFavorite = true;
        });
      }
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

  Future<void> _handleExpiredVote() async {
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

    // Eğer zaten expired vote verilmişse, işlem yapma
    if (_hasVotedExpired) {
      return;
    }

    // Loading state
    setState(() {
      _isExpiredVoting = true;
    });

    // Önceki oy durumunu kaydet
    final previousHotVote = _hasVotedHot;
    final previousColdVote = _hasVotedCold;
    final previousHotVotes = _hotVotes;
    final previousColdVotes = _coldVotes;
    final previousExpiredVotes = _expiredVotes;

    // Optimistic UI update
    setState(() {
      // Eğer daha önce hot veya cold vermişse, onları kaldır
      if (_hasVotedHot) {
        _hasVotedHot = false;
        _hotVotes = _hotVotes > 0 ? _hotVotes - 1 : 0;
      }
      if (_hasVotedCold) {
        _hasVotedCold = false;
        _coldVotes = _coldVotes > 0 ? _coldVotes - 1 : 0;
      }
      _hasVotedExpired = true;
      _expiredVotes += 1;
    });

    // Firestore'a kaydet
    final success = await _firestoreService.addExpiredVote(_currentDeal!.id, user.uid);

    if (!success && mounted) {
      // Hata durumunda önceki duruma geri dön
      setState(() {
        _hasVotedHot = previousHotVote;
        _hasVotedCold = previousColdVote;
        _hotVotes = previousHotVotes;
        _coldVotes = previousColdVotes;
        _expiredVotes = previousExpiredVotes;
        _hasVotedExpired = false;
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
    _loadDeal();
    _checkUserVote();

    if (!mounted) return;

    setState(() {
      _isExpiredVoting = false;
    });

    // 15 kişi basıldıysa bilgilendir
    if (_expiredVotes >= 15) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat bitti olarak işaretlendi'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _removeHotVote() async {
    final user = _authService.currentUser;
    if (user == null || _currentDeal == null) return;

    // Loading state
    setState(() {
      _isHotVoting = true;
    });

    // Önceki durumu kaydet
    final previousHotVote = _hasVotedHot;
    final previousHotVotes = _hotVotes;

    // Optimistic UI update
    setState(() {
      _hasVotedHot = false;
      _hotVotes = _hotVotes > 0 ? _hotVotes - 1 : 0;
      _isFavorite = false; // Favorilerden de çıkar
    });

    // Firestore'dan geri al
    final success = await _firestoreService.removeHotVote(_currentDeal!.id, user.uid);

    if (!success && mounted) {
      // Hata durumunda önceki duruma geri dön
      setState(() {
        _hasVotedHot = previousHotVote;
        _hotVotes = previousHotVotes;
        _isHotVoting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Beğeni geri alınırken bir hata oluştu. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Favorilerden çıkar
    if (success) {
      await _firestoreService.removeFromFavorites(user.uid, _currentDeal!.id);
    }

    // Deal'i yeniden yükle
    _loadDeal();
    _checkUserVote();

    if (!mounted) return;

    setState(() {
      _isHotVoting = false;
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
        
        // Eğer scrollToCommentId varsa, yorumlar bottom sheet'ini otomatik aç
        if (widget.scrollToCommentId != null && mounted) {
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted && _currentDeal != null) {
              final navigatorContext = navigatorKey.currentContext;
              if (navigatorContext != null) {
                _showCommentsBottomSheet(
                  navigatorContext,
                  _currentDeal!,
                  scrollToCommentId: widget.scrollToCommentId,
                );
              }
            }
          });
        }
      }
    } catch (e) {
      _log('Deal yükleme hatası: $e');
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
      _log('Görsel çekme hatası: $e');
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
      // ID bulunamazsa normalize et (bot ID veya name olabilir)
      final categoryId = Category.normalizeCategoryId(deal.category);
      category = categoryId != 'tumu'
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
                      // Raporla / Diğer İşlemler Butonu
                      const SizedBox(width: 8),
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
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert,
                            size: 20,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          onSelected: (value) {
                            if (value == 'report') {
                              showReportDialog(
                                context,
                                reportedId: deal.id,
                                type: 'deal',
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'report',
                              child: Row(
                                children: [
                                  Icon(Icons.flag_outlined, color: Colors.red[400], size: 20),
                                  const SizedBox(width: 12),
                                  Text(
                                    'Fırsatı Raporla',
                                    style: TextStyle(
                                      color: isDark ? Colors.white : Colors.black87,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                        // Yayından kaldır butonu (sadece onaylanmış fırsatlar için)
                        if (deal.isApproved == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.orange.withValues(alpha: 0.3),
                                width: 0.5,
                              ),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () => _unpublishDeal(deal.id),
                                child: Icon(
                                  Icons.close,
                                  size: 20,
                                  color: Colors.orange[700],
                                ),
                      ),
                            ),
                  ),
                        ],
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
                                    // Store + Category + Paylaşan
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
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
                                        // Sağ taraf: Kategori + Paylaşan
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
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
                                            // Paylaşan Kullanıcı (sadece kullanıcı paylaşımlarında göster)
                                            if (deal.postedBy.isNotEmpty && deal.isUserSubmitted)
                                              Padding(
                                                padding: const EdgeInsets.only(top: 8),
                                                child: StreamBuilder<DocumentSnapshot>(
                                                  stream: FirebaseFirestore.instance
                                                      .collection('users')
                                                      .doc(deal.postedBy)
                                                      .snapshots(),
                                                  builder: (context, snapshot) {
                                                    if (!snapshot.hasData || !snapshot.data!.exists) {
                                                      return const SizedBox.shrink();
                                                    }
                                                    
                                                    final userData = snapshot.data!.data() as Map<String, dynamic>;
                                                    final username = userData['username']?.toString() ?? 'Kullanıcı';
                                                    final profileImageUrl = userData['profileImageUrl']?.toString() ?? '';
                                                    
                                                    return InkWell(
                                                      onTap: () {
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (_) => ProfileScreen(userId: deal.postedBy),
                                                          ),
                                                        );
                                                      },
                                                      borderRadius: BorderRadius.circular(16),
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                                          color: isDark 
                                                              ? Colors.white.withValues(alpha: 0.05) 
                                                              : Colors.white,
                                                          borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                                            color: primaryColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            ClipOval(
                                                              child: profileImageUrl.isNotEmpty
                                                                  ? CachedNetworkImage(
                                                                      imageUrl: profileImageUrl,
                                                                      width: 16,
                                                                      height: 16,
                                                                      fit: BoxFit.cover,
                                                                      memCacheWidth: 32,
                                                                      memCacheHeight: 32,
                                                                      fadeInDuration: const Duration(milliseconds: 200),
                                                                      placeholder: (context, url) => Container(
                                                                        width: 16,
                                                                        height: 16,
                                                                        color: primaryColor.withOpacity(0.1),
                                                                        child: Icon(
                                                                          Icons.person,
                                                                          size: 10,
                                                                          color: primaryColor,
                                                                        ),
                                                                      ),
                                                                      errorWidget: (context, url, error) => Container(
                                                                        width: 16,
                                                                        height: 16,
                                                                        color: primaryColor.withOpacity(0.1),
                                                                        child: Icon(
                                                                          Icons.person,
                                                                          size: 10,
                                                                          color: primaryColor,
                                                                        ),
                                                                      ),
                                                                    )
                                                                  : Container(
                                                                      width: 16,
                                                                      height: 16,
                                                                      decoration: BoxDecoration(
                                                                        color: primaryColor.withOpacity(0.1),
                                                                        shape: BoxShape.circle,
                                                                      ),
                                                                      child: Icon(
                                                                        Icons.person,
                                                                        size: 10,
                                                                        color: primaryColor,
                                                                      ),
                                                                    ),
                                                            ),
                                                            const SizedBox(width: 6),
                                                            Text(
                                                              username,
                                                              style: TextStyle(
                                                                fontSize: 11,
                                                                fontWeight: FontWeight.w600,
                                                                color: primaryColor,
                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                          ],
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
                                    const SizedBox(height: 16),
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
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildStatButton(
                                            icon: Icons.chat_bubble_outline,
                                            count: deal.commentCount,
                                            label: 'Yorum',
                                            color: Colors.blue,
                                            onTap: () => _showCommentsBottomSheet(
                                              context, 
                                              deal,
                                              scrollToCommentId: widget.scrollToCommentId,
                                            ),
                                            isDark: isDark,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: _buildStatButton(
                                            icon: Icons.cancel_outlined,
                                            count: _expiredVotes > 0 ? _expiredVotes : deal.expiredVotes,
                                            label: 'Fırsat Bitti',
                                            color: Colors.grey,
                                            onTap: _handleExpiredVote,
                                            isSelected: _hasVotedExpired,
                                            isDark: isDark,
                                            isLoading: _isExpiredVoting,
                                          ),
                                        ),
                            ],
                          ),
                                    const SizedBox(height: 16),
                                    DealThermometer(
                                      deal: deal,
                                      hotVotes: _hotVotes,
                                      coldVotes: _coldVotes,
                                      hasVotedHot: _hasVotedHot,
                                      hasVotedCold: _hasVotedCold,
                                      onVote: _handleVote,
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
                                    if (deal.description.isNotEmpty || _isAdmin) ...[
                                      GestureDetector(
                                        onTap: _isAdmin ? () => _showEditDescriptionDialog(deal) : null,
                                        child: Container(
                                          width: double.infinity,
                                          padding: _isAdmin ? const EdgeInsets.all(12) : EdgeInsets.zero,
                                          decoration: _isAdmin ? BoxDecoration(
                                            color: isDark ? Colors.grey[800]!.withValues(alpha: 0.3) : Colors.grey[100],
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: primaryColor.withValues(alpha: 0.3),
                                              width: 1,
                                            ),
                                          ) : null,
                                  child: Row(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Text(
                                                  deal.description.isNotEmpty ? deal.description : 'Açıklama eklemek için tıklayın',
                                          style: TextStyle(
                                            fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                                    color: deal.description.isNotEmpty 
                                                        ? (isDark ? Colors.grey[300] : AppTheme.textSecondary)
                                                        : (isDark ? Colors.grey[500] : Colors.grey[400]),
                                          height: 1.6,
                                                    fontStyle: deal.description.isEmpty ? FontStyle.italic : FontStyle.normal,
                                                  ),
                                        ),
                                      ),
                                              if (_isAdmin) ...[
                                                const SizedBox(width: 8),
                                                Icon(
                                                  Icons.edit,
                                                  size: 16,
                                                  color: primaryColor,
                                                ),
                                              ],
                                    ],
                                  ),
                                ),
                              ),
                                      const SizedBox(height: 12),
                                    ],
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
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primary,
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
                            backgroundColor: AppTheme.secondary,
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
                  if (_isAdmin && deal.isApproved != true)
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
                                backgroundColor: AppTheme.primary,
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
    bool isLoading = false,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
                                        borderRadius: BorderRadius.circular(12),
          child: Container(
          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
          decoration: BoxDecoration(
            color: isDark 
                ? Colors.white.withValues(alpha: 0.05) 
                : AppTheme.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected 
                  ? color.withValues(alpha: 0.3) 
                  : Colors.black.withValues(alpha: isDark ? 0.05 : 0.05),
              width: 0.5,
                              ),
                            ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isLoading)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(color),
                  ),
                )
              else
                Icon(
                  icon,
                  size: 16,
                  color: color,
                            ),
              const SizedBox(height: 3),
              Text(
                count.toString(),
                                        style: TextStyle(
                  fontSize: 13,
                                          fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                      ),
                                        ),
              const SizedBox(height: 1),
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

    // deal.category artık her zaman uygulama kategori ID'si (bot ID'leri normalize edildi)
    String initialCategoryId = Category.normalizeCategoryId(deal.category);
    if (initialCategoryId == 'tumu') {
      initialCategoryId = 'elektronik';
    }

    // State değişkenleri closure içinde tutulmalı (StatefulBuilder dışında)
    String selectedCategoryId = initialCategoryId;
    String? selectedSubCategory = deal.subCategory;
    bool isEditorPick = deal.isEditorPick;
    bool isApproved = deal.isApproved ?? false;
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
                'category': selectedCategoryId,
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
    
    // Anahtar kelime kontrolü yap - onaylanan fırsat için
    if (_currentDeal != null) {
      try {
        final notificationService = NotificationService();
        await notificationService.checkKeywordsAndNotify(
          id,
          _currentDeal!.title,
          _currentDeal!.description,
        );
        _log('✅ Anahtar kelime kontrolü yapıldı: ${_currentDeal!.title}');

        // Takip bildirimi artık Cloud Function tarafından otomatik gönderiliyor
        // Deal onaylandığında Firestore trigger tetiklenir ve Cloud Function bildirimleri gönderir
        if (_currentDeal!.isUserSubmitted && _currentDeal!.postedBy.isNotEmpty) {
          _log('ℹ️ Takip bildirimi Cloud Function tarafından gönderilecek: ${_currentDeal!.postedBy}');
        }
      } catch (e) {
        _log('❌ Anahtar kelime kontrolü hatası: $e');
      }
    }
    
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

  Future<void> _unpublishDeal(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Fırsatı Kaldır'),
        content: const Text('Bu fırsatı kaldırmak istediğinize emin misiniz?\n\nFırsat "Süresi Bitenler" bölümüne taşınacak.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Evet, Kaldır'),
            ),
          ],
        ),
      );

    if (confirm != true) return;

    // Fırsatı "süresi bitmiş" olarak işaretle (onay bekleyenlere düşmez)
    await _firestoreService.updateDeal(id, {'isExpired': true});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Fırsat kaldırıldı ve süresi bitenler bölümüne taşındı ⚠️'),
          backgroundColor: Colors.orange,
        ),
      );
      // Geri dön çünkü fırsat artık görünmeyecek
      Navigator.of(context).pop();
    }
  }

  Future<void> _showCategorySelector(Deal deal) async {
    if (_currentDeal == null) return;

    // Mevcut kategoriyi al (bot ID'leri normalize edilmiş olarak gelir)
    String initialCategoryId = Category.normalizeCategoryId(deal.category);
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
      String cleanUrl = link.trim();
      if (!cleanUrl.startsWith('http://') && !cleanUrl.startsWith('https://')) {
        cleanUrl = 'https://$cleanUrl';
      }
      
      final uri = Uri.parse(cleanUrl);
      
      // canLaunchUrl kontrolü yapmadan direkt dene - daha güvenilir
      try {
        // Önce external application ile dene
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
        if (launched) return;
      } catch (e) {
        // External başarısız, devam et
      }
      
      // External başarısız olduysa platform default dene
      try {
        final launched = await launchUrl(
          uri,
          mode: LaunchMode.platformDefault,
        );
        if (launched) return;
      } catch (e) {
        // Platform default da başarısız
      }
      
      // Son çare: inAppWebView (eğer destekleniyorsa)
      try {
        await launchUrl(
          uri,
          mode: LaunchMode.inAppWebView,
        );
    } catch (e) {
        // Tüm yöntemler başarısız oldu
        throw Exception('Bağlantı açılamadı');
      }
    } catch (e) {
      _log('❌ URL açma hatası: $e');
      _log('❌ URL: $link');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Bağlantı açılamadı: ${e.toString()}'),
            duration: const Duration(seconds: 4),
            backgroundColor: Colors.red,
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

    // Zengin paylaşım metni
    final priceText = deal.price > 0 ? '💰 ${deal.price.toStringAsFixed(0)} TL' : '';
    final discountText = deal.discountRate != null && deal.discountRate! > 0 
        ? ' (-%${deal.discountRate})' 
        : '';
    final shareText = '''🔥 ${deal.title}
🏪 ${deal.store}
$priceText$discountText

👉 ${deal.link}

📱 FIRSATKOLİK ile keşfet!''';

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


  void _showCommentsBottomSheet(BuildContext context, Deal deal, {String? scrollToCommentId}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CommentsBottomSheet(
        deal: deal,
        scrollToCommentId: scrollToCommentId,
      ),
    );
  }

  // Affiliate Link Configuration
  static const Map<String, Map<String, String>> _affiliateConfig = {
    'trendyol': {
      'boutiqueId': '', // Trendyol Boutique ID'nizi buraya ekleyin
    },
    'hepsiburada': {
      'utmSource': 'linkgelir', // Hepsiburada Link Gelir için genellikle 'linkgelir' kullanılır
    },
    'n11': {
      'refId': '', // N11 Referans ID'nizi buraya ekleyin
    },
    'amazon': {
      'tag': '', // Amazon Associate Tag'inizi buraya ekleyin
    },
    'gittigidiyor': {
      'affiliateId': '', // GittiGidiyor Affiliate ID'nizi buraya ekleyin
    },
  };

  Future<String?> _resolveShortLink(String shortUrl) async {
    try {
      final projectId = DefaultFirebaseOptions.flavorProjectId;
      final functionsUrl =
          'https://us-central1-$projectId.cloudfunctions.net/resolveShortLink';
      final uri = Uri.parse('$functionsUrl?url=${Uri.encodeComponent(shortUrl)}');
      
      String? token;
      try {
        token = await FirebaseAppCheck.instance.getToken();
      } catch (e) {
        _log('App Check token alınamadı: $e');
      }

      final response = await http.get(
        uri,
        headers: {
          if (token != null) 'X-Firebase-AppCheck': token,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['resolvedUrl'] != null) {
          return data['resolvedUrl'] as String;
        }
      }
      return null;
    } catch (e) {
      _log('Kısa link çözme hatası: $e');
      return null;
    }
  }

  String _detectStoreFromUrl(String url) {
    if (url.isEmpty) return 'Bilinmeyen';

    try {
      final uri = Uri.parse(url);
      final hostname = uri.host.toLowerCase();

      if (hostname.contains('trendyol.com')) return 'Trendyol';
      if (hostname.contains('hepsiburada.com')) return 'Hepsiburada';
      if (hostname.contains('n11.com')) return 'N11';
      if (hostname.contains('amazon.com')) return 'Amazon';
      if (hostname.contains('gittigidiyor.com')) return 'GittiGidiyor';

      return 'Bilinmeyen';
    } catch (e) {
      return 'Bilinmeyen';
    }
  }

  String _convertToAffiliateLink(String originalUrl) {
    if (originalUrl.isEmpty) return originalUrl;

    try {
      final uri = Uri.parse(originalUrl);
      final hostname = uri.host.toLowerCase();

      // Hepsiburada kısa link kontrolü
      if (hostname.contains('hb.biz') || hostname.contains('app.hb.biz')) {
        _log('ℹ️ Kısa link tespit edildi: $originalUrl');
        return originalUrl;
      }

      // Trendyol
      if (hostname.contains('trendyol.com')) {
        final boutiqueId = _affiliateConfig['trendyol']?['boutiqueId'];
        if (boutiqueId != null && boutiqueId.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('boutiqueId');
          newQueryParams['boutiqueId'] = boutiqueId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // Hepsiburada (Link Gelir)
      if (hostname.contains('hepsiburada.com')) {
        final utmSource = _affiliateConfig['hepsiburada']?['utmSource'];
        if (utmSource != null && utmSource.isNotEmpty) {
          final existingUtmSource = uri.queryParameters['utm_source'];
          if (existingUtmSource == utmSource) {
            _log('ℹ️ Link zaten kendi affiliate linkiniz: $originalUrl');
            return originalUrl;
          }

          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('utm_source');
          newQueryParams.remove('utm_medium');
          newQueryParams.remove('utm_campaign');
          newQueryParams.remove('utm_content');
          newQueryParams.remove('wt_inf');

          newQueryParams['utm_source'] = utmSource;
          newQueryParams['utm_medium'] = 'referral';
          newQueryParams['utm_campaign'] = 'urun_paylasim';

          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // N11
      if (hostname.contains('n11.com')) {
        final refId = _affiliateConfig['n11']?['refId'];
        if (refId != null && refId.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('ref');
          newQueryParams['ref'] = refId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // Amazon
      if (hostname.contains('amazon.com.tr') || hostname.contains('amazon.com')) {
        final tag = _affiliateConfig['amazon']?['tag'];
        if (tag != null && tag.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('tag');
          newQueryParams['tag'] = tag;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      // GittiGidiyor
      if (hostname.contains('gittigidiyor.com')) {
        final affiliateId = _affiliateConfig['gittigidiyor']?['affiliateId'];
        if (affiliateId != null && affiliateId.isNotEmpty) {
          final newQueryParams = Map<String, String>.from(uri.queryParameters);
          newQueryParams.remove('affiliateId');
          newQueryParams['affiliateId'] = affiliateId;
          final newUri = uri.replace(queryParameters: newQueryParams);
          return newUri.toString();
        }
      }

      return originalUrl;
    } catch (e) {
      _log('Link dönüştürme hatası: $e');
      return originalUrl;
    }
  }

  Future<void> _showAdminEditDialog(Deal deal) async {
    final titleController = TextEditingController(text: deal.title);
    final descriptionController = TextEditingController(text: deal.description);
    final priceController = TextEditingController(text: deal.price.toStringAsFixed(2));
    final originalPriceController = TextEditingController(
      text: deal.originalPrice?.toStringAsFixed(2) ?? '',
    );
    final linkController = TextEditingController(text: deal.link);

    // Kategori eşleştirmesi
    String? selectedCategoryId;
    String? selectedSubCategory = deal.subCategory;
    
    final normalizedDealCategory = deal.category.toLowerCase().trim();

    // 1. Adım: ID ile tam eşleşme kontrolü
    for (final cat in Category.categories) {
      if (cat.id.toLowerCase() == normalizedDealCategory) {
        selectedCategoryId = cat.id;
        break;
      }
    }

    // 2. Adım: İsim ile eşleşme kontrolü (case-insensitive)
    if (selectedCategoryId == null) {
      for (final cat in Category.categories) {
        if (cat.name.toLowerCase() == normalizedDealCategory) {
          selectedCategoryId = cat.id;
          break;
        }
      }
    }

    // 3. Adım: Özel eşleştirmeler (eski veriler veya farklı formatlar için)
    if (selectedCategoryId == null) {
      if (normalizedDealCategory.contains('giyim') || normalizedDealCategory.contains('moda')) {
        selectedCategoryId = 'moda';
      } else if (normalizedDealCategory.contains('ev') || normalizedDealCategory.contains('yasam')) {
        selectedCategoryId = 'ev_yasam';
      } else if (normalizedDealCategory.contains('bebek') || normalizedDealCategory.contains('anne')) {
        selectedCategoryId = 'anne_bebek';
      } else if (normalizedDealCategory.contains('kozmetik') || normalizedDealCategory.contains('bakim')) {
        selectedCategoryId = 'kozmetik';
      } else if (normalizedDealCategory.contains('spor')) {
        selectedCategoryId = 'spor_outdoor';
      } else if (normalizedDealCategory.contains('market') && !normalizedDealCategory.contains('yapi')) {
        selectedCategoryId = 'supermarket';
      } else if (normalizedDealCategory.contains('yapi') || normalizedDealCategory.contains('oto')) {
        selectedCategoryId = 'yapi_oto';
      } else if (normalizedDealCategory.contains('kitap') || normalizedDealCategory.contains('hobi')) {
        selectedCategoryId = 'kitap_hobi';
      } else if (normalizedDealCategory.contains('elektronik') || normalizedDealCategory.contains('telefon') || normalizedDealCategory.contains('bilgisayar')) {
        selectedCategoryId = 'elektronik';
      }
    }

    // Bulunamazsa varsayılan olarak 'diger' kullan (listede varsa)
    if (selectedCategoryId == null) {
       // 'diger' kategorisi var mı kontrol et, yoksa 'elektronik' yap
       final hasDiger = Category.categories.any((c) => c.id == 'diger');
       selectedCategoryId = hasDiger ? 'diger' : 'elektronik';
    }
    
    // Alt kategori kontrolü: Eğer mevcut alt kategori, seçili kategorinin subcategories listesinde yoksa null yap
    if (selectedSubCategory != null && selectedCategoryId != null) {
      final category = Category.categories.firstWhere(
        (cat) => cat.id == selectedCategoryId,
        orElse: () => Category.categories.first,
      );
      if (!category.subcategories.contains(selectedSubCategory)) {
        selectedSubCategory = null; // Geçersiz alt kategori, null yap
      }
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          title: Text(
            'Ürün Bilgilerini Düzenle',
            style: TextStyle(color: textColor),
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: titleController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Başlık',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descriptionController,
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      labelText: 'Açıklama',
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                    ),
                    maxLines: 4,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Fiyat (₺)',
                            border: OutlineInputBorder(),
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: originalPriceController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Eski Fiyat (₺)',
                            border: OutlineInputBorder(),
                            hintText: 'Opsiyonel',
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Link alanı ve Affiliate Link'e Dönüştür butonu
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.link, color: Theme.of(context).colorScheme.primary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Ürün Linki',
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.w700,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: linkController,
                          style: TextStyle(color: textColor),
                          decoration: InputDecoration(
                            labelText: 'Ürün URL',
                            border: OutlineInputBorder(),
                            hintText: 'https://...',
                            filled: true,
                            fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                            prefixIcon: Icon(Icons.link, color: textColor.withValues(alpha: 0.6)),
                            suffixIcon: linkController.text.isNotEmpty
                                ? IconButton(
                                    icon: Icon(
                                      Icons.close,
                                      color: Colors.grey[600],
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setState(() {
                                        linkController.clear();
                                      });
                                    },
                                    tooltip: 'Linki Temizle',
                                  )
                                : null,
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: (value) {
                            setState(() {}); // Trigger rebuild to show/hide clear button
                          },
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final currentUrl = linkController.text.trim();
                              if (currentUrl.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Lütfen önce bir URL girin'),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
      return;
    }

                              // Loading göster
                              showDialog(
                                context: context,
                                barrierDismissible: false,
                                builder: (context) => const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              );

                              try {
                                String urlToConvert = currentUrl;

                                // Kısa link kontrolü (Hepsiburada kısa linkleri)
                                if (urlToConvert.contains('hb.biz') ||
                                    urlToConvert.contains('app.hb.biz')) {
                                  try {
                                    final resolvedUrl = await _resolveShortLink(urlToConvert);
                                    if (resolvedUrl != null && resolvedUrl.isNotEmpty) {
                                      urlToConvert = resolvedUrl;
                                      _log('✅ Kısa link çözüldü: $urlToConvert');
                                    }
                                  } catch (e) {
                                    _log('⚠️ Kısa link çözülemedi: $e');
                                  }
                                }

                                // Affiliate link'e dönüştür
                                final convertedUrl = _convertToAffiliateLink(urlToConvert);

                                if (context.mounted) {
                                  Navigator.pop(context); // Loading dialog'u kapat

                                  if (convertedUrl != urlToConvert) {
                                    setState(() {
                                      linkController.text = convertedUrl;
                                    });
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('✅ Affiliate link\'e dönüştürüldü!'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } else {
                                    final store = _detectStoreFromUrl(urlToConvert);
                                    if (store == 'Bilinmeyen') {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('⚠️ Bu mağaza desteklenmiyor'),
                                          backgroundColor: Colors.orange,
                                        ),
                                      );
                                    } else {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                              'ℹ️ Link zaten affiliate link veya $store için affiliate ID yapılandırılmamış'),
                                          backgroundColor: Colors.blue,
                                        ),
                                      );
                                    }
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  Navigator.pop(context); // Loading dialog'u kapat
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('❌ Hata: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.swap_horiz, size: 20),
                            label: const Text(
                              'Affiliate Link\'e Dönüştür',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
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
                  'link': linkController.text.trim(),
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

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text(
          'Fiyat Düzenle',
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: priceController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Güncel Fiyat (₺)',
                border: OutlineInputBorder(),
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: originalPriceController,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: 'Eski Fiyat (₺)',
                border: OutlineInputBorder(),
                hintText: 'Opsiyonel',
                filled: true,
                fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
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

  Future<void> _showEditDescriptionDialog(Deal deal) async {
    if (!_isAdmin) return;
    
    final descriptionController = TextEditingController(text: deal.description);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        title: Text(
          'Açıklama Düzenle',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: TextField(
          controller: descriptionController,
          autofocus: true,
          maxLines: 6,
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black,
          ),
          decoration: InputDecoration(
            hintText: 'Ürün açıklamasını girin',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: Theme.of(context).colorScheme.primary,
                width: 2,
              ),
            ),
            filled: true,
            fillColor: isDark ? Colors.grey[800]!.withValues(alpha: 0.3) : Colors.grey[50],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'İptal',
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              final newDescription = descriptionController.text.trim();
              
              final success = await _firestoreService.updateDeal(
                widget.dealId,
                {'description': newDescription},
              );
              
              if (context.mounted) {
                Navigator.pop(context);
                if (success) {
                  await _loadDeal();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Açıklama güncellendi ✅'),
                      backgroundColor: Colors.green,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Güncelleme sırasında bir hata oluştu ❌'),
                      backgroundColor: Colors.red,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
            ),
            child: const Text(
              'Kaydet',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCategoryEditDialog(Deal deal) async {
    String resolvedId = Category.normalizeCategoryId(deal.category);
    String? selectedCategoryId = resolvedId != 'tumu' ? resolvedId : null;
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

