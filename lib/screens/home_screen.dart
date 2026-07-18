import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:async';
import 'dart:ui';
import '../services/firestore_service.dart';
import '../services/deal_service.dart';
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
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import '../services/connectivity_service.dart';
import 'deal_detail_screen.dart';
import 'submit_deal_screen.dart';
import 'admin_screen.dart';
import 'profile_screen.dart';
import 'favorites_screen.dart';
import 'kuponlar_page.dart';
import 'aktuel_magazalar_page.dart';
import 'notification_settings_screen.dart';
import 'admin_notifications_screen.dart';

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
  bool _hasServerData = false;
  List<Deal> _rawDeals = [];
  
  late Stream<DealsSnapshot> _dealsStream;
  
  // Engelleme kontrolü için
  StreamSubscription? _blockedUserListener;
  
  // Okunmamış mesaj sayıları
  int _unreadMessageCount = 0;
  int _unreadAdminMessageCount = 0;
  StreamSubscription? _messageCountSubscription;
  StreamSubscription? _adminMessageCountSubscription;
  StreamSubscription? _intentSub;

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
    // Share Intent dinleyici
    _initShareIntentListener();
  }
  
  @override
  void dispose() {
    _blockedUserListener?.cancel();
    _messageCountSubscription?.cancel();
    _adminMessageCountSubscription?.cancel();
    _intentSub?.cancel();
    _themeService.removeListener(_onThemeChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _initShareIntentListener() {
    // 1. Uygulama açık veya arka plandayken gelen paylaşımları dinle
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      }
    }, onError: (err) {
      _log("getIntentSharingTextList Error: $err");
    });

    // 2. Uygulama tamamen kapalıyken paylaşımla açılırsa ilk paylaşımı al
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      }
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> files) {
    if (files.isEmpty) return;
    
    final sharedText = files.first.path;
    _log('📥 Paylaşılan veri alındı: $sharedText');
    
    final url = _extractUrl(sharedText);
    if (url != null) {
      _log('🎯 Ayıklanan URL: $url');
      
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubmitDealScreen(initialUrl: url),
          ),
        );
      }
    } else {
      _log('⚠️ Paylaşılan metinde geçerli bir link bulunamadı.');
    }
  }

  String? _extractUrl(String text) {
    final RegExp urlRegex = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegex.firstMatch(text);
    return match?.group(0);
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
      _messageCountSubscription = _firestoreService.getUserMessagesStream(currentUserId).listen(
        (messages) {
          if (mounted) {
            final unreadCount = messages
                .where((m) => m.receiverId == currentUserId && !m.isRead)
                .length;
            setState(() {
              _unreadMessageCount = unreadCount;
            });
          }
        },
        onError: (err) => _log('⚠️ HomeScreen unread message count stream error: $err'),
      );

      // Admin mesajları için stream
      _adminMessageCountSubscription?.cancel();
      _adminMessageCountSubscription = _firestoreService.getAdminToUserMessagesStream(currentUserId).listen(
        (messages) {
          if (mounted) {
            final unreadCount = messages.where((m) => !m.isRead).length;
            setState(() {
              _unreadAdminMessageCount = unreadCount;
            });
          }
        },
        onError: (err) => _log('⚠️ HomeScreen unread admin message count stream error: $err'),
      );
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
        if (error.toString().contains('permission-denied')) {
          _log('ℹ️ HomeScreen: Blocked user listener çıkış sırasında kapandı (beklenen)');
        } else {
          _log('❌ HomeScreen: Blocked user listener hatası: $error');
        }
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
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
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
        preferredSize: Size.fromHeight(
          MediaQuery.of(context).padding.top +
          (_isSearchMode ? 56 : 108),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackground : Colors.white,
            border: Border(
              bottom: BorderSide(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : Colors.black.withValues(alpha: 0.06),
                width: 1,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── ARAMA MODU ────────────────────────────────────────
                if (_isSearchMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            onChanged: _onSearchChanged,
                            style: TextStyle(
                              color: isDark ? Colors.white : AppTheme.textPrimary,
                              fontSize: 15,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Fırsat, mağaza veya açıklama ara...',
                              hintStyle: TextStyle(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.4)
                                    : AppTheme.textSecondary,
                                fontSize: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: AppTheme.primary.withValues(alpha: 0.7),
                                size: 20,
                              ),
                              suffixIcon: _searchQuery.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.close_rounded, size: 18),
                                      onPressed: _clearSearch,
                                      color: isDark ? Colors.white54 : AppTheme.textSecondary,
                                    )
                                  : null,
                              filled: true,
                              fillColor: isDark
                                  ? Colors.white.withValues(alpha: 0.07)
                                  : const Color(0xFFF5F5F5),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 10),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 22),
                          onPressed: _toggleSearchMode,
                          color: isDark ? Colors.white70 : AppTheme.textSecondary,
                        ),
                      ],
                    ),
                  )
                else ...[
                  // ─── SATIR 1: Logo + Bildirim + Profil + Admin ─────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 8, 4),
                    child: Row(
                      children: [
                        // Fırsatkolik logosu + wordmark
                        Image.asset(
                          'assets/store-icon.png',
                          width: 28,
                          height: 28,
                        ),
                        const SizedBox(width: 7),
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Fırsat',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : AppTheme.textPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const TextSpan(
                                text: 'kolik',
                                style: TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // Arama
                        _buildHeaderIconButton(
                          icon: Icons.search_rounded,
                          onTap: _toggleSearchMode,
                          isDark: isDark,
                        ),
                        // Bildirim zili
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildHeaderIconButton(
                              icon: _unreadAdminMessageCount > 0
                                  ? Icons.notifications_active
                                  : Icons.notifications_outlined,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => _unreadAdminMessageCount > 0
                                      ? const AdminNotificationsScreen()
                                      : const NotificationSettingsScreen(),
                                ),
                              ),
                              isDark: isDark,
                              accent: _unreadAdminMessageCount > 0
                                  ? Colors.red
                                  : null,
                            ),
                            if (_unreadAdminMessageCount > 0)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: isDark
                                          ? AppTheme.darkBackground
                                          : Colors.white,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Admin (sadece adminlere)
                        if (_isAdmin)
                          _buildHeaderIconButton(
                            icon: Icons.admin_panel_settings_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminScreen()),
                            ),
                            isDark: isDark,
                            accent: primaryColor,
                          ),
                      ],
                    ),
                  ),
                  // ─── SATIR 2: Kataloglar + Kuponlar + Grid/List ────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                    child: Row(
                      children: [
                        StreamBuilder<bool>(
                          stream: _firestoreService.couponsEnabledStream(),
                          initialData: true,
                          builder: (context, snapshot) {
                            final couponsEnabled = snapshot.data ?? true;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                _buildQuickActionChip(
                                  label: 'Kataloglar',
                                  icon: Icons.auto_stories_rounded,
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const AktuelMagazalarPage()),
                                  ),
                                  isDark: isDark,
                                  color: AppTheme.secondary,
                                ),
                                if (couponsEnabled) ...[
                                  const SizedBox(width: 8),
                                  _buildQuickActionChip(
                                    label: 'Kuponlar',
                                    icon: Icons.local_offer_rounded,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const KuponlarPage()),
                                    ),
                                    isDark: isDark,
                                    color: AppTheme.primary,
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const Spacer(),
                        // Grid / List toggle
                        Container(
                          height: 30,
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildViewModeButton(
                                icon: Icons.grid_view_rounded,
                                isSelected: _viewMode == CardViewMode.vertical,
                                onTap: () => _themeService
                                    .setViewMode(CardViewMode.vertical),
                                isDark: isDark,
                              ),
                              _buildViewModeButton(
                                icon: Icons.view_agenda_rounded,
                                isSelected:
                                    _viewMode == CardViewMode.horizontal,
                                onTap: () => _themeService
                                    .setViewMode(CardViewMode.horizontal),
                                isDark: isDark,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // ─── SATIR 3: Kategori Filtreleri ─────────────────────
                  SizedBox(
                    height: 36,
                    child: ListView.separated(
                      controller: _categoryScrollController,
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: Category.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 6),
                      itemBuilder: (context, index) {
                        final category = Category.categories[index];
                        final isSelected =
                            _selectedCategory == category.id &&
                                _selectedSubCategory == null;
                        return FilterChip(
                          label: Text(category.name),
                          selected: isSelected,
                          onSelected: (_) => setState(() {
                            _selectedCategory = category.id;
                            _selectedSubCategory = null;
                            _displayLimit = 20;
                          }),
                          backgroundColor:
                              isDark ? AppTheme.darkSurface : AppTheme.surface,
                          selectedColor: AppTheme.secondary,
                          labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white : AppTheme.textPrimary),
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            fontSize: 13,
                          ),
                          side: BorderSide(
                            color: isDark
                                ? (isSelected
                                    ? AppTheme.secondary
                                    : AppTheme.darkBorder)
                                : (isSelected
                                    ? AppTheme.secondary
                                    : const Color(0xFFE8E8E8)),
                            width: 1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 6),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ],
            ),
          ),
        ),
      ),      body: Column(
        children: [
          // Offline Banner
          const OfflineBanner(),
          // Liste
          Expanded(
            child: StreamBuilder<DealsSnapshot>(
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
                        childAspectRatio: 0.63,
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
                if (snapshot.hasData) {
                  final isFromCache = snapshot.data!.isFromCache;
                  if (!isFromCache) {
                    _hasServerData = true;
                  }
                }

                List<Deal> deals = snapshot.data?.deals ?? [];
                
                // Çevrimiçi isek, sunucu verisi zaten geldiyse ve bu snapshot cache'ten ise,
                // eski cache verisinin araya girip eski fırsatları tekrar göstermemesi için
                // hafızadaki son güncel listeyi (_rawDeals) koruyoruz.
                if (snapshot.hasData && snapshot.data!.isFromCache && _hasServerData && _rawDeals.isNotEmpty && ConnectivityService().isConnected) {
                  deals = _rawDeals;
                } else {
                  _rawDeals = deals;
                }
                
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

                // Profesyonel Oylama ve Sıcaklık Algoritması ile Sırala
                // (Sıcak fırsatlar en üstte, normaller/yeniler ortada, çöpler en altta)
                final List<Deal> sortedDeals = List<Deal>.from(filteredDeals);
                sortedDeals.sort(Deal.compareDeals);
                filteredDeals = sortedDeals;

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
                    
                    // Reset server data indicators to force fresh server retrieval
                    _hasServerData = false;
                    _rawDeals = [];
                    
                    if (mounted) {
                      setState(() {
                        _displayLimit = 20;
                        _dealsStream = _firestoreService.getDealsStream();
                        _hasMore = true;
                        _isLoadingMore = false;
                      });
                    }
                    
                    // Veriyi yenile
                    await Future.delayed(const Duration(milliseconds: 500));
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
                          childAspectRatio: 0.63,
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
                  
                  // Her durumda listeyi en üste kaydır
                  _scrollToTop();
                  
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

  Widget _buildHeaderIconButton({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    Color? accent,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: accent != null
                ? accent.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            icon,
            size: 22,
            color: accent ??
                (isDark ? Colors.white70 : AppTheme.textSecondary),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
    required Color color,
  }) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(9),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 11),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.13 : 0.08),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: color.withValues(alpha: isDark ? 0.3 : 0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark
                      ? color.withValues(alpha: 0.9)
                      : color,
                  letterSpacing: -0.1,
                ),
              ),
            ],
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
