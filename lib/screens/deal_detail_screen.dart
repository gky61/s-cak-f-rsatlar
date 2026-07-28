import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/deal.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';
import 'profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../main.dart'; // navigatorKey için

import '../widgets/report_dialog.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/deal_thermometer.dart';
import '../widgets/money_badge.dart';
import '../widgets/deal_card/deal_card_helpers.dart';
import 'deal_detail/deal_detail_helpers.dart';
import 'deal_detail/deal_detail_image.dart';
import 'deal_detail/deal_share_sheet.dart';
import 'deal_detail/deal_admin_dialogs.dart';

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
  bool _isHotVoting = false;
  bool _isColdVoting = false;
  bool _isExpiredVoting = false;
  int _hotVotes = 0;
  int _coldVotes = 0;
  int _expiredVotes = 0;
  bool _dealNotFound = false;
  bool _hasAutoOpenedComments = false; // Bildirimden açılan yorum penceresinin tekrar tekrar açılmasını engeller

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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Kaydetmek için giriş yapmalısınız'),
          backgroundColor: Colors.orange,
        ),
      );
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

    // Spam click önleme - herhangi bir oylama devam ediyorsa yeni tıklamayı engelle
    if (_isHotVoting || _isColdVoting || _isExpiredVoting) {
      return;
    }

    // Eğer zaten bu oyu vermişse ve tekrar aynı oya basarsa, geri al (toggle)
    if (isHot && _hasVotedHot) {
      await _removeHotVote();
      return;
    }
    if (!isHot && _hasVotedCold) {
      await _removeColdVote();
      return;
    }

    // Loading state set et
    setState(() {
      if (isHot) {
        _isHotVoting = true;
      } else {
        _isColdVoting = true;
      }
    });

    // Önceki durumları kaydet
    final previousHotVote = _hasVotedHot;
    final previousColdVote = _hasVotedCold;
    final previousHotVotes = _hotVotes;
    final previousColdVotes = _coldVotes;

    // Optimistic UI update - Bağımsız kalite oyu (Fırsat Bitti'ye dokunmaz)
    setState(() {
      if (isHot) {
        if (_hasVotedCold) {
          _hasVotedCold = false;
          _coldVotes = _coldVotes > 0 ? _coldVotes - 1 : 0;
        }
        _hasVotedHot = true;
        _hotVotes += 1;
      } else {
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
        _isHotVoting = false;
        _isColdVoting = false;
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
      _isHotVoting = false;
      _isColdVoting = false;
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

    // Spam click önleme
    if (_isHotVoting || _isColdVoting || _isExpiredVoting) {
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

  Future<void> _removeHotVote() async {
    final user = _authService.currentUser;
    if (user == null || _currentDeal == null) return;

    setState(() {
      _isHotVoting = true;
    });

    final previousHotVote = _hasVotedHot;
    final previousHotVotes = _hotVotes;

    setState(() {
      _hasVotedHot = false;
      _hotVotes = _hotVotes > 0 ? _hotVotes - 1 : 0;
    });

    final success = await _firestoreService.removeHotVote(_currentDeal!.id, user.uid);

    if (!success && mounted) {
      setState(() {
        _hasVotedHot = previousHotVote;
        _hotVotes = previousHotVotes;
        _isHotVoting = false;
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
      _isHotVoting = false;
    });
  }

  Future<void> _removeColdVote() async {
    final user = _authService.currentUser;
    if (user == null || _currentDeal == null) return;

    setState(() {
      _isColdVoting = true;
    });

    final previousColdVote = _hasVotedCold;
    final previousColdVotes = _coldVotes;

    setState(() {
      _hasVotedCold = false;
      _coldVotes = _coldVotes > 0 ? _coldVotes - 1 : 0;
    });

    final success = await _firestoreService.removeColdVote(_currentDeal!.id, user.uid);

    if (!success && mounted) {
      setState(() {
        _hasVotedCold = previousColdVote;
        _coldVotes = previousColdVotes;
        _isColdVoting = false;
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
      _isColdVoting = false;
    });
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
        if (didPop) return;
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : AppTheme.background,
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
                  backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
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
                                    Colors.black.withValues(alpha: 0.55),
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.25),
                                  ],
                                  stops: const [0.0, 0.4, 1.0],
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Floating Discount Badge (Bottom Right over Image)
                        if (deal.discountRate != null && deal.discountRate! > 0)
                          Positioned(
                            bottom: 32,
                            right: 16,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.deepOrange[600]!, Colors.red[700]!],
                                ),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.6),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.red.withValues(alpha: 0.4),
                                    blurRadius: 12,
                                    spreadRadius: 2,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.local_fire_department, color: Colors.white, size: 18),
                                  const SizedBox(width: 4),
                                  Text(
                                    '%${deal.discountRate} İNDİRİM',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
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
                          color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.08),
                          blurRadius: 30,
                          offset: const Offset(0, -10),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Handle Indicator
                        Center(
                          child: Container(
                            margin: const EdgeInsets.only(top: 12, bottom: 16),
                            width: 44,
                            height: 4.5,
                            decoration: BoxDecoration(
                              color: isDark ? Colors.grey[700] : Colors.grey[300],
                              borderRadius: BorderRadius.circular(3),
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
                                  // Sol grup: Satıcı + Marka + Editör Seçimi
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Satıcı Pill (Marka ile aynı stil)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                          decoration: BoxDecoration(
                                            color: isDark 
                                                ? Colors.white.withValues(alpha: 0.06) 
                                                : primaryColor.withValues(alpha: 0.08),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(
                                              color: primaryColor.withValues(alpha: 0.25),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              SizedBox(
                                                width: 18,
                                                height: 18,
                                                child: Center(
                                                  child: buildStoreLogo(deal.store, size: 18, borderRadius: 4),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                'Satıcı: ',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w500,
                                                  color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                                ),
                                              ),
                                              Flexible(
                                                child: Text(
                                                  deal.store.isEmpty ? 'Bilinmeyen' : deal.store,
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w700,
                                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Marka Pill
                                        if (deal.brand != null && deal.brand!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                            decoration: BoxDecoration(
                                              color: primaryColor.withValues(alpha: 0.08),
                                              borderRadius: BorderRadius.circular(8),
                                              border: Border.all(
                                                color: primaryColor.withValues(alpha: 0.25),
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child: Center(
                                                    child: Icon(Icons.verified_rounded, size: 16, color: primaryColor),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  'Marka: ',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w500,
                                                    color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                                  ),
                                                ),
                                                Flexible(
                                                  child: Text(
                                                    deal.brand!,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? Colors.white : AppTheme.textPrimary,
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
                                  // Sağ grup: Kategori + Paylaşan
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      // Category Pill
                                      InkWell(
                                        onTap: _isAdmin ? () => _showCategoryEditDialog(deal) : null,
                                        borderRadius: BorderRadius.circular(20),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                          decoration: BoxDecoration(
                                            gradient: LinearGradient(
                                              colors: isDark 
                                                  ? [Colors.grey[850]!, Colors.grey[800]!]
                                                  : [Colors.grey[100]!, Colors.grey[200]!],
                                            ),
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                category.name.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w800,
                                                  color: isDark ? Colors.grey[200] : AppTheme.textPrimary,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                              if (_isAdmin) ...[
                                                const SizedBox(width: 4),
                                                Icon(Icons.edit_rounded, size: 12, color: primaryColor),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                      // PostedBy User Tag
                                      if (deal.postedBy.isNotEmpty && deal.isUserSubmitted) ...[
                                        const SizedBox(height: 8),
                                        StreamBuilder<DocumentSnapshot>(
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
                                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey[100],
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
                                                          ? (profileImageUrl.startsWith('assets/')
                                                              ? Image.asset(profileImageUrl, width: 16, height: 16, fit: BoxFit.cover)
                                                              : CachedNetworkImage(
                                                                  imageUrl: profileImageUrl,
                                                                  width: 16,
                                                                  height: 16,
                                                                  fit: BoxFit.cover,
                                                                ))
                                                          : Container(
                                                              width: 16,
                                                              height: 16,
                                                              color: primaryColor.withOpacity(0.15),
                                                              child: Icon(Icons.person_rounded, size: 10, color: primaryColor),
                                                            ),
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      username,
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.w700,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ],
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
                                      gradient: LinearGradient(
                                        colors: [Colors.amber[700]!, Colors.orange[600]!],
                                      ),
                                      borderRadius: BorderRadius.circular(10),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.amber.withValues(alpha: 0.35),
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
                              Text(
                                deal.title,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  height: 1.3,
                                ),
                              ),

                              if (deal.ratingValue != null || deal.ratingCount != null) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF2C2517) : const Color(0xFFFFF8E1),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: const Color(0xFFFFD54F).withValues(alpha: 0.5),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.star_rounded,
                                            size: 16,
                                            color: Color(0xFFFFB800),
                                          ),
                                          const SizedBox(width: 4),
                                          if (deal.ratingValue != null)
                                            Text(
                                              deal.ratingValue!.toStringAsFixed(1),
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                                color: isDark ? const Color(0xFFFFD54F) : const Color(0xFFE65100),
                                              ),
                                            ),
                                          if (deal.ratingCount != null) ...[
                                            const SizedBox(width: 4),
                                            Text(
                                              '(${deal.ratingCount} değerlendirme)',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                                color: isDark ? Colors.grey[300] : Colors.grey[700],
                                              ),
                                            ),
                                          ],
                                          if (MoneyBadge.isMoneyDeal(deal)) ...[
                                            const SizedBox(width: 4),
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
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildStatButton(
                                        icon: _isFavorite ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                        count: -1,
                                        label: _isFavorite ? 'Kaydedildi' : 'Kaydet',
                                        color: _isFavorite ? Colors.amber[700]! : Colors.grey,
                                        onTap: _toggleFavorite,
                                        isSelected: _isFavorite,
                                        isDark: isDark,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildStatButton(
                                        icon: Icons.chat_bubble_outline_rounded,
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
                                        count: _expiredVotes,
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

                              const SizedBox(height: 28),

                              // Description Header
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    'ÜRÜN DETAYLARI',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      letterSpacing: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Description Content Card
                              if (deal.description.isNotEmpty || _isAdmin) ...[
                                GestureDetector(
                                  onTap: _isAdmin ? () => _showEditDescriptionDialog(deal) : null,
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isDark 
                                          ? Colors.white.withValues(alpha: 0.04) 
                                          : Colors.grey[50],
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: isDark 
                                            ? Colors.white.withValues(alpha: 0.08) 
                                            : Colors.grey[200]!,
                                        width: 1,
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
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.1),
                      blurRadius: 24,
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
                        // Price Column (Sol: İndirimli Fiyat font 24, Sağ: [İndirim Etiketi üstte, İndirimsiz Fiyat altta])
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
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Sol: İndirimli (Fırsat) Fiyatı - Dikeyde Ortalı, Font Size: 24
                                  FormattedPriceText(
                                    value: deal.price,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.w900,
                                      color: AppTheme.primary,
                                      height: 1.0,
                                    ),
                                  ),
                                  // Sağ: [İndirim Etiketi üstte, İndirimsiz (eski) Fiyat altta] Sütunu
                                  if (deal.originalPrice != null && deal.originalPrice! > deal.price) ...[
                                    const SizedBox(width: 10),
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        // İndirim Etiketi (tam indirimsiz fiyatın üstünde)
                                        if (deal.effectiveDiscountRate != null && deal.effectiveDiscountRate! > 0)
                                          Container(
                                            margin: const EdgeInsets.only(bottom: 2),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: isDark ? AppTheme.primary : const Color(0xFFE53935),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              '%${deal.effectiveDiscountRate} İndirim',
                                              style: TextStyle(
                                                fontSize: 9.5,
                                                fontWeight: FontWeight.w900,
                                                color: isDark ? Colors.black : Colors.white,
                                              ),
                                            ),
                                          ),
                                        // İndirimsiz (Eski) Fiyat (üstü çizili)
                                        FormattedPriceText(
                                          value: deal.originalPrice,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w500,
                                            color: isDark ? Colors.grey[500] : AppTheme.textSecondary,
                                            decoration: TextDecoration.lineThrough,
                                            decorationThickness: 1.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                              if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFFFF3E0),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFFFFB74D).withValues(alpha: 0.5),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    deal.priceLabel!,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFE65100),
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 12),

                        // Main CTA Button ("Mağazaya Git") - Dolgulu Turuncu/Sarı Marka Rengi ve Büyütülmüş
                        Container(
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              colors: deal.isExpired 
                                  ? [Colors.grey[700]!, Colors.grey[800]!]
                                  : [AppTheme.primary, const Color(0xFFFF9800)],
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: (deal.isExpired ? Colors.black : AppTheme.primary).withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () => _openLink(context, deal.link),
                            icon: const Icon(Icons.open_in_new_rounded, size: 18, color: Colors.white),
                            label: Text(
                              deal.isExpired ? 'Şansını Dene' : 'Mağazaya Git',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.2,
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
                                  side: const BorderSide(color: Colors.red, width: 2),
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
                        onTap: () => _showShareOptions(context, deal),
                      ),
                      const SizedBox(width: 8),
                      // Popup Menu
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.35),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.25),
                            width: 1,
                          ),
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
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (_isAdmin) ...[
                        const SizedBox(width: 8),
                        _buildGlassCircleButton(
                          icon: Icons.edit_rounded,
                          isDark: isDark,
                          color: primaryColor,
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
    );
  }

  // Helper Widget for Frosted Glass Header Action Buttons
  Widget _buildGlassCircleButton({
    required IconData icon,
    required bool isDark,
    required VoidCallback onTap,
    Color? color,
  }) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Icon(
            icon,
            size: 20,
            color: color ?? Colors.white,
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


  Future<void> _showShareOptions(BuildContext context, Deal deal) =>
      DealShareSheet.showShareOptions(context, deal);



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
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
      height: 1.6,
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

          return Text.rich(TextSpan(children: spans));
        }
      }
    }

    return Text(
      text.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('**', ''),
      style: baseStyle,
    );
  }
}
