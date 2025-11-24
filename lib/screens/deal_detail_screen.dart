import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';

import '../models/deal.dart';
import '../models/comment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/link_preview_service.dart';
import '../theme/app_theme.dart';

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
  bool _isHotVoting = false;
  bool _isColdVoting = false;
  int _hotVotes = 0;
  int _coldVotes = 0;

  @override
  void initState() {
    super.initState();
    _loadDeal();
    _checkAdminStatus();
    _checkFavoriteStatus();
    _checkUserVote();
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
    // _currentDeal null ise loading göster
    if (_currentDeal == null) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return _buildDealDetail(context, _currentDeal!);
  }

  Widget _buildDealDetail(BuildContext context, Deal deal) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '₺', decimalDigits: 0);

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Column(
          children: [
            // Üst bar - Geri ve Paylaş butonları
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildGlassButton(
                    context: context,
                    icon: Icons.arrow_back_rounded,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Row(
                    children: [
                      if (_isAdmin) ...[
                        _buildGlassButton(
                          context: context,
                          icon: Icons.edit_note_rounded,
                          onPressed: () => _showAdminEditSheet(deal),
                        ),
                        const SizedBox(width: 8),
                      ],
                      _buildGlassButton(
                        context: context,
                        icon: _isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        onPressed: _isLoadingFavorite ? null : _toggleFavorite,
                        color: _isFavorite ? Colors.red : null,
                      ),
                      const SizedBox(width: 8),
                      _buildGlassButton(
                        context: context,
                        icon: Icons.share_rounded,
                        onPressed: () => _showShareOptions(context, deal),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            // Ana içerik - Büyük, şık ve minimal tasarım
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.zero, // Görsel tam genişlik için padding kaldırıldı
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Görsel - Kompakt ve şık
                    SizedBox(
                      height: MediaQuery.of(context).size.height * 0.4, // %40 yükseklik
                      width: double.infinity,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          GestureDetector(
                            onTap: () => _showFullScreenImage(context, deal),
                            child: Hero(
                              tag: 'deal_${deal.id}_image',
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  _buildDetailImage(deal),
                                  // Gradient overlay - minimal (tıklamayı engellemesin)
                                  IgnorePointer(
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
                                ],
                              ),
                            ),
                          ),
                          // İndirim rozeti - Sağ üstte
                          if (deal.discountRate != null && deal.discountRate! > 0)
                            Positioned(
                              top: 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.redAccent.withOpacity(0.5),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Text(
                                  '%${deal.discountRate}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                            ),
                          // Editör seçimi badge - İndirim rozetinin altında veya sol üstte
                          if (deal.isEditorPick)
                            Positioned(
                              top: deal.discountRate != null && deal.discountRate! > 0 ? 70 : 12,
                              right: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.secondary],
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.star_rounded, color: Colors.white, size: 16),
                                    SizedBox(width: 4),
                                    Text(
                                      'Editörün Seçimi',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    
                    // İçerik alanı - Kompakt padding
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Başlık - Kompakt ama okunabilir
                          Text(
                            deal.title,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              color: AppTheme.accent,
                              fontWeight: FontWeight.w900,
                              fontSize: 22,
                              height: 1.3,
                              letterSpacing: -0.3,
                            ),
                            maxLines: null,
                            overflow: TextOverflow.visible,
                            textAlign: TextAlign.left,
                          ),
                          
                          const SizedBox(height: 12),
                          
                          // Açıklama - Kompakt
                          if (deal.description.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                deal.description,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey[800],
                                  fontSize: 15,
                                  height: 1.5,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: null,
                                overflow: TextOverflow.visible,
                                textAlign: TextAlign.left,
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],
                          
                          // Fiyat ve Mağaza - Kompakt
                          Row(
                            children: [
                              // Fiyat
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [AppTheme.primary, AppTheme.secondary],
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.primary.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (deal.originalPrice != null && deal.originalPrice! > deal.price)
                                      Text(
                                        currencyFormat.format(deal.originalPrice),
                                        style: const TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          decoration: TextDecoration.lineThrough,
                                          decorationColor: Colors.white70,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    Text(
                                  currencyFormat.format(deal.price),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                                  ],
                              ),
                              ),
                              const SizedBox(width: 10),
                              // İndirim Oranı (Varsa)
                              if (deal.discountRate != null && deal.discountRate! > 0)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.red.withValues(alpha: 0.2), width: 1),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.trending_down_rounded, color: Colors.red, size: 16),
                                      Text(
                                        '%${deal.discountRate}',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (deal.discountRate != null && deal.discountRate! > 0)
                              const SizedBox(width: 10),
                              // Mağaza
                              Expanded(
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.grey[300]!, width: 1),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.store_rounded, size: 18, color: Colors.grey[700]),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          deal.store,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.grey[800],
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 14),
                          
                          // Kategori ve Zaman - Kompakt
                          Row(
                            children: [
                              Expanded(
                                child: _buildCompactInfoChip(
                                  icon: Icons.local_offer_outlined,
                                  label: deal.category,
                                  color: AppTheme.primary,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _buildCompactInfoChip(
                                  icon: Icons.schedule_rounded,
                                  label: _formatRelativeTime(deal.createdAt),
                                  color: Colors.grey[600]!,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 14),
                          
                          // İstatistikler - Çok kompakt
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _handleVote(true),
                                    child: _buildCompactStat(
                                      icon: Icons.whatshot_rounded,
                                      count: _hotVotes > 0 ? _hotVotes : deal.hotVotes,
                                      label: 'Sıcak',
                                      color: Colors.orange,
                                      isSelected: _hasVotedHot,
                                      isLoading: _isHotVoting,
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 30, color: Colors.grey[200]),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _handleVote(false),
                                    child: _buildCompactStat(
                                      icon: Icons.ac_unit_rounded,
                                      count: _coldVotes > 0 ? _coldVotes : deal.coldVotes,
                                      label: 'Soğuk',
                                      color: Colors.blue,
                                      isSelected: _hasVotedCold,
                                      isLoading: _isColdVoting,
                                    ),
                                  ),
                                ),
                                Container(width: 1, height: 30, color: Colors.grey[200]),
                                Expanded(
                                  child: GestureDetector(
                                    onTap: () => _showCommentsBottomSheet(context, deal),
                                    child: _buildCompactStat(
                                      icon: Icons.chat_bubble_outline_rounded,
                                      count: deal.commentCount,
                                      label: 'Yorum',
                                      color: Colors.grey[600]!,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 14),
                          
                          // Yorumlar butonu - Kompakt
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () => _showCommentsBottomSheet(context, deal),
                              icon: const Icon(Icons.chat_bubble_outline_rounded, size: 18),
                              label: Text(
                                'Yorumlar (${deal.commentCount})',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppTheme.primary,
                                side: const BorderSide(color: AppTheme.primary, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                          ),
                          
                          if (!deal.isExpired) const SizedBox(height: 12),
                          
                          // Fırsat Bitti butonu - Kompakt
                          if (!deal.isExpired)
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () => _markDealAsExpired(context, deal),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red, width: 2),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.close_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Fırsat Bitti',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Sayaç
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        _getVoteCountText(deal),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.red[700],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          
                          if (!deal.isExpired) const SizedBox(height: 12),
                          
                          // Link butonu - Kompakt ve öne çıkan
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                _openLink(context, deal.link);
                              },
                              icon: const Icon(Icons.open_in_new_rounded, size: 18),
                              label: const Text(
                                'Fırsatı Görüntüle',
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primary,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16), // Alt padding
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

  void _showAdminEditSheet(Deal deal) {
    if (!_isAdmin) return;

    final titleController = TextEditingController(text: deal.title);
    final descriptionController = TextEditingController(text: deal.description);
    final storeController = TextEditingController(text: deal.store);
    final categoryController = TextEditingController(text: deal.category);
    final linkController = TextEditingController(text: deal.link);
    final priceController = TextEditingController(text: deal.price.toStringAsFixed(0));
    final originalPriceController = TextEditingController(
      text: deal.originalPrice != null ? deal.originalPrice!.toStringAsFixed(0) : '',
    );
    final discountController = TextEditingController(
      text: deal.discountRate != null ? deal.discountRate!.toString() : '',
    );

    bool isEditorPick = deal.isEditorPick;
    bool isApproved = deal.isApproved;
    bool isExpired = deal.isExpired;
    bool isSaving = false;
    String? errorText;

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
                'category': categoryController.text.trim(),
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
                      color: Colors.black.withOpacity(0.1),
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
                            const Text(
                              'Fırsatı Düzenle',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
                        _buildAdminTextField('Kategori', categoryController),
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

  Widget _buildAdminTextField(
    String label,
    TextEditingController controller, {
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: color ?? AppTheme.accent),
        onPressed: onPressed,
      ),
    );
  }

  Widget _buildCompactInfoChip({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
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
                color: Colors.grey[800],
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
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
            color: isSelected ? color : AppTheme.accent,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            color: isSelected ? color : Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildEditorTag() {
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
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, color: AppTheme.primary, size: 20),
          SizedBox(width: 6),
          Text(
            'Editörün Seçimi',
            style: TextStyle(
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

  Widget _buildStatsSection(Deal deal) {
    return Row(
      children: [
        Expanded(
          child: _buildStatCard(
            title: 'Sıcak Oylar',
            icon: Icons.local_fire_department_rounded,
            color: AppTheme.primary,
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
          const Row(
            children: [
              Icon(Icons.link_rounded, color: AppTheme.primary),
              SizedBox(width: 10),
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
                    backgroundColor: AppTheme.primary,
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
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppTheme.primary,
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

  Future<void> _markDealAsExpired(BuildContext context, Deal deal) async {
    // Admin kontrolü
    if (_isAdmin) {
      // Admin için direkt onay
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fırsatı Bitir'),
          content: const Text('Bu fırsatın bittiğini işaretlemek istediğinize emin misiniz?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Evet, Bitti'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        final firestoreService = FirestoreService();
        final success = await firestoreService.markDealAsExpired(deal.id);
        if (mounted) {
          if (success) {
            _loadDeal();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fırsat bitmiş olarak işaretlendi'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fırsat işaretlenirken bir hata oluştu'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      }
    } else {
      // Kullanıcı için oy kontrolü
      final totalVotes = deal.hotVotes + deal.coldVotes;
      
      if (totalVotes < 20) {
        // Yeterli oy yok
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Fırsatı bitirmek için en az 20 oy gerekiyor. Şu an: $totalVotes oy',
            ),
            backgroundColor: Colors.orange,
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }

      // Yeterli oy var, onay iste
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Fırsatı Bitir'),
          content: Text(
            'Bu fırsat $totalVotes oy aldı. Fırsatın bittiğini işaretlemek istediğinize emin misiniz?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('İptal'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Evet, Bitti'),
            ),
          ],
        ),
      );

      if (confirmed == true && mounted) {
        final firestoreService = FirestoreService();
        final success = await firestoreService.markDealAsExpired(deal.id);
        if (mounted) {
          if (success) {
            _loadDeal();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fırsat bitmiş olarak işaretlendi'),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Fırsat işaretlenirken bir hata oluştu'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
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
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    }

    return DateFormat('d MMM').format(date);
  }

  String _getVoteCountText(Deal deal) {
    final totalVotes = deal.hotVotes + deal.coldVotes;
    if (totalVotes >= 20) {
      return '20+ oy';
    } else {
      final remaining = 20 - totalVotes;
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

  void _showFullScreenImage(BuildContext context, Deal deal) {
    // Görsel URL'ini belirle
    String? imageUrl;
    if (!_originalImageFailed && deal.imageUrl.isNotEmpty) {
      imageUrl = deal.imageUrl;
    } else if (_fetchedImageUrl != null && _fetchedImageUrl!.isNotEmpty) {
      imageUrl = _fetchedImageUrl;
    }

    // Görsel yoksa işlem yapma
    if (imageUrl == null || imageUrl.isEmpty) {
      return;
    }

    // imageUrl artık null değil, non-nullable olarak kullan
    final finalImageUrl = imageUrl;

    // Full screen image viewer göster
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.close, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(finalImageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 2,
            initialScale: PhotoViewComputedScale.contained,
            heroAttributes: PhotoViewHeroAttributes(tag: 'deal_${deal.id}_image'),
            loadingBuilder: (context, event) => const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
              ),
            ),
            errorBuilder: (context, error, stackTrace) => const Center(
              child: Icon(
                Icons.error_outline,
                color: Colors.white,
                size: 60,
              ),
            ),
          ),
        ),
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

    // Kullanıcının nickname'ini al
    String displayName = user.displayName ?? 'Kullanıcı';
    try {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        displayName = userData.displayName;
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
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Yorumlar',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.accent,
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
                                style: TextStyle(color: Colors.grey[600]),
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
                              color: Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz yorum yok',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'İlk yorumu siz yapın!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
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
                  color: Colors.white,
                  border: Border(
                    top: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                          child: TextField(
                          controller: _commentController,
                          style: const TextStyle(color: Colors.black),
                          decoration: InputDecoration(
                            hintText: _replyingTo != null 
                                ? '@${_replyingTo!.userName} kullanıcısına cevap verin...' 
                                : 'Yorumunuzu yazın...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: const BorderSide(
                                color: AppTheme.primary,
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
                              color: Colors.grey[200],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.close, size: 20, color: Colors.grey),
                          ),
                        ),
                      ],
                      const SizedBox(width: 12),
                      Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppTheme.primary, AppTheme.secondary],
                          ),
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
    final isReply = comment.parentCommentId != null;
    return Container(
      margin: EdgeInsets.only(
        bottom: 8,
        left: isReply ? 32 : 0, // Cevaplar için sol margin
      ),
      padding: EdgeInsets.all(isReply ? 8 : 10),
      decoration: BoxDecoration(
        color: isReply ? Colors.grey[50] : Colors.white, // Cevaplar için farklı arka plan
        borderRadius: BorderRadius.circular(12),
        border: isReply ? Border.all(color: Colors.grey[300]!, width: 1) : null, // Cevaplar için border
        boxShadow: isReply ? null : [ // Cevaplar için shadow yok
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 6),
              ],
              CircleAvatar(
                radius: isReply ? 10 : 14, // Daha küçük avatar
                backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
                child: Text(
                  comment.userName.isNotEmpty
                      ? comment.userName[0].toUpperCase()
                      : 'U',
                  style: TextStyle(
                    color: AppTheme.primary,
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
                              color: AppTheme.accent,
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
                                color: AppTheme.primary,
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
                        color: Colors.grey[500],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Admin butonları
              if (isAdmin)
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert_rounded, color: Colors.grey[600], size: 16),
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
              color: AppTheme.accent,
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
              icon: const Icon(Icons.reply_rounded, size: 13, color: AppTheme.primary),
              label: const Text(
                'Cevap Ver',
                style: TextStyle(color: AppTheme.primary, fontSize: 11, fontWeight: FontWeight.w600),
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
      return '${difference.inMinutes} dk önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} sa önce';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    }

    return DateFormat('d MMM yyyy').format(date);
  }
}
