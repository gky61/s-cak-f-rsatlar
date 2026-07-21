import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
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
    final previousExpiredVote = _hasVotedExpired;
    final previousHotVotes = _hotVotes;
    final previousColdVotes = _coldVotes;
    final previousExpiredVotes = _expiredVotes;

    // Daha önce hot oy vermişse ve şimdi cold'a geçiyorsa, favorilerden çıkar
    final wasPreviouslyHot = _hasVotedHot;

    // Optimistic UI update
    setState(() {
      if (isHot) {
        // Eğer daha önce cold vermişse, cold'u kaldır
        if (_hasVotedCold) {
          _hasVotedCold = false;
          _coldVotes = _coldVotes > 0 ? _coldVotes - 1 : 0;
        }
        // Eğer daha önce expired vermişse, expired'ı kaldır
        if (_hasVotedExpired) {
          _hasVotedExpired = false;
          _expiredVotes = _expiredVotes > 0 ? _expiredVotes - 1 : 0;
        }
        _hasVotedHot = true;
        _hotVotes += 1;
      } else {
        // Eğer daha önce hot vermişse, hot'u kaldır ve favorilerden çıkar
        if (_hasVotedHot) {
          _hasVotedHot = false;
          _hotVotes = _hotVotes > 0 ? _hotVotes - 1 : 0;
          _isFavorite = false;
        }
        // Eğer daha önce expired vermişse, expired'ı kaldır
        if (_hasVotedExpired) {
          _hasVotedExpired = false;
          _expiredVotes = _expiredVotes > 0 ? _expiredVotes - 1 : 0;
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
        _hasVotedExpired = previousExpiredVote;
        _hotVotes = previousHotVotes;
        _coldVotes = previousColdVotes;
        _expiredVotes = previousExpiredVotes;
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

    if (success) {
      if (isHot) {
        // Hot vote ise favorilere ekle
        await _firestoreService.addToFavorites(
          user.uid,
          _currentDeal!.id,
          title: _currentDeal!.title,
          price: _currentDeal!.price,
          store: _currentDeal!.store,
          link: _currentDeal!.link,
        );
        if (mounted) {
          setState(() {
            _isFavorite = true;
          });
        }
      } else if (wasPreviouslyHot) {
        // Cold vote ise ve daha önce hot vermişse favorilerden çıkar
        await _firestoreService.removeFromFavorites(user.uid, _currentDeal!.id);
      }
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
    final previousHotVote = _hasVotedHot;
    final previousColdVote = _hasVotedCold;
    final previousExpiredVote = _hasVotedExpired;
    final previousHotVotes = _hotVotes;
    final previousColdVotes = _coldVotes;
    final previousExpiredVotes = _expiredVotes;

    // Daha önce hot oy vermişse, favorilerden çıkarmak için flag'i sakla
    final wasPreviouslyHot = _hasVotedHot;

    // Optimistic UI update
    setState(() {
      // Eğer daha önce hot veya cold vermişse, onları kaldır
      if (_hasVotedHot) {
        _hasVotedHot = false;
        _hotVotes = _hotVotes > 0 ? _hotVotes - 1 : 0;
        _isFavorite = false;
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
        _hasVotedExpired = previousExpiredVote;
        _hotVotes = previousHotVotes;
        _coldVotes = previousColdVotes;
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

    // Expired vote başarılıysa ve daha önce hot oy vermişse favorilerden çıkar
    if (success && wasPreviouslyHot) {
      await _firestoreService.removeFromFavorites(user.uid, _currentDeal!.id);
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
      _isFavorite = false; // Favorilerden de çıkar
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
          content: Text('Beğeni geri alınırken bir hata oluştu. Lütfen tekrar deneyin.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    if (success) {
      await _firestoreService.removeFromFavorites(user.uid, _currentDeal!.id);
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
    final currencyFormat = DynamicCurrencyFormatter();
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
                                                                  ? (profileImageUrl.startsWith('assets/')
                                                                      ? Image.asset(
                                                                          profileImageUrl,
                                                                          width: 16,
                                                                          height: 16,
                                                                          fit: BoxFit.cover,
                                                                        )
                                                                      : CachedNetworkImage(
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
                                                                        ))
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
                                          count: _hotVotes,
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
                                        child: _buildDescriptionWidget(deal.description, isDark, primaryColor, deal.store),
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
                bottom: MediaQuery.of(context).padding.bottom + 
                    (deal.priceLabel != null && deal.priceLabel!.isNotEmpty ? 22 : 16),
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
                          if (deal.priceLabel != null && deal.priceLabel!.isNotEmpty) ...[
                            const SizedBox(height: 8), // Increased spacing under price
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF3E0), // Soft orange amber container
                                borderRadius: BorderRadius.circular(6), // Rounded pill shape
                                border: Border.all(
                                  color: const Color(0xFFFFB74D).withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                deal.priceLabel!,
                                style: const TextStyle(
                                  fontSize: 10.5, // Font size bumped from 9 to 10.5 to stand out
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFE65100), // Clean deep orange tone
                                ),
                              ),
                            ),
                          ],
                        ],
                                ),
                      const SizedBox(width: 16),
                                Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => _openLink(context, deal.link),
                          icon: const Icon(Icons.open_in_new, size: 20),
                          label: Text(
                            deal.isExpired ? 'Şansını Dene / Mağazaya Git' : 'Mağazaya Git',
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

    // Eğer Migros fırsatıysa ve açıklama birden fazla satırdan oluşuyorsa ilk satırı CRM etiketi olarak biçimlendir
    if (store.toLowerCase() == 'migros') {
      final parts = text.split('\n\n');
      if (parts.isNotEmpty) {
        final firstLine = parts[0].trim();
        final rest = parts.skip(1).join('\n\n');

        // Temizlik koruması (HTML tagları ve yıldızları temizle)
        final cleanFirstLine = firstLine
            .replaceAll(RegExp(r'<[^>]*>'), '')
            .replaceAll('**', '');

        final List<InlineSpan> spans = [];
        spans.add(TextSpan(
          text: cleanFirstLine,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontStyle: FontStyle.italic,
            fontSize: 16,
            color: isDark ? Colors.amber[300] : const Color(0xFFFF7F00),
          ),
        ));

        if (rest.isNotEmpty) {
          spans.add(const TextSpan(text: '\n\n'));
          spans.add(TextSpan(
            text: rest.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('**', ''),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
              height: 1.6,
            ),
          ));
        }

        return Text.rich(
          TextSpan(
            children: spans,
          ),
        );
      }
    }

    final baseStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
      height: 1.6,
    );

    // Diğer mağazalar için düz metin olarak render et
    return Text(
      text,
      style: baseStyle,
    );
  }
}
