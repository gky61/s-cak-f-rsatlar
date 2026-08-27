import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/services.dart';
import 'dart:async';
import '../services/firestore_service.dart';
import '../services/deal_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/theme_service.dart';
import '../services/deal_search_engine.dart';
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
import 'admin_notifications_screen.dart';
import 'popular_deals_screen.dart';
import 'keyword_tracking_screen.dart';
import 'botkolik_profile_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/asset_path_migration.dart';
import '../utils/badge_helper.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../services/in_app_tutorial_service.dart';
import '../widgets/in_app_tutorial/tutorial_spotlight_overlay.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

// ViewMode artık DealCard içinde CardViewMode olarak tanımlı

enum SearchScope { deals, users }

class HomeScreen extends StatefulWidget {
  final String? initialSearchQuery;
  final bool startTutorial;
  final int initialTabIndex;

  const HomeScreen({
    super.key,
    this.initialSearchQuery,
    this.startTutorial = false,
    this.initialTabIndex = 0,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final NotificationService _notificationService = NotificationService();
  final ThemeService _themeService = ThemeService();
  final InAppTutorialService _tutorialService = InAppTutorialService();
  
  late int _currentTabIndex;
  String _selectedCategory = 'tumu';
  String? _selectedSubCategory;
  bool _isAdmin = false;
  bool _isCategoryMenuExpanded = false;
  Set<String> _followedCategories = {};
  Set<String> _followedSubCategories = {};
  Set<String> _followedKeywords = {};
  bool _isAddingKeywordFromSearch = false;
  bool _isGeneralNotificationsEnabled = true;
  String _searchQuery = '';
  bool _isSearchMode = false;
  SearchScope _activeSearchScope = SearchScope.deals;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _matchedUsers = [];
  bool _isSearchingUsers = false;
  Timer? _userSearchDebounceTimer;
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
  bool _initialLoadingTimedOut = false;
  Timer? _initialLoadingTimeoutTimer;
  List<Deal> _rawDeals = [];
  
  late Stream<DealsSnapshot> _dealsStream;
  
  // Engelleme kontrolü için
  StreamSubscription? _blockedUserListener;
  
  // Okunmamış mesaj ve bildirim sayıları
  int _unreadMessageCount = 0;
  int _unreadAdminMessageCount = 0;
  int _unreadNotificationCount = 0;
  StreamSubscription? _messageCountSubscription;
  StreamSubscription? _adminMessageCountSubscription;
  StreamSubscription? _unreadNotificationsSubscription;
  StreamSubscription? _intentSub;
  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _currentTabIndex = widget.initialTabIndex;
    _tutorialService.refreshKeys();
    _startInitialLoadingTimeout();
    _dealsStream = _firestoreService.getDealsStream();
    _viewMode = _themeService.viewMode;
    _checkAdminStatus();
    _checkBlockedStatus();
    _notificationService.setupNotificationListeners();
    _notificationService.saveFCMToken(); // Otomatik FCM token doğrulama ve iyileştirme
    _cleanupExpiredDeals();
    _loadFollowedCategories();
    _loadFollowedKeywords();
    _loadUnreadMessageCounts();

    if (widget.initialSearchQuery != null && widget.initialSearchQuery!.trim().isNotEmpty) {
      _isSearchMode = true;
      _searchQuery = widget.initialSearchQuery!.trim();
      _searchController.text = widget.initialSearchQuery!.trim();
    }

    _authSub = _authService.authStateChanges.listen((user) {
      if (mounted) {
        _checkAdminStatus();
        _loadFollowedCategories();
        _loadFollowedKeywords();
        _loadUnreadMessageCounts();
        if (user != null) {
          _notificationService.saveFCMToken(userId: user.uid);
        }
        setState(() {});
      }
    });
    // Theme service listener ekle
    _themeService.addListener(_onThemeChanged);
    // Scroll listener ekle
    _scrollController.addListener(_onScroll);
    // Share Intent dinleyici
    _initShareIntentListener();
    // In-App Tutorial Kontrolü
    _checkAndTriggerTutorial();
  }

  @override
  void didUpdateWidget(HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTabIndex != oldWidget.initialTabIndex) {
      setState(() {
        _currentTabIndex = widget.initialTabIndex;
      });
    }

    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery != oldWidget.initialSearchQuery &&
        widget.initialSearchQuery!.trim().isNotEmpty) {
      setState(() {
        _isSearchMode = true;
        _searchQuery = widget.initialSearchQuery!.trim();
        _searchController.text = widget.initialSearchQuery!.trim();
        _displayLimit = 20;
      });
    }

