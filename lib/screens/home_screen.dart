import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'dart:ui';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import '../widgets/offline_banner.dart';
import '../widgets/ad_deal_card.dart';
import '../models/category.dart';
import '../models/deal.dart';
import '../theme/app_theme.dart';
import 'deal_detail_screen.dart';
import 'submit_deal_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

// ViewMode artık DealCard içinde CardViewMode olarak tanımlı

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final ThemeService _themeService = ThemeService();
  
  String _selectedCategory = 'tumu';
  String? _selectedSubCategory;
  bool _isAdmin = false;
  bool _isCategoryMenuExpanded = false;
  Set<String> _followedCategories = {};
  Set<String> _followedSubCategories = {};
  bool _isGeneralNotificationsEnabled = true;
  String _searchQuery = '';
  bool _isSearchMode = false;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ScrollController _categoryScrollController = ScrollController();
  bool _showScrollToTop = false;
  late CardViewMode _viewMode;
  
  // Çift tıklama için timer
  DateTime? _lastHomeButtonTap;
  static const _doubleTapTimeLimit = Duration(milliseconds: 400);
  
  // Pagination için state
  List<Deal> _allDeals = [];
  int _displayLimit = 20;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  
  late Stream<List<Deal>> _dealsStream;
  
  // Engelleme kontrolü için
  StreamSubscription? _blockedUserListener;
  
  // Okunmamış mesaj sayıları
  int _unreadMessageCount = 0;
  int _unreadAdminMessageCount = 0;
  StreamSubscription? _messageCountSubscription;
  StreamSubscription? _adminMessageCountSubscription;

  @override
  void initState() {
    super.initState();
    _dealsStream = _firestoreService.getDealsStream();
    _viewMode = _themeService.viewMode;
    _checkAdminStatus();
    _checkBlockedStatus();
    _notificationService.requestPermission();
    _notificationService.setupNotificationListeners();
    _cleanupExpiredDeals();
    _loadFollowedCategories();
    _loadUnreadMessageCounts();
    // Theme service listener ekle
    _themeService.addListener(_onThemeChanged);
    // Scroll listener ekle
    _scrollController.addListener(_onScroll);
  }
  
  @override
  void dispose() {
    _blockedUserListener?.cancel();
    _messageCountSubscription?.cancel();
    _adminMessageCountSubscription?.cancel();
    _themeService.removeListener(_onThemeChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }
  
  // Okunmamış mesaj sayılarını yükle
  Future<void> _loadUnreadMessageCounts() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      // İlk yükleme
      final userMessageCount = await _firestoreService.getUnreadMessageCount(currentUserId);
      final adminMessageCount = await _firestoreService.getUnreadAdminToUserMessageCount(currentUserId);
      
      if (mounted) {
        setState(() {
          _unreadMessageCount = userMessageCount;
          _unreadAdminMessageCount = adminMessageCount;
        });
      }

      // Kullanıcı mesajları için stream
      _messageCountSubscription?.cancel();
      _messageCountSubscription = _firestoreService.getUserMessagesStream(currentUserId).listen((messages) {
        if (mounted) {
          final unreadCount = messages
              .where((m) => m.receiverId == currentUserId && !m.isRead)
              .length;
          setState(() {
            _unreadMessageCount = unreadCount;
          });
        }
      });

      // Admin mesajları için stream
      _adminMessageCountSubscription?.cancel();
      _adminMessageCountSubscription = _firestoreService.getAdminToUserMessagesStream(currentUserId).listen((messages) {
        if (mounted) {
          final unreadCount = messages.where((m) => !m.isRead).length;
          setState(() {
            _unreadAdminMessageCount = unreadCount;
          });
        }
      });
    } catch (e) {
      _log('❌ Okunmamış mesaj sayısı yükleme hatası: $e');
    }
  }
  
  // Engelleme durumunu kontrol et
  Future<void> _checkBlockedStatus() async {
    final currentUser = _authService.currentUser;
    if (currentUser == null) return;
    
    try {
      _log('🔍 HomeScreen: Engelleme kontrolü yapılıyor: ${currentUser.uid}');
      final isBlocked = await _firestoreService.isUserBlocked(currentUser.uid);
      _log('🔍 HomeScreen: Engelleme durumu: $isBlocked');
      
      if (isBlocked) {
        _log('🚫 HomeScreen: Kullanıcı engellenmiş, oturum kapatılıyor: ${currentUser.uid}');
        _blockedUserListener?.cancel();
        
        // Önce bildirim aboneliklerini temizle
        await _notificationService.clearAllSubscriptions();
        
        // Sonra oturumu kapat
        await _authService.signOut();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.block, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Hesabınız engellenmiştir. Lütfen destek ekibi ile iletişime geçin.',
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red[600],
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } else {
        // Kullanıcı engellenmemiş, real-time listener başlat
        _startBlockedUserListener(currentUser.uid);
      }
    } catch (e) {
      _log('❌ HomeScreen: Engelleme kontrolü hatası: $e');
    }
  }
  
  // Real-time listener: Kullanıcı uygulama açıkken engellenirse çıkış yaptır
  void _startBlockedUserListener(String userId) {
    // Eğer zaten bir listener varsa, yeni bir tane başlatma
    if (_blockedUserListener != null) {
      _log('👂 HomeScreen: Listener zaten aktif, yeni listener başlatılmıyor');
      return;
    }
    
    _log('👂 HomeScreen: Real-time engelleme listener başlatılıyor: $userId');
    try {
      _blockedUserListener = _firestoreService.firestore
          .collection('blockedUsers')
          .doc(userId)
          .snapshots()
          .listen((snapshot) async {
        _log('👂 HomeScreen: Engelleme listener tetiklendi: exists=${snapshot.exists}, mounted=$mounted, userId=$userId');
        if (snapshot.exists && mounted) {
          _log('🚫 HomeScreen: Kullanıcı engellendi (real-time), oturum kapatılıyor: $userId');
          _blockedUserListener?.cancel();
          
          try {
            // Önce bildirim aboneliklerini temizle
            await _notificationService.clearAllSubscriptions();
            _log('✅ HomeScreen: Bildirim abonelikleri temizlendi');
            
            // Sonra oturumu kapat
            await _authService.signOut();
            _log('✅ HomeScreen: Oturum kapatıldı');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Row(
                    children: [
                      Icon(Icons.block, color: Colors.white),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Hesabınız engellenmiştir. Lütfen destek ekibi ile iletişime geçin.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                  backgroundColor: Colors.red[600],
                  behavior: SnackBarBehavior.floating,
                  margin: const EdgeInsets.all(16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          } catch (e) {
            _log('❌ HomeScreen: Engelleme işlemi hatası: $e');
            // Hata olsa bile oturumu kapatmayı dene
            try {
              await _authService.signOut();
            } catch (signOutError) {
              _log('❌ HomeScreen: SignOut hatası: $signOutError');
            }
          }
        } else if (!snapshot.exists) {
          _log('✅ HomeScreen: Kullanıcı engeli kaldırıldı (real-time): $userId');
        }
      }, onError: (error) {
        _log('❌ HomeScreen: Blocked user listener hatası: $error');
        _blockedUserListener = null; // Hata durumunda listener'ı sıfırla
      });
      _log('✅ HomeScreen: Real-time engelleme listener başarıyla başlatıldı: $userId');
    } catch (e) {
      _log('❌ HomeScreen: Listener başlatma hatası: $e');
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // 150 piksel aşağı kaydırıldıysa veya en alta yakınsa butonu göster
    final shouldShow = offset > 150 || (maxScroll > 0 && offset > maxScroll * 0.1);
    
    // Sadece değişiklik olduğunda setState çağır
    if (shouldShow != _showScrollToTop && mounted) {
      setState(() {
        _showScrollToTop = shouldShow;
      });
    }
    
    // Infinite scroll: En alta yaklaşıldığında daha fazla yükle
    if (offset > maxScroll - 200 && _hasMore && !_isLoadingMore && mounted) {
      _loadMoreDeals();
    }
  }

  void _loadMoreDeals() {
    if (_isLoadingMore || !_hasMore) return;
    
    setState(() {
      _isLoadingMore = true;
    });
    
    // Daha fazla deal göster
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        final newLimit = _displayLimit + 20;
        final hasMore = newLimit < _allDeals.length;
        
        setState(() {
          _displayLimit = newLimit;
          _hasMore = hasMore;
          _isLoadingMore = false;
        });
      }
    });
  }

  void _scrollToTop() {
    _scrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 400), // Daha hızlı scroll
      curve: Curves.easeOut, // Daha hızlı curve
    );
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _viewMode = _themeService.viewMode;
      });
    }
  }

  Future<void> _loadFollowedCategories() async {
    final categories = await _notificationService.getFollowedCategories();
    final subCategories = await _notificationService.getFollowedSubCategories();
    final generalEnabled = await _notificationService.getGeneralNotificationsEnabled();
    if (mounted) {
      setState(() {
        _followedCategories = categories.toSet();
        _followedSubCategories = subCategories.toSet();
        _isGeneralNotificationsEnabled = generalEnabled;
      });
    }
  }

  Future<void> _toggleGeneralNotification() async {
    final newValue = !_isGeneralNotificationsEnabled;
    try {
      await _notificationService.setGeneralNotifications(newValue);
      if (mounted) {
        setState(() => _isGeneralNotificationsEnabled = newValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue ? 'Tüm bildirimler açıldı' : 'Tüm bildirimler kapatıldı',
            ),
            duration: const Duration(seconds: 1),
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
    }
  }

  Future<void> _toggleCategoryNotification(String categoryId) async {
    try {
      if (_followedCategories.contains(categoryId)) {
        await _notificationService.unsubscribeFromCategory(categoryId);
      } else {
        await _notificationService.subscribeToCategory(categoryId);
      }
      await _loadFollowedCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _followedCategories.contains(categoryId)
                  ? 'Bildirim açıldı'
                  : 'Bildirim kapatıldı',
            ),
            duration: const Duration(seconds: 1),
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
    }
  }

  Future<void> _toggleSubCategoryNotification(String categoryId, String subCategory) async {
    try {
      final subCategoryKey = '$categoryId:$subCategory';
      if (_followedSubCategories.contains(subCategoryKey)) {
        await _notificationService.unsubscribeFromSubCategory(categoryId, subCategory);
      } else {
        await _notificationService.subscribeToSubCategory(categoryId, subCategory);
      }
      await _loadFollowedCategories();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _followedSubCategories.contains(subCategoryKey)
                  ? 'Bildirim açıldı'
                  : 'Bildirim kapatıldı',
            ),
            duration: const Duration(seconds: 1),
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
    }
  }

  // Reklam pozisyonlarını hesapla (5-6-5-6-5-6 pattern)
  // Pattern: İlk reklam 5 deal'den sonra, ikinci 6 deal'den sonra, üçüncü 5 deal'den sonra, vs.
  // Pozisyonlar: 5, 12, 18, 25, 31, 38, ...
  List<int> _calculateAdPositions(int dealCount) {
    List<int> positions = [];
    int currentPosition = 5; // İlk reklam 5 deal'den sonra
    int patternIndex = 0; // Pattern index: 0=6 (ilk reklamdan sonra), 1=5, 2=6, 3=5, ...
    
    // Pattern: [5, 6, 5, 6, 5, 6, ...]
    while (currentPosition < dealCount) {
      positions.add(currentPosition);
      
      // Pattern'e göre interval belirle: çift index'ler 6, tek index'ler 5
      // İlk reklamdan sonra 6 deal, ikinci reklamdan sonra 5 deal, üçüncü reklamdan sonra 6 deal, ...
      int interval = (patternIndex % 2 == 0) ? 6 : 5;
      currentPosition += interval + 1; // +1 reklam kartı için
      patternIndex++;
    }
    
    return positions;
  }

  // Expired deal'leri temizle (gün bittiğinde sil)
  Future<void> _cleanupExpiredDeals() async {
    try {
      // Süresi dolan deal'ları temizle
      await _firestoreService.cleanupExpiredDeals();
      // 24 saatten eski deal'ları sil
      await _firestoreService.deleteOldDeals();
    } catch (e) {
      // Sessizce hata yok say, kullanıcıyı rahatsız etme
      _log('Temizleme hatası: $e');
    }
  }

  Future<void> _checkAdminStatus() async {
    try {
      _log('🔍 Admin durumu kontrol ediliyor...');
      final isAdmin = await _authService.isAdmin();
      _log('👮 Admin durumu: $isAdmin');
      if (mounted) {
        setState(() {
          _isAdmin = isAdmin;
          _log('✅ _isAdmin state güncellendi: $_isAdmin');
        });
      }
      // Admin ise bildirim aboneliğini garanti et (mobilde giriş sonrası FCM gecikmeli olabilir)
      if (isAdmin) {
        Future.delayed(const Duration(seconds: 2), () async {
          if (!mounted) return;
          try {
            await _notificationService.subscribeToAdminTopic();
            _log('✅ Ana sayfa: Admin bildirim aboneliği doğrulandı');
          } catch (e) {
            _log('⚠️ Admin bildirim aboneliği (Home): $e');
          }
        });
      }
    } catch (e) {
      _log('❌ Admin kontrolü hatası: $e');
    }
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      _displayLimit = 20;
      if (_isSearchMode) {
        _searchController.text = _searchQuery;
        // Arama modu açıldığında cursor'u sona al
        Future.delayed(const Duration(milliseconds: 100), () {
          _searchController.selection = TextSelection.fromPosition(
            TextPosition(offset: _searchController.text.length),
          );
        });
      } else {
        // Arama modu kapatıldığında sorguyu temizle
        _searchQuery = '';
        _searchController.clear();
      }
    });
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      _displayLimit = 20;
    });
  }

  void _clearSearch() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _displayLimit = 20;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return PopScope(
      canPop: !_isSearchMode,
      onPopInvoked: (bool didPop) {
        if (!didPop && _isSearchMode) {
          // Arama modu açıksa geri tuşuna basıldığında arama modunu kapat
          _toggleSearchMode();
        }
      },
      child: Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(125),
        child: Container(
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkBackground : Colors.white).withOpacity(0.95),
            border: Border(
              bottom: BorderSide(
                color: Colors.black.withOpacity(isDark ? 0.05 : 0.05),
                width: 2,
              ),
            ),
          ),
          child: Container(
            color: (isDark ? AppTheme.darkBackground : Colors.white).withOpacity(0.95),
            child: SafeArea(
              child: Column(
                children: [
                  // Header - FIRSAT KOLİK başlığı ve butonlar veya Arama çubuğu
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: _isSearchMode
                        ? Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  autofocus: true,
                                  onChanged: _onSearchChanged,
                                  decoration: InputDecoration(
                                    hintText: 'Fırsat, mağaza veya açıklama ara...',
                                    prefixIcon: const Icon(Icons.search),
                                    suffixIcon: _searchQuery.isNotEmpty
                                        ? IconButton(
                                            icon: const Icon(Icons.clear),
                                            onPressed: _clearSearch,
                                          )
                                        : null,
                                    filled: true,
                                    fillColor: isDark 
                                        ? Colors.white.withValues(alpha: 0.1)
                                        : Colors.black.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.close),
                                onPressed: _toggleSearchMode,
                                color: isDark ? Colors.white : AppTheme.textPrimary,
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'FIRSAT KOLİK',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? Colors.white : AppTheme.textPrimary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                        if (!_isSearchMode) ...[
                          // Görünüm modu toggle
                          Container(
                            height: 40,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildViewModeButton(
                                  icon: Icons.grid_view,
                                  isSelected: _viewMode == CardViewMode.vertical,
                                  onTap: () => _themeService.setViewMode(CardViewMode.vertical),
                                  isDark: isDark,
                                ),
                                _buildViewModeButton(
                                  icon: Icons.view_agenda,
                                  isSelected: _viewMode == CardViewMode.horizontal,
                                  onTap: () => _themeService.setViewMode(CardViewMode.horizontal),
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Dikey ayırıcı
                          Container(
                            width: 1,
                            height: 24,
                            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.1),
                          ),
                          const SizedBox(width: 12),
                          // Search butonu
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: _toggleSearchMode,
                                child: Icon(
                                  Icons.search,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                        // Admin panel butonu (sadece admin kullanıcılar için ve arama modunda değilken)
                        if (_isAdmin && !_isSearchMode) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(999),
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                                ),
                                child: Icon(
                                  Icons.admin_panel_settings_rounded,
                                  color: primaryColor,
                                  size: 22,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Kategori Chip'leri (Horizontal Scroll) - Arama modunda gizle
                  if (!_isSearchMode)
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      controller: _categoryScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: Category.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = Category.categories[index];
                        final isSelected = _selectedCategory == category.id && _selectedSubCategory == null;
                        
                        return FilterChip(
                          label: Text(category.name),
                          selected: isSelected,
                          onSelected: (_) => setState(() {
                            _selectedCategory = category.id;
                            _selectedSubCategory = null;
                            _displayLimit = 20;
                          }),
                          backgroundColor: isDark ? AppTheme.darkSurface : AppTheme.surface,
                          selectedColor: AppTheme.secondary,
                          labelStyle: TextStyle(
                            color: isSelected 
                                ? Colors.white
                                : (isDark ? Colors.white : AppTheme.textPrimary),
                            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 14,
                          ),
                          side: BorderSide(
                            color: isDark 
                                ? (isSelected ? AppTheme.secondary : AppTheme.darkBorder)
                                : (isSelected ? AppTheme.secondary : const Color(0xFFE0E0E0)),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999), // rounded-full
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Offline Banner
          const OfflineBanner(),
          // Liste
          Expanded(
            child: StreamBuilder<List<Deal>>(
              stream: _dealsStream,
              builder: (context, snapshot) {
                // StreamBuilder optimizasyonu - sadece gerekli durumlarda rebuild
                // Hata durumu
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Bir hata oluştu: ${snapshot.error}',
                          style: TextStyle(color: Colors.red[500], fontSize: 14),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () => setState(() {}),
                          child: const Text('Yeniden Dene'),
                        ),
                      ],
                    ),
                  );
                }

                // Yükleniyor durumu - Skeleton Loading
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  if (_viewMode == CardViewMode.vertical) {
                    return GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.68,
                      ),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return DealCardSkeleton(viewMode: _viewMode);
                      },
                    );
                  } else {
                    return ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
                      itemCount: 6,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: DealCardSkeleton(viewMode: _viewMode),
                        );
                      },
                    );
                  }
                }

                // Veri yoksa boş liste kullan
                final deals = snapshot.data ?? [];
                
                // Filtreleme (İstemci tarafında) - Optimize edildi
                // Bot'tan gelen kategori ID olarak saklanıyor ("elektronik", "moda" vb.)
                List<Deal> filteredDeals;
                if (_selectedCategory == 'tumu') {
                  filteredDeals = deals;
                } else {
                  final categoryLower = _selectedCategory.toLowerCase();
                  filteredDeals = deals.where((d) {
                        // Kategori ID ile karşılaştır (bot ID gönderiyor)
                    final categoryMatch = d.category.toLowerCase() == categoryLower;
                        if (_selectedSubCategory != null) {
                          return categoryMatch && d.subCategory == _selectedSubCategory;
                        }
                        return categoryMatch;
                      }).toList();
                }

                // Arama filtresi
                if (_searchQuery.isNotEmpty) {
                  final query = _searchQuery.toLowerCase();
                  filteredDeals = filteredDeals.where((deal) {
                    return deal.title.toLowerCase().contains(query) ||
                           deal.description.toLowerCase().contains(query) ||
                           deal.store.toLowerCase().contains(query);
                  }).toList();
                }

                // Pagination için deal'leri güncelle
                _allDeals = filteredDeals;
                _hasMore = filteredDeals.length > _displayLimit;

                if (filteredDeals.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.search_off_rounded, size: 64, color: Colors.grey[300]),
                        const SizedBox(height: 16),
                        Text(
                          'Henüz fırsat yok',
                          style: TextStyle(color: Colors.grey[500], fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                // Pagination için gösterilecek deal'ler
                final dealsToShow = filteredDeals.take(_displayLimit).toList();

                // Reklam kartlarını ekle (5-6-5-6-5-6 pattern)
                // Pattern: İlk reklam 5 deal'den sonra, ikinci 6 deal'den sonra, üçüncü 5 deal'den sonra, vs.
                List<int> adPositions = _calculateAdPositions(dealsToShow.length);
                final int adCount = adPositions.length;
                final int totalItemCount = dealsToShow.length + adCount + (_hasMore && _isLoadingMore ? 1 : 0);

                return RefreshIndicator(
                  onRefresh: () async {
                    // Haptic feedback ekle
                    HapticFeedback.mediumImpact();
                    
                    // Veriyi yenile
                    await Future.delayed(const Duration(milliseconds: 500));
                    
                    if (mounted) {
                      setState(() {
                        _displayLimit = 20;
                        _hasMore = _allDeals.length > _displayLimit;
                        _isLoadingMore = false;
                      });
                    }
                  },
                  color: AppTheme.primary,
                  strokeWidth: 3.0,
                  child: _viewMode == CardViewMode.vertical 
                    ? GridView.builder(
                        controller: _scrollController,
                        key: ValueKey('deal_grid_$_selectedCategory'),
                        padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.68,
                        ),
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        cacheExtent: 500, // Optimize edilmiş cache
                        addAutomaticKeepAlives: false, // Performans için
                        addRepaintBoundaries: true, // Repaint optimizasyonu
                        addSemanticIndexes: false, // Performans için
                        itemCount: totalItemCount,
                        itemBuilder: (context, index) {
                          // Loading indicator kontrolü
                          if (index >= dealsToShow.length + adCount) {
                            return Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (dotIndex) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                            );
                          }
                          
                          // Reklam pozisyonunu kontrol et (5-6-5-6-5-6 pattern)
                          // Reklam pozisyonları: 5, 12, 18, 25, 31, 38, ...
                          
                          // Kaç reklam geçtiğini hesapla
                          int passedAds = 0;
                          for (int i = 0; i < adPositions.length; i++) {
                            final adPosition = adPositions[i];
                            if (index == adPosition) {
                              // Bu pozisyon bir reklam pozisyonu
                              return RepaintBoundary(
                                key: ValueKey('ad_card_vertical_$i'),
                                child: AdDealCard(
                                  viewMode: CardViewMode.vertical,
                                  adUnitId: 'ca-app-pub-6853997017739651/8758625050', // Ana Sayfa Banner - Gerçek Ad Unit ID
                                ),
                              );
                            }
                            if (index > adPosition) {
                              passedAds++;
                            }
                          }
                          
                          // Normal deal kartı (geçilen reklam sayısını çıkar)
                          final actualIndex = index - passedAds;
                          if (actualIndex >= dealsToShow.length || actualIndex < 0) {
                            return const SizedBox.shrink();
                          }
                          final deal = dealsToShow[actualIndex];
                          return RepaintBoundary(
                            key: ValueKey('deal_card_${deal.id}'),
                            child: DealCard(
                              key: ValueKey('deal_card_${deal.id}'),
                              deal: deal,
                              viewMode: CardViewMode.vertical,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DealDetailScreen(dealId: deal.id),
                                ),
                              ),
                            ),
                          );
                        },
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        key: ValueKey('deal_list_$_selectedCategory'),
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 4),
                        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                        cacheExtent: 500, // Optimize edilmiş cache
                        addAutomaticKeepAlives: false, // Performans için
                        addRepaintBoundaries: true, // Repaint optimizasyonu
                        addSemanticIndexes: false, // Performans için
                        itemCount: totalItemCount,
                        itemBuilder: (context, index) {
                          // Loading indicator kontrolü
                          if (index >= dealsToShow.length + adCount) {
                            return Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(3, (dotIndex) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  );
                                }),
                              ),
                            );
                          }
                          
                          // Reklam pozisyonunu kontrol et (5-6-5-6-5-6 pattern)
                          // Reklam pozisyonları: 5, 12, 18, 25, 31, 38, ...
                          
                          // Kaç reklam geçtiğini hesapla
                          int passedAds = 0;
                          for (int i = 0; i < adPositions.length; i++) {
                            final adPosition = adPositions[i];
                            if (index == adPosition) {
                              // Bu pozisyon bir reklam pozisyonu
                              return RepaintBoundary(
                                key: ValueKey('ad_card_horizontal_$i'),
                                child: AdDealCard(
                                  viewMode: CardViewMode.horizontal,
                                  adUnitId: 'ca-app-pub-6853997017739651/8758625050', // Ana Sayfa Banner - Gerçek Ad Unit ID
                                ),
                              );
                            }
                            if (index > adPosition) {
                              passedAds++;
                            }
                          }
                          
                          // Normal deal kartı (geçilen reklam sayısını çıkar)
                          final actualIndex = index - passedAds;
                          if (actualIndex >= dealsToShow.length || actualIndex < 0) {
                            return const SizedBox.shrink();
                          }
                          final deal = dealsToShow[actualIndex];
                          return RepaintBoundary(
                            key: ValueKey('deal_card_list_${deal.id}'),
                            child: DealCard(
                              key: ValueKey('deal_card_list_${deal.id}'),
                              deal: deal,
                              viewMode: CardViewMode.horizontal,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => DealDetailScreen(dealId: deal.id),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          border: Border(
            top: BorderSide(
              color: Colors.black.withOpacity(isDark ? 0.1 : 0.05),
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 8, top: 4),
        child: SafeArea(
          top: false,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Ana Sayfa - Çift tıklama ile "Tümü" kategorisine geç
              _buildBottomNavItem(
                icon: Icons.home,
                label: 'Ana Sayfa',
                isSelected: true,
                onTap: () {
                  final now = DateTime.now();
                  if (_lastHomeButtonTap != null &&
                      now.difference(_lastHomeButtonTap!) < _doubleTapTimeLimit) {
                    // Çift tıklama algılandı - "Tümü" kategorisine geç
                    setState(() {
                      _selectedCategory = 'tumu';
                      _selectedSubCategory = null;
                      _displayLimit = 20;
                    });
                    // Kategori barını başa kaydır
                    if (_categoryScrollController.hasClients) {
                      _categoryScrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    }
                    _lastHomeButtonTap = null;
                  } else {
                    // İlk tıklama
                    _lastHomeButtonTap = now;
                  }
                },
              ),
              // Beğenilenler
              _buildBottomNavItem(
                icon: Icons.favorite,
                label: 'Beğenilenler',
                isSelected: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                  );
                },
              ),
              // Fırsat Paylaş
              _buildBottomNavItem(
                icon: Icons.add_circle_outline,
                label: 'Fırsat Paylaş',
                isSelected: false,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SubmitDealScreen()),
                  );
                },
              ),
              // Profil
              _buildBottomNavItem(
                icon: Icons.person,
                label: 'Profil',
                isSelected: false,
                badgeCount: _unreadMessageCount + _unreadAdminMessageCount,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfileScreen()),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton(
              heroTag: 'scroll_to_top',
              mini: true,
              onPressed: _scrollToTop,
              backgroundColor: primaryColor,
              child: const Icon(Icons.keyboard_arrow_up, color: Colors.black),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), // Dokunma alanını genişlet
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected 
                        ? primaryColor.withValues(alpha: isDark ? 0.1 : 0.2)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    icon,
                    color: isSelected 
                        ? (isDark ? primaryColor : Colors.black)
                        : (isDark ? Colors.grey[400] : AppTheme.textSecondary),
                    size: 18,
                  ),
                ),
                // Sağ alt köşede kırmızı nokta (bildirim göstergesi)
                if (badgeCount > 0)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? AppTheme.darkSurface : Colors.white,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 1),
            Text(
              label,
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: isSelected 
                    ? (isDark ? primaryColor : Colors.black)
                    : (isDark ? Colors.grey[400] : AppTheme.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewModeButton({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: isSelected 
                ? (isDark ? AppTheme.darkSurface : Colors.white)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            boxShadow: isSelected ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ] : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isSelected 
                ? (isDark ? Colors.white : AppTheme.textPrimary)
                : (isDark ? Colors.grey[400] : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  String _getSelectedCategoryText() {
    if (_selectedCategory == 'tumu') return 'Tümü';
    final category = Category.getById(_selectedCategory);
    if (_selectedSubCategory != null) {
      return '${category.icon} ${category.name} > $_selectedSubCategory';
    }
    return '${category.icon} ${category.name}';
  }

  Widget _buildCategoryItem(Category category, String? subCategory, {required bool isSelected, bool showNotification = true}) {
    final isNotificationEnabled = category.id == 'tumu'
        ? _isGeneralNotificationsEnabled
        : subCategory == null
            ? _followedCategories.contains(category.id)
            : _followedSubCategories.contains('${category.id}:$subCategory');

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        return InkWell(
          onTap: () {
            setState(() {
              if (subCategory != null) {
                _selectedCategory = category.id;
                _selectedSubCategory = subCategory;
              } else {
                _selectedCategory = category.id;
                _selectedSubCategory = null;
              }
              _displayLimit = 20;
              _isCategoryMenuExpanded = false;
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: isSelected 
                              ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1) 
                : Colors.transparent,
            child: Row(
              children: [
                if (subCategory == null) ...[
                  Text(
                    category.icon,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 12),
                ] else ...[
                  const SizedBox(width: 32),
                  Icon(
                    Icons.subdirectory_arrow_right, 
                    size: 16, 
                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    subCategory ?? category.name,
                    style: TextStyle(
                      fontSize: subCategory != null ? 14 : 16,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected 
                          ? primaryColor 
                          : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
                    ),
                  ),
                ),
                // Bildirim butonu (Tümü kategorisi için gösterilmez)
                if (showNotification)
                  IconButton(
                    icon: Icon(
                      isNotificationEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                      color: isNotificationEnabled 
                          ? primaryColor 
                          : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                      size: 20,
                    ),
                onPressed: () {
                  if (category.id == 'tumu') {
                    _toggleGeneralNotification();
                  } else if (subCategory == null) {
                    _toggleCategoryNotification(category.id);
                  } else {
                    _toggleSubCategoryNotification(category.id, subCategory);
                  }
                },
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: isNotificationEnabled ? 'Bildirimleri Kapat' : 'Bildirimleri Aç',
              ),
                if (showNotification) const SizedBox(width: 8),
                if (isSelected)
                  Icon(Icons.check, color: primaryColor, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpandableCategory(Category category) {
    final isMainCategorySelected = _selectedCategory == category.id && _selectedSubCategory == null;
    final isExpanded = _selectedCategory == category.id;
    final isNotificationEnabled = _followedCategories.contains(category.id);

    return Builder(
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Column(
          children: [
            InkWell(
              onTap: () {
                setState(() {
                  if (category.subcategories.isEmpty) {
                    // Alt kategori yoksa direkt seç
                    _selectedCategory = category.id;
                    _selectedSubCategory = null;
                    _displayLimit = 20;
                    _isCategoryMenuExpanded = false;
                  } else {
                    // Alt kategori varsa expand/collapse yap
                    if (_selectedCategory == category.id && _selectedSubCategory == null) {
                      _selectedCategory = 'tumu';
                      _selectedSubCategory = null;
                    } else {
                      _selectedCategory = category.id;
                      _selectedSubCategory = null;
                    }
                    _displayLimit = 20;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                color: isMainCategorySelected
                    ? primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                    : Colors.transparent,
                child: Row(
                  children: [
                    Text(
                      category.icon,
                      style: const TextStyle(fontSize: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        category.name,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: isMainCategorySelected ? FontWeight.bold : FontWeight.w500,
                          color: isMainCategorySelected 
                              ? primaryColor 
                              : (isDark ? AppTheme.darkTextPrimary : Colors.black87),
                        ),
                      ),
                    ),
                    // Bildirim butonu
                    IconButton(
                      icon: Icon(
                        isNotificationEnabled ? Icons.notifications_active : Icons.notifications_off_outlined,
                        color: isNotificationEnabled 
                            ? primaryColor 
                            : (isDark ? AppTheme.darkTextSecondary : Colors.grey),
                        size: 20,
                      ),
                      onPressed: () => _toggleCategoryNotification(category.id),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: isNotificationEnabled ? 'Bildirimleri Kapat' : 'Bildirimleri Aç',
                    ),
                    const SizedBox(width: 8),
                    if (category.subcategories.isNotEmpty)
                      AnimatedRotation(
                        turns: isExpanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.arrow_drop_down, 
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey,
                        ),
                      ),
                    if (isMainCategorySelected)
                      const SizedBox(width: 8),
                    if (isMainCategorySelected)
                      Icon(Icons.check, color: primaryColor, size: 20),
                  ],
                ),
              ),
            ),
            // Alt kategoriler
            if (isExpanded && category.subcategories.isNotEmpty)
              ...category.subcategories.map((sub) {
                final isSubSelected = _selectedCategory == category.id && _selectedSubCategory == sub;
                return _buildCategoryItem(category, sub, isSelected: isSubSelected);
              }).toList(),
            Divider(
              height: 1,
              color: isDark ? AppTheme.darkDivider : Colors.grey[200],
            ),
          ],
        );
      },
    );
  }

  Widget _buildThemeToggleButton() {
    final isDark = _themeService.isDarkMode;
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
      width: 56,
      height: 32,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: isDark
            ? LinearGradient(
                colors: [
                  Colors.orange.shade400,
                  Colors.deepOrange.shade600,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : LinearGradient(
                colors: [
                  Colors.amber.shade300,
                  Colors.orange.shade400,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.deepOrange : Colors.orange).withValues(alpha: 0.4),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // Haptic feedback ekle
            HapticFeedback.lightImpact();
            _themeService.toggleTheme();
          },
          child: Stack(
            children: [
              // Arka plan animasyonu
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOutCubic,
                left: isDark ? 24 : 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
              // İkonlar
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    return RotationTransition(
                      turns: Tween<double>(begin: 0.5, end: 1.0).animate(
                        CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeInOut,
                        ),
                      ),
                      child: FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(
                          scale: animation,
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: Icon(
                    isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                    key: ValueKey<bool>(isDark),
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
