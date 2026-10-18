import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/deal.dart';
import '../services/firestore_service.dart';
import '../services/deal_service.dart';
import '../services/theme_service.dart';
import '../theme/app_theme.dart';
import '../widgets/deal_card.dart';
import '../widgets/deal_card_skeleton.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../widgets/scroll_to_top_button.dart';
import 'category_preferences_screen.dart';
import 'deal_detail_screen.dart';
import '../services/deal_sync_service.dart';
import '../services/ad_manager_service.dart';
import '../widgets/ad_deal_card.dart';
import '../widgets/app_snack_bar.dart';
import '../widgets/floating_refresh_pill.dart';
import '../services/notification_service.dart';

class FavoritesScreen extends StatefulWidget {
  final bool isRootTab;

  const FavoritesScreen({
    super.key,
    this.isRootTab = false,
  });

  @override
  State<FavoritesScreen> createState() => FavoritesScreenState();
}

class FavoritesScreenState extends State<FavoritesScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  /// Alt navigasyon çubuğundan veya harici tetikleyiciden aktif sekmeyi tepeye fırlatma
  void scrollToTop() {
    final controller = _tabController.index == 0
        ? _myFavoritesScrollController
        : _followedCategoriesScrollController;
    if (controller.hasClients) {
      controller.animateTo(
        0,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
      );
    }
  }
  final FirestoreService _firestoreService = FirestoreService();
  final ThemeService _themeService = ThemeService();
  late TabController _tabController;
  bool _hasNewFollowedDealsPill = false;
  DateTime? _lastFollowedFetchTime;

  // Cached streams to prevent re-listening/recreating on rebuilds
  Stream<List<Deal>>? _myFavoritesStream;
  String? _cachedUserId;
  StreamSubscription? _authSub;
  StreamSubscription<DealSyncEvent>? _dealSyncSubscription;

  // Server-First Single-Flight Hydration State (Followed Categories)
  List<Deal> _followedDealsList = [];
  DocumentSnapshot? _lastFollowedDocument;
  bool _isLoadingFollowed = false;
  bool _isFirstLoadFollowed = true;
  bool _hasMoreFollowed = true;
  String? _followedErrorMessage;
  bool _isRefreshingFollowed = false;
  Future<DealsPageResult>? _activeFollowedServerFuture;
  static const Duration _followedServerTimeout = Duration(milliseconds: 1400);

  // Kategori Takip Durumu Kalkanı (0.1s yapay skeleton/loading jank önleyici)
  bool _hasFollowedCategories = false;
  bool _isFollowedCategoriesResolved = false;

  final Set<String> _locallyDeletedDealIds = {};
  final Set<String> _locallyRemovedFavoriteIds = {};

  int _favoriteFilterIndex = 0; // 0: Tümü, 1: Aktif, 2: Süresi Dolanlar

  late ScrollController _myFavoritesScrollController;
  late ScrollController _followedCategoriesScrollController;
  bool _showBanner = true;
  bool _showCleanupButton = true;
  bool _showScrollToTop = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _myFavoritesScrollController = ScrollController();
    _followedCategoriesScrollController = ScrollController();

    _myFavoritesScrollController.addListener(_scrollListener);
    _followedCategoriesScrollController.addListener(_scrollListener);

    _tabController.addListener(_tabListener);
    _themeService.addListener(_onThemeChanged);
    _listenToDealSync();

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (mounted) {
        _initializeStreams(user?.uid);
        setState(() {});
      }
    });
  }

  void _onThemeChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _scrollListener() {
    double offset = 0;
    if (_tabController.index == 0 && _myFavoritesScrollController.hasClients) {
      offset = _myFavoritesScrollController.offset;
    } else if (_tabController.index == 1 && _followedCategoriesScrollController.hasClients) {
      offset = _followedCategoriesScrollController.offset;
    }

    // 15px scroll sonrası banner ve temizle butonu durum kontrolü
    bool showBannerNow = _showBanner;
    if (offset > 15) {
      showBannerNow = false;
    }
    bool showCleanupNow = offset <= 15;

    // 700px scroll sonrası yukarı fırlatma butonu kontrolü
    bool showScrollToTopNow = offset > ScrollToTopButton.defaultThreshold;

    if (showBannerNow != _showBanner || showCleanupNow != _showCleanupButton || showScrollToTopNow != _showScrollToTop) {
      setState(() {
        _showBanner = showBannerNow;
        _showCleanupButton = showCleanupNow;
        _showScrollToTop = showScrollToTopNow;
      });
    }

    // FS-18: Takip edilen kategoriler sonsuz kaydırma tetikleyicisi
    if (_tabController.index == 1 && _followedCategoriesScrollController.hasClients) {
      if (_followedCategoriesScrollController.offset >=
          _followedCategoriesScrollController.position.maxScrollExtent - 350) {
        _loadMoreFollowed();
      }
    }
  }

  void _tabListener() {
    if (!_tabController.indexIsChanging) {
      HapticFeedback.selectionClick();
      double offset = 0;
      if (_tabController.index == 0 && _myFavoritesScrollController.hasClients) {
        offset = _myFavoritesScrollController.offset;
      } else if (_tabController.index == 1) {
        if (_followedCategoriesScrollController.hasClients) {
          offset = _followedCategoriesScrollController.offset;
        }
        final lastFetch = _lastFollowedFetchTime;
        final isStale = lastFetch != null &&
            DateTime.now().difference(lastFetch) > const Duration(minutes: 30);
        // FS-18 Lansman Standardı: Yalnızca daha önce hiç çekilmediyse (lastFetch == null) veya bayatlamışsa (isStale) çek.
        // Boş kategori listesinde her sekme tıklamasında yapay 0.1s loading/skeleton tetiklenmesini engelle
        if ((lastFetch == null || isStale) && !_isLoadingFollowed) {
          _loadFollowedFirstPage(isRefresh: isStale);
        }
      }

      setState(() {
        _showBanner = true;
        _showCleanupButton = offset <= 15;
        _showScrollToTop = offset > ScrollToTopButton.defaultThreshold;
      });
    }
  }

  void _initializeStreams(String? userId) {
    if (userId == null) {
      _myFavoritesStream = null;
      _cachedUserId = null;
      _followedDealsList = [];
      _lastFollowedDocument = null;
      _hasFollowedCategories = false;
      _isFollowedCategoriesResolved = false;
      return;
    }
    if (_cachedUserId != userId) {
      _cachedUserId = userId;
      _myFavoritesStream = _firestoreService.getFavoriteDeals(userId);

      // Kategori takip durumu senkron bellek veya disk kalkanından anında çözülür
      final syncHasCats = NotificationService().getCachedHasFollowedCategoriesSync(userId);
      if (syncHasCats != null) {
        _hasFollowedCategories = syncHasCats;
        _isFollowedCategoriesResolved = true;
      } else {
        NotificationService().hasFollowedCategories(userId).then((hasCats) {
          if (mounted && _cachedUserId == userId) {
            setState(() {
              _hasFollowedCategories = hasCats;
              _isFollowedCategoriesResolved = true;
            });
          }
        }).catchError((_) {});
      }

      _loadFollowedFirstPage();
    }
  }

  /// Server-First Single-Flight Hydration (Favori Kategorilerim)
  /// Lansman Kalite Standardı: İlk açılışta doğrudan sunucudan (Source.server) taze veri çeker.
  /// 1400ms içinde sunucu dönerse 0 jank, 0 reload ile en güncel kategori fırsatlarını gösterir.
  /// Ağ yavaşsa veya kesildiyse anında yerel SQLite cache kalkanına döner (Resilient Cache Fallback).
  /// Arka planda tamamlanan sunucu isteği kullanıcı scroll pozisyonuna saygı duyarak listeyi günceller.
  Future<void> _loadFollowedFirstPage({bool isRefresh = false}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || !mounted) return;

    if (isRefresh) {
      if (_isRefreshingFollowed) return;
      _isRefreshingFollowed = true;
    } else {
      if (_activeFollowedServerFuture != null) return;
      if (_isLoadingFollowed && _followedDealsList.isNotEmpty) return;
    }

    setState(() {
      _isLoadingFollowed = true;
      _followedErrorMessage = null;
    });

    try {
      // 1. Pull-to-Refresh: Kullanıcı manuel aşağı çektiğinde doğrudan sunucudan al
      if (isRefresh) {
        final serverResult = await _firestoreService.getFollowedCategoriesDealsPaginated(
          userId: user.uid,
          limit: 45,
          source: Source.server,
        );

        if (mounted) {
          if (!serverResult.isError) {
            setState(() {
              _followedDealsList = serverResult.deals;
              _lastFollowedDocument = serverResult.lastDocument;
              _hasMoreFollowed = serverResult.hasMore;
              _isLoadingFollowed = false;
              _isFirstLoadFollowed = false;
              _followedErrorMessage = null;
              _hasNewFollowedDealsPill = false;
              _lastFollowedFetchTime = DateTime.now();
              _hasFollowedCategories = serverResult.hasFollowedCategories;
              _isFollowedCategoriesResolved = true;
            });
          } else {
            if (_followedDealsList.isEmpty) {
              setState(() {
                _followedErrorMessage = serverResult.errorMessage ?? 'Fırsatlar yüklenemedi';
                _isLoadingFollowed = false;
                _isFirstLoadFollowed = false;
              });
            }
          }
        }
        return;
      }

      // 2. İlk Yükleme: Server-First (Single-Flight Future)
      final serverFuture = _firestoreService.getFollowedCategoriesDealsPaginated(
        userId: user.uid,
        limit: 45,
        source: Source.server,
      );
      _activeFollowedServerFuture = serverFuture;
      serverFuture.whenComplete(() {
        if (_activeFollowedServerFuture == serverFuture) {
          _activeFollowedServerFuture = null;
        }
      });

      bool serverLoaded = false;
      try {
        final serverResult = await serverFuture.timeout(_followedServerTimeout);
        if (mounted && !serverResult.isError) {
          serverLoaded = true;
          setState(() {
            _followedDealsList = serverResult.deals;
            _lastFollowedDocument = serverResult.lastDocument;
            _hasMoreFollowed = serverResult.hasMore;
            _isLoadingFollowed = false;
            _isFirstLoadFollowed = false;
            _followedErrorMessage = null;
            _hasNewFollowedDealsPill = false;
            _lastFollowedFetchTime = DateTime.now();
            _hasFollowedCategories = serverResult.hasFollowedCategories;
            _isFollowedCategoriesResolved = true;
          });
        }
      } catch (e) {
        // Ağ gecikmesi veya bağlantı hatası: Cache Fallback devreye girer
      }

      // 3. Resilient Cache Fallback (Yavaş ağ / çevrimdışı kalkanı)
      if (!serverLoaded && mounted) {
        bool cacheLoaded = false;
        try {
          final cacheResult = await _firestoreService.getFollowedCategoriesDealsPaginated(
            userId: user.uid,
            limit: 45,
            source: Source.cache,
          );
          if (mounted && cacheResult.deals.isNotEmpty) {
            cacheLoaded = true;
            setState(() {
              _followedDealsList = cacheResult.deals;
              _lastFollowedDocument = cacheResult.lastDocument;
              _hasMoreFollowed = cacheResult.hasMore;
              _isLoadingFollowed = false;
              _isFirstLoadFollowed = false;
              _hasFollowedCategories = cacheResult.hasFollowedCategories;
              _isFollowedCategoriesResolved = true;
            });
          }
        } catch (_) {}

        // Eğer cache boşsa ve sunucu henüz dönmediyse, serverFuture'ı bekle
        if (!cacheLoaded && _followedDealsList.isEmpty && mounted) {
          serverFuture.then((res) {
            if (mounted) {
              if (res.isError && _followedDealsList.isEmpty) {
                setState(() {
                  _isLoadingFollowed = false;
                  _isFirstLoadFollowed = false;
                  _followedErrorMessage = res.errorMessage ?? 'Fırsatlar yüklenemedi';
                });
              } else {
                setState(() {
                  _followedDealsList = res.deals;
                  _lastFollowedDocument = res.lastDocument;
                  _hasMoreFollowed = res.hasMore;
                  _isLoadingFollowed = false;
                  _isFirstLoadFollowed = false;
                  _followedErrorMessage = null;
                  _lastFollowedFetchTime = DateTime.now();
                  _hasFollowedCategories = res.hasFollowedCategories;
                  _isFollowedCategoriesResolved = true;
                });
              }
            }
          }).catchError((err) {
            if (mounted && _followedDealsList.isEmpty) {
              setState(() {
                _isLoadingFollowed = false;
                _isFirstLoadFollowed = false;
                _followedErrorMessage = 'Fırsatlar yüklenemedi';
              });
            }
          });
        } else {
          // Önbellekten veri basıldıysa, arka planda tamamlanacak serverFuture'ı dinle (Scroll-Aware)
          _attachBackgroundFollowedServerListener(serverFuture);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingFollowed = false;
          _isFirstLoadFollowed = false;
          if (_followedDealsList.isEmpty) {
            _followedErrorMessage = 'Fırsatlar yüklenemedi';
          }
        });
      }
    } finally {
      _isRefreshingFollowed = false;
    }
  }

  /// Arka planda sunucu tamamlandığında scroll durumuna göre listeyi pürüzsüz günceller
  void _attachBackgroundFollowedServerListener(Future<DealsPageResult> serverFuture) {
    serverFuture.then((res) {
      if (!mounted) return;
      if (res.isError || res.deals.isEmpty) return;

      // Kullanıcı listenin başındaysa pürüzsüzce güncelle
      final isAtTop = !_followedCategoriesScrollController.hasClients ||
          _followedCategoriesScrollController.offset <= 120;
      if (isAtTop) {
        setState(() {
          _followedDealsList = res.deals;
          _lastFollowedDocument = res.lastDocument;
          _hasMoreFollowed = res.hasMore;
          _isLoadingFollowed = false;
          _isFirstLoadFollowed = false;
          _hasNewFollowedDealsPill = false;
          _lastFollowedFetchTime = DateTime.now();
          _hasFollowedCategories = res.hasFollowedCategories;
          _isFollowedCategoriesResolved = true;
        });
      } else {
        // Kullanıcı aşağı kaydırmışsa liste sırasını zıplatma, floating pill ile kullanıcı iradesine sun
        setState(() {
          _lastFollowedDocument = res.lastDocument ?? _lastFollowedDocument;
          _hasMoreFollowed = res.hasMore;
          _hasNewFollowedDealsPill = true;
          _lastFollowedFetchTime = DateTime.now();
        });
      }
    }).catchError((_) {
      // Sessizce yoksay; yerel önbellek zaten ekranda
    });
  }

  /// FS-18: Sonsuz kaydırma - Takip edilen kategoriler sonraki sayfa
  Future<void> _loadMoreFollowed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _isLoadingFollowed || !_hasMoreFollowed || _lastFollowedDocument == null || !mounted) return;

    setState(() {
      _isLoadingFollowed = true;
    });

    try {
      final result = await _firestoreService.getFollowedCategoriesDealsPaginated(
        userId: user.uid,
        limit: 30,
        lastDocument: _lastFollowedDocument,
        source: Source.serverAndCache,
      );

      if (mounted) {
        if (!result.isError) {
          final existingIds = _followedDealsList.map((d) => d.id).toSet();
          final newDeals = result.deals.where((d) => !existingIds.contains(d.id)).toList();

          setState(() {
            _followedDealsList.addAll(newDeals);
            _lastFollowedDocument = result.lastDocument;
            _hasMoreFollowed = result.hasMore && result.lastDocument != null;
            _isLoadingFollowed = false;
          });
        } else {
          setState(() {
            _isLoadingFollowed = false;
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingFollowed = false;
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dealSyncSubscription?.cancel();
    _authSub?.cancel();
    _themeService.removeListener(_onThemeChanged);
    _tabController.removeListener(_tabListener);
    _tabController.dispose();
    _myFavoritesScrollController.removeListener(_scrollListener);
    _myFavoritesScrollController.dispose();
    _followedCategoriesScrollController.removeListener(_scrollListener);
    _followedCategoriesScrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _tabController.index == 1) {
      final lastFetch = _lastFollowedFetchTime;
      // 30 dakikadan uzun süre arka planda kalındıysa
      if (lastFetch != null && DateTime.now().difference(lastFetch) > const Duration(minutes: 30)) {
        if (!mounted) return;
        final isAtTop = !_followedCategoriesScrollController.hasClients ||
            _followedCategoriesScrollController.offset <= 120;
        if (isAtTop) {
          _loadFollowedFirstPage(isRefresh: true);
        } else {
          setState(() {
            _hasNewFollowedDealsPill = true;
          });
        }
      }
    }
  }

  /// FS-18 Kalkanı: İstemci içi reaktif senkronizasyon dinleyicisi
  void _listenToDealSync() {
    _dealSyncSubscription?.cancel();
    _dealSyncSubscription = DealSyncService.instance.stream.listen((event) {
      if (!mounted) return;
      if (event.action == DealSyncAction.dealDeleted) {
        _locallyDeletedDealIds.add(event.dealId);
      } else if (event.action == DealSyncAction.favoriteToggled) {
        if (event.isFavorite == false) {
          _locallyRemovedFavoriteIds.add(event.dealId);
        } else {
          _locallyRemovedFavoriteIds.remove(event.dealId);
        }
      }

      final index = _followedDealsList.indexWhere((d) => d.id == event.dealId);
      if (index != -1) {
        setState(() {
          if (event.action == DealSyncAction.dealDeleted) {
            _followedDealsList.removeAt(index);
          } else {
            _followedDealsList[index] = event.applyTo(_followedDealsList[index]);
          }
        });
      } else {
        setState(() {});
      }
    });
  }

  /// Fırsat detayına gidiş ve güvenli çift katmanlı senkronizasyon köprüsü
  Future<void> _openDealDetail(BuildContext context, Deal deal) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DealDetailScreen(dealId: deal.id),
      ),
    );
    if (result is Deal && mounted) {
      DealSyncService.instance.notifyDealUpdated(result);
    }
  }

  void _showCustomSnackBar({
    required String message,
    required IconData icon,
    required Color backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (!mounted) return;

    AppSnackBar.show(
      context: context,
      message: message,
      icon: icon,
      backgroundColor: backgroundColor,
      duration: duration,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);
    final currentUser = FirebaseAuth.instance.currentUser;

    _initializeStreams(currentUser?.uid);

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isRootTab,
        backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF8FAFC),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Kaydedilenler',
          style: TextStyle(
            color: textColor,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        iconTheme: IconThemeData(
          color: textColor,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Container(
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                  width: 1.0,
                ),
              ),
            ),
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                final isFirst = _tabController.index == 0;
                return TabBar(
                  controller: _tabController,
                  indicatorColor: AppTheme.primary,
                  indicatorWeight: 3,
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                  unselectedLabelColor: secondaryTextColor,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  tabs: [
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.bookmark_rounded,
                            size: 16,
                            color: isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Kaydettiklerim',
                            style: TextStyle(
                              color: isFirst
                                  ? (isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A))
                                  : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                              fontWeight: isFirst ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Tab(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.category_rounded,
                            size: 16,
                            color: !isFirst
                                ? AppTheme.primary
                                : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Favori Kategorilerim',
                            style: TextStyle(
                              color: !isFirst
                                  ? (isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A))
                                  : (isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B)),
                              fontWeight: !isFirst ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // 1. Kaydettiklerim Tab
          _buildMyFavorites(currentUser, isDark),
          // 2. Favori Kategorilerim Tab
          _buildFollowedCategories(currentUser, isDark),
        ],
      ),
      floatingActionButton: ScrollToTopButton(
        isVisible: _showScrollToTop,
        onPressed: () {
          final controller = _tabController.index == 0
              ? _myFavoritesScrollController
              : _followedCategoriesScrollController;
          if (controller.hasClients) {
            controller.animateTo(
              0,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeOutCubic,
            );
          }
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildMyFavorites(User? currentUser, bool isDark) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.bookmark_border_rounded,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Kaydedilenler İçin Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kaydettiğiniz fırsatları görmek ve listenize yeni fırsatlar eklemek için giriş yapmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showGuestLoginBottomSheet(
                    context,
                    title: 'Fırsatları Kaydetmek İçin Giriş Yap! 🔖',
                    message: 'Beğendiğin fırsatları arşivine eklemek ve dilediğin zaman ulaşmak için hızlıca giriş yap.',
                    primaryButtonText: '🚀 Google ile Giriş Yap',
                    onLoginSuccess: () => setState(() {}),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Giriş Yap',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  elevation: 2,
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

    return StreamBuilder<List<Deal>>(
      stream: _myFavoritesStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingGrid(isDark);
        }

        if (snapshot.hasError) {
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              setState(() {
                _myFavoritesStream = _firestoreService.getFavoriteDeals(currentUser.uid);
              });
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 56,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Bir hata oluştu',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: () {
                              HapticFeedback.lightImpact();
                              setState(() {
                                _myFavoritesStream = _firestoreService.getFavoriteDeals(currentUser.uid);
                              });
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 18),
                            label: const Text('Tekrar Dene'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final rawDeals = snapshot.data ?? [];
        final deals = rawDeals
            .where((d) => !_locallyDeletedDealIds.contains(d.id) && !_locallyRemovedFavoriteIds.contains(d.id))
            .toList();

        if (deals.isEmpty) {
          return RefreshIndicator(
            color: AppTheme.primary,
            onRefresh: () async {
              HapticFeedback.lightImpact();
              setState(() {
                _myFavoritesStream = _firestoreService.getFavoriteDeals(currentUser.uid);
              });
            },
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 68,
                            height: 68,
                            decoration: BoxDecoration(
                              color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.bookmark_border_rounded,
                              size: 34,
                              color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Henüz kaydettiğiniz fırsat yok',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Kaydettiğiniz fırsatlar burada düzenli olarak listelenir',
                            style: TextStyle(
                              fontSize: 13,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          );
        }

        final totalCount = deals.length;
        final activeDeals = deals.where((d) => !d.isArchived).toList();
        final expiredDeals = deals.where((d) => d.isArchived).toList();
        final activeCount = activeDeals.length;
        final expiredCount = expiredDeals.length;

        List<Deal> displayedDeals = deals;
        if (_favoriteFilterIndex == 1) {
          displayedDeals = activeDeals;
        } else if (_favoriteFilterIndex == 2) {
          displayedDeals = expiredDeals;
        }

        return Column(
          children: [
            // 30 gün bilgilendirme mesajı
            AnimatedCrossFade(
              firstChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 2),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7.5),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                      width: 1.0,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.025),
                        blurRadius: 4,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 14.5,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          '30 günden eski fırsatlar otomatik olarak listeden kaldırılır.',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              secondChild: const SizedBox.shrink(),
              crossFadeState: _showBanner ? CrossFadeState.showFirst : CrossFadeState.showSecond,
              duration: const Duration(milliseconds: 200),
            ),

            // Filtre Çipleri & Temizle Barı
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Tümü ($totalCount)',
                      icon: Icons.grid_view_rounded,
                      isSelected: _favoriteFilterIndex == 0,
                      isDark: isDark,
                      selectedColor: AppTheme.primary,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _favoriteFilterIndex = 0);
                      },
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: _buildFilterChip(
                      label: 'Aktif ($activeCount)',
                      icon: Icons.local_fire_department_rounded,
                      isSelected: _favoriteFilterIndex == 1,
                      isDark: isDark,
                      selectedColor: const Color(0xFF10B981),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _favoriteFilterIndex = 1);
                      },
                    ),
                  ),
                  if (expiredCount > 0) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      child: _buildFilterChip(
                        label: 'Süresi Dolan ($expiredCount)',
                        icon: Icons.hourglass_bottom_rounded,
                        isSelected: _favoriteFilterIndex == 2,
                        isDark: isDark,
                        selectedColor: const Color(0xFFEF4444),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _favoriteFilterIndex = 2);
                        },
                      ),
                    ),
                  ],

                  // Temizle Butonu
                  if (totalCount > 0) ...[
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _showClearFavoritesBottomSheet(
                            context,
                            currentUser,
                            deals,
                            expiredDeals,
                            isDark,
                          );
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7.5),
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
                              const Icon(
                                Icons.auto_delete_outlined,
                                color: Color(0xFFDC2626),
                                size: 14,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Temizle',
                                style: TextStyle(
                                  color: isDark ? const Color(0xFFF87171) : const Color(0xFFDC2626),
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11.5,
                                  letterSpacing: -0.2,
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
            ),

            Expanded(
              child: displayedDeals.isEmpty
                  ? _buildEmptyFilteredState(isDark)
                  : _buildDealGrid(displayedDeals, isDark, _myFavoritesScrollController),
            ),
          ],
        );
      },
    );
  }

  Widget _buildFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required bool isDark,
    required Color selectedColor,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF1E293B);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7.5),
          decoration: BoxDecoration(
            color: isSelected
                ? selectedColor
                : (isDark ? AppTheme.darkSurface : Colors.white),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected
                  ? selectedColor
                  : (isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0)),
              width: 1.0,
            ),
            boxShadow: [
              if (!isSelected)
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? Colors.white : secondaryTextColor,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                      letterSpacing: -0.2,
                      color: isSelected ? Colors.white : textColor,
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

  void _showClearFavoritesBottomSheet(
    BuildContext context,
    User currentUser,
    List<Deal> allDeals,
    List<Deal> expiredDeals,
    bool isDark,
  ) {
    final totalCount = allDeals.length;
    final expiredCount = expiredDeals.length;
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bottomSheetContext) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutamaç Çizgisi
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Başlık & Açıklama
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: isDark ? 0.2 : 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.auto_delete_rounded,
                        color: Color(0xFFEF4444),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kayıtları Temizle',
                            style: TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w800,
                              color: textColor,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Listenizden kaldırmak istediğiniz seçeneği belirleyin',
                            style: TextStyle(
                              fontSize: 12,
                              color: secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Seçenek 1: Süresi Dolanları Temizle (Varsa)
                if (expiredCount > 0) ...[
                  _buildClearOptionTile(
                    title: 'Süresi Dolanları Temizle ($expiredCount İlan)',
                    subtitle: 'Yalnızca süresi dolmuş fırsatları kaldırır. Aktif fırsatlarınız korunur.',
                    icon: Icons.hourglass_bottom_rounded,
                    iconColor: const Color(0xFFF59E0B),
                    isDark: isDark,
                    onTap: () async {
                      Navigator.pop(bottomSheetContext);
                      for (var d in expiredDeals) {
                        await _firestoreService.removeFromFavorites(currentUser.uid, d.id);
                      }
                      if (mounted) {
                        setState(() {
                          if (_favoriteFilterIndex == 2) {
                            _favoriteFilterIndex = 0;
                          }
                        });
                        _showCustomSnackBar(
                          message: '$expiredCount adet süresi dolan kayıt temizlendi',
                          icon: Icons.check_circle_rounded,
                          backgroundColor: const Color(0xFF10B981),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                ],

                // Seçenek 2: Tümünü Temizle
                _buildClearOptionTile(
                  title: 'Tüm Kayıtları Temizle ($totalCount İlan)',
                  subtitle: 'Aktif ve süresi dolan tüm kayıtlı fırsatları listenizden kalıcı olarak siler.',
                  icon: Icons.delete_forever_rounded,
                  iconColor: const Color(0xFFEF4444),
                  isDark: isDark,
                  onTap: () async {
                    Navigator.pop(bottomSheetContext);
                    for (var d in allDeals) {
                      await _firestoreService.removeFromFavorites(currentUser.uid, d.id);
                    }
                    if (mounted) {
                      setState(() {
                        _favoriteFilterIndex = 0;
                      });
                      _showCustomSnackBar(
                        message: '$totalCount adet kayıtlı fırsat temizlendi',
                        icon: Icons.delete_sweep_rounded,
                        backgroundColor: const Color(0xFFEF4444),
                      );
                    }
                  },
                ),
                const SizedBox(height: 14),

                // İptal Butonu
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(bottomSheetContext),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(
                        color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
                        width: 1.0,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Vazgeç',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearOptionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: isDark ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 2.5),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 17,
                color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyFilteredState(bool isDark) {
    String title = 'Fırsat Bulunamadı';
    String message = 'Bu filtreye uygun kayıtlı fırsatınız bulunmuyor.';
    IconData icon = Icons.inbox_rounded;

    if (_favoriteFilterIndex == 1) {
      title = 'Aktif Fırsat Bulunmuyor';
      message = 'Kaydettiğiniz tüm fırsatların süresi dolmuş. \'Süresi Dolanlar\' filtresinden inceleyebilirsiniz.';
      icon = Icons.hourglass_bottom_rounded;
    } else if (_favoriteFilterIndex == 2) {
      title = 'Süresi Dolan Fırsat Yok 🎉';
      message = 'Kaydettiğiniz tüm fırsatlar hala güncel ve aktif!';
      icon = Icons.check_circle_outline_rounded;
    }

    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        HapticFeedback.lightImpact();
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          setState(() {
            _myFavoritesStream = _firestoreService.getFavoriteDeals(currentUser.uid);
          });
        }
      },
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 52, color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF94A3B8)),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _favoriteFilterIndex = 0);
                      },
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Tüm Kayıtları Göster'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.primary,
                        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDealGrid(List<Deal> deals, bool isDark, ScrollController scrollController) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () async {
        final currentUser = FirebaseAuth.instance.currentUser;
        if (currentUser != null) {
          setState(() {
            _myFavoritesStream = _firestoreService.getFavoriteDeals(currentUser.uid);
          });
          await _loadFollowedFirstPage(isRefresh: true);
        }
      },
      child: GridView.builder(
        controller: scrollController,
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.635,
          crossAxisSpacing: 12,
          mainAxisSpacing: 11,
        ),
        itemCount: deals.length,
        itemBuilder: (context, index) {
          final deal = deals[index];
          return RepaintBoundary(
            key: ValueKey('fav_deal_boundary_${deal.id}'),
            child: DealCard(
              key: ValueKey('fav_deal_${deal.id}_v'),
              deal: deal,
              viewMode: CardViewMode.vertical,
              onTap: () {
                HapticFeedback.lightImpact();
                _openDealDetail(context, deal);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildFollowedCategories(User? currentUser, bool isDark) {
    final textColor = isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A);
    final secondaryTextColor = isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B);

    if (currentUser == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: isDark ? 0.2 : 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.category_outlined,
                  size: 36,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Favori Kategoriler İçin Giriş Yap',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Takip ettiğiniz özel kategorilerin anlık fırsat akışını görmek için giriş yapmalısınız.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showGuestLoginBottomSheet(
                    context,
                    title: 'Kategorileri Takip Etmek İçin Giriş Yap! 🏷️',
                    message: 'İlgilendiğin kategorileri takibe almak ve özel akışını oluşturmak için giriş yap.',
                    primaryButtonText: '🚀 Google ile Giriş Yap',
                    onLoginSuccess: () => setState(() {}),
                  );
                },
                icon: const Icon(Icons.login_rounded, size: 18),
                label: const Text(
                  'Giriş Yap',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
                  elevation: 2,
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

    // FS-18 Lansman Standardı: Kullanıcının takip ettiği kategori yoksa
    // 0.1 saniyelik yapay skeleton loading göstermeden doğrudan temiz boş durum sun
    if (_isFollowedCategoriesResolved && !_hasFollowedCategories) {
      return _buildFollowedCategoriesEmptyState(currentUser, isDark, textColor, secondaryTextColor);
    }

    // Takip edilen kategoriler varsa ve ilk kez yükleniyorsa skeleton ızgara göster
    if ((_isFirstLoadFollowed || (_isLoadingFollowed && !_isRefreshingFollowed)) && _followedDealsList.isEmpty) {
      return _buildLoadingGrid(isDark);
    }

    if (_followedErrorMessage != null && _followedDealsList.isEmpty) {
      return RefreshIndicator(
        color: AppTheme.primary,
        onRefresh: () => _loadFollowedFirstPage(isRefresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline_rounded,
                        size: 56,
                        color: isDark ? Colors.grey[600] : Colors.grey[400],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        _followedErrorMessage ?? 'Bir hata oluştu',
                        style: TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w800,
                          color: textColor,
                        ),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          _loadFollowedFirstPage();
                        },
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: const Text(
                          'Tekrar Dene',
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final deals = _followedDealsList;

    if (deals.isEmpty) {
      return _buildFollowedCategoriesEmptyState(currentUser, isDark, textColor, secondaryTextColor);
    }

    return Column(
      children: [
        AnimatedCrossFade(
          firstChild: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.local_offer_outlined,
                      size: 16,
                      color: secondaryTextColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${deals.length} Fırsat',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: secondaryTextColor,
                      ),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const CategoryPreferencesScreen(),
                      ),
                    ).then((_) async {
                      final hasCats = await NotificationService().hasFollowedCategories(currentUser.uid);
                      if (mounted) {
                        setState(() {
                          _hasFollowedCategories = hasCats;
                          _isFollowedCategoriesResolved = true;
                        });
                      }
                      _loadFollowedFirstPage(isRefresh: true);
                    });
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5.5),
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
                          Icons.tune_rounded,
                          size: 14,
                          color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          'Kategorileri Düzenle',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppTheme.darkTextPrimary : const Color(0xFF0F172A),
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          secondChild: const SizedBox.shrink(),
          crossFadeState: _showCleanupButton ? CrossFadeState.showFirst : CrossFadeState.showSecond,
          duration: const Duration(milliseconds: 200),
        ),
        Expanded(
          child: Stack(
            children: [
              _buildFollowedCategoriesDealGrid(deals, isDark, _followedCategoriesScrollController),
              Positioned(
                top: 10,
                left: 0,
                right: 0,
                child: FloatingRefreshPill(
                  isVisible: _hasNewFollowedDealsPill,
                  text: '🏷️ Yeni Kategori Fırsatları Var 👆',
                  icon: Icons.category_rounded,
                  primaryColor: AppTheme.primary,
                  onTap: () {
                    if (_followedCategoriesScrollController.hasClients) {
                      _followedCategoriesScrollController.animateTo(
                        0,
                        duration: const Duration(milliseconds: 400),
                        curve: Curves.easeOutCubic,
                      );
                    }
                    setState(() {
                      _hasNewFollowedDealsPill = false;
                    });
                    _loadFollowedFirstPage(isRefresh: true);
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Favori Kategorilerim (Takip Edilenler) sekmesi için AdMob destekli dinamik Grid.
  /// Anasayfa ve Popüler Fırsatlar ile birebir aynı mimaride:
  /// 2 sütunlu ürün grid'i her [chunkSize] üründe bir bölünerek araya tam genişlikte
  /// 124dp yatay Native Reklam kartı (TemplateType.small) yerleştirilir.
  /// Reklam kapalıysa veya eşiğin altındaysa temiz ızgara (_buildDealGrid) kullanılır.
  Widget _buildFollowedCategoriesDealGrid(
    List<Deal> deals,
    bool isDark,
    ScrollController scrollController,
  ) {
    return ListenableBuilder(
      listenable: AdManagerService.instance,
      builder: (context, _) {
        final adManager = AdManagerService.instance;
        final bool isAdEnabled = adManager.isAdsEnabled &&
            adManager.nativeEnabled &&
            adManager.nativeFollowedCategoriesEnabled;
        final int chunkSize = (adManager.nativeFollowedCategoriesInterval >= 4 &&
                adManager.nativeFollowedCategoriesInterval <= 20)
            ? adManager.nativeFollowedCategoriesInterval
            : 6;

        // Eşik koruması: Reklam kapalıysa veya ilan sayısı chunk boyutundan azsa standart temiz grid göster
        if (!isAdEnabled || deals.length < chunkSize) {
          return _buildDealGrid(deals, isDark, scrollController);
        }

        final int totalChunks = (deals.length / chunkSize).ceil();
        final List<Widget> slivers = [];

        for (int chunkIndex = 0; chunkIndex < totalChunks; chunkIndex++) {
          final startIndex = chunkIndex * chunkSize;
          final endIndex = (startIndex + chunkSize > deals.length)
              ? deals.length
              : startIndex + chunkSize;
          final chunkDeals = deals.sublist(startIndex, endIndex);
          final isLastChunk = chunkIndex == totalChunks - 1;

          // 1. Ürün Grid Bölümü (2 Sütunlu)
          slivers.add(
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                16,
                chunkIndex == 0 ? 12 : 6,
                16,
                (isLastChunk && chunkDeals.length < chunkSize) ? 24 : 6,
              ),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.635,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 11,
                ),
                delegate: SliverChildBuilderDelegate(
                  (ctx, idx) {
                    final deal = chunkDeals[idx];
                    return RepaintBoundary(
                      key: ValueKey('fav_cat_deal_grid_boundary_${deal.id}'),
                      child: DealCard(
                        key: ValueKey('fav_cat_deal_${deal.id}_v'),
                        deal: deal,
                        viewMode: CardViewMode.vertical,
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _openDealDetail(ctx, deal);
                        },
                      ),
                    );
                  },
                  childCount: chunkDeals.length,
                  addAutomaticKeepAlives: false,
                  addRepaintBoundaries: true,
                  addSemanticIndexes: false,
                ),
              ),
            ),
          );

          // 2. Tam Genişlikte Yatay Native Reklam (Her chunkSize üründen sonra)
          if (chunkDeals.length == chunkSize) {
            slivers.add(
              SliverPadding(
                padding: EdgeInsets.fromLTRB(16, 6, 16, isLastChunk ? 24 : 6),
                sliver: SliverToBoxAdapter(
                  child: AdDealCard(
                    key: ValueKey('ad_card_fav_cat_grid_$chunkIndex'),
                    viewMode: CardViewMode.horizontal,
                    placement: 'favorite_categories',
                  ),
                ),
              ),
            );
          }
        }

        if (_isLoadingFollowed && !_isFirstLoadFollowed) {
          slivers.add(
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: SizedBox(
                    width: 26,
                    height: 26,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          slivers.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () => _loadFollowedFirstPage(isRefresh: true),
          child: CustomScrollView(
            controller: scrollController,
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: slivers,
          ),
        );
      },
    );
  }

  Widget _buildLoadingGrid(bool isDark) {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.635,
        crossAxisSpacing: 12,
        mainAxisSpacing: 11,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return const DealCardSkeleton(viewMode: CardViewMode.vertical);
      },
    );
  }

  /// Favori Kategorilerim sekmesi için temiz, sıfır jank ve sıfır gecikmeli boş durum arayüzü
  Widget _buildFollowedCategoriesEmptyState(
    User currentUser,
    bool isDark,
    Color textColor,
    Color secondaryTextColor,
  ) {
    return RefreshIndicator(
      color: AppTheme.primary,
      onRefresh: () => _loadFollowedFirstPage(isRefresh: true),
      child: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: isDark ? AppTheme.darkSurfaceElevated : const Color(0xFFF1F5F9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.category_outlined,
                        size: 34,
                        color: isDark ? AppTheme.darkTextSecondary : const Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Henüz Fırsat Bulunamadı',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Takip ettiğiniz kategorilerde son 48 saatte paylaşılan yeni bir fırsat bulunmuyor veya henüz kategori seçmediniz.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: secondaryTextColor,
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CategoryPreferencesScreen(),
                          ),
                        ).then((_) async {
                          final hasCats = await NotificationService().hasFollowedCategories(currentUser.uid);
                          if (mounted) {
                            setState(() {
                              _hasFollowedCategories = hasCats;
                              _isFollowedCategoriesResolved = true;
                            });
                          }
                          _loadFollowedFirstPage(isRefresh: true);
                        });
                      },
                      icon: const Icon(Icons.tune_rounded, size: 18),
                      label: const Text(
                        'Kategorileri Yönet & Takip Et',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