    if (widget.startTutorial && !oldWidget.startTutorial) {
      _checkAndTriggerTutorial();
    }
  }

  void _checkAndTriggerTutorial() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (widget.startTutorial) {
        Future.delayed(const Duration(milliseconds: 600), () {
          if (mounted) {
            _startInAppTutorial();
          }
        });
        return;
      }

      if (widget.initialSearchQuery == null || widget.initialSearchQuery!.trim().isEmpty) {
        final hasSeen = await _tutorialService.hasSeenTutorial();
        if (!hasSeen && mounted) {
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              _startInAppTutorial();
            }
          });
        }
      }
    });
  }

  void _startInAppTutorial() {
    TutorialSpotlightOverlay.show(
      context: context,
      steps: _tutorialService.getTutorialSteps(),
    );
  }
  
  @override
  void dispose() {
    _initialLoadingTimeoutTimer?.cancel();
    _authSub?.cancel();
    _blockedUserListener?.cancel();
    _messageCountSubscription?.cancel();
    _adminMessageCountSubscription?.cancel();
    _unreadNotificationsSubscription?.cancel();
    _intentSub?.cancel();
    _themeService.removeListener(_onThemeChanged);
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _categoryScrollController.dispose();
    _searchController.dispose();
    _userSearchDebounceTimer?.cancel();
    super.dispose();
  }

  void _initShareIntentListener() {
    // 1. Uygulama açık veya arka plandayken gelen paylaşımları dinle
    _intentSub = ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
        ReceiveSharingIntent.instance.reset();
      }
    }, onError: (err) {
      _log("getIntentSharingTextList Error: $err");
    });

    // 2. Uygulama tamamen kapalıyken paylaşımla açılırsa ilk paylaşımı al
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
        ReceiveSharingIntent.instance.reset();
      }
    }).catchError((err) {
      _log("getInitialMedia Error: $err");
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

  void _startInitialLoadingTimeout() {
    _initialLoadingTimeoutTimer?.cancel();
    _initialLoadingTimedOut = false;
    _initialLoadingTimeoutTimer = Timer(const Duration(seconds: 6), () {
      if (mounted && !_hasServerData) {
        setState(() {
          _initialLoadingTimedOut = true;
        });
      }
    });
  }

  Widget _buildLoadingSkeleton() {
    if (_viewMode == CardViewMode.vertical) {
      return GridView.builder(
        controller: _scrollController,
        padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.61,
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

      // Bildirim kutusu (Notifications Center) için stream
      _unreadNotificationsSubscription?.cancel();
      _unreadNotificationsSubscription = _firestoreService.getUserNotificationsStream(currentUserId).listen(
        (notifications) {
          if (mounted) {
            final unreadCount = notifications.where((n) => n['read'] != true).length;
            setState(() {
              _unreadNotificationCount = unreadCount;
            });
          }
        },
        onError: (err) => _log('⚠️ HomeScreen unread notification count stream error: $err'),
      );
    } catch (e) {
      _log('❌ Okunmamış mesaj/bildirim sayısı yükleme hatası: $e');
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

  Future<void> _loadFollowedKeywords() async {
    try {
      final keywords = await _notificationService.getNotificationKeywords();
      if (mounted) {
        setState(() {
          _followedKeywords = keywords.map((k) => _notificationService.normalizeKeyword(k)).toSet();
        });
      }
    } catch (e) {
      _log('Followed keywords load error: $e');
    }
  }

  Future<void> _toggleKeywordSubscriptionFromSearch(String keyword) async {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;

    final currentUser = _authService.currentUser;
    if (currentUser == null || currentUser.isAnonymous) {
      showGuestLoginBottomSheet(
        context,
        title: 'Kelime Takibi İçin Giriş Yapın',
        message: '"$trimmed" aramasını radara alıp yeni fırsat bildirimleri almak için lütfen üye girişi yapın.',
      );
      return;
    }

    final normalized = _notificationService.normalizeKeyword(trimmed);
    final isFollowed = _followedKeywords.contains(normalized);

    HapticFeedback.mediumImpact();
    setState(() => _isAddingKeywordFromSearch = true);

    try {
      if (isFollowed) {
        await _notificationService.removeKeywordSubscription(trimmed);
        if (mounted) {
          setState(() {
            _followedKeywords.remove(normalized);
            _isAddingKeywordFromSearch = false;
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🗑️ "$trimmed" kelime takibinden çıkarıldı'),
              backgroundColor: const Color(0xFF334155),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      } else {
        await _notificationService.addKeywordSubscription(trimmed);
        _notificationService.requestPermission();
        if (mounted) {
          setState(() {
            _followedKeywords.add(normalized);
            _isAddingKeywordFromSearch = false;
          });
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('🔔 "$trimmed" takibe eklendi! Fırsat geldiğinde bildirim alacaksınız.'),
              backgroundColor: const Color(0xFF16A34A),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              action: SnackBarAction(
                label: 'Yönet',
                textColor: Colors.white,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const KeywordTrackingScreen()),
                  ).then((_) => _loadFollowedKeywords());
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      _log('Kelime takibi toggle hatası: $e');
      if (mounted) {
        setState(() => _isAddingKeywordFromSearch = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kelime takibi güncellenirken bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _toggleGeneralNotification() async {
    final newValue = !_isGeneralNotificationsEnabled;
    try {
      await _notificationService.setGeneralNotifications(newValue);
      if (newValue) {
        _notificationService.requestPermission();
      }
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
        _notificationService.requestPermission();
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
      _activeSearchScope = SearchScope.deals;
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
        _matchedUsers = [];
        _isSearchingUsers = false;
        _userSearchDebounceTimer?.cancel();
      }
    });
  }

  void _onSearchChanged(String value) {
    if (value.startsWith('@') && _activeSearchScope != SearchScope.users) {
      _activeSearchScope = SearchScope.users;
    }

    setState(() {
      _searchQuery = value;
      _displayLimit = 20;
    });

    _userSearchDebounceTimer?.cancel();
    final query = value.replaceFirst('@', '').trim();
    if (query.length >= 2) {
      _userSearchDebounceTimer = Timer(const Duration(milliseconds: 300), () {
        _searchUsers(query);
      });
    } else {
      setState(() {
        _matchedUsers = [];
        _isSearchingUsers = false;
      });
    }
  }

  void _clearSearch() {
    _userSearchDebounceTimer?.cancel();
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _matchedUsers = [];
      _isSearchingUsers = false;
      _displayLimit = 20;
    });
  }

  Future<void> _searchUsers(String rawQuery) async {
    final currentUserId = _authService.currentUser?.uid;
    final normalized = DealSearchEngine.normalizeText(rawQuery);
    if (normalized.isEmpty) return;

    setState(() => _isSearchingUsers = true);
    try {
      final results = <Map<String, dynamic>>[];

      // 1. Botkolik kontrolü
      if ('botkolik'.contains(normalized) || 'bot'.contains(normalized)) {
        results.add({
          'id': 'botkolik',
          'name': 'Botkolik',
          'username': 'botkolik',
          'isBot': true,
          'imageUrl': 'assets/botkolik.webp',
        });
      }

      // 2. Firestore Users koleksiyonundan arama (limit 30)
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(30)
          .get();

      for (final doc in snap.docs) {
        if (doc.id == currentUserId) continue; // Kendini listede arama sonucunda gösterme
        if (doc.id == 'botkolik' && results.any((r) => r['id'] == 'botkolik')) continue;

        final data = doc.data();
        final username = (data['username'] ?? '').toString();
        final displayName = (data['displayName'] ?? '').toString();
        final normUsername = DealSearchEngine.normalizeText(username);
        final normDisplay = DealSearchEngine.normalizeText(displayName);

        if (normUsername.contains(normalized) || normDisplay.contains(normalized)) {
          results.add({
            'id': doc.id,
            'name': displayName.isNotEmpty ? displayName : (username.isNotEmpty ? username : 'Kullanıcı'),
            'username': username.isNotEmpty ? username : (displayName.isNotEmpty ? displayName : 'kullanici'),
            'isBot': false,
            'imageUrl': migrateAssetPath(data['profileImageUrl']?.toString() ?? ''),
            'pinnedBadge': data['pinnedBadge']?.toString(),
          });
        }
      }

      if (mounted) {
        setState(() {
          _matchedUsers = results;
          _isSearchingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearchingUsers = false);
      }
    }
  }

  Widget _buildHomeScreenTab(bool isDark, Color primaryColor) {
    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(
          MediaQuery.of(context).padding.top +
          (_isSearchMode ? 102 : 132),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ─── ARAMA MODU ────────────────────────────────────────
                if (_isSearchMode) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 6, 12, 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 42,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? AppTheme.darkSurface
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _searchQuery.isNotEmpty
                                    ? primaryColor
                                    : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                width: _searchQuery.isNotEmpty ? 1.4 : 1.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _searchQuery.isNotEmpty
                                      ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.1)
                                      : Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: TextField(
                              controller: _searchController,
                              autofocus: true,
                              onChanged: _onSearchChanged,
                              style: TextStyle(
                                color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                                fontSize: 13.5,
                                fontWeight: FontWeight.w600,
                              ),
                              decoration: InputDecoration(
                                hintText: _activeSearchScope == SearchScope.users
                                    ? 'Kullanıcı adı (@kullanıcı) veya isim ara...'
                                    : 'Fırsat, marka, mağaza veya kupon ara...',
                                hintStyle: TextStyle(
                                  color: isDark
                                      ? AppTheme.darkTextSecondary
                                      : const Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: Icon(
                                  Icons.search_rounded,
                                  color: _searchQuery.isNotEmpty
                                      ? primaryColor
                                      : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8)),
                                  size: 19,
                                ),
                                suffixIcon: _searchQuery.isNotEmpty
                                    ? IconButton(
                                        onPressed: _clearSearch,
                                        icon: const Icon(
                                          Icons.cancel_rounded,
                                          size: 18,
                                          color: Color(0xFF94A3B8),
                                        ),
                                        splashRadius: 18,
                                      )
                                    : null,
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 10),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            _toggleSearchMode();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            child: Text(
                              'Vazgeç',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildSearchScopeSelector(isDark, primaryColor),
                ] else ...[
                  // ─── SATIR 1: Wordmark + İkonlar ─────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 6, 12, 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Wordmark
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: 'Fırsat',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: isDark ? Colors.white : const Color(0xFF0F172A),
                                  letterSpacing: -0.8,
                                ),
                              ),
                              TextSpan(
                                text: 'kolik',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primary,
                                  letterSpacing: -0.8,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        // ── İkon grubu: hepsi aynı boyut, aynı stil ──
                        KeyedSubtree(
                          key: _tutorialService.searchBarKey,
                          child: _buildHeaderAction(
                            icon: Icons.search_rounded,
                            onTap: _toggleSearchMode,
                            isDark: isDark,
                          ),
                        ),
                        const SizedBox(width: 6),
                        // Bildirim zili
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            _buildHeaderAction(
                              icon: Icons.notifications_none_rounded,
                              onTap: () {
                                if (_authService.currentUser == null) {
                                  showGuestLoginBottomSheet(
                                    context,
                                    title: 'Bildirimler İçin Giriş Yap! 🔔',
                                    message: 'Kişiselleştirilmiş fırsat bildirimlerinizi görmek ve yönetmek için giriş yapın.',
                                    primaryButtonText: '🚀 Google ile Giriş Yap',
                                  );
                                  return;
                                }
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const AdminNotificationsScreen(),
                                  ),
                                );
                              },
                              isDark: isDark,
                            ),
                            if (_unreadNotificationCount > 0)
                              Positioned(
                                top: -4,
                                right: -4,
                                child: Container(
                                  padding: _unreadNotificationCount < 10
                                      ? const EdgeInsets.all(3)
                                      : const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                                  constraints: BoxConstraints(
                                    minWidth: _unreadNotificationCount < 10 ? 18 : 22,
                                    minHeight: 18,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEF4444),
                                    shape: _unreadNotificationCount < 10 ? BoxShape.circle : BoxShape.rectangle,
                                    borderRadius: _unreadNotificationCount < 10 ? null : BorderRadius.circular(20),
                                    border: Border.all(
                                      color: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
                                      width: 2.0,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      _unreadNotificationCount > 99 ? '99+' : '$_unreadNotificationCount',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w900,
                                        height: 1.0,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_isAdmin) ...[
                          const SizedBox(width: 6),
                          _buildHeaderAction(
                            icon: Icons.settings_rounded,
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AdminScreen()),
                            ),
                            isDark: isDark,
                          ),
                        ],
                      ],
                    ),
                  ),
                  // ─── SATIR 2: Chips (Kataloglar, Kuponlar) + View ────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 12, 6),
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
                                KeyedSubtree(
                                  key: _tutorialService.aktuelChipKey,
                                  child: _buildNavChip(
                                    label: 'Aktüel',
                                    icon: Icons.auto_stories_rounded,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const AktuelMagazalarPage()),
                                    ),
                                    isDark: isDark,
                                  ),
                                ),
                                if (couponsEnabled) ...[
                                  const SizedBox(width: 8),
                                  KeyedSubtree(
                                    key: _tutorialService.kuponlarChipKey,
                                    child: _buildNavChip(
                                      label: 'Kuponlar',
                                      icon: Icons.confirmation_number_outlined,
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                            builder: (_) =>
                                                const KuponlarPage()),
                                      ),
                                      isDark: isDark,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        ),
                        const Spacer(),
                        // Grid / List toggle
                        Container(
                          height: 32,
                          padding: const EdgeInsets.all(2.5),
                          decoration: BoxDecoration(
                            color: isDark
                                ? AppTheme.darkSurface
                                : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildViewToggle(
                                icon: Icons.grid_view_rounded,
                                isSelected: _viewMode == CardViewMode.vertical,
                                onTap: () => _themeService
                                    .setViewMode(CardViewMode.vertical),
                                isDark: isDark,
                              ),
                              _buildViewToggle(
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
                      physics: const BouncingScrollPhysics(),
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: Category.categories.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final category = Category.categories[index];
                        final isSelected =
                            _selectedCategory == category.id &&
                                _selectedSubCategory == null;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCategory = category.id;
                              _selectedSubCategory = null;
                              _displayLimit = 20;
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 7),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppTheme.primary
                                  : (isDark ? AppTheme.darkSurface : Colors.white),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primary
                                    : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.2 : 0.9,
                              ),
                              boxShadow: isSelected
                                  ? [
                                      BoxShadow(
                                        color: AppTheme.primary.withValues(alpha: 0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                                        blurRadius: 4,
                                        offset: const Offset(0, 1),
                                      ),
                                    ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (category.id == 'tumu') ...[
                                  Icon(
                                    Icons.apps_rounded,
                                    size: 14,
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? AppTheme.darkTextSecondary
                                            : const Color(0xFF64748B)),
                                  ),
                                  const SizedBox(width: 6),
                                ] else if (category.icon.isNotEmpty) ...[
                                  Text(
                                    category.icon,
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  category.name,
                                  style: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : (isDark
                                            ? const Color(0xFFE4E4E7)
                                            : const Color(0xFF334155)),
                                    fontWeight: isSelected
                                        ? FontWeight.w800
                                        : FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
            child: (_isSearchMode && _activeSearchScope == SearchScope.users)
                ? _buildDedicatedUserSearchResults(isDark, primaryColor)
                : StreamBuilder<DealsSnapshot>(
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

                // Veri kaynağını kontrol et
                if (snapshot.hasData) {
                  final isFromCache = snapshot.data!.isFromCache;
                  if (!isFromCache) {
                    _hasServerData = true;
                    _initialLoadingTimeoutTimer?.cancel();
                  }
                }

                List<Deal> deals = snapshot.data?.deals ?? [];
                
                // Çevrimiçi isek, sunucu verisi zaten geldiyse ve bu snapshot cache'ten ise,
                // eski cache verisinin araya girip eski fırsatları tekrar göstermemesi için
                // hafızadaki son güncel listeyi (_rawDeals) koruyoruz.
                if (snapshot.hasData && snapshot.data!.isFromCache && _hasServerData && _rawDeals.isNotEmpty && ConnectivityService().isConnected) {
                  deals = _rawDeals;
                } else if (deals.isNotEmpty) {
                  _rawDeals = deals;
                }

                // İlk yükleme durumu (Skeleton Loading):
                // 1) Stream ilk bağlanırken henüz veri gelmemişse, VEYA
                // 2) Henüz sunucu verisi gelmemişken (_hasServerData == false), hafızada/cache'te fırsat yoksa (deals.isEmpty),
                //    internete bağlıysak ve timeout süresi dolmamışsa (!_initialLoadingTimedOut).
                final bool isInitialLoading = (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) ||
                    (!_hasServerData && deals.isEmpty && ConnectivityService().isConnected && !_initialLoadingTimedOut);

                if (isInitialLoading) {
                  return _buildLoadingSkeleton();
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

                // Akıllı Arama Filtresi & Alaka Düzeyi Sıralaması
                if (_searchQuery.trim().isNotEmpty) {
                  filteredDeals = DealSearchEngine.searchDeals(filteredDeals, _searchQuery);
                } else {
                  // Arama yapılmıyorsa Home Feed Skoru (homeFeedScore) ile sıralanır (%85 Tazelik + Alevlenme Bonusu - Troll/FOMO)
                  final List<Deal> sortedDeals = List<Deal>.from(filteredDeals);
                  sortedDeals.sort((a, b) => b.homeFeedScore.compareTo(a.homeFeedScore));
                  filteredDeals = sortedDeals;
                }

                // Pagination için deal'leri güncelle
                _allDeals = filteredDeals;
                _hasMore = filteredDeals.length > _displayLimit;

                if (filteredDeals.isEmpty) {
                  final cleanQuery = _searchQuery.trim();
                  final normalizedQuery = _notificationService.normalizeKeyword(cleanQuery);
                  final isFollowed = _followedKeywords.contains(normalizedQuery);

                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            _searchQuery.isNotEmpty ? Icons.radar_rounded : Icons.inbox_rounded,
                            size: 54,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          _searchQuery.isNotEmpty
                              ? 'Aradığın "$cleanQuery" ile ilgili taze fırsat bulamadık'
                              : 'Henüz fırsat eklenmemiş',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Yeni bir fırsat paylaşıldığında anında bildirim almak ister misin? Radara al, fırsatı ilk sen yakala!'
                                : 'Daha sonra tekrar kontrol edebilirsiniz.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                          if (_searchQuery.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            // Primary Radar CTA Button
                            ElevatedButton.icon(
                              onPressed: _isAddingKeywordFromSearch
                                  ? null
                                  : () => _toggleKeywordSubscriptionFromSearch(cleanQuery),
                              icon: _isAddingKeywordFromSearch
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : Icon(
                                      isFollowed ? Icons.check_circle_rounded : Icons.radar_rounded,
                                      size: 18,
                                    ),
                              label: Text(
                                isFollowed
                                    ? '✅ "$cleanQuery" Radarda (Takip Ediliyor)'
                                    : '🚀 "$cleanQuery" Kelimesini Radara Al',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: isFollowed ? const Color(0xFF16A34A) : primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                elevation: 0,
                              ),
                            ),
                            const SizedBox(height: 14),
                            // Secondary Flow Link to KeywordTrackingScreen
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  'Takip ettiğin kelimeleri ',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                  ),
                                ),
                                InkWell(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const KeywordTrackingScreen()),
                                    ).then((_) => _loadFollowedKeywords());
                                  },
                                  borderRadius: BorderRadius.circular(6),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          'Kelime Takibi',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w800,
                                            color: primaryColor,
                                            decoration: TextDecoration.underline,
                                            decorationColor: primaryColor,
                                          ),
                                        ),
                                        Icon(Icons.arrow_outward_rounded, size: 12, color: primaryColor),
                                      ],
                                    ),
                                  ),
                                ),
                                Text(
                                  ' sayfasından yönetebilirsin.',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: isDark ? Colors.grey[400] : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            // Reset Search Button
                            OutlinedButton.icon(
                              onPressed: _clearSearch,
                              icon: const Icon(Icons.refresh_rounded, size: 16),
                              label: const Text('Aramayı Sıfırla'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: isDark ? Colors.grey[300] : AppTheme.textPrimary,
                                side: BorderSide(
                                  color: isDark ? Colors.white24 : Colors.grey[300]!,
                                ),
                                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                          ],
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
                    _startInitialLoadingTimeout();
                    
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
                  child: Column(
                    children: [
                      if (_searchQuery.trim().isNotEmpty) ...[
                        Container(
                          margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.25),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.search_rounded, color: primaryColor, size: 18),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text.rich(
                                  TextSpan(
                                    text: '"${_searchQuery.trim()}" araması: ',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                      fontSize: 13,
                                    ),
                                    children: [
                                      TextSpan(
                                        text: '${filteredDeals.length} fırsat bulundu',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          color: primaryColor,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _clearSearch,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.close_rounded, size: 13, color: isDark ? Colors.white70 : Colors.black54),
                                      const SizedBox(width: 3),
                                      Text(
                                        'Temizle',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: isDark ? Colors.white70 : Colors.black54,
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
                      Expanded(
                        child: _viewMode == CardViewMode.vertical
                            ? GridView.builder(
                                controller: _scrollController,
                                key: ValueKey('deal_grid_$_selectedCategory'),
                                padding: const EdgeInsets.only(left: 12, right: 12, top: 4),
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 0.61,
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
                                  final cardWidget = DealCard(
                                    deal: deal,
                                    viewMode: CardViewMode.vertical,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DealDetailScreen(dealId: deal.id),
                                      ),
                                    ),
                                  );

                                  return RepaintBoundary(
                                    key: ValueKey('deal_grid_boundary_${deal.id}'),
                                    child: actualIndex == 0
                                        ? Container(
                                            key: _tutorialService.firstDealCardKey,
                                            child: cardWidget,
                                          )
                                        : cardWidget,
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
                                  int passedAds = 0;
                                  for (int i = 0; i < adPositions.length; i++) {
                                    final adPosition = adPositions[i];
                                    if (index == adPosition) {
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
                                  final cardWidget = DealCard(
                                    deal: deal,
                                    viewMode: CardViewMode.horizontal,
                                    onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => DealDetailScreen(dealId: deal.id),
                                      ),
                                    ),
                                  );

                                  return RepaintBoundary(
                                    key: ValueKey('deal_list_boundary_${deal.id}'),
                                    child: actualIndex == 0
                                        ? Container(
                                            key: _tutorialService.firstDealCardKey,
                                            child: cardWidget,
                                          )
                                        : cardWidget,
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: _showScrollToTop
          ? FloatingActionButton.small(
              heroTag: 'scroll_to_top',
              onPressed: () {
                HapticFeedback.lightImpact();
                _scrollToTop();
              },
              backgroundColor: primaryColor,
              elevation: 4,
              child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 20),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return PopScope(
      canPop: !_isSearchMode && _currentTabIndex == 0,
      onPopInvokedWithResult: (bool didPop, dynamic result) {
        if (!didPop) {
          if (_isSearchMode) {
            _toggleSearchMode();
          } else if (_currentTabIndex != 0) {
            setState(() => _currentTabIndex = 0);
          }
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        body: IndexedStack(
          index: _currentTabIndex,
          children: [
            _buildHomeScreenTab(isDark, primaryColor),
            const PopularDealsScreen(isRootTab: true),
            const FavoritesScreen(isRootTab: true),
            const ProfileScreen(isRootTab: true),
          ],
        ),
        bottomNavigationBar: Container(
          decoration: BoxDecoration(
            color: (isDark ? AppTheme.darkSurface : Colors.white).withValues(alpha: isDark ? 0.98 : 0.96),
            border: Border(
              top: BorderSide(
                color: isDark ? const Color(0xFF262626) : const Color(0xFFF1F5F9),
                width: 0.8,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.03),
                blurRadius: 12,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 4),
          child: SafeArea(
            top: false,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // 1. Ana Sayfa (Index 0)
                _buildBottomNavItem(
                  icon: Icons.home_outlined,
                  activeIcon: Icons.home_rounded,
                  label: 'Ana Sayfa',
                  isSelected: _currentTabIndex == 0,
                  onTap: () {
                    if (_currentTabIndex != 0) {
                      setState(() => _currentTabIndex = 0);
                      return;
                    }
                    final now = DateTime.now();
                    _scrollToTop();
                    if (_lastHomeButtonTap != null &&
                        now.difference(_lastHomeButtonTap!) < _doubleTapTimeLimit) {
                      setState(() {
                        _selectedCategory = 'tumu';
                        _selectedSubCategory = null;
                        _displayLimit = 20;
                      });
                      if (_categoryScrollController.hasClients) {
                        _categoryScrollController.animateTo(
                          0,
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOut,
                        );
                      }
                      _lastHomeButtonTap = null;
                    } else {
                      _lastHomeButtonTap = now;
                    }
                  },
                ),
                // 2. Popüler Fırsatlar (Index 1)
                _buildBottomNavItem(
                  targetKey: _tutorialService.bottomNavPopularKey,
                  icon: Icons.whatshot_outlined,
                  activeIcon: Icons.whatshot_rounded,
                  label: 'Popüler',
                  isSelected: _currentTabIndex == 1,
                  onTap: () {
                    setState(() => _currentTabIndex = 1);
                  },
                ),
                // 3. Özel Dairesel Orta Buton (Aksiyon: Fırsat Paylaş - Odak Formu)
                _buildCenterActionButton(
                  targetKey: _tutorialService.bottomNavAddKey,
                  onTap: () {
                    final user = _authService.currentUser;
                    if (user == null) {
                      showGuestLoginBottomSheet(
                        context,
                        title: 'Fırsat Paylaşmak İçin Giriş Yap! 🚀',
                        message: 'Yakaladığın harika fırsatı tüm toplulukla paylaşmak için hızlıca giriş yap.',
                        primaryButtonText: '🚀 Google ile Giriş Yap',
                      );
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const SubmitDealScreen(),
                        fullscreenDialog: true,
                      ),
                    );
                  },
                ),
                // 4. Kaydedilenler (Index 2)
                _buildBottomNavItem(
                  targetKey: _tutorialService.bottomNavSavedKey,
                  icon: Icons.bookmark_outline_rounded,
                  activeIcon: Icons.bookmark_rounded,
                  label: 'Kaydedilenler',
                  isSelected: _currentTabIndex == 2,
                  onTap: () {
                    setState(() => _currentTabIndex = 2);
                  },
                ),
                // 5. Profil (Index 3)
                _buildBottomNavItem(
                  targetKey: _tutorialService.bottomNavProfileKey,
                  icon: Icons.person_outline_rounded,
                  activeIcon: Icons.person_rounded,
                  label: 'Profil',
                  isSelected: _currentTabIndex == 3,
                  badgeCount: _unreadMessageCount + _unreadAdminMessageCount,
                  onTap: () {
                    setState(() => _currentTabIndex = 3);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Minimalist & Ferah Alt Menü Butonu
  Widget _buildBottomNavItem({
    required IconData icon,
    IconData? activeIcon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
    int badgeCount = 0,
    Key? targetKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final inactiveColor = isDark ? const Color(0xFF8E8E93) : const Color(0xFF8E8E93);
    const activeColor = AppTheme.primary;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          key: targetKey,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Icon(
                    isSelected ? (activeIcon ?? icon) : icon,
                    color: isSelected ? activeColor : inactiveColor,
                    size: 24,
                  ),
                  // Sağ üst köşede zarif bildirim göstergesi
                  if (badgeCount > 0)
                    Positioned(
                      right: -3,
                      top: -1,
                      child: Container(
                        width: 7.5,
                        height: 7.5,
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isDark ? AppTheme.darkSurface : Colors.white,
                            width: 1.2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 3.5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                  letterSpacing: -0.1,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Minimalist & Uyumlu Orta Buton (Fırsat Paylaş)
  Widget _buildCenterActionButton({
    required VoidCallback onTap,
    Key? targetKey,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const activeColor = AppTheme.primary;

    return Expanded(
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          onTap();
        },
        splashColor: Colors.transparent,
        highlightColor: Colors.transparent,
        child: Container(
          key: targetKey,
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFFFF7A45), // Canlı Turuncu
                      Color(0xFFFF3D00), // Ateş / Marka Turuncusu
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFFF5722).withValues(alpha: isDark ? 0.35 : 0.25),
                      blurRadius: 6,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(height: 3.5),
              Text(
                'Fırsat Paylaş',
                style: TextStyle(
                  fontSize: 10.0,
                  fontWeight: FontWeight.w700,
                  color: isDark ? const Color(0xFFFF8C5A) : activeColor,
                  letterSpacing: -0.1,
                  height: 1.1,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewToggle({
    required IconData icon,
    required bool isSelected,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: 28,
        height: 26,
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? AppTheme.darkSurfaceElevated : Colors.white)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(7),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Icon(
          icon,
          size: 15,
          color: isSelected
              ? AppTheme.primary
              : (isDark
                  ? const Color(0xFF71717A)
                  : const Color(0xFF94A3B8)),
        ),
      ),
    );
  }

  Widget _buildHeaderAction({
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Icon(
          icon,
          size: 19,
          color: isDark
              ? AppTheme.darkTextPrimary
              : const Color(0xFF0F172A),
        ),
      ),
    );
  }

  Widget _buildNavChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isDark ? AppTheme.darkSurface : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 15,
              color: isDark
                  ? AppTheme.darkTextPrimary
                  : const Color(0xFF0F172A),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isDark
                    ? AppTheme.darkTextPrimary
                    : const Color(0xFF0F172A),
                letterSpacing: -0.2,
              ),
            ),
          ],
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

  Widget _buildSearchScopeSelector(bool isDark, Color primaryColor) {
    final trackBg = isDark ? const Color(0xFF13161C) : const Color(0xFFF1F5F9);
    final trackBorder = isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0);
    final activeTabBg = isDark ? const Color(0xFF252A34) : Colors.white;
    final activeTabBorder = isDark
        ? Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8)
        : Border.all(color: Colors.black.withValues(alpha: 0.04), width: 0.8);
    final isDealsActive = _activeSearchScope == SearchScope.deals;
    final isUsersActive = _activeSearchScope == SearchScope.users;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
      child: Container(
        height: 38,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: trackBg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(
            color: trackBorder,
            width: 0.8,
          ),
        ),
        child: Row(
          children: [
            // ─── Fırsatlar Tab ───
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isDealsActive) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _activeSearchScope = SearchScope.deals;
                    });
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isDealsActive ? activeTabBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isDealsActive ? activeTabBorder : null,
                    boxShadow: isDealsActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.local_offer_rounded,
                        size: 13.5,
                        color: isDealsActive
                            ? primaryColor
                            : (isDark ? const Color(0xFF6E7681) : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 5.5),
                      Text(
                        'Fırsatlar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isDealsActive ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: -0.2,
                          color: isDealsActive
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 4),
            // ─── Kullanıcılar Tab ───
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!isUsersActive) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _activeSearchScope = SearchScope.users;
                    });
                    final query = _searchQuery.replaceFirst('@', '').trim();
                    if (query.length >= 2 && _matchedUsers.isEmpty && !_isSearchingUsers) {
                      _searchUsers(query);
                    }
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: isUsersActive ? activeTabBg : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: isUsersActive ? activeTabBorder : null,
                    boxShadow: isUsersActive
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.people_alt_rounded,
                        size: 13.5,
                        color: isUsersActive
                            ? primaryColor
                            : (isDark ? const Color(0xFF6E7681) : const Color(0xFF94A3B8)),
                      ),
                      const SizedBox(width: 5.5),
                      Text(
                        'Kullanıcılar',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isUsersActive ? FontWeight.w600 : FontWeight.w500,
                          letterSpacing: -0.2,
                          color: isUsersActive
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                        ),
                      ),
                      if (_matchedUsers.isNotEmpty) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1),
                          decoration: BoxDecoration(
                            color: isUsersActive
                                ? primaryColor.withValues(alpha: isDark ? 0.22 : 0.12)
                                : (isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${_matchedUsers.length}',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              color: isUsersActive
                                  ? (isDark ? const Color(0xFFFF9566) : primaryColor)
                                  : (isDark ? const Color(0xFF8B949E) : const Color(0xFF64748B)),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDedicatedUserSearchResults(bool isDark, Color primaryColor) {
    // 1. Arama henüz yapılmadıysa (Arama kutusu boş)
    if (_searchQuery.replaceFirst('@', '').trim().isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  Icons.person_search_rounded,
                  size: 48,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kullanıcı veya Profil Ara',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.white : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'FırsatKolik topluluğundaki kullanıcıları bulmak için arama çubuğuna kullanıcı adı veya isim yazabilirsiniz.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 22),
              // Botkolik Hızlı Öneri Kartı
              Container(
                constraints: const BoxConstraints(maxWidth: 320),
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.lightImpact();
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const BotkolikProfileScreen()),
                      );
                    },
                    borderRadius: BorderRadius.circular(14),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                      child: Row(
                        children: [
                          _buildUserAvatar('assets/botkolik.webp', 'Botkolik', true, primaryColor, 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Botkolik',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? Colors.white : AppTheme.textPrimary,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    _buildBotBadge(),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '@botkolik • Fırsat Asistanı',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: isDark ? Colors.white38 : const Color(0xFF94A3B8),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 2. Arama yapılıyorsa (Loading)
    if (_isSearchingUsers) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: primaryColor,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Kullanıcılar aranıyor...',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 3. Eşleşen kullanıcılar bulunduysa (Results List)
    if (_matchedUsers.isNotEmpty) {
      return ListView.separated(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
        itemCount: _matchedUsers.length + 1,
        separatorBuilder: (_, index) => index == 0 ? const SizedBox.shrink() : const SizedBox(height: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // Sonuç Başlığı
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8.5),
              decoration: BoxDecoration(
                color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: primaryColor.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.people_alt_rounded, color: primaryColor, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        text: '"${_searchQuery.trim()}" araması: ',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                          fontSize: 13,
                        ),
                        children: [
                          TextSpan(
                            text: '${_matchedUsers.length} kullanıcı bulundu',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: primaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _clearSearch,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : Colors.black.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.close_rounded, size: 13, color: isDark ? Colors.white70 : Colors.black54),
                          const SizedBox(width: 3),
                          Text(
                            'Temizle',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          final user = _matchedUsers[index - 1];
          final name = user['name'] as String;
          final username = user['username'] as String;
          final imageUrl = user['imageUrl'] as String;
          final isBot = user['isBot'] == true;
          final pinnedBadge = user['pinnedBadge'] as String?;

          return Container(
            decoration: BoxDecoration(
              color: isDark ? AppTheme.darkSurface : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                width: 0.9,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _navigateToUserProfile(user),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  child: Row(
                    children: [
                      _buildUserAvatar(imageUrl, name, isBot, primaryColor, 22),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                    ),
                                  ),
                                ),
                                if (isBot) ...[
                                  const SizedBox(width: 5),
                                  _buildBotBadge(),
                                ] else if (pinnedBadge != null && pinnedBadge.isNotEmpty) ...[
                                  const SizedBox(width: 5),
                                  _buildPinnedBadge(pinnedBadge),
                                ],
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@$username',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.grey[400] : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'Profili Gör',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: primaryColor,
                              ),
                            ),
                            const SizedBox(width: 3),
                            Icon(Icons.arrow_forward_ios_rounded, size: 10, color: primaryColor),
                          ],
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
    }

    // 4. Eşleşen kullanıcı bulunamadı (Empty state)
    final cleanQuery = _searchQuery.trim();
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: isDark ? 0.15 : 0.08),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                  width: 1.5,
                ),
              ),
              child: Icon(
                Icons.person_off_rounded,
                size: 48,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '"$cleanQuery" adında kullanıcı bulunamadı',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.white : AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Kullanıcı adını veya görünen ismi kontrol ederek tekrar arayabilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : AppTheme.textSecondary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: _clearSearch,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Aramayı Sıfırla'),
              style: OutlinedButton.styleFrom(
                foregroundColor: isDark ? Colors.grey[300] : AppTheme.textPrimary,
                side: BorderSide(
                  color: isDark ? Colors.white24 : Colors.grey[300]!,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(String imageUrl, String name, bool isBot, Color primaryColor, double radius) {
    if (isBot || name.toLowerCase() == 'botkolik') {
      return Container(
        width: radius * 2 + 4,
        height: radius * 2 + 4,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            colors: [Color(0xFF00F0FF), Color(0xFF6366F1), Color(0xFFFF6B35)],
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F0FF).withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        padding: const EdgeInsets.all(1.5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFF0F172A),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/botkolik.webp',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Center(
                child: Icon(Icons.smart_toy_rounded, size: radius, color: const Color(0xFF00F0FF)),
              ),
            ),
          ),
        ),
      );
    }

    if (imageUrl.isNotEmpty) {
      final isAsset = imageUrl.startsWith('assets/');
      return Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: primaryColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: CircleAvatar(
          radius: radius,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          backgroundImage: isAsset
              ? AssetImage(imageUrl) as ImageProvider
              : CachedNetworkImageProvider(imageUrl),
          onBackgroundImageError: (_, __) {},
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: CircleAvatar(
        radius: radius,
        backgroundColor: primaryColor.withValues(alpha: 0.12),
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : 'U',
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w800,
            fontSize: radius * 0.8,
          ),
        ),
      ),
    );
  }

  Widget _buildBotBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: const Text(
        'BOT',
        style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w800, color: Colors.blue),
      ),
    );
  }

  Widget _buildPinnedBadge(String pinnedBadge) {
    final badge = BadgeHelper.getBadgeInfo(pinnedBadge);
    if (badge == null) return const SizedBox.shrink();
    return Icon(badge.iconData, size: 12, color: badge.color);
  }

  void _navigateToUserProfile(Map<String, dynamic> user) {
    HapticFeedback.lightImpact();
    if (user['isBot'] == true) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const BotkolikProfileScreen()),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ProfileScreen(userId: user['id'] as String),
        ),
      );
    }
  }
}
