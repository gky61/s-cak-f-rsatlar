import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:sicak_firsatlar/utils/asset_path_migration.dart';

import '../models/deal.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import 'botkolik_profile_screen.dart';
import 'message_screen.dart';

import '../widgets/report_dialog.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../widgets/deal_thermometer.dart';
import '../widgets/money_badge.dart';
import '../widgets/deal_card/deal_card_helpers.dart';
import 'deal_detail/deal_detail_helpers.dart';
import 'deal_detail/deal_detail_image.dart';
import 'deal_detail/deal_share_sheet.dart';
import 'deal_detail/deal_admin_dialogs.dart';
import '../widgets/skeletons/deal_detail_skeleton.dart';

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
  bool _hasVotedHot = false;
  bool _hasVotedCold = false;
  bool _hasVotedExpired = false;
  bool _isExpiredVoting = false;
  int _hotVotes = 0;
  int _coldVotes = 0;
  int _expiredVotes = 0;
  bool _dealNotFound = false;
  bool _hasAutoOpenedComments = false; // Bildirimden açılan yorum penceresinin tekrar tekrar açılmasını engeller
  Timer? _voteDebounceTimer;

  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _loadDeal();
    _checkAdminStatus();
    _checkFavoriteStatus();
    _checkUserVote();
    _authSub = _authService.authStateChanges.listen((user) {
      if (mounted) {
        _checkAdminStatus();
        _checkFavoriteStatus();
        _checkUserVote();
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _voteDebounceTimer?.cancel();
    _authSub?.cancel();
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
    final hasExpired = await _firestoreService.hasUserVotedExpired(_currentDeal!.id, user.uid);
    if (mounted) {
      setState(() {
        _hasVotedHot = vote == 'hot';
        _hasVotedCold = vote == 'cold';
        _hasVotedExpired = hasExpired;
      });
    }
  }

  // Kaydet/Favorile toggle - Kişisel aksiyon, skoru etkilemez
  Future<void> _toggleFavorite() async {
    final user = _authService.currentUser;
    if (user == null) {
      final loggedIn = await showGuestLoginBottomSheet(
        context,
        title: 'Fırsatı Kaydetmek İçin Giriş Yap! 🔖',
        message: 'Beğendiğin fırsatları daha sonra kolayca bulmak ve kaçırmamak için hesabına kaydet.',
        primaryButtonText: '🚀 Google ile Giriş Yap',
      );
      if (loggedIn == true && mounted) {
        _checkFavoriteStatus();
        _toggleFavorite();
      }
      return;
    }
    if (_currentDeal == null) return;

    final previousFavorite = _isFavorite;
    // Optimistic UI
    setState(() {
      _isFavorite = !_isFavorite;
    });

    bool success;
    if (_isFavorite) {
      success = await _firestoreService.addToFavorites(
        user.uid,
        _currentDeal!.id,
        title: _currentDeal!.title,
        price: _currentDeal!.price,
        store: _currentDeal!.store,
        link: _currentDeal!.link,
        imageUrl: _currentDeal!.imageUrl,
      );
    } else {
      success = await _firestoreService.removeFromFavorites(user.uid, _currentDeal!.id);
    }

    if (!success && mounted) {
      setState(() {
        _isFavorite = previousFavorite;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isFavorite ? 'Kaydedilemedi. Lütfen tekrar deneyin.' : 'Kayıt kaldırılamadı. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _handleVote(bool isHot) {
    final user = _authService.currentUser;
    if (user == null) {
      showGuestLoginBottomSheet(
        context,
        title: 'Bu Fırsatı Oylamak İçin Giriş Yap! 🔥',
        message: 'Topluluğa yön vermek ve fırsatın sıcaklığını oylamak için hızlıca giriş yapabilirsin.',
        primaryButtonText: '🚀 Google ile Giriş Yap',
      ).then((loggedIn) {
        if (loggedIn == true && mounted) {
          _checkUserVote();
          _handleVote(isHot);
        }
      });
      return;
    }

    if (_currentDeal == null) return;

    // Anında Optimistic UI Güncellemesi (0ms gecikme, kilitlenme yok)
    setState(() {
      if (isHot) {
        if (_hasVotedHot) {
          // Sıcak oyu geri al (toggle off)
          _hasVotedHot = false;
          _hotVotes = (_hotVotes > 0) ? _hotVotes - 1 : 0;
        } else {
          // Sıcak oyu ver (Soğuk oy varsa onu düşür)
          if (_hasVotedCold) {
            _hasVotedCold = false;
            _coldVotes = (_coldVotes > 0) ? _coldVotes - 1 : 0;
          }
          _hasVotedHot = true;
          _hotVotes += 1;
        }
      } else {
        if (_hasVotedCold) {
          // Soğuk oyu geri al (toggle off)
          _hasVotedCold = false;
          _coldVotes = (_coldVotes > 0) ? _coldVotes - 1 : 0;
        } else {
          // Soğuk oyu ver (Sıcak oy varsa onu düşür)
          if (_hasVotedHot) {
            _hasVotedHot = false;
            _hotVotes = (_hotVotes > 0) ? _hotVotes - 1 : 0;
          }
          _hasVotedCold = true;
          _coldVotes += 1;
        }
      }
    });

    // Firestore ile Arka Plan Debounced Senkronizasyon (300ms)
    _voteDebounceTimer?.cancel();
    _voteDebounceTimer = Timer(const Duration(milliseconds: 300), () async {
      if (!mounted || _currentDeal == null) return;
      final targetVote = _hasVotedHot ? 'hot' : (_hasVotedCold ? 'cold' : null);
      try {
        if (targetVote == 'hot') {
          await _firestoreService.addHotVote(_currentDeal!.id, user.uid);
        } else if (targetVote == 'cold') {
          await _firestoreService.addColdVote(_currentDeal!.id, user.uid);
        } else {
          await _firestoreService.removeVote(_currentDeal!.id, user.uid);
        }
      } catch (e) {
        // Hata durumunda sessizce logla
      }
    });
  }

  Future<void> _handleExpiredVote() async {
    final user = _authService.currentUser;
    if (user == null) {
      final loggedIn = await showGuestLoginBottomSheet(
        context,
        title: 'Fırsat Bildirimi Yapmak İçin Giriş Yap! ⚠️',
        message: 'Fırsatın bittiğini topluluğa bildirmek için hızlıca giriş yapabilirsin.',
        primaryButtonText: '🚀 Google ile Giriş Yap',
      );
      if (loggedIn == true && mounted) {
        _checkUserVote();
        _handleExpiredVote();
      }
      return;
    }

    if (_currentDeal == null) return;

    // Spam click önleme
    if (_isExpiredVoting) {
      return;
    }

    // Eğer zaten expired vermişse ve tekrar basarsa, geri al (toggle)
    if (_hasVotedExpired) {
      await _removeExpiredVote();
      return;
    }

    // Loading state
    setState(() {
      _isExpiredVoting = true;
    });

    // Önceki durumları kaydet
    final previousExpiredVote = _hasVotedExpired;
    final previousExpiredVotes = _expiredVotes;

    // Optimistic UI update - Bağımsız durum bildirimi (AL/GEÇ oyuna dokunmaz)
    setState(() {
      _hasVotedExpired = true;
      _expiredVotes += 1;
    });

    // Firestore'a kaydet
    final success = await _firestoreService.addExpiredVote(_currentDeal!.id, user.uid);

    if (!success && mounted) {
      // Hata durumunda önceki duruma geri dön
      setState(() {
        _hasVotedExpired = previousExpiredVote;
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

  Future<void> _removeExpiredVote() async {
    final user = _authService.currentUser;
    if (user == null || _currentDeal == null) return;

    setState(() {
      _isExpiredVoting = true;
    });

    final previousExpiredVote = _hasVotedExpired;
    final previousExpiredVotes = _expiredVotes;

    setState(() {
      _hasVotedExpired = false;
      _expiredVotes = _expiredVotes > 0 ? _expiredVotes - 1 : 0;
    });

    final success = await _firestoreService.removeExpiredVote(_currentDeal!.id, user.uid);

    if (!success && mounted) {
      setState(() {
        _hasVotedExpired = previousExpiredVote;
        _expiredVotes = previousExpiredVotes;
        _isExpiredVoting = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Oy geri alınırken bir hata oluştu. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      _isExpiredVoting = false;
    });
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
      if (deal == null) {
        if (mounted) {
          setState(() {
            _dealNotFound = true;
          });
        }
        return;
      }
      if (mounted) {
        setState(() {
          _currentDeal = deal;
          _hotVotes = deal.hotVotes;
          _coldVotes = deal.coldVotes;
          _expiredVotes = deal.expiredVotes;
        });
        _checkUserVote();
        // Eğer görsel yoksa, linkten çekmeyi dene
        if (deal.imageUrl.isEmpty && deal.link.isNotEmpty && !_hasTriedFetching) {
          _fetchImageFromLink(deal.link);
        }
        
        // Eğer scrollToCommentId varsa ve henüz otomatik açılmadıysa, yorumlar bottom sheet'ini tam 1 defa aç
        if (widget.scrollToCommentId != null && !_hasAutoOpenedComments && mounted) {
          _hasAutoOpenedComments = true;
          Future.delayed(const Duration(milliseconds: 400), () {
            if (mounted && context.mounted && _currentDeal != null) {
              _showCommentsBottomSheet(
                context,
                _currentDeal!,
                scrollToCommentId: widget.scrollToCommentId,
              );
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
    
    if (_dealNotFound) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
        appBar: AppBar(
          title: const Text('Fırsat Bulunamadı'),
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          elevation: 0,
          iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.sentiment_dissatisfied_rounded, size: 72, color: Colors.grey[400]),
                const SizedBox(height: 16),
                const Text(
                  'Aradığınız fırsat yayından kaldırılmış veya silinmiş olabilir.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Geri Dön'),
                ),
              ],
            ),
          ),
        ),
      );
    }
    
    // _currentDeal null ise skeleton loading göster
    if (_currentDeal == null) {
      return Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        appBar: AppBar(
          backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
          foregroundColor: isDark ? Colors.white : AppTheme.textPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: const Text(
            'Fırsat Detayı',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
          ),
          centerTitle: true,
        ),
        body: const DealDetailSkeleton(),
      );
    }
    
    return _buildDealDetail(context, _currentDeal!);
  }

  Widget _buildDealDetail(BuildContext context, Deal deal) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
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

    return SelectionArea(
      child: PopScope(
        canPop: true,
        onPopInvokedWithResult: (bool didPop, dynamic result) {
          if (didPop) return;
        },
        child: Scaffold(
          backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
          body: Stack(
          children: [
            // Main CustomScrollView
            CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // 1. Immersive Hero Image Header (SliverAppBar - scrolls off screen)
                SliverAppBar(
                  expandedHeight: MediaQuery.of(context).size.width * 0.75, // 4:3 Aspect Ratio
                  pinned: false,
                  floating: false,
                  elevation: 0,
                  backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
                  automaticallyImplyLeading: false,
                  flexibleSpace: FlexibleSpaceBar(
                    background: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Main Hero Image
                        GestureDetector(
                          onTap: () {
                            String? imageUrl;
                            if (!_originalImageFailed && deal.imageUrl.isNotEmpty) {
                              imageUrl = deal.imageUrl;
                            } else if (_fetchedImageUrl != null && _fetchedImageUrl!.isNotEmpty) {
                              imageUrl = _fetchedImageUrl;
                            }
                            if (imageUrl != null && imageUrl.isNotEmpty) {
                              _showFullScreenImage(imageUrl);
                            }
                          },
                          child: Container(
                            color: isDark ? Colors.grey[950] : Colors.white,
                            child: _buildDetailImage(deal),
                          ),
                        ),
                        // Gradient Overlay for Header contrast
                        Positioned.fill(
                          child: IgnorePointer(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.black.withValues(alpha: 0.42),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.2),
                                  ],
                                  stops: const [0.0, 0.35, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Floating Discount Badge (Bottom Right over Image)
                        if (deal.discountRate != null && deal.discountRate! > 0)
                          Positioned(
                            bottom: 30,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFFFF5722), Color(0xFFDC2626)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.45),
                                  width: 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFFDC2626).withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department_rounded, color: Colors.white, size: 16),
                                  const SizedBox(width: 4),
                                  Text(
                                    '%${deal.discountRate} İNDİRİM',
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.4,
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

                // 2. Rounded Main Content Sheet (SliverToBoxAdapter with minHeight)
                SliverToBoxAdapter(
                  child: Container(
                    constraints: BoxConstraints(
                      minHeight: MediaQuery.of(context).size.height - 
                          MediaQuery.of(context).padding.top - 
                          MediaQuery.of(context).padding.bottom - 60,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? AppTheme.darkSurface : Colors.white,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.06),
                          blurRadius: 24,
                          offset: const Offset(0, -8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Handle Indicator
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 18),
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Info Section - 2 Column Layout
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Sol grup: Satıcı + Marka
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Satıcı Pill
                                        Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(horizontal: 9),
                                          decoration: BoxDecoration(
                                            color: isDark 
                                                ? AppTheme.darkSurfaceElevated 
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark 
                                                  ? AppTheme.darkBorder 
                                                  : const Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child: Center(
                                                  child: buildStoreLogo(deal.store, size: 16, borderRadius: 3.5),
                                                ),
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Satıcı: ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                ),
                                              ),
                                              Flexible(
                                                child: Text(
                                                  deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                                  style: TextStyle(
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              if (deal.isAmazonWarehouse) ...[
                                                const SizedBox(width: 4),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1.5),
                                                  decoration: BoxDecoration(
                                                    color: const Color(0xFFD97706).withValues(alpha: 0.15),
                                                    borderRadius: BorderRadius.circular(4),
                                                  ),
                                                  child: const Text(
                                                    'Depo',
                                                    style: TextStyle(
                                                      fontSize: 8.5,
                                                      fontWeight: FontWeight.w800,
                                                      color: Color(0xFFD97706),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        // Marka Pill
                                        if (deal.brand != null && deal.brand!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            height: 32,
                                            padding: const EdgeInsets.symmetric(horizontal: 9),
                                            decoration: BoxDecoration(
                                              color: isDark 
                                                  ? AppTheme.darkSurfaceElevated 
                                                  : const Color(0xFFF1F5F9),
                                              borderRadius: BorderRadius.circular(10),
                                              border: Border.all(
                                                color: isDark 
                                                    ? AppTheme.darkBorder 
                                                    : const Color(0xFFE2E8F0),
                                                width: 1.0,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.verified_rounded, size: 14, color: primaryColor),
                                                const SizedBox(width: 5),
                                                Text(
                                                  'Marka: ',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    deal.brand!,
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                                                    ),
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  // Sağ grup: Paylaşan (Üstte) + Kategori (Altta)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // 1. Paylaşan Botkolik veya Kullanıcı Kartı (Üstte)
                                      if (deal.isBotkolik)
                                        _buildCompactBotkolikCard(deal, isDark, primaryColor)
                                      else if (deal.postedBy.isNotEmpty && deal.isUserSubmitted)
                                        _buildCompactDealAuthorCard(deal, isDark, primaryColor),
                                      if (deal.isBotkolik || (deal.postedBy.isNotEmpty && deal.isUserSubmitted))
                                        const SizedBox(height: 8),
                                      // 2. Category Pill (Altta)
                                      InkWell(
                                        onTap: _isAdmin ? () => _showCategoryEditDialog(deal) : null,
                                        borderRadius: BorderRadius.circular(10),
                                        child: Container(
                                          height: 32,
                                          padding: const EdgeInsets.symmetric(horizontal: 10),
                                          decoration: BoxDecoration(
                                            color: isDark 
                                                ? AppTheme.darkSurfaceElevated 
                                                : const Color(0xFFF1F5F9),
                                            borderRadius: BorderRadius.circular(10),
                                            border: Border.all(
                                              color: isDark 
                                                  ? AppTheme.darkBorder 
                                                  : const Color(0xFFE2E8F0),
                                              width: 1.0,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                category.name.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF334155),
                                                  letterSpacing: 0.5,
                                                ),
                                              ),
                                              if (_isAdmin) ...[
                                                const SizedBox(width: 4),
                                                Icon(Icons.edit_rounded, size: 11, color: primaryColor),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),

                              const SizedBox(height: 14),

                              // Editor's Pick Badge
                              if (deal.isEditorPick)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4, bottom: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                                          blurRadius: 8,
                                          offset: const Offset(0, 3),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.star_rounded, color: Colors.white, size: 16),
                                        SizedBox(width: 6),
                                        Text(
                                          'Editörün Seçimi',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),

                              // Product Title
                              SelectableText(
                                deal.title,
                                style: TextStyle(
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                  height: 1.35,
                                  letterSpacing: -0.3,
                                ),
                              ),

                              if (deal.ratingValue != null || deal.ratingCount != null) ...[
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF282008) : const Color(0xFFFFFBEB),
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: const Color(0xFFFDE68A).withValues(alpha: isDark ? 0.35 : 0.85),
                                          width: 1.0,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 16.5,
                                            color: Color(0xFFF59E0B),
                                          ),
                                          const SizedBox(width: 4),
                                          if (deal.ratingValue != null)
                                            Text(
                                              deal.ratingValue!.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? const Color(0xFFFBBF24) : const Color(0xFFB45309),
                                              ),
                                            ),
                                          if (deal.ratingCount != null) ...[
                                            const SizedBox(width: 5),
                                            Text(
                                              '(${deal.ratingCount} değerlendirme)',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                              ),
                                            ),
                                          ],
                                          if (MoneyBadge.isMoneyDeal(deal)) ...[
                                            const SizedBox(width: 6),
                                            const MoneyBadge(
                                              fontSize: 11,
                                              iconSize: 13,
                                              padding: EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              const SizedBox(height: 20),

                              // 3 Stat Cards Grid (Kaydet, Yorum, Fırsat Bitti)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildStatButton(
                                      icon: _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                      count: -1,
                                      label: _isFavorite ? 'Kaydedildi' : 'Kaydet',
                                      color: const Color(0xFFF59E0B),
                                      onTap: _toggleFavorite,
                                      isSelected: _isFavorite,
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8.5),
                                  Expanded(
                                    child: _buildStatButton(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      count: deal.commentCount,
                                      label: 'Yorum',
                                      color: const Color(0xFF3B82F6),
                                      onTap: () => _showCommentsBottomSheet(
                                        context, 
                                        deal,
                                        scrollToCommentId: widget.scrollToCommentId,
                                      ),
                                      isDark: isDark,
                                    ),
                                  ),
                                  const SizedBox(width: 8.5),
                                  Expanded(
                                    child: _buildStatButton(
                                      icon: _hasVotedExpired ? Icons.cancel_rounded : Icons.cancel_outlined,
                                      count: _expiredVotes,
                                      label: _hasVotedExpired ? 'Bitti (Oylandı)' : 'Fırsat Bitti',
                                      color: const Color(0xFFEF4444),
                                      onTap: _handleExpiredVote,
                                      isSelected: _hasVotedExpired,
                                      isDark: isDark,
                                      isLoading: _isExpiredVoting,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 20),

                              // Deal Thermometer Section
                              DealThermometer(
                                deal: deal,
                                hotVotes: _hotVotes,
                                coldVotes: _coldVotes,
                                hasVotedHot: _hasVotedHot,
                                hasVotedCold: _hasVotedCold,
                                onVote: _handleVote,
                              ),

                              const SizedBox(height: 26),

                              // Description Header & Sharing Date
                              Row(
                                children: [
                                  Container(
                                    width: 3.5,
                                    height: 16,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primaryColor, const Color(0xFFFF8E53)],
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                      ),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'ÜRÜN DETAYLARI',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Şık & Modern Paylaşım Tarihi
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                                    decoration: BoxDecoration(
                                      color: isDark 
                                          ? AppTheme.darkSurfaceElevated 
                                          : const Color(0xFFF1F5F9),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: isDark 
                                            ? AppTheme.darkBorder 
                                            : const Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 13,
                                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          formatExactDateTime(deal.createdAt),
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),

                              // Amazon Depo Bilgilendirme Kartı (Ürün Detayları Alanı)
                              if (deal.isAmazonWarehouse) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: isDark 
                                        ? const Color(0xFF451A03).withValues(alpha: 0.35) 
                                        : const Color(0xFFFFFBEB),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isDark 
                                          ? const Color(0xFFB45309).withValues(alpha: 0.5) 
                                          : const Color(0xFFFDE68A),
                                      width: 1.0,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.inventory_2_rounded,
                                          color: Color(0xFFD97706),
                                          size: 18,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              '📦 Amazon Depo Ürünü',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w800,
                                                color: Color(0xFFB45309),
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              'Bu ürün Amazon Depo satıcılıdır. Ürün yenilenmiş veya ikinci el olabilir.',
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.grey[300] : const Color(0xFF78350F),
                                                height: 1.35,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Description Content Card
                              if (deal.description.isNotEmpty || _isAdmin) ...[
                                GestureDetector(
                                  onTap: _isAdmin ? () => _showEditDescriptionDialog(deal) : null,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark 
                                          ? AppTheme.darkSurfaceElevated 
                                          : const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark 
                                            ? AppTheme.darkBorder 
                                            : const Color(0xFFE2E8F0),
                                        width: 1.0,
                                      ),
                                    ),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: _buildDescriptionWidget(deal.description, isDark, primaryColor, deal.store),
                                        ),
                                        if (_isAdmin) ...[
                                          const SizedBox(width: 8),
                                          Icon(Icons.edit_rounded, size: 16, color: primaryColor),
                                        ],
                                      ],
                                    ),
                                  ),
                                ),
                              ],

                              const SizedBox(height: 120), // Bottom Sticky Bar Spacing
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // 3. Floating Frosted Sticky Bottom Action Bar
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ClipRect(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                  child: Container(
                    padding: EdgeInsets.only(
                      left: 20,
                      right: 20,
                      top: 14,
                      bottom: MediaQuery.of(context).padding.bottom + 14,
                    ),
                    decoration: BoxDecoration(
                      color: (isDark ? AppTheme.darkSurface : Colors.white).withValues(alpha: 0.95),
                      border: Border(
                        top: BorderSide(
                          color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.06),
                          blurRadius: 20,
                          offset: const Offset(0, -6),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Price Column
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  // Money ile Rozeti (Fiyatın tam üstünde)
                                  if (MoneyBadge.isMoneyDeal(deal)) ...[
                                    const MoneyBadge(
                                      fontSize: 10,
                                      iconSize: 13,
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                    ),
                                    const SizedBox(height: 5),
                                  ],
                                  if (!deal.hidePrice)
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          // Sol: İndirimli (Fırsat) Fiyatı
                                          FormattedPriceText(
                                            value: deal.price,
                                            style: const TextStyle(
                                              fontSize: 23,
                                              fontWeight: FontWeight.w900,
                                              color: AppTheme.primary,
                                              height: 1.0,
                                              letterSpacing: -0.5,
                                            ),
                                          ),
                                          // Sağ: İndirim Etiketi üstte, İndirimsiz Fiyat altta
                                          if (deal.originalPrice != null && deal.originalPrice! > deal.price) ...[
                                            const SizedBox(width: 8),
                                            Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // İndirim Etiketi
                                                if (deal.effectiveDiscountRate != null && deal.effectiveDiscountRate! > 0)
                                                  Container(
                                                    margin: const EdgeInsets.only(bottom: 2),
                                                    padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                                                    decoration: BoxDecoration(
                                                      gradient: const LinearGradient(
                                                        colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                                                      ),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      '%${deal.effectiveDiscountRate} İndirim',
                                                      style: const TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w900,
                                                        color: Colors.white,
                                                        letterSpacing: 0.2,
                                                      ),
                                                    ),
                                                  ),
                                                // İndirimsiz (Eski) Fiyat
                                                FormattedPriceText(
                                                  value: deal.originalPrice,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                    color: isDark ? const Color(0xFF64748B) : const Color(0xFF94A3B8),
                                                    decoration: TextDecoration.lineThrough,
                                                    decorationThickness: 1.5,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                  if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ...[
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFFFF7ED),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFDBA74).withValues(alpha: 0.6),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Text(
                                        deal.priceLabel!,
                                        style: const TextStyle(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFEA580C),
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(width: 10),

                            // Main CTA Button ("Mağazaya Git")
                            Container(
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: deal.isExpired 
                                      ? [Colors.grey[700]!, Colors.grey[800]!]
                                      : [const Color(0xFFFF6B35), const Color(0xFFFF8E53)],
                                  begin: Alignment.centerLeft,
                                  end: Alignment.centerRight,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: (deal.isExpired ? Colors.black : const Color(0xFFFF6B35)).withValues(alpha: 0.35),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  _openLink(context, deal.link);
                                },
                                icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    deal.isExpired ? 'Şansını Dene' : 'Mağazaya Git',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  shadowColor: Colors.transparent,
                                  padding: const EdgeInsets.symmetric(horizontal: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Admin approval / rejection controls (for pending deals)
                        if (_isAdmin && deal.isApproved != true)
                          Padding(
                            padding: const EdgeInsets.only(top: 14),
                            child: Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _rejectDeal(deal.id),
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    label: const Text(
                                      'Reddet',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                    ),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                      side: const BorderSide(color: Colors.red, width: 1.5),
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: () => _confirmApproval(deal.id),
                                    icon: const Icon(Icons.check_rounded, size: 18),
                                    label: const Text(
                                      'Onayla',
                                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppTheme.primary,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
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
              ),
            ),

            // 4. Fixed Top Floating Action Buttons Overlay
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 16,
              right: 16,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Geri Butonu (Frosted Glass)
                  _buildGlassCircleButton(
                    icon: Icons.arrow_back,
                    isDark: isDark,
                    onTap: () => Navigator.of(context).pop(),
                  ),

                  // Sağ Aksiyon Grubu (Share, Report, Admin)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildGlassCircleButton(
                        icon: Icons.share_rounded,
                        isDark: isDark,
                        onTap: () => DealShareSheet.shareToNativeApps(context, deal),
                      ),
                      const SizedBox(width: 8),
                      // Popup Menu
                      ClipRRect(
                        borderRadius: BorderRadius.circular(22),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: 42,
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurface.withValues(alpha: 0.85)
                                  : Colors.black.withValues(alpha: 0.35),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? AppTheme.darkBorder : Colors.white.withValues(alpha: 0.25),
                                width: 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(
                                Icons.more_vert_rounded,
                                size: 20,
                                color: Colors.white,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              color: isDark ? AppTheme.darkSurfaceElevated : Colors.white,
                              onSelected: (value) {
                                if (value == 'forward_message') {
                                  DealShareSheet.showForwardSheet(context, deal);
                                } else if (value == 'copy_deal_link' || value == 'copy_link') {
                                  DealShareSheet.copyDealLink(context, deal);
                                } else if (value == 'copy_store_link') {
                                  DealShareSheet.copyStoreLink(context, deal);
                                } else if (value == 'report') {
                                  showReportDialog(
                                    context,
                                    reportedId: deal.id,
                                    type: 'deal',
                                    targetContent: deal.title,
                                    targetAuthor: deal.postedBy,
                                    targetAuthorId: deal.postedBy,
                                  );
                                }
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'forward_message',
                                  child: Row(
                                    children: [
                                      Icon(Icons.send_rounded, color: primaryColor, size: 18),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Fırsatı Mesajla Gönder',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'copy_deal_link',
                                  child: Row(
                                    children: [
                                      Icon(Icons.link_rounded, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7), size: 18),
                                      const SizedBox(width: 12),
                                      Text(
                                        'FırsatKolik Bağlantısını Kopyala',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'copy_store_link',
                                  child: Row(
                                    children: [
                                      const Icon(Icons.storefront_rounded, color: Color(0xFF10B981), size: 18),
                                      const SizedBox(width: 12),
                                      Text(
                                        deal.store.isNotEmpty
                                            ? '${deal.store} Linkini Kopyala'
                                            : 'Mağaza Linkini Kopyala',
                                        style: TextStyle(
                                          color: isDark ? Colors.white : Colors.black87,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuDivider(),
                                PopupMenuItem(
                                  value: 'report',
                                  child: Row(
                                    children: [
                                      Icon(Icons.flag_outlined, color: Colors.red[400], size: 18),
                                      const SizedBox(width: 12),
                                      Text(
                                        'Fırsatı Raporla',
                                        style: TextStyle(
                                          color: Colors.red[400],
                                          fontWeight: FontWeight.w600,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 8),
                        _buildGlassCircleButton(
                          icon: Icons.edit_rounded,
                          isDark: isDark,
                          color: const Color(0xFFFF9800),
                          onTap: () => _showAdminEditDialog(deal),
                        ),
                        if (deal.isApproved == true) ...[
                          const SizedBox(width: 8),
                          _buildGlassCircleButton(
                            icon: Icons.close_rounded,
                            isDark: isDark,
                            color: Colors.orangeAccent,
                            onTap: () => _unpublishDeal(deal.id),
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
      ),
    ),
  );
  }

  // Helper Widget for Frosted Glass Header Action Buttons
  Widget _buildGlassCircleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    Color? color,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: isDark
                ? AppTheme.darkSurface.withValues(alpha: 0.85)
                : Colors.black.withValues(alpha: 0.35),
            shape: BoxShape.circle,
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.white.withValues(alpha: 0.25),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(22),
              onTap: () {
                HapticFeedback.lightImpact();
                onTap();
              },
              child: Center(
                child: Icon(
                  icon,
                  size: 20,
                  color: color ?? Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }




  // =====================================================================
  // Delegating Wrappers — modül dosyalarına yönlendiren ince katman
  // =====================================================================

  Widget _buildStatButton({
    required IconData icon,
    required int count,
    required String label,
    required Color color,
    required VoidCallback onTap,
    required bool isDark,
    bool isSelected = false,
    bool isLoading = false,
  }) => DealDetailHelpers.buildStatButton(
    context: context, icon: icon, count: count, label: label,
    color: color, onTap: onTap, isDark: isDark,
    isSelected: isSelected, isLoading: isLoading,
  );

  Future<void> _confirmApproval(String id) => DealAdminDialogs.confirmApproval(
    context: context, dealId: id, currentDeal: _currentDeal,
    firestoreService: _firestoreService, onDealUpdated: _loadDeal,
  );

  Future<void> _unpublishDeal(String id) => DealAdminDialogs.unpublishDeal(
    context: context, dealId: id, firestoreService: _firestoreService,
  );



  Future<void> _rejectDeal(String id) => DealAdminDialogs.rejectDeal(
    context: context, dealId: id,
    firestoreService: _firestoreService, onDealUpdated: _loadDeal,
  );



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


  Widget _buildDetailImage(Deal deal) {
    return DealDetailImage(
      deal: deal,
      fetchedImageUrl: _fetchedImageUrl,
      originalImageFailed: _originalImageFailed,
      isFetchingImage: _isFetchingImage,
      hasTriedFetching: _hasTriedFetching,
      onFetchImage: () => _fetchImageFromLink(deal.link),
      onOriginalImageFailed: (failed) {
        if (mounted) {
          setState(() => _originalImageFailed = failed);
          if (!_hasTriedFetching && deal.link.isNotEmpty) {
            _fetchImageFromLink(deal.link);
          }
        }
      },
      onFullScreen: (url) => DealDetailImage.showFullScreenImage(context, url),
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
    ).then((_) {
      _loadDeal();
    });
  }


  Future<void> _showAdminEditDialog(Deal deal) => DealAdminDialogs.showAdminEditDialog(
    context: context, deal: deal, dealId: widget.dealId,
    firestoreService: _firestoreService, onDealUpdated: _loadDeal,
  );

  Future<void> _showEditDescriptionDialog(Deal deal) => DealAdminDialogs.showEditDescriptionDialog(
    context: context, deal: deal, dealId: widget.dealId,
    firestoreService: _firestoreService, onDealUpdated: _loadDeal,
  );


  Future<void> _showCategoryEditDialog(Deal deal) => DealAdminDialogs.showCategoryEditDialog(
    context: context, deal: deal, dealId: widget.dealId,
    firestoreService: _firestoreService, onDealUpdated: _loadDeal,
  );

  void _showFullScreenImage(String imageUrl) =>
      DealDetailImage.showFullScreenImage(context, imageUrl);

  Widget _buildDescriptionWidget(String text, bool isDark, Color primaryColor, String store) {
    if (text.isEmpty) {
      return Text(
        'Açıklama eklemek için tıklayın',
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.grey[500] : Colors.grey[400],
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final baseStyle = TextStyle(
      fontSize: 14.5,
      fontWeight: FontWeight.w500,
      color: isDark ? const Color(0xFFE2E8F0) : const Color(0xFF334155),
      height: 1.6,
      letterSpacing: 0.1,
    );

    // Eğer Migros fırsatıysa ve ilk satır bilinen bir CRM etiketi ise sadece ilk satırı biçimlendir
    if (store.toLowerCase() == 'migros' && text.contains('\n\n')) {
      final parts = text.split('\n\n');
      if (parts.length > 1) {
        final firstLine = parts[0].trim();
        final rest = parts.skip(1).join('\n\n');

        final cleanFirstLine = firstLine
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('**', '');

        final upperFirst = cleanFirstLine.toUpperCase();
        final isCrmLabel = upperFirst.contains('MONEY') ||
            upperFirst.contains('SEPETTE') ||
            upperFirst.contains('SADECE MİGROS') ||
            upperFirst.contains('İNDİRİM') ||
            upperFirst.contains('HEDİYE') ||
            upperFirst.contains('BEDAVA');

        if (isCrmLabel) {
          final List<InlineSpan> spans = [];
          spans.add(TextSpan(
            text: cleanFirstLine,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontStyle: FontStyle.italic,
              fontSize: 15,
              color: isDark ? Colors.amber[300] : const Color(0xFFFF7F00),
            ),
          ));

          spans.add(const TextSpan(text: '\n\n'));
          spans.add(TextSpan(
            text: rest.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('**', ''),
            style: baseStyle,
          ));

          return SelectableText.rich(TextSpan(children: spans));
        }
      }
    }

    final cleanText = text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('**', '');

    // #tanıtım vb. etiketleri göze batmayan, hafif muted (zarif gri) tonda göster
    final hashtagRegex = RegExp(r'(#(?:reklam|işbirliği|isbirligi|tanıtım|tanitim|sponsorlu)\b)', caseSensitive: false);
    if (hashtagRegex.hasMatch(cleanText)) {
      final List<InlineSpan> spans = [];
      int lastIndex = 0;
      for (final match in hashtagRegex.allMatches(cleanText)) {
        if (match.start > lastIndex) {
          spans.add(TextSpan(
            text: cleanText.substring(lastIndex, match.start),
            style: baseStyle,
          ));
        }
        spans.add(TextSpan(
          text: match.group(0),
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: isDark ? Colors.grey[500] : Colors.grey[400],
            letterSpacing: 0.2,
          ),
        ));
        lastIndex = match.end;
      }
      if (lastIndex < cleanText.length) {
        spans.add(TextSpan(
          text: cleanText.substring(lastIndex),
          style: baseStyle,
        ));
      }
      return SelectableText.rich(TextSpan(children: spans));
    }

    return SelectableText(
      cleanText,
      style: baseStyle,
    );
  }

  String _extractFirstName(String? fullName) {
    if (fullName == null) return 'Kullanıcı';
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return 'Kullanıcı';
    final parts = trimmed.split(RegExp(r'\s+'));
    return parts.isNotEmpty ? parts.first : trimmed;
  }

  Widget _buildCompactBotkolikCard(Deal deal, bool isDark, Color primaryColor) {
    final pillBgColor = isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9);
    final pillBorderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return StreamBuilder<bool>(
      stream: _firestoreService.botkolikChatEnabledStream(),
      builder: (context, snapshot) {
        final isChatEnabled = snapshot.data ?? true;

        return Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: pillBgColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: pillBorderColor,
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Botkolik Profil Segmenti (Tıklanınca Profile Gider)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const BotkolikProfileScreen()),
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppTheme.primary.withValues(alpha: 0.35),
                                  width: 1,
                                ),
                              ),
                              child: ClipOval(
                                child: Image.asset(
                                  'assets/botkolik.webp',
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                width: 5.5,
                                height: 5.5,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: isDark ? const Color(0xFF1E242B) : Colors.white,
                                    width: 1,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 6),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Bot',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF1A1A2E),
                                  letterSpacing: -0.3,
                                ),
                              ),
                              const TextSpan(
                                text: 'kolik',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 13,
                          color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (isChatEnabled) ...[
                // Dikey Ayırıcı Çizgi
                Container(
                  width: 1,
                  height: 14,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  color: dividerColor,
                ),
                // Botkolik Fırsat Sohbet Butonu
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final currentUid = _authService.currentUser?.uid;
                      if (currentUid == null) {
                        showGuestLoginBottomSheet(
                          context,
                          title: 'Mesaj Gönder',
                          message: 'Botkolik ile iletişime geçmek ve bu fırsat hakkında soru iletmek için Giriş Yap! 🚀',
                        );
                        return;
                      }
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MessageScreen(
                            otherUserId: 'botkolik',
                            otherUserName: 'Botkolik',
                            otherUserImageUrl: 'assets/botkolik.webp',
                            initialDealTitle: deal.title,
                            initialDealId: deal.id,
                            initialDealImageUrl: deal.imageUrl,
                            initialDealPrice: deal.price.toString(),
                            initialDealStore: deal.store,
                          ),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(6),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary,
                        borderRadius: BorderRadius.circular(6),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                            blurRadius: 4,
                            offset: const Offset(0, 1.5),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 10.5,
                            color: Colors.white,
                          ),
                          SizedBox(width: 3.5),
                          Text(
                            'Sor',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildCompactDealAuthorCard(Deal deal, bool isDark, Color primaryColor) {
    final firstName = _extractFirstName(deal.postedByName);
    final profileImageUrl = migrateAssetPath(deal.postedByAvatar ?? '');
    final currentUid = _authService.currentUser?.uid;
    final isOwnDeal = currentUid != null && currentUid == deal.postedBy;

    final pillBgColor = isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9);
    final pillBorderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);
    final dividerColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: pillBgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: pillBorderColor,
          width: 1.0,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Profil Segmenti (Tıklanınca Profil Açılır)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => ProfileScreen(userId: deal.postedBy)),
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Avatar & Canlı Online Noktası
                    Stack(
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: profileImageUrl.isNotEmpty
                                ? (profileImageUrl.startsWith('assets/')
                                    ? Image.asset(
                                        profileImageUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, __, ___) => const Icon(Icons.person_rounded, size: 12, color: AppTheme.primary),
                                      )
                                    : CachedNetworkImage(
                                        imageUrl: profileImageUrl,
                                        fit: BoxFit.cover,
                                        placeholder: (_, __) => Container(color: Colors.grey[300]),
                                        errorWidget: (_, __, ___) => const Icon(Icons.person, size: 12, color: AppTheme.primary),
                                      ))
                                : Container(
                                    color: AppTheme.primary.withValues(alpha: 0.15),
                                    child: const Icon(Icons.person_rounded, size: 12, color: AppTheme.primary),
                                  ),
                          ),
                        ),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            width: 5.5,
                            height: 5.5,
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isDark ? const Color(0xFF1E242B) : Colors.white,
                                width: 1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 6),
                    // Kullanıcı İlk Adı
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 80),
                      child: Text(
                        firstName,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : const Color(0xFF1E293B),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 13,
                      color: isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 2. Dikey Ayırıcı Çizgi (Segment Divider)
          Container(
            width: 1,
            height: 14,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            color: dividerColor,
          ),

          // 3. Fırsat Sohbet Butonu (Tıklanınca Fırsat İliştirilmiş Mesaj Başlatılır)
          if (!isOwnDeal)
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  if (currentUid == null) {
                    showGuestLoginBottomSheet(
                      context,
                      title: 'Mesaj Gönder',
                      message: 'Fırsat sahibiyle doğrudan iletişime geçmek için Giriş Yap! 🚀',
                    );
                    return;
                  }
                  HapticFeedback.lightImpact();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => MessageScreen(
                        otherUserId: deal.postedBy,
                        otherUserName: deal.postedByName ?? firstName,
                        otherUserImageUrl: profileImageUrl,
                        initialDealTitle: deal.title,
                        initialDealId: deal.id,
                        initialDealImageUrl: deal.imageUrl,
                        initialDealPrice: deal.price.toString(),
                        initialDealStore: deal.store,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(6),
                child: Ink(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primary.withValues(alpha: isDark ? 0.35 : 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 1.5),
                      ),
                    ],
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 10.5,
                        color: Colors.white,
                      ),
                      SizedBox(width: 3.5),
                      Text(
                        'Sor',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded, size: 10, color: AppTheme.primary),
                  SizedBox(width: 2.5),
                  Text(
                    'Sizin',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
