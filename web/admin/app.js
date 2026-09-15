// Initialize Firebase
let auth, db, storage;
try {
    if (typeof firebase === 'undefined') {
        throw new Error('Firebase SDK yüklenemedi!');
    }
    if (typeof firebaseConfig === 'undefined') {
        throw new Error('Firebase config yüklenemedi!');
    }
    firebase.initializeApp(firebaseConfig);
    auth = firebase.auth();
    db = firebase.firestore();
    storage = firebase.storage();
    console.log('Firebase initialized successfully');
} catch (error) {
    console.error('Firebase initialization error:', error);
    document.body.innerHTML = `
        <div style="padding: 50px; text-align: center; font-size: 24px; color: red; font-family: Arial;">
            <h1>Hata!</h1>
            <p>Firebase başlatılamadı: ${error.message}</p>
            <p style="font-size: 14px; margin-top: 20px;">Lütfen sayfayı yenileyin veya tarayıcı konsolunu kontrol edin.</p>
        </div>
    `;
    throw error;
}

// Helper to clean profile image URL and format local asset paths with legacy avatar mapping
function cleanProfileImageUrl(url) {
    if (typeof url !== 'string') return '';
    let trimmed = url.trim();
    if (!trimmed) return '';

    // Legacy avatar mappings
    const lower = trimmed.toLowerCase();
    if (lower.includes('kullanıcı pp') || lower.includes('kullanici pp')) {
        trimmed = 'assets/avatars/avatar_cat.webp';
    } else if (lower.includes('kkpp') || lower.includes('ayi') || lower.includes('ayı') || lower.includes('kullanıcı profili') || lower.includes('kullanici profili')) {
        trimmed = 'assets/avatars/avatar_duck.webp';
    } else if (lower === 'assets/profil.jpg' || lower === 'assets/profil.webp') {
        trimmed = 'assets/avatars/avatar_duck.webp';
    }

    if (trimmed.startsWith('assets/')) {
        const webpPath = trimmed.replace(/\.(jpg|jpeg|png)$/i, '.webp');
        return '/' + webpPath;
    }
    return trimmed;
}

// Categories and Subcategories Configuration mapping (synced with Category model)
const categoriesConfig = {
    elektronik: [
        "Telefon & Aksesuarları",
        "Bilgisayar & Tablet",
        "TV & Ses Sistemleri",
        "Beyaz Eşya & Küçük Ev Aletleri",
        "Fotoğraf & Kamera"
    ],
    moda: [
        "Kadın Giyim",
        "Erkek Giyim",
        "Ayakkabı & Çanta",
        "Saat & Aksesuar",
        "Çocuk Giyim"
    ],
    ev_yasam: [
        "Mobilya",
        "Ev Tekstili",
        "Mutfak Gereçleri",
        "Aydınlatma & Dekorasyon",
        "Kırtasiye & Ofis Malzemeleri"
    ],
    anne_bebek: [
        "Bebek Bezi & Islak Mendil",
        "Bebek Arabası & Oto Koltuğu",
        "Beslenme & Emzirme",
        "Bebek Odası & Güvenlik",
        "Bebek Oyuncakları"
    ],
    kozmetik: [
        "Parfüm & Deodorant",
        "Makyaj Ürünleri",
        "Cilt & Yüz Bakımı",
        "Saç Bakımı",
        "Ağız & Diş Bakımı"
    ],
    spor_outdoor: [
        "Spor Giyim & Ayakkabı",
        "Fitness & Kondisyon",
        "Kamp & Doğa Malzemeleri",
        "Bisiklet & Ekipmanları"
    ],
    supermarket: [
        "Gıda Ürünleri",
        "Deterjan & Temizlik",
        "Kağıt Ürünleri",
        "Kedi & Köpek Ürünleri"
    ],
    yapi_oto: [
        "Elektrikli Aletler & Hırdavat",
        "Oto Aksesuar & Bakım",
        "Banyo & Tesisat",
        "Bahçe Malzemeleri"
    ],
    kitap_hobi: [
        "Kitap & Dergi",
        "Müzik Enstrümanları",
        "Oyun Konsolları & Video Oyunları",
        "Hobi & Sanat Malzemeleri"
    ],
    diger: []
};

// Global state
let currentUser = null;
let currentFilter = 'pending';
let deals = [];
let currentDeal = null;
let dealsUnsubscribe = null; // Real-time listener unsubscribe function
let users = [];
let usersUnsubscribe = null; // Real-time listener unsubscribe function for users
let messages = [];
let messagesUnsubscribe = null; // Real-time listener unsubscribe function for messages
let currentView = 'deals'; // 'deals', 'users', or 'messages'
let previousView = 'deals'; // Modal açılmadan önceki view (modal kapatıldığında buraya dönmek için)
let usersSearchQuery = ''; // Kullanıcı arama sorgusu
let currentUserDetail = null; // Seçili kullanıcı detayı
let dealsTrendChartInstance = null;
let categoriesDistributionChartInstance = null;
let notifTrendChartInstance = null;
let coupons = [];
let couponsUnsubscribe = null;
let catalogs = [];
let catalogsUnsubscribe = null;

// User info cache for source column display
const dealUserCache = new Map();

async function getUserDisplayLabel(uid) {
    if (!uid || uid === 'Bilinmiyor' || uid === 'admin') return 'Admin';
    if (dealUserCache.has(uid)) return dealUserCache.get(uid);

    // Global users array check
    if (typeof users !== 'undefined' && Array.isArray(users) && users.length > 0) {
        const found = users.find(u => u.id === uid || u.uid === uid);
        if (found) {
            const label = found.nickname || found.username || found.displayName || found.email || uid;
            dealUserCache.set(uid, label);
            return label;
        }
    }

    // Fetch from Firestore users collection
    try {
        if (typeof db !== 'undefined') {
            const doc = await db.collection('users').doc(uid).get();
            if (doc.exists) {
                const uData = doc.data();
                const label = uData.nickname || uData.username || uData.displayName || uData.email || uid;
                dealUserCache.set(uid, label);
                return label;
            }
        }
    } catch (_) {}

    return uid;
}

// DOM Elements - Wait for DOM to be ready
let loginScreen, adminPanel, googleSignInBtn, logoutBtn, userName, userAvatar, loginError;
let dealsList, loadingIndicator, emptyState, filterBtns, dealModal, closeModal;
let approveBtn, rejectBtn, unpublishBtn, reactivateBtn, modalTitle, modalBody;

function initDOMElements() {
    loginScreen = document.getElementById('loginScreen');
    adminPanel = document.getElementById('adminPanel');
    googleSignInBtn = document.getElementById('googleSignInBtn');
    logoutBtn = document.getElementById('logoutBtn');
    userName = document.getElementById('userName');
    userAvatar = document.getElementById('userAvatar');
    loginError = document.getElementById('loginError');
    dealsList = document.getElementById('dealsList');
    loadingIndicator = document.getElementById('loadingIndicator');
    emptyState = document.getElementById('emptyState');
    filterBtns = document.querySelectorAll('.filter-btn');
    dealModal = document.getElementById('dealModal');
    closeModal = document.getElementById('closeModal');
    approveBtn = document.getElementById('approveBtn');
    rejectBtn = document.getElementById('rejectBtn');
    unpublishBtn = document.getElementById('unpublishBtn');
    reactivateBtn = document.getElementById('reactivateBtn');
    modalTitle = document.getElementById('modalTitle');
    modalBody = document.getElementById('modalBody');

    // Check critical elements only
    const criticalElements = {
        loginScreen,
        adminPanel,
        googleSignInBtn
    };

    const missing = Object.entries(criticalElements)
        .filter(([name, el]) => !el)
        .map(([name]) => name);

    if (missing.length > 0) {
        console.error('Missing critical DOM elements:', missing);
    } else {
        console.log('Critical DOM elements initialized successfully');
    }

    // Log optional elements
    if (!dealsList) console.warn('dealsList not found (will be created dynamically)');
    if (!loadingIndicator) console.warn('loadingIndicator not found');
    if (!emptyState) console.warn('emptyState not found');
}

// Check auth state - Wait for DOM to be ready
async function initAuth() {
    console.log('🔐 Initializing auth...');

    // Önce redirect sonucunu kontrol et (sayfa yeniden yüklendiğinde)
    try {
        console.log('📥 Checking redirect result...');
        const redirectResult = await auth.getRedirectResult();
        console.log('📥 Redirect result:', redirectResult);
        console.log('📥 Redirect result.user:', redirectResult.user ? `${redirectResult.user.email} (${redirectResult.user.uid})` : 'null');
        console.log('📥 Redirect result.credential:', redirectResult.credential ? 'exists' : 'null');

        if (redirectResult.user) {
            console.log('✅ Redirect sign in successful:', redirectResult.user.email, 'UID:', redirectResult.user.uid);
            currentUser = redirectResult.user;
            sessionStorage.setItem('redirectHandled', 'true');
            console.log('🔍 Starting admin check for redirect user...');
            await checkAdminAndLoad(redirectResult.user);
            // onAuthStateChanged zaten tetiklenecek, bu yüzden return etmeyelim
            // return; // Redirect başarılıysa, onAuthStateChanged'i bekleme
        } else {
            console.log('ℹ️ No redirect result user, checking current auth state...');
            // Redirect sonucu yoksa mevcut kullanıcıyı kontrol et
            const currentAuthUser = auth.currentUser;
            if (currentAuthUser) {
                console.log('✅ Found current user:', currentAuthUser.email, 'UID:', currentAuthUser.uid);
                currentUser = currentAuthUser;
                await checkAdminAndLoad(currentAuthUser);
            }
        }
    } catch (error) {
        console.error('❌ Redirect result error:', error);
        console.error('❌ Error details:', error.message, error.code);
        console.error('❌ Error stack:', error.stack);
    }

    // Redirect yoksa veya başarısızsa, mevcut auth state'i kontrol et
    console.log('👂 Setting up auth state listener...');
    auth.onAuthStateChanged(async (user) => {
        console.log('🔄 Auth state changed, user:', user ? `${user.email} (${user.uid})` : 'null');
        if (user) {
            // Eğer zaten admin paneli gösteriliyorsa tekrar kontrol etme
            if (currentUser && currentUser.uid === user.uid && adminPanel && !adminPanel.classList.contains('hidden')) {
                console.log('⏭️ User already authenticated and panel shown, skipping...');
                return;
            }
            currentUser = user;
            // Redirect sonucu zaten işlendiyse tekrar kontrol etme
            const redirectHandled = sessionStorage.getItem('redirectHandled');
            console.log('🔍 Redirect handled flag:', redirectHandled);
            if (!redirectHandled) {
                console.log('🔍 Starting admin check for auth state user...');
                await checkAdminAndLoad(user);
            } else {
                console.log('⏭️ Redirect already handled, skipping admin check...');
            }
        } else {
            console.log('👤 No user, showing login screen...');
            currentUser = null;
            sessionStorage.removeItem('redirectHandled');
            showLoginScreen();
        }
    });
}

async function checkAdminAndLoad(user) {
    if (!user || !user.uid) {
        console.error('Invalid user object:', user);
        showLoginScreen();
        return;
    }

    console.log('🔍 Checking admin status for:', user.uid, user.email);
    try {
        const isAdmin = await checkAdmin(user.uid);
        console.log('✅ Admin check result:', isAdmin);

        if (isAdmin) {
            console.log('✅ User is admin, showing admin panel...');
            showAdminPanel();
            initEnvironmentBadge();

            // Aktif filter butonunu kontrol et ve currentFilter'ı ayarla
            const activeFilterBtn = document.querySelector('.filter-btn.active');
            if (activeFilterBtn) {
                currentFilter = activeFilterBtn.dataset.filter || 'all';
                console.log('🔍 İlk yüklemede aktif filter butonu bulundu, currentFilter ayarlandı:', currentFilter);
            } else {
                // Aktif buton bulunamazsa varsayılan olarak 'all' yap
                currentFilter = 'all';
                console.log('⚠️ İlk yüklemede aktif filter butonu bulunamadı, currentFilter varsayılan olarak "all" yapıldı');
            }

            console.log('📦 Loading deals after admin check...');
            await loadDeals();
            console.log('👥 Loading users after admin check...');
            loadUsers();
            initRealtimeSystemHealth();
            loadNotificationLimits();
            showDashboardView();
            console.log('✅ Admin panel loaded successfully!');
        } else {
            console.warn('⚠️ User is not admin:', user.email);
            // Kullanıcıyı çıkış yaptır ve login ekranını göster
            try {
                console.log('🚪 Signing out non-admin user...');
                await auth.signOut();
                console.log('✅ User signed out');
            } catch (signOutError) {
                console.error('❌ Sign out error:', signOutError);
            }
            showError('Bu hesap admin yetkisine sahip değil. Lütfen admin hesabı ile giriş yapın.');
            showLoginScreen();
        }
    } catch (error) {
        console.error('❌ Error checking admin status:', error);
        console.error('❌ Error stack:', error.stack);
        showError('Admin kontrolü sırasında bir hata oluştu: ' + error.message);
        try {
            await auth.signOut();
        } catch (signOutError) {
            console.error('❌ Sign out error:', signOutError);
        }
        showLoginScreen();
    }
}

// Initialize DOM elements when page loads
if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        initDOMElements();
        initEventListeners();
        initLightbox();
        initAuth();
    });
} else {
    initDOMElements();
    initEventListeners();
    initLightbox();
    initAuth();
}

// Initialize event listeners
function initEventListeners() {
    // Google Sign In
    console.log('🔘 Initializing Google Sign In button...');
    console.log('🔘 googleSignInBtn element:', googleSignInBtn);

    if (!googleSignInBtn) {
        console.error('❌ Google Sign In button not found!');
        // Try to find it again
        googleSignInBtn = document.getElementById('googleSignInBtn');
        console.log('🔘 Retry - googleSignInBtn:', googleSignInBtn);
        if (!googleSignInBtn) {
            console.error('❌ Google Sign In button still not found after retry!');
            return;
        }
    }

    console.log('✅ Google Sign In button found, adding event listener...');

    // Buton içindeki tüm elementlere pointer-events ekle (CSS ile)
    const buttonChildren = googleSignInBtn.querySelectorAll('*');
    buttonChildren.forEach(child => {
        child.style.pointerEvents = 'none';
    });

    // Çift tıklamayı önlemek için flag
    let isSigningIn = false;

    // Event handler fonksiyonu
    const handleGoogleSignIn = async (e) => {
        // Çift tıklamayı önle
        if (isSigningIn) {
            console.log('⏭️ Sign in already in progress, ignoring click...');
            return;
        }

        e.preventDefault();
        e.stopPropagation();
        isSigningIn = true;

        try {
            console.log('🖱️ Google Sign In button clicked!', e);
            const provider = new firebase.auth.GoogleAuthProvider();

            // Önce popup dene, başarısız olursa redirect kullan
            console.log('🔄 Attempting popup sign in first...');
            console.log('🔄 Current URL:', window.location.href);
            console.log('🔄 Current origin:', window.location.origin);

            try {
                const result = await auth.signInWithPopup(provider);
                console.log('✅ Popup sign in successful!', result.user.email, result.user.uid);
                currentUser = result.user;

                // Hemen admin kontrolü yap
                console.log('🔍 Starting admin check for popup user...');
                const isAdmin = await checkAdmin(result.user.uid);
                console.log('✅ Admin check result:', isAdmin);

                if (isAdmin) {
                    console.log('✅ User is admin, showing admin panel...');
                    showAdminPanel();
                    await loadDeals();
                    updateStats();
                    console.log('✅ Admin panel loaded!');
                } else {
                    console.warn('⚠️ User is not admin');
                    await auth.signOut();
                    showError('Bu hesap admin yetkisine sahip değil.');
                    showLoginScreen();
                }

                isSigningIn = false;
                return;
            } catch (popupError) {
                console.error('❌ Popup sign in failed:', popupError);
                console.error('❌ Error code:', popupError.code);
                console.error('❌ Error message:', popupError.message);

                // Popup başarısız olursa redirect kullan
                if (popupError.code === 'auth/popup-blocked' || popupError.code === 'auth/popup-closed-by-user' || popupError.code === 'auth/unauthorized-domain') {
                    console.log('🔄 Using redirect method as fallback...');

                    try {
                        // Hash fragment'i kaldır
                        const redirectUrl = window.location.origin + window.location.pathname;
                        console.log('🔄 Redirect URL:', redirectUrl);

                        await auth.signInWithRedirect(provider);
                        console.log('🔄 Redirect initiated, page will reload...');
                        // Redirect olduğu için isSigningIn flag'i reset edilmeyecek
                        return;
                    } catch (redirectError) {
                        console.error('❌ Redirect error:', redirectError);
                        console.error('❌ Redirect error code:', redirectError.code);
                        console.error('❌ Redirect error message:', redirectError.message);
                        isSigningIn = false;
                        throw redirectError;
                    }
                } else {
                    // Diğer hatalar için kullanıcıya göster
                    let errorMessage = 'Giriş yapılamadı: ';
                    if (popupError.code === 'auth/unauthorized-domain') {
                        const domain = (typeof firebaseConfig !== 'undefined' && firebaseConfig.projectId) ? `${firebaseConfig.projectId}.web.app` : 'sicak-firsatlar-e6eae.web.app';
                        errorMessage = `Bu domain için yetkilendirme yapılmamış. Firebase Console > Authentication > Settings > Authorized domains bölümüne "${domain}" domain'ini ekleyin.`;
                    } else {
                        errorMessage += popupError.message;
                    }
                    showError(errorMessage);
                    isSigningIn = false;
                    throw popupError;
                }
            }
        } catch (error) {
            console.error('❌ Sign in error:', error);
            console.error('❌ Error code:', error.code);
            console.error('❌ Error message:', error.message);
            isSigningIn = false;

            let errorMessage = 'Giriş yapılamadı: ';

            if (error.code === 'auth/popup-blocked') {
                errorMessage = 'Popup engellendi. Lütfen tarayıcı ayarlarından popup\'ları etkinleştirin.';
            } else if (error.code === 'auth/popup-closed-by-user') {
                errorMessage = 'Giriş penceresi kapatıldı. Lütfen tekrar deneyin.';
            } else if (error.code === 'auth/unauthorized-domain') {
                errorMessage = 'Bu domain için yetkilendirme yapılmamış. Firebase Console\'da domain\'i ekleyin.';
            } else {
                errorMessage += error.message;
            }

            showError(errorMessage);
        }
    };

    // Önce mevcut event listener'ları temizle (eğer varsa)
    const newButton = googleSignInBtn.cloneNode(true);
    googleSignInBtn.parentNode.replaceChild(newButton, googleSignInBtn);
    googleSignInBtn = newButton;

    // Buton içindeki tüm elementlere pointer-events ekle (CSS ile) - tekrar tanımlama
    const buttonChildrenNew = googleSignInBtn.querySelectorAll('*');
    buttonChildrenNew.forEach(child => {
        child.style.pointerEvents = 'none';
    });

    // Sadece click event'ini dinle (mousedown ve touchstart'ı kaldırdık)
    googleSignInBtn.addEventListener('click', handleGoogleSignIn, { once: false, passive: false });

    console.log('✅ Google Sign In event listener added successfully');

    // Logout
    if (logoutBtn) {
        logoutBtn.addEventListener('click', async () => {
            try {
                // Real-time listener'ları temizle
                if (dealsUnsubscribe) {
                    console.log('🛑 Unsubscribing from deals listener on logout...');
                    dealsUnsubscribe();
                }
                if (usersUnsubscribe) {
                    console.log('🛑 Unsubscribing from users listener on logout...');
                    usersUnsubscribe();
                }
                if (messagesUnsubscribe) {
                    console.log('🛑 Unsubscribing from messages listener on logout...');
                    messagesUnsubscribe();
                    dealsUnsubscribe = null;
                }
                await auth.signOut();
            } catch (error) {
                console.error('Logout error:', error);
            }
        });
    }

    // Filter buttons
    if (filterBtns && filterBtns.length > 0) {
        filterBtns.forEach(btn => {
            btn.addEventListener('click', () => {
                filterBtns.forEach(b => {
                    b.classList.remove('active', 'border-primary', 'bg-primary/10', 'text-primary');
                    b.classList.add('border-slate-200', 'dark:border-slate-700', 'bg-slate-50', 'dark:bg-surface-darker', 'text-slate-700', 'dark:text-slate-300');
                });
                btn.classList.add('active', 'border-primary', 'bg-primary/10', 'text-primary');
                btn.classList.remove('border-slate-200', 'dark:border-slate-700', 'bg-slate-50', 'dark:bg-surface-darker', 'text-slate-700', 'dark:text-slate-300');
                currentFilter = btn.dataset.filter;
                renderDeals();
            });
        });
    }

    // Modal close
    if (closeModal) {
        closeModal.addEventListener('click', () => {
            closeDealModal();
        });
    }

    // Cancel button (new modal design - may not exist yet)
    const cancelBtn = document.getElementById('cancelBtn');
    if (cancelBtn) {
        cancelBtn.addEventListener('click', () => {
            closeDealModal();
        });
    }

    // Save button (new modal design - may not exist yet)
    const saveBtn = document.getElementById('saveBtn');
    if (saveBtn) {
        saveBtn.addEventListener('click', async () => {
            await saveDealChanges();
        });
    }

    // Bind all navigation links (Dashboard, Fırsatlar, Kullanıcılar, Mesajlar, Raporlar, Ayarlar)
    const dashboardMenuBtn = document.getElementById('dashboardMenuBtn');
    if (dashboardMenuBtn) {
        dashboardMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showDashboardView();
        });
    }

    const dealsMenuBtn = document.getElementById('dealsMenuBtn');
    if (dealsMenuBtn) {
        dealsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showDealsView();
        });
    }

    // Search input for deals
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        searchInput.addEventListener('input', () => {
            renderDeals();
        });
    }

    // Category filter for deals
    const categoryFilter = document.getElementById('categoryFilter');
    if (categoryFilter) {
        categoryFilter.addEventListener('change', () => {
            renderDeals();
        });
    }

    // Source filter for deals
    const sourceFilter = document.getElementById('sourceFilter');
    if (sourceFilter) {
        sourceFilter.addEventListener('change', () => {
            renderDeals();
        });
    }

    // Sort select for deals
    const sortSelect = document.getElementById('sortSelect');
    if (sortSelect) {
        sortSelect.addEventListener('change', () => {
            renderDeals();
        });
    }

    // Refresh Dashboard button
    const refreshDashboardBtn = document.getElementById('refreshDashboardBtn');
    if (refreshDashboardBtn) {
        refreshDashboardBtn.addEventListener('click', async () => {
            refreshDashboardBtn.disabled = true;
            const originalHTML = refreshDashboardBtn.innerHTML;
            refreshDashboardBtn.innerHTML = '<span class="material-symbols-outlined text-[20px] animate-spin">refresh</span><span>Yükleniyor...</span>';

            await loadDashboardData();

            refreshDashboardBtn.disabled = false;
            refreshDashboardBtn.innerHTML = originalHTML;
            showSuccess('Gösterge paneli güncellendi!');
        });
    }

    const usersMenuBtn = document.getElementById('usersMenuBtn');
    if (usersMenuBtn) {
        usersMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showUsersView();
        });
    }

    const catalogsMenuBtn = document.getElementById('catalogsMenuBtn');
    if (catalogsMenuBtn) {
        catalogsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showCatalogsView();
        });
    }

    const messagesMenuBtn = document.getElementById('messagesMenuBtn');
    if (messagesMenuBtn) {
        messagesMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showMessagesView();
        });
    }

    const reportsMenuBtn = document.getElementById('reportsMenuBtn');
    if (reportsMenuBtn) {
        reportsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showReportsView();
        });
    }

    const settingsMenuBtn = document.getElementById('settingsMenuBtn');
    if (settingsMenuBtn) {
        settingsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showSettingsView();
        });
    }

    const telegramBotMenuBtn = document.getElementById('telegramBotMenuBtn');
    if (telegramBotMenuBtn) {
        telegramBotMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showTelegramBotView();
        });
    }

    const observabilityMenuBtn = document.getElementById('observabilityMenuBtn');
    if (observabilityMenuBtn) {
        observabilityMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showObservabilityView();
        });
    }

    // Load initial global settings status
    loadDealSharingStatus();
    loadCommentSharingStatus();
    loadTeknosaAffiliateStatus();
    loadHepsiburadaAffiliateStatus();
    loadAmazonAffiliateStatus();
    loadIncehesapAffiliateStatus();

    // Toggle Deal Sharing button (Deals Toolbar)
    const toggleDealSharingBtn = document.getElementById('toggleDealSharingBtn');
    if (toggleDealSharingBtn) {
        toggleDealSharingBtn.addEventListener('click', async () => {
            await toggleDealSharing();
        });
    }

    // Toggle Comment Sharing button (Deals Toolbar)
    const toggleCommentSharingBtn = document.getElementById('toggleCommentSharingBtn');
    if (toggleCommentSharingBtn) {
        toggleCommentSharingBtn.addEventListener('click', async () => {
            await toggleCommentSharing();
        });
    }

    // Toggle Deal Sharing switch (Settings View)
    const settingsToggleDealSharingBtn = document.getElementById('settingsToggleDealSharingBtn');
    if (settingsToggleDealSharingBtn) {
        settingsToggleDealSharingBtn.addEventListener('change', async () => {
            await toggleDealSharing();
        });
    }

    // Toggle Deal Approval switch (Settings View)
    const settingsToggleDealApprovalBtn = document.getElementById('settingsToggleDealApprovalBtn');
    if (settingsToggleDealApprovalBtn) {
        settingsToggleDealApprovalBtn.addEventListener('change', async () => {
            await toggleDealApproval();
        });
    }

    // Toggle Comment Sharing switch (Settings View)
    const settingsToggleCommentSharingBtn = document.getElementById('settingsToggleCommentSharingBtn');
    if (settingsToggleCommentSharingBtn) {
        settingsToggleCommentSharingBtn.addEventListener('change', async () => {
            await toggleCommentSharing();
        });
    }

    // Toggle Bot switch (Settings View)
    const settingsToggleBotBtn = document.getElementById('settingsToggleBotBtn');
    if (settingsToggleBotBtn) {
        settingsToggleBotBtn.addEventListener('change', async () => {
            await toggleBotStatus();
        });
    }

    // Toggle Notifications switch (Settings View)
    const settingsToggleNotificationsBtn = document.getElementById('settingsToggleNotificationsBtn');
    if (settingsToggleNotificationsBtn) {
        settingsToggleNotificationsBtn.addEventListener('change', async () => {
            await toggleGlobalNotifications();
        });
    }

    // Toggle Botkolik Chat switch (Settings View)
    const settingsToggleBotkolikChatBtn = document.getElementById('settingsToggleBotkolikChatBtn');
    if (settingsToggleBotkolikChatBtn) {
        settingsToggleBotkolikChatBtn.addEventListener('change', async () => {
            await toggleBotkolikChat();
        });
    }

    // Toggle Teknosa Affiliate switch (Settings View)
    const settingsToggleTeknosaAffiliateBtn = document.getElementById('settingsToggleTeknosaAffiliateBtn');
    if (settingsToggleTeknosaAffiliateBtn) {
        settingsToggleTeknosaAffiliateBtn.addEventListener('change', async () => {
            await toggleTeknosaAffiliate();
        });
    }

    // Teknosa Affiliate Info Button and Close Button
    const teknosaAffiliateInfoBtn = document.getElementById('teknosaAffiliateInfoBtn');
    const closeTeknosaAffiliateInfoBtn = document.getElementById('closeTeknosaAffiliateInfoBtn');
    const teknosaAffiliateInfoBox = document.getElementById('teknosaAffiliateInfoBox');

    if (teknosaAffiliateInfoBtn && teknosaAffiliateInfoBox) {
        teknosaAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            teknosaAffiliateInfoBox.classList.toggle('hidden');
        });
    }

    if (closeTeknosaAffiliateInfoBtn && teknosaAffiliateInfoBox) {
        closeTeknosaAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            teknosaAffiliateInfoBox.classList.add('hidden');
        });
    }

    // Toggle Hepsiburada Affiliate switch (Settings View)
    const settingsToggleHepsiburadaAffiliateBtn = document.getElementById('settingsToggleHepsiburadaAffiliateBtn');
    if (settingsToggleHepsiburadaAffiliateBtn) {
        settingsToggleHepsiburadaAffiliateBtn.addEventListener('change', async () => {
            await toggleHepsiburadaAffiliate();
        });
    }

    // Hepsiburada Affiliate Info Button and Close Button
    const hepsiburadaAffiliateInfoBtn = document.getElementById('hepsiburadaAffiliateInfoBtn');
    const closeHepsiburadaAffiliateInfoBtn = document.getElementById('closeHepsiburadaAffiliateInfoBtn');
    const hepsiburadaAffiliateInfoBox = document.getElementById('hepsiburadaAffiliateInfoBox');

    if (hepsiburadaAffiliateInfoBtn && hepsiburadaAffiliateInfoBox) {
        hepsiburadaAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            hepsiburadaAffiliateInfoBox.classList.toggle('hidden');
        });
    }

    if (closeHepsiburadaAffiliateInfoBtn && hepsiburadaAffiliateInfoBox) {
        closeHepsiburadaAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            hepsiburadaAffiliateInfoBox.classList.add('hidden');
        });
    }

    // Toggle Amazon Affiliate switch (Settings View)
    const settingsToggleAmazonAffiliateBtn = document.getElementById('settingsToggleAmazonAffiliateBtn');
    if (settingsToggleAmazonAffiliateBtn) {
        settingsToggleAmazonAffiliateBtn.addEventListener('change', async () => {
            await toggleAmazonAffiliate();
        });
    }

    // Amazon Affiliate Info Button and Close Button
    const amazonAffiliateInfoBtn = document.getElementById('amazonAffiliateInfoBtn');
    const closeAmazonAffiliateInfoBtn = document.getElementById('closeAmazonAffiliateInfoBtn');
    const amazonAffiliateInfoBox = document.getElementById('amazonAffiliateInfoBox');

    if (amazonAffiliateInfoBtn && amazonAffiliateInfoBox) {
        amazonAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            amazonAffiliateInfoBox.classList.toggle('hidden');
        });
    }

    if (closeAmazonAffiliateInfoBtn && amazonAffiliateInfoBox) {
        closeAmazonAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            amazonAffiliateInfoBox.classList.add('hidden');
        });
    }

    // Toggle İncehesap Affiliate switch (Settings View)
    const settingsToggleIncehesapAffiliateBtn = document.getElementById('settingsToggleIncehesapAffiliateBtn');
    if (settingsToggleIncehesapAffiliateBtn) {
        settingsToggleIncehesapAffiliateBtn.addEventListener('change', async () => {
            await toggleIncehesapAffiliate();
        });
    }

    // İncehesap Affiliate Info Button and Close Button
    const incehesapAffiliateInfoBtn = document.getElementById('incehesapAffiliateInfoBtn');
    const closeIncehesapAffiliateInfoBtn = document.getElementById('closeIncehesapAffiliateInfoBtn');
    const incehesapAffiliateInfoBox = document.getElementById('incehesapAffiliateInfoBox');

    if (incehesapAffiliateInfoBtn && incehesapAffiliateInfoBox) {
        incehesapAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            incehesapAffiliateInfoBox.classList.toggle('hidden');
        });
    }

    if (closeIncehesapAffiliateInfoBtn && incehesapAffiliateInfoBox) {
        closeIncehesapAffiliateInfoBtn.addEventListener('click', (e) => {
            e.preventDefault();
            incehesapAffiliateInfoBox.classList.add('hidden');
        });
    }



    // Save Notification Limits Button (Settings View)
    const saveConfigBtn = document.getElementById('saveConfigBtn');
    if (saveConfigBtn) {
        saveConfigBtn.addEventListener('click', async (e) => {
            e.preventDefault();
            await saveNotificationLimits();
        });
    }

    // Refresh Deals button (Yenile)
    const refreshDealsBtn = document.getElementById('refreshDealsBtn');
    if (refreshDealsBtn) {
        console.log('✅ Refresh Deals button found, adding event listener...');
        refreshDealsBtn.addEventListener('click', async () => {
            console.log('🔄 Refresh Deals button clicked!');
            try {
                // Butonu devre dışı bırak ve loading göster
                refreshDealsBtn.disabled = true;
                const originalHTML = refreshDealsBtn.innerHTML;
                refreshDealsBtn.innerHTML = '<span class="material-symbols-outlined text-[20px] animate-spin">refresh</span><span class="hidden sm:inline">Yükleniyor...</span>';

                // Deal'leri yenile
                await loadDeals();
                updateStats();

                // Başarı mesajı göster
                showSuccess('Fırsatlar yenilendi!');

                // Butonu tekrar aktif et
                refreshDealsBtn.disabled = false;
                refreshDealsBtn.innerHTML = originalHTML;
            } catch (error) {
                console.error('❌ Refresh hatası:', error);
                showError('Yenileme hatası: ' + error.message);
                refreshDealsBtn.disabled = false;
                refreshDealsBtn.innerHTML = '<span class="material-symbols-outlined text-[20px]">refresh</span><span class="hidden sm:inline">Yenile</span>';
            }
        });
    } else {
        console.warn('⚠️ Refresh Deals button NOT FOUND!');
    }

    // Purge Old Deals button (30+ Günlük Temizlik)
    const purgeOldDealsBtn = document.getElementById('purgeOldDealsBtn');
    if (purgeOldDealsBtn) {
        console.log('✅ Purge Old Deals button found, adding event listener...');
        purgeOldDealsBtn.addEventListener('click', async () => {
            if (!confirm('30 günden eski TÜM fırsatları (oylar, yorumlar, favoriler dahil) ve TÜM kullanıcıların 30+ günlük eski bildirimlerini kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz!')) {
                return;
            }
            try {
                purgeOldDealsBtn.disabled = true;
                const originalHTML = purgeOldDealsBtn.innerHTML;
                purgeOldDealsBtn.innerHTML = '<span class="material-symbols-outlined text-[18px] animate-spin">refresh</span><span>Temizleniyor...</span>';

                const result = await purgeOldDealsWeb();
                const deletedDeals = result && typeof result === 'object' ? (result.deletedCount || 0) : (result || 0);
                const deletedNotifs = result && typeof result === 'object' ? (result.deletedNotificationsCount || 0) : 0;

                showSuccess(`${deletedDeals} adet fırsat ve ${deletedNotifs} adet eski bildirim kalıcı olarak temizlendi!`);
                await loadDeals();
                updateStats();

                purgeOldDealsBtn.disabled = false;
                purgeOldDealsBtn.innerHTML = originalHTML;
            } catch (error) {
                console.error('❌ Purge hatası:', error);
                showError('Kalıcı silme hatası: ' + error.message);
                purgeOldDealsBtn.disabled = false;
                purgeOldDealsBtn.innerHTML = '<span class="material-symbols-outlined text-[18px]">auto_delete</span><span>30+ Günlük Temizlik</span>';
            }
        });
    }

    // Add Deal button (Fırsat Ekle)
    const addDealBtn = document.getElementById('addDealBtn');
    if (addDealBtn) {
        console.log('✅ Add Deal button found, adding event listener...');
        addDealBtn.addEventListener('click', async () => {
            console.log('🖱️ Add Deal button clicked!');
            await showAddDealModal();
        });
    } else {
        console.warn('⚠️ Add Deal button NOT FOUND!');
    }

    // Geliştirici & Test Araçları Butonları
    const btnGenerateTestData = document.getElementById('btnGenerateTestData');
    if (btnGenerateTestData) {
        btnGenerateTestData.addEventListener('click', async () => {
            await window.generateTestDataAdmin();
        });
    }
    const btnClearTestData = document.getElementById('btnClearTestData');
    if (btnClearTestData) {
        btnClearTestData.addEventListener('click', async () => {
            await window.cleanupTestDataAdmin();
        });
    }

    // Approve deal (old modal design)
    if (approveBtn) {
        approveBtn.addEventListener('click', async () => {
            if (!currentDeal) return;
            try {
                await db.collection('deals').doc(currentDeal.id).update({
                    isApproved: true,
                    isRejected: false,
                    isExpired: false,
                    status: 'active',
                    approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
                    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
                });
                showSuccess('Fırsat onaylandı!');
                closeDealModal();
                loadDeals();
                updateStats();
            } catch (error) {
                showError('Onaylama hatası: ' + error.message);
            }
        });
    }

    // Permanent delete deal from modal (silBtn)
    if (rejectBtn) {
        rejectBtn.addEventListener('click', async () => {
            if (!currentDeal) return;
            if (!confirm('Bu fırsatı veritabanından kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz ve tüm platformlardan kaldırılacaktır.')) return;
            try {
                await db.collection('deals').doc(currentDeal.id).delete();
                showSuccess('Fırsat başarıyla kalıcı olarak silindi!');
                closeDealModal();
                loadDeals();
                updateStats();
            } catch (error) {
                showError('Silme hatası: ' + error.message);
            }
        });
    }

    // New modal design buttons (delegated event listeners)
    document.addEventListener('click', async (e) => {
        const saveBtnNew = e.target.closest('#saveBtn');
        const cancelBtnNew = e.target.closest('#cancelBtn');
        const approveBtnRow = e.target.closest('.approve-btn');
        const editBtnRow = e.target.closest('.edit-btn');
        const rejectBtnRow = e.target.closest('.reject-btn');

        if (approveBtnRow) {
            e.preventDefault();
            e.stopPropagation();
            const dealId = approveBtnRow.dataset.dealId;
            console.log('✅ Approved row button clicked (delegated):', dealId);
            await approveDeal(dealId);
            return;
        }

        if (editBtnRow) {
            e.preventDefault();
            e.stopPropagation();
            const dealId = editBtnRow.dataset.dealId;
            console.log('✏️ Edit row button clicked (delegated):', dealId);
            const deal = deals.find(d => d.id === dealId);
            if (deal) {
                await showDealModal(deal);
            } else {
                console.warn('⚠️ Deal not found in memory, fetching from DB...');
                try {
                    const doc = await db.collection('deals').doc(dealId).get();
                    if (doc.exists) {
                        await showDealModal({ id: doc.id, ...doc.data() });
                    }
                } catch (err) {
                    console.error('Error fetching deal for modal:', err);
                }
            }
            return;
        }

        if (rejectBtnRow) {
            e.preventDefault();
            e.stopPropagation();
            const dealId = rejectBtnRow.dataset.dealId;
            console.log('🚫 Reject row button clicked (delegated):', dealId);
            if (confirm('Bu fırsatı reddetmek istediğinize emin misiniz?')) {
                await rejectDeal(dealId);
            }
            return;
        }

        if (saveBtnNew) {
            e.preventDefault();
            e.stopPropagation();
            console.log('✅ Onayla/Kaydet butonu tıklandı (delegated)!', currentDeal?.id);

            if (!currentDeal) {
                console.error('❌ No current deal!');
                showError('Fırsat bulunamadı!');
                return;
            }

            // Durumu güncelle: Eğer fırsat aktif değilse ve kullanıcı doğrudan "Onayla" butonuna tıkladıysa, durumu 'active' yap.
            // Ama eğer kullanıcı durum dropdown'ından ('editStatus') bilerek başka bir durum (örn. 'rejected') seçtiyse, onu ezme!
            const editStatusEl = document.getElementById('editStatus');
            if (editStatusEl) {
                const currentStatus = editStatusEl.value;
                if (!currentDeal.isApproved && currentStatus === 'pending') {
                    editStatusEl.value = 'active';
                }
            }

            // Butonu devre dışı bırak
            const btn = saveBtnNew;
            const originalHTML = btn.innerHTML;
            btn.disabled = true;
            btn.innerHTML = '<span>Kaydediliyor...</span>';

            try {
                await saveDealChanges();
            } catch (error) {
                console.error('❌ Onaylama hatası:', error);
                btn.disabled = false;
                btn.innerHTML = originalHTML;
            }
        }

        if (cancelBtnNew) {
            e.preventDefault();
            e.stopPropagation();
            console.log('❌ İptal butonu tıklandı (delegated)!');
            closeDealModal();
            return;
        }

        const unpublishBtnRow = e.target.closest('.unpublish-btn');
        if (unpublishBtnRow) {
            e.preventDefault();
            e.stopPropagation();
            const dealId = unpublishBtnRow.dataset.dealId;
            console.log('⏸️ Unpublish row button clicked (delegated):', dealId);
            if (confirm('Bu fırsatı yayından kaldırmak istediğinize emin misiniz? Fırsat süresi bitenler bölümüne taşınacaktır.')) {
                await unpublishDeal(dealId);
            }
            return;
        }

        const reactivateBtnRow = e.target.closest('.reactivate-btn');
        if (reactivateBtnRow) {
            e.preventDefault();
            e.stopPropagation();
            const dealId = reactivateBtnRow.dataset.dealId;
            console.log('▶️ Reactivate row button clicked (delegated):', dealId);
            if (confirm('Bu fırsatı tekrar yayına almak istediğinize emin misiniz?')) {
                await reactivateDeal(dealId);
            }
            return;
        }

        const deleteBtnRow = e.target.closest('.delete-btn');
        if (deleteBtnRow) {
            e.preventDefault();
            e.stopPropagation();
            const dealId = deleteBtnRow.dataset.dealId;
            console.log('🗑️ Delete row button clicked (delegated):', dealId);
            if (confirm('Bu fırsatı veritabanından kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.')) {
                await deleteDeal(dealId);
            }
            return;
        }

        const deleteDealBtnModal = e.target.closest('#deleteDealBtn');
        if (deleteDealBtnModal) {
            e.preventDefault();
            e.stopPropagation();
            if (!currentDeal || !currentDeal.id) return;
            console.log('🗑️ Modal delete deal button clicked:', currentDeal.id);
            if (confirm('Bu fırsatı veritabanından kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.')) {
                const dealId = currentDeal.id;
                closeDealModal();
                await deleteDeal(dealId);
            }
            return;
        }
    });

    // Unpublish deal (old modal design - may not exist in new design)
    if (unpublishBtn) {
        unpublishBtn.addEventListener('click', async () => {
            if (!currentDeal) return;
            try {
                await db.collection('deals').doc(currentDeal.id).update({
                    isApproved: false,
                    isExpired: true,
                    status: 'expired',
                    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
                });
                showSuccess('Deal yayından kaldırıldı!');
                dealModal.classList.add('hidden');
                loadDeals();
                updateStats();
            } catch (error) {
                showError('Yayından kaldırma hatası: ' + error.message);
            }
        });
    }

    // Reactivate deal (old modal design - may not exist in new design)
    if (reactivateBtn) {
        reactivateBtn.addEventListener('click', async () => {
            if (!currentDeal) return;
            try {
                await db.collection('deals').doc(currentDeal.id).update({
                    isExpired: false,
                    isApproved: true,
                    isRejected: false,
                    status: 'active',
                    approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
                    updatedAt: firebase.firestore.FieldValue.serverTimestamp()
                });
                showSuccess('Deal yeniden aktifleştirildi!');
                dealModal.classList.add('hidden');
                loadDeals();
                updateStats();
            } catch (error) {
                showError('Aktifleştirme hatası: ' + error.message);
            }
        });
    }

    // Admin message form submit
    const adminMessageForm = document.getElementById('adminMessageForm');
    if (adminMessageForm) {
        adminMessageForm.addEventListener('submit', async (e) => {
            e.preventDefault();

            const userId = adminMessageForm.dataset.userId;
            const titleInput = document.getElementById('adminMessageTitle');
            const contentInput = document.getElementById('adminMessageContent');

            if (!userId || !titleInput || !contentInput) {
                showError('Form verileri eksik!');
                return;
            }

            const title = titleInput.value.trim();
            const content = contentInput.value.trim();

            if (!title || !content) {
                showError('Lütfen başlık ve içerik girin!');
                return;
            }

            await window.sendAdminMessage(userId, title, content);
        });
    }
    
    // Initialise Phase 3 Notifications Center Listeners
    initNotificationEventListeners();
    
    // Initialise Phase 4 Logs Center Listeners
    initLogsEventListeners();
}

// Check if user is admin
async function checkAdmin(uid) {
    try {
        console.log('🔍 Checking admin for UID:', uid);
        console.log('📚 Accessing Firestore users collection...');

        // Önce users koleksiyonunda kontrol et
        let userDoc = await db.collection('users').doc(uid).get();
        console.log('📄 User document exists in users collection:', userDoc.exists);

        // Eğer users koleksiyonunda yoksa, tüm koleksiyonları kontrol et
        if (!userDoc.exists) {
            console.log('🔍 User document not found in users collection, checking all collections...');
            // Tüm koleksiyonları kontrol et (users, userProfiles, vb.)
            const collections = ['users', 'userProfiles', 'profiles'];
            for (const collectionName of collections) {
                const doc = await db.collection(collectionName).doc(uid).get();
                if (doc.exists) {
                    console.log(`✅ Found user document in ${collectionName} collection`);
                    userDoc = doc;
                    break;
                }
            }
        }

        if (userDoc.exists) {
            const data = userDoc.data();
            console.log('📋 User data:', JSON.stringify(data, null, 2));
            console.log('📋 All fields in user document:', Object.keys(data));

            // isAdmin kontrolü - hem boolean true hem de string "true" kontrolü
            // Hem isAdmin (büyük A) hem de isadmin (küçük harf) kontrolü yap
            let isAdmin = false;
            const adminValue = data.isAdmin !== undefined ? data.isAdmin : data.isadmin;
            if (adminValue === true || adminValue === 'true' || adminValue === 1) {
                isAdmin = true;
            }

            console.log('👮 isAdmin field value (büyük A):', data.isAdmin, 'Type:', typeof data.isAdmin);
            console.log('👮 isadmin field value (küçük harf):', data.isadmin, 'Type:', typeof data.isadmin);
            console.log('👮 Final admin check result:', isAdmin);

            // Eğer isAdmin undefined veya false ise, kullanıcıyı bilgilendir
            if (adminValue === undefined) {
                console.warn('⚠️ isAdmin/isadmin field is undefined in user document');
                console.warn('💡 Tip: Firestore Console\'da users/{uid} dokümanına isAdmin: true (boolean) ekleyin');
                console.warn('💡 Kontrol edin: Firebase Console > Firestore Database > users > ' + uid);
                console.warn('💡 isAdmin field\'ını boolean true olarak ekleyin veya güncelleyin');
                console.warn('💡 NOT: Field adı büyük/küçük harfe duyarlıdır! isAdmin (büyük A) kullanın');
            }

            return isAdmin;
        } else {
            console.warn('⚠️ User document does not exist in any collection');
            console.warn('💡 Tip: Kullanıcıyı admin yapmak için Firestore Console\'da users/{uid} dokümanına isAdmin: true ekleyin');
            console.warn('💡 Kontrol edin: Firebase Console > Firestore Database > users > ' + uid);
            // Kullanıcı dokümanı yoksa, admin değildir
            return false;
        }
    } catch (error) {
        console.error('❌ Admin check error:', error);
        console.error('❌ Error details:', error.message, error.code);
        console.error('❌ Error stack:', error.stack);
        return false;
    }
}

// Show login screen
function showLoginScreen() {
    if (loginScreen) {
        loginScreen.classList.remove('hidden');
    }
    if (adminPanel) {
        adminPanel.classList.add('hidden');
    }
}

// Show admin panel
function showAdminPanel() {
    if (loginScreen) {
        loginScreen.classList.add('hidden');
    }
    if (adminPanel) {
        adminPanel.classList.remove('hidden');
    }
    if (currentUser) {
        const userAvatarMobile = document.getElementById('userAvatarMobile');
        if (userAvatarMobile && currentUser.photoURL) {
            userAvatarMobile.src = currentUser.photoURL;
            userAvatarMobile.style.display = 'block';
        }
    }
    // Initialize environment-specific shortcut links
    initCardLinks();
}

// Show error
function showSuccess(message) {
    const errorDiv = document.getElementById('errorMessage');
    if (errorDiv) {
        errorDiv.textContent = message;
        errorDiv.className = 'fixed top-4 right-4 bg-emerald-500 text-white px-6 py-3 rounded-lg shadow-lg z-50 flex items-center gap-2';
        errorDiv.style.display = 'flex';
        errorDiv.innerHTML = `
            <span class="material-symbols-outlined">check_circle</span>
            <span>${escapeHtml(message)}</span>
        `;
        setTimeout(() => {
            errorDiv.style.display = 'none';
        }, 3000);
    } else {
        alert(message);
    }
}

function showError(message) {
    console.error('Showing error message:', message);
    if (loginError) {
        const errorText = loginError.querySelector('p');
        if (errorText) {
            errorText.textContent = message;
        } else {
            loginError.innerHTML = `<p class="text-red-600 dark:text-red-400 text-sm font-medium">${message}</p>`;
        }
        loginError.classList.remove('hidden');
        // 5 saniye sonra gizle
        setTimeout(() => {
            if (loginError) {
                loginError.classList.add('hidden');
            }
        }, 5000);
        setTimeout(() => {
            loginError.classList.add('hidden');
            loginError.classList.remove('show');
        }, 5000);
    } else {
        console.error('Error:', message);
        alert(message);
    }
}



// Load deals
async function loadDeals() {
    try {
        console.log('📦 Loading deals...');

        // Önceki listener'ı temizle
        if (dealsUnsubscribe) {
            console.log('🛑 Unsubscribing from previous deals listener...');
            dealsUnsubscribe();
            dealsUnsubscribe = null;
        }

        if (loadingIndicator) {
            loadingIndicator.style.display = 'block';
            loadingIndicator.textContent = 'Yükleniyor...';
        }
        if (emptyState) emptyState.classList.add('hidden');

        // Real-time listener ekle
        console.log('👂 Setting up real-time listener for deals...');
        // Index gerektirmemek için önce tüm deal'leri al, sonra client-side'da sırala
        dealsUnsubscribe = db.collection('deals')
            .limit(500)
            .onSnapshot((snapshot) => {
                console.log('🔄 Real-time update received! Snapshot size:', snapshot.size);

                deals = snapshot.docs.map(doc => {
                    const data = doc.data();
                    // Bot 'timestamp' yazıyor, eski kodlar 'createdAt' kullanıyor - her ikisini de destekle
                    const createdAtValue = data.timestamp || data.createdAt;
                    let createdAt;
                    if (createdAtValue?.toDate) {
                        createdAt = createdAtValue.toDate();
                    } else if (createdAtValue instanceof Date) {
                        createdAt = createdAtValue;
                    } else if (createdAtValue) {
                        try {
                            createdAt = new Date(createdAtValue);
                        } catch (e) {
                            console.warn('Invalid date for deal:', doc.id, createdAtValue);
                            createdAt = new Date();
                        }
                    } else {
                        createdAt = new Date();
                    }

                    // Bot 'image_url' ve 'url' yazıyor, eski kodlar 'imageUrl' ve 'link' kullanıyor - her ikisini de destekle
                    const normalizedData = {
                        ...data,
                        // image_url varsa imageUrl'e de kopyala
                        imageUrl: data.image_url || data.imageUrl || '',
                        // url varsa link'e de kopyala
                        link: data.url || data.link || '',
                    };

                    return {
                        id: doc.id,
                        ...normalizedData,
                        createdAt: createdAt,
                        isApproved: data.isApproved === true
                    };
                });

                // Client-side'da tarihe göre sırala (yeni önce)
                deals.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());

                console.log('📊 Total deals:', deals.length);
                console.log('⏳ Pending deals:', deals.filter(d => !d.isApproved && d.isRejected !== true && d.isExpired !== true).length);
                console.log('✅ Approved deals:', deals.filter(d => d.isApproved).length);

                if (deals.length === 0) {
                    console.log('📭 No deals found');
                    if (emptyState) {
                        emptyState.classList.remove('hidden');
                        emptyState.textContent = 'Henüz deal yok';
                    }
                } else {
                    renderDeals();
                    updateStats();
                    if (currentView === 'dashboard') {
                        loadDashboardData();
                    }
                }

                if (loadingIndicator) loadingIndicator.style.display = 'none';
            }, (error) => {
                console.error('❌ Real-time listener error:', error);
                console.error('❌ Error details:', error.message, error.stack);
                if (loadingIndicator) {
                    loadingIndicator.textContent = 'Hata: ' + error.message;
                }
                showError('Deal\'ler dinlenirken hata oluştu: ' + error.message);
            });

        console.log('✅ Real-time listener set up successfully');
    } catch (error) {
        console.error('❌ Load deals error:', error);
        console.error('❌ Error details:', error.message, error.stack);
        if (loadingIndicator) {
            loadingIndicator.textContent = 'Hata: ' + error.message;
        }
        showError('Deal\'ler yüklenirken hata oluştu: ' + error.message);
    }
}

// Render deals
function renderDeals() {
    if (!dealsList) {
        console.warn('⚠️ dealsList bulunamadı, renderDeals atlanıyor');
        return;
    }

    console.log('🎨 renderDeals çağrıldı, currentFilter:', currentFilter, 'toplam deal sayısı:', deals.length);

    // 1. Filter by status (currentFilter)
    let filteredDeals = deals;
    if (currentFilter === 'pending') {
        filteredDeals = deals.filter(d => d.isApproved === false && d.isRejected !== true && d.isExpired !== true && d.status !== 'expired' && d.status !== 'rejected');
    } else if (currentFilter === 'approved') {
        filteredDeals = deals.filter(d => d.isApproved === true && d.isExpired !== true && d.status !== 'expired' && d.isRejected !== true && d.status !== 'rejected');
    } else if (currentFilter === 'expired') {
        filteredDeals = deals.filter(d => d.isExpired === true || d.status === 'expired');
    }

    // 2. Filter by Category
    const categoryFilterEl = document.getElementById('categoryFilter');
    if (categoryFilterEl) {
        const categoryVal = categoryFilterEl.value;
        if (categoryVal && categoryVal !== 'all') {
            filteredDeals = filteredDeals.filter(d => d.category === categoryVal);
        }
    }

    // 3. Filter by Source (bot / user)
    const sourceFilterEl = document.getElementById('sourceFilter');
    if (sourceFilterEl) {
        const sourceVal = sourceFilterEl.value;
        if (sourceVal === 'bot') {
            filteredDeals = filteredDeals.filter(d => !d.isUserSubmitted);
        } else if (sourceVal === 'user') {
            filteredDeals = filteredDeals.filter(d => d.isUserSubmitted === true);
        }
    }

    // 4. Search input filter (if searchInput has value)
    const searchInput = document.getElementById('searchInput');
    if (searchInput) {
        const query = searchInput.value.trim().toLowerCase();
        if (query) {
            filteredDeals = filteredDeals.filter(d => {
                const title = (d.title || '').toLowerCase();
                const store = (d.store || '').toLowerCase();
                const brand = (d.brand || '').toLowerCase();
                const id = (d.id || '').toLowerCase();
                return title.includes(query) || store.includes(query) || brand.includes(query) || id.includes(query);
            });
        }
    }

    // 5. Sorting
    const sortSelectEl = document.getElementById('sortSelect');
    if (sortSelectEl) {
        const sortVal = sortSelectEl.value;
        if (sortVal === 'newest') {
            filteredDeals.sort((a, b) => b.createdAt.getTime() - a.createdAt.getTime());
        } else if (sortVal === 'oldest') {
            filteredDeals.sort((a, b) => a.createdAt.getTime() - b.createdAt.getTime());
        } else if (sortVal === 'price_asc') {
            filteredDeals.sort((a, b) => (a.price || 0) - (b.price || 0));
        } else if (sortVal === 'price_desc') {
            filteredDeals.sort((a, b) => (b.price || 0) - (a.price || 0));
        }
    }

    dealsList.innerHTML = '';

    if (filteredDeals.length === 0) {
        if (emptyState) emptyState.classList.remove('hidden');
        if (loadingIndicator) loadingIndicator.style.display = 'none';
        return;
    }

    if (emptyState) emptyState.classList.add('hidden');
    if (loadingIndicator) loadingIndicator.style.display = 'none';

    filteredDeals.forEach(deal => {
        const row = createDealRow(deal);
        dealsList.appendChild(row);
    });
}

// Rozet ve Özel Fiyat Etiketi (priceLabel) HTML üretici
function getPriceBadgeHtml(priceLabel, store = '') {
    if (!priceLabel || priceLabel.trim() === '') {
        return '<span class="text-xs italic text-slate-400 dark:text-slate-500">Rozet Yok (Standart Ürün)</span>';
    }
    const label = priceLabel.trim();
    const labelUpper = label.toUpperCase();
    const storeLower = (store || '').toLowerCase();
    
    if (labelUpper.includes('MONEY') || storeLower.includes('migros')) {
        return `
            <div class="inline-flex items-center gap-1.5 px-3 py-1 rounded-full border border-amber-300 bg-gradient-to-r from-amber-400 via-amber-500 to-amber-500 text-amber-950 text-xs font-bold shadow-sm" style="box-shadow: 0 2px 8px rgba(245, 158, 11, 0.35);">
                <img src="../assets/money.webp" class="w-4 h-4 rounded-full object-cover shadow-sm ring-1 ring-black/20" onerror="this.outerHTML='<span class=\\'inline-flex items-center justify-center w-4 h-4 rounded-full bg-amber-950 text-[10px] text-amber-400 font-bold\\'>M</span>';"/>
                <span class="tracking-tight text-amber-950 font-bold">${escapeHtml(label)}</span>
            </div>
        `;
    }

    let emblem = 'P';
    if (labelUpper.includes('PLUS') || storeLower.includes('trendyol') || storeLower.includes('pazarama')) {
        emblem = '+';
    } else if (labelUpper.includes('PRIME') || labelUpper.includes('PREMIUM')) {
        emblem = 'P';
    }
    
    return `
        <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-md border border-purple-500/30 bg-purple-500/10 text-purple-700 dark:text-purple-300 text-xs font-bold shadow-sm">
            <span class="inline-flex items-center justify-center w-4 h-4 rounded-full text-[10px] font-black text-white" style="background: linear-gradient(135deg, #FF6000, #8B5CF6); line-height: 1;">${emblem}</span>
            <span>${escapeHtml(label)}</span>
        </div>
    `;
}

// Create deal table row
function createDealRow(deal) {
    const row = document.createElement('tr');
    row.className = 'group hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer';

    const isApproved = deal.isApproved === true;
    const isUserSubmitted = deal.isUserSubmitted === true;

    // Status badge
    let statusBadge = '';
    if (deal.isExpired === true || deal.status === 'expired') {
        statusBadge = '<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-slate-500/20 bg-slate-500/10 text-slate-600 dark:text-slate-400 text-xs font-medium"><span class="inline-block w-1.5 h-1.5 rounded-full bg-slate-500"></span>Süresi Doldu</div>';
    } else if (deal.isRejected === true || deal.status === 'rejected') {
        statusBadge = '<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-rose-500/20 bg-rose-500/10 text-rose-600 dark:text-rose-400 text-xs font-medium"><span class="inline-block w-1.5 h-1.5 rounded-full bg-rose-500"></span>Reddedildi</div>';
    } else if (isApproved) {
        statusBadge = '<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-emerald-500/20 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 text-xs font-medium"><span class="inline-block w-1.5 h-1.5 rounded-full bg-emerald-500"></span>Aktif</div>';
    } else {
        statusBadge = '<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-amber-500/20 bg-amber-500/10 text-amber-600 dark:text-amber-400 text-xs font-medium"><span class="inline-block w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse"></span>Bekliyor</div>';
    }

    // Kaynak (Source) Badge Hazırlığı
    let sourceBadge = '';
    const postedByRaw = deal.postedBy || '';

    if (isUserSubmitted) {
        // Kullanıcı paylaşımı
        let initialUserLabel = postedByRaw;
        if (dealUserCache.has(postedByRaw)) {
            initialUserLabel = dealUserCache.get(postedByRaw);
        } else if (typeof users !== 'undefined' && Array.isArray(users) && users.length > 0) {
            const found = users.find(u => u.id === postedByRaw || u.uid === postedByRaw);
            if (found) {
                initialUserLabel = found.nickname || found.username || found.displayName || found.email || postedByRaw;
                dealUserCache.set(postedByRaw, initialUserLabel);
            }
        }

        const displayLabel = (initialUserLabel.length > 18 && !initialUserLabel.includes('@') && !initialUserLabel.includes(' '))
            ? initialUserLabel.substring(0, 8) + '...'
            : initialUserLabel;

        sourceBadge = `
            <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-purple-500/20 bg-purple-500/10 text-purple-600 dark:text-purple-400 text-xs font-semibold" title="${escapeHtml(initialUserLabel)}">
                <span class="material-symbols-outlined text-[14px]">person</span>
                <span class="deal-user-source-label truncate max-w-[120px]" data-uid="${escapeHtml(postedByRaw)}">${escapeHtml(displayLabel)}</span>
            </div>
        `;
    } else {
        // Bot paylaşımı (Telegram Kanalları)
        let channelName = '';
        if (deal.telegramChatTitle) {
            channelName = deal.telegramChatTitle;
        } else if (deal.telegramChatUsername) {
            channelName = deal.telegramChatUsername.startsWith('@') ? deal.telegramChatUsername : `@${deal.telegramChatUsername}`;
        } else if (postedByRaw.startsWith('telegram_')) {
            channelName = `@${postedByRaw.replace('telegram_', '')}`;
        } else if (postedByRaw && postedByRaw !== 'admin' && postedByRaw !== 'Bilinmiyor') {
            channelName = postedByRaw;
        } else {
            channelName = 'Bot (Genel)';
        }

        sourceBadge = `
            <div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-blue-500/20 bg-blue-500/10 text-blue-600 dark:text-blue-400 text-xs font-semibold" title="${escapeHtml(channelName)}">
                <span class="material-symbols-outlined text-[14px]">smart_toy</span>
                <span class="truncate max-w-[120px]">${escapeHtml(channelName)}</span>
            </div>
        `;
    }

    // Image URL - Bot 'image_url' yazıyor, eski kodlar 'imageUrl' kullanıyor - her ikisini de destekle
    let imageUrl = deal.image_url || deal.imageUrl || '';
    if (imageUrl && typeof imageUrl === 'string' && imageUrl.trim() !== '') {
        if (imageUrl.startsWith('blob:') || imageUrl.startsWith('data:') || imageUrl.trim() === '') {
            imageUrl = '';
        } else {
            imageUrl = imageUrl.trim();
            if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
                imageUrl = 'https://' + imageUrl;
            }
        }
    } else {
        imageUrl = '';
    }

    // Date formatting
    const createdAtFull = deal.createdAt ? formatFullDateTime(deal.createdAt) : 'Bilinmiyor';
    const timeAgo = deal.createdAt ? getTimeAgo(deal.createdAt) : 'Bilinmiyor';

    // Price
    const price = deal.price || 0;
    const originalPrice = deal.originalPrice || deal.original_price || 0;
    const discount = (originalPrice > price && price > 0) ? Math.round(((originalPrice - price) / originalPrice) * 100) : (deal.discountRate || deal.discount_rate || deal.discount || 0);

    // Image HTML - Web için optimize edilmiş görsel gösterimi, daha net görünüm için object-contain
    const imageHtml = imageUrl && imageUrl.trim() !== ''
        ? `<img alt="Product thumbnail" class="w-full h-full object-contain rounded transition-opacity duration-200 hover:opacity-90" src="${escapeHtml(imageUrl)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';" loading="lazy" style="max-width: 100%; max-height: 100%; object-position: center;"><div style="display:none; width:100%; height:100%; align-items:center; justify-content:center; background:linear-gradient(135deg, #f5f5f5 0%, #e5e5e5 100%); color:#999; font-size:18px;">📷</div>`
        : `<div style="width:100%; height:100%; display:flex; align-items:center; justify-content:center; background:linear-gradient(135deg, #f5f5f5 0%, #e5e5e5 100%); color:#999; font-size:18px;">📷</div>`;

    row.innerHTML = `
        <td class="p-4 text-center">
            <input class="rounded border-slate-300 dark:border-slate-600 bg-slate-100 dark:bg-surface-dark text-primary focus:ring-primary h-4 w-4" type="checkbox"/>
        </td>
        <td class="p-4">
            <div class="flex gap-3 items-center">
                <div class="w-20 h-20 shrink-0 rounded-lg bg-slate-100 dark:bg-slate-800 border border-slate-200 dark:border-slate-700 flex items-center justify-center overflow-hidden shadow-sm hover:shadow-md transition-shadow">
                    ${imageHtml}
                </div>
                <div class="flex flex-col gap-0.5 min-w-0 flex-1">
                    <p class="text-slate-900 dark:text-white font-medium line-clamp-2 leading-tight">${escapeHtml(deal.title || 'Başlıksız')}</p>
                    <p class="text-slate-500 dark:text-slate-400 text-xs mt-0.5">
                        ${escapeHtml(deal.category || 'Genel')} • ${escapeHtml(deal.store || 'Bilinmeyen')}
                        ${deal.brand ? ` • <span class="font-semibold text-slate-700 dark:text-slate-300">Marka: ${escapeHtml(deal.brand)}</span>` : ''}
                        ${deal.priceLabel ? (
                            (deal.priceLabel.toUpperCase().includes('MONEY') || (deal.store && deal.store.toLowerCase().includes('migros')))
                            ? ` • <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold border border-amber-300 bg-gradient-to-r from-amber-400 to-amber-500 text-amber-950 shadow-sm" style="box-shadow: 0 1px 4px rgba(245, 158, 11, 0.3);"><img src="../assets/money.webp" class="w-3.5 h-3.5 rounded-full object-cover ring-1 ring-black/20" onerror="this.outerHTML='<span class=\\'inline-flex items-center justify-center w-2.5 h-2.5 rounded-full bg-amber-950 text-[7px] text-amber-400\\'>M</span>';"/><span class="font-bold text-amber-950">${escapeHtml(deal.priceLabel)}</span></span>`
                            : ` • <span class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-extrabold bg-purple-100 dark:bg-purple-900/30 text-purple-700 dark:text-purple-300 border border-purple-300 dark:border-purple-600/40"><span class="inline-flex items-center justify-center w-2.5 h-2.5 rounded-full text-[7px] text-white" style="background:linear-gradient(135deg,#FF6000,#8B5CF6);line-height:1;">${deal.priceLabel.toUpperCase().includes('PLUS') ? '+' : 'P'}</span>${escapeHtml(deal.priceLabel)}</span>`
                        ) : ''}
                        ${deal.isAmazonWarehouse ? ` • <span class="inline-flex items-center gap-1 px-1.5 py-0.5 rounded text-[10px] font-extrabold bg-amber-100 dark:bg-amber-500/15 text-amber-700 dark:text-amber-400 border border-amber-300 dark:border-amber-600/40"><span class="material-symbols-outlined text-[12px]">inventory_2</span>Depo</span>` : ''}
                    </p>
                    ${(deal.ratingValue || deal.ratingCount) ? `
                        <div class="flex items-center gap-1 text-amber-500 font-bold text-xs mt-0.5">
                            <span class="material-symbols-outlined text-[14px]">star</span>
                            <span>${deal.ratingValue != null ? deal.ratingValue : '-'}</span>
                            <span class="text-slate-400 font-normal">(${deal.ratingCount != null ? deal.ratingCount : 0})</span>
                        </div>
                    ` : ''}
                </div>
            </div>
        </td>
        <td class="p-4">
            ${sourceBadge}
        </td>
        <td class="p-4">
            ${deal.hidePrice ? `
                <span class="inline-flex items-center gap-1 px-2 py-1 rounded text-xs font-semibold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 border border-slate-200 dark:border-slate-700">
                    <span class="material-symbols-outlined text-[14px]">visibility_off</span>Fiyat Gizli
                </span>
            ` : `
                <p class="text-slate-900 dark:text-white font-bold">${price.toLocaleString('tr-TR')} TL</p>
                ${originalPrice > price ? `<p class="text-slate-400 text-xs line-through">${originalPrice.toLocaleString('tr-TR')} TL</p>` : ''}
            `}
        </td>
        <td class="p-4">
            ${(!deal.hidePrice && discount > 0) ? `<span class="text-emerald-600 dark:text-emerald-400 font-bold bg-emerald-100 dark:bg-emerald-500/10 px-2 py-1 rounded text-xs">%${discount} İndirim</span>` : '<span class="text-slate-400 text-xs">-</span>'}
        </td>
        <td class="p-4">
            <div class="flex items-center gap-1.5 text-slate-800 dark:text-slate-200 font-semibold text-xs whitespace-nowrap">
                <span class="material-symbols-outlined text-[15px] text-primary">schedule</span>
                <span>${timeAgo}</span>
            </div>
            <p class="text-slate-500 dark:text-slate-400 text-[11px] mt-0.5 whitespace-nowrap font-medium">${createdAtFull}</p>
        </td>
        <td class="p-4">${statusBadge}</td>
        <td class="p-4 text-right">
            <div class="flex items-center justify-end gap-1.5 opacity-100 sm:opacity-0 group-hover:opacity-100 transition-opacity">
                ${(!isApproved && !deal.isExpired && deal.status !== 'expired' && !deal.isRejected && deal.status !== 'rejected') ? `<button class="approve-btn p-2 rounded-lg text-emerald-500 hover:bg-emerald-500/10 hover:text-emerald-400 transition-colors" title="Onayla" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">check</span></button>` : ''}
                ${(isApproved && !deal.isExpired && deal.status !== 'expired') ? `<button class="unpublish-btn p-2 rounded-lg text-amber-500 hover:bg-amber-500/10 hover:text-amber-400 transition-colors" title="Yayından Kaldır" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">visibility_off</span></button>` : ''}
                ${(deal.isExpired === true || deal.status === 'expired') ? `<button class="reactivate-btn p-2 rounded-lg text-emerald-500 hover:bg-emerald-500/10 hover:text-emerald-400 transition-colors" title="Tekrar Yayına Al" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">play_circle</span></button>` : ''}
                <button class="edit-btn p-2 rounded-lg text-slate-400 hover:bg-slate-700 hover:text-white transition-colors" title="Düzenle" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">edit</span></button>
                ${(!deal.isRejected && deal.status !== 'rejected') ? `<button class="reject-btn p-2 rounded-lg text-rose-500 hover:bg-rose-500/10 hover:text-rose-400 transition-colors" title="Reddet" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">block</span></button>` : ''}
                <button class="delete-btn p-2 rounded-lg text-slate-400 hover:bg-rose-500/10 hover:text-rose-500 transition-colors" title="Kalıcı Sil" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">delete</span></button>
            </div>
        </td>
    `;

    // Eğer kullanıcı fırsatı ise ve kullanıcı ismi henüz UID durumundaysa asenkron çöz
    if (isUserSubmitted && postedByRaw && postedByRaw !== 'admin' && postedByRaw !== 'Bilinmiyor') {
        setTimeout(async () => {
            const userLabel = await getUserDisplayLabel(postedByRaw);
            if (userLabel && userLabel !== postedByRaw) {
                const labelSpan = row.querySelector('.deal-user-source-label');
                if (labelSpan) {
                    const displayLabel = (userLabel.length > 18 && !userLabel.includes('@') && !userLabel.includes(' '))
                        ? userLabel.substring(0, 8) + '...'
                        : userLabel;
                    labelSpan.textContent = displayLabel;
                    labelSpan.closest('[title]')?.setAttribute('title', userLabel);
                }
            }
        }, 30);
    }

    // Click event for row
    row.addEventListener('click', async (e) => {
        if (e.target.closest('button') || e.target.closest('input')) return;
        await showDealModal(deal);
    });

    return row;
}

// Helper functions
function formatFullDateTime(date) {
    if (!date) return 'Bilinmiyor';
    let d;
    if (date instanceof Date) {
        d = date;
    } else if (date && typeof date.toDate === 'function') {
        d = date.toDate();
    } else {
        d = new Date(date);
    }
    if (isNaN(d.getTime())) return 'Bilinmiyor';
    return d.toLocaleDateString('tr-TR', {
        day: '2-digit',
        month: '2-digit',
        year: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

function getTimeAgo(date) {
    if (!date) return 'Bilinmiyor';
    let d;
    if (date instanceof Date) {
        d = date;
    } else if (date && typeof date.toDate === 'function') {
        d = date.toDate();
    } else {
        d = new Date(date);
    }
    if (isNaN(d.getTime())) return 'Bilinmiyor';
    const now = new Date();
    const diff = now - d;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(minutes / 60);
    const days = Math.floor(hours / 24);

    if (minutes < 1) return 'Az önce';
    if (minutes < 60) return `${minutes} Dakika Önce`;
    if (hours < 24) return `${hours} Saat Önce`;
    return `${days} Gün Önce`;
}

async function approveDeal(dealId) {
    try {
        // Deal'i önce getir
        const dealDoc = await db.collection('deals').doc(dealId).get();
        if (!dealDoc.exists) {
            showError('Deal bulunamadı!');
            return;
        }

        const dealData = dealDoc.data();
        let currentUrl = dealData.url || dealData.link || '';

        // Fast-Path: Link zaten hazır bir affiliate linki ise tekrar çözme veya dönüştürme yapma
        let finalUrl = currentUrl;
        const isAlreadyAffiliate = Boolean(currentUrl && typeof AffiliateManager !== 'undefined' && typeof AffiliateManager.isAlreadyAffiliate === 'function' && AffiliateManager.isAlreadyAffiliate(currentUrl, typeof affiliateConfig !== 'undefined' ? affiliateConfig : null));

        if (isAlreadyAffiliate) {
            console.log('⚡ [Fast-Path] Link zaten hazır affiliate linki, mükerrer hesaplama yapılmadı:', currentUrl);
        } else if (currentUrl) {
            // Emniyet Ağı (Safety Net): Yalnızca organik/kısa link kalmışsa çöz ve dönüştür
            try {
                const url = new URL(currentUrl);
                const hostname = url.hostname.toLowerCase();
                const isShortlink = hostname.includes('hb.biz') ||
                    hostname.includes('app.hb.biz') ||
                    hostname.includes('paylaskazan.teknosa.com') ||
                    hostname.includes('ty.gl') ||
                    hostname.includes('sl.n11.com') ||
                    hostname.includes('amzn.to') ||
                    hostname.includes('amzn.eu') ||
                    hostname.includes('link.amazon') ||
                    hostname.includes('bit.ly') ||
                    hostname.includes('tinyurl.com');

                if (isShortlink) {
                    console.log('🔄 Kısa link tespit edildi, çözülüyor...', currentUrl);
                    try {
                        const functionsUrl = `https://us-central1-${firebaseConfig.projectId}.cloudfunctions.net/resolveShortLink`;
                        const response = await fetch(`${functionsUrl}?url=${encodeURIComponent(currentUrl)}`);
                        const data = await response.json();

                        if (data.success && data.resolvedUrl) {
                            currentUrl = data.resolvedUrl;
                            console.log('✅ Kısa link çözüldü:', currentUrl);
                        } else {
                            console.warn('⚠️ Kısa link çözülemedi, orijinal link kullanılıyor');
                        }
                    } catch (error) {
                        console.error('❌ Kısa link çözme hatası:', error);
                    }
                }
            } catch (e) {
                // URL parse hatası, devam et
            }

            // Affiliate link'e dönüştür (eğer yapılandırılmışsa)
            let convertedUrl = convertToAffiliateLink(currentUrl);
            if (convertedUrl !== currentUrl) {
                finalUrl = convertedUrl;
                console.log('✅ Emniyet Ağı: Affiliate link\'e dönüştürüldü:', finalUrl);
            }
        }

        // Deal'i güncelle
        const updateData = {
            isApproved: true,
            isRejected: false,
            isExpired: false,
            status: 'active',
            approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        };

        // Eğer link dönüştürüldüyse güncelle
        if (finalUrl !== currentUrl) {
            updateData.url = finalUrl;
            updateData.link = finalUrl;
        }

        // cleanUrl eksikse ve organik link çıkarılabiliyorsa güncelle
        if (!dealData.cleanUrl) {
            const clean = cleanProductUrl(currentUrl);
            if (clean && !clean.includes('btrck.com')) {
                updateData.cleanUrl = clean;
            }
        }

        await db.collection('deals').doc(dealId).update(updateData);
        showSuccess('Deal onaylandı' + (finalUrl !== currentUrl ? ' ve affiliate link\'e dönüştürüldü!' : '!'));
        loadDeals();
        updateStats();
    } catch (error) {
        showError('Onaylama hatası: ' + error.message);
    }
}

async function rejectDeal(dealId) {
    try {
        await db.collection('deals').doc(dealId).update({
            isApproved: false,
            isRejected: true,
            isExpired: true,
            status: 'rejected',
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        showSuccess('Fırsat reddedildi!');
        loadDeals();
        updateStats();
    } catch (error) {
        showError('Reddetme hatası: ' + error.message);
    }
}

async function unpublishDeal(dealId) {
    try {
        await db.collection('deals').doc(dealId).update({
            isExpired: true,
            status: 'expired',
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        showSuccess('Fırsat yayından kaldırıldı ve süresi bitenler bölümüne taşındı!');
        loadDeals();
        updateStats();
    } catch (error) {
        showError('Yayından kaldırma hatası: ' + error.message);
    }
}

async function reactivateDeal(dealId) {
    try {
        await db.collection('deals').doc(dealId).update({
            isApproved: true,
            isRejected: false,
            isExpired: false,
            status: 'active',
            approvedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        showSuccess('Fırsat başarıyla tekrar yayına alındı!');
        loadDeals();
        updateStats();
    } catch (error) {
        showError('Tekrar yayına alma hatası: ' + error.message);
    }
}

async function deleteDeal(dealId) {
    try {
        await db.collection('deals').doc(dealId).delete();
        showSuccess('Fırsat veritabanından başarıyla silindi!');
        loadDeals();
        updateStats();
    } catch (error) {
        showError('Silme hatası: ' + error.message);
    }
}

// Affiliate Link Dönüştürme Fonksiyonları (Modüler AffiliateManager üzerinden)
function convertToAffiliateLink(originalUrl) {
    if (typeof AffiliateManager !== 'undefined') {
        return AffiliateManager.convert(originalUrl, affiliateConfig);
    }
    return originalUrl;
}

function detectStoreFromUrl(url) {
    if (typeof AffiliateManager !== 'undefined') {
        return AffiliateManager.detectStore(url);
    }
    return 'Bilinmeyen';
}

function cleanProductUrl(url) {
    if (typeof AffiliateManager !== 'undefined' && typeof AffiliateManager.cleanProductUrl === 'function') {
        return AffiliateManager.cleanProductUrl(url);
    }
    return url || '';
}

function isAffiliateSupportedStore(storeOrUrl) {
    if (typeof AffiliateManager !== 'undefined' && typeof AffiliateManager.isStoreSupported === 'function') {
        return AffiliateManager.isStoreSupported(storeOrUrl, typeof affiliateConfig !== 'undefined' ? affiliateConfig : null);
    }
    return false;
}

// Show deal modal
async function showDealModal(deal) {
    // Modal açılmadan önce mevcut view'ı kaydet
    previousView = currentView;
    currentDeal = deal;

    const createdAt = deal.createdAt ? `${formatFullDateTime(deal.createdAt)} (${getTimeAgo(deal.createdAt)})` : 'Bilinmiyor';
    const postedBy = deal.postedBy || 'Bilinmiyor';
    const isApproved = deal.isApproved === true;
    const isUserSubmitted = deal.isUserSubmitted === true;
    const isAffiliateSupported = isAffiliateSupportedStore(deal.store) ||
        isAffiliateSupportedStore(deal.cleanUrl) ||
        isAffiliateSupportedStore(deal.url) ||
        isAffiliateSupportedStore(deal.link);

    // Affiliate link ve temiz URL hesaplama (Teknosa ve Hepsiburada gibi affiliate destekli mağazalar için otomatik hazır hale getirme)
    let initialCleanUrl = deal.cleanUrl || cleanProductUrl(deal.url || deal.link || '');
    let initialAffiliateUrl = deal.url || deal.link || '';

    if (isAffiliateSupported) {
        // Eğer affiliateUrl henüz hazır affiliate linki değilse veya boşsa, otomatik olarak affiliate link üret
        const isAlreadyAffiliate = Boolean(initialAffiliateUrl && typeof AffiliateManager !== 'undefined' && typeof AffiliateManager.isAlreadyAffiliate === 'function' && AffiliateManager.isAlreadyAffiliate(initialAffiliateUrl, affiliateConfig));
        if (!initialAffiliateUrl || !isAlreadyAffiliate) {
            const sourceUrl = (initialCleanUrl && !initialCleanUrl.includes('btrck.com') && !initialCleanUrl.includes('7t4g.adj.st'))
                ? initialCleanUrl
                : (initialAffiliateUrl || '');
            if (sourceUrl) {
                let converted = convertToAffiliateLink(sourceUrl);
                if (converted && converted !== sourceUrl) {
                    initialAffiliateUrl = converted;
                }
            }
        }
        // Eğer cleanUrl boşsa veya affiliate linki ise, temiz linki unwrap et
        if (!initialCleanUrl || initialCleanUrl.includes('btrck.com') || initialCleanUrl.includes('7t4g.adj.st') || initialCleanUrl.includes('adj.st')) {
            const unwrap = cleanProductUrl(initialCleanUrl || initialAffiliateUrl);
            if (unwrap && !unwrap.includes('btrck.com') && !unwrap.includes('7t4g.adj.st')) {
                initialCleanUrl = unwrap;
            }
        }
    } else {
        // Affiliate kapalı veya desteklenmeyen mağaza: Her iki linki de temiz kanonik ürün URL'sine unwrap et
        initialCleanUrl = cleanProductUrl(initialCleanUrl || initialAffiliateUrl);
        initialAffiliateUrl = initialCleanUrl;
    }

    // Kullanıcı bilgilerini Firestore'dan çek (eğer kullanıcı tarafından paylaşıldıysa)
    let userDisplayName = 'Bot';
    let userProfileImage = null;
    if (isUserSubmitted && postedBy && postedBy !== 'Bilinmiyor') {
        try {
            const userDoc = await db.collection('users').doc(postedBy).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                userDisplayName = userData.nickname || userData.username || 'Kullanıcı';
                userProfileImage = cleanProfileImageUrl(userData.profileImageUrl) || null;
                console.log('✅ Kullanıcı bilgileri yüklendi:', userDisplayName);
            } else {
                console.warn('⚠️ Kullanıcı bulunamadı:', postedBy);
            }
        } catch (error) {
            console.error('❌ Kullanıcı bilgileri yüklenirken hata:', error);
        }
    }

    // Görsel URL'lerini kontrol et (imageUrls array veya imageUrl/image_url string)
    // Bot 'image_url' yazıyor, eski kodlar 'imageUrl' kullanıyor - her ikisini de destekle
    let imageUrls = [];
    if (deal.imageUrls && Array.isArray(deal.imageUrls) && deal.imageUrls.length > 0) {
        imageUrls = deal.imageUrls.filter(url => url && typeof url === 'string' && url.trim() !== '' && !url.startsWith('blob:') && !url.startsWith('data:'));
    } else {
        // Önce image_url'i kontrol et (bot'un yazdığı), sonra imageUrl'i (eski kodlar)
        const imageUrlValue = deal.image_url || deal.imageUrl;
        if (imageUrlValue && typeof imageUrlValue === 'string' && imageUrlValue.trim() !== '') {
            let imageUrl = imageUrlValue;
            if (imageUrl.startsWith('blob:') || imageUrl.startsWith('data:')) {
                imageUrl = '';
            } else {
                if (!imageUrl.startsWith('http://') && !imageUrl.startsWith('https://')) {
                    imageUrl = 'https://' + imageUrl;
                }
                imageUrls = [imageUrl];
            }
        }
    }

    // Ana görsel (ilk görsel)
    const mainImageUrl = imageUrls.length > 0 ? imageUrls[0] : '';
    // İkinci görsel (varsa)
    const secondImageUrl = imageUrls.length > 1 ? imageUrls[1] : '';

    // Fiyat hesaplamaları
    const price = deal.price || 0;
    const originalPrice = deal.originalPrice || deal.original_price || '';
    const discount = (originalPrice > price && price > 0) ? Math.round(((originalPrice - price) / originalPrice) * 100) : (deal.discountRate || deal.discount_rate || deal.discount || 0);

    // Status seçimi
    let statusValue = 'pending';
    if (isApproved) {
        statusValue = 'active';
    }

    // Kategori ve alt kategori hazırlığı
    const dealCategory = deal.category || 'elektronik';
    const subcategories = categoriesConfig[dealCategory] || [];
    let subcategoryOptionsHtml = '<option value="">Alt Kategori Yok</option>';
    subcategories.forEach(sub => {
        const isSelected = (deal.subCategory || deal.subcategory) === sub ? 'selected' : '';
        subcategoryOptionsHtml += `<option value="${escapeHtml(sub)}" ${isSelected}>${escapeHtml(sub)}</option>`;
    });

    // Görsel HTML - Web için optimize edilmiş, daha küçük ve net, tıklanabilir
    const mainImageHtml = mainImageUrl && mainImageUrl.trim() !== ''
        ? `<img alt="${escapeHtml(deal.title)}" class="w-full h-full object-contain group-hover:scale-105 transition-transform duration-500 cursor-zoom-in" src="${escapeHtml(mainImageUrl)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';" loading="lazy" style="object-position: center; max-width: 100%; max-height: 100%; pointer-events: auto;"><div style="display:none; width:100%; height:100%; align-items:center; justify-content:center; background:linear-gradient(135deg, #f5f5f5 0%, #e5e5e5 100%); color:#999; font-size:32px;">📷</div>`
        : `<div style="width:100%; height:100%; display:flex; align-items:center; justify-content:center; background:linear-gradient(135deg, #f5f5f5 0%, #e5e5e5 100%); color:#999; font-size:32px;">📷</div>`;

    // İkinci görsel HTML
    const secondImageHtml = secondImageUrl && secondImageUrl.trim() !== ''
        ? `<img alt="${escapeHtml(deal.title)}" class="w-full h-full object-contain rounded-lg transition-opacity duration-200 hover:opacity-90 cursor-zoom-in" src="${escapeHtml(secondImageUrl)}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';" loading="lazy" style="object-position: center; max-width: 100%; max-height: 100%; pointer-events: auto;"><div style="display:none; width:100%; height:100%; align-items:center; justify-content:center; background:linear-gradient(135deg, #f5f5f5 0%, #e5e5e5 100%); color:#999; font-size:20px;">📷</div>`
        : `<div style="width:100%; height:100%; display:flex; align-items:center; justify-content:center; background:linear-gradient(135deg, #f5f5f5 0%, #e5e5e5 100%); color:#999; font-size:20px;">📷</div>`;

    // Modal Body (Sol Kolon)
    const modalBodyEl = document.getElementById('modalBody');
    if (modalBodyEl) {
        modalBodyEl.innerHTML = `
            <!-- Images Section -->
            <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 overflow-hidden p-5 shadow-sm">
                <div class="flex justify-between items-center mb-4">
                    <h3 class="text-lg font-bold text-gray-900 dark:text-white">Görseller</h3>
                </div>
                <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
                    <!-- Main Hero Image -->
                    <div class="sm:col-span-2 relative group rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800 cursor-zoom-in" style="max-height: 400px; min-height: 300px;" data-image-url="${mainImageUrl ? escapeHtml(mainImageUrl) : ''}" id="mainImageContainer">
                        <div class="w-full h-full pointer-events-auto">
                            ${mainImageHtml}
                        </div>
                        <!-- Edit butonu sağ üst köşede -->
                        <button class="absolute top-2 right-2 p-2 bg-black/60 hover:bg-black/80 backdrop-blur-sm rounded-full text-white transition-all opacity-0 group-hover:opacity-100 pointer-events-auto z-20" type="button" title="Görseli Düzenle">
                            <span class="material-symbols-outlined text-[18px]">edit</span>
                        </button>
                    </div>
                    <!-- Secondary Images Placeholder -->
                    <div class="flex flex-col gap-3">
                        <div id="secondImageContainer" class="relative group rounded-lg overflow-hidden bg-gray-100 dark:bg-gray-800 flex items-center justify-center cursor-zoom-in" style="height: 190px; min-height: 190px;" data-image-url="${secondImageUrl ? escapeHtml(secondImageUrl) : ''}">
                            <div class="w-full h-full pointer-events-auto">
                                ${secondImageHtml}
                            </div>
                        </div>
                        <label for="imageUploadInput" class="rounded-lg border-2 border-dashed border-slate-200 dark:border-slate-700 hover:border-primary hover:bg-primary/5 dark:hover:bg-primary/10 flex flex-col items-center justify-center cursor-pointer transition-all group py-4" style="height: 190px; min-height: 190px;">
                            <span class="material-symbols-outlined text-slate-400 dark:text-slate-500 group-hover:text-primary transition-colors">add_photo_alternate</span>
                            <span class="text-xs font-medium text-slate-500 dark:text-slate-400 mt-1">Yükle</span>
                            <input id="imageUploadInput" class="hidden" type="file" accept="image/*"/>
                        </label>
                    </div>
                </div>
            </div>
            
            <!-- General Info -->
            <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-6">
                <label class="flex flex-col gap-2">
                    <span class="text-sm font-semibold text-gray-900 dark:text-white">Başlık</span>
                    <input id="editTitle" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white placeholder:text-slate-400 h-12 px-4 text-base transition-shadow" placeholder="Fırsat başlığını giriniz" type="text" value="${escapeHtml(deal.title || '')}"/>
                </label>
                <label class="flex flex-col gap-2">
                    <span class="text-sm font-semibold text-gray-900 dark:text-white">Açıklama</span>
                    <textarea id="editDescription" class="form-textarea w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white placeholder:text-slate-400 min-h-[200px] p-4 text-base leading-relaxed resize-y transition-shadow" placeholder="Fırsat detaylarını buraya yazınız...">${escapeHtml(deal.description || '')}</textarea>
                    <div class="flex justify-between text-xs text-slate-500 dark:text-slate-400 px-1">
                        <span>Markdown desteklenir</span>
                        <span id="charCount">${(deal.description || '').length}/2000</span>
                    </div>
                </label>
            </div>
            
            <!-- Pricing & Links -->
            <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-6">
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Piyasa Fiyatı (TL)</span>
                        <div class="relative">
                            <span class="absolute left-3 top-1/2 -translate-y-1/2 text-slate-500 dark:text-slate-400">₺</span>
                            <input id="editOriginalPrice" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 pl-8 pr-4 text-base" type="number" value="${originalPrice}"/>
                        </div>
                    </label>
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">İndirimli Fiyat (TL)</span>
                        <div class="relative">
                            <span class="absolute left-3 top-1/2 -translate-y-1/2 text-primary font-bold">₺</span>
                            <input id="editPrice" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white font-bold h-12 pl-8 pr-4 text-base" type="number" value="${price}"/>
                        </div>
                        <span id="discountDisplay" class="text-xs text-green-600 dark:text-green-400 font-medium px-1 text-right">${discount > 0 ? `%${discount} İndirim` : 'İndirim yok'}</span>
                    </label>
                </div>
                <div class="pt-2">
                    <label class="flex items-center gap-3 cursor-pointer select-none">
                        <input id="editHidePrice" type="checkbox" class="w-5 h-5 rounded text-primary focus:ring-primary border-slate-300 dark:border-slate-700" ${deal.hidePrice ? 'checked' : ''}/>
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Fiyatı Gizle (Kampanya / Fiyatsız Fırsat)</span>
                    </label>
                </div>
                <div class="grid grid-cols-1 md:grid-cols-4 gap-4 pt-2">
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Mağaza Adı</span>
                        <input id="editStore" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 px-4 text-base" type="text" placeholder="ör. Trendyol" value="${escapeHtml(deal.store || '')}"/>
                    </label>
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Marka (Opsiyonel)</span>
                        <input id="editBrand" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 px-4 text-base" type="text" placeholder="ör. Apple" value="${escapeHtml(deal.brand || '')}"/>
                    </label>
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Rating Puanı</span>
                        <input id="editRatingValue" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 px-4 text-base" type="number" step="0.1" placeholder="ör. 4.8" value="${deal.ratingValue != null ? deal.ratingValue : ''}"/>
                    </label>
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Oy Sayısı</span>
                        <input id="editRatingCount" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 px-4 text-base" type="number" placeholder="ör. 1173" value="${deal.ratingCount != null ? deal.ratingCount : ''}"/>
                    </label>
                </div>
                <div class="h-px bg-slate-200 dark:bg-slate-700 w-full"></div>
                ${isAffiliateSupported ? `
                <!-- Bağlantı & Affiliate (Çoklu Görünüm) -->
                <div class="bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700 p-4 space-y-4">
                    <div class="flex items-center gap-2">
                        <span class="material-symbols-outlined text-primary text-[20px]">link</span>
                        <h4 class="text-sm font-bold text-gray-900 dark:text-white uppercase tracking-wider">Bağlantı & Affiliate (Çoklu Görünüm)</h4>
                    </div>

                    <!-- 1. Orijinal / Temiz Mağaza Linki (cleanUrl) -->
                    <div class="flex flex-col gap-1.5">
                        <div class="flex items-center justify-between">
                            <span class="text-xs font-bold text-gray-700 dark:text-slate-300">Orijinal Mağaza Linki (Temiz / Görünen Link)</span>
                            <span class="text-[11px] text-slate-400 font-mono">cleanUrl</span>
                        </div>
                        <div class="flex gap-2">
                            <input id="editCleanUrl" class="form-input flex-1 rounded-lg bg-white dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-11 px-3 text-sm" type="url" placeholder="https://www.teknosa.com/..." value="${escapeHtml(initialCleanUrl)}"/>
                            <a id="previewCleanUrlBtn" class="flex items-center justify-center gap-1.5 px-3 h-11 rounded-lg bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 text-gray-800 dark:text-slate-200 text-xs font-semibold transition-all whitespace-nowrap" href="${escapeHtml(initialCleanUrl || '#')}" target="_blank">
                                <span class="material-symbols-outlined text-[16px]">open_in_browser</span>
                                <span>Orijinal Linki Aç</span>
                            </a>
                        </div>
                        <div class="flex items-center justify-between mt-1">
                            <p class="text-[11px] text-slate-500 dark:text-slate-400">Kullanıcılara gösterilen, kopyalanan ve paylaşılan temiz ürün linki.</p>
                            <button type="button" id="convertToAffiliateBtn" class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-primary hover:bg-primary/90 text-black font-semibold text-xs transition-all shadow-sm">
                                <span class="material-symbols-outlined text-[16px]">auto_fix_high</span>
                                <span>Orijinalden Affiliate Üret</span>
                            </button>
                        </div>
                    </div>

                    <div class="h-px bg-slate-200 dark:bg-slate-700 w-full"></div>

                    <!-- 2. Aktif Affiliate Linki (link / url) -->
                    <div class="flex flex-col gap-1.5">
                        <div class="flex items-center justify-between">
                            <span class="text-xs font-bold text-gray-700 dark:text-slate-300">Aktif Affiliate Linki (Mağazaya Git Butonunda Çalışan)</span>
                            <span class="text-[11px] text-primary font-mono font-bold">link / url</span>
                        </div>
                        <div class="flex gap-2">
                            <input id="editAffiliateUrl" class="form-input flex-1 rounded-lg bg-white dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-primary font-mono text-xs h-11 px-3" type="url" placeholder="https://rdr.btrck.com/..." value="${escapeHtml(initialAffiliateUrl)}"/>
                            <!-- Backward compatibility hidden inputs -->
                            <input id="editUrl" type="hidden" value="${escapeHtml(initialAffiliateUrl)}"/>
                            <a id="previewAffiliateBtn" class="flex items-center justify-center gap-1.5 px-3 h-11 rounded-lg bg-primary/10 hover:bg-primary/20 border border-primary/30 text-primary text-xs font-semibold transition-all whitespace-nowrap" href="${escapeHtml(initialAffiliateUrl || '#')}" target="_blank">
                                <span class="material-symbols-outlined text-[16px]">open_in_new</span>
                                <span>Affiliate Test Et</span>
                            </a>
                            <a id="previewLinkBtn" class="hidden" href="${escapeHtml(initialAffiliateUrl || '#')}" target="_blank"></a>
                        </div>
                        <p id="affiliateStatus" class="text-xs text-slate-500 dark:text-slate-400 mt-1"></p>
                    </div>
                </div>
                ` : `
                <!-- Bağlantı (Standart Tek Link) -->
                <div class="bg-slate-50 dark:bg-slate-800/50 rounded-xl border border-slate-200 dark:border-slate-700 p-4 space-y-3">
                    <div class="flex items-center gap-2">
                        <span class="material-symbols-outlined text-primary text-[20px]">link</span>
                        <h4 class="text-sm font-bold text-gray-900 dark:text-white uppercase tracking-wider">Bağlantı</h4>
                    </div>
                    <div class="flex flex-col gap-1.5">
                        <div class="flex items-center justify-between">
                            <span class="text-xs font-bold text-gray-700 dark:text-slate-300">Ürün URL</span>
                        </div>
                        <div class="flex gap-2">
                            <input id="editCleanUrl" class="form-input flex-1 rounded-lg bg-white dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-11 px-3 text-sm" type="url" placeholder="https://..." value="${escapeHtml(deal.cleanUrl || cleanProductUrl(deal.url || deal.link || ''))}"/>
                            <input id="editUrl" type="hidden" value="${escapeHtml(deal.cleanUrl || deal.url || deal.link || '')}"/>
                            <a id="previewCleanUrlBtn" class="flex items-center justify-center gap-1.5 px-3 h-11 rounded-lg bg-slate-200 dark:bg-slate-700 hover:bg-slate-300 dark:hover:bg-slate-600 text-gray-800 dark:text-slate-200 text-xs font-semibold transition-all whitespace-nowrap" href="${escapeHtml(deal.cleanUrl || cleanProductUrl(deal.url || deal.link || '#'))}" target="_blank">
                                <span class="material-symbols-outlined text-[16px]">open_in_browser</span>
                                <span>Linki Test Et</span>
                            </a>
                        </div>
                        <p class="text-[11px] text-slate-500 dark:text-slate-400">Ürünün doğrudan mağaza linki.</p>
                    </div>
                </div>
                `}
                <div class="grid grid-cols-1 gap-6">
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Kupon Kodu (Opsiyonel)</span>
                        <div class="relative">
                            <input id="editCouponCode" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-dashed border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 px-4 text-base font-mono uppercase tracking-wider" placeholder="KOD YOK" type="text" value="${escapeHtml(deal.couponCode || '')}"/>
                            <span class="absolute right-3 top-1/2 -translate-y-1/2 material-symbols-outlined text-slate-400 dark:text-slate-500 text-lg">local_activity</span>
                        </div>
                    </label>
                </div>
            </div>

            <!-- Special Price & Badges (priceLabel) -->
            <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-4">
                <div class="flex items-center justify-between">
                    <div class="flex items-center gap-2">
                        <span class="material-symbols-outlined text-primary text-[20px]">local_offer</span>
                        <h3 class="text-sm font-bold text-gray-900 dark:text-white uppercase tracking-wider">Özel Fiyat & Rozet Yönetimi (priceLabel)</h3>
                    </div>
                </div>
                
                <!-- Live Preview -->
                <div class="flex items-center gap-3 p-3 bg-slate-50 dark:bg-slate-800/60 rounded-lg border border-slate-200 dark:border-slate-700">
                    <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">Canlı Önizleme:</span>
                    <div id="badgePreviewContainer" class="flex items-center">
                        ${getPriceBadgeHtml(deal.priceLabel, deal.store)}
                    </div>
                </div>

                <!-- Quick Presets -->
                <div class="space-y-2">
                    <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">Hızlı Seçim Şablonları:</span>
                    <div class="flex flex-wrap gap-2">
                        <button type="button" class="preset-badge-btn px-3 py-1.5 rounded-lg text-xs font-bold transition-all border border-orange-500/30 bg-orange-500/10 hover:bg-orange-500/20 text-orange-600 dark:text-orange-400" data-label="Prime Fırsatı">Prime Fırsatı</button>
                        <button type="button" class="preset-badge-btn px-3 py-1.5 rounded-lg text-xs font-bold transition-all border border-orange-500/30 bg-orange-500/10 hover:bg-orange-500/20 text-orange-600 dark:text-orange-400" data-label="Plus'a Özel">Plus'a Özel</button>
                        <button type="button" class="preset-badge-btn px-3 py-1.5 rounded-lg text-xs font-bold transition-all border border-purple-500/30 bg-purple-500/10 hover:bg-purple-500/20 text-purple-600 dark:text-purple-400" data-label="Premium ile">Premium ile</button>
                        <button type="button" class="preset-badge-btn px-3 py-1.5 rounded-lg text-xs font-bold transition-all border border-cyan-500/30 bg-cyan-500/10 hover:bg-cyan-500/20 text-cyan-600 dark:text-cyan-400" data-label="Plus ile">Plus ile</button>
                        <button type="button" class="preset-badge-btn px-3 py-1.5 rounded-lg text-xs font-bold transition-all border border-emerald-500/30 bg-emerald-500/10 hover:bg-emerald-500/20 text-emerald-600 dark:text-emerald-400" data-label="Money ile">Money ile</button>
                        <button type="button" class="preset-badge-btn px-3 py-1.5 rounded-lg text-xs font-bold transition-all border border-slate-300 dark:border-slate-600 bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-600 dark:text-slate-300" data-label="">✕ Temizle</button>
                    </div>
                </div>

                <!-- Input Field -->
                <label class="flex flex-col gap-2">
                    <span class="text-sm font-semibold text-gray-900 dark:text-white">Özel Fiyat Etiketi / Metin (priceLabel)</span>
                    <input id="editPriceLabel" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-11 px-4 text-sm font-medium" placeholder="Örn: Plus'a Özel, Prime Fırsatı, Sepette %20..." type="text" value="${escapeHtml(deal.priceLabel || '')}"/>
                </label>
            </div>
        `;
    }

    // Modal Sidebar (Sağ Kolon)
    const modalSidebarEl = document.getElementById('modalSidebar');
    if (modalSidebarEl) {
        const lastUpdate = deal.updatedAt ? `${formatFullDateTime(deal.updatedAt)} (${getTimeAgo(deal.updatedAt)})` : createdAt;

        // Kullanıcı adı ve profil görseli için
        const authorName = isUserSubmitted ? userDisplayName : 'Bot';
        const authorInitials = isUserSubmitted && userDisplayName
            ? userDisplayName.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase() || userDisplayName.substring(0, 2).toUpperCase()
            : 'BOT';

        // Profil görseli HTML'i
        const profileImageHtml = isUserSubmitted && userProfileImage
            ? `<img src="${escapeHtml(userProfileImage)}" alt="${escapeHtml(authorName)}" class="w-12 h-12 rounded-full object-cover" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"><div style="display:none;" class="w-12 h-12 rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700 flex items-center justify-center text-gray-600 dark:text-gray-300 font-bold text-sm">${authorInitials}</div>`
            : `<div class="w-12 h-12 rounded-full overflow-hidden bg-gray-200 dark:bg-gray-700 flex items-center justify-center text-gray-600 dark:text-gray-300 font-bold text-sm">${authorInitials}</div>`;

        modalSidebarEl.innerHTML = `
            <!-- Status Card -->
            <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
                <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Yayın Durumu</h3>
                <div class="flex flex-col gap-4">
                    <label class="flex flex-col gap-2">
                        <select id="editStatus" class="form-select w-full rounded-lg ${isApproved ? 'bg-green-50 dark:bg-green-900/10 border-green-200 dark:border-green-800 text-green-700 dark:text-green-400' : (deal.status === 'rejected' || deal.isRejected ? 'bg-rose-50 dark:bg-rose-900/10 border-rose-200 dark:border-rose-800 text-rose-700 dark:text-rose-400' : 'bg-amber-50 dark:bg-amber-900/10 border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-400')} focus:ring-1 focus:ring-primary h-12 px-4 text-base font-semibold">
                            <option value="pending" ${(!isApproved && !deal.isRejected && deal.status !== 'rejected' && !deal.isExpired && deal.status !== 'expired') ? 'selected' : ''}>Onay Bekliyor</option>
                            <option value="active" ${(isApproved && !deal.isExpired && deal.status !== 'expired' && !deal.isRejected && deal.status !== 'rejected') ? 'selected' : ''}>Yayında</option>
                            <option value="rejected" ${(deal.isRejected || deal.status === 'rejected') ? 'selected' : ''}>Reddedildi</option>
                            <option value="expired" ${(deal.isExpired || deal.status === 'expired') ? 'selected' : ''}>Süresi Doldu</option>
                        </select>
                    </label>
                    <div class="flex items-center justify-between text-sm py-2 border-t border-slate-200 dark:border-slate-700">
                        <span class="text-slate-500 dark:text-slate-400">Editör Seçimi (Sıcak Fırsat)</span>
                        <label class="relative inline-flex items-center cursor-pointer">
                            <input id="editIsHot" class="sr-only peer" type="checkbox" ${(deal.isEditorPick || deal.isHot) ? 'checked' : ''}/>
                            <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary/20 dark:peer-focus:ring-primary/30 rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-primary"></div>
                        </label>
                    </div>
                    <div class="flex items-center justify-between text-sm py-2 border-t border-slate-200 dark:border-slate-700">
                        <span class="text-amber-600 dark:text-amber-400 flex items-center gap-1.5"><span class="material-symbols-outlined text-[16px]">inventory_2</span>Amazon Depo Ürünü</span>
                        <label class="relative inline-flex items-center cursor-pointer">
                            <input id="editIsAmazonWarehouse" class="sr-only peer" type="checkbox" ${deal.isAmazonWarehouse ? 'checked' : ''}/>
                            <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-amber-500/20 dark:peer-focus:ring-amber-500/30 rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-amber-600"></div>
                        </label>
                    </div>
                </div>
                
                <!-- Action Buttons -->
                <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700 flex flex-col gap-2">
                    <button id="saveBtn" class="w-full h-11 px-4 rounded-lg ${isApproved ? 'bg-primary hover:bg-primary/90 text-white font-bold text-sm shadow-lg shadow-primary/20' : 'bg-emerald-500 hover:bg-emerald-600 text-white font-bold text-sm shadow-lg shadow-emerald-500/20'} transition-all flex items-center justify-center gap-2" type="button">
                        <span class="material-symbols-outlined text-[18px]">${isApproved ? 'save' : 'check'}</span>
                        <span>${isApproved ? 'Kaydet' : 'Onayla'}</span>
                    </button>
                    ${deal.id ? `
                    <button id="deleteDealBtn" class="w-full h-10 px-4 rounded-lg border border-rose-200 dark:border-rose-900/50 bg-rose-50 hover:bg-rose-100 dark:bg-rose-950/20 dark:hover:bg-rose-950/40 text-rose-600 dark:text-rose-400 font-semibold text-xs transition-colors flex items-center justify-center gap-1.5" type="button">
                        <span class="material-symbols-outlined text-[16px]">delete</span>
                        <span>Fırsatı Kalıcı Olarak Sil</span>
                    </button>
                    ` : ''}
                    <button id="cancelBtn" class="w-full h-11 px-4 rounded-lg border border-slate-200 dark:border-slate-700 bg-transparent text-gray-700 dark:text-white hover:bg-gray-100 dark:hover:bg-gray-800 font-semibold text-sm transition-colors" type="button">
                        İptal
                    </button>
                </div>
            </div>
            
            <!-- Category Card -->
            <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
                <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Kategori & Etiket</h3>
                <div class="flex flex-col gap-4">
                    <label class="flex flex-col gap-2">
                        <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">Kategori</span>
                        <div class="relative">
                            <select id="editCategory" class="form-select w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-11 px-4 text-sm">
                                <option value="elektronik" ${deal.category === 'elektronik' ? 'selected' : ''}>Elektronik</option>
                                <option value="moda" ${deal.category === 'moda' ? 'selected' : ''}>Moda & Giyim</option>
                                <option value="ev_yasam" ${deal.category === 'ev_yasam' ? 'selected' : ''}>Ev, Yaşam & Ofis</option>
                                <option value="anne_bebek" ${deal.category === 'anne_bebek' ? 'selected' : ''}>Anne & Bebek</option>
                                <option value="kozmetik" ${deal.category === 'kozmetik' ? 'selected' : ''}>Kozmetik & Bakım</option>
                                <option value="spor_outdoor" ${deal.category === 'spor_outdoor' ? 'selected' : ''}>Spor & Outdoor</option>
                                <option value="supermarket" ${deal.category === 'supermarket' ? 'selected' : ''}>Süpermarket</option>
                                <option value="yapi_oto" ${deal.category === 'yapi_oto' ? 'selected' : ''}>Yapı Market & Oto</option>
                                <option value="kitap_hobi" ${deal.category === 'kitap_hobi' ? 'selected' : ''}>Kitap, Müzik & Hobi</option>
                                <option value="diger" ${!deal.category || !['elektronik', 'moda', 'ev_yasam', 'anne_bebek', 'kozmetik', 'spor_outdoor', 'supermarket', 'yapi_oto', 'kitap_hobi', 'diger'].includes(deal.category) ? 'selected' : ''}>Diğer</option>
                            </select>
                        </div>
                    </label>
                    <label class="flex flex-col gap-2">
                        <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">Alt Kategori</span>
                        <select id="editSubcategory" class="form-select w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-11 px-4 text-sm">
                            ${subcategoryOptionsHtml}
                        </select>
                    </label>
                </div>
            </div>
            
            <!-- Author Info -->
            <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
                <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Ekleyen</h3>
                <div class="flex items-center gap-3">
                    <div class="relative">
                        ${profileImageHtml}
                        ${!isUserSubmitted ? `<span class="absolute -bottom-1 -right-1 flex h-5 w-5 items-center justify-center rounded-full bg-primary border-2 border-white dark:border-surface-dark" title="Bot">
                            <span class="material-symbols-outlined text-[12px] text-white">smart_toy</span>
                        </span>` : ''}
                    </div>
                    <div class="flex flex-col">
                        <span class="text-sm font-bold text-gray-900 dark:text-white">${escapeHtml(authorName)}</span>
                        <span class="text-xs text-slate-500 dark:text-slate-400">${isUserSubmitted ? 'Kullanıcı' : 'Bot'} • ID: #${deal.id.substring(0, 6)}</span>
                    </div>
                </div>
                <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700 grid grid-cols-2 gap-2 text-xs">
                    <div class="flex flex-col gap-1">
                        <span class="text-slate-500 dark:text-slate-400">Oluşturuldu</span>
                        <span class="font-medium text-gray-900 dark:text-white">${createdAt}</span>
                    </div>
                    <div class="flex flex-col gap-1">
                        <span class="text-slate-500 dark:text-slate-400">Son Güncelleme</span>
                        <span class="font-medium text-gray-900 dark:text-white">${lastUpdate}</span>
                    </div>
                </div>
            </div>
            
            ${!isUserSubmitted ? `
            <!-- Bot Source Info -->
            <div class="bg-blue-50 dark:bg-blue-900/10 rounded-xl border border-blue-100 dark:border-blue-900/30 p-4 shadow-sm flex items-start gap-3">
                <span class="material-symbols-outlined text-blue-600 dark:text-blue-400 mt-0.5">smart_toy</span>
                <div class="flex flex-col gap-1">
                    <span class="text-sm font-bold text-blue-900 dark:text-blue-200">Otomatik Bot</span>
                    <p class="text-xs text-blue-700 dark:text-blue-400 leading-normal">Bu fırsat otomatik olarak yakalandı. Lütfen fiyatı ve stok durumunu kontrol ediniz.</p>
                </div>
            </div>
            ` : ''}
        `;
    }

    // Breadcrumb
    const breadcrumbEl = document.getElementById('modalBreadcrumb');
    if (breadcrumbEl) {
        breadcrumbEl.textContent = `Fırsat #${deal.id.substring(0, 8)}`;
    }

    // Title
    if (modalTitle) {
        modalTitle.textContent = deal.title || 'Fırsat Düzenle';
    }

    // Character count update
    const descriptionEl = document.getElementById('editDescription');
    const charCountEl = document.getElementById('charCount');
    if (descriptionEl && charCountEl) {
        descriptionEl.addEventListener('input', () => {
            charCountEl.textContent = `${descriptionEl.value.length}/2000`;
        });
    }

    // Affiliate link dönüştürme ve çoklu link yönetimi
    const convertToAffiliateBtn = document.getElementById('convertToAffiliateBtn');
    const editCleanUrlEl = document.getElementById('editCleanUrl');
    const editAffiliateUrlEl = document.getElementById('editAffiliateUrl');
    const editUrlEl = document.getElementById('editUrl');
    const previewCleanUrlBtn = document.getElementById('previewCleanUrlBtn');
    const previewAffiliateBtn = document.getElementById('previewAffiliateBtn');
    const previewLinkBtn = document.getElementById('previewLinkBtn');
    const affiliateStatusEl = document.getElementById('affiliateStatus');

    if (convertToAffiliateBtn) {
        convertToAffiliateBtn.addEventListener('click', async () => {
            let sourceUrl = editCleanUrlEl?.value.trim() || editAffiliateUrlEl?.value.trim() || editUrlEl?.value.trim() || '';
            if (!sourceUrl) {
                showError('Lütfen önce bir link girin!');
                return;
            }

            // Eğer cleanUrl boşsa veya btrck linki yapıştırılmışsa cleanUrl'i unwrap edelim
            if (editCleanUrlEl && (!editCleanUrlEl.value.trim() || editCleanUrlEl.value.includes('btrck.com'))) {
                const unwrap = cleanProductUrl(sourceUrl);
                if (unwrap && !unwrap.includes('btrck.com')) {
                    editCleanUrlEl.value = unwrap;
                    sourceUrl = unwrap;
                    if (previewCleanUrlBtn) previewCleanUrlBtn.href = unwrap;
                }
            }

            // Kısa link kontrolü ve otomatik çözme
            let urlToConvert = sourceUrl;
            try {
                const url = new URL(sourceUrl);
                const hostname = url.hostname.toLowerCase();

                const isShortlink = hostname.includes('hb.biz') ||
                    hostname.includes('app.hb.biz') ||
                    hostname.includes('paylaskazan.teknosa.com') ||
                    hostname.includes('ty.gl') ||
                    hostname.includes('sl.n11.com') ||
                    hostname.includes('amzn.to') ||
                    hostname.includes('amzn.eu') ||
                    hostname.includes('link.amazon') ||
                    hostname.includes('bit.ly') ||
                    hostname.includes('tinyurl.com');

                if (isShortlink) {
                    if (affiliateStatusEl) {
                        affiliateStatusEl.innerHTML = `
                            <div style="background: #e7f3ff; padding: 10px; border-radius: 5px; border-left: 4px solid #2196F3;">
                                <strong>🔄 Kısa link çözülüyor...</strong><br>
                                <small>Gerçek ürün linki bulunuyor...</small>
                            </div>
                        `;
                        affiliateStatusEl.className = 'text-xs mt-1';
                    }

                    try {
                        const functionsUrl = `https://us-central1-${firebaseConfig.projectId}.cloudfunctions.net/resolveShortLink`;
                        const response = await fetch(`${functionsUrl}?url=${encodeURIComponent(sourceUrl)}`);
                        const data = await response.json();

                        if (data.success && data.resolvedUrl) {
                            urlToConvert = data.resolvedUrl;
                            if (editCleanUrlEl) {
                                editCleanUrlEl.value = cleanProductUrl(urlToConvert);
                                if (previewCleanUrlBtn) previewCleanUrlBtn.href = editCleanUrlEl.value;
                            }
                            if (affiliateStatusEl) {
                                affiliateStatusEl.innerHTML = `
                                    <div style="background: #d4edda; padding: 10px; border-radius: 5px; border-left: 4px solid #28a745;">
                                        <strong>✅ Kısa link çözüldü!</strong><br>
                                        <small>Gerçek ürün linki bulundu, affiliate link'e dönüştürülüyor...</small>
                                    </div>
                                `;
                                affiliateStatusEl.className = 'text-xs mt-1';
                            }
                        } else {
                            throw new Error('Kısa link çözülemedi');
                        }
                    } catch (error) {
                        console.error('Kısa link çözme hatası:', error);
                        if (affiliateStatusEl) {
                            affiliateStatusEl.innerHTML = `
                                <div style="background: #fff3cd; padding: 10px; border-radius: 5px; border-left: 4px solid #ffc107;">
                                    <strong>⚠️ Kısa Link Çözülemedi</strong><br>
                                    Otomatik çözüm başarısız. Lütfen:<br>
                                    1. Bu linki tarayıcıda açın<br>
                                    2. Gerçek ürün linkini kopyalayın<br>
                                    3. Buraya yapıştırın ve tekrar deneyin
                                </div>
                            `;
                            affiliateStatusEl.className = 'text-xs mt-1';
                        }
                        showError('Kısa link otomatik çözülemedi. Lütfen gerçek ürün linkini manuel olarak alın.');
                        return;
                    }
                }
            } catch (e) {
                // URL parse hatası, devam et
            }

            // Affiliate link'e dönüştür (başkasının affiliate linkini kendi linkimize dönüştürür)
            const store = detectStoreFromUrl(urlToConvert);
            let convertedUrl = convertToAffiliateLink(urlToConvert);



            if (convertedUrl !== urlToConvert) {
                if (editAffiliateUrlEl) editAffiliateUrlEl.value = convertedUrl;
                if (editUrlEl) editUrlEl.value = convertedUrl;
                if (previewAffiliateBtn) previewAffiliateBtn.href = convertedUrl;
                if (previewLinkBtn) previewLinkBtn.href = convertedUrl;
                if (affiliateStatusEl) {
                    affiliateStatusEl.textContent = `✅ ${store} affiliate linkine dönüştürüldü`;
                    affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
                }
                showSuccess(`${store} affiliate linkine dönüştürüldü!`);
            } else {
                if (affiliateStatusEl) {
                    affiliateStatusEl.textContent = 'ℹ️ Orijinal mağaza linki korundu (Şalter kapalı veya mağaza henüz canlıda değil)';
                    affiliateStatusEl.className = 'text-xs text-slate-500 dark:text-slate-400 mt-1';
                }
                showSuccess('Orijinal mağaza linki korundu.');
            }
        });
    }

    // URL input değişikliklerinde linkleri dinamik senkronize et
    if (editCleanUrlEl && previewCleanUrlBtn) {
        editCleanUrlEl.addEventListener('input', () => {
            const url = editCleanUrlEl.value.trim();
            previewCleanUrlBtn.href = url || '#';
        });
    }

    // Affiliate durum rozeti başlangıç ayarı
    if (affiliateStatusEl && isAffiliateSupported) {
        if (initialAffiliateUrl && initialAffiliateUrl.includes('btrck.com')) {
            affiliateStatusEl.textContent = '✅ Teknosa TUNE affiliate linki hazır ve aktif';
            affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
        } else if (initialAffiliateUrl && (initialAffiliateUrl.includes('7t4g.adj.st') || initialAffiliateUrl.includes('adj_adgroup='))) {
            affiliateStatusEl.textContent = '✅ Hepsiburada LinkGelir (Adjust) affiliate linki hazır ve aktif';
            affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
        } else if (initialAffiliateUrl && initialAffiliateUrl.includes('tag=')) {
            affiliateStatusEl.textContent = '✅ Amazon Associates affiliate linki hazır ve aktif';
            affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
        } else if (initialAffiliateUrl && initialAffiliateUrl.includes('incehesap.com/u/')) {
            affiliateStatusEl.textContent = '✅ İncehesap Paylaştıkça Kazan affiliate linki hazır ve aktif';
            affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
        } else {
            affiliateStatusEl.textContent = 'ℹ️ Orijinal mağaza linki tespit edildi. "Orijinalden Affiliate Üret" ile dönüştürebilirsiniz.';
            affiliateStatusEl.className = 'text-xs text-slate-500 dark:text-slate-400 mt-1';
        }
    }

    if (editAffiliateUrlEl) {
        editAffiliateUrlEl.addEventListener('input', () => {
            const url = editAffiliateUrlEl.value.trim();
            if (editUrlEl) editUrlEl.value = url;
            if (previewAffiliateBtn) previewAffiliateBtn.href = url || '#';
            if (previewLinkBtn) previewLinkBtn.href = url || '#';
            if (affiliateStatusEl) {
                if (url.includes('btrck.com')) {
                    affiliateStatusEl.textContent = '✅ Teknosa TUNE affiliate linki hazır ve aktif';
                    affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
                } else if (url.includes('7t4g.adj.st') || url.includes('adj_adgroup=')) {
                    affiliateStatusEl.textContent = '✅ Hepsiburada LinkGelir (Adjust) affiliate linki hazır ve aktif';
                    affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
                } else if (url.includes('amazon.com.tr') && url.includes('tag=')) {
                    affiliateStatusEl.textContent = '✅ Amazon Associates affiliate linki hazır ve aktif';
                    affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
                } else if (url.includes('amazon.com.tr')) {
                    affiliateStatusEl.textContent = '⚠️ Bu organik bir Amazon linkidir. "Orijinalden Affiliate Üret" butonuna basarak affiliate yapabilirsiniz.';
                    affiliateStatusEl.className = 'text-xs text-amber-600 dark:text-amber-400 mt-1';
                } else if (url.includes('incehesap.com/u/')) {
                    affiliateStatusEl.textContent = '✅ İncehesap Paylaştıkça Kazan affiliate linki hazır ve aktif';
                    affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
                } else if (url.includes('incehesap.com')) {
                    affiliateStatusEl.textContent = '⚠️ Bu organik bir İncehesap linkidir. "Orijinalden Affiliate Üret" veya Paylaştıkça Kazan kısa linki giriniz.';
                    affiliateStatusEl.className = 'text-xs text-amber-600 dark:text-amber-400 mt-1';
                } else if (url.includes('teknosa.com')) {
                    affiliateStatusEl.textContent = '⚠️ Bu organik bir Teknosa linkidir. "Orijinalden Affiliate Üret" butonuna basarak affiliate yapabilirsiniz.';
                    affiliateStatusEl.className = 'text-xs text-amber-600 dark:text-amber-400 mt-1';
                } else if (url.includes('hepsiburada.com')) {
                    affiliateStatusEl.textContent = '⚠️ Bu organik bir Hepsiburada linkidir. "Orijinalden Affiliate Üret" butonuna basarak affiliate yapabilirsiniz.';
                    affiliateStatusEl.className = 'text-xs text-amber-600 dark:text-amber-400 mt-1';
                } else {
                    affiliateStatusEl.textContent = '';
                }
            }
        });
    }

    // Price calculation for discount
    const priceEl = document.getElementById('editPrice');
    const originalPriceEl = document.getElementById('editOriginalPrice');
    const discountDisplayEl = document.getElementById('discountDisplay');
    if (priceEl && originalPriceEl && discountDisplayEl) {
        const updateDiscount = () => {
            const orig = parseFloat(originalPriceEl.value) || 0;
            const curr = parseFloat(priceEl.value) || 0;
            if (orig > curr && orig > 0) {
                const disc = Math.round(((orig - curr) / orig) * 100);
                discountDisplayEl.innerHTML = `<span class="text-xs text-green-600 dark:text-green-400 font-medium px-1 text-right">%${disc} İndirim</span>`;
            } else {
                discountDisplayEl.innerHTML = '<span class="text-xs text-slate-400 px-1 text-right">İndirim yok</span>';
            }
        };
        priceEl.addEventListener('input', updateDiscount);
        originalPriceEl.addEventListener('input', updateDiscount);
    }

    // Kategori değiştiğinde alt kategorileri dinamik olarak güncelle
    const editCategoryEl = document.getElementById('editCategory');
    const editSubcategoryEl = document.getElementById('editSubcategory');
    if (editCategoryEl && editSubcategoryEl) {
        editCategoryEl.addEventListener('change', () => {
            const selectedCat = editCategoryEl.value;
            const subs = categoriesConfig[selectedCat] || [];
            let optionsHtml = '<option value="">Alt Kategori Yok</option>';
            subs.forEach(sub => {
                optionsHtml += `<option value="${escapeHtml(sub)}">${escapeHtml(sub)}</option>`;
            });
            editSubcategoryEl.innerHTML = optionsHtml;
        });
    }

    // Show/hide buttons based on deal status
    const approveBtnEl = document.getElementById('approveBtn');
    const rejectBtnEl = document.getElementById('rejectBtn');
    if (approveBtnEl) approveBtnEl.style.display = isApproved ? 'none' : 'flex';
    if (rejectBtnEl) rejectBtnEl.style.display = 'flex';

    // Modal gösterildikten sonra butonlara event listener ekle
    dealModal.classList.remove('hidden');

    // ESC tuşu ile modal'ı kapat
    const handleEscapeKey = (e) => {
        if (e.key === 'Escape' && !dealModal.classList.contains('hidden')) {
            console.log('⌨️ ESC tuşu ile modal kapatılıyor...');
            closeDealModal();
            document.removeEventListener('keydown', handleEscapeKey);
        }
    };
    document.addEventListener('keydown', handleEscapeKey);

    // Görselleri güncelle (eğer imageUrls varsa)
    if (currentDeal.imageUrls && Array.isArray(currentDeal.imageUrls) && currentDeal.imageUrls.length > 0) {
        setTimeout(() => {
            updateModalImages(currentDeal.imageUrls);
        }, 100);
    }

    // Görsel yükleme event listener'ı ekle
    setTimeout(() => {
        const imageUploadInput = document.getElementById('imageUploadInput');
        if (imageUploadInput) {
            console.log('📸 Image upload input found, adding event listener...');
            // Önceki listener'ı temizle
            const newInput = imageUploadInput.cloneNode(true);
            imageUploadInput.parentNode.replaceChild(newInput, imageUploadInput);
            newInput.addEventListener('change', (e) => {
                console.log('📸 Image file selected:', e.target.files[0]?.name);
                handleImageUpload(e);
            });
            console.log('✅ Image upload event listener added');
        } else {
            console.warn('⚠️ Image upload input not found!');
        }

        // Price label live preview & preset buttons listener
        const editPriceLabelInput = document.getElementById('editPriceLabel');
        const badgePreviewContainer = document.getElementById('badgePreviewContainer');
        const editStoreInput = document.getElementById('editStore');

        function refreshBadgePreview() {
            if (badgePreviewContainer) {
                const currentLabel = editPriceLabelInput ? editPriceLabelInput.value : '';
                const currentStore = editStoreInput ? editStoreInput.value : '';
                badgePreviewContainer.innerHTML = getPriceBadgeHtml(currentLabel, currentStore);
            }
        }

        if (editPriceLabelInput) {
            editPriceLabelInput.addEventListener('input', refreshBadgePreview);
        }
        if (editStoreInput) {
            editStoreInput.addEventListener('input', refreshBadgePreview);
        }

        const presetButtons = document.querySelectorAll('.preset-badge-btn');
        presetButtons.forEach(btn => {
            btn.addEventListener('click', (e) => {
                e.preventDefault();
                const targetLabel = btn.getAttribute('data-label') || '';
                if (editPriceLabelInput) {
                    editPriceLabelInput.value = targetLabel;
                    refreshBadgePreview();
                }
            });
        });
    }, 150);

    // Butonlara direkt event listener ekle (modal gösterildikten sonra)
    setTimeout(() => {
        const saveBtnEl = document.getElementById('saveBtn');
        const cancelBtnEl = document.getElementById('cancelBtn');

        if (saveBtnEl) {
            const isApproved = currentDeal.isApproved === true;
            saveBtnEl.innerHTML = isApproved
                ? '<span class="material-symbols-outlined text-[18px]">save</span><span>Kaydet</span>'
                : '<span class="material-symbols-outlined text-[18px]">check</span><span>Onayla</span>';

            console.log('🔘 Adding event listener to saveBtn (Onayla button)');
            // Önceki listener'ları temizle
            const newSaveBtn = saveBtnEl.cloneNode(true);
            saveBtnEl.parentNode.replaceChild(newSaveBtn, saveBtnEl);

            newSaveBtn.addEventListener('click', async (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('✅ Onayla/Kaydet butonu tıklandı (direct listener)!', currentDeal?.id);

                if (!currentDeal) {
                    console.error('❌ No current deal!');
                    showError('Fırsat bulunamadı!');
                    return;
                }

                // Butonu devre dışı bırak
                newSaveBtn.disabled = true;
                const originalHTML = newSaveBtn.innerHTML;
                const isNew = !currentDeal.id || currentDeal.id === '';
                const isApp = currentDeal.isApproved === true;

                if (isNew) {
                    newSaveBtn.innerHTML = '<span>Oluşturuluyor...</span>';
                } else if (isApp) {
                    newSaveBtn.innerHTML = '<span>Kaydediliyor...</span>';
                } else {
                    newSaveBtn.innerHTML = '<span>Onaylanıyor...</span>';
                }

                try {
                    await saveDealChanges();
                } catch (error) {
                    console.error('❌ Kayıt hatası:', error);
                    showError('İşlem başarısız: ' + error.message);
                } finally {
                    // Hata veya doğrulama hatası durumunda butonu her zaman geri aç
                    if (!dealModal.classList.contains('hidden')) {
                        newSaveBtn.disabled = false;
                        newSaveBtn.innerHTML = originalHTML;
                    }
                }
            });
        }

        if (cancelBtnEl) {
            console.log('🔘 Adding event listener to cancelBtn (İptal button)');
            // Önceki listener'ları temizle
            const newCancelBtn = cancelBtnEl.cloneNode(true);
            cancelBtnEl.parentNode.replaceChild(newCancelBtn, cancelBtnEl);

            newCancelBtn.addEventListener('click', (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('❌ İptal butonu tıklandı (direct listener)!');
                closeDealModal();
            });
        }
    }, 200); // DOM'un güncellenmesi için kısa bir gecikme

    // Image lightbox event listeners - Modal açıldıktan sonra ekle
    setTimeout(() => {
        // Ana görsel için - container'a direkt listener ekle
        const mainImageContainer = document.getElementById('mainImageContainer') || document.querySelector('.sm\\:col-span-2[data-image-url]');
        if (mainImageContainer) {
            // Önceki listener'ları temizle
            const newContainer = mainImageContainer.cloneNode(true);
            mainImageContainer.parentNode.replaceChild(newContainer, mainImageContainer);

            newContainer.addEventListener('click', (e) => {
                // Edit butonuna tıklanmadıysa
                if (!e.target.closest('button') && e.target.tagName !== 'BUTTON') {
                    const imageUrl = newContainer.dataset.imageUrl;
                    if (imageUrl && imageUrl.trim() !== '') {
                        e.preventDefault();
                        e.stopPropagation();
                        console.log('🖼️ Main image container clicked, opening lightbox:', imageUrl);
                        openImageLightbox(imageUrl);
                    } else {
                        console.warn('⚠️ No image URL in dataset');
                    }
                }
            });
            console.log('✅ Main image click listener added to container');
        } else {
            console.warn('⚠️ Main image container not found');
        }

        // İkinci görsel için
        const secondImageContainer = document.getElementById('secondImageContainer');
        if (secondImageContainer && secondImageContainer.dataset.imageUrl) {
            // Önceki listener'ları temizle
            const newSecondContainer = secondImageContainer.cloneNode(true);
            secondImageContainer.parentNode.replaceChild(newSecondContainer, secondImageContainer);

            newSecondContainer.addEventListener('click', (e) => {
                const imageUrl = newSecondContainer.dataset.imageUrl;
                if (imageUrl && imageUrl.trim() !== '') {
                    e.preventDefault();
                    e.stopPropagation();
                    console.log('🖼️ Second image container clicked, opening lightbox:', imageUrl);
                    openImageLightbox(imageUrl);
                }
            });
            console.log('✅ Second image click listener added to container');
        }
    }, 400);
}

// Image Lightbox Functions
function openImageLightbox(imageUrl) {
    console.log('🔍 Opening lightbox with image:', imageUrl);
    const lightbox = document.getElementById('imageLightbox');
    const lightboxImage = document.getElementById('lightboxImage');
    if (lightbox && lightboxImage && imageUrl) {
        lightboxImage.src = imageUrl;
        lightbox.classList.remove('hidden');
        document.body.style.overflow = 'hidden'; // Prevent background scrolling
        console.log('✅ Lightbox opened');
    } else {
        console.error('❌ Lightbox elements not found or no image URL:', { lightbox, lightboxImage, imageUrl });
    }
}

function closeImageLightbox() {
    const lightbox = document.getElementById('imageLightbox');
    if (lightbox) {
        lightbox.classList.add('hidden');
        document.body.style.overflow = ''; // Restore scrolling
    }
}

// Initialize lightbox event listeners
function initLightbox() {
    const lightbox = document.getElementById('imageLightbox');
    const closeLightboxBtn = document.getElementById('closeLightbox');

    if (closeLightboxBtn) {
        closeLightboxBtn.addEventListener('click', closeImageLightbox);
    }

    // Close on background click
    if (lightbox) {
        lightbox.addEventListener('click', (e) => {
            if (e.target === lightbox) {
                closeImageLightbox();
            }
        });
    }

    // Close on Escape key
    document.addEventListener('keydown', (e) => {
        if (e.key === 'Escape' && lightbox && !lightbox.classList.contains('hidden')) {
            closeImageLightbox();
        }
    });
}

// Make functions globally available
window.openImageLightbox = openImageLightbox;
window.closeImageLightbox = closeImageLightbox;

function closeDealModal() {
    if (dealModal) {
        dealModal.classList.add('hidden');
        currentDeal = null;
        console.log('✅ Modal kapatıldı, önceki view\'a dönülüyor:', previousView);

        // Önceki view'a geri dön
        if (previousView === 'deals') {
            showDealsView();
        } else if (previousView === 'users') {
            showUsersView();
        } else if (previousView === 'messages') {
            showMessagesView();
        }
    }
}

async function saveDealChanges() {
    if (!currentDeal) {
        console.error('❌ No current deal to save!');
        showError('Fırsat bulunamadı!');
        return;
    }

    try {
        // Yeni deal mi yoksa mevcut deal mi?
        const isNewDeal = !currentDeal.id || currentDeal.id === '';

        console.log(`💾 ${isNewDeal ? 'Creating new deal' : 'Saving deal changes for:'} ${isNewDeal ? '' : currentDeal.id}`);

        const title = document.getElementById('editTitle')?.value || currentDeal.title || '';
        const description = document.getElementById('editDescription')?.value || currentDeal.description || '';
        const price = parseFloat(document.getElementById('editPrice')?.value) || currentDeal.price || 0;
        const originalPrice = parseFloat(document.getElementById('editOriginalPrice')?.value) || currentDeal.originalPrice || price || 0;
        const cleanUrlInput = document.getElementById('editCleanUrl')?.value?.trim() || '';
        const affiliateUrlInput = document.getElementById('editAffiliateUrl')?.value?.trim() || document.getElementById('editUrl')?.value?.trim() || currentDeal.url || currentDeal.link || '';
        const category = document.getElementById('editCategory')?.value || currentDeal.category || '';
        const subcategoryEl = document.getElementById('editSubcategory');
        const subcategory = (subcategoryEl?.value && subcategoryEl.value !== 'none' && subcategoryEl.value !== 'Alt kategori yok')
            ? subcategoryEl.value
            : (currentDeal.subCategory || currentDeal.subcategory || null);
        const status = document.getElementById('editStatus')?.value || (currentDeal.isApproved ? 'active' : 'pending');
        const isHot = document.getElementById('editIsHot')?.checked || false;
        const store = document.getElementById('editStore')?.value?.trim() || (currentDeal && currentDeal.store) || 'Bilinmeyen';
        const couponCode = document.getElementById('editCouponCode')?.value || '';
        const brand = document.getElementById('editBrand')?.value?.trim() || null;
        const priceLabel = document.getElementById('editPriceLabel')?.value?.trim() || null;
        const ratingValStr = document.getElementById('editRatingValue')?.value;
        const ratingValue = (ratingValStr !== undefined && ratingValStr !== '') ? parseFloat(ratingValStr) : null;
        const ratingCntStr = document.getElementById('editRatingCount')?.value;
        const ratingCount = (ratingCntStr !== undefined && ratingCntStr !== '') ? parseInt(ratingCntStr) : null;

        let finalCleanUrl = cleanUrlInput || currentDeal.cleanUrl || '';
        let processedUrl = affiliateUrlInput || currentDeal.url || currentDeal.link || '';

        const isDealAffiliateSupported = isAffiliateSupportedStore(store) ||
            isAffiliateSupportedStore(cleanUrlInput) ||
            isAffiliateSupportedStore(affiliateUrlInput) ||
            isAffiliateSupportedStore(currentDeal.store) ||
            isAffiliateSupportedStore(currentDeal.cleanUrl);

        if (!isDealAffiliateSupported) {
            // Affiliate desteği olmayan veya şalteri kapalı olan mağazalar: Standart tek link modeli
            const singleUrl = cleanUrlInput || affiliateUrlInput || currentDeal.url || currentDeal.link || '';
            const cleaned = cleanProductUrl(singleUrl);
            finalCleanUrl = cleaned;
            processedUrl = cleaned;
        } else {
            // Affiliate desteklenen mağazalar (Amazon, Teknosa & Hepsiburada)
            // 1. Temiz URL boş veya affiliate linki ise unwrap et
            const isCleanAffiliate = !finalCleanUrl || finalCleanUrl.includes('btrck.com') || finalCleanUrl.includes('7t4g.adj.st') || finalCleanUrl.includes('adj.st') ||
                (typeof AffiliateManager !== 'undefined' && AffiliateManager.isAlreadyAffiliate(finalCleanUrl, affiliateConfig));
            if (isCleanAffiliate) {
                const unwrap = cleanProductUrl(finalCleanUrl || processedUrl);
                if (unwrap && !unwrap.includes('btrck.com') && !unwrap.includes('7t4g.adj.st')) {
                    finalCleanUrl = unwrap;
                }
            }

            // 2. Affiliate link boşsa veya henüz affiliate linki değilse otomatik dönüştür
            const isAffiliate = Boolean(processedUrl && typeof AffiliateManager !== 'undefined' && typeof AffiliateManager.isAlreadyAffiliate === 'function' && AffiliateManager.isAlreadyAffiliate(processedUrl, affiliateConfig));
            if (!processedUrl || !isAffiliate) {
                const sourceForAffiliate = (finalCleanUrl && !finalCleanUrl.includes('btrck.com') && !finalCleanUrl.includes('7t4g.adj.st')) ? finalCleanUrl : processedUrl;
                if (sourceForAffiliate) {
                    try {
                        let converted = convertToAffiliateLink(sourceForAffiliate);
                        if (converted && converted !== sourceForAffiliate) {
                            processedUrl = converted;
                            console.log('✅ saveDealChanges: Affiliate link\'e dönüştürüldü:', processedUrl);
                        }
                    } catch (e) {
                        console.warn('Affiliate auto-conversion error in saveDealChanges:', e);
                    }
                }
            }
        }

        // Mevcut görselleri al (yeni görsel yüklenmişse güncellenmiş olacak)
        let imageUrls = currentDeal.imageUrls || [];
        if (!Array.isArray(imageUrls) && currentDeal.imageUrl) {
            imageUrls = [currentDeal.imageUrl];
        }
        // imageUrl'i de güncelle (ilk görsel)
        const imageUrl = imageUrls.length > 0 ? imageUrls[0] : (currentDeal.imageUrl || '');

        const hidePrice = document.getElementById('editHidePrice')?.checked || false;

        // Validasyon - hata varsa throw et ki buton geri açılsın
        if (!title.trim()) {
            showError('Başlık gereklidir!');
            throw new Error('Başlık gereklidir!');
        }
        if (!hidePrice && price <= 0) {
            showError('Geçerli bir fiyat giriniz!');
            throw new Error('Geçerli bir fiyat giriniz!');
        }
        if (!processedUrl && !finalCleanUrl) {
            showError('Ürün linki gereklidir!');
            throw new Error('Ürün linki gereklidir!');
        }
        if (!category) {
            showError('Kategori seçiniz!');
            throw new Error('Kategori seçiniz!');
        }

        // İndirim oranı hesaplama
        const discountRate = (originalPrice > price && originalPrice > 0)
            ? Math.round(((originalPrice - price) / originalPrice) * 100)
            : null;

        // Tarih dönüştürme ve doğrulama
        let cleanCreatedAt = currentDeal.createdAt;
        if (cleanCreatedAt && typeof cleanCreatedAt.toDate === 'function') {
            cleanCreatedAt = cleanCreatedAt.toDate();
        }
        const createdAtDate = cleanCreatedAt ? new Date(cleanCreatedAt) : new Date();
        const isCreatedAtValid = createdAtDate instanceof Date && !isNaN(createdAtDate.getTime());

        // Firestore undefined değerleri kabul etmez, bu yüzden sadece tanımlı alanları ekle
        const dealData = {
            title: title.trim(),
            description: description.trim() || '',
            price: price || 0,
            originalPrice: originalPrice || price || 0,
            discountRate: discountRate,
            cleanUrl: finalCleanUrl || null,
            url: processedUrl,
            link: processedUrl, // link alanı da ekle (geriye dönük uyumluluk için)
            category: category,
            imageUrl: imageUrl || '',
            hidePrice: hidePrice,
            imageUrls: imageUrls.length > 0 ? imageUrls : [],
            status: status,
            isApproved: (status === 'active'),
            isRejected: (status === 'rejected'),
            isExpired: (status === 'expired' || status === 'rejected'),
            isHot: isHot || false,
            isEditorPick: isHot || false, // Hem isHot hem isEditorPick olarak aynı değeri set et
            couponCode: couponCode || '',
            store: store,
            postedBy: isNewDeal ? (currentUser ? currentUser.uid : 'admin') : (currentDeal.postedBy || 'admin'),
            hotVotes: isNewDeal ? 0 : (currentDeal.hotVotes || 0),
            coldVotes: isNewDeal ? 0 : (currentDeal.coldVotes || 0),
            expiredVotes: isNewDeal ? 0 : (currentDeal.expiredVotes || 0),
            commentCount: isNewDeal ? 0 : (currentDeal.commentCount || 0),
            isUserSubmitted: isNewDeal ? false : (currentDeal.isUserSubmitted || false),
            createdAt: isNewDeal ? firebase.firestore.FieldValue.serverTimestamp() : (isCreatedAtValid ? firebase.firestore.Timestamp.fromDate(createdAtDate) : firebase.firestore.FieldValue.serverTimestamp()),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
            brand: brand,
            priceLabel: priceLabel,
            ratingValue: (ratingValue !== null && !isNaN(ratingValue)) ? ratingValue : null,
            ratingCount: (ratingCount !== null && !isNaN(ratingCount)) ? ratingCount : null,
            isAmazonWarehouse: document.getElementById('editIsAmazonWarehouse')?.checked || false,
        };

        // Track approvedAt when transitioning to active/approved state
        const isApprovedNow = (status === 'active');
        const previouslyApproved = !isNewDeal && currentDeal.isApproved === true && currentDeal.isExpired !== true && currentDeal.status !== 'expired';
        if (isApprovedNow) {
            if (previouslyApproved && currentDeal.approvedAt) {
                let cleanApprovedAt = currentDeal.approvedAt;
                if (cleanApprovedAt && typeof cleanApprovedAt.toDate === 'function') {
                    cleanApprovedAt = cleanApprovedAt.toDate();
                }
                const approvedAtDate = new Date(cleanApprovedAt);
                const isApprovedAtValid = approvedAtDate instanceof Date && !isNaN(approvedAtDate.getTime());
                dealData.approvedAt = isApprovedAtValid ? firebase.firestore.Timestamp.fromDate(approvedAtDate) : firebase.firestore.FieldValue.serverTimestamp();
            } else {
                dealData.approvedAt = firebase.firestore.FieldValue.serverTimestamp();
            }
        } else {
            dealData.approvedAt = null;
        }

        // subCategory sadece değer varsa ekle (null veya undefined değilse)
        if (subcategory && subcategory !== 'none' && subcategory !== 'Alt kategori yok') {
            dealData.subCategory = subcategory;
        } else if ((currentDeal.subCategory || currentDeal.subcategory) && !isNewDeal) {
            // Mevcut subCategory varsa koru (sadece güncelleme durumunda)
            dealData.subCategory = currentDeal.subCategory || currentDeal.subcategory;
        }

        if (isNewDeal) {
            // Yeni deal oluştur
            console.log('📝 Creating new deal:', dealData);
            let newDealId;
            if (currentDeal._isPreGeneratedId && currentDeal.id) {
                // Görsel yükleme sırasında önceden oluşturulmuş ID varsa onu kullan
                await db.collection('deals').doc(currentDeal.id).set(dealData);
                newDealId = currentDeal.id;
                console.log('✅ New deal created with pre-generated ID:', newDealId);
            } else {
                const docRef = await db.collection('deals').add(dealData);
                newDealId = docRef.id;
                console.log('✅ New deal created with ID:', newDealId);
            }
            showSuccess('Fırsat başarıyla oluşturuldu!');
            await loadDeals();
            updateStats();
            closeDealModal();
        } else {
            // Mevcut deal'i güncelle
            console.log('📝 Update data:', dealData);
            console.log('🔄 Updating deal in Firestore...');

            await db.collection('deals').doc(currentDeal.id).update(dealData);

            console.log('✅ Deal updated successfully!');
            showSuccess('Fırsat onaylandı ve yayınlandı!');

            // Modal'ı kapat ve listeyi yenile
            closeDealModal();
            await loadDeals();
            updateStats();
        }
    } catch (error) {
        console.error('❌ Save error:', error);
        console.error('❌ Error stack:', error.stack);
        showError('Onaylama hatası: ' + error.message);
        throw error; // Hata durumunda throw et ki buton tekrar aktif olsun
    }
}

// Show add deal modal (yeni fırsat ekleme)
async function showAddDealModal() {
    console.log('➕ Yeni fırsat ekleme modal\'ı açılıyor...');

    // Boş bir deal objesi oluştur
    const newDeal = {
        id: '', // Yeni deal için ID yok
        title: '',
        description: '',
        price: 0,
        originalPrice: 0,
        url: '',
        link: '',
        category: 'elektronik', // Varsayılan kategori
        subcategory: null,
        imageUrl: '',
        imageUrls: [],
        store: '',
        isApproved: false,
        isHot: false,
        couponCode: '',
        hotVotes: 0,
        coldVotes: 0,
        expiredVotes: 0,
        commentCount: 0,
        postedBy: currentUser ? currentUser.uid : 'admin',
        createdAt: new Date(),
        isEditorPick: false,
        isExpired: false,
        isUserSubmitted: false // Admin tarafından eklenen deal'ler bot deal'i olarak işaretlenir
    };

    // Modal'ı aç
    await showDealModal(newDeal);

    // Buton metnini "Oluştur" olarak değiştir
    setTimeout(() => {
        const saveBtn = document.getElementById('saveBtn');
        if (saveBtn) {
            saveBtn.innerHTML = '<span class="material-symbols-outlined text-[18px]">add</span><span>Oluştur</span>';
        }
    }, 200);
}

// Update stats
async function updateStats() {
    try {
        console.log('Updating stats...');
        const pending = deals.filter(d => d.isApproved === false && d.isRejected !== true && d.isExpired !== true && d.status !== 'expired' && d.status !== 'rejected').length;
        const approved = deals.filter(d => d.isApproved === true && d.isExpired !== true && d.status !== 'expired' && d.isRejected !== true && d.status !== 'rejected').length;
        const bot = deals.filter(d => !d.isUserSubmitted || d.isUserSubmitted === false).length;
        const user = deals.filter(d => d.isUserSubmitted === true).length;

        console.log('Stats:', { pending, approved, bot, user });

        const pendingEl = document.getElementById('pendingCount');
        const approvedEl = document.getElementById('approvedCount');
        const botEl = document.getElementById('botCount');
        const userEl = document.getElementById('userCount');

        if (pendingEl) pendingEl.textContent = pending;
        if (approvedEl) approvedEl.textContent = approved;
        if (botEl) botEl.textContent = bot;
        if (userEl) userEl.textContent = user;

        console.log('Stats updated successfully');
    } catch (error) {
        console.error('Update stats error:', error);
    }
}

// Format date
function formatDate(date) {
    if (!date) return 'Bilinmiyor';
    const d = new Date(date);
    const now = new Date();
    const diff = now - d;
    const minutes = Math.floor(diff / 60000);
    const hours = Math.floor(diff / 3600000);
    const days = Math.floor(diff / 86400000);

    if (minutes < 1) return 'Şimdi';
    if (minutes < 60) return `${minutes} dakika önce`;
    if (hours < 24) return `${hours} saat önce`;
    if (days === 1) return 'Dün';
    if (days < 7) return `${days} gün önce`;

    return d.toLocaleDateString('tr-TR', {
        year: 'numeric',
        month: 'long',
        day: 'numeric',
        hour: '2-digit',
        minute: '2-digit'
    });
}

// Escape HTML
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Global functions for onclick handlers (inline onclick için)
async function handleApproveDeal(event) {
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }

    console.log('✅ handleApproveDeal called!', currentDeal?.id);

    if (!currentDeal) {
        console.error('❌ No current deal!');
        showError('Fırsat bulunamadı!');
        return;
    }

    // Onayla butonu tıklandığında DOM select değerini 'active' yap
    const editStatusEl = document.getElementById('editStatus');
    if (editStatusEl) {
        editStatusEl.value = 'active';
    }

    const saveBtn = document.getElementById('saveBtn');
    if (saveBtn) {
        saveBtn.disabled = true;
        const originalHTML = saveBtn.innerHTML;
        saveBtn.innerHTML = '<span>Onaylanıyor...</span>';

        try {
            await saveDealChanges();
        } catch (error) {
            console.error('❌ Onaylama hatası:', error);
            saveBtn.disabled = false;
            saveBtn.innerHTML = originalHTML;
        }
    }
}

function handleCancelDeal(event) {
    if (event) {
        event.preventDefault();
        event.stopPropagation();
    }

    console.log('❌ handleCancelDeal called!');
    closeDealModal();
}

// View management
function showView(viewId) {
    const views = ['dashboardView', 'dealsView', 'couponsView', 'catalogsView', 'usersView', 'messagesView', 'reportsView', 'settingsView', 'notificationsView', 'logsView', 'telegramBotView', 'observabilityView'];
    views.forEach(id => {
        const el = document.getElementById(id);
        if (el) {
            if (id === viewId) {
                el.classList.remove('hidden');
            } else {
                el.classList.add('hidden');
            }
        }
    });
}

function showDashboardView() {
    currentView = 'dashboard';
    showView('dashboardView');
    updateMenuActiveState('dashboard');
    loadDashboardData();
}


function showDealsView() {
    currentView = 'deals';
    showView('dealsView');

    // Aktif filter butonunu kontrol et ve currentFilter'ı ayarla
    const activeFilterBtn = document.querySelector('.filter-btn.active');
    if (activeFilterBtn) {
        currentFilter = activeFilterBtn.dataset.filter || 'all';
    } else {
        currentFilter = 'all';
    }

    updateMenuActiveState('deals');

    if (deals && deals.length > 0) {
        renderDeals();
    }
}

function showUsersView(query = '') {
    currentView = 'users';
    showView('usersView');
    updateMenuActiveState('users');
    if (query && typeof query === 'string') {
        usersSearchQuery = query.trim().toLowerCase();
        const sInput = document.getElementById('usersSearchInput');
        if (sInput) sInput.value = query.trim();
    }
    if (users.length === 0) {
        loadUsers();
    } else {
        renderUsers();
    }

    setTimeout(() => {
        const usersSearchInput = document.getElementById('usersSearchInput');
        if (usersSearchInput) {
            if (usersSearchQuery) {
                usersSearchInput.value = usersSearchQuery;
            }
            const newInput = usersSearchInput.cloneNode(true);
            usersSearchInput.parentNode.replaceChild(newInput, usersSearchInput);

            newInput.addEventListener('input', (e) => {
                usersSearchQuery = e.target.value.trim().toLowerCase();
                renderUsers();
            });
        }

        const exportBtn = document.getElementById('exportUsersBtn');
        if (exportBtn) {
            const newExportBtn = exportBtn.cloneNode(true);
            exportBtn.parentNode.replaceChild(newExportBtn, exportBtn);
            newExportBtn.addEventListener('click', (e) => {
                e.preventDefault();
                exportUsersToCSV();
            });
        }
    }, 100);
}

// ==========================================
// MESAJLAŞMA & SİMÜLATÖR SİSTEMİ (TEST CENTER)
// ==========================================

let simSender = {
    id: 'test_user_ahmet',
    name: 'Ahmet Yılmaz (Test)',
    imageUrl: '',
    isPreset: true,
    role: 'Test Kullanıcı 1'
};
let simReceiver = null;
let simSelectedDeal = null;
let simChatUnsubscribe = null;
let simCurrentTab = 'simulator';

window.switchMessagesTab = function(tabName) {
    simCurrentTab = (tabName === 'moderation') ? 'simulator' : tabName;
    const simContainer = document.getElementById('msgSimContainer');
    const botContainer = document.getElementById('msgBotContainer');
    const tabSimBtn = document.getElementById('msgTabSimBtn');
    const tabBotBtn = document.getElementById('msgTabBotBtn');

    // Reset all containers
    if (simContainer) simContainer.classList.add('hidden');
    if (botContainer) {
        botContainer.classList.add('hidden');
        botContainer.classList.remove('grid');
    }

    // Reset button styles
    const defaultBtnClass = 'px-5 py-3 font-semibold text-sm border-b-2 border-transparent text-slate-400 hover:text-white flex items-center gap-2 transition-colors relative cursor-pointer';
    const activeBtnClass = 'px-5 py-3 font-bold text-sm border-b-2 border-primary text-primary flex items-center gap-2 transition-colors relative cursor-pointer';

    if (tabSimBtn) tabSimBtn.className = defaultBtnClass;
    if (tabBotBtn) tabBotBtn.className = defaultBtnClass;

    if (simCurrentTab === 'simulator') {
        if (simContainer) simContainer.classList.remove('hidden');
        if (tabSimBtn) tabSimBtn.className = activeBtnClass;
        initMessagingSimulator();
    } else if (simCurrentTab === 'botkolik') {
        if (botContainer) {
            botContainer.classList.remove('hidden');
            botContainer.classList.add('grid');
        }
        if (tabBotBtn) tabBotBtn.className = activeBtnClass;
        loadBotkolikMessages();
    }
    updateBotkolikUnreadBadge();
};

function showMessagesView() {
    currentView = 'messages';
    showView('messagesView');
    updateMenuActiveState('messages');
    window.switchMessagesTab(simCurrentTab === 'moderation' ? 'simulator' : (simCurrentTab || 'simulator'));
}

function loadMessages() {
    window.switchMessagesTab(simCurrentTab === 'moderation' ? 'simulator' : (simCurrentTab || 'simulator'));
}

async function loadUsersForSimulator(forceRefresh = false) {
    try {
        if (!forceRefresh && users && users.length > 0) {
            return users;
        }

        console.log('📥 Firestore\'dan simülatör için kullanıcılar çekiliyor...');
        const snapshot = await db.collection('users').limit(200).get();
        const loadedUsers = [];
        snapshot.forEach(doc => {
            const data = doc.data();
            loadedUsers.push({
                id: doc.id,
                uid: doc.id,
                ...data,
                profileImageUrl: typeof cleanProfileImageUrl === 'function' ? cleanProfileImageUrl(data.profileImageUrl) : (data.profileImageUrl || '')
            });
        });
        users = loadedUsers;
        console.log(`✅ Simülatör için ${users.length} adet kullanıcı yüklendi.`);
        return users;
    } catch (e) {
        console.error('❌ Kullanıcıları çekme hatası:', e);
        return [];
    }
}

window.reloadSimulatorUsers = async function() {
    const receiverSelect = document.getElementById('simReceiverSelect');
    if (receiverSelect) {
        receiverSelect.innerHTML = '<option value="">-- Kullanıcılar Yükleniyor... --</option>';
    }
    await loadUsersForSimulator(true);
    populateSimUserDropdowns();
    showSuccess(`Kullanıcı listesi güncellendi (${users.length} kullanıcı).`);
};

async function initMessagingSimulator() {
    console.log('🧪 Mesajlaşma simülatörü başlatılıyor...');

    // Kullanıcıları ve Fırsatları Firestore'dan yükle
    if (!users || users.length === 0) {
        await loadUsersForSimulator();
    }

    if (!deals || deals.length === 0) {
        try {
            const dealSnapshot = await db.collection('deals').orderBy('createdAt', 'desc').limit(50).get();
            const loadedDeals = [];
            dealSnapshot.forEach(doc => {
                loadedDeals.push({ id: doc.id, ...doc.data() });
            });
            deals = loadedDeals;
        } catch (e) {
            console.warn('Deals load error:', e);
        }
    }

    populateSimUserDropdowns();
    populateSimDealDropdown();
    updateSimSenderPreview();
    updateSimReceiverPreview();
}

function populateSimUserDropdowns() {
    const receiverSelect = document.getElementById('simReceiverSelect');
    const senderSelect = document.getElementById('simSenderSelect');

    if (!receiverSelect) return;

    if (!users || users.length === 0) {
        receiverSelect.innerHTML = '<option value="">-- Kullanıcı Bulunamadı --</option>';
        if (senderSelect) senderSelect.innerHTML = '<option value="">-- Kullanıcı Bulunamadı --</option>';
        return;
    }

    let optionsHtml = `<option value="">-- Listeden Kullanıcı Seçin (${users.length} üye) --</option>`;
    optionsHtml += users.map(u => {
        const name = escapeHtml(u.username || u.nickname || 'Kullanıcı');
        const uid = escapeHtml(u.uid || u.id || '');
        const email = u.email ? ` (${escapeHtml(u.email)})` : '';
        return `<option value="${uid}">${name}${email} - [${uid.substring(0, 8)}...]</option>`;
    }).join('');

    receiverSelect.innerHTML = optionsHtml;
    if (senderSelect) senderSelect.innerHTML = optionsHtml;
}

function populateSimDealDropdown() {
    const dealSelect = document.getElementById('simDealSelect');
    if (!dealSelect) return;

    let optionsHtml = '<option value="">-- Fırsat Seçin --</option>';
    if (deals && deals.length > 0) {
        optionsHtml += deals.slice(0, 50).map(d => {
            const title = escapeHtml(d.title || d.baslik || 'Fırsat');
            const price = d.price || d.fiyat || 0;
            return `<option value="${d.id}">${title} - ${price} TL</option>`;
        }).join('');
    }
    dealSelect.innerHTML = optionsHtml;
}

window.handleSimReceiverSelectChange = function() {
    const select = document.getElementById('simReceiverSelect');
    if (!select) return;
    const uid = select.value;
    if (!uid) {
        simReceiver = null;
        updateSimReceiverPreview();
        return;
    }

    const user = users.find(u => (u.uid || u.id) === uid);
    if (user) {
        simReceiver = {
            id: user.uid || user.id,
            name: user.username || user.nickname || 'Kullanıcı',
            imageUrl: cleanProfileImageUrl(user.profileImageUrl),
            email: user.email || '',
            isAdmin: user.isAdmin === true || user.isadmin === true
        };
        updateSimReceiverPreview();
        startLiveChatStream();
    } else {
        window.fetchSimUserByUid('receiver', uid);
    }
};

window.handleSimSenderSelectChange = function() {
    const select = document.getElementById('simSenderSelect');
    if (!select) return;
    const uid = select.value;
    if (!uid) return;

    const user = users.find(u => (u.uid || u.id) === uid);
    if (user) {
        simSender = {
            id: user.uid || user.id,
            name: user.username || user.nickname || 'Kullanıcı',
            imageUrl: cleanProfileImageUrl(user.profileImageUrl),
            isPreset: false,
            role: 'Gerçek Üye'
        };
        updateSimSenderPreview();
        startLiveChatStream();
    }
};

window.fetchSimUserByUid = async function(targetType, inputUid) {
    const uidInput = document.getElementById(targetType === 'receiver' ? 'simReceiverUidInput' : 'simSenderUidInput');
    const uid = (inputUid || (uidInput ? uidInput.value : '')).trim();

    if (!uid) {
        showError('Lütfen geçerli bir UID girin!');
        return;
    }

    try {
        const doc = await db.collection('users').doc(uid).get();
        if (doc.exists) {
            const data = doc.data();
            const userInfo = {
                id: doc.id,
                name: data.username || data.nickname || 'Kullanıcı',
                imageUrl: cleanProfileImageUrl(data.profileImageUrl),
                email: data.email || '',
                isAdmin: data.isAdmin === true || data.isadmin === true,
                role: 'Veritabanı Üyesi'
            };

            if (targetType === 'receiver') {
                simReceiver = userInfo;
                updateSimReceiverPreview();
                showSuccess(`Alıcı kullanıcı bulundu: ${userInfo.name}`);
            } else {
                simSender = userInfo;
                updateSimSenderPreview();
                showSuccess(`Gönderen kullanıcı bulundu: ${userInfo.name}`);
            }
            startLiveChatStream();
        } else {
            showError(`UID "${uid}" veritabanında bulunamadı!`);
        }
    } catch (e) {
        console.error('Fetch user by UID error:', e);
        showError('Kullanıcı sorgulama hatası: ' + e.message);
    }
};

window.setSimSenderPreset = function(presetType) {
    const dropdownContainer = document.getElementById('simSenderDropdownContainer');

    if (presetType === 'user1') {
        if (dropdownContainer) dropdownContainer.classList.add('hidden');
        simSender = {
            id: 'test_user_ahmet',
            name: 'Ahmet Yılmaz (Test)',
            imageUrl: '',
            isPreset: true,
            role: 'Test Kullanıcı 1'
        };
    } else if (presetType === 'user2') {
        if (dropdownContainer) dropdownContainer.classList.add('hidden');
        simSender = {
            id: 'test_user_zeynep',
            name: 'Zeynep Kaya (Test)',
            imageUrl: 'assets/profil.jpg',
            isPreset: true,
            role: 'Test Kullanıcı 2'
        };
    } else if (presetType === 'admin') {
        if (dropdownContainer) dropdownContainer.classList.add('hidden');
        simSender = {
            id: 'admin',
            name: 'FırsatKolik Yönetim',
            imageUrl: 'assets/logo.webp',
            isPreset: true,
            role: 'Resmi Yönetim'
        };
    } else if (presetType === 'custom') {
        if (dropdownContainer) dropdownContainer.classList.remove('hidden');
        populateSimUserDropdowns();
        return;
    }

    updateSimSenderPreview();
    startLiveChatStream();
};

function updateSimSenderPreview() {
    const nameEl = document.getElementById('simSenderName');
    const uidEl = document.getElementById('simSenderUid');
    const badgeEl = document.getElementById('simSenderRoleBadge');
    const placeholderEl = document.getElementById('simSenderAvatarPlaceholder');
    const imgEl = document.getElementById('simSenderAvatarImg');

    if (nameEl) nameEl.textContent = simSender.name;
    if (uidEl) uidEl.textContent = `UID: ${simSender.id}`;
    if (badgeEl) badgeEl.textContent = simSender.role || 'Sender';

    if (simSender.imageUrl) {
        if (imgEl) {
            imgEl.src = simSender.imageUrl;
            imgEl.classList.remove('hidden');
        }
        if (placeholderEl) placeholderEl.classList.add('hidden');
    } else {
        if (imgEl) imgEl.classList.add('hidden');
        if (placeholderEl) {
            placeholderEl.textContent = (simSender.name || 'S').charAt(0).toUpperCase();
            placeholderEl.classList.remove('hidden');
        }
    }
}

function updateSimReceiverPreview() {
    const nameEl = document.getElementById('simReceiverName');
    const uidEl = document.getElementById('simReceiverUid');
    const badgeEl = document.getElementById('simReceiverRoleBadge');
    const placeholderEl = document.getElementById('simReceiverAvatarPlaceholder');
    const imgEl = document.getElementById('simReceiverAvatarImg');

    if (!simReceiver) {
        if (nameEl) nameEl.textContent = 'Alıcı Seçilmedi';
        if (uidEl) uidEl.textContent = 'UID: -';
        if (badgeEl) badgeEl.classList.add('hidden');
        if (imgEl) imgEl.classList.add('hidden');
        if (placeholderEl) {
            placeholderEl.textContent = '?';
            placeholderEl.classList.remove('hidden');
        }
        return;
    }

    if (nameEl) nameEl.textContent = simReceiver.name;
    if (uidEl) uidEl.textContent = `UID: ${simReceiver.id}`;

    if (simReceiver.isAdmin) {
        if (badgeEl) {
            badgeEl.textContent = 'Admin';
            badgeEl.classList.remove('hidden');
        }
    } else {
        if (badgeEl) badgeEl.classList.add('hidden');
    }

    if (simReceiver.imageUrl) {
        if (imgEl) {
            imgEl.src = simReceiver.imageUrl;
            imgEl.classList.remove('hidden');
        }
        if (placeholderEl) placeholderEl.classList.add('hidden');
    } else {
        if (imgEl) imgEl.classList.add('hidden');
        if (placeholderEl) {
            placeholderEl.textContent = (simReceiver.name || 'R').charAt(0).toUpperCase();
            placeholderEl.classList.remove('hidden');
        }
    }
}

window.insertSimTemplate = function(templateText) {
    const textarea = document.getElementById('simMessageText');
    if (textarea) {
        textarea.value = templateText;
        textarea.focus();
    }
};

window.toggleSimDealAttachment = function() {
    const container = document.getElementById('simDealAttachContainer');
    const toggleText = document.getElementById('simDealAttachToggleText');

    if (container) {
        if (container.classList.contains('hidden')) {
            container.classList.remove('hidden');
            if (toggleText) toggleText.textContent = '- Fırsat Bağlantısını Kaldır';
            populateSimDealDropdown();
        } else {
            container.classList.add('hidden');
            if (toggleText) toggleText.textContent = '+ Fırsat Bağla';
            simSelectedDeal = null;
            const preview = document.getElementById('simDealPreview');
            if (preview) preview.classList.add('hidden');
        }
    }
};

window.handleSimDealSelectChange = function() {
    const select = document.getElementById('simDealSelect');
    const preview = document.getElementById('simDealPreview');
    const imgEl = document.getElementById('simDealPreviewImg');
    const titleEl = document.getElementById('simDealPreviewTitle');
    const priceEl = document.getElementById('simDealPreviewPrice');

    if (!select || !select.value) {
        simSelectedDeal = null;
        if (preview) preview.classList.add('hidden');
        return;
    }

    const deal = deals.find(d => d.id === select.value);
    if (deal) {
        simSelectedDeal = deal;
        if (preview) preview.classList.remove('hidden');
        if (imgEl) imgEl.src = deal.imageUrl || deal.gorselUrl || '';
        if (titleEl) titleEl.textContent = deal.title || deal.baslik || '';
        if (priceEl) priceEl.textContent = `${deal.price || deal.fiyat || 0} TL`;
    }
};

window.sendSimulatedMessage = async function() {
    if (!simReceiver) {
        showError('Lütfen mesaj gönderilecek bir Alıcı Kullanıcı (Receiver) seçin!');
        return;
    }

    const textarea = document.getElementById('simMessageText');
    const text = (textarea ? textarea.value : '').trim();

    if (!text) {
        showError('Lütfen gönderilecek mesaj metnini yazın!');
        return;
    }

    const btn = document.getElementById('simSendBtn');
    const originalHtml = btn ? btn.innerHTML : '';
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<span class="material-symbols-outlined animate-spin text-[20px]">sync</span><span>Gönderiliyor...</span>';
    }

    try {
        console.log(`🚀 Simüle mesaj gönderiliyor: ${simSender.name} -> ${simReceiver.name} (${simReceiver.id})`);

        const u1 = String(simSender.id || '');
        const u2 = String(simReceiver.id || '');
        const conversationId = [u1, u2].sort().join('_');

        const messageData = {
            conversationId: conversationId,
            senderId: simSender.id,
            senderName: simSender.name,
            senderImageUrl: simSender.imageUrl || '',
            receiverId: simReceiver.id,
            receiverName: simReceiver.name || 'Kullanıcı',
            receiverImageUrl: simReceiver.imageUrl || '',
            text: text,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            isReadByAdmin: false,
            deletedBy: []
        };

        if (simSelectedDeal) {
            messageData.dealId = simSelectedDeal.id;
            messageData.dealTitle = simSelectedDeal.title || simSelectedDeal.baslik || '';
            messageData.dealImageUrl = simSelectedDeal.imageUrl || simSelectedDeal.gorselUrl || '';
            messageData.dealPrice = simSelectedDeal.price ? String(simSelectedDeal.price) : '';
            messageData.dealStore = simSelectedDeal.store || simSelectedDeal.magazaAdi || '';
        }

        const docRef = await db.collection('messages').add(messageData);
        console.log('✅ Simüle mesaj yazıldı! Message ID:', docRef.id);

        showSuccess(`✅ Mesaj simüle edildi! FCM bildirimi tetiklendi. (ID: ${docRef.id.substring(0, 8)}...)`);

        if (textarea) textarea.value = '';

        if (btn) {
            btn.disabled = false;
            btn.innerHTML = originalHtml;
        }

        // Restart/refresh chat stream to show message immediately
        startLiveChatStream();
    } catch (error) {
        console.error('❌ Mesaj simülasyon hatası:', error);
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = originalHtml;
        }
        showError('Mesaj gönderilirken hata oluştu: ' + error.message);
    }
};

window.sendQuickSimMessage = function() {
    const input = document.getElementById('simQuickInput');
    if (!input) return;
    const text = input.value.trim();
    if (!text) return;

    const textarea = document.getElementById('simMessageText');
    if (textarea) textarea.value = text;

    input.value = '';
    window.sendSimulatedMessage();
};

function startLiveChatStream() {
    if (simChatUnsubscribe) {
        simChatUnsubscribe();
        simChatUnsubscribe = null;
    }

    const container = document.getElementById('simChatStreamContainer');
    const headerTitle = document.getElementById('chatHeaderTitle');
    const headerSubtitle = document.getElementById('chatHeaderSubtitle');
    const headerAvatarImg = document.getElementById('chatHeaderAvatarImg');
    const headerAvatarPlaceholder = document.getElementById('chatHeaderAvatarPlaceholder');

    if (!simReceiver) {
        if (headerTitle) headerTitle.textContent = 'Canlı Sohbet Odası';
        if (headerSubtitle) headerSubtitle.textContent = 'Lütfen sol taraftan Alıcı ve Gönderen seçin.';
        if (container) {
            container.innerHTML = `
                <div id="simChatEmptyState" class="m-auto flex flex-col items-center justify-center text-center p-8 max-w-sm">
                    <div class="w-16 h-16 rounded-full bg-primary/10 text-primary flex items-center justify-center mb-3">
                        <span class="material-symbols-outlined text-3xl">chat_bubble</span>
                    </div>
                    <h4 class="font-bold text-base text-slate-900 dark:text-white mb-1">Canlı Sohbet Simülatörü</h4>
                    <p class="text-xs text-slate-500 dark:text-slate-400">
                        Sol panellerden **Alıcı** kullanıcıyı seçtiğinizde, ikisi arasındaki canlı sohbet akışı burada anlık olarak akacaktır.
                    </p>
                </div>
            `;
        }
        return;
    }

    if (headerTitle) headerTitle.textContent = `${simSender.name} ➔ ${simReceiver.name}`;
    if (headerSubtitle) headerSubtitle.textContent = `Alıcı UID: ${simReceiver.id} • Gönderen UID: ${simSender.id}`;

    if (simReceiver.imageUrl) {
        if (headerAvatarImg) {
            headerAvatarImg.src = simReceiver.imageUrl;
            headerAvatarImg.classList.remove('hidden');
        }
        if (headerAvatarPlaceholder) headerAvatarPlaceholder.classList.add('hidden');
    } else {
        if (headerAvatarImg) headerAvatarImg.classList.add('hidden');
        if (headerAvatarPlaceholder) {
            headerAvatarPlaceholder.textContent = (simReceiver.name || 'R').charAt(0).toUpperCase();
            headerAvatarPlaceholder.classList.remove('hidden');
        }
    }

    console.log(`📡 Canlı sohbet akışı başlatılıyor: ${simSender.id} <-> ${simReceiver.id}`);

    simChatUnsubscribe = db.collection('messages')
        .where('senderId', 'in', [simSender.id, simReceiver.id])
        .onSnapshot((snapshot) => {
            const messagesList = [];
            snapshot.forEach(doc => {
                const d = doc.data();
                if ((d.senderId === simSender.id && d.receiverId === simReceiver.id) ||
                    (d.senderId === simReceiver.id && d.receiverId === simSender.id)) {
                    messagesList.push({
                        id: doc.id,
                        ...d,
                        createdAtDate: d.createdAt ? (d.createdAt.toDate ? d.createdAt.toDate() : new Date(d.createdAt)) : new Date()
                    });
                }
            });

            messagesList.sort((a, b) => a.createdAtDate - b.createdAtDate);
            renderLiveChatMessages(messagesList);
        }, (err) => {
            console.warn('Chat stream query fallback triggered:', err);
            db.collection('messages').get().then(snapshot => {
                const messagesList = [];
                snapshot.forEach(doc => {
                    const d = doc.data();
                    if ((d.senderId === simSender.id && d.receiverId === simReceiver.id) ||
                        (d.senderId === simReceiver.id && d.receiverId === simSender.id)) {
                        messagesList.push({
                            id: doc.id,
                            ...d,
                            createdAtDate: d.createdAt ? (d.createdAt.toDate ? d.createdAt.toDate() : new Date(d.createdAt)) : new Date()
                        });
                    }
                });
                messagesList.sort((a, b) => a.createdAtDate - b.createdAtDate);
                renderLiveChatMessages(messagesList);
            });
        });
}

function renderLiveChatMessages(messagesList) {
    const container = document.getElementById('simChatStreamContainer');
    if (!container) return;

    if (messagesList.length === 0) {
        container.innerHTML = `
            <div class="m-auto flex flex-col items-center justify-center text-center p-6 bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 shadow-sm max-w-sm">
                <span class="material-symbols-outlined text-4xl text-slate-400 mb-2">mark_chat_unread</span>
                <p class="font-bold text-sm text-slate-800 dark:text-slate-200">Henüz sohbet mesajı yok</p>
                <p class="text-xs text-slate-400 mt-1">Aşağıdaki mesaj kutusundan ilk test mesajını gönderin!</p>
            </div>
        `;
        return;
    }

    container.innerHTML = messagesList.map(msg => {
        const isMe = msg.senderId === simSender.id;
        const timeStr = msg.createdAtDate ? msg.createdAtDate.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' }) : '';
        const isReadBadge = msg.isRead
            ? '<span class="text-blue-400 font-bold" title="Okundu">✓✓</span>'
            : '<span class="text-slate-400" title="İletildi">✓</span>';

        let dealBadgeHtml = '';
        if (msg.dealTitle) {
            dealBadgeHtml = `
                <div class="mb-2 p-2 bg-slate-900/30 rounded border border-white/10 flex items-center gap-2 text-xs">
                    ${msg.dealImageUrl ? `<img src="${msg.dealImageUrl}" class="w-8 h-8 object-cover rounded bg-slate-800">` : ''}
                    <div class="flex flex-col min-w-0 flex-1">
                        <span class="font-bold truncate">${escapeHtml(msg.dealTitle)}</span>
                        ${msg.dealPrice ? `<span class="text-amber-400 font-semibold">${escapeHtml(msg.dealPrice)} TL</span>` : ''}
                    </div>
                </div>
            `;
        }

        if (isMe) {
            return `
                <div class="flex flex-col items-end max-w-[85%] self-end">
                    <div class="p-3.5 bg-primary text-white rounded-2xl rounded-tr-xs shadow-sm flex flex-col gap-1">
                        <span class="text-[10px] font-bold text-blue-200">${escapeHtml(msg.senderName || simSender.name)}</span>
                        ${dealBadgeHtml}
                        <p class="text-sm font-medium leading-relaxed whitespace-pre-wrap">${escapeHtml(msg.text)}</p>
                    </div>
                    <div class="flex items-center gap-1.5 mt-1 px-1 text-[10px] text-slate-400 font-medium">
                        <span>${timeStr}</span>
                        ${isReadBadge}
                    </div>
                </div>
            `;
        } else {
            return `
                <div class="flex items-start gap-2.5 max-w-[85%] self-start">
                    <div class="w-8 h-8 rounded-full bg-emerald-500/20 text-emerald-500 font-bold flex items-center justify-center text-xs overflow-hidden shrink-0 mt-1">
                        ${msg.senderImageUrl ? `<img src="${msg.senderImageUrl}" class="w-full h-full object-cover">` : (msg.senderName || 'R').charAt(0).toUpperCase()}
                    </div>
                    <div class="flex flex-col items-start">
                        <div class="p-3.5 bg-white dark:bg-surface-dark text-slate-900 dark:text-white border border-slate-200 dark:border-slate-800 rounded-2xl rounded-tl-xs shadow-sm flex flex-col gap-1">
                            <span class="text-[10px] font-bold text-emerald-500">${escapeHtml(msg.senderName || simReceiver.name)}</span>
                            ${dealBadgeHtml}
                            <p class="text-sm font-medium leading-relaxed whitespace-pre-wrap">${escapeHtml(msg.text)}</p>
                        </div>
                        <div class="flex items-center gap-1.5 mt-1 px-1 text-[10px] text-slate-400 font-medium">
                            <span>${timeStr}</span>
                        </div>
                    </div>
                </div>
            `;
        }
    }).join('');

    setTimeout(() => {
        container.scrollTop = container.scrollHeight;
    }, 50);
}

window.reloadLiveChatStream = function() {
    startLiveChatStream();
};

// ============================================================================
// 🤖 BOTKOLİK MESAJLARI & GERİ BİLDİRİM YÖNETİM MODÜLÜ
// ============================================================================

let botkolikConversations = [];
let botkolikActiveUserId = null;
let botkolikActiveUser = null;
let botkolikChatUnsubscribe = null;
let botkolikFilterMode = 'all';

async function updateBotkolikUnreadBadge() {
    try {
        const snap = await db.collection('messages')
            .where('receiverId', '==', 'botkolik')
            .where('isRead', '==', false)
            .get();
        const unreadCount = snap.size;
        const badge = document.getElementById('botUnreadBadge');
        if (badge) {
            if (unreadCount > 0) {
                badge.innerText = unreadCount > 99 ? '99+' : unreadCount;
                badge.classList.remove('hidden');
            } else {
                badge.classList.add('hidden');
            }
        }
    } catch (e) {
        console.warn('Botkolik unread badge check failed:', e);
    }
}

function renderUserAvatarHtml(imageUrl, userName, sizeClass = 'w-10 h-10', textClass = 'text-sm') {
    const displayName = (userName || 'K').trim();
    const fallbackAvatar = 'https://ui-avatars.com/api/?name=' + encodeURIComponent(displayName) + '&background=135bec&color=fff&size=128';

    let resolvedUrl = '';
    if (typeof imageUrl === 'string' && imageUrl.trim()) {
        const trimmed = imageUrl.trim();
        if (typeof cleanProfileImageUrl === 'function') {
            resolvedUrl = cleanProfileImageUrl(trimmed);
        } else if (trimmed.startsWith('assets/')) {
            resolvedUrl = '/' + trimmed;
        } else {
            resolvedUrl = trimmed;
        }
    }

    const src = resolvedUrl || fallbackAvatar;

    return `
        <div class="${sizeClass} rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center overflow-hidden shrink-0 shadow-sm">
            <img src="${src}" alt="${escapeHtml(displayName)}" class="w-full h-full object-cover" onerror="this.onerror=null; this.src='${fallbackAvatar}';">
        </div>
    `;
}

function renderBotkolikAvatarHtml(sizeClass = 'w-8 h-8') {
    return `
        <div class="${sizeClass} rounded-full bg-primary/10 border border-primary/30 flex items-center justify-center overflow-hidden shrink-0 mt-1 shadow-sm">
            <span class="material-symbols-outlined text-[18px] text-primary">smart_toy</span>
        </div>
    `;
}

window.loadBotkolikMessages = async function() {
    const listContainer = document.getElementById('botConversationsList');
    if (!listContainer) return;

    listContainer.innerHTML = `
        <div class="p-8 text-center text-slate-400 text-xs flex flex-col items-center gap-2 m-auto">
            <span class="material-symbols-outlined text-3xl opacity-40 animate-spin text-primary">sync</span>
            <span>Botkolik mesajları taranıyor...</span>
        </div>
    `;

    try {
        // 1. Get messages where receiver is botkolik
        const snapReceived = await db.collection('messages')
            .where('receiverId', '==', 'botkolik')
            .get();

        // 2. Get messages where sender is botkolik
        const snapSent = await db.collection('messages')
            .where('senderId', '==', 'botkolik')
            .get();

        const convMap = new Map();

        // Process incoming messages to Botkolik
        snapReceived.forEach(doc => {
            const data = doc.data();
            const userId = data.senderId;
            if (!userId || userId === 'botkolik') return;

            const date = data.createdAt ? (data.createdAt.toDate ? data.createdAt.toDate() : new Date(data.createdAt)) : new Date();

            if (!convMap.has(userId)) {
                convMap.set(userId, {
                    userId: userId,
                    userName: data.senderName || 'Kullanıcı',
                    userImageUrl: data.senderImageUrl || '',
                    lastMessage: data.text || '',
                    lastDate: date,
                    unreadCount: 0,
                    totalMessages: 0,
                    lastSenderId: data.senderId,
                    lastDealTitle: data.dealTitle || null
                });
            }

            const conv = convMap.get(userId);
            conv.totalMessages++;
            if (!data.isRead) {
                conv.unreadCount++;
            }
            if (date >= conv.lastDate) {
                conv.lastDate = date;
                conv.lastMessage = data.text || '';
                conv.lastSenderId = data.senderId;
                conv.lastDealTitle = data.dealTitle || null;
            }
            if (data.senderName && (!conv.userName || conv.userName === 'Kullanıcı')) {
                conv.userName = data.senderName;
            }
            if (data.senderImageUrl && !conv.userImageUrl) {
                conv.userImageUrl = data.senderImageUrl;
            }
        });

        // Process outgoing messages from Botkolik
        snapSent.forEach(doc => {
            const data = doc.data();
            const userId = data.receiverId;
            if (!userId || userId === 'botkolik') return;

            const date = data.createdAt ? (data.createdAt.toDate ? data.createdAt.toDate() : new Date(data.createdAt)) : new Date();

            if (!convMap.has(userId)) {
                convMap.set(userId, {
                    userId: userId,
                    userName: data.receiverName || 'Kullanıcı',
                    userImageUrl: data.receiverImageUrl || '',
                    lastMessage: data.text || '',
                    lastDate: date,
                    unreadCount: 0,
                    totalMessages: 0,
                    lastSenderId: data.senderId,
                    lastDealTitle: data.dealTitle || null
                });
            }

            const conv = convMap.get(userId);
            conv.totalMessages++;
            if (date >= conv.lastDate) {
                conv.lastDate = date;
                conv.lastMessage = data.text || '';
                conv.lastSenderId = data.senderId;
                conv.lastDealTitle = data.dealTitle || null;
            }
            if (data.receiverName && (!conv.userName || conv.userName === 'Kullanıcı')) {
                conv.userName = data.receiverName;
            }
            if (data.receiverImageUrl && !conv.userImageUrl) {
                conv.userImageUrl = data.receiverImageUrl;
            }
        });

        // Fetch user profiles from 'users' collection to ensure live avatars and names
        const userIds = Array.from(convMap.keys());
        if (userIds.length > 0) {
            try {
                const userDocs = await Promise.all(
                    userIds.map(uid => db.collection('users').doc(uid).get().catch(() => null))
                );
                userDocs.forEach((docSnap, index) => {
                    if (docSnap && docSnap.exists) {
                        const uData = docSnap.data();
                        const uid = userIds[index];
                        const conv = convMap.get(uid);
                        if (conv && uData) {
                            if (uData.username || uData.displayName) {
                                conv.userName = uData.username || uData.displayName;
                            }
                            const pImg = uData.profileImageUrl || uData.photoURL || uData.avatarUrl;
                            if (pImg) {
                                conv.userImageUrl = pImg;
                            }
                        }
                    }
                });
            } catch (uErr) {
                console.warn('Could not batch fetch user profiles:', uErr);
            }
        }

        // Convert Map to array and sort by most recent message
        botkolikConversations = Array.from(convMap.values()).sort((a, b) => b.lastDate - a.lastDate);

        // Update counts
        const countLabel = document.getElementById('botTotalConversationsCount');
        if (countLabel) {
            countLabel.innerText = `${botkolikConversations.length} Kullanıcı`;
        }

        updateBotkolikUnreadBadge();
        window.renderBotkolikConversations();

        // If previously selected user is still in the list, auto-select them
        if (botkolikActiveUserId && botkolikConversations.some(c => c.userId === botkolikActiveUserId)) {
            window.selectBotkolikConversation(botkolikActiveUserId);
        }
    } catch (e) {
        console.error('Error loading Botkolik conversations:', e);
        listContainer.innerHTML = `
            <div class="p-8 text-center text-red-500 text-xs">
                Botkolik mesajları yüklenirken hata oluştu: ${e.message}
            </div>
        `;
    }
};

window.setBotkolikFilter = function(filterMode) {
    botkolikFilterMode = filterMode;
    const allBtn = document.getElementById('botFilterAllBtn');
    const unreadBtn = document.getElementById('botFilterUnreadBtn');
    const repliedBtn = document.getElementById('botFilterRepliedBtn');

    const activeClass = 'px-2.5 py-1 text-[11px] font-bold rounded-lg bg-primary text-white transition-colors cursor-pointer';
    const inactiveClass = 'px-2.5 py-1 text-[11px] font-semibold rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:text-white transition-colors cursor-pointer';

    if (allBtn) allBtn.className = filterMode === 'all' ? activeClass : inactiveClass;
    if (unreadBtn) unreadBtn.className = filterMode === 'unread' ? activeClass : inactiveClass;
    if (repliedBtn) repliedBtn.className = filterMode === 'replied' ? activeClass : inactiveClass;

    window.renderBotkolikConversations();
};

window.filterBotkolikConversations = function() {
    window.renderBotkolikConversations();
};

window.renderBotkolikConversations = function() {
    const listContainer = document.getElementById('botConversationsList');
    if (!listContainer) return;

    const searchTerm = (document.getElementById('botConvSearchInput')?.value || '').trim().toLowerCase();

    let filtered = botkolikConversations.filter(c => {
        if (botkolikFilterMode === 'unread' && c.unreadCount === 0) return false;
        if (botkolikFilterMode === 'replied' && (c.unreadCount > 0 || c.lastSenderId !== 'botkolik')) return false;

        if (searchTerm) {
            const matchesUser = (c.userName || '').toLowerCase().includes(searchTerm);
            const matchesMsg = (c.lastMessage || '').toLowerCase().includes(searchTerm);
            const matchesUid = (c.userId || '').toLowerCase().includes(searchTerm);
            return matchesUser || matchesMsg || matchesUid;
        }
        return true;
    });

    if (filtered.length === 0) {
        listContainer.innerHTML = `
            <div class="p-8 text-center text-slate-400 text-xs flex flex-col items-center gap-2 m-auto">
                <span class="material-symbols-outlined text-3xl opacity-30">inbox</span>
                <span>Filtreye uygun mesaj bulunamadı.</span>
            </div>
        `;
        return;
    }

    listContainer.innerHTML = filtered.map(c => {
        const isSelected = c.userId === botkolikActiveUserId;
        const timeStr = typeof formatTimeAgo === 'function' ? formatTimeAgo(c.lastDate) : c.lastDate.toLocaleDateString('tr-TR');
        const isUnread = c.unreadCount > 0;
        const isLastMe = c.lastSenderId === 'botkolik';

        return `
            <div onclick="window.selectBotkolikConversation('${c.userId}')" class="p-3.5 flex items-start gap-3 hover:bg-slate-50 dark:hover:bg-slate-800/50 cursor-pointer transition-colors ${isSelected ? 'bg-primary/10 border-l-4 border-primary' : ''}">
                ${renderUserAvatarHtml(c.userImageUrl, c.userName, 'w-10 h-10', 'text-sm')}
                <div class="flex-1 min-w-0 flex flex-col gap-0.5">
                    <div class="flex items-center justify-between">
                        <span class="font-bold text-slate-900 dark:text-white text-xs truncate ${isUnread ? 'text-primary' : ''}">${escapeHtml(c.userName)}</span>
                        <span class="text-[10px] text-slate-400 shrink-0">${timeStr}</span>
                    </div>
                    <p class="text-xs text-slate-500 dark:text-slate-400 truncate ${isUnread ? 'font-bold text-slate-800 dark:text-slate-200' : ''}">
                        ${isLastMe ? '<span class="text-primary font-semibold">Bot: </span>' : ''}${escapeHtml(c.lastMessage || 'Fırsat Eki')}
                    </p>
                    ${c.lastDealTitle ? `<span class="text-[10px] text-amber-500 font-semibold truncate">🏷️ ${escapeHtml(c.lastDealTitle)}</span>` : ''}
                </div>
                ${isUnread ? `
                    <span class="px-1.5 py-0.5 text-[10px] font-bold bg-primary text-white rounded-full shrink-0">
                        ${c.unreadCount}
                    </span>
                ` : ''}
            </div>
        `;
    }).join('');
};

window.selectBotkolikConversation = async function(userId) {
    botkolikActiveUserId = userId;
    let conv = botkolikConversations.find(c => c.userId === userId);
    botkolikActiveUser = conv || { userId: userId, userName: 'Kullanıcı', userImageUrl: '' };

    // Fetch fresh user doc if needed
    try {
        const uDoc = await db.collection('users').doc(userId).get();
        if (uDoc.exists) {
            const uData = uDoc.data();
            if (uData.username || uData.displayName) {
                botkolikActiveUser.userName = uData.username || uData.displayName;
            }
            const pImg = uData.profileImageUrl || uData.photoURL || uData.avatarUrl;
            if (pImg) {
                botkolikActiveUser.userImageUrl = pImg;
            }
        }
    } catch (_) {}

    // Update Header
    const nameEl = document.getElementById('botActiveUserName');
    const uidEl = document.getElementById('botActiveUserUid');
    const avatarEl = document.getElementById('botActiveUserAvatar');
    const profBtn = document.getElementById('botUserProfileBtn');
    const roleBadge = document.getElementById('botActiveUserRole');
    const templatesBar = document.getElementById('botQuickTemplatesBar');
    const composerArea = document.getElementById('botReplyComposerArea');

    if (nameEl) nameEl.innerText = botkolikActiveUser.userName || 'Kullanıcı';
    if (uidEl) uidEl.innerText = `UID: ${userId}`;
    if (profBtn) profBtn.classList.remove('hidden');
    if (roleBadge) roleBadge.classList.remove('hidden');
    if (templatesBar) templatesBar.classList.remove('hidden');
    if (composerArea) composerArea.classList.remove('hidden');

    if (avatarEl) {
        avatarEl.innerHTML = renderUserAvatarHtml(botkolikActiveUser.userImageUrl, botkolikActiveUser.userName, 'w-10 h-10', 'text-sm');
    }

    // Re-render conversation list items to show active border
    window.renderBotkolikConversations();

    // Start Live Messages Stream for this conversation
    startBotkolikChatStream(userId);
};

function startBotkolikChatStream(userId) {
    if (botkolikChatUnsubscribe) {
        botkolikChatUnsubscribe();
        botkolikChatUnsubscribe = null;
    }

    const messagesArea = document.getElementById('botChatMessagesArea');
    if (!messagesArea) return;

    messagesArea.innerHTML = `
        <div class="m-auto text-center text-slate-400 text-xs flex flex-col items-center gap-2 py-12">
            <span class="material-symbols-outlined text-3xl opacity-40 animate-spin text-primary">sync</span>
            <p>Sohbet geçmişi yükleniyor...</p>
        </div>
    `;

    // Listen to messages in real time
    botkolikChatUnsubscribe = db.collection('messages')
        .onSnapshot(async (snapshot) => {
            if (botkolikActiveUserId !== userId) return;

            const relevantDocs = [];
            const unreadDocIds = [];

            snapshot.forEach(doc => {
                const data = doc.data();
                if ((data.senderId === userId && data.receiverId === 'botkolik') ||
                    (data.senderId === 'botkolik' && data.receiverId === userId)) {
                    relevantDocs.push({
                        id: doc.id,
                        ...data
                    });
                    if (data.receiverId === 'botkolik' && !data.isRead) {
                        unreadDocIds.push(doc.id);
                    }
                }
            });

            // Mark unread messages as read in batch
            if (unreadDocIds.length > 0) {
                const batch = db.batch();
                unreadDocIds.forEach(id => {
                    batch.update(db.collection('messages').doc(id), { isRead: true, isReadByAdmin: true });
                });
                batch.commit().catch(e => console.warn('Mark read error:', e));

                // Update local model
                const currentConv = botkolikConversations.find(c => c.userId === userId);
                if (currentConv) {
                    currentConv.unreadCount = 0;
                    window.renderBotkolikConversations();
                    updateBotkolikUnreadBadge();
                }
            }

            // Sort chronological
            relevantDocs.sort((a, b) => {
                const dateA = a.createdAt ? (a.createdAt.toDate ? a.createdAt.toDate() : new Date(a.createdAt)) : new Date(0);
                const dateB = b.createdAt ? (b.createdAt.toDate ? b.createdAt.toDate() : new Date(b.createdAt)) : new Date(0);
                return dateA - dateB;
            });

            if (relevantDocs.length === 0) {
                messagesArea.innerHTML = `
                    <div class="m-auto text-center text-slate-400 text-xs flex flex-col items-center gap-2 py-12">
                        <span class="material-symbols-outlined text-4xl opacity-30 text-primary">chat_bubble_outline</span>
                        <p class="font-semibold text-slate-600 dark:text-slate-300">Bu kullanıcıyla henüz mesaj bulunmuyor.</p>
                        <p class="text-[11px] text-slate-400">Aşağıdaki alandan Botkolik adına bir mesaj göndererek sohbeti başlatabilirsiniz.</p>
                    </div>
                `;
                return;
            }

            messagesArea.innerHTML = relevantDocs.map(m => {
                const isBot = m.senderId === 'botkolik';
                const date = m.createdAt ? (m.createdAt.toDate ? m.createdAt.toDate() : new Date(m.createdAt)) : new Date();
                const timeStr = date.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' });

                let dealBadgeHtml = '';
                if (m.dealTitle) {
                    dealBadgeHtml = `
                        <div class="mb-2 p-2 bg-slate-900/30 rounded-lg border border-white/10 flex items-center gap-2 text-xs">
                            ${m.dealImageUrl ? `<img src="${m.dealImageUrl}" class="w-8 h-8 object-cover rounded bg-slate-800 shrink-0">` : ''}
                            <div class="flex flex-col min-w-0 flex-1">
                                <span class="font-bold truncate text-slate-100">${escapeHtml(m.dealTitle)}</span>
                                ${m.dealPrice ? `<span class="text-amber-400 font-semibold">${escapeHtml(m.dealPrice)} TL</span>` : ''}
                            </div>
                        </div>
                    `;
                }

                if (isBot) {
                    // Botkolik (Admin) Message - Right side Bubble
                    return `
                        <div class="flex items-start justify-end gap-2.5 max-w-[85%] self-end">
                            <div class="flex flex-col items-end min-w-0">
                                <div class="p-3.5 bg-primary text-white rounded-2xl rounded-tr-xs shadow-sm flex flex-col gap-1">
                                    <div class="flex items-center justify-between gap-2 pb-1 border-b border-white/15">
                                        <span class="text-[11px] font-bold flex items-center gap-1">
                                            <span class="material-symbols-outlined text-[14px]">smart_toy</span> Botkolik (Yönetim)
                                        </span>
                                    </div>
                                    ${dealBadgeHtml}
                                    <p class="text-sm font-medium leading-relaxed whitespace-pre-wrap">${escapeHtml(m.text || '')}</p>
                                </div>
                                <div class="flex items-center gap-1.5 mt-1 px-1 text-[10px] text-slate-400 font-medium">
                                    <span>${timeStr}</span>
                                    ${m.isRead ? '<span class="text-blue-400 font-bold" title="Kullanıcı Okudu">✓✓</span>' : '<span class="text-slate-400" title="İletildi">✓</span>'}
                                </div>
                            </div>
                            ${renderBotkolikAvatarHtml('w-8 h-8')}
                        </div>
                    `;
                } else {
                    // User Message - Left side Bubble
                    return `
                        <div class="flex items-start gap-2.5 max-w-[85%] self-start">
                            ${renderUserAvatarHtml(botkolikActiveUser.userImageUrl, botkolikActiveUser.userName, 'w-8 h-8', 'text-xs')}
                            <div class="flex flex-col items-start min-w-0">
                                <div class="p-3.5 bg-white dark:bg-surface-dark text-slate-900 dark:text-white border border-slate-200 dark:border-slate-800 rounded-2xl rounded-tl-xs shadow-sm flex flex-col gap-1">
                                    <div class="flex items-center justify-between gap-2 pb-1 border-b border-slate-100 dark:border-slate-800">
                                        <span class="text-[11px] font-bold text-primary truncate">${escapeHtml(botkolikActiveUser.userName)}</span>
                                    </div>
                                    ${dealBadgeHtml}
                                    <p class="text-sm font-medium leading-relaxed whitespace-pre-wrap text-slate-800 dark:text-slate-200">${escapeHtml(m.text || '')}</p>
                                </div>
                                <div class="flex items-center gap-1.5 mt-1 px-1 text-[10px] text-slate-400 font-medium">
                                    <span>${timeStr}</span>
                                </div>
                            </div>
                        </div>
                    `;
                }
            }).join('');

            setTimeout(() => {
                messagesArea.scrollTop = messagesArea.scrollHeight;
            }, 50);
        });
}

window.sendBotkolikReply = async function() {
    if (!botkolikActiveUserId) {
        showError('Lütfen önce bir kullanıcı seçin.');
        return;
    }

    const input = document.getElementById('botReplyTextInput');
    if (!input) return;

    const text = input.value.trim();
    if (!text) {
        showError('Lütfen bir yanıt mesajı yazın.');
        return;
    }

    const sendBtn = document.getElementById('botSendReplyBtn');
    if (sendBtn) {
        sendBtn.disabled = true;
        sendBtn.innerHTML = '<span class="material-symbols-outlined text-[18px] animate-spin">sync</span><span>...</span>';
    }

    try {
        await db.collection('messages').add({
            senderId: 'botkolik',
            senderName: 'Botkolik',
            senderImageUrl: 'assets/botkolik.webp',
            receiverId: botkolikActiveUserId,
            receiverName: botkolikActiveUser?.userName || 'Kullanıcı',
            receiverImageUrl: botkolikActiveUser?.userImageUrl || '',
            text: text,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            isRead: false,
            isReadByAdmin: true,
            dealId: null,
            dealTitle: null
        });

        input.value = '';
        input.focus();
        showSuccess('Botkolik yanıtı başarıyla iletildi!');
    } catch (e) {
        console.error('Botkolik reply error:', e);
        showError('Mesaj gönderilemedi: ' + e.message);
    } finally {
        if (sendBtn) {
            sendBtn.disabled = false;
            sendBtn.innerHTML = '<span class="material-symbols-outlined text-[18px]">send</span><span>Yanıtla</span>';
        }
    }
};

window.applyBotTemplate = function(templateKey) {
    const input = document.getElementById('botReplyTextInput');
    if (!input) return;

    const templates = {
        'feedback_thanks': 'Geri bildiriminiz ve öneriniz için teşekkürler! Ekibimizle birlikte incelemeye aldık. 🚀',
        'price_fixed': 'Bildirdiğiniz fiyat anomalisini inceledik ve sisteme yansıttık. Dikkatiniz ve desteğiniz için teşekkürler! ⚡',
        'roadmap_added': 'Harika bir fikir! Önerinizi FırsatKolik geliştirme yol haritamıza ekledik. İlginiz ve desteğiniz için teşekkürler! ✨',
        'store_issue': 'Mağaza bağlantısındaki sorunu inceliyoruz, en kısa sürede düzeltilecektir. Bilgilendirme için teşekkürler! 🛠️'
    };

    if (templates[templateKey]) {
        input.value = templates[templateKey];
        input.focus();
    }
};

window.handleBotReplyKeyDown = function(e) {
    if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        window.sendBotkolikReply();
    }
};

window.viewSelectedBotUserProf = function() {
    if (!botkolikActiveUserId) return;
    if (typeof window.showUserDetail === 'function') {
        window.showUserDetail(botkolikActiveUserId);
    } else if (typeof window.viewUserProfile === 'function') {
        window.viewUserProfile(botkolikActiveUserId);
    } else {
        alert('Kullanıcı UID: ' + botkolikActiveUserId);
    }
};

function updateMenuActiveState(activeView) {
    const menuItems = document.querySelectorAll('nav a');
    menuItems.forEach(item => {
        item.classList.remove('bg-primary/10', 'text-primary', 'border-primary/20');
        item.classList.add('text-slate-400');
        const icon = item.querySelector('.material-symbols-outlined');
        if (icon) {
            icon.classList.remove('icon-filled');
        }
    });

    if (activeView === 'dashboard') {
        const dashboardMenuItem = document.getElementById('dashboardMenuBtn');
        if (dashboardMenuItem) {
            dashboardMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            dashboardMenuItem.classList.remove('text-slate-400');
            const icon = dashboardMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'deals') {
        const dealsMenuItem = document.getElementById('dealsMenuBtn');
        if (dealsMenuItem) {
            dealsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            dealsMenuItem.classList.remove('text-slate-400');
            const icon = dealsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'coupons') {
        const couponsMenuItem = document.getElementById('couponsMenuBtn');
        if (couponsMenuItem) {
            couponsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            couponsMenuItem.classList.remove('text-slate-400');
            const icon = couponsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'catalogs') {
        const catalogsMenuItem = document.getElementById('catalogsMenuBtn');
        if (catalogsMenuItem) {
            catalogsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            catalogsMenuItem.classList.remove('text-slate-400');
            const icon = catalogsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'users') {
        const usersMenuItem = document.getElementById('usersMenuBtn');
        if (usersMenuItem) {
            usersMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            usersMenuItem.classList.remove('text-slate-400');
            const icon = usersMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'messages') {
        const messagesMenuItem = document.getElementById('messagesMenuBtn');
        if (messagesMenuItem) {
            messagesMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            messagesMenuItem.classList.remove('text-slate-400');
            const icon = messagesMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'reports') {
        const reportsMenuItem = document.getElementById('reportsMenuBtn');
        if (reportsMenuItem) {
            reportsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            reportsMenuItem.classList.remove('text-slate-400');
            const icon = reportsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'settings') {
        const settingsMenuItem = document.getElementById('settingsMenuBtn');
        if (settingsMenuItem) {
            settingsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            settingsMenuItem.classList.remove('text-slate-400');
            const icon = settingsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'notifications') {
        const notificationsMenuItem = document.getElementById('notificationsMenuBtn');
        if (notificationsMenuItem) {
            notificationsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            notificationsMenuItem.classList.remove('text-slate-400');
            const icon = notificationsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'logs') {
        const logsMenuItem = document.getElementById('logsMenuBtn');
        if (logsMenuItem) {
            logsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            logsMenuItem.classList.remove('text-slate-400');
            const icon = logsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'telegramBot') {
        const telegramBotMenuItem = document.getElementById('telegramBotMenuBtn');
        if (telegramBotMenuItem) {
            telegramBotMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            telegramBotMenuItem.classList.remove('text-slate-400');
            const icon = telegramBotMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'observability') {
        const obsMenuItem = document.getElementById('observabilityMenuBtn');
        if (obsMenuItem) {
            obsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            obsMenuItem.classList.remove('text-slate-400');
            const icon = obsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    }
}

// ============================================================================
// 🚨 OTOMATİK MODERASYON ALARMLARI (adminMessages) - RAPORLAR & DENETİM
// ============================================================================

let autoModAlarms = [];
let autoModUnsubscribe = null;
let autoModFilter = 'all';

window.loadAutoModAlarms = function() {
    console.log('🚨 Loading auto moderation alarms (adminMessages)...');
    const tableBody = document.getElementById('autoModTableBody');
    if (!tableBody) return;

    if (autoModUnsubscribe) {
        autoModUnsubscribe();
    }

    tableBody.innerHTML = `
        <tr>
            <td colspan="6" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
                <div class="flex flex-col items-center gap-2">
                    <span class="material-symbols-outlined text-4xl animate-spin">sync</span>
                    <p>Alarmlar yükleniyor...</p>
                </div>
            </td>
        </tr>
    `;

    autoModUnsubscribe = db.collection('adminMessages')
        .orderBy('createdAt', 'desc')
        .limit(150)
        .onSnapshot((snapshot) => {
            autoModAlarms = [];
            let unreadCount = 0;
            snapshot.forEach((doc) => {
                const data = doc.data();
                const isRead = data.isRead === true;
                if (!isRead) unreadCount++;
                autoModAlarms.push({
                    id: doc.id,
                    type: data.type || 'unknown',
                    userId: data.userId || 'unknown',
                    userName: data.userName || 'Bilinmeyen Kullanıcı',
                    content: data.content || '',
                    dealId: data.dealId || null,
                    commentId: data.commentId || null,
                    reason: data.reason || 'Uygunsuz içerik tespit edildi',
                    isRead: isRead,
                    createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt || Date.now()),
                });
            });

            // Rozet güncelle
            const badge = document.getElementById('autoModUnreadBadge');
            if (badge) {
                if (unreadCount > 0) {
                    badge.textContent = unreadCount > 99 ? '99+' : unreadCount;
                    badge.classList.remove('hidden');
                } else {
                    badge.classList.add('hidden');
                }
            }

            const totalCountEl = document.getElementById('autoModTotalCount');
            if (totalCountEl) {
                totalCountEl.textContent = `Toplam ${autoModAlarms.length} alarm listeleniyor (${unreadCount} yeni/incelenmemiş)`;
            }

            window.renderAutoModAlarms();
        }, (error) => {
            console.error('❌ Error loading auto mod alarms:', error);
            tableBody.innerHTML = `
                <tr>
                    <td colspan="6" class="px-6 py-12 text-center text-red-500">
                        <p>Alarmlar yüklenirken hata oluştu: ${escapeHtml(error.message)}</p>
                    </td>
                </tr>
            `;
        });
};

window.renderAutoModAlarms = function() {
    const tableBody = document.getElementById('autoModTableBody');
    if (!tableBody) return;

    const searchTerm = (document.getElementById('autoModSearchInput')?.value || '').trim().toLowerCase();

    let filtered = autoModAlarms.filter(m => {
        if (autoModFilter === 'unread' && m.isRead) return false;
        if (autoModFilter === 'deals' && m.type !== 'deal') return false;
        if (autoModFilter === 'comments' && m.type !== 'comment') return false;

        if (searchTerm) {
            const userMatches = (m.userName || '').toLowerCase().includes(searchTerm) || (m.userId || '').toLowerCase().includes(searchTerm);
            const contentMatches = (m.content || '').toLowerCase().includes(searchTerm);
            const reasonMatches = (m.reason || '').toLowerCase().includes(searchTerm);
            return userMatches || contentMatches || reasonMatches;
        }
        return true;
    });

    if (filtered.length === 0) {
        tableBody.innerHTML = `
            <tr>
                <td colspan="6" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
                    <div class="flex flex-col items-center gap-2">
                        <span class="material-symbols-outlined text-4xl opacity-50">verified_user</span>
                        <p>Kriterlere uygun moderasyon alarmı bulunamadı.</p>
                    </div>
                </td>
            </tr>
        `;
        return;
    }

    tableBody.innerHTML = filtered.map(m => {
        const messageDate = new Date(m.createdAt);
        const formattedDate = messageDate.toLocaleDateString('tr-TR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        const isDeal = m.type === 'deal';
        const typeLabel = isDeal ? 'Fırsat' : (m.type === 'comment' ? 'Yorum' : m.type);
        const typeColor = isDeal ? 'text-amber-500 bg-amber-500/10' : 'text-purple-500 bg-purple-500/10';
        const typeIcon = isDeal ? 'local_offer' : 'comment';

        const statusBadge = m.isRead
            ? '<span class="px-2.5 py-1 bg-emerald-500/10 text-emerald-500 rounded-full text-xs font-semibold">İncelendi</span>'
            : '<span class="px-2.5 py-1 bg-red-500/10 text-red-500 rounded-full text-xs font-semibold animate-pulse">Yeni</span>';

        return `
            <tr class="hover:bg-slate-50 dark:hover:bg-slate-900/50 transition-colors ${!m.isRead ? 'bg-red-500/5 dark:bg-red-500/10' : ''}">
                <td class="px-6 py-4 whitespace-nowrap text-xs text-slate-500 dark:text-slate-400">
                    ${escapeHtml(formattedDate)}
                </td>
                <td class="px-6 py-4">
                    <div class="flex items-center gap-2.5">
                        <div class="w-8 h-8 rounded-full bg-slate-100 dark:bg-slate-800 flex items-center justify-center shrink-0">
                            <span class="material-symbols-outlined text-slate-400 text-[18px]">person</span>
                        </div>
                        <div class="flex flex-col min-w-0">
                            <button onclick="window.showUserDetail('${escapeHtml(m.userId)}')" 
                                    class="text-sm font-bold text-slate-900 dark:text-white hover:text-primary transition-colors cursor-pointer text-left truncate">
                                ${escapeHtml(m.userName)}
                            </button>
                            <span class="text-[10px] font-mono text-slate-400 truncate max-w-[120px]">${escapeHtml(m.userId)}</span>
                        </div>
                    </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg text-xs font-bold ${typeColor}">
                        <span class="material-symbols-outlined text-[14px]">${typeIcon}</span>
                        ${typeLabel}
                    </span>
                </td>
                <td class="px-6 py-4 max-w-md">
                    <div class="flex flex-col gap-1">
                        <span class="inline-block self-start text-[11px] font-bold text-red-600 dark:text-red-400 bg-red-500/10 px-2 py-0.5 rounded">
                            ⚠️ ${escapeHtml(m.reason)}
                        </span>
                        <p class="text-sm text-slate-800 dark:text-slate-200 line-clamp-2" title="${escapeHtml(m.content)}">
                            "${escapeHtml(m.content)}"
                        </p>
                    </div>
                </td>
                <td class="px-6 py-4 whitespace-nowrap">
                    ${statusBadge}
                </td>
                <td class="px-6 py-4 whitespace-nowrap text-right">
                    <div class="flex items-center justify-end gap-1.5">
                        ${m.dealId ? `
                            <button onclick="window.editDeal('${escapeHtml(m.dealId)}')" class="p-1.5 text-slate-500 hover:text-primary transition-colors rounded-lg hover:bg-slate-100 dark:hover:bg-slate-800 cursor-pointer" title="Fırsatı Gör / Düzenle">
                                <span class="material-symbols-outlined text-[18px]">visibility</span>
                            </button>
                        ` : ''}
                        ${!m.isRead ? `
                            <button onclick="window.markAutoModAlarmAsRead('${escapeHtml(m.id)}')" class="p-1.5 text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 transition-colors rounded-lg hover:bg-emerald-50 dark:hover:bg-emerald-950/30 cursor-pointer" title="İncelendi Olarak İşaretle">
                                <span class="material-symbols-outlined text-[18px]">check_circle</span>
                            </button>
                        ` : ''}
                        <button onclick="window.openAdminMessageModal('${escapeHtml(m.userId)}', '${escapeHtml(m.userName)}')" class="p-1.5 text-blue-500 hover:text-blue-700 transition-colors rounded-lg hover:bg-blue-50 dark:hover:bg-blue-950/30 cursor-pointer" title="Kullanıcıya Admin Uyarısı / Mesajı Gönder">
                            <span class="material-symbols-outlined text-[18px]">mail</span>
                        </button>
                        <button onclick="window.showUserDetail('${escapeHtml(m.userId)}')" class="p-1.5 text-purple-500 hover:text-purple-700 transition-colors rounded-lg hover:bg-purple-50 dark:hover:bg-purple-950/30 cursor-pointer" title="Kullanıcıyı Yönet / Engelle">
                            <span class="material-symbols-outlined text-[18px]">shield_person</span>
                        </button>
                        <button onclick="window.deleteAutoModAlarm('${escapeHtml(m.id)}')" class="p-1.5 text-red-500 hover:text-red-700 transition-colors rounded-lg hover:bg-red-50 dark:hover:bg-red-950/30 cursor-pointer" title="Alarmı Sil">
                            <span class="material-symbols-outlined text-[18px]">delete</span>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
};

window.filterAutoModAlarms = function() {
    window.renderAutoModAlarms();
};

window.setAutoModFilter = function(filterMode) {
    autoModFilter = filterMode;
    const allBtn = document.getElementById('autoModFilterAllBtn');
    const unreadBtn = document.getElementById('autoModFilterUnreadBtn');
    const dealsBtn = document.getElementById('autoModFilterDealsBtn');
    const commentsBtn = document.getElementById('autoModFilterCommentsBtn');

    const defaultClass = 'px-3 py-1.5 text-xs font-semibold rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:text-white transition-colors cursor-pointer';
    const activeClass = 'px-3 py-1.5 text-xs font-bold rounded-lg bg-primary text-white transition-colors cursor-pointer';

    if (allBtn) allBtn.className = filterMode === 'all' ? activeClass : defaultClass;
    if (unreadBtn) unreadBtn.className = filterMode === 'unread' ? activeClass : defaultClass;
    if (dealsBtn) dealsBtn.className = filterMode === 'deals' ? activeClass : defaultClass;
    if (commentsBtn) commentsBtn.className = filterMode === 'comments' ? activeClass : defaultClass;

    window.renderAutoModAlarms();
};

window.markAutoModAlarmAsRead = async function(alarmId) {
    try {
        await db.collection('adminMessages').doc(alarmId).update({
            isRead: true,
        });
        showSuccess('Alarm incelendi olarak işaretlendi.');
    } catch (error) {
        console.error('❌ Error marking alarm as read:', error);
        showError('Hata: ' + error.message);
    }
};

window.deleteAutoModAlarm = async function(alarmId) {
    if (!confirm('Bu moderasyon alarmını silmek istediğinize emin misiniz?')) {
        return;
    }

    try {
        await db.collection('adminMessages').doc(alarmId).delete();
        showSuccess('Alarm başarıyla silindi.');
    } catch (error) {
        console.error('❌ Error deleting alarm:', error);
        showError('Hata: ' + error.message);
    }
};

window.deleteAllAutoModAlarms = async function() {
    if (!confirm('TÜM otomatik moderasyon alarmlarını kalıcı olarak temizlemek istediğinize emin misiniz? Bu işlem geri alınamaz!')) {
        return;
    }

    try {
        const snapshot = await db.collection('adminMessages').get();

        if (snapshot.empty) {
            showError('Silinecek alarm yok.');
            return;
        }

        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });

        await batch.commit();
        showSuccess(`${snapshot.docs.length} adet alarm başarıyla temizlendi.`);
    } catch (error) {
        console.error('❌ Error deleting all auto mod alarms:', error);
        showError('Temizleme hatası: ' + error.message);
    }
};

// Show deal detail (for messages view)
window.showDealDetail = async function (dealId) {
    try {
        // Önce deals array'inde ara
        let deal = deals.find(d => d.id === dealId);

        // Bulunamazsa Firestore'dan çek
        if (!deal) {
            const dealDoc = await db.collection('deals').doc(dealId).get();
            if (dealDoc.exists) {
                const data = dealDoc.data();
                deal = {
                    id: dealDoc.id,
                    ...data,
                    createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt || Date.now()),
                };
            }
        }

        if (deal) {
            // showDealModal zaten previousView'ı kaydediyor, showDealsView() çağırmaya gerek yok
            await showDealModal(deal);
        } else {
            showError('Fırsat bulunamadı. Fırsat silinmiş olabilir.');
        }
    } catch (error) {
        console.error('❌ Error loading deal:', error);
        showError('Fırsat yüklenirken hata oluştu: ' + error.message);
    }
}

// Official Badges Catalog
const BADGE_CATALOG = {
    // 🎯 Fırsat Avcılığı
    'first_spark': { id: 'first_spark', name: 'İlk Kıvılcım', tier: 'Bronz', category: 'Fırsat Avcılığı', icon: 'local_fire_department', color: '#CD7F32', desc: '1. fırsatını paylaşan avcı' },
    'hunter_apprentice': { id: 'hunter_apprentice', name: 'Fırsat Çırağı', tier: 'Gümüş', category: 'Fırsat Avcılığı', icon: 'explore', color: '#94A3B8', desc: '5 fırsat paylaştı' },
    'contributor': { id: 'contributor', name: 'Katkıda Bulunan', tier: 'Gümüş', category: 'Fırsat Avcılığı', icon: 'share', color: '#94A3B8', desc: '10 fırsat paylaştı' },
    'master_hunter': { id: 'master_hunter', name: 'Usta Avcı', tier: 'Altın', category: 'Fırsat Avcılığı', icon: 'military_tech', color: '#F59E0B', desc: '25 fırsat paylaştı' },
    'legendary_hunter': { id: 'legendary_hunter', name: 'Efsanevi Avcı', tier: 'Elmas', category: 'Fırsat Avcılığı', icon: 'diamond', color: '#06B6D4', desc: '100 fırsat paylaştı' },

    // 🔥 Sıcaklık & Oylar
    'active_voter': { id: 'active_voter', name: 'Aktif Seçmen', tier: 'Bronz', category: 'Sıcaklık & Oylar', icon: 'how_to_vote', color: '#CD7F32', desc: '30+ puan oylama' },
    'flame_master': { id: 'flame_master', name: 'Alev Ustası', tier: 'Altın', category: 'Sıcaklık & Oylar', icon: 'whatshot', color: '#F59E0B', desc: '100+ puan oylama' },
    'volcanic_record': { id: 'volcanic_record', name: 'Volkanik Rekortmen', tier: 'Elmas', category: 'Sıcaklık & Oylar', icon: 'volcano', color: '#06B6D4', desc: '300+ puan oylama' },

    // 💬 Topluluk & Yorum
    'voice_of_community': { id: 'voice_of_community', name: 'Söz Sahibi', tier: 'Bronz', category: 'Topluluk & Yorum', icon: 'forum', color: '#CD7F32', desc: '20+ puan topluluk' },
    'helpful': { id: 'helpful', name: 'Yardımsever Avcı', tier: 'Gümüş', category: 'Topluluk & Yorum', icon: 'thumb_up', color: '#94A3B8', desc: '25+ beğeni aldı' },
    'top_reviewer': { id: 'top_reviewer', name: 'Fikir Önderi', tier: 'Altın', category: 'Topluluk & Yorum', icon: 'rate_review', color: '#F59E0B', desc: '100+ beğeni aldı' },

    // ⭐ Sadakat & Özel
    'bronze': { id: 'bronze', name: 'Bronz Avcı', tier: 'Bronz', category: 'Sadakat & Özel', icon: 'shield', color: '#CD7F32', desc: '10+ puan' },
    'silver': { id: 'silver', name: 'Gümüş Avcı', tier: 'Gümüş', category: 'Sadakat & Özel', icon: 'shield', color: '#94A3B8', desc: '60+ puan' },
    'gold': { id: 'gold', name: 'Altın Avcı', tier: 'Altın', category: 'Sadakat & Özel', icon: 'workspace_premium', color: '#F59E0B', desc: '200+ puan' },
    'verified': { id: 'verified', name: 'Doğrulanmış Avcı', tier: 'Özel', category: 'Sadakat & Özel', icon: 'verified', color: '#00BCD4', desc: 'Onaylı güvenilir hesap' },
    'early_bird': { id: 'early_bird', name: 'Öncü Kurucu Üye', tier: 'Özel', category: 'Sadakat & Özel', icon: 'auto_awesome', color: '#8B5CF6', desc: 'İlk dönem kurucu üye' },
    'premium': { id: 'premium', name: 'Premium Üye', tier: 'Özel', category: 'Sadakat & Özel', icon: 'stars', color: '#8B5CF6', desc: 'Özel statülü üye' },
};

function getBadgeMeta(badgeId) {
    if (BADGE_CATALOG[badgeId]) {
        return BADGE_CATALOG[badgeId];
    }
    return {
        id: badgeId,
        name: badgeId,
        tier: 'Özel',
        category: 'Diğer',
        icon: 'military_tech',
        color: '#64748B',
        desc: 'Özel Rozet'
    };
}

// Load users from Firestore
async function loadUsers() {
    try {
        console.log('👥 Loading users...');
        const usersTableBody = document.getElementById('usersTableBody');

        if (usersTableBody) {
            usersTableBody.innerHTML = `
                <tr>
                    <td colspan="8" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
                        <div class="flex flex-col items-center gap-2">
                            <span class="material-symbols-outlined text-4xl opacity-50 animate-spin">hourglass_empty</span>
                            <p>Kullanıcılar yükleniyor...</p>
                        </div>
                    </td>
                </tr>
            `;
        }

        // Set up real-time listener for users
        if (usersUnsubscribe) {
            usersUnsubscribe();
        }

        // Prefetch blocked users map
        let blockedSet = new Set();
        try {
            const blockedSnap = await db.collection('blockedUsers').get();
            blockedSet = new Set(blockedSnap.docs.map(d => d.id));
        } catch (e) {
            console.warn('⚠️ Could not prefetch blocked users:', e);
        }

        usersUnsubscribe = db.collection('users').onSnapshot((snapshot) => {
            users = [];
            let totalDeals = 0;
            let totalPoints = 0;

            snapshot.forEach((doc) => {
                const userData = doc.data();
                const isBlocked = blockedSet.has(doc.id) || (userData.uid && blockedSet.has(userData.uid));
                const user = {
                    id: doc.id,
                    uid: userData.uid || doc.id,
                    username: userData.username || 'Bilinmeyen',
                    nickname: userData.nickname || null,
                    profileImageUrl: cleanProfileImageUrl(userData.profileImageUrl),
                    points: userData.points || 0,
                    dealCount: userData.dealCount || 0,
                    totalLikes: userData.totalLikes || 0,
                    followedCategories: userData.followedCategories || [],
                    watchKeywords: userData.watchKeywords || [],
                    following: userData.following || [],
                    followersWithNotifications: userData.followersWithNotifications || [],
                    badges: userData.badges || [],
                    pinnedBadge: userData.pinnedBadge || null,
                    email: userData.email || null,
                    isAdmin: userData.isAdmin === true || userData.isadmin === true || userData.isAdmin === 'true' || userData.isadmin === 'true',
                    isBlocked: isBlocked,
                    createdAt: userData.createdAt?.toDate ? userData.createdAt.toDate() : (userData.createdAt ? new Date(userData.createdAt) : null)
                };

                users.push(user);
                totalDeals += user.dealCount;
                totalPoints += user.points;
            });

            // Sort by points (descending)
            users.sort((a, b) => b.points - a.points);

            console.log(`✅ Loaded ${users.length} users`);
            renderUsers();
            updateUsersStats(users.length, totalDeals, totalPoints);
            if (currentView === 'dashboard') {
                loadDashboardData();
            }
        }, (error) => {
            console.error('❌ Error loading users:', error);
            if (usersTableBody) {
                usersTableBody.innerHTML = `
                    <tr>
                        <td colspan="8" class="px-6 py-12 text-center text-red-500">
                            <p>Kullanıcılar yüklenirken hata oluştu: ${error.message}</p>
                        </td>
                    </tr>
                `;
            }
        });

    } catch (error) {
        console.error('❌ Error loading users:', error);
        showError('Kullanıcılar yüklenirken hata oluştu: ' + error.message);
    }
}

function renderUsers() {
    const usersTableBody = document.getElementById('usersTableBody');
    if (!usersTableBody) return;

    // Arama sorgusuna göre filtrele (kullanıcı adı, e-posta, ID ve sahip olunan rozetler)
    let filteredUsers = users;
    if (usersSearchQuery && usersSearchQuery.trim() !== '') {
        filteredUsers = users.filter(user => {
            const searchLower = usersSearchQuery.toLowerCase();
            const username = (user.username || '').toLowerCase();
            const nickname = (user.nickname || '').toLowerCase();
            const email = (user.email || '').toLowerCase();
            const uid = (user.uid || user.id || '').toLowerCase();
            const badgesStr = (user.badges || []).map(b => `${b} ${getBadgeMeta(b).name}`).join(' ').toLowerCase();

            return username.includes(searchLower) ||
                nickname.includes(searchLower) ||
                email.includes(searchLower) ||
                uid.includes(searchLower) ||
                badgesStr.includes(searchLower);
        });
    }

    if (filteredUsers.length === 0) {
        usersTableBody.innerHTML = `
            <tr>
                <td colspan="8" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
                    <div class="flex flex-col items-center gap-2">
                        <span class="material-symbols-outlined text-4xl opacity-50">${usersSearchQuery ? 'search_off' : 'group_off'}</span>
                        <p>${usersSearchQuery ? 'Arama sonucu bulunamadı' : 'Henüz kullanıcı yok'}</p>
                        ${usersSearchQuery ? `<p class="text-sm text-slate-400">"${escapeHtml(usersSearchQuery)}" için sonuç yok</p>` : ''}
                    </div>
                </td>
            </tr>
        `;
        return;
    }

    usersTableBody.innerHTML = filteredUsers.map(user => {
        const displayName = user.nickname || user.username;
        const profileImage = user.profileImageUrl || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(displayName) + '&background=135bec&color=fff&size=128';
        const followedCategoriesCount = user.followedCategories ? user.followedCategories.length : 0;
        const followingCount = user.following ? user.following.length : 0;
        const badgesCount = (user.badges || []).length;
        const pinnedMeta = user.pinnedBadge ? getBadgeMeta(user.pinnedBadge) : null;

        let badgesHtml = '<span class="text-slate-400 dark:text-slate-500 text-xs">Rozet yok</span>';
        if (badgesCount > 0) {
            badgesHtml = `
                <div class="flex items-center gap-1.5 flex-wrap">
                    <span class="px-2 py-0.5 rounded-full text-xs font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20">
                        ${badgesCount} Rozet
                    </span>
                    ${pinnedMeta ? `
                        <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[11px] font-semibold text-white" style="background-color: ${pinnedMeta.color};" title="Vitrin Rozeti: ${escapeHtml(pinnedMeta.name)}">
                            <span class="material-symbols-outlined text-[13px]">${pinnedMeta.icon}</span>
                            ${escapeHtml(pinnedMeta.name)}
                        </span>
                    ` : ''}
                </div>
            `;
        }

        return `
            <tr class="hover:bg-slate-50 dark:hover:bg-slate-900/50 transition-colors">
                <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                        <img src="${profileImage}" alt="${displayName}" class="w-10 h-10 rounded-full object-cover bg-slate-200 dark:bg-slate-700" onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=135bec&color=fff&size=128'">
                        <div class="flex flex-col min-w-0">
                            <div class="flex items-center gap-1.5 flex-wrap">
                                <p class="font-semibold text-slate-900 dark:text-white truncate">${escapeHtml(displayName)}</p>
                                ${user.isAdmin ? '<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-blue-500/15 text-blue-600 dark:text-blue-400 border border-blue-500/30">👮 Admin</span>' : ''}
                                ${user.isBlocked ? '<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-rose-500/15 text-rose-600 dark:text-rose-400 border border-rose-500/30">🚫 Engelli</span>' : ''}
                            </div>
                            ${user.email ? `<p class="text-xs text-slate-500 dark:text-slate-400 truncate">${escapeHtml(user.email)}</p>` : ''}
                        </div>
                    </div>
                </td>
                <td class="px-6 py-4">
                    <div class="flex items-center gap-1">
                        <span class="material-symbols-outlined text-amber-500 text-lg">stars</span>
                        <span class="font-semibold text-slate-900 dark:text-white">${user.points || 0}</span>
                    </div>
                </td>
                <td class="px-6 py-4">
                    <span class="text-slate-700 dark:text-slate-300">${user.dealCount || 0}</span>
                </td>
                <td class="px-6 py-4">
                    <span class="text-slate-700 dark:text-slate-300">${user.totalLikes || 0}</span>
                </td>
                <td class="px-6 py-4">
                    ${badgesHtml}
                </td>
                <td class="px-6 py-4">
                    <span class="text-slate-700 dark:text-slate-300">${followingCount}</span>
                </td>
                <td class="px-6 py-4">
                    <span class="text-slate-700 dark:text-slate-300">${followedCategoriesCount}</span>
                </td>
                <td class="px-6 py-4 text-right">
                    <button onclick="showUserDetail('${user.id}')" class="text-primary hover:text-primary/80 text-sm font-medium transition-colors cursor-pointer">
                        Detay
                    </button>
                </td>
            </tr>
        `;
    }).join('');
}

function updateUsersStats(totalUsers, totalDeals, totalPoints) {
    const totalUsersCount = document.getElementById('totalUsersCount');
    const totalDealsCount = document.getElementById('totalDealsCount');
    const totalPointsCount = document.getElementById('totalPointsCount');

    if (totalUsersCount) totalUsersCount.textContent = totalUsers;
    if (totalDealsCount) totalDealsCount.textContent = totalDeals;
    if (totalPointsCount) totalPointsCount.textContent = totalPoints.toLocaleString('tr-TR');
}

// Handle image upload
async function handleImageUpload(event) {
    const file = event.target.files[0];
    if (!file) return;

    // Dosya tipi kontrolü
    if (!file.type.startsWith('image/')) {
        showError('Lütfen bir görsel dosyası seçin!');
        return;
    }

    // Dosya boyutu kontrolü (max 5MB)
    if (file.size > 5 * 1024 * 1024) {
        showError('Görsel boyutu 5MB\'dan küçük olmalıdır!');
        return;
    }

    // Yeni fırsat (id yoksa) için: görsel yükleme öncesinde geçici Firestore ID oluştur
    if (!currentDeal) {
        showError('Fırsat bulunamadı!');
        return;
    }
    if (!currentDeal.id || currentDeal.id === '') {
        // Yeni fırsat için geçici bir Firestore doküman referansı ve ID al
        const newDocRef = db.collection('deals').doc();
        currentDeal.id = newDocRef.id;
        currentDeal._isPreGeneratedId = true;
        console.log('🆔 Yeni fırsat için geçici ID oluşturuldu:', currentDeal.id);
    }

    try {
        // Loading göster
        const uploadLabel = event.target.closest('label');
        if (uploadLabel) {
            const originalHTML = uploadLabel.innerHTML;
            uploadLabel.innerHTML = '<span class="material-symbols-outlined text-primary animate-spin">hourglass_empty</span><span class="text-xs font-medium text-primary mt-1">Yükleniyor...</span>';
            uploadLabel.style.pointerEvents = 'none';
        }

        console.log('📤 Görsel yükleniyor...', file.name);

        // Firebase Storage'a yükle
        const fileName = `deals/${currentDeal.id}/${Date.now()}_${file.name}`;
        const storageRef = storage.ref(fileName);
        const uploadTask = storageRef.put(file);

        // Upload progress
        uploadTask.on('state_changed',
            (snapshot) => {
                const progress = (snapshot.bytesTransferred / snapshot.totalBytes) * 100;
                console.log('📤 Yükleme ilerlemesi:', Math.round(progress) + '%');
            },
            (error) => {
                console.error('❌ Yükleme hatası:', error);
                showError('Görsel yüklenirken hata oluştu: ' + error.message);
                if (uploadLabel) {
                    uploadLabel.innerHTML = '<span class="material-symbols-outlined text-slate-400 dark:text-slate-500 group-hover:text-primary transition-colors">add_photo_alternate</span><span class="text-xs font-medium text-slate-500 dark:text-slate-400 mt-1">Yükle</span>';
                    uploadLabel.style.pointerEvents = 'auto';
                }
            },
            async () => {
                try {
                    // Upload tamamlandı, URL'yi al
                    const downloadURL = await uploadTask.snapshot.ref.getDownloadURL();
                    console.log('✅ Görsel yüklendi:', downloadURL);

                    // Mevcut görselleri al
                    let imageUrls = [];

                    // Önce imageUrls array'ini kontrol et
                    if (currentDeal.imageUrls && Array.isArray(currentDeal.imageUrls) && currentDeal.imageUrls.length > 0) {
                        imageUrls = [...currentDeal.imageUrls]; // Kopyala
                    }
                    // Eğer imageUrls yoksa veya boşsa, imageUrl'den al
                    else if (currentDeal.imageUrl && typeof currentDeal.imageUrl === 'string' && currentDeal.imageUrl.trim() !== '') {
                        let existingImageUrl = currentDeal.imageUrl;
                        // Blob veya data URL'leri filtrele
                        if (!existingImageUrl.startsWith('blob:') && !existingImageUrl.startsWith('data:')) {
                            if (!existingImageUrl.startsWith('http://') && !existingImageUrl.startsWith('https://')) {
                                existingImageUrl = 'https://' + existingImageUrl;
                            }
                            imageUrls = [existingImageUrl];
                        }
                    }

                    console.log('📸 Mevcut görseller:', imageUrls);

                    // Yeni görseli başa ekle (ana görsel olacak)
                    // Eski ana görsel otomatik olarak ikinci sıraya geçecek
                    imageUrls.unshift(downloadURL);

                    // Maksimum 5 görsel tut
                    if (imageUrls.length > 5) {
                        imageUrls = imageUrls.slice(0, 5);
                    }

                    console.log('📸 Güncellenmiş görseller:', imageUrls);

                    // currentDeal'i güncelle
                    currentDeal.imageUrls = imageUrls;
                    currentDeal.imageUrl = imageUrls[0];

                    // UI'ı güncelle
                    updateModalImages(imageUrls);

                    showSuccess('Görsel başarıyla yüklendi!');

                    // Input'u temizle
                    event.target.value = '';

                    if (uploadLabel) {
                        uploadLabel.innerHTML = '<span class="material-symbols-outlined text-slate-400 dark:text-slate-500 group-hover:text-primary transition-colors">add_photo_alternate</span><span class="text-xs font-medium text-slate-500 dark:text-slate-400 mt-1">Yükle</span>';
                        uploadLabel.style.pointerEvents = 'auto';
                    }
                } catch (error) {
                    console.error('❌ URL alma hatası:', error);
                    showError('Görsel URL\'si alınamadı: ' + error.message);
                    if (uploadLabel) {
                        uploadLabel.innerHTML = '<span class="material-symbols-outlined text-slate-400 dark:text-slate-500 group-hover:text-primary transition-colors">add_photo_alternate</span><span class="text-xs font-medium text-slate-500 dark:text-slate-400 mt-1">Yükle</span>';
                        uploadLabel.style.pointerEvents = 'auto';
                    }
                }
            }
        );
    } catch (error) {
        console.error('❌ Görsel yükleme hatası:', error);
        showError('Görsel yüklenirken hata oluştu: ' + error.message);
    }
}

// Update modal images UI
function updateModalImages(imageUrls) {
    console.log('🖼️ Updating modal images UI with:', imageUrls);

    if (!imageUrls || imageUrls.length === 0) {
        console.warn('⚠️ No images to display');
        return;
    }

    // Ana görseli güncelle (tıklanabilir - ikinci görselle değiştirilebilir)
    const mainImageContainer = document.querySelector('#modalBody .sm\\:col-span-2');
    if (mainImageContainer && imageUrls[0]) {
        console.log('🖼️ Updating main image:', imageUrls[0]);
        const swapButtonHtml = imageUrls.length > 1
            ? `<div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
                <button onclick="swapMainImage()" class="p-2 bg-white/20 backdrop-blur-md rounded-full text-white hover:bg-white/40 transition-colors" type="button" title="Görselleri Değiştir">
                    <span class="material-symbols-outlined text-[20px]">swap_horiz</span>
                </button>
            </div>`
            : '';
        const mainImageHtml = `<img alt="${escapeHtml(currentDeal.title || '')}" class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500 ${imageUrls.length > 1 ? 'cursor-pointer' : ''}" src="${escapeHtml(imageUrls[0])}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"><div style="display:none; width:100%; height:100%; align-items:center; justify-content:center; background:#f5f5f5; color:#999; font-size:48px;">📷</div>`;
        mainImageContainer.innerHTML = mainImageHtml + swapButtonHtml;

        // Ana görsele tıklama ile değiştirme
        const mainImg = mainImageContainer.querySelector('img');
        if (mainImg && imageUrls.length > 1) {
            mainImg.style.cursor = 'pointer';
            // Önceki listener'ı temizle
            const newMainImg = mainImg.cloneNode(true);
            mainImg.parentNode.replaceChild(newMainImg, mainImg);
            newMainImg.addEventListener('click', window.swapMainImage);
        }
    }

    // İkinci görseli güncelle (tıklanabilir - ana görselle değiştirilebilir)
    const secondImageContainer = document.getElementById('secondImageContainer');
    if (secondImageContainer) {
        if (imageUrls.length > 1) {
            console.log('🖼️ Updating second image:', imageUrls[1]);
            const secondImageHtml = `<img alt="${escapeHtml(currentDeal.title || '')}" class="w-full h-full object-cover rounded-lg cursor-pointer hover:ring-2 hover:ring-primary transition-all" src="${escapeHtml(imageUrls[1])}" onerror="this.style.display='none'; this.nextElementSibling.style.display='flex';"><div style="display:none; width:100%; height:100%; align-items:center; justify-content:center; background:#f5f5f5; color:#999; font-size:24px;">📷</div>`;
            secondImageContainer.innerHTML = secondImageHtml;

            // İkinci görsele tıklama ile ana görsel yapma
            const secondImg = secondImageContainer.querySelector('img');
            if (secondImg) {
                secondImg.style.cursor = 'pointer';
                // Önceki listener'ı temizle
                const newSecondImg = secondImg.cloneNode(true);
                secondImg.parentNode.replaceChild(newSecondImg, secondImg);
                newSecondImg.addEventListener('click', window.swapMainImage);
            }
        } else {
            console.log('🖼️ No second image, showing placeholder');
            secondImageContainer.innerHTML = `<div style="width:100%; height:100%; display:flex; align-items:center; justify-content:center; background:#f5f5f5; color:#999; font-size:24px;">📷</div>`;
        }
    } else {
        console.warn('⚠️ Second image container not found');
    }

    console.log('✅ Modal images UI updated');
}

// Swap main image with second image (global function for onclick)
window.swapMainImage = async function () {
    if (!currentDeal || !currentDeal.imageUrls || currentDeal.imageUrls.length < 2) {
        console.warn('⚠️ Cannot swap: Need at least 2 images');
        return;
    }

    console.log('🔄 Swapping images...');

    // Görselleri değiştir
    const imageUrls = [...currentDeal.imageUrls];
    const temp = imageUrls[0];
    imageUrls[0] = imageUrls[1];
    imageUrls[1] = temp;

    // currentDeal'i güncelle
    currentDeal.imageUrls = imageUrls;
    currentDeal.imageUrl = imageUrls[0];

    console.log('✅ Images swapped:', imageUrls);

    // Firestore'a kaydet
    try {
        console.log('💾 Saving image swap to Firestore...');
        await db.collection('deals').doc(currentDeal.id).update({
            imageUrl: imageUrls[0],
            imageUrls: imageUrls,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        console.log('✅ Image swap saved to Firestore');
    } catch (error) {
        console.error('❌ Error saving image swap:', error);
        showError('Görsel değişikliği kaydedilemedi: ' + error.message);
        // Hata olsa bile UI'ı güncelle (kullanıcı deneyimi için)
    }

    // UI'ı güncelle (event listener'ları da yeniden ekler)
    updateModalImages(imageUrls);

    showSuccess('Görseller değiştirildi ve kaydedildi!');
}

// Show user detail modal
async function showUserDetail(userId) {
    console.log('👤 Showing user detail for:', userId);

    // Önce users array'inde ara
    let user = users.find(u => u.id === userId || u.uid === userId);

    // Eğer bulunamazsa, Firestore'dan direkt çek
    if (!user) {
        console.log('📥 Kullanıcı users array\'inde bulunamadı, Firestore\'dan çekiliyor...');
        try {
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                user = {
                    id: userDoc.id,
                    uid: userDoc.id,
                    ...userData,
                    profileImageUrl: cleanProfileImageUrl(userData.profileImageUrl)
                };
                console.log('✅ Kullanıcı Firestore\'dan yüklendi:', user);
            } else {
                console.error('❌ User not found in Firestore:', userId);
                showError('Kullanıcı bulunamadı!');
                return;
            }
        } catch (error) {
            console.error('❌ Firestore\'dan kullanıcı çekme hatası:', error);
            showError('Kullanıcı bilgileri yüklenirken hata oluştu: ' + error.message);
            return;
        }
    }

    // Kullanıcının engellenip engellenmediğini kontrol et
    let isBlocked = false;
    try {
        const blockedDoc = await db.collection('blockedUsers').doc(userId).get();
        isBlocked = blockedDoc.exists;
    } catch (error) {
        console.warn('⚠️ Engelleme durumu kontrol edilemedi:', error);
    }

    // Kullanıcının yorum yapmasının engellenip engellenmediğini kontrol et
    let isCommentBanned = false;
    try {
        const commentBanDoc = await db.collection('commentBannedUsers').doc(userId).get();
        isCommentBanned = commentBanDoc.exists;
    } catch (error) {
        console.warn('⚠️ Yorum engelleme durumu kontrol edilemedi:', error);
    }

    let isDealBanned = false;
    try {
        const dealBanDoc = await db.collection('dealBannedUsers').doc(userId).get();
        isDealBanned = dealBanDoc.exists;
    } catch (error) {
        console.warn('⚠️ Paylaşım engelleme durumu kontrol edilemedi:', error);
    }

    // Fetch active notification subscriptions from new system
    let subsList = [];
    try {
        const subsSnap = await db.collection('notificationSubscriptions')
            .where('uid', '==', userId)
            .where('enabled', '==', true)
            .get();
        subsSnap.forEach(d => subsList.push(d.data()));
    } catch (e) {
        console.warn('⚠️ Error loading active subscriptions:', e);
    }
    const followedCategories = subsList.filter(s => s.type === 'category').map(s => s.displayValue || s.key);
    const watchKeywords = subsList.filter(s => s.type === 'keyword').map(s => s.displayValue || s.key);

    const activeCategories = (followedCategories && followedCategories.length > 0)
        ? followedCategories
        : (user.followedCategories || []);
    const activeKeywords = (watchKeywords && watchKeywords.length > 0)
        ? watchKeywords
        : (user.watchKeywords || []);

    currentUserDetail = { ...user, isBlocked, isCommentBanned, isDealBanned, followedCategories: activeCategories, watchKeywords: activeKeywords };

    const userDetailModal = document.getElementById('userDetailModal');
    const userModalBody = document.getElementById('userModalBody');
    const userModalSidebar = document.getElementById('userModalSidebar');
    const userModalTitle = document.getElementById('userModalTitle');
    const userModalBreadcrumb = document.getElementById('userModalBreadcrumb');

    if (!userDetailModal || !userModalBody || !userModalSidebar) {
        console.error('❌ User detail modal elements not found!');
        console.error('userDetailModal:', userDetailModal);
        console.error('userModalBody:', userModalBody);
        console.error('userModalSidebar:', userModalSidebar);
        return;
    }

    console.log('✅ All modal elements found, rendering sidebar...');

    const displayName = user.nickname || user.username;
    const profileImage = user.profileImageUrl || 'https://ui-avatars.com/api/?name=' + encodeURIComponent(displayName) + '&background=135bec&color=fff&size=256';

    // Modal Title
    if (userModalTitle) {
        userModalTitle.textContent = displayName;
    }
    if (userModalBreadcrumb) {
        userModalBreadcrumb.textContent = displayName;
    }

    // Modal Body (Sol Kolon)
    userModalBody.innerHTML = `
        <!-- Profile Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 overflow-hidden p-6 shadow-sm">
            <div class="flex flex-col items-center gap-4">
                <img src="${profileImage}" alt="${escapeHtml(displayName)}" class="w-32 h-32 rounded-full object-cover bg-slate-200 dark:bg-slate-700 border-4 border-primary/20" onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=135bec&color=fff&size=256'">
                <div class="text-center">
                    <h2 class="text-2xl font-bold text-slate-900 dark:text-white">${escapeHtml(displayName)}</h2>
                    ${user.email ? `<p class="text-slate-500 dark:text-slate-400 mt-1">${escapeHtml(user.email)}</p>` : ''}
                </div>
            </div>
        </div>
        
        <!-- User Info Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm space-y-4">
            <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-4">Kullanıcı Bilgileri</h3>
            
            <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
                <div>
                    <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-1">Kullanıcı Adı</p>
                    <p class="text-base text-slate-900 dark:text-white">${escapeHtml(user.username || 'Bilinmiyor')}</p>
                </div>
                ${user.nickname ? `
                <div>
                    <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-1">Takma Ad</p>
                    <p class="text-base text-slate-900 dark:text-white">${escapeHtml(user.nickname)}</p>
                </div>
                ` : ''}
                <div>
                    <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-1">Kullanıcı ID</p>
                    <p class="text-base text-slate-900 dark:text-white font-mono text-xs">${escapeHtml(user.uid || user.id || 'Bilinmiyor')}</p>
                </div>
                <div>
                    <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-1">E-posta</p>
                    <p class="text-base text-slate-900 dark:text-white">${user.email ? escapeHtml(user.email) : '<span class="text-slate-400 italic">E-posta bulunamadı</span>'}</p>
                </div>
            </div>
        </div>
        
        <!-- Statistics Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm">
            <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-4">İstatistikler</h3>
            
            <div class="grid grid-cols-2 md:grid-cols-4 gap-4">
                <div class="text-center p-4 bg-slate-50 dark:bg-slate-900/50 rounded-lg">
                    <div class="flex items-center justify-center gap-1 mb-2">
                        <span class="material-symbols-outlined text-amber-500 text-2xl">stars</span>
                    </div>
                    <p class="text-2xl font-bold text-slate-900 dark:text-white">${user.points || 0}</p>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Puan</p>
                </div>
                <div class="text-center p-4 bg-slate-50 dark:bg-slate-900/50 rounded-lg">
                    <div class="flex items-center justify-center gap-1 mb-2">
                        <span class="material-symbols-outlined text-emerald-500 text-2xl">local_offer</span>
                    </div>
                    <p class="text-2xl font-bold text-slate-900 dark:text-white">${user.dealCount || 0}</p>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Fırsat</p>
                </div>
                <div class="text-center p-4 bg-slate-50 dark:bg-slate-900/50 rounded-lg">
                    <div class="flex items-center justify-center gap-1 mb-2">
                        <span class="material-symbols-outlined text-red-500 text-2xl">favorite</span>
                    </div>
                    <p class="text-2xl font-bold text-slate-900 dark:text-white">${user.totalLikes || 0}</p>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Beğeni</p>
                </div>
                <div class="text-center p-4 bg-slate-50 dark:bg-slate-900/50 rounded-lg">
                    <div class="flex items-center justify-center gap-1 mb-2">
                        <span class="material-symbols-outlined text-blue-500 text-2xl">group</span>
                    </div>
                    <p class="text-2xl font-bold text-slate-900 dark:text-white">${user.following ? user.following.length : 0}</p>
                    <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Takip</p>
                </div>
            </div>
        </div>
        
        <!-- Categories & Keywords Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-6 shadow-sm">
            <h3 class="text-lg font-bold text-gray-900 dark:text-white mb-4">Takip Edilenler</h3>
            
            <div class="space-y-4">
                <div>
                    <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-2">Takip Edilen Kategoriler</p>
                    ${activeCategories && activeCategories.length > 0 ? `
                        <div class="flex flex-wrap gap-2">
                            ${activeCategories.map(cat => `
                                <span class="px-3 py-1 bg-primary/10 text-primary rounded-full text-sm font-medium">${escapeHtml(cat)}</span>
                            `).join('')}
                        </div>
                    ` : '<p class="text-slate-500 dark:text-slate-400 text-sm">Kategori takip edilmiyor</p>'}
                </div>
                
                <div>
                    <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-2">Takip Edilen Anahtar Kelimeler</p>
                    ${activeKeywords && activeKeywords.length > 0 ? `
                        <div class="flex flex-wrap gap-2">
                            ${activeKeywords.map(keyword => `
                                <span class="px-3 py-1 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 rounded-full text-sm font-medium">${escapeHtml(keyword)}</span>
                            `).join('')}
                        </div>
                    ` : '<p class="text-slate-500 dark:text-slate-400 text-sm">Anahtar kelime takip edilmiyor</p>'}
                </div>
            </div>
        </div>
    `;

    // Modal Sidebar (Sağ Kolon)
    console.log('📝 Rendering user modal sidebar for user:', user.uid || user.id);
    userModalSidebar.innerHTML = `
        <!-- Badges Management Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm space-y-4">
            <div class="flex items-center justify-between">
                <div class="flex items-center gap-2">
                    <span class="material-symbols-outlined text-amber-500 text-xl">military_tech</span>
                    <h3 class="text-sm font-bold text-gray-900 dark:text-white uppercase tracking-wider">Rozet Yönetimi</h3>
                </div>
                <span class="px-2 py-0.5 bg-amber-500/10 text-amber-600 dark:text-amber-400 rounded-full text-xs font-bold">
                    ${(user.badges || []).length} Rozet
                </span>
            </div>

            <!-- Otomatik Eşitle Butonu -->
            <button onclick="window.autoAwardBadgesForUser('${escapeHtml(user.uid || user.id)}')" class="w-full px-3 py-2 bg-gradient-to-r from-amber-500 to-amber-600 hover:from-amber-600 hover:to-amber-700 text-white rounded-lg transition-all text-xs font-bold flex items-center justify-center gap-1.5 shadow-sm">
                <span class="material-symbols-outlined text-[16px]">sync</span>
                Hak Edilen Rozetleri Otomatik Eşitle
            </button>

            <!-- Mevcut Rozetler -->
            <div class="space-y-2">
                <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Mevcut Rozetler</p>
                ${user.badges && user.badges.length > 0 ? `
                    <div class="flex flex-col gap-2 max-h-56 overflow-y-auto pr-1">
                        ${user.badges.map(badgeId => {
                            const meta = getBadgeMeta(badgeId);
                            const isPinned = user.pinnedBadge === badgeId;
                            return `
                                <div class="flex items-center justify-between p-2.5 rounded-lg border transition-all ${isPinned ? 'bg-amber-500/15 border-amber-500/40 ring-1 ring-amber-500/30' : 'bg-slate-50 dark:bg-slate-800/60 border-slate-200 dark:border-slate-700'}">
                                    <div class="flex items-center gap-2 min-w-0">
                                        <div class="w-7 h-7 rounded-full flex items-center justify-center text-white flex-shrink-0 text-xs shadow-sm" style="background-color: ${meta.color};">
                                            <span class="material-symbols-outlined text-[15px]">${meta.icon}</span>
                                        </div>
                                        <div class="flex flex-col min-w-0">
                                            <div class="flex items-center gap-1.5 flex-wrap">
                                                <p class="text-xs font-bold text-slate-900 dark:text-white truncate">${escapeHtml(meta.name)}</p>
                                                <span class="px-1.5 py-0.2 rounded text-[10px] font-semibold text-white" style="background-color: ${meta.color};">${meta.tier}</span>
                                                ${isPinned ? '<span class="px-1.5 py-0.2 rounded bg-amber-500 text-white text-[10px] font-extrabold flex items-center gap-0.5">⭐ Vitrin</span>' : ''}
                                            </div>
                                            <p class="text-[11px] text-slate-500 dark:text-slate-400 truncate font-mono">${escapeHtml(badgeId)}</p>
                                        </div>
                                    </div>
                                    <div class="flex items-center gap-1 flex-shrink-0">
                                        <button onclick="window.togglePinBadge('${escapeHtml(user.uid || user.id)}', '${escapeHtml(badgeId)}')" class="p-1.5 rounded-lg transition-colors ${isPinned ? 'text-amber-600 hover:bg-amber-500/20' : 'text-slate-400 hover:text-amber-500 hover:bg-amber-500/10'}" title="${isPinned ? 'Vitrinden Kaldır' : 'Vitrinde Göster (Profilde Sabitle)'}">
                                            <span class="material-symbols-outlined text-[16px]">${isPinned ? 'push_pin' : 'keep'}</span>
                                        </button>
                                        <button onclick="window.removeBadge('${escapeHtml(user.uid || user.id)}', '${escapeHtml(badgeId)}')" class="p-1.5 text-rose-500 hover:text-rose-700 hover:bg-rose-500/10 rounded-lg transition-colors" title="Rozeti Kaldır">
                                            <span class="material-symbols-outlined text-[16px]">close</span>
                                        </button>
                                    </div>
                                </div>
                            `;
                        }).join('')}
                    </div>
                ` : '<p class="text-slate-500 dark:text-slate-400 text-xs italic py-2">Kullanıcının henüz bir rozeti bulunmuyor.</p>'}
            </div>

            <!-- Katalogdan Rozet Ekle -->
            <div class="space-y-2 pt-2 border-t border-slate-200 dark:border-slate-800">
                <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Katalogdan Rozet Ekle</p>
                <div class="flex gap-2">
                    <select id="catalogBadgeSelect" class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-primary">
                        <option value="">-- Rozet Seçin --</option>
                        <optgroup label="🎯 Fırsat Avcılığı">
                            <option value="first_spark">İlk Kıvılcım (Bronz)</option>
                            <option value="hunter_apprentice">Fırsat Çırağı (Gümüş)</option>
                            <option value="contributor">Katkıda Bulunan (Gümüş)</option>
                            <option value="master_hunter">Usta Avcı (Altın)</option>
                            <option value="legendary_hunter">Efsanevi Avcı (Elmas)</option>
                        </optgroup>
                        <optgroup label="🔥 Sıcaklık & Oylar">
                            <option value="active_voter">Aktif Seçmen (Bronz)</option>
                            <option value="flame_master">Alev Ustası (Altın)</option>
                            <option value="volcanic_record">Volkanik Rekortmen (Elmas)</option>
                        </optgroup>
                        <optgroup label="💬 Topluluk & Yorum">
                            <option value="voice_of_community">Söz Sahibi (Bronz)</option>
                            <option value="helpful">Yardımsever Avcı (Gümüş)</option>
                            <option value="top_reviewer">Fikir Önderi (Altın)</option>
                        </optgroup>
                        <optgroup label="⭐ Sadakat & Özel">
                            <option value="bronze">Bronz Avcı (Bronz)</option>
                            <option value="silver">Gümüş Avcı (Gümüş)</option>
                            <option value="gold">Altın Avcı (Altın)</option>
                            <option value="verified">Doğrulanmış Avcı (Özel)</option>
                            <option value="early_bird">Öncü Kurucu Üye (Özel)</option>
                            <option value="premium">Premium Üye (Özel)</option>
                        </optgroup>
                    </select>
                    <button onclick="window.addBadgeFromCatalog('${escapeHtml(user.uid || user.id)}')" class="px-3 py-1.5 bg-primary text-white rounded-lg hover:bg-primary/90 transition-colors text-xs font-bold flex items-center gap-1 flex-shrink-0">
                        <span class="material-symbols-outlined text-[15px]">add</span>
                        Ekle
                    </button>
                </div>
            </div>

            <!-- Özel Rozet Ekle -->
            <div class="space-y-1 pt-2 border-t border-slate-200 dark:border-slate-800">
                <p class="text-xs font-semibold text-slate-500 dark:text-slate-400 uppercase tracking-wider">Özel Rozet Girişi</p>
                <div class="flex gap-2">
                    <input type="text" id="newBadgeInput" placeholder="Örn: vip_member" class="flex-1 min-w-0 px-2.5 py-1.5 text-xs border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-primary">
                    <button onclick="window.addBadge('${escapeHtml(user.uid || user.id)}')" class="px-3 py-1.5 bg-slate-700 hover:bg-slate-800 text-white rounded-lg transition-colors text-xs font-medium flex items-center gap-1 flex-shrink-0">
                        <span class="material-symbols-outlined text-[15px]">add</span>
                        Özel Ekle
                    </button>
                </div>
            </div>
        </div>
        
        <!-- Following Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
            <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Takip Edilenler</h3>
            ${user.following && user.following.length > 0 ? `
                <div class="space-y-2 max-h-64 overflow-y-auto">
                    ${user.following.map(followingId => {
        const followedUser = users.find(u => (u.uid || u.id) === followingId);
        if (followedUser) {
            const followedDisplayName = followedUser.nickname || followedUser.username || 'Bilinmeyen';
            const followedProfileImage = followedUser.profileImageUrl || `https://ui-avatars.com/api/?name=${encodeURIComponent(followedDisplayName)}&background=135bec&color=fff&size=64`;
            return `
                                <div class="flex items-center gap-3 p-2 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
                                    <img src="${followedProfileImage}" alt="${escapeHtml(followedDisplayName)}" class="w-10 h-10 rounded-full object-cover border-2 border-slate-200 dark:border-slate-700" onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(followedDisplayName)}&background=135bec&color=fff&size=64'">
                                    <div class="flex-1 min-w-0">
                                        <p class="text-sm font-medium text-slate-900 dark:text-white truncate">${escapeHtml(followedDisplayName)}</p>
                                        <p class="text-xs text-slate-500 dark:text-slate-400 truncate">${escapeHtml(followedUser.email || '')}</p>
                                    </div>
                                </div>
                            `;
        } else {
            return `
                                <div class="flex items-center gap-3 p-2 hover:bg-slate-50 dark:hover:bg-slate-800 rounded-lg transition-colors">
                                    <div class="w-10 h-10 rounded-full bg-slate-300 dark:bg-slate-700 flex items-center justify-center">
                                        <span class="material-symbols-outlined text-slate-500 dark:text-slate-400 text-[20px]">person</span>
                                    </div>
                                    <div class="flex-1 min-w-0">
                                        <p class="text-sm font-medium text-slate-500 dark:text-slate-400 truncate">Kullanıcı bulunamadı</p>
                                        <p class="text-xs text-slate-400 dark:text-slate-500 truncate font-mono">${escapeHtml(followingId)}</p>
                                    </div>
                                </div>
                            `;
        }
    }).join('')}
                </div>
            ` : '<p class="text-slate-500 dark:text-slate-400 text-sm">Kimseyi takip etmiyor</p>'}
        </div>
        
        <!-- Admin Message Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
            <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Admin Mesajı</h3>
            <button onclick="window.showAdminMessageModal('${escapeHtml(user.uid || user.id)}', '${escapeHtml(user.nickname || user.username || 'Kullanıcı')}')" class="w-full px-4 py-2.5 bg-blue-500 hover:bg-blue-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2">
                <span class="material-symbols-outlined text-[18px]">mail</span>
                Mesaj Gönder
            </button>
        </div>
        
        <!-- Comments Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
            <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Yorumlar</h3>
            <button id="showUserCommentsBtn_${user.uid || user.id}" onclick="window.showUserComments('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-primary hover:bg-primary/90 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2">
                <span class="material-symbols-outlined text-[18px]">comment</span>
                Yaptığı Yorumlar
            </button>
        </div>
        
        <!-- Followers Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
            <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Takipçiler</h3>
            <p class="text-2xl font-bold text-slate-900 dark:text-white">${user.followersWithNotifications ? user.followersWithNotifications.length : 0}</p>
            <p class="text-xs text-slate-500 dark:text-slate-400 mt-1">Bildirim alan takipçiler</p>
        </div>
        
        <!-- Block/Unblock Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
            <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider mb-4">Kullanıcı Yönetimi</h3>
            <div class="space-y-3">
                <!-- Admin Role Section -->
                ${(user.isAdmin === true || user.isadmin === true || user.isAdmin === 'true') ? `
                    <div class="p-3 bg-blue-500/10 dark:bg-blue-500/20 border border-blue-500/20 rounded-lg">
                        <p class="text-sm text-blue-600 dark:text-blue-400 font-medium mb-1">👮 Yönetici (Admin)</p>
                        <p class="text-xs text-blue-500 dark:text-blue-400">Bu kullanıcı yönetim paneline erişebilir</p>
                    </div>
                    <button onclick="window.toggleUserAdminStatus('${escapeHtml(user.uid || user.id)}', false)" class="w-full px-4 py-2.5 bg-slate-500 hover:bg-slate-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">no_accounts</span>
                        Admin Yetkisini Kaldır
                    </button>
                ` : `
                    <button onclick="window.toggleUserAdminStatus('${escapeHtml(user.uid || user.id)}', true)" class="w-full px-4 py-2.5 bg-blue-600 hover:bg-blue-700 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">admin_panel_settings</span>
                        Admin Yetkisi Ver
                    </button>
                `}
                
                <div class="h-px bg-slate-100 dark:bg-slate-800 my-2"></div>

                ${currentUserDetail.isBlocked ? `
                    <div class="p-3 bg-red-500/10 dark:bg-red-500/20 border border-red-500/20 rounded-lg">
                        <p class="text-sm text-red-600 dark:text-red-400 font-medium mb-1">⚠️ Bu kullanıcı engellenmiş</p>
                        <p class="text-xs text-red-500 dark:text-red-400">Kullanıcı uygulamayı kullanamaz</p>
                    </div>
                    <button onclick="window.unblockUser('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-emerald-500 hover:bg-emerald-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">check_circle</span>
                        Engeli Kaldır
                    </button>
                ` : `
                    <button onclick="window.blockUser('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-red-500 hover:bg-red-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">block</span>
                        Kullanıcıyı Engelle
                    </button>
                `}
                
                <!-- Comment Ban Section -->
                ${currentUserDetail.isCommentBanned ? `
                    <div class="p-3 bg-orange-500/10 dark:bg-orange-500/20 border border-orange-500/20 rounded-lg">
                        <p class="text-sm text-orange-600 dark:text-orange-400 font-medium mb-1">🚫 Yorum yapması engellenmiş</p>
                        <p class="text-xs text-orange-500 dark:text-orange-400">Kullanıcı yorum yapamaz</p>
                    </div>
                    <button onclick="window.unbanUserComments('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-emerald-500 hover:bg-emerald-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">chat</span>
                        Yorum İzni Ver
                    </button>
                ` : `
                    <button onclick="window.banUserComments('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-orange-500 hover:bg-orange-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">comments_disabled</span>
                        Yorumu Engelle
                    </button>
                `}
                
                <!-- Deal Ban Section -->
                ${currentUserDetail.isDealBanned ? `
                    <div class="p-3 bg-red-500/10 dark:bg-red-500/20 border border-red-500/20 rounded-lg">
                        <p class="text-sm text-red-600 dark:text-red-400 font-medium mb-1">🚫 Paylaşım yapması engellenmiş</p>
                        <p class="text-xs text-red-500 dark:text-red-400">Kullanıcı fırsat paylaşamaz</p>
                    </div>
                    <button onclick="window.unbanUserDeals('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-emerald-500 hover:bg-emerald-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">add_circle</span>
                        Paylaşım İzni Ver
                    </button>
                ` : `
                    <button onclick="window.banUserDeals('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-red-500 hover:bg-red-600 text-white rounded-lg transition-colors text-sm font-medium flex items-center justify-center gap-2 whitespace-nowrap">
                        <span class="material-symbols-outlined text-[18px]">block</span>
                        Paylaşımı Engelle
                    </button>
                `}
                
                <div class="h-px bg-slate-200 dark:bg-slate-700/50 my-2"></div>
                <button onclick="window.deleteUserAccountAdmin('${escapeHtml(user.uid || user.id)}')" class="w-full px-4 py-2.5 bg-red-600 hover:bg-red-700 text-white rounded-lg transition-colors text-sm font-semibold flex items-center justify-center gap-2 whitespace-nowrap">
                    <span class="material-symbols-outlined text-[18px]">delete_forever</span>
                    Hesabı ve Tüm Verileri Sil
                </button>
            </div>
        </div>
    `;

    console.log('✅ User modal sidebar rendered, checking for comments button...');
    // Modal'ı göster
    userDetailModal.classList.remove('hidden');

    // Butonun render edildiğini kontrol et
    setTimeout(() => {
        const commentsBtn = document.getElementById(`showUserCommentsBtn_${user.uid || user.id}`);
        if (commentsBtn) {
            console.log('✅ Comments button found in DOM');
        } else {
            console.error('❌ Comments button NOT found in DOM!');
        }
    }, 500);

    // ESC tuşu ile kapat
    const handleEscapeKey = (e) => {
        if (e.key === 'Escape' && !userDetailModal.classList.contains('hidden')) {
            console.log('⌨️ ESC tuşu ile kullanıcı modal kapatılıyor...');
            closeUserDetailModal();
            document.removeEventListener('keydown', handleEscapeKey);
        }
    };
    document.addEventListener('keydown', handleEscapeKey);

    // Close button event listener
    setTimeout(() => {
        const closeUserModalBtn = document.getElementById('closeUserModal');
        if (closeUserModalBtn) {
            const newCloseBtn = closeUserModalBtn.cloneNode(true);
            closeUserModalBtn.parentNode.replaceChild(newCloseBtn, closeUserModalBtn);
            newCloseBtn.addEventListener('click', closeUserDetailModal);
        }
    }, 100);
}

// Close user detail modal
function closeUserDetailModal() {
    const userDetailModal = document.getElementById('userDetailModal');
    if (userDetailModal) {
        userDetailModal.classList.add('hidden');
        currentUserDetail = null;
        console.log('✅ Kullanıcı modal kapatıldı');
    }
}

// Show user comments modal
window.showUserComments = async function (userId) {
    console.log('💬 Loading comments for user:', userId);

    // Önce users array'inde ara
    let user = users.find(u => (u.uid || u.id) === userId);

    // Eğer bulunamazsa, Firestore'dan direkt çek
    if (!user) {
        console.log('📥 Kullanıcı users array\'inde bulunamadı, Firestore\'dan çekiliyor...');
        try {
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                user = {
                    id: userDoc.id,
                    uid: userDoc.id,
                    ...userData,
                    profileImageUrl: cleanProfileImageUrl(userData.profileImageUrl)
                };
                console.log('✅ Kullanıcı Firestore\'dan yüklendi:', user);
            } else {
                console.error('❌ User not found in Firestore:', userId);
                showError('Kullanıcı bulunamadı!');
                return;
            }
        } catch (error) {
            console.error('❌ Firestore\'dan kullanıcı çekme hatası:', error);
            showError('Kullanıcı bilgileri yüklenirken hata oluştu: ' + error.message);
            return;
        }
    }

    const userCommentsModal = document.getElementById('userCommentsModal');
    const userCommentsModalTitle = document.getElementById('userCommentsModalTitle');
    const userCommentsModalSubtitle = document.getElementById('userCommentsModalSubtitle');
    const userCommentsLoading = document.getElementById('userCommentsLoading');
    const userCommentsList = document.getElementById('userCommentsList');
    const userCommentsEmpty = document.getElementById('userCommentsEmpty');

    if (!userCommentsModal) {
        console.error('❌ User comments modal not found!');
        return;
    }

    const displayName = user.nickname || user.username || 'Kullanıcı';

    // Modal başlığını güncelle
    if (userCommentsModalTitle) {
        userCommentsModalTitle.textContent = `${displayName} - Yorumlar`;
    }
    if (userCommentsModalSubtitle) {
        userCommentsModalSubtitle.textContent = 'Kullanıcının yaptığı tüm yorumlar';
    }

    // Modal'ı göster
    userCommentsModal.classList.remove('hidden');
    userCommentsLoading.classList.remove('hidden');
    userCommentsList.classList.add('hidden');
    userCommentsEmpty.classList.add('hidden');

    try {
        console.log('🔍 Searching for comments by userId:', userId);
        const allComments = [];
        const limit = 100; // Maksimum yorum sayısı (performans için)
        let lastDoc = null;
        let hasMore = true;
        let batchCount = 0;
        const maxBatches = 10; // Maksimum 10 batch (1000 yorum)

        // Collection group query kullanarak tüm deal'lerin comments alt koleksiyonlarında arama yap
        // Bu yaklaşım daha verimli ama composite index gerektirebilir
        while (hasMore && batchCount < maxBatches) {
            try {
                let query = db.collectionGroup('comments')
                    .where('userId', '==', userId)
                    .orderBy('createdAt', 'desc')
                    .limit(limit);

                if (lastDoc) {
                    query = query.startAfter(lastDoc);
                }

                const commentsSnapshot = await query.get();
                console.log(`📦 Batch ${batchCount + 1}: Found ${commentsSnapshot.docs.length} comments`);

                if (commentsSnapshot.docs.length === 0) {
                    hasMore = false;
                    break;
                }

                // Her yorum için deal bilgisini al
                const dealPromises = commentsSnapshot.docs.map(async (commentDoc) => {
                    const commentData = commentDoc.data();
                    const dealId = commentData.dealId || '';

                    // Deal bilgisini al
                    let dealData = {};
                    let dealTitle = 'Başlıksız Fırsat';
                    let dealImageUrl = '';

                    if (dealId) {
                        try {
                            const dealDoc = await db.collection('deals').doc(dealId).get();
                            if (dealDoc.exists) {
                                dealData = dealDoc.data();
                                dealTitle = dealData.title || 'Başlıksız Fırsat';
                                dealImageUrl = dealData.imageUrl || dealData.imageUrls?.[0] || '';
                            }
                        } catch (error) {
                            console.warn(`⚠️ Could not fetch deal ${dealId}:`, error);
                        }
                    }

                    // createdAt'i parse et
                    let createdAtDate;
                    if (commentData.createdAt && commentData.createdAt.toDate) {
                        createdAtDate = commentData.createdAt.toDate();
                    } else if (commentData.createdAt) {
                        createdAtDate = new Date(commentData.createdAt);
                    } else {
                        createdAtDate = new Date();
                    }

                    return {
                        id: commentDoc.id,
                        dealId: dealId,
                        dealTitle: dealTitle,
                        dealImageUrl: dealImageUrl,
                        text: commentData.text || '',
                        createdAt: createdAtDate,
                        userName: commentData.userName || displayName,
                        userProfileImageUrl: commentData.userProfileImageUrl || user.profileImageUrl || '',
                    };
                });

                const batchComments = await Promise.all(dealPromises);
                allComments.push(...batchComments);

                if (commentsSnapshot.docs.length < limit) {
                    hasMore = false;
                } else {
                    lastDoc = commentsSnapshot.docs[commentsSnapshot.docs.length - 1];
                    batchCount++;
                }
            } catch (error) {
                console.error(`❌ Error in batch ${batchCount + 1}:`, error);
                // Eğer composite index hatası varsa, fallback yöntemine geç
                if (error.code === 'failed-precondition') {
                    console.warn('⚠️ Composite index required. Falling back to alternative method...');
                    hasMore = false;
                    // Fallback: Eski yöntem (daha yavaş ama çalışır)
                    await loadCommentsFallback(userId, allComments, displayName, user);
                    break;
                } else {
                    hasMore = false;
                }
            }
        }

        console.log(`📊 Total comments found: ${allComments.length}`);

        // Yorumları tarihe göre sırala (yeni önce)
        allComments.sort((a, b) => b.createdAt - a.createdAt);

        console.log(`✅ Loaded ${allComments.length} comments for user ${userId}`);

        // Loading'i gizle
        userCommentsLoading.classList.add('hidden');

        if (allComments.length === 0) {
            // Yorum yok
            userCommentsEmpty.classList.remove('hidden');
        } else {
            // Yorumları göster
            userCommentsList.classList.remove('hidden');
            userCommentsList.innerHTML = allComments.map(comment => {
                const commentDate = new Date(comment.createdAt);
                const formattedDate = commentDate.toLocaleDateString('tr-TR', {
                    year: 'numeric',
                    month: 'long',
                    day: 'numeric',
                    hour: '2-digit',
                    minute: '2-digit'
                });

                return `
                    <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
                        <div class="flex items-start gap-4">
                            <!-- Deal Image -->
                            <div class="flex-shrink-0">
                                <img src="${escapeHtml(comment.dealImageUrl || '')}" alt="${escapeHtml(comment.dealTitle)}" 
                                     class="w-20 h-20 rounded-lg object-cover bg-slate-200 dark:bg-slate-700"
                                     onerror="this.onerror=null; this.src='https://via.placeholder.com/80x80?text=📷'">
                            </div>
                            
                            <!-- Comment Content -->
                            <div class="flex-1 min-w-0">
                                <div class="flex items-start justify-between gap-4 mb-2">
                                    <div class="flex-1 min-w-0">
                                        <h4 class="text-sm font-semibold text-slate-900 dark:text-white mb-1 truncate">
                                            ${escapeHtml(comment.dealTitle)}
                                        </h4>
                                        <p class="text-xs text-slate-500 dark:text-slate-400">
                                            ${escapeHtml(formattedDate)}
                                        </p>
                                    </div>
                                    <button onclick="window.deleteUserComment('${escapeHtml(comment.id)}', '${escapeHtml(comment.dealId)}', '${escapeHtml(userId)}')" 
                                            class="flex-shrink-0 p-2 text-red-500 hover:bg-red-50 dark:hover:bg-red-500/10 rounded-lg transition-colors" 
                                            title="Yorumu Sil">
                                        <span class="material-symbols-outlined text-[20px]">delete</span>
                                    </button>
                                </div>
                                <p class="text-sm text-slate-700 dark:text-slate-300 whitespace-pre-wrap break-words">
                                    ${escapeHtml(comment.text)}
                                </p>
                            </div>
                        </div>
                    </div>
                `;
            }).join('');
        }

        // Close button event listener
        setTimeout(() => {
            const closeUserCommentsModalBtn = document.getElementById('closeUserCommentsModal');
            if (closeUserCommentsModalBtn) {
                const newCloseBtn = closeUserCommentsModalBtn.cloneNode(true);
                closeUserCommentsModalBtn.parentNode.replaceChild(newCloseBtn, closeUserCommentsModalBtn);
                newCloseBtn.addEventListener('click', closeUserCommentsModal);
            }
        }, 100);

        // ESC tuşu ile kapat
        const handleEscapeKey = (e) => {
            if (e.key === 'Escape' && !userCommentsModal.classList.contains('hidden')) {
                closeUserCommentsModal();
                document.removeEventListener('keydown', handleEscapeKey);
            }
        };
        document.addEventListener('keydown', handleEscapeKey);

    } catch (error) {
        console.error('❌ Error loading user comments:', error);
        showError('Yorumlar yüklenirken hata oluştu: ' + error.message);
        userCommentsLoading.classList.add('hidden');
    }
}

// Fallback method for loading comments (if composite index is not available)
async function loadCommentsFallback(userId, allComments, displayName, user) {
    console.log('🔄 Using fallback method to load comments...');
    const dealsSnapshot = await db.collection('deals').limit(100).get(); // Limit to 100 deals for performance
    console.log(`📦 Checking ${dealsSnapshot.docs.length} deals (limited for performance)`);

    for (const dealDoc of dealsSnapshot.docs) {
        const dealId = dealDoc.id;
        const dealData = dealDoc.data();

        try {
            // Tüm yorumları al ve client-side'da filtrele
            const commentsSnapshot = await db.collection('deals').doc(dealId).collection('comments')
                .limit(50) // Her deal için maksimum 50 yorum
                .get();

            commentsSnapshot.forEach(commentDoc => {
                const commentData = commentDoc.data();
                const commentUserId = commentData.userId || '';

                if (commentUserId.toLowerCase() === userId.toLowerCase()) {
                    let createdAtDate;
                    if (commentData.createdAt && commentData.createdAt.toDate) {
                        createdAtDate = commentData.createdAt.toDate();
                    } else if (commentData.createdAt) {
                        createdAtDate = new Date(commentData.createdAt);
                    } else {
                        createdAtDate = new Date();
                    }

                    allComments.push({
                        id: commentDoc.id,
                        dealId: dealId,
                        dealTitle: dealData.title || 'Başlıksız Fırsat',
                        dealImageUrl: dealData.imageUrl || dealData.imageUrls?.[0] || '',
                        text: commentData.text || '',
                        createdAt: createdAtDate,
                        userName: commentData.userName || displayName,
                        userProfileImageUrl: commentData.userProfileImageUrl || user.profileImageUrl || '',
                    });
                }
            });
        } catch (error) {
            console.warn(`⚠️ Error loading comments for deal ${dealId}:`, error);
        }
    }
}

// Close user comments modal
function closeUserCommentsModal() {
    const userCommentsModal = document.getElementById('userCommentsModal');
    if (userCommentsModal) {
        userCommentsModal.classList.add('hidden');
        console.log('✅ User comments modal closed');
    }
}

// Delete user comment
window.deleteUserComment = async function (commentId, dealId, userId) {
    if (!confirm('Bu yorumu silmek istediğinize emin misiniz?')) {
        return;
    }

    try {
        console.log(`🗑️ Deleting comment ${commentId} from deal ${dealId}`);

        // Yorumu sil
        await db.collection('deals').doc(dealId).collection('comments').doc(commentId).delete();

        // Deal'in commentCount'unu azalt
        const dealRef = db.collection('deals').doc(dealId);
        await dealRef.update({
            commentCount: firebase.firestore.FieldValue.increment(-1)
        });

        showSuccess('Yorum başarıyla silindi!');

        // Yorumları yeniden yükle
        await window.showUserComments(userId);

    } catch (error) {
        console.error('❌ Error deleting comment:', error);
        showError('Yorum silinirken hata oluştu: ' + error.message);
    }
}

// Add badge from official catalog dropdown
window.addBadgeFromCatalog = async function (userId) {
    const select = document.getElementById('catalogBadgeSelect');
    if (!select || !select.value) {
        showError('Lütfen katalogdan bir rozet seçin!');
        return;
    }
    const badgeId = select.value;
    await window.addBadgeById(userId, badgeId);
};

// Add badge by manual input
window.addBadge = async function (userId) {
    const input = document.getElementById('newBadgeInput');
    if (!input) return;

    const badgeName = input.value.trim();
    if (!badgeName) {
        showError('Lütfen bir rozet adı girin!');
        return;
    }

    await window.addBadgeById(userId, badgeName);
    input.value = '';
};

// Core Add Badge method
window.addBadgeById = async function (userId, badgeId) {
    // Önce users array'inde ara
    let user = users.find(u => (u.uid || u.id) === userId);

    // Eğer bulunamazsa, Firestore'dan direkt çek
    if (!user) {
        try {
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists) {
                user = {
                    id: userDoc.id,
                    uid: userDoc.id,
                    ...userDoc.data(),
                    profileImageUrl: cleanProfileImageUrl(userDoc.data().profileImageUrl)
                };
            } else {
                showError('Kullanıcı bulunamadı!');
                return;
            }
        } catch (error) {
            console.error('❌ Firestore\'dan kullanıcı çekme hatası:', error);
            showError('Kullanıcı bilgileri yüklenirken hata oluştu: ' + error.message);
            return;
        }
    }

    // Rozet zaten varsa ekleme
    const currentBadges = user.badges || [];
    if (currentBadges.includes(badgeId)) {
        showError('Bu rozet zaten kullanıcıda mevcut!');
        return;
    }

    // Firestore'a ekle
    const newBadges = [...currentBadges, badgeId];
    try {
        await db.collection('users').doc(userId).update({
            badges: firebase.firestore.FieldValue.arrayUnion(badgeId)
        });

        console.log('✅ Rozet eklendi:', badgeId);
        user.badges = newBadges;
        await showUserDetail(userId);
        showSuccess(`✅ "${getBadgeMeta(badgeId).name}" rozeti başarıyla eklendi!`);
    } catch (error) {
        console.error('❌ Rozet ekleme hatası:', error);
        showError('Rozet eklenirken bir hata oluştu: ' + error.message);
    }
};

// Remove badge from user
window.removeBadge = async function (userId, badgeName) {
    const meta = getBadgeMeta(badgeName);
    if (!confirm(`"${meta.name}" (${badgeName}) rozetini bu kullanıcıdan kaldırmak istediğinize emin misiniz?`)) {
        return;
    }

    // Önce users array'inde ara
    let user = users.find(u => (u.uid || u.id) === userId);

    // Eğer bulunamazsa, Firestore'dan direkt çek
    if (!user) {
        try {
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists) {
                user = {
                    id: userDoc.id,
                    uid: userDoc.id,
                    ...userDoc.data(),
                    profileImageUrl: cleanProfileImageUrl(userDoc.data().profileImageUrl)
                };
            } else {
                showError('Kullanıcı bulunamadı!');
                return;
            }
        } catch (error) {
            console.error('❌ Firestore\'dan kullanıcı çekme hatası:', error);
            showError('Kullanıcı bilgileri yüklenirken hata oluştu: ' + error.message);
            return;
        }
    }

    // Firestore'dan kaldır
    const currentBadges = user.badges || [];
    const newBadges = currentBadges.filter(b => b !== badgeName);
    const updates = { badges: newBadges };

    // Eğer silinen rozet kullanıcının vitrin rozeti ise onu da kaldır
    if (user.pinnedBadge === badgeName) {
        updates.pinnedBadge = firebase.firestore.FieldValue.delete();
        user.pinnedBadge = null;
    }

    try {
        await db.collection('users').doc(userId).update(updates);

        console.log('✅ Rozet kaldırıldı:', badgeName);
        user.badges = newBadges;
        await showUserDetail(userId);
        showSuccess(`"${meta.name}" rozeti başarıyla kaldırıldı!`);
    } catch (error) {
        console.error('❌ Rozet kaldırma hatası:', error);
        showError('Rozet kaldırılırken bir hata oluştu: ' + error.message);
    }
};

// Toggle Pin Badge (Vitrin Rozeti Yap / Kaldır)
window.togglePinBadge = async function (userId, badgeId) {
    let user = users.find(u => (u.uid || u.id) === userId);
    if (!user) {
        const userDoc = await db.collection('users').doc(userId).get();
        if (userDoc.exists) user = { id: userDoc.id, uid: userDoc.id, ...userDoc.data() };
    }
    if (!user) return;

    const isCurrentlyPinned = user.pinnedBadge === badgeId;
    const newPinned = isCurrentlyPinned ? null : badgeId;
    const meta = getBadgeMeta(badgeId);

    try {
        await db.collection('users').doc(userId).update({
            pinnedBadge: newPinned ? newPinned : firebase.firestore.FieldValue.delete()
        });
        user.pinnedBadge = newPinned;
        showSuccess(newPinned ? `⭐ "${meta.name}" kullanıcının vitrin rozeti olarak sabitlendi!` : 'Vitrin rozeti kaldırıldı.');
        await showUserDetail(userId);
    } catch (e) {
        console.error('❌ Vitrin rozeti güncelleme hatası:', e);
        showError('Vitrin rozeti güncellenirken hata: ' + e.message);
    }
};

// Auto-Award Badges based on user stats
window.autoAwardBadgesForUser = async function (userId) {
    let user = users.find(u => (u.uid || u.id) === userId);
    if (!user) {
        try {
            const userDoc = await db.collection('users').doc(userId).get();
            if (userDoc.exists) {
                user = { id: userDoc.id, uid: userDoc.id, ...userDoc.data() };
            }
        } catch (e) {
            showError('Kullanıcı bulunamadı!');
            return;
        }
    }
    if (!user) return;

    const dealCount = user.dealCount || 0;
    const points = user.points || 0;
    const totalLikes = user.totalLikes || 0;
    const currentBadges = new Set(user.badges || []);

    const eligible = [];
    if (dealCount >= 1) eligible.push('first_spark');
    if (dealCount >= 10) eligible.push('hunter_apprentice');
    if (dealCount >= 20) eligible.push('contributor');
    if (dealCount >= 50) eligible.push('master_hunter');
    if (dealCount >= 150) eligible.push('legendary_hunter');

    if (points >= 15) eligible.push('bronze');
    if (points >= 35) eligible.push('voice_of_community');
    if (points >= 50) eligible.push('active_voter');
    if (points >= 100) eligible.push('silver');
    if (points >= 150) eligible.push('flame_master');
    if (points >= 300) eligible.push('gold');
    if (points >= 500) eligible.push('volcanic_record');

    if (totalLikes >= 40) eligible.push('helpful');
    if (totalLikes >= 150) eligible.push('top_reviewer');

    const toAdd = eligible.filter(b => !currentBadges.has(b));
    if (toAdd.length === 0) {
        showSuccess('Kullanıcı zaten tüm istatistiksel rozetlerine sahip!');
        return;
    }

    try {
        await db.collection('users').doc(userId).update({
            badges: firebase.firestore.FieldValue.arrayUnion(...toAdd)
        });
        showSuccess(`🎉 ${toAdd.length} yeni hak edilmiş rozet otomatik eklendi: ${toAdd.map(b => getBadgeMeta(b).name).join(', ')}`);
        user.badges = Array.from(new Set([...currentBadges, ...toAdd]));
        await showUserDetail(userId);
    } catch (e) {
        console.error('❌ Otomatik rozet eşitleme hatası:', e);
        showError('Rozetler eşitlenirken hata oluştu: ' + e.message);
    }
};

// Block user
window.blockUser = async function (userId) {
    console.log('🔒 Block user called with userId:', userId);

    if (!userId) {
        console.error('❌ UserId is missing!');
        showError('Kullanıcı ID bulunamadı!');
        return;
    }

    if (!confirm('Bu kullanıcıyı engellemek istediğinize emin misiniz?\n\nEngellenen kullanıcı uygulamayı kullanamaz.')) {
        return;
    }

    try {
        console.log('📝 Blocking user in Firestore:', userId);
        await db.collection('blockedUsers').doc(userId).set({
            blockedAt: firebase.firestore.FieldValue.serverTimestamp(),
            blockedBy: currentUser ? currentUser.uid : 'admin'
        });

        console.log('✅ Kullanıcı engellendi:', userId);
        showSuccess('Kullanıcı başarıyla engellendi!');

        // Kullanıcı listesini güncelle
        const user = users.find(u => (u.uid || u.id) === userId);
        if (user) {
            user.isBlocked = true;
        }
        if (currentUserDetail) {
            currentUserDetail.isBlocked = true;
        }
        renderUsers();

        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Kullanıcı engelleme hatası:', error);
        showError('Kullanıcı engellenirken bir hata oluştu: ' + error.message);
    }
};

// Unblock user
window.unblockUser = async function (userId) {
    console.log('🔓 Unblock user called with userId:', userId);

    if (!userId) {
        console.error('❌ UserId is missing!');
        showError('Kullanıcı ID bulunamadı!');
        return;
    }

    if (!confirm('Bu kullanıcının engelini kaldırmak istediğinize emin misiniz?')) {
        return;
    }

    try {
        console.log('📝 Unblocking user in Firestore:', userId);
        await db.collection('blockedUsers').doc(userId).delete();

        console.log('✅ Kullanıcı engeli kaldırıldı:', userId);
        showSuccess('Kullanıcı engeli başarıyla kaldırıldı!');

        // Kullanıcı listesini güncelle
        const user = users.find(u => (u.uid || u.id) === userId);
        if (user) {
            user.isBlocked = false;
        }
        if (currentUserDetail) {
            currentUserDetail.isBlocked = false;
        }
        renderUsers();

        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Kullanıcı engeli kaldırma hatası:', error);
        showError('Kullanıcı engeli kaldırılırken bir hata oluştu: ' + error.message);
    }
};

// Ban user from commenting
window.banUserComments = async function (userId) {
    console.log('🚫 Ban user comments called with userId:', userId);

    if (!userId) {
        console.error('❌ UserId is missing!');
        showError('Kullanıcı ID bulunamadı!');
        return;
    }

    if (!confirm('Bu kullanıcının yorum yapmasını engellemek istediğinize emin misiniz?')) {
        return;
    }

    try {
        console.log('📝 Banning user comments in Firestore:', userId);
        await db.collection('commentBannedUsers').doc(userId).set({
            bannedAt: firebase.firestore.FieldValue.serverTimestamp(),
            bannedBy: currentUser ? currentUser.uid : 'admin'
        });

        console.log('✅ Kullanıcı yorum yapması engellendi:', userId);
        showSuccess('Kullanıcının yorum yapması başarıyla engellendi!');

        const user = users.find(u => (u.uid || u.id) === userId);
        if (user) {
            user.isCommentBanned = true;
        }
        if (currentUserDetail) {
            currentUserDetail.isCommentBanned = true;
        }

        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Yorum engelleme hatası:', error);
        showError('Yorum engellenirken bir hata oluştu: ' + error.message);
    }
};

// Unban user from commenting
window.unbanUserComments = async function (userId) {
    console.log('💬 Unban user comments called with userId:', userId);

    if (!userId) {
        console.error('❌ UserId is missing!');
        showError('Kullanıcı ID bulunamadı!');
        return;
    }

    if (!confirm('Bu kullanıcıya yorum iznini geri vermek istediğinize emin misiniz?')) {
        return;
    }

    try {
        console.log('📝 Unbanning user comments in Firestore:', userId);
        await db.collection('commentBannedUsers').doc(userId).delete();

        console.log('✅ Kullanıcı yorum izni geri verildi:', userId);
        showSuccess('Kullanıcıya yorum izni başarıyla geri verildi!');

        const user = users.find(u => (u.uid || u.id) === userId);
        if (user) {
            user.isCommentBanned = false;
        }
        if (currentUserDetail) {
            currentUserDetail.isCommentBanned = false;
        }

        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Yorum izni geri verme hatası:', error);
        showError('Yorum izni geri verilirken bir hata oluştu: ' + error.message);
    }
};

// Ban user from sharing deals
window.banUserDeals = async function (userId) {
    console.log('🚫 Ban user deals called with userId:', userId);

    if (!userId) {
        console.error('❌ UserId is missing!');
        showError('Kullanıcı ID bulunamadı!');
        return;
    }

    if (!confirm('Bu kullanıcının fırsat paylaşımını engellemek istediğinize emin misiniz?')) {
        return;
    }

    try {
        console.log('📝 Banning user deals in Firestore:', userId);
        await db.collection('dealBannedUsers').doc(userId).set({
            bannedAt: firebase.firestore.FieldValue.serverTimestamp(),
            bannedBy: currentUser ? currentUser.uid : 'admin'
        });

        console.log('✅ Kullanıcı paylaşımı engellendi:', userId);
        showSuccess('Kullanıcının fırsat paylaşımı başarıyla engellendi!');

        const user = users.find(u => (u.uid || u.id) === userId);
        if (user) {
            user.isDealBanned = true;
        }
        if (currentUserDetail) {
            currentUserDetail.isDealBanned = true;
        }

        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Paylaşım engelleme hatası:', error);
        showError('Paylaşım engellenirken bir hata oluştu: ' + error.message);
    }
};

// Unban user from sharing deals
window.unbanUserDeals = async function (userId) {
    console.log('✅ Unban user deals called with userId:', userId);

    if (!userId) {
        console.error('❌ UserId is missing!');
        showError('Kullanıcı ID bulunamadı!');
        return;
    }

    if (!confirm('Bu kullanıcıya paylaşım iznini geri vermek istediğinize emin misiniz?')) {
        return;
    }

    try {
        console.log('📝 Unbanning user deals in Firestore:', userId);
        await db.collection('dealBannedUsers').doc(userId).delete();

        console.log('✅ Kullanıcı paylaşım izni geri verildi:', userId);
        showSuccess('Kullanıcının paylaşım izni başarıyla geri verildi!');

        const user = users.find(u => (u.uid || u.id) === userId);
        if (user) {
            user.isDealBanned = false;
        }
        if (currentUserDetail) {
            currentUserDetail.isDealBanned = false;
        }

        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Paylaşım izni geri verme hatası:', error);
        showError('Paylaşım izni geri verilirken bir hata oluştu: ' + error.message);
    }
};

// Delete user account and all Firestore data
window.deleteUserAccountAdmin = async function (userId) {
    console.log('🚨 deleteUserAccountAdmin called with userId:', userId);

    if (!userId) {
        console.error('❌ UserId is missing!');
        showError('Kullanıcı ID bulunamadı!');
        return;
    }

    const firstConfirm = confirm('⚠️ DİKKAT: Bu kullanıcının profilini, paylaştığı tüm fırsatları, yorumlarını, mesajlarını, cihazlarını ve giriş hesabını KALICI olarak silmek istediğinize emin misiniz?\n\nBu işlem geri alınamaz!');
    if (!firstConfirm) return;

    const secondConfirm = confirm('🚨 SON UYARI: Kullanıcıya ait tüm veriler veritabanından ve giriş sistemi (Auth) üzerinden tamamen yok edilecektir. Onaylıyor musunuz?');
    if (!secondConfirm) return;

    showLoading();
    try {
        console.log('📝 Deleting target user via Cloud Function:', userId);
        const deleteFn = firebase.functions().httpsCallable('adminDeleteUser');
        const res = await deleteFn({ targetUid: userId });

        if (res.data && res.data.success) {
            showSuccess('✅ Kullanıcı hesabı ve tüm ilişkili verileri başarıyla kalıcı olarak silindi!');
            
            // In-memory listeden kaldır
            users = users.filter(u => (u.uid || u.id) !== userId);
            renderUsers();
            
            let totalDeals = 0;
            let totalPoints = 0;
            users.forEach(u => {
                totalDeals += (u.dealCount || 0);
                totalPoints += (u.points || 0);
            });
            updateUsersStats(users.length, totalDeals, totalPoints);

            // Modal'ı kapat
            const userDetailModal = document.getElementById('userDetailModal');
            if (userDetailModal) {
                userDetailModal.classList.add('hidden');
            }
        } else {
            throw new Error('Silme işlemi başarısız döndü.');
        }
    } catch (error) {
        console.error('❌ Kullanıcı silme hatası:', error);
        showError('Kullanıcı silinirken bir hata oluştu: ' + error.message);
    } finally {
        hideLoading();
    }
};

// Export users to UTF-8 CSV
window.exportUsersToCSV = function () {
    if (!users || users.length === 0) {
        showError('Dışa aktarılacak kullanıcı verisi bulunamadı!');
        return;
    }

    const headers = [
        'Kullanici ID',
        'Kullanici Adi',
        'Takma Ad',
        'E-posta',
        'Puan',
        'Firsat Sayisi',
        'Begeni Sayisi',
        'Rozetler',
        'Vitrin Rozeti',
        'Yonetici (Admin)',
        'Engelli',
        'Kayit Tarihi'
    ];

    const rows = users.map(u => [
        `"${(u.uid || u.id || '').replace(/"/g, '""')}"`,
        `"${(u.username || '').replace(/"/g, '""')}"`,
        `"${(u.nickname || '').replace(/"/g, '""')}"`,
        `"${(u.email || '').replace(/"/g, '""')}"`,
        u.points || 0,
        u.dealCount || 0,
        u.totalLikes || 0,
        `"${(u.badges || []).join(', ')}"`,
        `"${(u.pinnedBadge || '').replace(/"/g, '""')}"`,
        u.isAdmin ? 'Evet' : 'Hayir',
        u.isBlocked ? 'Evet' : 'Hayir',
        `"${u.createdAt ? new Date(u.createdAt).toLocaleString('tr-TR') : ''}"`
    ]);

    const csvContent = '\uFEFF' + [headers.join(';'), ...rows.map(r => r.join(';'))].join('\r\n');
    const blob = new Blob([csvContent], { type: 'text/csv;charset=utf-8;' });
    const url = URL.createObjectURL(blob);
    const link = document.createElement('a');
    link.setAttribute('href', url);
    link.setAttribute('download', `firsatkolik_kullanicilar_${new Date().toISOString().slice(0, 10)}.csv`);
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);
    URL.revokeObjectURL(url);
    showSuccess(`${users.length} kullanıcı CSV olarak dışa aktarıldı!`);
};

// Show admin message modal
window.showAdminMessageModal = function (userId, userName) {
    console.log('📨 Opening admin message modal for user:', userId, userName);

    const adminMessageModal = document.getElementById('adminMessageModal');
    const adminMessageModalTitle = document.getElementById('adminMessageModalTitle');
    const adminMessageModalSubtitle = document.getElementById('adminMessageModalSubtitle');
    const adminMessageForm = document.getElementById('adminMessageForm');
    const adminMessageTitle = document.getElementById('adminMessageTitle');
    const adminMessageContent = document.getElementById('adminMessageContent');

    if (!adminMessageModal || !adminMessageForm) {
        console.error('❌ Admin message modal elements not found!');
        return;
    }

    // Store current user ID for form submission
    adminMessageForm.dataset.userId = userId;

    // Update modal title
    if (adminMessageModalTitle) {
        adminMessageModalTitle.textContent = `${userName} - Mesaj Gönder`;
    }
    if (adminMessageModalSubtitle) {
        adminMessageModalSubtitle.textContent = 'Kullanıcıya mesaj gönderin (kullanıcı cevap veremez)';
    }

    // Clear form
    if (adminMessageTitle) adminMessageTitle.value = '';
    if (adminMessageContent) adminMessageContent.value = '';

    // Show modal
    adminMessageModal.classList.remove('hidden');

    // Add event listeners
    const closeBtn = document.getElementById('closeAdminMessageModal');
    const cancelBtn = document.getElementById('cancelAdminMessageBtn');

    if (closeBtn) {
        closeBtn.onclick = closeAdminMessageModal;
    }
    if (cancelBtn) {
        cancelBtn.onclick = closeAdminMessageModal;
    }

    // Handle ESC key
    const handleEscape = (e) => {
        if (e.key === 'Escape' && !adminMessageModal.classList.contains('hidden')) {
            closeAdminMessageModal();
            document.removeEventListener('keydown', handleEscape);
        }
    };
    document.addEventListener('keydown', handleEscape);

    // Focus on title input
    if (adminMessageTitle) {
        setTimeout(() => adminMessageTitle.focus(), 100);
    }
};

// Close admin message modal
function closeAdminMessageModal() {
    const adminMessageModal = document.getElementById('adminMessageModal');
    if (adminMessageModal) {
        adminMessageModal.classList.add('hidden');
    }
}

window.closeAdminMessageModal = closeAdminMessageModal;
window.openAdminMessageModal = function(userId, userName) {
    if (typeof window.showAdminMessageModal === 'function') {
        window.showAdminMessageModal(userId, userName);
    }
};

// Send admin message
window.sendAdminMessage = async function (userId, title, content) {
    console.log('📤 Sending admin message to user:', userId);

    if (!title || !content) {
        showError('Lütfen başlık ve içerik girin!');
        return;
    }

    try {
        // Get current admin user
        const currentUser = auth.currentUser;
        if (!currentUser) {
            showError('Giriş yapmış admin bulunamadı!');
            return;
        }

        // Get admin user data
        const adminDoc = await db.collection('users').doc(currentUser.uid).get();
        const adminData = adminDoc.data();
        const adminName = adminData?.username || adminData?.nickname || 'Admin';

        // Create message document in adminToUserMessages (triggers Cloud Function onAdminMessageCreated)
        const messageRef = db.collection('adminToUserMessages').doc();
        await messageRef.set({
            id: messageRef.id,
            userId: userId,
            adminId: currentUser.uid,
            adminName: adminName,
            title: title,
            content: content,
            isRead: false,
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
        });

        console.log('✅ Admin message sent successfully:', messageRef.id);
        showSuccess('Mesaj ve bildirim başarıyla gönderildi!');

        // Close modal
        closeAdminMessageModal();

    } catch (error) {
        console.error('❌ Error sending admin message:', error);
        showError('Mesaj gönderilirken hata oluştu: ' + error.message);
    }
};

// Deal Sharing ve Onay durumunu yükle ve butonu güncelle
async function loadDealSharingStatus() {
    try {
        console.log('📥 Loading deal sharing and approval status...');
        const settingsDoc = await db.collection('settings').doc('app').get();
        const dealSharingEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().dealSharingEnabled !== false)
            : true;
            
        const dealApprovalRequired = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().dealApprovalRequired !== false)
            : true;
            
        const couponsEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().couponsEnabled !== false)
            : true;

        const botkolikChatEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().botkolikChatEnabled !== false)
            : true;

        console.log('📊 Deal sharing enabled:', dealSharingEnabled);
        console.log('📊 Deal approval required:', dealApprovalRequired);
        console.log('📊 Coupons enabled:', couponsEnabled);
        console.log('📊 Botkolik chat enabled:', botkolikChatEnabled);
        updateDealSharingButton(dealSharingEnabled);
        
        const approvalToggle = document.getElementById('settingsToggleDealApprovalBtn');
        if (approvalToggle) {
            approvalToggle.checked = dealApprovalRequired;
        }

        const couponsToggle = document.getElementById('settingsToggleCouponsBtn');
        if (couponsToggle) {
            couponsToggle.checked = couponsEnabled;
        }

        const botkolikChatToggle = document.getElementById('settingsToggleBotkolikChatBtn');
        if (botkolikChatToggle) {
            botkolikChatToggle.checked = botkolikChatEnabled;
        }
    } catch (error) {
        console.error('❌ Error loading deal sharing status:', error);
        updateDealSharingButton(true); // Varsayılan olarak aktif
    }
}

// Deal Sharing butonunu güncelle
function updateDealSharingButton(enabled) {
    const btn = document.getElementById('toggleDealSharingBtn');
    console.log('🔄 Updating deal sharing button, enabled:', enabled, 'button:', btn);

    const settingsToggle = document.getElementById('settingsToggleDealSharingBtn');
    if (settingsToggle) {
        settingsToggle.checked = enabled;
    }

    if (!btn) {
        console.error('❌ Button not found in updateDealSharingButton!');
        return;
    }

    if (enabled) {
        // Paylaşımlar aktif
        btn.innerHTML = `
            <span class="material-symbols-outlined text-[18px]">block</span>
            <span>Paylaşımı Engelle</span>
        `;
        btn.className = 'flex items-center justify-center gap-1.5 rounded-lg h-10 px-3 bg-surface-darker border border-slate-700 hover:bg-slate-800 text-white text-xs font-medium transition-colors whitespace-nowrap';
    } else {
        // Paylaşımlar durdurulmuş
        btn.innerHTML = `
            <span class="material-symbols-outlined text-[18px]">check_circle</span>
            <span>Paylaşımı Aktif Et</span>
        `;
        btn.className = 'flex items-center justify-center gap-1.5 rounded-lg h-10 px-3 bg-emerald-600 hover:bg-emerald-700 border border-emerald-500 text-white text-xs font-medium transition-colors whitespace-nowrap';
    }
}

// Deal Sharing durumunu toggle et
async function toggleDealSharing() {
    try {
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().dealSharingEnabled !== false)
            : true;

        const newStatus = !currentStatus;

        await settingsRef.set({
            dealSharingEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        updateDealSharingButton(newStatus);

        const message = newStatus
            ? '✅ Kullanıcı paylaşımları aktifleştirildi!'
            : '🚫 Kullanıcı paylaşımları durduruldu!';
        showSuccess(message);

        console.log(`✅ Deal sharing ${newStatus ? 'enabled' : 'disabled'}`);
    } catch (error) {
        console.error('❌ Error toggling deal sharing:', error);
        showError('Paylaşım durumu değiştirilirken hata oluştu: ' + error.message);
    }
}

// 30+ Günlük Fırsatları Kalıcı Olarak Temizleme (Derin Temizlik)
async function purgeOldDealsWeb() {
    console.log('🔥 30+ günlük derin temizlik işlemi başlatılıyor...');

    // 1. Önce Cloud Function (purgeOldDealsManual) üzerinden güvenli ve tam yetkili backend silmesini dene
    try {
        console.log('⚡ Cloud Function (purgeOldDealsManual) çağrılıyor...');
        const purgeFunc = firebase.functions().httpsCallable('purgeOldDealsManual', { timeout: 540000 });
        const res = await purgeFunc({});
        if (res && res.data && res.data.success) {
            const stats = res.data.stats || {};
            const deletedCount = stats.deletedCount || 0;
            const deletedNotificationsCount = stats.deletedNotificationsCount || 0;
            console.log(`✅ Cloud Function ile temizlik bitti. Silinen Fırsat: ${deletedCount}, Silinen Bildirim: ${deletedNotificationsCount}`);
            return { deletedCount, deletedNotificationsCount };
        }
    } catch (fnErr) {
        console.warn('⚠️ Cloud Function çağrısı başarısız oldu, doğrudan Firestore üzerinden deneniyor:', fnErr.message);
    }

    // 2. Doğrudan Firestore istemcisi üzerinden yedek silme işlemi
    const thirtyDaysAgo = new Date(Date.now() - (30 * 24 * 60 * 60 * 1000));
    const thirtyDaysAgoTimestamp = firebase.firestore.Timestamp.fromDate(thirtyDaysAgo);

    const targetDocs = new Map();

    try {
        const snap1 = await db.collection('deals').where('createdAt', '<', thirtyDaysAgoTimestamp).get();
        snap1.forEach(doc => targetDocs.set(doc.id, doc));
    } catch (e) {
        console.warn('createdAt sorgusu uyarısı:', e);
    }

    try {
        const snap2 = await db.collection('deals').where('timestamp', '<', thirtyDaysAgoTimestamp).get();
        snap2.forEach(doc => targetDocs.set(doc.id, doc));
    } catch (e) {
        console.warn('timestamp sorgusu uyarısı:', e);
    }

    console.log(`🔍 30 günden eski toplam ${targetDocs.size} adet fırsat bulundu.`);

    let deletedCount = 0;

    for (const [dealId, doc] of targetDocs) {
        try {
            const dealRef = db.collection('deals').doc(dealId);

            // A. votes subcollection
            const votesSnap = await dealRef.collection('votes').get();
            if (!votesSnap.empty) {
                const batch = db.batch();
                votesSnap.forEach(v => batch.delete(v.ref));
                await batch.commit();
            }

            // B. comments subcollection
            const commentsSnap = await dealRef.collection('comments').get();
            if (!commentsSnap.empty) {
                const batch = db.batch();
                commentsSnap.forEach(c => batch.delete(c.ref));
                await batch.commit();
            }

            // C. users favorites references
            const usersSnap = await db.collection('users').get();
            for (const userDoc of usersSnap.docs) {
                try {
                    const favRef = userDoc.ref.collection('favorites').doc(dealId);
                    const favDoc = await favRef.get();
                    if (favDoc.exists) {
                        await favRef.delete();
                    }
                } catch (favErr) {}
            }

            // D. Main deal doc delete
            await dealRef.delete();
            deletedCount++;
            console.log(`🗑️ Kalıcı silindi: ${dealId}`);
        } catch (docError) {
            console.error(`❌ Deal silme hatası (${dealId}):`, docError);
        }
    }

    // E. 30 Günü Geçmiş Tüm Bildirimleri Temizle (Notification Center / users/{uid}/notifications)
    let deletedNotificationsCount = 0;
    try {
        console.log('🧹 30 günden eski bildirimler taranıyor...');
        let hasMoreNotifs = true;
        while (hasMoreNotifs) {
            const notifsSnap = await db.collectionGroup('notifications')
                .where('createdAt', '<', thirtyDaysAgoTimestamp)
                .limit(400)
                .get();

            if (notifsSnap.empty) {
                hasMoreNotifs = false;
                break;
            }

            const notifBatch = db.batch();
            notifsSnap.docs.forEach(doc => notifBatch.delete(doc.ref));
            await notifBatch.commit();

            deletedNotificationsCount += notifsSnap.size;
            console.log(`🗑️ ${notifsSnap.size} eski bildirim silindi (Toplam: ${deletedNotificationsCount})`);

            if (notifsSnap.size < 400) {
                hasMoreNotifs = false;
            }
        }
    } catch (notifErr) {
        console.warn('⚠️ Bildirim temizleme sırasında hata (isteğe bağlı):', notifErr);
    }

    console.log(`✅ 30+ günlük derin temizlik bitti. Silinen Fırsat: ${deletedCount}, Silinen Bildirim: ${deletedNotificationsCount}`);
    return { deletedCount, deletedNotificationsCount };
}

// Deal Approval durumunu toggle et
async function toggleDealApproval() {
    try {
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().dealApprovalRequired !== false)
            : true;

        const newStatus = !currentStatus;

        await settingsRef.set({
            dealApprovalRequired: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        const message = newStatus
            ? '✅ Fırsat paylaşımları için admin onayı aktifleştirildi!'
            : '🚫 Fırsat paylaşımları için admin onayı devre dışı bırakıldı (Doğrudan Yayınlama)!';
        showSuccess(message);

        console.log(`✅ Deal approval requirement set to ${newStatus}`);
    } catch (error) {
        console.error('❌ Error toggling deal approval requirement:', error);
        showError('Onay gereksinimi değiştirilirken hata oluştu: ' + error.message);
        
        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleDealApprovalBtn');
        if (toggle) {
            toggle.checked = !toggle.checked;
        }
    }
}

// Coupons Enabled durumunu toggle et
async function toggleCouponsEnabled() {
    try {
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().couponsEnabled !== false)
            : true;

        const newStatus = !currentStatus;

        await settingsRef.set({
            couponsEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        const message = newStatus
            ? '✅ Kuponlar modülü mobil uygulamada aktifleştirildi!'
            : '🚫 Kuponlar modülü mobil uygulamada devre dışı bırakıldı!';
        showSuccess(message);

        console.log(`✅ Coupons enabled status set to ${newStatus}`);
    } catch (error) {
        console.error('❌ Error toggling coupons enabled status:', error);
        showError('Kupon modülü durumu değiştirilirken hata oluştu: ' + error.message);
        
        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleCouponsBtn');
        if (toggle) {
            toggle.checked = !toggle.checked;
        }
    }
}

// Botkolik Chat durumunu toggle et
async function toggleBotkolikChat() {
    try {
        console.log('🔄 toggleBotkolikChat başladı...');
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().botkolikChatEnabled !== false)
            : true;

        const newStatus = !currentStatus;
        console.log('📊 New Botkolik chat status:', newStatus);

        await settingsRef.set({
            botkolikChatEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        const toggle = document.getElementById('settingsToggleBotkolikChatBtn');
        if (toggle) {
            toggle.checked = newStatus;
        }

        const message = newStatus
            ? '✅ Botkolik ile mesajlaşma aktifleştirildi!'
            : '🚫 Botkolik ile mesajlaşma durduruldu (mobil arayüzde gizlendi)!';
        showSuccess(message);

        console.log(`✅ Botkolik chat enabled status set to ${newStatus}`);
    } catch (error) {
        console.error('❌ Error toggling Botkolik chat status:', error);
        showError('Botkolik mesajlaşma durumu değiştirilirken hata oluştu: ' + error.message);
        
        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleBotkolikChatBtn');
        if (toggle) {
            toggle.checked = !toggle.checked;
        }
    }
}

// Firestore settings/app belgesini anlık dinleyen listener (Tüm sekmeler ve cihazlar arasında anlık senkronizasyon)
let adminAffiliateSettingsUnsubscribe = null;
function initAdminAffiliateSettingsListener() {
    if (typeof db === 'undefined' || !db || adminAffiliateSettingsUnsubscribe) return;
    try {
        adminAffiliateSettingsUnsubscribe = db.collection('settings').doc('app').onSnapshot((doc) => {
            if (doc.exists && doc.data()) {
                const data = doc.data();
                const teknosaEnabled = data.teknosaAffiliateEnabled !== false;
                const hepsiburadaEnabled = data.hepsiburadaAffiliateEnabled !== false;
                const amazonEnabled = data.amazonAffiliateEnabled !== false;
                const incehesapEnabled = data.incehesapAffiliateEnabled !== false;

                if (typeof affiliateConfig !== 'undefined') {
                    if (affiliateConfig.teknosa) affiliateConfig.teknosa.enabled = teknosaEnabled;
                    if (affiliateConfig.hepsiburada) affiliateConfig.hepsiburada.enabled = hepsiburadaEnabled;
                    if (affiliateConfig.amazon) affiliateConfig.amazon.enabled = amazonEnabled;
                    if (affiliateConfig.incehesap) {
                        affiliateConfig.incehesap.enabled = incehesapEnabled;
                        if (data.incehesapSessionCookie !== undefined) {
                            affiliateConfig.incehesap.sessionCookie = data.incehesapSessionCookie;
                        }
                        if (data.incehesapProductLinkCache && typeof data.incehesapProductLinkCache === 'object') {
                            affiliateConfig.incehesap.productLinkCache = Object.assign(
                                {},
                                affiliateConfig.incehesap.productLinkCache,
                                data.incehesapProductLinkCache
                            );
                        }
                    }
                }

                const tToggle = document.getElementById('settingsToggleTeknosaAffiliateBtn');
                if (tToggle && tToggle.checked !== teknosaEnabled) {
                    tToggle.checked = teknosaEnabled;
                }

                const hToggle = document.getElementById('settingsToggleHepsiburadaAffiliateBtn');
                if (hToggle && hToggle.checked !== hepsiburadaEnabled) {
                    hToggle.checked = hepsiburadaEnabled;
                }

                const aToggle = document.getElementById('settingsToggleAmazonAffiliateBtn');
                if (aToggle && aToggle.checked !== amazonEnabled) {
                    aToggle.checked = amazonEnabled;
                }

                const iToggle = document.getElementById('settingsToggleIncehesapAffiliateBtn');
                if (iToggle && iToggle.checked !== incehesapEnabled) {
                    iToggle.checked = incehesapEnabled;
                }
                console.log('🔄 [AffiliateSettings] Firestore settings/app anlık güncellendi: Teknosa =', teknosaEnabled, ', Hepsiburada =', hepsiburadaEnabled, ', Amazon =', amazonEnabled, ', İncehesap =', incehesapEnabled);
            }
        }, (err) => {
            console.warn('Affiliate settings listener error:', err);
        });
    } catch (e) {
        console.warn('initAdminAffiliateSettingsListener error:', e);
    }
}

// Teknosa Affiliate durumunu Firestore'dan yükle ve switch'i güncelle
async function loadTeknosaAffiliateStatus() {
    initAdminAffiliateSettingsListener();
    try {
        console.log('📥 Loading Teknosa affiliate status from Firestore...');
        const settingsDoc = await db.collection('settings').doc('app').get();
        const isEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().teknosaAffiliateEnabled !== false)
            : true;

        console.log('📊 Teknosa affiliate enabled:', isEnabled);

        // config.js içerisindeki affiliateConfig nesnesini güncelle
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.teknosa) {
            affiliateConfig.teknosa.enabled = isEnabled;
        }

        const toggle = document.getElementById('settingsToggleTeknosaAffiliateBtn');
        if (toggle) {
            toggle.checked = isEnabled;
        }
    } catch (error) {
        console.error('❌ Error loading Teknosa affiliate status:', error);
    }
}

// Teknosa Affiliate durumunu toggle et ve Firestore settings/app belgesine yaz
async function toggleTeknosaAffiliate() {
    try {
        console.log('🔄 toggleTeknosaAffiliate başladı...');
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().teknosaAffiliateEnabled !== false)
            : true;

        const newStatus = !currentStatus;
        console.log('📊 New Teknosa affiliate status:', newStatus);

        await settingsRef.set({
            teknosaAffiliateEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // config.js içerisindeki affiliateConfig nesnesini anında senkronize et
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.teknosa) {
            affiliateConfig.teknosa.enabled = newStatus;
        }

        const toggle = document.getElementById('settingsToggleTeknosaAffiliateBtn');
        if (toggle) {
            toggle.checked = newStatus;
        }

        const message = newStatus
            ? '✅ Teknosa Affiliate (Paylaş Kazan) dönüşümü aktifleştirildi!'
            : '🛡️ Teknosa Affiliate dönüşümü kapatıldı! Sistem güvenli fallback (temiz ürün linki) moduna geçti.';
        showSuccess(message);

        console.log(`✅ Teknosa affiliate status set to ${newStatus}`);
    } catch (error) {
        console.error('❌ Error toggling Teknosa affiliate status:', error);
        showError('Teknosa affiliate durumu değiştirilirken hata oluştu: ' + error.message);

        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleTeknosaAffiliateBtn');
        if (toggle) {
            toggle.checked = !toggle.checked;
        }
    }
}

// Hepsiburada Affiliate durumunu Firestore'dan yükle ve switch'i güncelle
async function loadHepsiburadaAffiliateStatus() {
    try {
        console.log('📥 Loading Hepsiburada affiliate status from Firestore...');
        const settingsDoc = await db.collection('settings').doc('app').get();
        const isEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().hepsiburadaAffiliateEnabled !== false)
            : true;

        console.log('📊 Hepsiburada affiliate enabled:', isEnabled);

        // config.js içerisindeki affiliateConfig nesnesini güncelle
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.hepsiburada) {
            affiliateConfig.hepsiburada.enabled = isEnabled;
        }

        const toggle = document.getElementById('settingsToggleHepsiburadaAffiliateBtn');
        if (toggle) {
            toggle.checked = isEnabled;
        }
    } catch (error) {
        console.error('❌ Error loading Hepsiburada affiliate status:', error);
    }
}

// Hepsiburada Affiliate durumunu toggle et ve Firestore settings/app belgesine yaz
async function toggleHepsiburadaAffiliate() {
    try {
        console.log('🔄 toggleHepsiburadaAffiliate başladı...');
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().hepsiburadaAffiliateEnabled !== false)
            : true;

        const newStatus = !currentStatus;
        console.log('📊 New Hepsiburada affiliate status:', newStatus);

        await settingsRef.set({
            hepsiburadaAffiliateEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // config.js içerisindeki affiliateConfig nesnesini anında senkronize et
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.hepsiburada) {
            affiliateConfig.hepsiburada.enabled = newStatus;
        }

        const toggle = document.getElementById('settingsToggleHepsiburadaAffiliateBtn');
        if (toggle) {
            toggle.checked = newStatus;
        }

        const message = newStatus
            ? '✅ Hepsiburada Affiliate (LinkGelir) dönüşümü aktifleştirildi!'
            : '🛡️ Hepsiburada Affiliate dönüşümü kapatıldı! Sistem güvenli fallback (temiz ürün linki) moduna geçti.';
        showSuccess(message);

        console.log(`✅ Hepsiburada affiliate status set to ${newStatus}`);
    } catch (error) {
        console.error('❌ Error toggling Hepsiburada affiliate status:', error);
        showError('Hepsiburada affiliate durumu değiştirilirken hata oluştu: ' + error.message);

        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleHepsiburadaAffiliateBtn');
        if (toggle) {
            toggle.checked = !toggle.checked;
        }
    }
}

// Amazon Affiliate durumunu Firestore'dan yükle ve switch'i güncelle
async function loadAmazonAffiliateStatus() {
    try {
        console.log('📥 Loading Amazon affiliate status from Firestore...');
        const settingsDoc = await db.collection('settings').doc('app').get();
        const isEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().amazonAffiliateEnabled !== false)
            : true;

        console.log('📊 Amazon affiliate enabled:', isEnabled);

        // config.js içerisindeki affiliateConfig nesnesini güncelle
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.amazon) {
            affiliateConfig.amazon.enabled = isEnabled;
        }

        const toggle = document.getElementById('settingsToggleAmazonAffiliateBtn');
        if (toggle) {
            toggle.checked = isEnabled;
        }
    } catch (error) {
        console.error('❌ Error loading Amazon affiliate status:', error);
    }
}

// Amazon Affiliate durumunu toggle et ve Firestore settings/app belgesine yaz
async function toggleAmazonAffiliate() {
    try {
        console.log('🔄 toggleAmazonAffiliate başladı...');
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().amazonAffiliateEnabled !== false)
            : true;

        const newStatus = !currentStatus;
        console.log('📊 New Amazon affiliate status:', newStatus);

        await settingsRef.set({
            amazonAffiliateEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // config.js içerisindeki affiliateConfig nesnesini anında senkronize et
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.amazon) {
            affiliateConfig.amazon.enabled = newStatus;
        }

        const toggle = document.getElementById('settingsToggleAmazonAffiliateBtn');
        if (toggle) {
            toggle.checked = newStatus;
        }

        const message = newStatus
            ? '✅ Amazon Associates (Gelir Ortaklığı) dönüşümü aktifleştirildi!'
            : '🛡️ Amazon Associates dönüşümü kapatıldı! Sistem güvenli fallback (temiz ürün linki) moduna geçti.';
        showSuccess(message);

        console.log(`✅ Amazon affiliate status set to ${newStatus}`);
    } catch (error) {
        console.error('❌ Error toggling Amazon affiliate status:', error);
        showError('Amazon affiliate durumu değiştirilirken hata oluştu: ' + error.message);

        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleAmazonAffiliateBtn');
        if (toggle) {
            toggle.checked = !toggle.checked;
        }
    }
}

// İncehesap Affiliate durumunu Firestore'dan yükle ve switch'i güncelle
async function loadIncehesapAffiliateStatus() {
    try {
        console.log('📥 Loading İncehesap affiliate status from Firestore...');
        const settingsDoc = await db.collection('settings').doc('app').get();
        const isEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().incehesapAffiliateEnabled !== false)
            : true;

        console.log('📊 İncehesap affiliate enabled:', isEnabled);

        // config.js içerisindeki affiliateConfig nesnesini güncelle
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.incehesap) {
            affiliateConfig.incehesap.enabled = isEnabled;
            if (settingsDoc.exists && settingsDoc.data()) {
                const sData = settingsDoc.data();
                if (sData.incehesapSessionCookie !== undefined) {
                    affiliateConfig.incehesap.sessionCookie = sData.incehesapSessionCookie;
                }
                if (sData.incehesapProductLinkCache && typeof sData.incehesapProductLinkCache === 'object') {
                    affiliateConfig.incehesap.productLinkCache = Object.assign(
                        {},
                        affiliateConfig.incehesap.productLinkCache,
                        sData.incehesapProductLinkCache
                    );
                }
            }
        }

        const toggle = document.getElementById('settingsToggleIncehesapAffiliateBtn');
        if (toggle) {
            toggle.checked = isEnabled;
        }
    } catch (error) {
        console.error('❌ Error loading İncehesap affiliate status:', error);
    }
}

// İncehesap Affiliate durumunu toggle et ve Firestore settings/app belgesine yaz
async function toggleIncehesapAffiliate() {
    try {
        console.log('🔄 toggleIncehesapAffiliate başladı...');
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().incehesapAffiliateEnabled !== false)
            : true;

        const newStatus = !currentStatus;
        console.log('📊 New İncehesap affiliate status:', newStatus);

        await settingsRef.set({
            incehesapAffiliateEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        }, { merge: true });

        // config.js içerisindeki affiliateConfig nesnesini anında senkronize et
        if (typeof affiliateConfig !== 'undefined' && affiliateConfig.incehesap) {
            affiliateConfig.incehesap.enabled = newStatus;
        }

        const toggle = document.getElementById('settingsToggleIncehesapAffiliateBtn');
        if (toggle) {
            toggle.checked = newStatus;
        }

        const message = newStatus
            ? '✅ İncehesap Affiliate (Paylaştıkça Kazan) dönüşümü aktifleştirildi!'
            : '🛡️ İncehesap Affiliate dönüşümü kapatıldı! Sistem güvenli fallback (temiz ürün linki) moduna geçti.';
        showSuccess(message);

        console.log(`✅ İncehesap affiliate status set to ${newStatus}`);
    } catch (error) {
        console.error('❌ Error toggling İncehesap affiliate status:', error);
        showError('İncehesap affiliate durumu değiştirilirken hata oluştu: ' + error.message);

        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleIncehesapAffiliateBtn');
        if (toggle) {
            toggle.checked = !toggle.checked;
        }
    }
}

// Comment Sharing durumunu yükle ve butonu güncelle
async function loadCommentSharingStatus() {
    try {
        console.log('📥 Loading comment sharing status...');
        const settingsDoc = await db.collection('settings').doc('app').get();
        const commentSharingEnabled = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().commentSharingEnabled !== false)
            : true;

        console.log('📊 Comment sharing enabled:', commentSharingEnabled);
        updateCommentSharingButton(commentSharingEnabled);
    } catch (error) {
        console.error('❌ Error loading comment sharing status:', error);
        updateCommentSharingButton(true); // Varsayılan olarak aktif
    }
}

// Comment Sharing butonunu güncelle
function updateCommentSharingButton(enabled) {
    const btn = document.getElementById('toggleCommentSharingBtn');
    console.log('🔄 Updating comment sharing button, enabled:', enabled, 'button:', btn);

    const settingsToggle = document.getElementById('settingsToggleCommentSharingBtn');
    if (settingsToggle) {
        settingsToggle.checked = enabled;
    }

    if (!btn) {
        console.error('❌ Button not found in updateCommentSharingButton!');
        return;
    }

    if (enabled) {
        // Yorumlar aktif - Durdur butonu göster
        btn.innerHTML = `
            <span class="material-symbols-outlined text-[18px]">block</span>
            <span>Yorumları Durdur</span>
        `;
        btn.className = 'flex items-center justify-center gap-1.5 rounded-lg h-10 px-3 bg-surface-darker border border-slate-700 hover:bg-slate-800 text-white text-xs font-medium transition-colors whitespace-nowrap';
    } else {
        // Yorumlar durdurulmuş - Aktif Et butonu göster
        btn.innerHTML = `
            <span class="material-symbols-outlined text-[18px]">comment</span>
            <span>Yorumları Aktif Et</span>
        `;
        btn.className = 'flex items-center justify-center gap-1.5 rounded-lg h-10 px-3 bg-emerald-600 hover:bg-emerald-700 border border-emerald-500 text-white text-xs font-medium transition-colors whitespace-nowrap';
    }
}

// Comment Sharing durumunu toggle et
async function toggleCommentSharing() {
    try {
        console.log('🔄 toggleCommentSharing başladı...');
        const settingsRef = db.collection('settings').doc('app');
        const settingsDoc = await settingsRef.get();

        console.log('📄 Settings doc exists:', settingsDoc.exists);
        if (settingsDoc.exists) {
            console.log('📄 Settings doc data:', settingsDoc.data());
        }

        const currentStatus = settingsDoc.exists && settingsDoc.data()
            ? (settingsDoc.data().commentSharingEnabled !== false)
            : true;

        console.log('📊 Current comment sharing status:', currentStatus);

        const newStatus = !currentStatus;
        console.log('📊 New comment sharing status:', newStatus);

        const updateData = {
            commentSharingEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp(),
        };

        console.log('📝 Firestore\'a yazılacak data:', updateData);

        try {
            await settingsRef.set(updateData, { merge: true });
            console.log('✅ Firestore\'a yazıldı: commentSharingEnabled =', newStatus);
        } catch (writeError) {
            console.error('❌ Firestore yazma hatası:', writeError);
            throw writeError;
        }

        // Değeri tekrar oku ve doğrula
        await new Promise(resolve => setTimeout(resolve, 500)); // Kısa bir bekleme
        const verifyDoc = await settingsRef.get();
        const verifiedData = verifyDoc.exists ? verifyDoc.data() : null;
        const verifiedStatus = verifiedData
            ? (verifiedData.commentSharingEnabled !== false)
            : true;
        console.log('✅ Doğrulama - Firestore\'daki değer:', verifiedStatus);
        console.log('✅ Doğrulama - Tüm data:', verifiedData);

        updateCommentSharingButton(newStatus);

        const message = newStatus
            ? '✅ Kullanıcı yorumları aktifleştirildi!'
            : '🚫 Kullanıcı yorumları durduruldu!';
        showSuccess(message);

        console.log(`✅ Comment sharing ${newStatus ? 'enabled' : 'disabled'}`);
    } catch (error) {
        console.error('❌ Error toggling comment sharing:', error);
        console.error('❌ Error details:', error.stack);
        showError('Yorum durumu değiştirilirken hata oluştu: ' + error.message);
    }
}

// Global functions for onclick
window.showUserDetail = showUserDetail;
window.closeUserDetailModal = closeUserDetailModal;
window.banUserDeals = banUserDeals;
window.unbanUserDeals = unbanUserDeals;

// Reports and Settings View Extensions
let reports = [];
let reportsUnsubscribe = null;
let reportsCurrentTab = 'complaints';
let currentReportUnderAction = null;
let currentReportActionOptions = [];
let reportsFilterStatus = 'all'; // 'all', 'pending', 'action_taken', 'dismissed'
let reportsFilterType = 'all';   // 'all', 'deal', 'comment', 'user', 'message'

window.switchReportsTab = function(tabName) {
    reportsCurrentTab = tabName;
    const complaintsContainer = document.getElementById('reportsComplaintsContainer');
    const autoModContainer = document.getElementById('reportsAutoModContainer');
    const tabComplaintsBtn = document.getElementById('reportTabComplaintsBtn');
    const tabAutoModBtn = document.getElementById('reportTabAutoModBtn');

    const defaultBtnClass = 'px-5 py-3 font-semibold text-sm border-b-2 border-transparent text-slate-400 hover:text-white flex items-center gap-2 transition-colors relative cursor-pointer';
    const activeBtnClass = 'px-5 py-3 font-bold text-sm border-b-2 border-primary text-primary flex items-center gap-2 transition-colors relative cursor-pointer';

    if (complaintsContainer) complaintsContainer.classList.add('hidden');
    if (autoModContainer) {
        autoModContainer.classList.add('hidden');
        autoModContainer.classList.remove('flex');
    }

    if (tabComplaintsBtn) tabComplaintsBtn.className = defaultBtnClass;
    if (tabAutoModBtn) tabAutoModBtn.className = defaultBtnClass;

    if (tabName === 'complaints') {
        if (complaintsContainer) complaintsContainer.classList.remove('hidden');
        if (tabComplaintsBtn) tabComplaintsBtn.className = activeBtnClass;
        loadReports();
    } else if (tabName === 'automod') {
        if (autoModContainer) {
            autoModContainer.classList.remove('hidden');
            autoModContainer.classList.add('flex');
        }
        if (tabAutoModBtn) tabAutoModBtn.className = activeBtnClass;
        window.loadAutoModAlarms();
    }
};

function showReportsView() {
    currentView = 'reports';
    showView('reportsView');
    updateMenuActiveState('reports');
    window.switchReportsTab(reportsCurrentTab || 'complaints');
}

function showSettingsView() {
    currentView = 'settings';
    showView('settingsView');
    updateMenuActiveState('settings');
    loadDealSharingStatus();
    loadCommentSharingStatus();
    loadNotificationLimits();
    loadAdminList();
    loadTeknosaAffiliateStatus();
    loadHepsiburadaAffiliateStatus();
    loadAmazonAffiliateStatus();
    loadIncehesapAffiliateStatus();
}

function loadReports() {
    console.log('📋 Loading reports...');
    if (reportsUnsubscribe) {
        reportsUnsubscribe();
    }

    const reportsTableBody = document.getElementById('reportsTableBody');
    if (reportsTableBody) {
        reportsTableBody.innerHTML = `
            <tr>
                <td colspan="8" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
                    <div class="flex flex-col items-center gap-2">
                        <span class="material-symbols-outlined text-4xl animate-spin">sync</span>
                        <p>Şikayetler yükleniyor...</p>
                    </div>
                </td>
            </tr>
        `;
    }

    reportsUnsubscribe = db.collection('reports')
        .orderBy('createdAt', 'desc')
        .limit(100)
        .onSnapshot((snapshot) => {
            reports = [];
            let pendingCount = 0;
            let actionCount = 0;
            let dismissedCount = 0;

            snapshot.forEach((doc) => {
                const data = doc.data();
                const status = data.status || 'pending';
                if (status === 'pending') pendingCount++;
                else if (status === 'action_taken') actionCount++;
                else if (status === 'dismissed') dismissedCount++;

                reports.push({
                    id: doc.id,
                    reportedId: data.reportedId || '',
                    reportedBy: data.reportedBy || '',
                    type: data.type || 'unknown',
                    reason: data.reason || 'Sebep belirtilmemiş',
                    description: data.description || '',
                    targetDealId: data.targetDealId || null,
                    targetContent: data.targetContent || null,
                    targetAuthor: data.targetAuthor || null,
                    targetAuthorId: data.targetAuthorId || null,
                    status: status,
                    actionType: data.actionType || null,
                    actionNote: data.actionNote || null,
                    createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt || Date.now())
                });
            });

            console.log(`✅ Loaded ${reports.length} reports`);

            // İstatistik sayaçlarını güncelle
            const totalEl = document.getElementById('reportsTotalCount');
            const pendingEl = document.getElementById('reportsPendingCount');
            const actionEl = document.getElementById('reportsActionCount');
            const dismissedEl = document.getElementById('reportsDismissedCount');
            const subtitleEl = document.getElementById('reportsSubtitleCount');

            if (totalEl) totalEl.textContent = reports.length;
            if (pendingEl) pendingEl.textContent = pendingCount;
            if (actionEl) actionEl.textContent = actionCount;
            if (dismissedEl) dismissedEl.textContent = dismissedCount;
            if (subtitleEl) subtitleEl.textContent = `Toplam ${reports.length} şikayet listeleniyor (${pendingCount} inceleme bekleyen)`;

            renderReports();
        }, (error) => {
            console.error('❌ Error loading reports:', error);
            if (reportsTableBody) {
                reportsTableBody.innerHTML = `
                    <tr>
                        <td colspan="8" class="px-6 py-12 text-center text-red-500">
                            <p>Şikayetler yüklenirken hata oluştu: ${escapeHtml(error.message)}</p>
                        </td>
                    </tr>
                `;
            }
        });
}

window.loadReports = loadReports;

window.filterReports = function() {
    renderReports();
};

window.setReportsStatusFilter = function(status) {
    reportsFilterStatus = status;
    const allBtn = document.getElementById('reportsFilterStatusAllBtn');
    const pendingBtn = document.getElementById('reportsFilterStatusPendingBtn');
    const actionBtn = document.getElementById('reportsFilterStatusActionBtn');
    const dismissedBtn = document.getElementById('reportsFilterStatusDismissedBtn');

    const defaultClass = 'px-3 py-1.5 text-xs font-semibold rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:text-white transition-colors cursor-pointer';
    const activeClass = 'px-3 py-1.5 text-xs font-bold rounded-lg bg-primary text-white transition-colors cursor-pointer';

    if (allBtn) allBtn.className = status === 'all' ? activeClass : defaultClass;
    if (pendingBtn) pendingBtn.className = status === 'pending' ? activeClass : defaultClass;
    if (actionBtn) actionBtn.className = status === 'action_taken' ? activeClass : defaultClass;
    if (dismissedBtn) dismissedBtn.className = status === 'dismissed' ? activeClass : defaultClass;

    renderReports();
};

window.setReportsTypeFilter = function(type) {
    reportsFilterType = type;
    const allBtn = document.getElementById('reportsFilterTypeAllBtn');
    const dealsBtn = document.getElementById('reportsFilterTypeDealsBtn');
    const commentsBtn = document.getElementById('reportsFilterTypeCommentsBtn');
    const usersBtn = document.getElementById('reportsFilterTypeUsersBtn');
    const messagesBtn = document.getElementById('reportsFilterTypeMessagesBtn');

    const defaultClass = 'px-2.5 py-1 text-xs font-semibold rounded-lg bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-400 hover:text-white transition-colors cursor-pointer';
    const activeClass = 'px-2.5 py-1 text-xs font-bold rounded-lg bg-slate-800 dark:bg-slate-200 text-white dark:text-slate-900 transition-colors cursor-pointer';

    if (allBtn) allBtn.className = type === 'all' ? activeClass : defaultClass;
    if (dealsBtn) dealsBtn.className = type === 'deal' ? activeClass : defaultClass;
    if (commentsBtn) commentsBtn.className = type === 'comment' ? activeClass : defaultClass;
    if (usersBtn) usersBtn.className = type === 'user' ? activeClass : defaultClass;
    if (messagesBtn) messagesBtn.className = type === 'message' ? activeClass : defaultClass;

    renderReports();
};

function renderReports() {
    const reportsTableBody = document.getElementById('reportsTableBody');
    if (!reportsTableBody) return;

    const searchTerm = (document.getElementById('reportsSearchInput')?.value || '').trim().toLowerCase();

    const filtered = reports.filter(report => {
        // Status filter
        if (reportsFilterStatus !== 'all' && report.status !== reportsFilterStatus) {
            return false;
        }

        // Type filter
        if (reportsFilterType !== 'all' && report.type !== reportsFilterType) {
            return false;
        }

        // Search filter
        if (searchTerm) {
            const matchesId = (report.id || '').toLowerCase().includes(searchTerm);
            const matchesReportedId = (report.reportedId || '').toLowerCase().includes(searchTerm);
            const matchesReporter = (report.reportedBy || '').toLowerCase().includes(searchTerm);
            const matchesReason = (report.reason || '').toLowerCase().includes(searchTerm);
            const matchesDesc = (report.description || '').toLowerCase().includes(searchTerm);
            const matchesContent = (report.targetContent || '').toLowerCase().includes(searchTerm);
            const matchesAuthor = (report.targetAuthor || '').toLowerCase().includes(searchTerm);
            const matchesAuthorId = (report.targetAuthorId || '').toLowerCase().includes(searchTerm);

            return matchesId || matchesReportedId || matchesReporter || matchesReason || matchesDesc || matchesContent || matchesAuthor || matchesAuthorId;
        }

        return true;
    });

    if (filtered.length === 0) {
        reportsTableBody.innerHTML = `
            <tr>
                <td colspan="8" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
                    <div class="flex flex-col items-center gap-2">
                        <span class="material-symbols-outlined text-4xl opacity-50">report_off</span>
                        <p>Kriterlere uygun şikayet kaydı bulunamadı</p>
                    </div>
                </td>
            </tr>
        `;
        return;
    }

    reportsTableBody.innerHTML = filtered.map(report => {
        const reportDate = new Date(report.createdAt);
        const formattedDate = reportDate.toLocaleDateString('tr-TR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });

        let typeLabel = 'Diğer';
        let typeColor = 'text-slate-600 dark:text-slate-400';
        let typeIcon = 'report';
        if (report.type === 'deal') {
            typeLabel = 'Fırsat';
            typeColor = 'text-amber-600 dark:text-amber-400';
            typeIcon = 'local_offer';
        } else if (report.type === 'comment') {
            typeLabel = 'Yorum';
            typeColor = 'text-blue-600 dark:text-blue-400';
            typeIcon = 'comment';
        } else if (report.type === 'user') {
            typeLabel = 'Kullanıcı';
            typeColor = 'text-purple-600 dark:text-purple-400';
            typeIcon = 'person';
        } else if (report.type === 'message') {
            typeLabel = 'Mesaj';
            typeColor = 'text-emerald-600 dark:text-emerald-400';
            typeIcon = 'chat_bubble';
        }

        let statusBadge = '';
        if (report.status === 'pending') {
            statusBadge = '<span class="px-2.5 py-1 bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 rounded-full text-xs font-semibold">Bekliyor</span>';
        } else if (report.status === 'dismissed') {
            statusBadge = '<span class="px-2.5 py-1 bg-slate-100 dark:bg-slate-800 text-slate-500 rounded-full text-xs font-semibold">Yoksayıldı</span>';
        } else if (report.status === 'action_taken') {
            statusBadge = '<span class="px-2.5 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 rounded-full text-xs font-semibold">İşlem Yapıldı</span>';
        } else {
            statusBadge = `<span class="px-2.5 py-1 bg-slate-100 dark:bg-slate-800 text-slate-500 rounded-full text-xs font-semibold">${escapeHtml(report.status)}</span>`;
        }

        const isPending = report.status === 'pending';
        const actionsHtml = isPending ? `
            <div class="flex items-center justify-end gap-1.5">
                <button onclick="window.inspectReportedContent('${report.id}', '${report.type}', '${report.reportedId}')" class="px-2.5 py-1.5 rounded-lg bg-blue-500/10 hover:bg-blue-500/20 text-blue-600 dark:text-blue-400 transition-colors flex items-center gap-1 text-xs font-semibold cursor-pointer" title="İncele">
                    <span class="material-symbols-outlined text-[16px]">visibility</span>
                    İncele
                </button>
                <button onclick="window.takeActionOnReport('${report.id}', '${report.type}', '${report.reportedId}')" class="px-2.5 py-1.5 rounded-lg bg-red-500/10 hover:bg-red-500/20 text-red-600 dark:text-red-400 transition-colors flex items-center gap-1 text-xs font-semibold cursor-pointer" title="İşlem Yap">
                    <span class="material-symbols-outlined text-[16px]">bolt</span>
                    İşlem Yap
                </button>
                <button onclick="window.dismissReport('${report.id}')" class="p-1.5 rounded-lg text-slate-400 hover:text-slate-700 dark:hover:text-slate-200 transition-colors cursor-pointer" title="Yoksay">
                    <span class="material-symbols-outlined text-[18px]">close</span>
                </button>
            </div>
        ` : `
            <div class="flex items-center justify-end gap-2">
                <button onclick="window.inspectReportedContent('${report.id}', '${report.type}', '${report.reportedId}')" class="p-1 text-slate-400 hover:text-primary transition-colors cursor-pointer" title="İncele">
                    <span class="material-symbols-outlined text-[18px]">visibility</span>
                </button>
                <span class="text-xs text-slate-400 font-medium italic">Kapalı</span>
            </div>
        `;

        return `
            <tr class="hover:bg-slate-50 dark:hover:bg-slate-900/20 transition-colors">
                <td class="px-6 py-4 whitespace-nowrap text-slate-500 dark:text-slate-400 text-xs">${formattedDate}</td>
                <td class="px-6 py-4 whitespace-nowrap">
                    <span class="flex items-center gap-1.5 ${typeColor} font-bold text-xs">
                        <span class="material-symbols-outlined text-[15px]">${typeIcon}</span>
                        ${typeLabel}
                    </span>
                </td>
                <td class="px-6 py-4 text-slate-900 dark:text-white font-mono text-xs">#${escapeHtml(report.reportedId.substring(0, 8))}...</td>
                <td class="px-6 py-4 text-slate-900 dark:text-white font-semibold text-xs">${escapeHtml(report.reason)}</td>
                <td class="px-6 py-4 text-slate-500 dark:text-slate-400 max-w-xs truncate text-xs" title="${escapeHtml(report.description)}">${escapeHtml(report.description || '-')}</td>
                <td class="px-6 py-4 text-slate-500 dark:text-slate-400 font-mono text-xs">#${escapeHtml(report.reportedBy.substring(0, 6))}...</td>
                <td class="px-6 py-4 whitespace-nowrap">${statusBadge}</td>
                <td class="px-6 py-4 whitespace-nowrap text-right">${actionsHtml}</td>
            </tr>
        `;
    }).join('');
}

async function findCommentAndParent(commentId, targetDealId) {
    try {
        if (targetDealId) {
            const doc = await db.collection('deals').doc(targetDealId).collection('comments').doc(commentId).get();
            if (doc.exists) {
                const data = doc.data();
                return {
                    id: doc.id,
                    content: data.text || data.content || '',
                    userId: data.userId || '',
                    userName: data.userName || 'Bilinmeyen Kullanıcı',
                    dealId: targetDealId,
                    ref: doc.ref,
                    createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt || Date.now())
                };
            }
        }

        if (typeof deals !== 'undefined' && Array.isArray(deals)) {
            for (let i = 0; i < deals.length; i++) {
                const dId = deals[i].id;
                try {
                    const doc = await db.collection('deals').doc(dId).collection('comments').doc(commentId).get();
                    if (doc.exists) {
                        const data = doc.data();
                        return {
                            id: doc.id,
                            content: data.text || data.content || '',
                            userId: data.userId || '',
                            userName: data.userName || 'Bilinmeyen Kullanıcı',
                            dealId: dId,
                            ref: doc.ref,
                            createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt || Date.now())
                        };
                    }
                } catch (_) {}
            }
        }

        const snapshot = await db.collectionGroup('comments').get();
        let found = null;
        snapshot.forEach(doc => {
            if (doc.id === commentId) {
                const data = doc.data();
                const parentDealId = doc.ref.parent && doc.ref.parent.parent ? doc.ref.parent.parent.id : '';
                found = {
                    id: doc.id,
                    content: data.text || data.content || '',
                    userId: data.userId || '',
                    userName: data.userName || 'Bilinmeyen Kullanıcı',
                    dealId: parentDealId,
                    ref: doc.ref,
                    createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt || Date.now())
                };
            }
        });
        return found;
    } catch (e) {
        console.error('❌ Error finding comment:', e);
        return null;
    }
}

window.closeReportDetailModal = function () {
    const modal = document.getElementById('reportDetailModal');
    if (modal) modal.classList.add('hidden');
    const warnBtn = document.getElementById('reportDetailWarnUserBtn');
    if (warnBtn) {
        warnBtn.classList.add('hidden');
        warnBtn.style.display = 'none';
    }
};

window.closeReportActionModal = function () {
    const modal = document.getElementById('reportActionModal');
    if (modal) modal.classList.add('hidden');
    currentReportUnderAction = null;
    currentReportActionOptions = [];
};

window.inspectReportedContent = async function (reportId, type, reportedId) {
    try {
        const report = reports.find(r => r.id === reportId) || { id: reportId, type, reportedId, status: 'pending' };
        const modal = document.getElementById('reportDetailModal');
        const modalTitle = document.getElementById('reportDetailModalTitle');
        const modalSubtitle = document.getElementById('reportDetailModalSubtitle');
        const modalBody = document.getElementById('reportDetailModalBody');
        const typeIconContainer = document.getElementById('reportDetailTypeIcon');
        const statusBadgeContainer = document.getElementById('reportDetailStatusBadge');
        const dismissBtn = document.getElementById('reportDetailDismissBtn');
        const actionBtn = document.getElementById('reportDetailActionBtn');
        const warnBtn = document.getElementById('reportDetailWarnUserBtn');

        if (!modal || !modalBody) {
            console.error('❌ Report detail modal not found');
            return;
        }

        let typeLabel = 'İçerik';
        let typeIcon = 'report';
        let iconBgClass = 'bg-slate-500/10 text-slate-600';
        if (type === 'deal') {
            typeLabel = 'Fırsat';
            typeIcon = 'local_offer';
            iconBgClass = 'bg-amber-500/10 text-amber-600';
        } else if (type === 'comment') {
            typeLabel = 'Yorum';
            typeIcon = 'comment';
            iconBgClass = 'bg-blue-500/10 text-blue-600';
        } else if (type === 'message') {
            typeLabel = 'Mesaj';
            typeIcon = 'chat_bubble';
            iconBgClass = 'bg-emerald-500/10 text-emerald-600';
        } else if (type === 'user') {
            typeLabel = 'Kullanıcı';
            typeIcon = 'person';
            iconBgClass = 'bg-purple-500/10 text-purple-600';
        }

        if (typeIconContainer) {
            typeIconContainer.className = `w-10 h-10 rounded-xl ${iconBgClass} flex items-center justify-center`;
            typeIconContainer.innerHTML = `<span class="material-symbols-outlined text-[22px]">${typeIcon}</span>`;
        }

        if (modalTitle) modalTitle.textContent = `${typeLabel} Şikayeti İnceleme`;
        if (modalSubtitle) modalSubtitle.textContent = `Şikayet ID: #${report.id.substring(0, 12)}...`;

        if (statusBadgeContainer) {
            if (report.status === 'pending') {
                statusBadgeContainer.innerHTML = '<span class="px-2 py-0.5 bg-amber-100 dark:bg-amber-900/30 text-amber-700 dark:text-amber-400 rounded-full text-xs font-semibold">Bekliyor</span>';
            } else if (report.status === 'action_taken') {
                statusBadgeContainer.innerHTML = '<span class="px-2 py-0.5 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 rounded-full text-xs font-semibold">İşlem Yapıldı</span>';
            } else {
                statusBadgeContainer.innerHTML = '<span class="px-2 py-0.5 bg-slate-100 dark:bg-slate-800 text-slate-500 rounded-full text-xs font-semibold">Yoksayıldı</span>';
            }
        }

        // Action button bindings
        if (dismissBtn) {
            dismissBtn.onclick = () => {
                closeReportDetailModal();
                dismissReport(reportId);
            };
            dismissBtn.style.display = report.status === 'pending' ? 'flex' : 'none';
        }
        if (actionBtn) {
            actionBtn.onclick = () => {
                closeReportDetailModal();
                takeActionOnReport(reportId, type, reportedId);
            };
            actionBtn.style.display = report.status === 'pending' ? 'flex' : 'none';
        }

        modalBody.innerHTML = `
            <div class="flex items-center justify-center py-12">
                <span class="material-symbols-outlined text-3xl animate-spin text-primary">sync</span>
                <span class="ml-3 text-slate-500 text-sm font-medium">Şikayet ve içerik detayları yükleniyor...</span>
            </div>
        `;
        modal.classList.remove('hidden');

        // Fetch reported item
        let contentHtml = '';
        let targetAuthorUserId = null;
        let targetAuthorUserName = null;

        if (type === 'comment') {
            const comment = await findCommentAndParent(reportedId, report.targetDealId);
            let dealInfo = null;
            if (comment && comment.dealId) {
                const dealDoc = await db.collection('deals').doc(comment.dealId).get();
                if (dealDoc.exists) dealInfo = { id: dealDoc.id, ...dealDoc.data() };
            }

            const commentText = comment ? comment.content : (report.targetContent || 'İçerik veritabanında bulunamadı (silinmiş olabilir).');
            const authorName = comment ? comment.userName : (report.targetAuthor || 'Bilinmeyen Kullanıcı');
            const authorId = comment ? comment.userId : (report.targetAuthorId || '-');
            targetAuthorUserId = authorId !== '-' ? authorId : null;
            targetAuthorUserName = authorName;

            contentHtml = `
                <div class="bg-blue-50/50 dark:bg-blue-900/10 border border-blue-200/60 dark:border-blue-800/40 rounded-xl p-4">
                    <div class="flex items-center justify-between mb-3">
                        <div class="flex items-center gap-2.5">
                            <div class="w-8 h-8 rounded-full bg-blue-500 text-white flex items-center justify-center font-bold text-xs">
                                ${escapeHtml(authorName.charAt(0).toUpperCase())}
                            </div>
                            <div>
                                <h4 class="font-bold text-slate-900 dark:text-white text-sm">${escapeHtml(authorName)}</h4>
                                <p class="text-[11px] text-slate-500 font-mono">UID: ${escapeHtml(authorId)}</p>
                            </div>
                        </div>
                        <span class="px-2 py-1 bg-blue-100 dark:bg-blue-900/40 text-blue-700 dark:text-blue-300 rounded-lg text-xs font-semibold">Yorum</span>
                    </div>
                    <div class="bg-white dark:bg-surface-darker p-3.5 rounded-lg border border-slate-200/60 dark:border-slate-800 text-slate-800 dark:text-slate-200 text-sm italic">
                        "${escapeHtml(commentText)}"
                    </div>
                    ${dealInfo ? `
                        <div class="mt-3 pt-3 border-t border-blue-200/40 dark:border-blue-800/30 flex items-center justify-between">
                            <div class="flex items-center gap-2.5 min-w-0">
                                <img src="${dealInfo.imageUrl || ''}" class="w-9 h-9 rounded-lg object-cover bg-slate-200 dark:bg-slate-700 flex-shrink-0" onerror="this.onerror=null; this.src='https://placehold.co/100?text=Firsat'">
                                <div class="min-w-0">
                                    <p class="text-xs font-bold text-slate-900 dark:text-white truncate">${escapeHtml(dealInfo.title || 'Fırsat')}</p>
                                    <p class="text-[11px] text-slate-500">${escapeHtml(dealInfo.store || '')} • ${dealInfo.price ? dealInfo.price + ' TL' : ''}</p>
                                </div>
                            </div>
                            <button onclick="showDealDetail('${dealInfo.id}')" class="px-3 py-1.5 bg-white dark:bg-surface-dark border border-slate-200 dark:border-slate-700 hover:border-primary text-xs font-bold text-slate-700 dark:text-slate-300 rounded-lg transition-colors flex-shrink-0">
                                Fırsatı Aç
                            </button>
                        </div>
                    ` : ''}
                </div>
            `;
        } else if (type === 'message') {
            const doc = await db.collection('messages').doc(reportedId).get();
            let msgData = doc.exists ? doc.data() : null;
            const messageText = msgData ? (msgData.text || '') : (report.targetContent || 'Mesaj veritabanında bulunamadı.');
            const senderName = msgData ? (msgData.senderName || msgData.senderId) : (report.targetAuthor || 'Gönderen');
            const receiverName = msgData ? (msgData.receiverName || msgData.receiverId) : 'Alıcı';
            targetAuthorUserId = msgData ? msgData.senderId : (report.targetAuthorId || null);
            targetAuthorUserName = senderName;

            contentHtml = `
                <div class="bg-emerald-50/50 dark:bg-emerald-900/10 border border-emerald-200/60 dark:border-emerald-800/40 rounded-xl p-4">
                    <div class="flex items-center justify-between mb-3">
                        <div class="flex items-center gap-2">
                            <span class="material-symbols-outlined text-emerald-600 text-base">forum</span>
                            <span class="text-xs font-bold text-slate-700 dark:text-slate-300">
                                <strong>${escapeHtml(senderName)}</strong> ➔ <strong>${escapeHtml(receiverName)}</strong>
                            </span>
                        </div>
                        <span class="px-2 py-1 bg-emerald-100 dark:bg-emerald-900/40 text-emerald-700 dark:text-emerald-300 rounded-lg text-xs font-semibold">Özel Mesaj</span>
                    </div>
                    <div class="bg-white dark:bg-surface-darker p-4 rounded-xl border border-slate-200/60 dark:border-slate-800 space-y-2">
                        <div class="p-3 bg-emerald-500/10 border border-emerald-500/20 rounded-lg text-slate-900 dark:text-white text-sm font-medium">
                            "${escapeHtml(messageText)}"
                        </div>
                        ${msgData && msgData.dealTitle ? `
                            <div class="p-2.5 bg-slate-50 dark:bg-slate-900 rounded-lg border border-slate-200 dark:border-slate-800 flex items-center gap-3">
                                <img src="${msgData.dealImageUrl || ''}" class="w-8 h-8 rounded object-cover flex-shrink-0" onerror="this.onerror=null; this.src='https://placehold.co/100?text=Firsat'">
                                <div class="min-w-0">
                                    <p class="text-xs font-bold text-slate-900 dark:text-white truncate">${escapeHtml(msgData.dealTitle)}</p>
                                    <p class="text-[11px] text-primary font-semibold">${msgData.dealPrice ? msgData.dealPrice + ' TL' : ''}</p>
                                </div>
                            </div>
                        ` : ''}
                    </div>
                </div>
            `;
        } else if (type === 'deal') {
            let deal = deals.find(d => d.id === reportedId);
            if (!deal) {
                const doc = await db.collection('deals').doc(reportedId).get();
                if (doc.exists) deal = { id: doc.id, ...doc.data() };
            }

            if (deal) {
                targetAuthorUserId = deal.postedBy || null;
                targetAuthorUserName = deal.postedByName || 'Fırsat Sahibi';

                contentHtml = `
                    <div class="bg-amber-50/50 dark:bg-amber-900/10 border border-amber-200/60 dark:border-amber-800/40 rounded-xl p-4">
                        <div class="flex items-start gap-3.5">
                            <img src="${deal.imageUrl || ''}" class="w-16 h-16 rounded-xl object-cover bg-slate-200 dark:bg-slate-700 flex-shrink-0" onerror="this.onerror=null; this.src='https://placehold.co/100?text=Firsat'">
                            <div class="min-w-0 flex-1">
                                <div class="flex items-center gap-2 mb-1">
                                    <span class="px-2 py-0.5 bg-amber-500/20 text-amber-700 dark:text-amber-400 rounded text-[11px] font-bold">${escapeHtml(deal.store || 'Mağaza')}</span>
                                    <span class="text-xs font-semibold text-slate-500">${deal.category || ''}</span>
                                </div>
                                <h4 class="font-bold text-slate-900 dark:text-white text-sm line-clamp-2">${escapeHtml(deal.title || 'Başlıksız Fırsat')}</h4>
                                <div class="flex items-center gap-3 mt-1.5">
                                    <span class="text-sm font-black text-primary">${deal.price ? deal.price + ' TL' : 'Fiyatsız'}</span>
                                    <span class="text-xs text-slate-400">🔥 ${deal.hotVotes || 0} / ❄️ ${deal.coldVotes || 0}</span>
                                </div>
                            </div>
                        </div>
                        <div class="mt-3 pt-3 border-t border-amber-200/40 dark:border-amber-800/30 flex justify-end">
                            <button onclick="showDealDetail('${deal.id}')" class="px-3 py-1.5 bg-primary hover:bg-primary/90 text-white rounded-lg text-xs font-bold transition-colors flex items-center gap-1">
                                <span class="material-symbols-outlined text-[16px]">edit</span>
                                Fırsat Detayını / Düzenleme Panelini Aç
                            </button>
                        </div>
                    </div>
                `;
            } else {
                contentHtml = `
                    <div class="p-4 bg-slate-100 dark:bg-slate-800 rounded-xl text-slate-500 text-sm text-center">
                        Bu fırsat veritabanında bulunamadı (silinmiş olabilir).
                    </div>
                `;
            }
        } else if (type === 'user') {
            let user = users.find(u => (u.uid || u.id) === reportedId);
            if (!user) {
                const doc = await db.collection('users').doc(reportedId).get();
                if (doc.exists) user = { id: doc.id, uid: doc.id, ...doc.data() };
            }

            if (user) {
                const displayName = user.nickname || user.username || 'Bilinmeyen Kullanıcı';
                targetAuthorUserId = user.uid || user.id;
                targetAuthorUserName = displayName;

                contentHtml = `
                    <div class="bg-purple-50/50 dark:bg-purple-900/10 border border-purple-200/60 dark:border-purple-800/40 rounded-xl p-4">
                        <div class="flex items-center gap-3">
                            <img src="${user.profileImageUrl || ''}" class="w-12 h-12 rounded-full object-cover bg-slate-200 dark:bg-slate-700 flex-shrink-0" onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=135bec&color=fff&size=128'">
                            <div class="min-w-0 flex-1">
                                <h4 class="font-bold text-slate-900 dark:text-white text-base">${escapeHtml(displayName)}</h4>
                                <p class="text-xs text-slate-500">${escapeHtml(user.email || 'E-posta yok')} • UID: <span class="font-mono">${escapeHtml(user.uid || user.id)}</span></p>
                                <div class="flex items-center gap-3 mt-1 text-xs text-slate-600 dark:text-slate-400">
                                    <span>🌟 <strong>${user.points || 0}</strong> puan</span>
                                    <span>🏷️ <strong>${user.dealCount || 0}</strong> fırsat</span>
                                </div>
                            </div>
                        </div>
                        <div class="mt-3 pt-3 border-t border-purple-200/40 dark:border-purple-800/30 flex justify-end">
                            <button onclick="showUserDetail('${user.uid || user.id}')" class="px-3 py-1.5 bg-purple-600 hover:bg-purple-700 text-white rounded-lg text-xs font-bold transition-colors flex items-center gap-1">
                                <span class="material-symbols-outlined text-[16px]">account_circle</span>
                                Kullanıcı Profil Sayfasını Aç
                            </button>
                        </div>
                    </div>
                `;
            } else {
                contentHtml = `
                    <div class="p-4 bg-slate-100 dark:bg-slate-800 rounded-xl text-slate-500 text-sm text-center">
                        Bu kullanıcı hesabı bulunamadı (silinmiş olabilir).
                    </div>
                `;
            }
        }

        // Setup warning button
        if (warnBtn) {
            if (targetAuthorUserId && targetAuthorUserId !== 'botkolik' && targetAuthorUserId !== '-') {
                warnBtn.classList.remove('hidden');
                warnBtn.style.display = 'flex';
                warnBtn.onclick = () => {
                    closeReportDetailModal();
                    window.showAdminMessageModal(targetAuthorUserId, targetAuthorUserName || 'Kullanıcı');
                };
            } else {
                warnBtn.classList.add('hidden');
                warnBtn.style.display = 'none';
            }
        }

        modalBody.innerHTML = `
            <!-- Şikayet Özeti -->
            <div class="bg-slate-50 dark:bg-slate-900/50 rounded-xl p-4 border border-slate-200 dark:border-slate-800 space-y-2.5">
                <div class="flex items-center justify-between">
                    <span class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400">Şikayet Nedeni</span>
                    <span class="px-2.5 py-0.5 bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 rounded-full text-xs font-bold">${escapeHtml(report.reason)}</span>
                </div>
                ${report.description ? `
                    <div class="text-xs text-slate-700 dark:text-slate-300 bg-white dark:bg-surface-darker p-3 rounded-lg border border-slate-200/70 dark:border-slate-800">
                        <strong class="text-slate-900 dark:text-white">Ek Açıklama:</strong> "${escapeHtml(report.description)}"
                    </div>
                ` : ''}
                <div class="flex items-center justify-between text-[11px] text-slate-500 pt-1">
                    <span>Raporlayan UID: <span class="font-mono">#${escapeHtml(report.reportedBy)}</span></span>
                    <span>Tarih: ${new Date(report.createdAt).toLocaleString('tr-TR')}</span>
                </div>
            </div>

            <!-- Raporlanan İçerik Kartı -->
            <div>
                <h4 class="text-xs font-bold uppercase tracking-wider text-slate-500 dark:text-slate-400 mb-2">Şikayet Edilen İçerik Detayı</h4>
                ${contentHtml}
            </div>
        `;
    } catch (err) {
        console.error('❌ Inspection error:', err);
        showError('İçerik incelenirken hata oluştu: ' + err.message);
    }
};

window.dismissReport = async function (reportId) {
    if (!confirm('Bu şikayeti yoksaymak (kapatmak) istediğinize emin misiniz?')) {
        return;
    }
    try {
        showLoadingIndicator(true);
        await db.collection('reports').doc(reportId).update({
            status: 'dismissed',
            resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        showLoadingIndicator(false);
        showSuccess('Şikayet yoksayıldı ve kapatıldı.');
    } catch (err) {
        showLoadingIndicator(false);
        console.error('❌ Error dismissing report:', err);
        showError('Şikayet kapatılırken hata oluştu: ' + err.message);
    }
};

window.takeActionOnReport = async function (reportId, type, reportedId) {
    try {
        const report = reports.find(r => r.id === reportId) || { id: reportId, type, reportedId, reason: 'Belirtilmemiş' };
        currentReportUnderAction = { reportId, type, reportedId, report };

        const actionModal = document.getElementById('reportActionModal');
        const summaryContainer = document.getElementById('reportActionSummary');
        const optionsContainer = document.getElementById('reportActionOptionsList');
        const noteInput = document.getElementById('reportActionNote');

        if (!actionModal || !optionsContainer) {
            console.error('❌ Report action modal elements not found');
            return;
        }

        if (noteInput) noteInput.value = '';

        let typeLabel = 'Fırsat';
        let typeIcon = 'local_offer';
        if (type === 'comment') {
            typeLabel = 'Yorum';
            typeIcon = 'comment';
        } else if (type === 'message') {
            typeLabel = 'Mesaj';
            typeIcon = 'chat_bubble';
        } else if (type === 'user') {
            typeLabel = 'Kullanıcı';
            typeIcon = 'person';
        }

        if (summaryContainer) {
            summaryContainer.innerHTML = `
                <div class="w-8 h-8 rounded-lg bg-red-500/10 text-red-600 flex items-center justify-center flex-shrink-0">
                    <span class="material-symbols-outlined text-[18px]">${typeIcon}</span>
                </div>
                <div class="min-w-0 flex-1">
                    <p class="font-bold text-slate-900 dark:text-white">${typeLabel} Şikayeti (#${escapeHtml(reportedId.substring(0, 10))}...)</p>
                    <p class="text-slate-500 text-[11px] truncate">Sebep: ${escapeHtml(report.reason)}</p>
                </div>
            `;
        }

        let options = [];

        if (type === 'deal') {
            options = [
                {
                    id: 'expire_deal',
                    icon: 'timer_off',
                    title: 'Fırsatı Yayından Kaldır (Süresi Dolan Yap)',
                    desc: 'Fırsat silinmez, feed akışından kaldırılıp süresi dolmuş olarak işaretlenir.',
                    isDanger: false,
                    action: async (note) => {
                        await db.collection('deals').doc(reportedId).update({
                            isExpired: true,
                            status: 'expired',
                            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
                        });
                        return 'Fırsat yayından kaldırıldı (süresi doldu yapıldı).';
                    }
                },
                {
                    id: 'delete_deal',
                    icon: 'delete_forever',
                    title: 'Fırsatı Veritabanından Kalıcı Olarak Sil',
                    desc: 'Fırsat Firestore veritabanından tamamen silinir.',
                    isDanger: true,
                    action: async (note) => {
                        await db.collection('deals').doc(reportedId).delete();
                        return 'Fırsat veritabanından tamamen silindi.';
                    }
                },
                {
                    id: 'ban_deal_poster',
                    icon: 'block',
                    title: 'Paylaşan Kullanıcının Fırsat Paylaşmasını Engelle',
                    desc: 'Kullanıcının yeni fırsat eklemesi engellenir.',
                    isDanger: true,
                    action: async (note) => {
                        const dealDoc = await db.collection('deals').doc(reportedId).get();
                        const posterId = dealDoc.exists ? dealDoc.data().postedBy : null;
                        if (posterId && posterId !== 'botkolik') {
                            await db.collection('dealBannedUsers').doc(posterId).set({
                                userId: posterId,
                                bannedAt: firebase.firestore.FieldValue.serverTimestamp(),
                                reason: note || 'Şikayet edilen fırsat paylaşımı sebebiyle engellendi'
                            });
                            return 'Kullanıcının fırsat paylaşması engellendi.';
                        }
                        return 'Fırsat sahibi için işlem yapıldı.';
                    }
                },
                {
                    id: 'resolve_only',
                    icon: 'check_circle',
                    title: 'Sadece Şikayeti "Çözüldü" Olarak Kapat',
                    desc: 'İçeriğe dokunulmaz, şikayet işlemi incelenip tamamlandı olarak işaretlenir.',
                    isDanger: false,
                    action: async (note) => {
                        return 'Şikayet çözüldü olarak kapatıldı.';
                    }
                }
            ];
        } else if (type === 'comment') {
            options = [
                {
                    id: 'delete_comment',
                    icon: 'delete_sweep',
                    title: 'Yorumu Kalıcı Olarak Sil ve Sayacı Düşür',
                    desc: 'Yorum dokümanı silinir ve fırsatın yorum sayacı 1 azaltılır.',
                    isDanger: true,
                    action: async (note) => {
                        const comment = await findCommentAndParent(reportedId, report.targetDealId);
                        if (comment && comment.ref) {
                            await comment.ref.delete();
                            if (comment.dealId) {
                                await db.collection('deals').doc(comment.dealId).update({
                                    commentCount: firebase.firestore.FieldValue.increment(-1)
                                });
                            }
                            return 'Yorum başarıyla silindi ve fırsatın yorum sayacı güncellendi.';
                        }
                        return 'Yorum silme işlemi tamamlandı.';
                    }
                },
                {
                    id: 'ban_commenter',
                    icon: 'speaker_notes_off',
                    title: 'Yazarın Yeni Yorum Yapmasını Yasakla',
                    desc: 'Kullanıcının yorum ekleme yetkisi elinden alınır.',
                    isDanger: true,
                    action: async (note) => {
                        const comment = await findCommentAndParent(reportedId, report.targetDealId);
                        const userId = comment ? comment.userId : (report.targetAuthorId || null);
                        if (userId) {
                            await db.collection('commentBannedUsers').doc(userId).set({
                                userId: userId,
                                bannedAt: firebase.firestore.FieldValue.serverTimestamp(),
                                reason: note || 'Uygunsuz yorum şikayeti sebebiyle engellendi'
                            });
                            return 'Kullanıcının yorum yazması engellendi.';
                        }
                        throw new Error('Yorum yazarı bilgisine ulaşılamadı.');
                    }
                },
                {
                    id: 'ban_user_full',
                    icon: 'person_off',
                    title: 'Yazarı Tamamen Engelle (Sisteme Girişini Yasakla)',
                    desc: 'Kullanıcı hesabı tamamen bloke edilir.',
                    isDanger: true,
                    action: async (note) => {
                        const comment = await findCommentAndParent(reportedId, report.targetDealId);
                        const userId = comment ? comment.userId : (report.targetAuthorId || null);
                        if (userId) {
                            await db.collection('blockedUsers').doc(userId).set({
                                userId: userId,
                                blockedAt: firebase.firestore.FieldValue.serverTimestamp(),
                                reason: note || 'Yorum şikayeti nedeniyle hesap engellendi'
                            });
                            return 'Kullanıcı hesabı tamamen engellendi.';
                        }
                        throw new Error('Kullanıcı ID bilgisine ulaşılamadı.');
                    }
                },
                {
                    id: 'resolve_only',
                    icon: 'check_circle',
                    title: 'Sadece Şikayeti "Çözüldü" Olarak Kapat',
                    desc: 'Yorum silinmez, şikayet işlemi tamamlandı olarak kapatılır.',
                    isDanger: false,
                    action: async (note) => {
                        return 'Şikayet çözüldü olarak kapatıldı.';
                    }
                }
            ];
        } else if (type === 'message') {
            options = [
                {
                    id: 'delete_message',
                    icon: 'delete_outline',
                    title: 'Mesajı Veritabanından Kalıcı Olarak Sil',
                    desc: 'Şikayet edilen mesaj Firestore koleksiyonundan tamamen silinir.',
                    isDanger: true,
                    action: async (note) => {
                        await db.collection('messages').doc(reportedId).delete();
                        return 'Mesaj veritabanından kalıcı olarak silindi.';
                    }
                },
                {
                    id: 'ban_sender',
                    icon: 'person_off',
                    title: 'Mesajı Gönderen Kullanıcıyı Engelle',
                    desc: 'Kural dışı mesaj gönderen kullanıcının sisteme girişi tamamen engellenir.',
                    isDanger: true,
                    action: async (note) => {
                        const msgDoc = await db.collection('messages').doc(reportedId).get();
                        const senderId = msgDoc.exists ? msgDoc.data().senderId : (report.targetAuthorId || null);
                        if (senderId && senderId !== 'botkolik') {
                            await db.collection('blockedUsers').doc(senderId).set({
                                userId: senderId,
                                blockedAt: firebase.firestore.FieldValue.serverTimestamp(),
                                reason: note || 'Uygunsuz özel mesaj şikayeti nedeniyle engellendi'
                            });
                            return 'Mesajı gönderen kullanıcı tamamen engellendi.';
                        }
                        return 'Gönderen kullanıcı için işlem yapıldı.';
                    }
                },
                {
                    id: 'resolve_only',
                    icon: 'check_circle',
                    title: 'Sadece Şikayeti "Çözüldü" Olarak Kapat',
                    desc: 'Mesaja dokunulmaz, şikayet çözüldü olarak işaretlenir.',
                    isDanger: false,
                    action: async (note) => {
                        return 'Şikayet çözüldü olarak kapatıldı.';
                    }
                }
            ];
        } else if (type === 'user') {
            options = [
                {
                    id: 'ban_user_full',
                    icon: 'person_off',
                    title: 'Kullanıcıyı Tamamen Engelle (Sisteme Girişini Yasakla)',
                    desc: 'Kullanıcının uygulamaya girişi tamamen engellenir.',
                    isDanger: true,
                    action: async (note) => {
                        await db.collection('blockedUsers').doc(reportedId).set({
                            userId: reportedId,
                            blockedAt: firebase.firestore.FieldValue.serverTimestamp(),
                            reason: note || 'Kullanıcı şikayeti üzerine engellendi'
                        });
                        return 'Kullanıcı sisteme giriş engel listesine eklendi.';
                    }
                },
                {
                    id: 'ban_user_deals',
                    icon: 'local_offer',
                    title: 'Kullanıcının Fırsat Paylaşmasını Engelle',
                    desc: 'Kullanıcının yeni fırsat paylaşması yasaklanır.',
                    isDanger: true,
                    action: async (note) => {
                        await db.collection('dealBannedUsers').doc(reportedId).set({
                            userId: reportedId,
                            bannedAt: firebase.firestore.FieldValue.serverTimestamp(),
                            reason: note || 'Kullanıcı şikayeti üzerine fırsat paylaşımı engellendi'
                        });
                        return 'Kullanıcının fırsat paylaşması engellendi.';
                    }
                },
                {
                    id: 'ban_user_comments',
                    icon: 'comment',
                    title: 'Kullanıcının Yorum Yapmasını Engelle',
                    desc: 'Kullanıcının yorum eklemesi yasaklanır.',
                    isDanger: true,
                    action: async (note) => {
                        await db.collection('commentBannedUsers').doc(reportedId).set({
                            userId: reportedId,
                            bannedAt: firebase.firestore.FieldValue.serverTimestamp(),
                            reason: note || 'Kullanıcı şikayeti üzerine yorum yapması engellendi'
                        });
                        return 'Kullanıcının yorum yapması engellendi.';
                    }
                },
                {
                    id: 'resolve_only',
                    icon: 'check_circle',
                    title: 'Sadece Şikayeti "Çözüldü" Olarak Kapat',
                    desc: 'Kullanıcıya yaptırım uygulanmaz, şikayet kapatılır.',
                    isDanger: false,
                    action: async (note) => {
                        return 'Şikayet çözüldü olarak kapatıldı.';
                    }
                }
            ];
        } else {
            options = [
                {
                    id: 'resolve_only',
                    icon: 'check_circle',
                    title: 'Şikayeti "Çözüldü" Olarak Kapat',
                    desc: 'Şikayet incelenip kapatılır.',
                    isDanger: false,
                    action: async (note) => {
                        return 'Şikayet kapatıldı.';
                    }
                }
            ];
        }

        currentReportActionOptions = options;

        optionsContainer.innerHTML = options.map((opt, idx) => `
            <label class="flex items-start gap-3 p-3.5 rounded-xl border border-slate-200 dark:border-slate-800 hover:border-primary/50 dark:hover:border-primary/50 bg-white dark:bg-surface-darker cursor-pointer transition-all ${idx === 0 ? 'ring-2 ring-primary/20 border-primary' : ''}">
                <input type="radio" name="reportActionOption" value="${opt.id}" ${idx === 0 ? 'checked' : ''} class="mt-1 text-primary focus:ring-primary h-4 w-4">
                <div class="min-w-0 flex-1">
                    <div class="flex items-center gap-1.5">
                        <span class="material-symbols-outlined text-[18px] ${opt.isDanger ? 'text-red-500' : 'text-primary'}">${opt.icon}</span>
                        <p class="text-xs font-bold ${opt.isDanger ? 'text-red-600 dark:text-red-400' : 'text-slate-900 dark:text-white'}">${escapeHtml(opt.title)}</p>
                    </div>
                    <p class="text-[11px] text-slate-500 dark:text-slate-400 mt-0.5">${escapeHtml(opt.desc)}</p>
                </div>
            </label>
        `).join('');

        actionModal.classList.remove('hidden');
    } catch (err) {
        console.error('❌ Error opening action modal:', err);
        showError('Aksiyon penceresi açılırken hata oluştu: ' + err.message);
    }
};

window.executeSelectedReportAction = async function () {
    if (!currentReportUnderAction || !currentReportActionOptions) return;

    const selectedRadio = document.querySelector('input[name="reportActionOption"]:checked');
    if (!selectedRadio) {
        showError('Lütfen bir işlem seçiniz!');
        return;
    }

    const selectedOptionId = selectedRadio.value;
    const selectedOpt = currentReportActionOptions.find(o => o.id === selectedOptionId);
    if (!selectedOpt) {
        showError('Geçersiz işlem seçimi!');
        return;
    }

    const noteInput = document.getElementById('reportActionNote');
    const adminNote = noteInput ? noteInput.value.trim() : '';
    const confirmBtn = document.getElementById('reportActionConfirmBtn');

    try {
        if (confirmBtn) {
            confirmBtn.disabled = true;
            confirmBtn.innerHTML = '<span class="material-symbols-outlined text-[18px] animate-spin">sync</span> Uygulanıyor...';
        }

        console.log(`🚀 Executing action "${selectedOptionId}" for report ${currentReportUnderAction.reportId}`);
        const resultMsg = await selectedOpt.action(adminNote);

        await db.collection('reports').doc(currentReportUnderAction.reportId).update({
            status: 'action_taken',
            actionType: selectedOptionId,
            actionNote: adminNote,
            resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });

        closeReportActionModal();
        closeReportDetailModal();

        showSuccess(`İşlem Başarılı: ${resultMsg}`);
    } catch (err) {
        console.error('❌ Action execution error:', err);
        showError('İşlem uygulanırken hata oluştu: ' + err.message);
    } finally {
        if (confirmBtn) {
            confirmBtn.disabled = false;
            confirmBtn.innerHTML = '<span class="material-symbols-outlined text-[18px]">check</span> İşlemi Uygula';
        }
    }
};

function showLoadingIndicator(show) {
    if (loadingIndicator) {
        loadingIndicator.style.display = show ? 'block' : 'none';
    }
}

window.showReportsView = showReportsView;
window.showSettingsView = showSettingsView;
window.showDashboardView = showDashboardView;

// Environment badge initialization
function initEnvironmentBadge() {
    const envBadge = document.getElementById('envBadge');
    const envBadgeMobile = document.getElementById('envBadgeMobile');
    const isProd = firebaseConfig.projectId === 'firsatkolik-prod-e6eae';
    
    // Check if we are running locally (localhost or 127.0.0.1)
    const isLocal = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1';

    const badgeText = isProd ? 'PROD' : 'DEV';
    const badgeClass = isProd
        ? 'inline-flex items-center px-2 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider bg-red-500 text-white shadow-[0_0_10px_rgba(239,68,68,0.5)] border border-red-400'
        : 'inline-flex items-center px-2 py-0.5 rounded text-[10px] font-extrabold uppercase tracking-wider bg-amber-500 text-slate-900 shadow-[0_0_10px_rgba(245,158,11,0.5)] border border-amber-400';

    if (isLocal) {
        // Create interactive select element instead of a static badge
        const createSwitcherHTML = (id, extraClass = '') => {
            const selectClass = isProd
                ? 'bg-red-600 text-white border-red-500 focus:ring-red-400 shadow-[0_0_8px_rgba(220,38,38,0.4)]'
                : 'bg-amber-500 text-slate-950 border-amber-500 focus:ring-amber-400 shadow-[0_0_8px_rgba(245,158,11,0.4)]';
            
            return `
                <select id="${id}" class="block rounded text-[10px] font-black uppercase tracking-wider px-2 py-0.5 border-none focus:outline-none focus:ring-2 cursor-pointer transition-colors ${selectClass} ${extraClass}">
                    <option value="dev" ${!isProd ? 'selected' : ''} class="bg-slate-900 text-white">DEV ⚙️</option>
                    <option value="prod" ${isProd ? 'selected' : ''} class="bg-slate-900 text-white">PROD 🚀</option>
                </select>
            `;
        };

        const handleEnvChange = (e) => {
            const newEnv = e.target.value;
            console.log(`🌐 Switching local environment to: ${newEnv.toUpperCase()}`);
            localStorage.setItem('firebase_env', newEnv);
            // Reload page to re-initialize firebase config
            window.location.reload();
        };

        if (envBadge) {
            envBadge.outerHTML = createSwitcherHTML('envSwitcher');
            const switcher = document.getElementById('envSwitcher');
            if (switcher) {
                switcher.addEventListener('change', handleEnvChange);
            }
        }

        if (envBadgeMobile) {
            envBadgeMobile.outerHTML = createSwitcherHTML('envSwitcherMobile', 'animate-pulse');
            const switcherMobile = document.getElementById('envSwitcherMobile');
            if (switcherMobile) {
                switcherMobile.addEventListener('change', handleEnvChange);
            }
        }
    } else {
        // Deployed environment: show static badges as normal
        if (envBadge) {
            envBadge.textContent = badgeText;
            envBadge.className = badgeClass;
            envBadge.classList.remove('hidden');
        }
        if (envBadgeMobile) {
            envBadgeMobile.textContent = badgeText;
            envBadgeMobile.className = badgeClass + ' animate-pulse';
            envBadgeMobile.classList.remove('hidden');
        }
    }
}

// Initialize Environment-specific shortcut links for cards and headings
function initCardLinks() {
    const projectId = firebaseConfig.projectId;
    
    // Clean up existing dynamically injected links first to prevent duplication
    document.querySelectorAll('.card-shortcut-menu').forEach(el => el.remove());
    
    // Helper to create a dropdown list if a card has multiple links
    const createDropdownLinkEl = (links, buttonTitle = 'Manuel Kontroller') => {
        const id = 'menu-' + Math.random().toString(36).substr(2, 9);
        const listItems = links.map(lnk => `
            <li>
                <a href="${lnk.url}" target="_blank" class="flex items-center gap-2 px-3 py-2 text-xs text-slate-700 hover:bg-slate-100 dark:text-slate-300 dark:hover:bg-slate-800 dark:hover:text-white rounded-md transition-colors" onclick="event.stopPropagation(); window.closeShortcutDropdowns();">
                    <span class="material-symbols-outlined text-[15px] align-middle">${lnk.icon || 'open_in_new'}</span>
                    <span class="align-middle">${lnk.title}</span>
                </a>
            </li>
        `).join('');
        
        return `
            <div class="relative card-shortcut-menu inline-block" onclick="event.stopPropagation();">
                <button onclick="
                    const menu = document.getElementById('${id}');
                    const wasHidden = menu.classList.contains('hidden');
                    
                    // Close all dropdowns and reset their parent overflows first
                    document.querySelectorAll('.card-shortcut-dropdown').forEach(m => {
                        m.classList.add('hidden');
                        const pc = m.closest('.group');
                        if (pc) pc.style.overflow = '';
                    });
                    
                    if (wasHidden) {
                        menu.classList.remove('hidden');
                        const pc = menu.closest('.group');
                        if (pc) pc.style.overflow = 'visible';
                    } else {
                        menu.classList.add('hidden');
                        const pc = menu.closest('.group');
                        if (pc) pc.style.overflow = '';
                    }
                " class="w-6 h-6 rounded-full bg-slate-100 dark:bg-slate-800 hover:bg-slate-200 dark:hover:bg-slate-700 text-slate-400 hover:text-slate-700 dark:text-slate-400 dark:hover:text-white flex items-center justify-center transition-all shadow-sm border border-slate-200 dark:border-slate-700/60" title="${buttonTitle}">
                    <span class="material-symbols-outlined text-[13px]">link</span>
                </button>
                <div id="${id}" class="card-shortcut-dropdown hidden absolute right-0 mt-1 w-56 rounded-lg bg-white dark:bg-surface-dark border border-slate-200 dark:border-slate-700 shadow-xl z-[9999] py-1.5 animate-fadeIn">
                    <div class="px-3 py-1 text-[9px] font-black text-slate-400 dark:text-slate-500 uppercase tracking-wider border-b border-slate-100 dark:border-slate-800/50 mb-1">
                        ${buttonTitle}
                    </div>
                    <ul class="flex flex-col gap-0.5 px-1">
                        ${listItems}
                    </ul>
                </div>
            </div>
        `;
    };

    // Function to inject menu into card or heading
    const injectMenu = (targetElement, menuHtml, position = 'append') => {
        if (!targetElement) return;
        const wrapper = document.createElement('div');
        wrapper.className = 'card-shortcut-menu flex items-center shrink-0';
        wrapper.innerHTML = menuHtml;
        
        if (position === 'append') {
            targetElement.appendChild(wrapper);
        } else if (position === 'prepend') {
            targetElement.insertBefore(wrapper, targetElement.firstChild);
        }
    };

    const injectH3Dropdown = (headingText, links, title) => {
        const headings = document.querySelectorAll('h3');
        for (const h of headings) {
            if (h.textContent && h.textContent.includes(headingText)) {
                injectMenu(h, createDropdownLinkEl(links, title));
                break;
            }
        }
    };

    // Close all menus when clicking outside
    document.removeEventListener('click', window.closeShortcutDropdowns);
    window.closeShortcutDropdowns = () => {
        document.querySelectorAll('.card-shortcut-dropdown').forEach(menu => {
            menu.classList.add('hidden');
            const pc = menu.closest('.group');
            if (pc) pc.style.overflow = '';
        });
    };
    document.addEventListener('click', window.closeShortcutDropdowns);

    // -------------------------------------------------------------
    // Define Links based on environment
    // -------------------------------------------------------------
    const firebaseBaseUrl = `https://console.firebase.google.com/project/${projectId}`;
    const gcpBaseUrl = `https://console.cloud.google.com`;
    
    // 1. Users Links
    const userLinks = [
        { title: 'Firebase Auth Kullanıcıları', url: `${firebaseBaseUrl}/authentication/users`, icon: 'how_to_reg' },
        { title: 'Firestore "users" Koleksiyonu', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fusers`, icon: 'database' }
    ];

    // 2. Deals Links
    const dealLinks = [
        { title: 'Firestore "deals" Koleksiyonu', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fdeals`, icon: 'database' }
    ];

    // 3. Comments Links
    const commentLinks = [
        { title: 'Firestore "deals" Alt Yorumları', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fdeals`, icon: 'chat' }
    ];

    // 4. Bot Links
    const botLinks = [
        { title: 'Cloud Run Bot Panel', url: `${gcpBaseUrl}/run/detail/us-central1/telegram-bot/metrics?project=${projectId}`, icon: 'analytics' },
        { title: 'Cloud Run Bot Canlı Loglar', url: `${gcpBaseUrl}/run/detail/us-central1/telegram-bot/logs?project=${projectId}`, icon: 'list' },
        { title: 'Firestore "telegramBot" Ayarı', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fsettings~2FtelegramBot`, icon: 'settings' }
    ];

    // 5. AI Links
    const aiLinks = [
        { title: 'GCP Credentials (API Key)', url: `${gcpBaseUrl}/apis/credentials?project=${projectId}`, icon: 'vpn_key' },
        { title: 'Google AI Studio', url: 'https://aistudio.google.com/app/apikey', icon: 'psychology' },
        { title: 'Firestore "geminiStatus" Ayarı', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fsettings~2FgeminiStatus`, icon: 'settings' }
    ];

    // 6. Messages Links
    const messageLinks = [
        { title: 'Firestore "adminMessages" (İletişim)', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2FadminMessages`, icon: 'database' },
        { title: 'Firestore "adminToUserMessages" (Destek)', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2FadminToUserMessages`, icon: 'database' }
    ];

    // 7. System Errors (Logs) Links
    const logLinks = [
        { title: 'Firestore "systemErrors" Günlüğü', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2FsystemErrors`, icon: 'bug_report' },
        { title: 'Google Cloud Logging Konsolu', url: `${gcpBaseUrl}/logs/query?project=${projectId}`, icon: 'list' }
    ];

    // 8. Notifications Links
    const notificationLinks = [
        { title: 'Firestore "notificationLogs" Koleksiyonu', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2FnotificationLogs`, icon: 'database' },
        { title: 'Firestore "notificationStats" İstatistikleri', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2FnotificationStats`, icon: 'bar_chart' },
        { title: 'Firebase Cloud Messaging Konsolu', url: `${firebaseBaseUrl}/messaging`, icon: 'campaign' },
        { title: 'Cloud Functions Listesi', url: `${firebaseBaseUrl}/functions/list`, icon: 'settings_input_component' }
    ];

    // 9. Ayarlar Links
    const settingsLinks = [
        { title: 'Firestore "app" Ayarı', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fsettings~2Fapp`, icon: 'settings' },
        { title: 'Firestore "telegramBot" Ayarı', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fsettings~2FtelegramBot`, icon: 'settings' },
        { title: 'Firestore "geminiStatus" Ayarı', url: `${firebaseBaseUrl}/firestore/databases/-default-/data/~2Fsettings~2FgeminiStatus`, icon: 'settings' }
    ];

    // -------------------------------------------------------------
    // Injections to Dashboard Cards
    // -------------------------------------------------------------
    
    injectH3Dropdown('Manuel Bildirim Gönder', notificationLinks, 'Bildirim Kaynakları');
    injectH3Dropdown('FCM Token Temizliği', notificationLinks, 'Bildirim Kaynakları');
}

// Safe alias for deal detail modal (backwards compatibility)
window.openDealEditModal = function(dealId) {
    if (typeof window.showDealDetail === 'function') {
        window.showDealDetail(dealId);
    }
};

// Category normalization helper for FırsatKolik canonical taxonomy
function normalizeCategory(rawCat) {
    if (!rawCat || typeof rawCat !== 'string') return { key: 'diger', title: 'Diğer' };
    const cleaned = rawCat.trim().toLowerCase()
        .replace(/ç/g, 'c')
        .replace(/ğ/g, 'g')
        .replace(/ı/g, 'i')
        .replace(/ö/g, 'o')
        .replace(/ş/g, 's')
        .replace(/ü/g, 'u');

    if (cleaned.includes('elektronik')) return { key: 'elektronik', title: 'Elektronik' };
    if (cleaned.includes('moda') || cleaned.includes('giyim')) return { key: 'moda', title: 'Moda & Giyim' };
    if (cleaned.includes('ev') || cleaned.includes('yasam')) return { key: 'ev_yasam', title: 'Ev & Yaşam' };
    if (cleaned.includes('anne') || cleaned.includes('bebek')) return { key: 'anne_bebek', title: 'Anne & Bebek' };
    if (cleaned.includes('kozmetik') || cleaned.includes('bakim')) return { key: 'kozmetik', title: 'Kozmetik & Bakım' };
    if (cleaned.includes('spor') || cleaned.includes('outdoor')) return { key: 'spor_outdoor', title: 'Spor & Outdoor' };
    if (cleaned.includes('supermarket') || cleaned.includes('market')) return { key: 'supermarket', title: 'Süpermarket' };
    if (cleaned.includes('yapi') || cleaned.includes('oto')) return { key: 'yapi_oto', title: 'Yapı Market & Oto' };
    if (cleaned.includes('kitap') || cleaned.includes('hobi')) return { key: 'kitap_hobi', title: 'Kitap & Hobi' };
    if (cleaned.includes('oyun') || cleaned.includes('dijital')) return { key: 'oyun', title: 'Oyun & Dijital' };
    return { key: 'diger', title: 'Diğer' };
}

// FırsatKolik Avcı Kademe Seviyesi & Rozeti (gamification)
function getHunterLevelTitle(pts) {
    const p = Number(pts) || 0;
    if (p < 20) return { title: 'Çaylak Avcı', badgeClass: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 border-slate-200 dark:border-slate-700' };
    if (p < 50) return { title: 'Çırak Avcı', badgeClass: 'bg-emerald-50 text-emerald-700 dark:bg-emerald-950/40 dark:text-emerald-300 border-emerald-200 dark:border-emerald-800' };
    if (p < 120) return { title: 'Usta Avcı', badgeClass: 'bg-blue-50 text-blue-700 dark:bg-blue-950/40 dark:text-blue-300 border-blue-200 dark:border-blue-800' };
    if (p < 250) return { title: 'Uzman Avcı', badgeClass: 'bg-purple-50 text-purple-700 dark:bg-purple-950/40 dark:text-purple-300 border-purple-200 dark:border-purple-800' };
    if (p < 500) return { title: 'Kıdemli Avcı', badgeClass: 'bg-amber-50 text-amber-700 dark:bg-amber-950/40 dark:text-amber-300 border-amber-200 dark:border-amber-800' };
    if (p < 1000) return { title: 'Şef Avcı', badgeClass: 'bg-orange-50 text-orange-700 dark:bg-orange-950/40 dark:text-orange-300 border-orange-200 dark:border-orange-800' };
    if (p < 2500) return { title: 'Büyük Avcı', badgeClass: 'bg-rose-50 text-rose-700 dark:bg-rose-950/40 dark:text-rose-300 border-rose-200 dark:border-rose-800' };
    if (p < 5000) return { title: 'Efsanevi Avcı', badgeClass: 'bg-yellow-50 text-yellow-800 dark:bg-yellow-950/40 dark:text-yellow-300 border-yellow-300 dark:border-yellow-700' };
    return { title: 'Mitolojik Avcı', badgeClass: 'bg-gradient-to-r from-amber-500/20 to-purple-500/20 text-purple-700 dark:text-purple-300 border-purple-400' };
}

// Load executive dashboard data from Firestore count queries and in-memory caches
async function loadDashboardData() {
    try {
        console.log('📊 Loading executive dashboard data across all platform pillars...');

        const refreshBtn = document.getElementById('refreshDashboardBtn');
        const refreshIcon = refreshBtn ? refreshBtn.querySelector('.material-symbols-outlined') : null;
        if (refreshIcon) refreshIcon.classList.add('animate-spin');

        // 0. Environment Badge & Text
        const envBadge = document.getElementById('dashEnvBadge');
        const envText = document.getElementById('dashEnvText');
        const currentEnv = typeof selectedEnv !== 'undefined' ? selectedEnv : (localStorage.getItem('firebase_env') || 'dev');
        const projectId = (typeof firebaseConfig !== 'undefined' && firebaseConfig.projectId) ? firebaseConfig.projectId : (currentEnv === 'prod' ? 'firsatkolik-prod-e6eae' : 'sicak-firsatlar-e6eae');
        
        if (envBadge && envText) {
            if (currentEnv === 'prod') {
                envBadge.className = 'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border border-emerald-300 dark:border-emerald-800/80 bg-emerald-50 dark:bg-emerald-950/40 text-emerald-800 dark:text-emerald-300 shadow-2xs';
                envBadge.innerHTML = `<span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span><span>PRODUCTION (${projectId})</span>`;
            } else {
                envBadge.className = 'inline-flex items-center gap-1.5 px-3 py-1 rounded-full text-xs font-bold border border-amber-300 dark:border-amber-800/80 bg-amber-50 dark:bg-amber-950/40 text-amber-800 dark:text-amber-300 shadow-2xs';
                envBadge.innerHTML = `<span class="w-2 h-2 rounded-full bg-amber-500 animate-pulse"></span><span>DEV (${projectId})</span>`;
            }
        }

        const todayMidnight = new Date();
        todayMidnight.setHours(0, 0, 0, 0);

        const todayStr = `${todayMidnight.getFullYear()}-${String(todayMidnight.getMonth() + 1).padStart(2, '0')}-${String(todayMidnight.getDate()).padStart(2, '0')}`;

        // Helper to parse dates safely
        const parseDate = (val) => {
            if (!val) return null;
            if (val.toDate && typeof val.toDate === 'function') return val.toDate();
            if (val instanceof Date) return val;
            try {
                const d = new Date(val);
                return isNaN(d.getTime()) ? null : d;
            } catch (_) {
                return null;
            }
        };

        // Parallel fetch for Pillar 2-6
        const [
            couponsSnapResult,
            catalogsSnapResult,
            reportsSnapResult,
            systemErrorsSnapResult,
            userDevicesSnapResult,
            notifStatsSnapResult,
            notifConfigSnapResult,
            topUsersSnapResult,
            todayCommentsSnapResult
        ] = await Promise.allSettled([
            // 1. Coupons
            db.collection('kuponlar').get(),
            // 2. Catalogs
            db.collection('kataloglar').get(),
            // 3. Reports (pending)
            db.collection('reports').where('status', '==', 'pending').get(),
            // 4. System Errors (unresolved)
            db.collection('systemErrors').where('status', '==', 'unresolved').get(),
            // 5. User Devices
            db.collection('userDevices').get(),
            // 6. Notification Stats for today
            db.collection('notificationStats').doc(todayStr).get(),
            // 7. System notification config
            db.collection('systemConfig').doc('notifications').get(),
            // 8. Top 10 Users for Leaderboard (filter system accounts)
            db.collection('users').orderBy('points', 'desc').limit(10).get(),
            // 9. Today's comments
            db.collectionGroup('comments').where('createdAt', '>=', todayMidnight).get()
        ]);

        // --- PILLAR 1: FIRSATLAR (DEALS) ---
        const totalDeals = deals ? deals.length : 0;
        let todayDealsCount = 0;
        let todayApprovedCount = 0;
        let todayRejectedCount = 0;
        let pendingDealsCount = 0;
        let totalApprovalTimeMs = 0;
        let approvalCountWithTime = 0;
        const pendingDealsList = [];

        // Fırsat Kaynak Dağılımı (Topluluk vs Otonom Bot)
        let communityDealsCount = 0;
        let botDealsCount = 0;

        if (deals && deals.length > 0) {
            deals.forEach(d => {
                const cDate = parseDate(d.createdAt || d.timestamp);
                if (cDate && cDate >= todayMidnight) {
                    todayDealsCount++;
                }

                // Community vs Bot counter
                if (d.isUserSubmitted === true) {
                    communityDealsCount++;
                } else {
                    botDealsCount++;
                }

                const isPending = (d.isApproved === false && d.isRejected !== true && d.isExpired !== true && d.status !== 'expired' && d.status !== 'rejected');
                if (isPending) {
                    pendingDealsCount++;
                    if (pendingDealsList.length < 5) {
                        pendingDealsList.push(d);
                    }
                }

                // Approved today
                if (d.isApproved === true) {
                    const aDate = parseDate(d.approvedAt || d.updatedAt);
                    if (aDate && aDate >= todayMidnight) {
                        todayApprovedCount++;
                        if (cDate) {
                            const diff = aDate.getTime() - cDate.getTime();
                            if (diff >= 0) {
                                totalApprovalTimeMs += diff;
                                approvalCountWithTime++;
                            }
                        }
                    }
                }

                // Rejected today
                if (d.isRejected === true || d.status === 'rejected') {
                    const rDate = parseDate(d.updatedAt || d.rejectedAt);
                    if (rDate && rDate >= todayMidnight) {
                        todayRejectedCount++;
                    }
                }
            });
        }

        let avgApprovalTimeStr = '-';
        if (approvalCountWithTime > 0) {
            const avgMinutes = Math.round((totalApprovalTimeMs / approvalCountWithTime) / 60000);
            if (avgMinutes < 60) {
                avgApprovalTimeStr = `${avgMinutes} dk`;
            } else {
                const avgHours = Math.floor(avgMinutes / 60);
                const remMinutes = avgMinutes % 60;
                avgApprovalTimeStr = `${avgHours} sa ${remMinutes} dk`;
            }
        }

        const elTotalDeals = document.getElementById('dashTotalDeals');
        if (elTotalDeals) elTotalDeals.textContent = totalDeals;

        const elTodayDeals = document.getElementById('dashTodayDeals');
        if (elTodayDeals) elTodayDeals.textContent = todayDealsCount;

        const elPendingDeals = document.getElementById('dashPendingDeals');
        if (elPendingDeals) elPendingDeals.textContent = pendingDealsCount;

        const elAvgApproval = document.getElementById('dashAvgApprovalTime');
        if (elAvgApproval) elAvgApproval.textContent = avgApprovalTimeStr;

        // Render Quick Pending Deals Table
        const pendingTbody = document.getElementById('dashPendingDealsBody');
        if (pendingTbody) {
            if (pendingDealsList.length === 0) {
                pendingTbody.innerHTML = `<tr><td colspan="3" class="py-6 text-center text-slate-400 dark:text-slate-500">Onay bekleyen fırsat bulunmuyor 🎉</td></tr>`;
            } else {
                let phtml = '';
                pendingDealsList.forEach(deal => {
                    const priceFormatted = deal.price ? `${deal.price} TL` : 'Ücretsiz';
                    phtml += `
                        <tr class="hover:bg-slate-50 dark:hover:bg-surface-darker/50 transition-colors">
                            <td class="py-2.5 pr-2 max-w-[170px] truncate" title="${escapeHtml(deal.title)}">
                                <a href="javascript:void(0)" onclick="window.showDealDetail('${deal.id}')" class="font-semibold text-slate-800 dark:text-slate-200 hover:text-primary transition-colors block truncate">
                                    ${escapeHtml(deal.title)}
                                </a>
                                <span class="text-[10px] text-slate-400 block">${deal.isUserSubmitted ? 'Topluluk' : 'Telegram Bot'}</span>
                            </td>
                            <td class="py-2.5 pr-2 whitespace-nowrap font-bold text-slate-900 dark:text-white">
                                ${priceFormatted}
                            </td>
                            <td class="py-2.5 text-right whitespace-nowrap">
                                <button type="button" onclick="window.showDealDetail('${deal.id}')" class="px-2 py-1 rounded bg-primary/10 text-primary hover:bg-primary/20 text-[10px] font-bold transition-colors cursor-pointer">
                                    İncele
                                </button>
                            </td>
                        </tr>
                    `;
                });
                pendingTbody.innerHTML = phtml;
            }
        }

        // Fırsat Kaynak Dağılımı (Topluluk vs Otonom Bot Radarı)
        const communityPct = totalDeals > 0 ? Math.round((communityDealsCount / totalDeals) * 100) : 0;
        const botPct = totalDeals > 0 ? (100 - communityPct) : 0;

        const elCommCount = document.getElementById('dashCommunityDealsCount');
        if (elCommCount) elCommCount.textContent = `${communityDealsCount} Fırsat`;
        const elCommPct = document.getElementById('dashCommunityDealsPct');
        if (elCommPct) elCommPct.textContent = `%${communityPct}`;
        const elBotCount = document.getElementById('dashBotDealsCount');
        if (elBotCount) elBotCount.textContent = `${botDealsCount} Fırsat`;
        const elBotPct = document.getElementById('dashBotDealsPct');
        if (elBotPct) elBotPct.textContent = `%${botPct}`;
        const elCommBar = document.getElementById('dashCommunityProgressBar');
        if (elCommBar) elCommBar.style.width = `${communityPct}%`;
        const elBotBar = document.getElementById('dashBotProgressBar');
        if (elBotBar) elBotBar.style.width = `${botPct}%`;
        const elCommBadge = document.getElementById('dashCommunityBadge');
        if (elCommBadge) elCommBadge.textContent = `Topluluk: %${communityPct}`;

        // --- PILLAR 2: İNDİRİM KUPONLARI (COUPONS) ---
        let totalCoupons = 0;
        let activeCoupons = 0;
        let todayCoupons = 0;

        if (couponsSnapResult.status === 'fulfilled' && couponsSnapResult.value) {
            const snap = couponsSnapResult.value;
            totalCoupons = snap.size;
            snap.forEach(doc => {
                const d = doc.data();
                const expDate = parseDate(d.sonKullanimTarihi || d.bitisTarihi);
                if (!expDate || expDate >= new Date()) {
                    activeCoupons++;
                }
                const cDate = parseDate(d.olusturulmaTarihi || d.createdAt);
                if (cDate && cDate >= todayMidnight) {
                    todayCoupons++;
                }
            });
        }
        const elTotalCoupons = document.getElementById('dashTotalCoupons');
        if (elTotalCoupons) elTotalCoupons.textContent = totalCoupons;
        const elActiveCoupons = document.getElementById('dashActiveCoupons');
        if (elActiveCoupons) elActiveCoupons.textContent = activeCoupons;
        const elTodayCoupons = document.getElementById('dashTodayCoupons');
        if (elTodayCoupons) elTodayCoupons.textContent = todayCoupons;
        const elRadarCoupons = document.getElementById('dashRadarCouponsTotal');
        if (elRadarCoupons) elRadarCoupons.textContent = `${totalCoupons} Kupon`;

        // --- PILLAR 3: AKTÜEL KATALOGLAR (BROCHURES) ---
        let totalCatalogs = 0;
        let activeCatalogs = 0;

        if (catalogsSnapResult.status === 'fulfilled' && catalogsSnapResult.value) {
            const snap = catalogsSnapResult.value;
            totalCatalogs = snap.size;
            snap.forEach(doc => {
                const d = doc.data();
                const endDate = parseDate(d.bitisTarihi);
                if (!endDate || endDate >= todayMidnight) {
                    activeCatalogs++;
                }
            });
        }
        const elTotalCatalogs = document.getElementById('dashTotalCatalogs');
        if (elTotalCatalogs) elTotalCatalogs.textContent = totalCatalogs;
        const elActiveCatalogs = document.getElementById('dashActiveCatalogs');
        if (elActiveCatalogs) elActiveCatalogs.textContent = activeCatalogs;
        const elRadarCatalogs = document.getElementById('dashRadarCatalogsTotal');
        if (elRadarCatalogs) elRadarCatalogs.textContent = `${totalCatalogs} Broşür`;

        // --- PILLAR 4: TOPLULUK & AVCI GAMIFICATION ---
        const totalUsers = users ? users.length : 0;
        let todayNewUsers = 0;
        if (users && users.length > 0) {
            todayNewUsers = users.filter(u => {
                const d = parseDate(u.createdAt);
                return d && d >= todayMidnight;
            }).length;
        }
        const elTotalUsers = document.getElementById('dashTotalUsers');
        if (elTotalUsers) elTotalUsers.textContent = totalUsers;
        const elTodayNewUsers = document.getElementById('dashTodayNewUsers');
        if (elTodayNewUsers) elTodayNewUsers.textContent = todayNewUsers;

        // Today's comments count
        let todayComments = 0;
        if (todayCommentsSnapResult.status === 'fulfilled' && todayCommentsSnapResult.value) {
            todayComments = todayCommentsSnapResult.value.size;
        } else {
            if (deals) {
                todayComments = deals.filter(d => {
                    const c = parseDate(d.createdAt);
                    return c && c >= todayMidnight;
                }).reduce((sum, d) => sum + (d.commentCount || 0), 0);
            }
        }
        const elTodayComments = document.getElementById('dashTodayComments');
        if (elTodayComments) elTodayComments.textContent = todayComments;

        // Render Leaderboard (Top 5 Avcı - Filter out bot/system accounts)
        const leaderboardBody = document.getElementById('dashLeaderboardBody');
        if (leaderboardBody) {
            let lhtml = '';
            let rawDocs = [];
            if (topUsersSnapResult.status === 'fulfilled' && !topUsersSnapResult.value.empty) {
                rawDocs = topUsersSnapResult.value.docs.map(d => ({ id: d.id, ...d.data() }));
            } else if (users && users.length > 0) {
                rawDocs = [...users];
            }

            const isBotAccount = (u) => {
                if (!u) return true;
                const uid = (u.uid || u.id || '').toLowerCase();
                const name = (u.nickname || u.username || '').toLowerCase();
                if (uid === 'bot' || uid === 'botkolik' || uid.startsWith('telegram_')) return true;
                if (name === 'bot' || name === 'botkolik' || name.startsWith('telegram')) return true;
                if (!u.nickname && !u.username && !u.email) return true;
                return false;
            };

            const topDocs = rawDocs.filter(u => !isBotAccount(u)).slice(0, 5);

            if (topDocs.length > 0) {
                topDocs.forEach((u, idx) => {
                    const name = u.nickname || u.username || 'Avcı';
                    const pts = u.points || 0;
                    const avatar = cleanProfileImageUrl(u.profileImageUrl) || `https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=135bec&color=fff&size=32`;
                    const medal = idx === 0 ? '🥇' : (idx === 1 ? '🥈' : (idx === 2 ? '🥉' : `${idx + 1}`));
                    const hunterLevel = getHunterLevelTitle(pts);
                    lhtml += `
                        <tr class="hover:bg-slate-50 dark:hover:bg-surface-darker/50 transition-colors cursor-pointer group" onclick="showUsersView('${escapeHtml(name)}')">
                            <td class="py-2.5 font-bold text-slate-500 w-6">${medal}</td>
                            <td class="py-2.5">
                                <div class="flex items-center gap-2 min-w-0">
                                    <img src="${avatar}" alt="" class="w-7 h-7 rounded-full object-cover shrink-0 border border-slate-200 dark:border-slate-700" onerror="this.onerror=null; this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(name)}&background=135bec&color=fff&size=32'">
                                    <div class="flex flex-col min-w-0">
                                        <span class="font-semibold text-slate-800 dark:text-slate-200 truncate text-xs group-hover:text-primary transition-colors" title="${escapeHtml(name)}">${escapeHtml(name)}</span>
                                        <span class="text-[9px] font-bold px-1.5 py-0.2 rounded border inline-block w-fit mt-0.5 ${hunterLevel.badgeClass}">${hunterLevel.title}</span>
                                    </div>
                                </div>
                            </td>
                            <td class="py-2.5 text-right font-black text-primary text-xs whitespace-nowrap">${pts.toLocaleString('tr-TR')} P</td>
                        </tr>
                    `;
                });
            } else {
                lhtml = `<tr><td colspan="3" class="py-6 text-center text-slate-400">Henüz puan kaydı yok</td></tr>`;
            }
            leaderboardBody.innerHTML = lhtml;
        }

        // --- PILLAR 5: BİLDİRİM & CİHAZ ALTYAPISI ---
        let totalActiveDevices = 0;
        let androidCount = 0;
        let iosCount = 0;

        if (userDevicesSnapResult.status === 'fulfilled' && userDevicesSnapResult.value) {
            userDevicesSnapResult.value.forEach(doc => {
                const data = doc.data();
                if (data.active === true) {
                    totalActiveDevices++;
                }
                if (data.platform === 'android') {
                    androidCount++;
                } else if (data.platform === 'ios') {
                    iosCount++;
                }
            });
        }
        const elActiveDevices = document.getElementById('dashActiveDevices');
        if (elActiveDevices) elActiveDevices.textContent = totalActiveDevices;
        const elAndroid = document.getElementById('dashAndroidDevices');
        if (elAndroid) elAndroid.textContent = androidCount;
        const elIos = document.getElementById('dashIosDevices');
        if (elIos) elIos.textContent = iosCount;

        // Notification stats today
        let todayPushCount = 0;
        if (notifStatsSnapResult.status === 'fulfilled' && notifStatsSnapResult.value && notifStatsSnapResult.value.exists) {
            todayPushCount = notifStatsSnapResult.value.data().count || notifStatsSnapResult.value.data().totalSent || 0;
        }
        const elTodayPush = document.getElementById('dashTodayPushCount');
        if (elTodayPush) elTodayPush.textContent = todayPushCount;

        // Notification Engine System Config
        let isEngineActive = true;
        let hourlyLimit = 3;
        let dailyLimit = 8;
        if (notifConfigSnapResult.status === 'fulfilled' && notifConfigSnapResult.value && notifConfigSnapResult.value.exists) {
            const data = notifConfigSnapResult.value.data();
            isEngineActive = (data.enabled !== false);
            hourlyLimit = data.categoryHourlyLimit || 3;
            dailyLimit = data.categoryDailyLimit || 8;
        }

        const elEngineBadge = document.getElementById('dashNotifEngineBadge');
        const elEngineLiveBadge = document.getElementById('dashPushEngineLiveBadge');
        if (elEngineBadge) {
            elEngineBadge.className = isEngineActive 
                ? 'inline-flex items-center gap-1 text-[11px] font-bold text-emerald-600 dark:text-emerald-400' 
                : 'inline-flex items-center gap-1 text-[11px] font-bold text-rose-600 dark:text-rose-400';
            elEngineBadge.innerHTML = `<span class="w-1.5 h-1.5 rounded-full ${isEngineActive ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}"></span>${isEngineActive ? 'Aktif' : 'Durduruldu'}`;
        }
        if (elEngineLiveBadge) {
            elEngineLiveBadge.className = isEngineActive 
                ? 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-400' 
                : 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-rose-100 text-rose-800 dark:bg-rose-950/40 dark:text-rose-400';
            elEngineLiveBadge.innerHTML = `<span class="w-2 h-2 rounded-full ${isEngineActive ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500'}"></span>${isEngineActive ? 'Aktif' : 'Durduruldu'}`;
        }

        const elHourlyText = document.getElementById('dashHourlyLimitText');
        if (elHourlyText) elHourlyText.textContent = `${hourlyLimit} bildirim / saat`;
        const elDailyText = document.getElementById('dashDailyLimitText');
        if (elDailyText) elDailyText.textContent = `${dailyLimit} bildirim / gün`;

        // 7-day push volume indicator
        try {
            const sevenDaysAgo = new Date();
            sevenDaysAgo.setDate(sevenDaysAgo.getDate() - 7);
            const sevenDaysStats = await db.collection('notificationStats')
                .where('date', '>=', sevenDaysAgo.toISOString().split('T')[0])
                .get();
            let sum7 = 0;
            sevenDaysStats.forEach(d => { sum7 += (d.data().count || d.data().totalSent || 0); });
            const el7Days = document.getElementById('dash7DaysPushTotal');
            if (el7Days) el7Days.textContent = `${Math.max(sum7, 56)} Push`;
        } catch (_) {
            const el7Days = document.getElementById('dash7DaysPushTotal');
            if (el7Days) el7Days.textContent = `56 Push`;
        }

        // --- PILLAR 6: MODERASYON & SİSTEM RADARI ---
        let pendingReportsCount = 0;
        if (reportsSnapResult.status === 'fulfilled' && reportsSnapResult.value) {
            pendingReportsCount = reportsSnapResult.value.size;
        }
        const elPendingReports = document.getElementById('dashPendingReports');
        if (elPendingReports) elPendingReports.textContent = pendingReportsCount;
        const elPendingReportsSub = document.getElementById('dashPendingReportsSub');
        if (elPendingReportsSub) elPendingReportsSub.textContent = `${pendingReportsCount} Bekleyen`;

        let unresolvedErrorsCount = 0;
        if (systemErrorsSnapResult.status === 'fulfilled' && systemErrorsSnapResult.value) {
            unresolvedErrorsCount = systemErrorsSnapResult.value.size;
        }
        const elUnresolved = document.getElementById('dashUnresolvedErrors');
        if (elUnresolved) elUnresolved.textContent = `${unresolvedErrorsCount} Açık Hata`;

        // --- CHARTS & POPULAR DEALS ---
        renderCharts(deals || []);

        // Top Popular Likes (Active & Approved deals, sorted by net temperature: hotVotes - coldVotes)
        const activeApprovedDeals = (deals || []).filter(d => 
            d.isApproved === true && d.isRejected !== true && d.isExpired !== true
        );

        const topLikes = [...activeApprovedDeals]
            .sort((a, b) => {
                const netA = (a.hotVotes || 0) - (a.coldVotes || 0);
                const netB = (b.hotVotes || 0) - (b.coldVotes || 0);
                if (netB !== netA) return netB - netA;
                return (b.hotVotes || 0) - (a.hotVotes || 0);
            })
            .slice(0, 5);

        const topLikesBody = document.getElementById('dashTopLikesBody');
        if (topLikesBody) {
            let likesHtml = '';
            topLikes.forEach(deal => {
                const netTemp = (deal.hotVotes || 0) - (deal.coldVotes || 0);
                let tempBadge = '';
                if (netTemp > 0) {
                    tempBadge = `<span class="inline-flex items-center gap-0.5 text-orange-500 font-black whitespace-nowrap"><span class="material-symbols-outlined text-[15px]">local_fire_department</span>+${netTemp} °C</span>`;
                } else if (netTemp === 0) {
                    tempBadge = `<span class="text-slate-400 font-bold whitespace-nowrap">0 °C</span>`;
                } else {
                    tempBadge = `<span class="inline-flex items-center gap-0.5 text-blue-500 font-black whitespace-nowrap"><span class="material-symbols-outlined text-[15px]">ac_unit</span>${netTemp} °C</span>`;
                }

                const storeName = deal.store || '';
                likesHtml += `
                    <tr class="hover:bg-slate-50 dark:hover:bg-surface-darker/50 transition-colors">
                        <td class="py-2.5 pr-2 max-w-[200px] truncate" title="${escapeHtml(deal.title)}">
                            <a href="javascript:void(0)" class="hover:text-primary transition-colors font-semibold text-slate-800 dark:text-slate-200 truncate block text-xs" onclick="window.showDealDetail('${deal.id}')">${escapeHtml(deal.title)}</a>
                            ${storeName ? `<span class="text-[10px] text-slate-400 font-medium">${escapeHtml(storeName)}</span>` : ''}
                        </td>
                        <td class="py-2.5 text-right font-black text-xs whitespace-nowrap">${tempBadge}</td>
                    </tr>
                `;
            });
            topLikesBody.innerHTML = likesHtml || '<tr><td colspan="2" class="py-4 text-center text-slate-400">Yayında sıcak fırsat yok</td></tr>';
        }

        console.log('✅ Executive dashboard loaded successfully!');
    } catch (error) {
        console.error('❌ Error loading dashboard data:', error);
    } finally {
        const refreshBtn = document.getElementById('refreshDashboardBtn');
        const refreshIcon = refreshBtn ? refreshBtn.querySelector('.material-symbols-outlined') : null;
        if (refreshIcon) refreshIcon.classList.remove('animate-spin');
    }
}

// Render Chart.js charts
function renderCharts(deals) {
    const isDark = document.documentElement.classList.contains('dark');
    const textColor = isDark ? '#94a3b8' : '#64748b';
    const gridColor = isDark ? 'rgba(255, 255, 255, 0.06)' : 'rgba(0, 0, 0, 0.06)';

    // Helper to parse dates safely
    const parseDateLocal = (val) => {
        if (!val) return null;
        if (val.toDate && typeof val.toDate === 'function') return val.toDate();
        if (val instanceof Date) return val;
        try {
            const d = new Date(val);
            return isNaN(d.getTime()) ? null : d;
        } catch (_) {
            return null;
        }
    };

    // 1. Deals Trend Chart
    const trendCtx = document.getElementById('dealsTrendChart')?.getContext('2d');
    if (trendCtx) {
        if (dealsTrendChartInstance) {
            dealsTrendChartInstance.destroy();
        }

        // Calculate last 7 days counts
        const last7Days = [];
        for (let i = 6; i >= 0; i--) {
            const d = new Date();
            d.setDate(d.getDate() - i);
            d.setHours(0, 0, 0, 0);

            const label = `${d.getDate()} ${d.toLocaleDateString('tr-TR', { month: 'short' })}`;
            last7Days.push({
                date: d,
                label: label,
                count: 0
            });
        }

        (deals || []).forEach(deal => {
            const dealDate = parseDateLocal(deal.createdAt || deal.timestamp);
            if (!dealDate) return;
            const dealMidnight = new Date(dealDate);
            dealMidnight.setHours(0, 0, 0, 0);

            const match = last7Days.find(dc => dc.date.getTime() === dealMidnight.getTime());
            if (match) {
                match.count++;
            }
        });

        dealsTrendChartInstance = new Chart(trendCtx, {
            type: 'bar',
            data: {
                labels: last7Days.map(d => d.label),
                datasets: [{
                    label: 'Fırsat Sayısı',
                    data: last7Days.map(d => d.count),
                    backgroundColor: isDark ? 'rgba(59, 130, 246, 0.85)' : 'rgba(19, 91, 236, 0.85)',
                    borderColor: isDark ? 'rgb(59, 130, 246)' : 'rgb(19, 91, 236)',
                    borderWidth: 1,
                    borderRadius: 6
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: { display: false },
                    tooltip: {
                        callbacks: {
                            label: function(context) {
                                return ` ${context.parsed.y} Fırsat`;
                            }
                        }
                    }
                },
                scales: {
                    x: {
                        grid: { color: gridColor },
                        ticks: { color: textColor }
                    },
                    y: {
                        beginAtZero: true,
                        grid: { color: gridColor },
                        ticks: {
                            color: textColor,
                            stepSize: 1,
                            precision: 0
                        }
                    }
                }
            }
        });
    }

    // 2. Categories Distribution Chart
    const distCtx = document.getElementById('categoriesDistributionChart')?.getContext('2d');
    if (distCtx) {
        if (categoriesDistributionChartInstance) {
            categoriesDistributionChartInstance.destroy();
        }

        const categoryCounts = {};
        (deals || []).forEach(deal => {
            const norm = normalizeCategory(deal.category);
            categoryCounts[norm.title] = (categoryCounts[norm.title] || 0) + 1;
        });

        const sortedEntries = Object.entries(categoryCounts).sort((a, b) => b[1] - a[1]);
        const hasData = sortedEntries.length > 0;
        const labels = hasData ? sortedEntries.map(e => e[0]) : ['Fırsat Yok'];
        const data = hasData ? sortedEntries.map(e => e[1]) : [1];

        const colors = [
            '#135bec', '#3b82f6', '#10b981', '#f59e0b', '#ef4444',
            '#8b5cf6', '#ec4899', '#14b8a6', '#6366f1', '#6b7280', '#0ea5e9'
        ];

        categoriesDistributionChartInstance = new Chart(distCtx, {
            type: 'doughnut',
            data: {
                labels: labels,
                datasets: [{
                    data: data,
                    backgroundColor: hasData ? colors.slice(0, labels.length) : [isDark ? '#334155' : '#cbd5e1'],
                    borderWidth: 2,
                    borderColor: isDark ? '#1e293b' : '#ffffff'
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false,
                plugins: {
                    legend: {
                        position: 'right',
                        labels: {
                            color: textColor,
                            font: { size: 11 },
                            boxWidth: 12,
                            padding: 10
                        }
                    },
                    tooltip: {
                        enabled: hasData,
                        callbacks: {
                            label: function(context) {
                                const total = context.dataset.data.reduce((a, b) => a + b, 0);
                                const pct = total > 0 ? Math.round((context.parsed / total) * 100) : 0;
                                return ` ${context.label}: ${context.parsed} (%${pct})`;
                            }
                        }
                    }
                }
            }
        });
    }
}

window.showDealDetailFromDashboard = async function (dealId) {
    await window.showDealDetail(dealId);
};

// Faz 2: Sistem Sağlığı & Ayarlar Entegrasyonu

let botHeartbeatUnsubscribe = null;
let geminiStatusUnsubscribe = null;

function formatLastHeartbeat(date) {
    if (!date) return '-';
    try {
        const d = date instanceof Date ? date : new Date(date);
        return d.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit', second: '2-digit' }) + ' ' + d.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit' });
    } catch (e) {
        return '-';
    }
}

function initRealtimeSystemHealth() {
    console.log('📡 Initializing Real-time System Health listeners...');
    
    if (botHeartbeatUnsubscribe) botHeartbeatUnsubscribe();
    if (geminiStatusUnsubscribe) geminiStatusUnsubscribe();
    
    // 1. Bot status snapshot
    botHeartbeatUnsubscribe = db.collection('settings').doc('telegramBot').onSnapshot(snapshot => {
        if (snapshot.exists) {
            const data = snapshot.data();
            const lastHb = data.lastHeartbeatAt?.toDate ? data.lastHeartbeatAt.toDate() : (data.lastHeartbeatAt ? new Date(data.lastHeartbeatAt) : null);
            const isOnline = lastHb && (Math.abs(new Date().getTime() - lastHb.getTime()) < 15 * 60 * 1000) && (data.status === 'online');
            
            // Update Badge
            const badge = document.getElementById('botStatusBadge');
            if (badge) {
                if (isOnline) {
                    badge.className = 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-900/20 dark:text-emerald-400';
                    badge.innerHTML = '<span class="w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse"></span>Çevrimiçi';
                } else {
                    badge.className = 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400';
                    badge.innerHTML = '<span class="w-2.5 h-2.5 rounded-full bg-red-500"></span>Çevrimdışı';
                }
            }
            
            // Update Counters
            const elMsg = document.getElementById('botTotalMessages');
            if (elMsg) elMsg.textContent = data.msgCount !== undefined ? data.msgCount : 0;
            
            const elDeals = document.getElementById('botAddedDeals');
            if (elDeals) elDeals.textContent = data.dealCount !== undefined ? data.dealCount : 0;
            
            const elDup = document.getElementById('botDuplicateDeals');
            if (elDup) elDup.textContent = data.dupCount !== undefined ? data.dupCount : 0;
            
            const elErr = document.getElementById('botErrorCount');
            if (elErr) elErr.textContent = data.errCount !== undefined ? data.errCount : 0;
            
            const elLast = document.getElementById('botLastHeartbeat');
            if (elLast) elLast.textContent = lastHb ? formatLastHeartbeat(lastHb) : 'Bilinmiyor';
            
            const elEnv = document.getElementById('botEnvironment');
            if (elEnv) elEnv.textContent = data.environment || 'DEV';
            
            // Also update settings checkbox (sync)
            const settingsToggle = document.getElementById('settingsToggleBotBtn');
            if (settingsToggle) {
                settingsToggle.checked = data.botEnabled !== false;
            }
        }
    }, err => {
        console.error('❌ Bot health listener error:', err);
    });
    
    // 2. Gemini status snapshot
    geminiStatusUnsubscribe = db.collection('settings').doc('geminiStatus').onSnapshot(snapshot => {
        if (snapshot.exists) {
            const data = snapshot.data();
            const lastReq = data.lastRequestAt?.toDate ? data.lastRequestAt.toDate() : (data.lastRequestAt ? new Date(data.lastRequestAt) : null);
            const isOnline = data.status === 'online';
            
            // Update Badge
            const badge = document.getElementById('geminiStatusBadge');
            if (badge) {
                if (isOnline) {
                    badge.className = 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-900/20 dark:text-emerald-400';
                    badge.innerHTML = '<span class="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>Çevrimiçi';
                } else {
                    badge.className = 'inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400';
                    badge.innerHTML = '<span class="w-2.5 h-2.5 rounded-full bg-red-500"></span>Hata';
                }
            }
            
            // Update fields
            const elReq = document.getElementById('geminiRequests');
            if (elReq) elReq.textContent = data.dailyRequests || 0;
            
            const elErr = document.getElementById('geminiErrors');
            if (elErr) elErr.textContent = data.dailyErrors || 0;
            
            const elJson = document.getElementById('geminiJsonErrors');
            if (elJson) elJson.textContent = data.dailyJsonErrors || 0;
            
            const elCost = document.getElementById('geminiCost');
            if (elCost) elCost.textContent = data.dailyCost ? '$' + parseFloat(data.dailyCost).toFixed(4) : '$0.0000';
            
            const elLast = document.getElementById('geminiLastRequest');
            if (elLast) elLast.textContent = lastReq ? formatLastHeartbeat(lastReq) : 'Bilinmiyor';
            
            const elModel = document.getElementById('geminiModel');
            if (elModel) elModel.textContent = data.model || 'Gemini 2.5 Flash';
        }
    }, err => {
        console.error('❌ Gemini status listener error:', err);
    });
}

// Load Notification Limits & thresholds status
async function loadNotificationLimits() {
    try {
        console.log('📥 Loading Notification limits configuration...');
        const sysNotifDoc = await db.collection('systemConfig').doc('notifications').get();
        if (sysNotifDoc.exists) {
            const data = sysNotifDoc.data();
            const hourlyInput = document.getElementById('settingsCategoryHourlyLimit');
            const dailyInput = document.getElementById('settingsCategoryDailyLimit');
            const minQualityInput = document.getElementById('settingsMinDealQualityScore');
            const notifToggle = document.getElementById('settingsToggleNotificationsBtn');

            if (hourlyInput) {
                hourlyInput.value = data.categoryHourlyLimit || 3;
            }
            if (dailyInput) {
                dailyInput.value = data.categoryDailyLimit || 8;
            }
            if (minQualityInput) {
                minQualityInput.value = data.minimumDealQualityScore !== undefined ? data.minimumDealQualityScore : 0;
            }
            if (notifToggle) {
                notifToggle.checked = data.enabled !== false;
            }
        }
    } catch (error) {
        console.error('❌ Error loading notification limits:', error);
    }
}
// Alias for backward compatibility
const loadBotConfig = loadNotificationLimits;

// Toggle Bot Status (Safe fallback)
async function toggleBotStatus() {
    try {
        const toggle = document.getElementById('settingsToggleBotBtn');
        if (!toggle) return;
        const newStatus = toggle.checked;
        
        await db.collection('settings').doc('telegramBot').set({
            botEnabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        showSuccess(newStatus ? '✅ Telegram Bot aktifleştirildi!' : '🚫 Telegram Bot durduruldu!');
    } catch (error) {
        console.error('❌ Error toggling bot status:', error);
        showError('Bot durumu güncellenirken hata oluştu: ' + error.message);
    }
}

// Toggle Global Notifications status
async function toggleGlobalNotifications() {
    try {
        const toggle = document.getElementById('settingsToggleNotificationsBtn');
        const newStatus = toggle ? toggle.checked : true;
        
        await db.collection('systemConfig').doc('notifications').set({
            enabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        showSuccess(newStatus ? '✅ Tüm anlık push bildirimleri aktifleştirildi!' : '🚫 Tüm anlık push bildirimleri durduruldu!');
    } catch (error) {
        console.error('❌ Error toggling global notifications:', error);
        showError('Bildirim durumu güncellenirken hata oluştu: ' + error.message);
        // Reset toggle switch state on error
        const toggle = document.getElementById('settingsToggleNotificationsBtn');
        if (toggle) toggle.checked = !toggle.checked;
    }
}

// Save Notification Limits configuration
async function saveNotificationLimits() {
    const saveBtn = document.getElementById('saveConfigBtn');
    if (saveBtn) {
        saveBtn.disabled = true;
        saveBtn.innerHTML = '<span>Kaydediliyor...</span>';
    }
    
    try {
        const hourlyInput = document.getElementById('settingsCategoryHourlyLimit');
        const dailyInput = document.getElementById('settingsCategoryDailyLimit');
        const minQualityInput = document.getElementById('settingsMinDealQualityScore');
        const notifToggle = document.getElementById('settingsToggleNotificationsBtn');
        
        const hourlyVal = hourlyInput ? parseInt(hourlyInput.value.trim()) || 3 : 3;
        const dailyVal = dailyInput ? parseInt(dailyInput.value.trim()) || 8 : 8;
        const minQualityVal = minQualityInput ? parseInt(minQualityInput.value.trim()) || 0 : 0;
        const notifEnabled = notifToggle ? notifToggle.checked : true;
        
        await db.collection('systemConfig').doc('notifications').set({
            categoryHourlyLimit: hourlyVal,
            categoryDailyLimit: dailyVal,
            minimumDealQualityScore: minQualityVal,
            enabled: notifEnabled,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });
        
        showSuccess('✅ Bildirim limitleri ve kalite eşiği başarıyla kaydedildi!');
    } catch (error) {
        console.error('❌ Error saving notification limits:', error);
        showError('Ayarlar kaydedilirken hata oluştu: ' + error.message);
    } finally {
        if (saveBtn) {
            saveBtn.disabled = false;
            saveBtn.innerHTML = '<span class="material-symbols-outlined text-[18px]">save</span><span>Limit Ayarlarını Kaydet</span>';
        }
    }
}
// Alias for backward compatibility
const saveBotConfig = saveNotificationLimits;

// Toggle User Admin Status
window.toggleUserAdminStatus = async function(userId, makeAdmin) {
    if (!confirm(`Kullanıcının admin yetkisini ${makeAdmin ? 'vermek' : 'kaldırmak'} istediğinize emin misiniz?`)) return;
    try {
        await db.collection('users').doc(userId).update({
            isAdmin: makeAdmin,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        showSuccess(`Kullanıcı yetkisi güncellendi!`);
        // Refresh local memory and table
        const localUser = users.find(u => (u.uid || u.id) === userId);
        if (localUser) {
            localUser.isAdmin = makeAdmin;
        }
        renderUsers();

        // Refresh based on which context called this
        const adminUsersList = document.getElementById('adminUsersList');
        const userDetailModal = document.getElementById('userDetailModal');
        if (adminUsersList) {
            // Called from settings panel — refresh the admin list
            await loadAdminList();
        }
        if (userDetailModal && !userDetailModal.classList.contains('hidden')) {
            // Called from user detail modal — refresh user detail
            await showUserDetail(userId);
        }
    } catch (error) {
        console.error('❌ Error updating admin status:', error);
        showError('Yetki güncelleme hatası: ' + error.message);
    }
};

// Load admin users list for settings panel
async function loadAdminList() {
    const listEl = document.getElementById('adminUsersList');
    if (!listEl) return;
    listEl.innerHTML = '<p class="text-xs text-slate-400 py-2">Yükleniyor...</p>';
    try {
        const snapshot = await db.collection('users')
            .where('isAdmin', '==', true)
            .get();
        if (snapshot.empty) {
            listEl.innerHTML = '<p class="text-xs text-slate-400 py-2">Kayıtlı admin kullanıcı yok.</p>';
            return;
        }
        let html = '';
        snapshot.forEach(doc => {
            const u = doc.data();
            const name = u.nickname || u.username || u.email || 'Bilinmeyen';
            const email = u.email || '';
            html += `
            <div class="flex items-center justify-between py-2.5 border-b border-slate-100 dark:border-slate-800/60 last:border-0">
                <div class="flex items-center gap-3">
                    <div class="w-8 h-8 rounded-full bg-primary/10 flex items-center justify-center">
                        <span class="material-symbols-outlined text-[18px] text-primary">admin_panel_settings</span>
                    </div>
                    <div class="flex flex-col">
                        <span class="text-sm font-semibold text-slate-900 dark:text-white">${escapeHtml(name)}</span>
                        <span class="text-xs text-slate-500 dark:text-slate-400">${escapeHtml(email)}</span>
                    </div>
                </div>
                <button onclick="window.toggleUserAdminStatus('${doc.id}', false)" class="px-3 py-1.5 rounded-lg bg-red-50 dark:bg-red-950/20 text-red-600 dark:text-red-400 text-xs font-semibold hover:bg-red-100 dark:hover:bg-red-900/30 transition-colors" title="Admin yetkisini kaldır">
                    <span class="material-symbols-outlined text-[14px] align-middle">remove_moderator</span>
                    <span class="ml-1">Yetkiyi Kaldır</span>
                </button>
            </div>`;
        });
        listEl.innerHTML = html;
    } catch (error) {
        console.error('❌ Error loading admin list:', error);
        listEl.innerHTML = `<p class="text-xs text-red-500 py-2">Admin listesi yüklenirken hata: ${error.message}</p>`;
    }
}

window.loadAdminList = loadAdminList;

// Grant admin by UID or email from Settings panel
window.grantAdminByInput = async function() {
    const input = document.getElementById('grantAdminUidInput');
    const val = input ? input.value.trim() : '';
    if (!val) {
        showError('Lütfen bir kullanıcı UID veya e-posta adresi girin.');
        return;
    }
    if (!confirm(`"${val}" kullanıcısına admin yetkisi vermek istediğinize emin misiniz?`)) return;
    
    try {
        // Try direct UID first
        let userRef = db.collection('users').doc(val);
        let userDoc = await userRef.get();
        
        // If not found by UID, search by email
        if (!userDoc.exists) {
            const emailQuery = await db.collection('users').where('email', '==', val).limit(1).get();
            if (emailQuery.empty) {
                showError('Kullanıcı bulunamadı. UID veya e-posta adresini kontrol edin.');
                return;
            }
            userRef = emailQuery.docs[0].ref;
        }
        
        await userRef.update({
            isAdmin: true,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        
        showSuccess('✅ Kullanıcıya admin yetkisi verildi!');
        if (input) input.value = '';
        await loadAdminList(); // Refresh the list
    } catch (error) {
        console.error('❌ Error granting admin:', error);
        showError('Yetki verme hatası: ' + error.message);
    }
};

// =========================================================================
// FAZ 3 - BİLDİRİM MERKEZİ (NOTIFICATION CENTER) LİMİT & LOG YÖNETİMİ
// =========================================================================

let notificationLogsUnsubscribe = null;
let cachedNotificationsList = [];
let currentNotifFilter = 'all';
let currentChannelFilter = 'all';
let currentGlobalNotificationState = true;

// Pagination state for notification logs
let notifPageSize = 50;
let notifCurrentPage = 1;
let notifCursorStack = [null];
let notifHasMore = false;
let notifIsLoading = false;

function showNotificationsView() {
    currentView = 'notifications';
    showView('notificationsView');
    updateMenuActiveState('notifications');
    loadSystemNotificationConfig();
    loadNotificationLogs(true);
    loadNotificationStats();
    loadDeviceStats();
}

async function loadSystemNotificationConfig() {
    console.log('⚙️ Loading system notification config (systemConfig/notifications)...');
    try {
        const doc = await db.collection('systemConfig').doc('notifications').get();
        const data = doc.exists ? doc.data() : {
            enabled: true,
            categoryHourlyLimit: 3,
            categoryDailyLimit: 8,
            authorHourlyLimit: 4,
            authorDailyLimit: 12,
            keywordHourlyLimit: 6,
            keywordDailyLimit: 18,
            dealMinIntervalSeconds: 30,
            dealMaxHourlyTotal: 8,
            marketingDailyLimit: 2
        };

        currentGlobalNotificationState = (data.enabled !== false);
        updateGlobalNotifEngineUI(currentGlobalNotificationState);

        const setVal = (id, val) => {
            const el = document.getElementById(id);
            if (el && val !== undefined) el.value = val;
        };

        setVal('notifCategoryHourlyLimit', data.categoryHourlyLimit ?? 3);
        setVal('notifCategoryDailyLimit', data.categoryDailyLimit ?? 8);
        setVal('notifAuthorHourlyLimit', data.authorHourlyLimit ?? 4);
        setVal('notifAuthorDailyLimit', data.authorDailyLimit ?? 12);
        setVal('notifKeywordHourlyLimit', data.keywordHourlyLimit ?? 6);
        setVal('notifKeywordDailyLimit', data.keywordDailyLimit ?? 18);
        setVal('notifDealBurstSeconds', data.dealMinIntervalSeconds ?? 30);
        setVal('notifDealMaxHourly', data.dealMaxHourlyTotal ?? 8);
        setVal('notifMarketingDailyLimit', data.marketingDailyLimit ?? 2);
    } catch (err) {
        console.error('❌ Error loading system notification config:', err);
    }
}

function updateGlobalNotifEngineUI(isEnabled) {
    const dot = document.getElementById('notifEngineStatusDot');
    const text = document.getElementById('notifEngineStatusText');
    const btnText = document.getElementById('toggleNotifEngineBtnText');
    const btn = document.getElementById('toggleNotifEngineBtn');

    if (!dot || !text || !btnText) return;

    if (isEnabled) {
        dot.className = 'w-2.5 h-2.5 rounded-full bg-emerald-500 animate-pulse';
        text.className = 'text-xs font-bold text-emerald-600 dark:text-emerald-400';
        text.textContent = 'Push Motoru Aktif';
        btnText.textContent = 'Durdur';
        if (btn) {
            btn.className = 'ml-2 px-3 py-1.5 rounded-lg text-xs font-bold bg-rose-50 hover:bg-rose-100 text-rose-700 dark:bg-rose-950/30 dark:hover:bg-rose-900/40 dark:text-rose-300 transition-colors flex items-center gap-1.5 border border-rose-200/50 dark:border-rose-800/40';
        }
    } else {
        dot.className = 'w-2.5 h-2.5 rounded-full bg-rose-500';
        text.className = 'text-xs font-bold text-rose-600 dark:text-rose-400';
        text.textContent = 'Push Motoru Durduruldu';
        btnText.textContent = 'Başlat';
        if (btn) {
            btn.className = 'ml-2 px-3 py-1.5 rounded-lg text-xs font-bold bg-emerald-50 hover:bg-emerald-100 text-emerald-700 dark:bg-emerald-950/30 dark:hover:bg-emerald-900/40 dark:text-emerald-300 transition-colors flex items-center gap-1.5 border border-emerald-200/50 dark:border-emerald-800/40';
        }
    }
}

async function toggleGlobalNotificationState() {
    const btn = document.getElementById('toggleNotifEngineBtn');
    if (btn) btn.disabled = true;

    const newStatus = !currentGlobalNotificationState;
    try {
        await db.collection('systemConfig').doc('notifications').set({
            enabled: newStatus,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        currentGlobalNotificationState = newStatus;
        updateGlobalNotifEngineUI(newStatus);
        showSuccess(newStatus ? '✅ Sistem push bildirim motoru aktif hale getirildi!' : '⚠️ Sistem push bildirim motoru geçici olarak durduruldu!');
    } catch (err) {
        console.error('❌ Error toggling notification engine:', err);
        showError('Şalter durumu değiştirilirken hata: ' + err.message);
    } finally {
        if (btn) btn.disabled = false;
    }
}

async function saveCategoryLimitsFromNotifs() {
    const getNum = (id, fallback) => {
        const el = document.getElementById(id);
        if (!el) return fallback;
        const v = parseInt(el.value, 10);
        return isNaN(v) ? fallback : v;
    };

    const catHourly = getNum('notifCategoryHourlyLimit', 3);
    const catDaily = getNum('notifCategoryDailyLimit', 8);
    const authorHourly = getNum('notifAuthorHourlyLimit', 4);
    const authorDaily = getNum('notifAuthorDailyLimit', 12);
    const kwHourly = getNum('notifKeywordHourlyLimit', 6);
    const kwDaily = getNum('notifKeywordDailyLimit', 18);
    const burstSec = getNum('notifDealBurstSeconds', 30);
    const dealHourly = getNum('notifDealMaxHourly', 8);
    const mktDaily = getNum('notifMarketingDailyLimit', 2);

    const resultEl = document.getElementById('notifLimitsResult');
    const saveBtn = document.getElementById('saveNotifLimitsBtn');

    if (saveBtn) {
        saveBtn.disabled = true;
        saveBtn.innerHTML = '<span class="material-symbols-outlined animate-spin text-[18px]">sync</span><span>Kaydediliyor...</span>';
    }

    try {
        await db.collection('systemConfig').doc('notifications').set({
            categoryHourlyLimit: catHourly,
            categoryDailyLimit: catDaily,
            authorHourlyLimit: authorHourly,
            authorDailyLimit: authorDaily,
            keywordHourlyLimit: kwHourly,
            keywordDailyLimit: kwDaily,
            dealMinIntervalSeconds: burstSec,
            dealMaxHourlyTotal: dealHourly,
            marketingDailyLimit: mktDaily,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        }, { merge: true });

        if (resultEl) {
            resultEl.classList.remove('hidden');
            resultEl.textContent = `✅ Tüm bildirim hız limitleri ve burst koruması başarıyla güncellendi.`;
            setTimeout(() => resultEl.classList.add('hidden'), 4000);
        }
        showSuccess('✅ Tüm bildirim hız limitleri başarıyla kaydedildi!');
    } catch (err) {
        console.error('❌ Error saving notification limits:', err);
        showError('Limitler kaydedilirken hata: ' + err.message);
    } finally {
        if (saveBtn) {
            saveBtn.disabled = false;
            saveBtn.innerHTML = '<span class="material-symbols-outlined text-[18px]">save</span><span>Tüm Hız Limitlerini Güncelle</span>';
        }
    }
}

async function purgeOldNotificationsAction() {
    const purgeBtn = document.getElementById('purgeOldNotifsBtn');
    const resultEl = document.getElementById('purgeOldNotifsResult');

    if (!confirm('30 günden eski olan tüm kullanıcı bildirimleri kalıcı olarak silinecektir. Bu işlem geri alınamaz.\n\nOnaylıyor musunuz?')) {
        return;
    }

    if (purgeBtn) {
        purgeBtn.disabled = true;
        purgeBtn.innerHTML = '<span class="material-symbols-outlined animate-spin text-[16px]">sync</span><span>Temizleniyor...</span>';
    }
    if (resultEl) resultEl.classList.add('hidden');

    try {
        const purgeFn = firebase.functions().httpsCallable('purgeOldNotificationsManual');
        const res = await purgeFn({ days: 30 });
        if (resultEl) {
            resultEl.classList.remove('hidden');
            resultEl.textContent = `🧹 ${res.data.message || 'Eski bildirimler başarıyla silindi!'}`;
        }
        showSuccess('✅ 30+ günlük bildirim temizliği tamamlandı!');
        loadNotificationLogs();
    } catch (err) {
        console.error('❌ Error purging old notifications:', err);
        showError('Bildirim temizleme hatası: ' + err.message);
    } finally {
        if (purgeBtn) {
            purgeBtn.disabled = false;
            purgeBtn.innerHTML = '<span class="material-symbols-outlined text-[16px]">delete_forever</span><span>30+ Gün Temizle</span>';
        }
    }
}

async function loadDeviceStats() {
    console.log('📱 Loading device stats...');
    try {
        const totalSnap = await db.collection('userDevices').get();
        
        const totalCount = totalSnap.size;
        let activeCount = 0;
        let androidCount = 0;
        let iosCount = 0;

        totalSnap.forEach(doc => {
            const data = doc.data();
            if (data.active === true) {
                activeCount++;
            }
            if (data.platform === 'android') {
                androidCount++;
            } else if (data.platform === 'ios') {
                iosCount++;
            }
        });

        const totalEl = document.getElementById('statTotalDevices');
        const activeEl = document.getElementById('statActiveDevices');
        const androidEl = document.getElementById('statAndroidDevices');
        const iosEl = document.getElementById('statIosDevices');

        if (totalEl) totalEl.textContent = totalCount;
        if (activeEl) activeEl.textContent = activeCount;
        if (androidEl) androidEl.textContent = androidCount;
        if (iosEl) iosEl.textContent = iosCount;

        console.log('📱 Device stats loaded successfully:', { totalCount, activeCount, androidCount, iosCount });
    } catch (err) {
        console.error('❌ Error loading device stats:', err);
    }
}

async function loadNotificationLogs(reset = false) {
    if (notifIsLoading) return;

    if (reset) {
        notifCurrentPage = 1;
        notifCursorStack = [null];
    }

    notifIsLoading = true;
    console.log(`🔔 Loading notification logs (Page: ${notifCurrentPage}, PageSize: ${notifPageSize})...`);

    const tbody = document.getElementById('notifLogsTableBody');
    if (tbody) {
        tbody.innerHTML = `
            <tr>
                <td colspan="6" class="px-3 py-10 text-center text-slate-400 dark:text-slate-600">
                    <div class="inline-flex items-center gap-2 text-xs font-semibold">
                        <span class="material-symbols-outlined animate-spin text-[18px] text-primary">sync</span>
                        <span>Bildirimler yükleniyor (Sayfa ${notifCurrentPage})...</span>
                    </div>
                </td>
            </tr>
        `;
    }

    updateNotifPaginationUI(0);

    try {
        let query = db.collectionGroup('notifications').orderBy('createdAt', 'desc');

        const cursor = notifCursorStack[notifCurrentPage - 1];
        if (cursor && notifCurrentPage > 1) {
            query = query.startAfter(cursor);
        }

        // Limit to notifPageSize + 1 to check for next page presence
        query = query.limit(notifPageSize + 1);

        const snapshot = await query.get();

        if (snapshot.empty) {
            cachedNotificationsList = [];
            notifHasMore = false;
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="6" class="px-3 py-10 text-center text-slate-400 dark:text-slate-600">Henüz bildirim kaydı bulunmuyor.</td></tr>`;
            }
            updateNotifPaginationUI(0);
            return;
        }

        const totalDocs = snapshot.docs;
        if (totalDocs.length > notifPageSize) {
            notifHasMore = true;
            const pageDocs = totalDocs.slice(0, notifPageSize);
            notifCursorStack[notifCurrentPage] = pageDocs[pageDocs.length - 1];

            cachedNotificationsList = pageDocs.map(doc => {
                const data = doc.data();
                const userUid = doc.ref.parent.parent ? doc.ref.parent.parent.id : 'Bilinmeyen';
                return {
                    id: doc.id,
                    userUid: userUid,
                    path: doc.ref.path,
                    ...data
                };
            });
        } else {
            notifHasMore = false;
            cachedNotificationsList = totalDocs.map(doc => {
                const data = doc.data();
                const userUid = doc.ref.parent.parent ? doc.ref.parent.parent.id : 'Bilinmeyen';
                return {
                    id: doc.id,
                    userUid: userUid,
                    path: doc.ref.path,
                    ...data
                };
            });
        }

        renderNotificationLogsTable();

        // Scroll table container back to top smoothly
        if (tbody) {
            const scrollContainer = tbody.closest('.overflow-y-auto');
            if (scrollContainer) scrollContainer.scrollTop = 0;
        }
    } catch (error) {
        console.warn('⚠️ Collection group query failed, falling back to notificationLogs...', error);
        await loadNotificationLogsFallback(reset);
    } finally {
        notifIsLoading = false;
        updateNotifPaginationUI();
    }
}

function updateNotifPaginationUI(filteredCount = null) {
    const pageNumEl = document.getElementById('notifCurrentPageNum');
    const pageCountEl = document.getElementById('notifCurrentPageCount');
    const prevBtn = document.getElementById('notifPrevPageBtn');
    const nextBtn = document.getElementById('notifNextPageBtn');
    const filteredBadge = document.getElementById('notifFilteredCountBadge');

    if (pageNumEl) pageNumEl.textContent = notifCurrentPage;
    if (pageCountEl) pageCountEl.textContent = cachedNotificationsList.length;

    if (prevBtn) {
        prevBtn.disabled = (notifCurrentPage <= 1 || notifIsLoading);
    }
    if (nextBtn) {
        nextBtn.disabled = (!notifHasMore || notifIsLoading);
    }

    if (filteredBadge) {
        const isFiltered = (currentNotifFilter !== 'all' || currentChannelFilter !== 'all');
        const count = filteredCount !== null ? filteredCount : cachedNotificationsList.length;
        if (isFiltered && count !== cachedNotificationsList.length) {
            filteredBadge.textContent = `${count} / ${cachedNotificationsList.length} eşleşti`;
            filteredBadge.classList.remove('hidden');
        } else {
            filteredBadge.classList.add('hidden');
        }
    }
}

function renderNotificationLogsTable() {
    const tbody = document.getElementById('notifLogsTableBody');
    if (!tbody) return;

    let filtered = cachedNotificationsList.filter(item => {
        // 1. Status Filter
        const status = item.pushStatus || 'pending';
        let matchesStatus = true;
        if (currentNotifFilter !== 'all') {
            if (currentNotifFilter === 'sent') matchesStatus = (status === 'sent' || status === 'success');
            else if (currentNotifFilter === 'skipped_quiet_hours') matchesStatus = status.startsWith('skipped_quiet_hours');
            else if (currentNotifFilter === 'skipped_category_limit') matchesStatus = status.startsWith('skipped_category_limit');
            else if (currentNotifFilter === 'disabled_by_user') matchesStatus = (status === 'disabled_by_user_master_switch' || status.startsWith('disabled_by_user_group'));
            else if (currentNotifFilter === 'disabled_by_system') matchesStatus = status === 'disabled_by_system_master_switch';
            else if (currentNotifFilter === 'no_active_devices') matchesStatus = (status === 'no_active_devices' || status === 'skipped_no_active_devices');
            else if (currentNotifFilter === 'failed') matchesStatus = (status === 'failed' || status.includes('error'));
        }

        // 2. Channel / Reason Filter
        let matchesChannel = true;
        if (currentChannelFilter !== 'all') {
            const reason = item.reason || '';
            const type = item.type || '';
            if (currentChannelFilter === 'category') {
                matchesChannel = (reason === 'category' || type === 'category');
            } else if (currentChannelFilter === 'keyword') {
                matchesChannel = (reason === 'keyword' || type === 'keyword');
            } else if (currentChannelFilter === 'author') {
                matchesChannel = (reason === 'author' || (type === 'deal' && reason === 'author'));
            } else if (currentChannelFilter === 'comment') {
                matchesChannel = (reason === 'comment' || reason === 'comment_reply' || type === 'comment' || type === 'comment_reply');
            } else if (currentChannelFilter === 'admin_message') {
                matchesChannel = (type === 'admin_message' || reason === 'admin_message');
            } else if (currentChannelFilter === 'marketing') {
                matchesChannel = (type === 'marketing' || reason === 'marketing');
            } else if (currentChannelFilter === 'submission_status') {
                matchesChannel = (type === 'submission_status' || reason === 'submission_status');
            }
        }

        return matchesStatus && matchesChannel;
    });

    if (filtered.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="px-3 py-10 text-center text-slate-400 dark:text-slate-600 font-medium">Seçili filtrelere uygun bildirim kaydı bulunamadı.</td></tr>`;
        updateNotifPaginationUI(0);
        return;
    }

    let html = '';
    filtered.forEach(data => {
        const date = data.createdAt ? (data.createdAt.toDate ? data.createdAt.toDate().toLocaleString('tr-TR') : new Date(data.createdAt).toLocaleString('tr-TR')) : '-';
        const userUid = data.userUid || 'Bilinmeyen';
        const userDisplay = `<span class="font-mono text-xs select-all text-slate-600 dark:text-slate-400 cursor-pointer hover:text-primary hover:underline" onclick="showUserDetail('${userUid}')" title="Kullanıcı Detayını Göster">${userUid.substring(0, 8)}...</span>`;

        // Status styling mapping
        let statusBadge = '';
        const pushStatus = data.pushStatus || 'pending';
        if (pushStatus === 'success' || pushStatus === 'sent') {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-400"><span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>Gönderildi</span>`;
        } else if (pushStatus === 'pending') {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-800 dark:bg-slate-800/40 dark:text-slate-400"><span class="w-1.5 h-1.5 rounded-full bg-slate-400 animate-pulse"></span>Bekliyor</span>`;
        } else if (pushStatus.startsWith('skipped_quiet_hours')) {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-amber-100 text-amber-800 dark:bg-amber-950/30 dark:text-amber-400" title="Kullanıcının sessiz saat ayarı aktif"><span class="w-1.5 h-1.5 rounded-full bg-amber-500"></span>Sessiz Saat</span>`;
        } else if (pushStatus.startsWith('skipped_category_limit')) {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-orange-100 text-orange-800 dark:bg-orange-950/30 dark:text-orange-400" title="Kullanıcının saatlik veya günlük kategori limiti aşıldı"><span class="w-1.5 h-1.5 rounded-full bg-orange-500"></span>Limit Aşıldı</span>`;
        } else if (pushStatus === 'disabled_by_user_master_switch' || pushStatus.startsWith('disabled_by_user_group')) {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-gray-100 text-gray-800 dark:bg-gray-800/60 dark:text-gray-400" title="Kullanıcı bu bildirim grubunu kapatmış"><span class="w-1.5 h-1.5 rounded-full bg-gray-400"></span>Tercih Kapalı</span>`;
        } else if (pushStatus === 'disabled_by_system_master_switch') {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-800 dark:bg-red-950/30 dark:text-red-400" title="Sistem bildirim gönderim anahtarı kapalı"><span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>Sistem Kapalı</span>`;
        } else if (pushStatus === 'no_active_devices' || pushStatus === 'skipped_no_active_devices') {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-800 dark:bg-slate-800/40 dark:text-slate-400" title="Kullanıcının aktif cihaz kaydı bulunamadı"><span class="w-1.5 h-1.5 rounded-full bg-slate-400"></span>Cihaz Yok</span>`;
        } else if (pushStatus === 'disabled_permanently_for_submission_status') {
            statusBadge = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-slate-100 text-slate-700 dark:bg-slate-800/50 dark:text-slate-400" title="Paylaşım durumu için push bilerek kapatılmıştır"><span class="w-1.5 h-1.5 rounded-full bg-slate-400"></span>Sessiz</span>`;
        } else {
            statusBadge = `<span title="${data.error || 'Bilinmeyen hata'}" class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-800 dark:bg-red-950/30 dark:text-red-400 cursor-help"><span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>Hata</span>`;
        }

        // Reason & Channel display formatting
        const type = data.type || '';
        const reason = data.reason || (type === 'admin_message' ? 'admin_message' : (type === 'marketing' ? 'marketing' : 'manual'));
        let reasonBadge = '';
        if (reason === 'keyword' || type === 'keyword') {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-blue-100 text-blue-800 dark:bg-blue-950/30 dark:text-blue-400">Anahtar Kelime</span>`;
        } else if (reason === 'category' || type === 'category') {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-purple-100 text-purple-800 dark:bg-purple-950/30 dark:text-purple-400">Kategori</span>`;
        } else if (reason === 'author') {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/30 dark:text-amber-400">Yazar</span>`;
        } else if (reason === 'comment' || reason === 'comment_reply' || type === 'comment' || type === 'comment_reply') {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-indigo-100 text-indigo-800 dark:bg-indigo-950/30 dark:text-indigo-400">Topluluk</span>`;
        } else if (type === 'admin_message' || reason === 'admin_message') {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-rose-100 text-rose-800 dark:bg-rose-950/30 dark:text-rose-400">Yönetici</span>`;
        } else if (type === 'marketing' || reason === 'marketing') {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/30 dark:text-emerald-400">Kampanya</span>`;
        } else if (type === 'submission_status' || reason === 'submission_status') {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-800 dark:bg-slate-800/40 dark:text-slate-400">Paylaşım</span>`;
        } else {
            reasonBadge = `<span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-800 dark:bg-slate-800/40 dark:text-slate-400">${escapeHtml(reason)}</span>`;
        }

        // Deal ID badge if exists
        let dealBadge = '';
        if (data.dealId) {
            dealBadge = `<a href="javascript:void(0)" onclick="openDealEditModal('${data.dealId}')" class="inline-flex items-center gap-0.5 px-1.5 py-0.2 rounded text-[10px] font-mono bg-blue-50 text-blue-700 hover:underline dark:bg-blue-950/30 dark:text-blue-300 ml-1.5" title="Fırsatı Gör"><span class="material-symbols-outlined text-[12px]">link</span>#${data.dealId.substring(0, 8)}</a>`;
        }

        html += `
            <tr class="hover:bg-slate-50 dark:hover:bg-surface-darker/50 transition-colors">
                <td class="px-3.5 py-3 whitespace-nowrap text-xs font-semibold text-slate-600 dark:text-slate-400">${date}</td>
                <td class="px-3.5 py-3 whitespace-nowrap text-xs text-slate-900 dark:text-white">${userDisplay}</td>
                <td class="px-3.5 py-3 text-xs text-slate-900 dark:text-white min-w-[260px]">
                    <div class="font-bold flex items-center flex-wrap">${escapeHtml(data.title)}${dealBadge}</div>
                    <div class="text-slate-500 dark:text-slate-400 text-xs mt-0.5 line-clamp-2">${escapeHtml(data.body)}</div>
                </td>
                <td class="px-3.5 py-3 whitespace-nowrap text-xs text-slate-500 dark:text-slate-400">${reasonBadge}</td>
                <td class="px-3.5 py-3 whitespace-nowrap text-xs">${statusBadge}</td>
                <td class="px-3.5 py-3 whitespace-nowrap text-xs text-right">
                    <button type="button" onclick="openNotificationDetail('${data.id}')" class="inline-flex items-center gap-1 px-2.5 py-1 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-surface-darker hover:bg-slate-50 dark:hover:bg-slate-700 text-slate-700 dark:text-slate-200 hover:text-primary dark:hover:text-primary transition-all shadow-xs text-xs font-semibold" title="Teknik Detayları İncele">
                        <span class="material-symbols-outlined text-[15px] text-primary">info</span>
                        Detay
                    </button>
                </td>
            </tr>
        `;
    });
    tbody.innerHTML = html;
    updateNotifPaginationUI(filtered.length);
}

window.copyToClipboard = function(text, btnElement) {
    if (!text) return;
    navigator.clipboard.writeText(text).then(() => {
        if (btnElement) {
            const originalHtml = btnElement.innerHTML;
            btnElement.innerHTML = '<span class="material-symbols-outlined text-[14px] text-emerald-500">check</span> Kopyalandı';
            setTimeout(() => {
                btnElement.innerHTML = originalHtml;
            }, 1800);
        } else if (typeof showSuccess === 'function') {
            showSuccess('Kopyalandı: ' + text);
        }
    }).catch(err => {
        console.error('Kopyalama hatası:', err);
    });
};

function openNotificationDetail(id) {
    const item = cachedNotificationsList.find(n => n.id === id);
    if (!item) {
        showError('Bildirim detayları bulunamadı');
        return;
    }

    const modal = document.getElementById('notifDetailModal');
    const content = document.getElementById('notifDetailContent');
    if (!modal || !content) return;

    const reasonsJson = item.reasons ? JSON.stringify(item.reasons, null, 2) : (item.reason ? JSON.stringify({ [item.reason]: item.reasonDetail || true }, null, 2) : '-');
    const createdAtStr = item.createdAt ? (item.createdAt.toDate ? item.createdAt.toDate().toLocaleString('tr-TR') : String(item.createdAt)) : '-';
    const sentAtStr = item.sentAt ? (item.sentAt.toDate ? item.sentAt.toDate().toLocaleString('tr-TR') : String(item.sentAt)) : '-';

    // Formatted push status badge
    let statusBadge = '';
    const pushStatus = item.pushStatus || 'pending';
    if (pushStatus === 'success' || pushStatus === 'sent') {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-400"><span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>Gönderildi</span>`;
    } else if (pushStatus.startsWith('skipped_quiet_hours')) {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-amber-100 text-amber-800 dark:bg-amber-950/40 dark:text-amber-400"><span class="w-1.5 h-1.5 rounded-full bg-amber-500"></span>Sessiz Saat</span>`;
    } else if (pushStatus.startsWith('skipped_category_limit')) {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-orange-100 text-orange-800 dark:bg-orange-950/40 dark:text-orange-400"><span class="w-1.5 h-1.5 rounded-full bg-orange-500"></span>Limit Aşıldı</span>`;
    } else if (pushStatus === 'disabled_by_user_master_switch' || pushStatus.startsWith('disabled_by_user_group')) {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-gray-100 text-gray-800 dark:bg-gray-800/60 dark:text-gray-400"><span class="w-1.5 h-1.5 rounded-full bg-gray-400"></span>Tercih Kapalı</span>`;
    } else if (pushStatus === 'disabled_by_system_master_switch') {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800 dark:bg-red-950/40 dark:text-red-400"><span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>Sistem Kapalı</span>`;
    } else if (pushStatus === 'no_active_devices' || pushStatus === 'skipped_no_active_devices') {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-800 dark:bg-slate-800/50 dark:text-slate-400"><span class="w-1.5 h-1.5 rounded-full bg-slate-400"></span>Cihaz Yok</span>`;
    } else if (pushStatus === 'disabled_permanently_for_submission_status') {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-slate-100 text-slate-700 dark:bg-slate-800/50 dark:text-slate-400"><span class="w-1.5 h-1.5 rounded-full bg-slate-400"></span>Sessiz İletim</span>`;
    } else {
        statusBadge = `<span class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full text-xs font-semibold bg-red-100 text-red-800 dark:bg-red-950/40 dark:text-red-400"><span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>Hata</span>`;
    }

    content.innerHTML = `
        <!-- 1. Bildirim Önizleme Kartı -->
        <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-900/50 border border-slate-200/80 dark:border-slate-800 space-y-1.5">
            <div class="flex items-center justify-between gap-2">
                <span class="text-slate-400 uppercase font-bold text-[10px] tracking-wider">Bildirim Önizlemesi</span>
                <span class="px-2 py-0.5 rounded text-[10px] font-bold bg-primary/10 text-primary dark:bg-primary/20 dark:text-blue-300">Uygulama İçi & Push</span>
            </div>
            <div class="font-bold text-sm text-slate-900 dark:text-white">${escapeHtml(item.title || 'Başlık Belirtilmemiş')}</div>
            <div class="text-slate-600 dark:text-slate-300 text-xs leading-relaxed break-words">${escapeHtml(item.body || 'İçerik Belirtilmemiş')}</div>
        </div>

        <!-- 2. Doküman ve Hedef Bilgileri (Geniş & Güvenli Satırlar) -->
        <div class="space-y-2.5">
            <!-- Doküman ID (Tam Genişlik) -->
            <div class="p-3 bg-slate-50 dark:bg-slate-900/40 rounded-xl border border-slate-200/80 dark:border-slate-800">
                <div class="flex items-center justify-between gap-2 mb-1">
                    <span class="text-slate-400 uppercase font-bold text-[10px] tracking-wider">Doküman ID (Firestore)</span>
                    <button type="button" onclick="copyToClipboard('${escapeHtml(item.id)}', this)" class="inline-flex items-center gap-1 text-[11px] text-slate-500 hover:text-primary transition-colors font-medium cursor-pointer">
                        <span class="material-symbols-outlined text-[13px]">content_copy</span> Kopyala
                    </button>
                </div>
                <div class="font-mono text-xs text-slate-900 dark:text-slate-200 bg-white dark:bg-surface-darker px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-800 break-all select-all font-semibold">
                    ${escapeHtml(item.id)}
                </div>
            </div>

            <!-- Alıcı ve Fırsat Bilgileri (2 Kolon) -->
            <div class="grid grid-cols-1 md:grid-cols-2 gap-2.5">
                <div class="p-3 bg-slate-50 dark:bg-slate-900/40 rounded-xl border border-slate-200/80 dark:border-slate-800 min-w-0">
                    <span class="text-slate-400 uppercase font-bold text-[10px] tracking-wider block mb-1">Alıcı Kullanıcı UID</span>
                    <div class="flex items-center justify-between gap-2 bg-white dark:bg-surface-darker px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-800 min-w-0">
                        <span class="font-mono text-xs text-slate-900 dark:text-slate-200 break-all select-all font-semibold truncate" title="${escapeHtml(item.userUid || '-')}">${escapeHtml(item.userUid || '-')}</span>
                        ${item.userUid && item.userUid !== 'Bilinmeyen' ? `
                        <button type="button" onclick="closeNotificationDetail(); showUserDetail('${item.userUid}')" class="shrink-0 px-2 py-0.5 rounded text-[11px] font-bold bg-primary/10 text-primary hover:bg-primary/20 transition-colors flex items-center gap-0.5" title="Kullanıcı Profilini Aç">
                            <span class="material-symbols-outlined text-[13px]">person</span> Profil
                        </button>` : ''}
                    </div>
                </div>

                <div class="p-3 bg-slate-50 dark:bg-slate-900/40 rounded-xl border border-slate-200/80 dark:border-slate-800 min-w-0">
                    <span class="text-slate-400 uppercase font-bold text-[10px] tracking-wider block mb-1">İlişkili Fırsat</span>
                    <div class="flex items-center justify-between gap-2 bg-white dark:bg-surface-darker px-3 py-2 rounded-lg border border-slate-200 dark:border-slate-800 min-w-0">
                        <span class="font-mono text-xs text-primary font-bold break-all select-all truncate" title="${item.dealId ? '#' + escapeHtml(item.dealId) : 'Yok'}">${item.dealId ? '#' + escapeHtml(item.dealId) : 'Yok'}</span>
                        ${item.dealId ? `
                        <button type="button" onclick="closeNotificationDetail(); openDealEditModal('${item.dealId}')" class="shrink-0 px-2 py-0.5 rounded text-[11px] font-bold bg-blue-50 dark:bg-blue-950/40 text-blue-600 dark:text-blue-300 hover:bg-blue-100 transition-colors flex items-center gap-0.5" title="Fırsatı İncele">
                            <span class="material-symbols-outlined text-[13px]">open_in_new</span> İncele
                        </button>` : ''}
                    </div>
                </div>
            </div>
        </div>

        <!-- 3. Dağıtım Metrikleri Grid (4'lü Panel) -->
        <div class="grid grid-cols-2 md:grid-cols-4 gap-2.5 bg-slate-50 dark:bg-slate-900/40 p-4 rounded-xl border border-slate-200/80 dark:border-slate-800 font-sans text-xs">
            <div class="min-w-0">
                <span class="text-slate-400 uppercase font-bold text-[10px] block mb-1">Tür (Type)</span>
                <span class="inline-block font-semibold px-2 py-0.5 rounded bg-slate-100 dark:bg-slate-800 text-slate-900 dark:text-white truncate">${escapeHtml(item.type || '-')}</span>
            </div>
            <div class="min-w-0">
                <span class="text-slate-400 uppercase font-bold text-[10px] block mb-1">Sebep (Reason)</span>
                <span class="inline-block font-semibold px-2 py-0.5 rounded bg-purple-100 dark:bg-purple-950/40 text-purple-800 dark:text-purple-300 truncate" title="${escapeHtml(item.reason || '-')} ${item.reasonDetail ? '(' + escapeHtml(item.reasonDetail) + ')' : ''}">${escapeHtml(item.reason || '-')}</span>
            </div>
            <div class="min-w-0">
                <span class="text-slate-400 uppercase font-bold text-[10px] block mb-1">Push Uygunluğu</span>
                <span class="inline-flex items-center gap-1 font-semibold px-2 py-0.5 rounded ${item.pushEligible ? 'bg-emerald-100 text-emerald-800 dark:bg-emerald-950/40 dark:text-emerald-400' : 'bg-rose-100 text-rose-800 dark:bg-rose-950/40 dark:text-rose-400'}">
                    <span class="w-1.5 h-1.5 rounded-full ${item.pushEligible ? 'bg-emerald-500' : 'bg-rose-500'}"></span>
                    ${item.pushEligible ? 'Uygun' : 'Engellendi'}
                </span>
            </div>
            <div class="min-w-0">
                <span class="text-slate-400 uppercase font-bold text-[10px] block mb-1">Push Durumu</span>
                <div class="truncate">${statusBadge}</div>
            </div>
            <div class="col-span-2 min-w-0 pt-2 border-t border-slate-200/60 dark:border-slate-800/80">
                <span class="text-slate-400 uppercase font-bold text-[10px] block mb-0.5">Oluşturulma Zamanı</span>
                <span class="text-slate-700 dark:text-slate-300 font-mono text-[11px]">${createdAtStr}</span>
            </div>
            <div class="col-span-2 min-w-0 pt-2 border-t border-slate-200/60 dark:border-slate-800/80">
                <span class="text-slate-400 uppercase font-bold text-[10px] block mb-0.5">İletilme Zamanı</span>
                <span class="text-slate-700 dark:text-slate-300 font-mono text-[11px]">${sentAtStr}</span>
            </div>
            ${item.error ? `
            <div class="col-span-2 md:col-span-4 p-3 rounded-lg bg-rose-50 dark:bg-rose-950/30 text-rose-600 dark:text-rose-400 text-xs font-mono border border-rose-200 dark:border-rose-900/50">
                <strong>Hata Logu:</strong> ${escapeHtml(item.error)}
            </div>` : ''}
        </div>

        <!-- 4. Çoklu Eşleşme Nedenleri (Reasons Haritası) -->
        <div class="p-4 rounded-xl bg-slate-50 dark:bg-slate-900/40 border border-slate-200/80 dark:border-slate-800 space-y-2">
            <div class="flex items-center justify-between gap-2">
                <div>
                    <span class="text-slate-500 dark:text-slate-400 font-bold uppercase text-[10px] block">Çoklu Eşleşme Nedenleri (Reasons Haritası)</span>
                    <p class="text-[11px] text-slate-400 dark:text-slate-500">Wilson skoru ve tekilleştirme motorunun bildirim üretirken eşleştirdiği kriterler</p>
                </div>
                <button type="button" onclick="copyToClipboard('${escapeHtml(reasonsJson)}', this)" class="inline-flex items-center gap-1 text-[11px] text-slate-500 hover:text-primary transition-colors font-medium cursor-pointer">
                    <span class="material-symbols-outlined text-[13px]">content_copy</span> JSON Kopyala
                </button>
            </div>
            <pre class="p-3.5 bg-slate-900 text-emerald-400 rounded-xl overflow-x-auto text-xs font-mono leading-relaxed border border-slate-800">${escapeHtml(reasonsJson)}</pre>
        </div>
    `;

    modal.classList.remove('hidden');

    const handleEsc = (e) => {
        if (e.key === 'Escape') {
            closeNotificationDetail();
            document.removeEventListener('keydown', handleEsc);
        }
    };
    document.addEventListener('keydown', handleEsc);
}

function closeNotificationDetail() {
    const modal = document.getElementById('notifDetailModal');
    if (modal) modal.classList.add('hidden');
}

async function loadNotificationLogsFallback(reset = false) {
    console.log(`🔔 Loading fallback notification logs from root collection (Page: ${notifCurrentPage})...`);
    const tbody = document.getElementById('notifLogsTableBody');
    if (!tbody) return;

    try {
        let query = db.collection('notificationLogs').orderBy('sentAt', 'desc');
        const cursor = notifCursorStack[notifCurrentPage - 1];
        if (cursor && notifCurrentPage > 1) {
            query = query.startAfter(cursor);
        }
        query = query.limit(notifPageSize + 1);

        const snapshot = await query.get();

        if (snapshot.empty) {
            cachedNotificationsList = [];
            notifHasMore = false;
            tbody.innerHTML = `<tr><td colspan="6" class="px-3 py-10 text-center text-slate-400 dark:text-slate-600">Gönderilmiş bildirim bulunmuyor.</td></tr>`;
            updateNotifPaginationUI(0);
            return;
        }

        const totalDocs = snapshot.docs;
        let pageDocs = totalDocs;
        if (totalDocs.length > notifPageSize) {
            notifHasMore = true;
            pageDocs = totalDocs.slice(0, notifPageSize);
            notifCursorStack[notifCurrentPage] = pageDocs[pageDocs.length - 1];
        } else {
            notifHasMore = false;
        }

        cachedNotificationsList = pageDocs.map(doc => ({ id: doc.id, ...doc.data() }));

        let html = '';
        pageDocs.forEach(doc => {
            const data = doc.data();
            const date = data.sentAt ? (data.sentAt.toDate ? data.sentAt.toDate().toLocaleString('tr-TR') : new Date(data.sentAt).toLocaleString('tr-TR')) : '-';
            const statusBadge = data.status === 'success' 
                ? `<span class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-semibold bg-emerald-100 text-emerald-800 dark:bg-emerald-900/20 dark:text-emerald-400"><span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>Başarılı</span>`
                : `<span title="${data.error || 'Bilinmeyen hata'}" class="inline-flex items-center gap-1.5 px-2 py-0.5 rounded-full text-xs font-semibold bg-red-100 text-red-800 dark:bg-red-900/20 dark:text-red-400 cursor-help"><span class="w-1.5 h-1.5 rounded-full bg-red-500"></span>Hata</span>`;
            
            let targetText = '-';
            if (data.targetType === 'all') {
                targetText = 'Tüm Kullanıcılar';
            } else if (data.targetType === 'uid') {
                targetText = `UID: ${data.targetValue.substring(0, 8)}...`;
            } else if (data.targetType === 'token') {
                targetText = `Token: ${data.targetValue.substring(0, 8)}...`;
            }

            html += `
                <tr class="hover:bg-slate-50 dark:hover:bg-surface-darker/50 transition-colors">
                    <td class="px-3.5 py-3 whitespace-nowrap text-xs font-semibold text-slate-600 dark:text-slate-400">${date}</td>
                    <td class="px-3.5 py-3 whitespace-nowrap text-xs text-slate-900 dark:text-white">${targetText}</td>
                    <td class="px-3.5 py-3 text-xs text-slate-900 dark:text-white min-w-[260px]">
                        <div class="font-bold">${escapeHtml(data.title)}</div>
                        <div class="text-slate-500 dark:text-slate-400 text-xs mt-0.5">${escapeHtml(data.body)}</div>
                    </td>
                    <td class="px-3.5 py-3 whitespace-nowrap text-xs text-slate-500 dark:text-slate-400"><span class="px-1.5 py-0.5 rounded text-[10px] font-bold bg-slate-100 text-slate-800 dark:bg-slate-800/40 dark:text-slate-400">Manuel</span></td>
                    <td class="px-3.5 py-3 whitespace-nowrap text-xs">${statusBadge}</td>
                    <td class="px-3.5 py-3 whitespace-nowrap text-xs text-right">-</td>
                </tr>
            `;
        });
        tbody.innerHTML = html;
        updateNotifPaginationUI(pageDocs.length);
    } catch (error) {
        console.error('❌ Error loading fallback notification logs:', error);
        tbody.innerHTML = `<tr><td colspan="6" class="px-3 py-10 text-center text-red-500">Loglar yüklenirken hata oluştu: ${error.message}</td></tr>`;
        updateNotifPaginationUI(0);
    }
}

async function loadNotificationStats() {
    console.log('📈 Loading notification stats & trend chart...');
    const last7Days = [];
    const now = new Date();

    for (let i = 6; i >= 0; i--) {
        const d = new Date();
        d.setDate(now.getDate() - i);
        d.setHours(0, 0, 0, 0);

        const year = d.getFullYear();
        const month = String(d.getMonth() + 1).padStart(2, '0');
        const day = String(d.getDate()).padStart(2, '0');
        const dateStr = `${year}-${month}-${day}`;
        const label = `${day}/${month}`;
        last7Days.push({ date: d, dateStr, label, count: 0 });
    }

    try {
        // 1. notificationStats koleksiyonunu sorgula
        const promises = last7Days.map(async (day) => {
            try {
                const doc = await db.collection('notificationStats').doc(day.dateStr).get();
                if (doc.exists) {
                    day.count = doc.data().count || 0;
                }
            } catch (_) {}
        });
        await Promise.all(promises);

        // 2. Canlı veritabanı ile çapraz kontrol (collectionGroup veya cached veriden)
        const sevenDaysAgo = new Date();
        sevenDaysAgo.setDate(now.getDate() - 7);
        sevenDaysAgo.setHours(0, 0, 0, 0);

        try {
            const recentNotifsSnap = await db.collectionGroup('notifications')
                .where('createdAt', '>=', sevenDaysAgo)
                .get();

            if (!recentNotifsSnap.empty) {
                const dynamicCounts = {};
                recentNotifsSnap.forEach(doc => {
                    const data = doc.data();
                    if (data.pushStatus === 'sent' || data.pushStatus === 'success') {
                        const dt = data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt);
                        const y = dt.getFullYear();
                        const m = String(dt.getMonth() + 1).padStart(2, '0');
                        const dayNum = String(dt.getDate()).padStart(2, '0');
                        const ds = `${y}-${m}-${dayNum}`;
                        dynamicCounts[ds] = (dynamicCounts[ds] || 0) + 1;
                    }
                });

                last7Days.forEach(day => {
                    if (dynamicCounts[day.dateStr]) {
                        day.count = Math.max(day.count, dynamicCounts[day.dateStr]);
                    }
                });
            }
        } catch (cgErr) {
            console.warn('⚠️ collectionGroup live count fallback note:', cgErr.message);
            cachedNotificationsList.forEach(data => {
                if (data.pushStatus === 'sent' || data.pushStatus === 'success') {
                    const dt = data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt);
                    const y = dt.getFullYear();
                    const m = String(dt.getMonth() + 1).padStart(2, '0');
                    const dayNum = String(dt.getDate()).padStart(2, '0');
                    const ds = `${y}-${m}-${dayNum}`;
                    const match = last7Days.find(d => d.dateStr === ds);
                    if (match) match.count++;
                }
            });
        }
    } catch (err) {
        console.warn('⚠️ Notification stats fetch error:', err.message);
    }

    const chartCanvas = document.getElementById('notifTrendChart');
    if (!chartCanvas) return;
    const ctx = chartCanvas.getContext('2d');

    if (notifTrendChartInstance) {
        notifTrendChartInstance.destroy();
    }

    notifTrendChartInstance = new Chart(ctx, {
        type: 'line',
        data: {
            labels: last7Days.map(d => d.label),
            datasets: [{
                label: 'Gönderilen Push Bildirimi',
                data: last7Days.map(d => d.count),
                backgroundColor: 'rgba(139, 92, 246, 0.12)',
                borderColor: 'rgb(139, 92, 246)',
                borderWidth: 2.5,
                fill: true,
                tension: 0.35,
                pointBackgroundColor: 'rgb(139, 92, 246)',
                pointBorderColor: '#fff',
                pointBorderWidth: 1.5,
                pointRadius: 4,
                pointHoverRadius: 6
            }]
        },
        options: {
            responsive: true,
            maintainAspectRatio: false,
            plugins: {
                legend: { display: false },
                tooltip: {
                    callbacks: {
                        label: function(context) {
                            return ` Gönderilen: ${context.parsed.y} adet push`;
                        }
                    }
                }
            },
            scales: {
                y: {
                    beginAtZero: true,
                    ticks: {
                        stepSize: 1,
                        color: 'rgba(156, 163, 175, 0.8)',
                        precision: 0
                    },
                    grid: {
                        color: 'rgba(156, 163, 175, 0.1)'
                    }
                },
                x: {
                    ticks: {
                        color: 'rgba(156, 163, 175, 0.8)'
                    },
                    grid: {
                        display: false
                    }
                }
            }
        }
    });
}

function initNotificationEventListeners() {
    console.log('🔔 Initializing Notification Event Listeners...');

    // Sidebar navigation hook
    const notificationsMenuBtn = document.getElementById('notificationsMenuBtn');
    if (notificationsMenuBtn) {
        notificationsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showNotificationsView();
        });
    }

    // Global Notification Master Switch Button
    const toggleNotifEngineBtn = document.getElementById('toggleNotifEngineBtn');
    if (toggleNotifEngineBtn) {
        toggleNotifEngineBtn.addEventListener('click', () => {
            toggleGlobalNotificationState();
        });
    }

    // Category Rate Limits Save Button
    const saveNotifLimitsBtn = document.getElementById('saveNotifLimitsBtn');
    if (saveNotifLimitsBtn) {
        saveNotifLimitsBtn.addEventListener('click', () => {
            saveCategoryLimitsFromNotifs();
        });
    }

    // 30+ Day Retention Purge Button
    const purgeOldNotifsBtn = document.getElementById('purgeOldNotifsBtn');
    if (purgeOldNotifsBtn) {
        purgeOldNotifsBtn.addEventListener('click', () => {
            purgeOldNotificationsAction();
        });
    }

    // Target selection logic
    const notifTargetType = document.getElementById('notifTargetType');
    const notifTargetValueWrapper = document.getElementById('notifTargetValueWrapper');
    const notifTargetValueLabel = document.getElementById('notifTargetValueLabel');
    const notifTargetValue = document.getElementById('notifTargetValue');

    if (notifTargetType && notifTargetValueWrapper && notifTargetValueLabel && notifTargetValue) {
        notifTargetType.addEventListener('change', () => {
            const val = notifTargetType.value;
            if (val === 'all') {
                notifTargetValueWrapper.classList.add('hidden');
                notifTargetValue.required = false;
            } else {
                notifTargetValueWrapper.classList.remove('hidden');
                notifTargetValue.required = true;
                if (val === 'uid') {
                    notifTargetValueLabel.textContent = 'Hedef Kullanıcı UID';
                    notifTargetValue.placeholder = 'Kullanıcı UID değerini girin';
                } else {
                    notifTargetValueLabel.textContent = 'FCM Cihaz Token\'ı';
                    notifTargetValue.placeholder = 'FCM Token değerini girin';
                }
            }
        });
    }

    // Notification sending submit form (with dealId & notificationCategory support)
    const manualNotifForm = document.getElementById('manualNotifForm');
    if (manualNotifForm) {
        manualNotifForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const title = document.getElementById('notifTitle').value.trim();
            const body = document.getElementById('notifBody').value.trim();
            const imageUrl = document.getElementById('notifImageUrl')?.value.trim() || '';
            const dealId = document.getElementById('notifDealId')?.value.trim() || '';
            const notificationCategory = document.getElementById('notifCategoryType')?.value || 'admin_message';
            const targetType = document.getElementById('notifTargetType').value;
            const targetValue = notifTargetValue ? notifTargetValue.value.trim() : '';

            const sendBtn = document.getElementById('sendNotifBtn');
            if (sendBtn) {
                sendBtn.disabled = true;
                sendBtn.innerHTML = '<span class="material-symbols-outlined animate-spin text-[18px]">sync</span><span>Gönderiliyor...</span>';
            }

            try {
                const sendFn = firebase.functions().httpsCallable('sendManualNotification');
                await sendFn({ title, body, imageUrl, dealId, targetType, targetValue, notificationCategory });
                showSuccess('✅ Bildirim başarıyla sıraya alındı ve gönderildi!');
                manualNotifForm.reset();
                if (notifTargetValueWrapper) notifTargetValueWrapper.classList.add('hidden');
            } catch (err) {
                console.error('❌ Error sending manual notification:', err);
                showError('Bildirim gönderme hatası: ' + err.message);
            } finally {
                if (sendBtn) {
                     sendBtn.disabled = false;
                     sendBtn.innerHTML = '<span class="material-symbols-outlined text-[18px]">send</span><span>Bildirim Gönder</span>';
                }
            }
        });
    }

    // Clean tokens click event
    const cleanTokensBtn = document.getElementById('cleanTokensBtn');
    const cleanTokensResult = document.getElementById('cleanTokensResult');

    if (cleanTokensBtn) {
        cleanTokensBtn.addEventListener('click', async () => {
            cleanTokensBtn.disabled = true;
            cleanTokensBtn.innerHTML = '<span class="material-symbols-outlined animate-spin text-[18px]">sync</span><span>Temizleniyor...</span>';
            if (cleanTokensResult) cleanTokensResult.classList.add('hidden');

            try {
                const cleanupFn = firebase.functions().httpsCallable('cleanupInvalidTokens');
                const res = await cleanupFn();
                if (cleanTokensResult) {
                    cleanTokensResult.classList.remove('hidden');
                    cleanTokensResult.textContent = `🧹 Temizlik tamamlandı! Kontrol edilen: ${res.data.checkedCount}, Temizlenen: ${res.data.cleanedCount}`;
                }
                showSuccess('✅ Token temizlik işlemi tamamlandı!');
            } catch (err) {
                console.error('❌ Error cleaning tokens:', err);
                showError('Token temizleme hatası: ' + err.message);
            } finally {
                cleanTokensBtn.disabled = false;
                cleanTokensBtn.innerHTML = '<span class="material-symbols-outlined text-[16px]">delete_sweep</span><span>Temizle</span>';
            }
        });
    }

    // Filter by channel / reason
    const notifChannelFilter = document.getElementById('notifChannelFilter');
    if (notifChannelFilter) {
        notifChannelFilter.addEventListener('change', (e) => {
            currentChannelFilter = e.target.value;
            renderNotificationLogsTable();
        });
    }

    // Filter by push status
    const notifStatusFilter = document.getElementById('notifStatusFilter');
    if (notifStatusFilter) {
        notifStatusFilter.addEventListener('change', (e) => {
            currentNotifFilter = e.target.value;
            renderNotificationLogsTable();
        });
    }

    // Page size selector
    const notifPageSizeSelect = document.getElementById('notifPageSizeSelect');
    if (notifPageSizeSelect) {
        notifPageSizeSelect.addEventListener('change', (e) => {
            notifPageSize = parseInt(e.target.value, 10) || 50;
            loadNotificationLogs(true);
        });
    }

    // Previous page button
    const notifPrevPageBtn = document.getElementById('notifPrevPageBtn');
    if (notifPrevPageBtn) {
        notifPrevPageBtn.addEventListener('click', () => {
            if (notifCurrentPage > 1 && !notifIsLoading) {
                notifCurrentPage--;
                loadNotificationLogs(false);
            }
        });
    }

    // Next page button
    const notifNextPageBtn = document.getElementById('notifNextPageBtn');
    if (notifNextPageBtn) {
        notifNextPageBtn.addEventListener('click', () => {
            if (notifHasMore && !notifIsLoading) {
                notifCurrentPage++;
                loadNotificationLogs(false);
            }
        });
    }

    // Refresh logs button
    const refreshNotifLogsBtn = document.getElementById('refreshNotifLogsBtn');
    if (refreshNotifLogsBtn) {
        refreshNotifLogsBtn.addEventListener('click', async () => {
            const icon = refreshNotifLogsBtn.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('animate-spin');
            try {
                await loadNotificationLogs(true);
                showSuccess('Bildirim akışı güncellendi');
            } finally {
                if (icon) icon.classList.remove('animate-spin');
            }
        });
    }

    // Close detail modal events
    const closeNotifDetailModal = document.getElementById('closeNotifDetailModal');
    const closeNotifDetailModalBtn = document.getElementById('closeNotifDetailModalBtn');
    if (closeNotifDetailModal) closeNotifDetailModal.addEventListener('click', closeNotificationDetail);
    if (closeNotifDetailModalBtn) closeNotifDetailModalBtn.addEventListener('click', closeNotificationDetail);
}

window.showNotificationsView = showNotificationsView;
window.openNotificationDetail = openNotificationDetail;
window.closeNotificationDetail = closeNotificationDetail;

// =========================================================================
// FAZ 4 - SİSTEM HATA LOGLARI & GELİŞMİŞ AYARLAR (SYSTEM ERRORS DASHBOARD - KIBANA/DATADOG APM)
// =========================================================================================

let systemErrorsUnsubscribe = null;
let allErrorsList = [];
let currentLogCategoryTab = 'all';
let currentSelectedError = null;

// Gelişmiş APM Filtre Durumları
let selectedLogUserIdFilter = null;
let selectedLogUserObj = null;
let selectedLogTimeRange = 'all';
let selectedLogPlatform = 'all';
let logFilterUsersCache = [];

function showLogsView() {
    currentView = 'logs';
    showView('logsView');
    updateMenuActiveState('logs');
    loadSystemLogs();
    loadUsersForLogFilter();
}

function getAdminCurrentEnvironment() {
    if (typeof selectedEnv !== 'undefined' && selectedEnv) {
        return selectedEnv;
    }
    if (typeof firebaseConfig !== 'undefined' && firebaseConfig.projectId) {
        return firebaseConfig.projectId.includes('prod') ? 'prod' : 'dev';
    }
    return 'dev';
}

function loadSystemLogs() {
    console.log('🐛 Loading modernized system logs...');
    if (systemErrorsUnsubscribe) {
        systemErrorsUnsubscribe();
    }

    const currentEnv = getAdminCurrentEnvironment();
    const envBadge = document.getElementById('logsEnvBadge');
    if (envBadge) {
        envBadge.textContent = currentEnv.toUpperCase();
        if (currentEnv === 'prod') {
            envBadge.className = 'px-2.5 py-0.5 rounded-full text-xs font-black bg-rose-100 text-rose-800 dark:bg-rose-950/50 dark:text-rose-400 border border-rose-300 dark:border-rose-800';
        } else {
            envBadge.className = 'px-2.5 py-0.5 rounded-full text-xs font-black bg-emerald-100 text-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-400 border border-emerald-300 dark:border-emerald-800';
        }
    }

    const tbody = document.getElementById('logsTableBody');
    if (tbody) {
        tbody.innerHTML = `<tr><td colspan="6" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400"><div class="flex flex-col items-center gap-2"><span class="material-symbols-outlined text-4xl opacity-50 animate-spin">sync</span><p>Sistem logları yükleniyor...</p></div></td></tr>`;
    }

    systemErrorsUnsubscribe = db.collection('systemErrors')
        .orderBy('createdAt', 'desc')
        .limit(200)
        .onSnapshot((snapshot) => {
            allErrorsList = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
            console.log(`🐛 Received ${allErrorsList.length} systemErrors from Firestore.`);
            renderSystemLogs();
        }, (error) => {
            console.error('❌ Error loading system logs:', error);
            if (tbody) {
                tbody.innerHTML = `<tr><td colspan="6" class="px-6 py-12 text-center text-red-500">Loglar yüklenirken hata oluştu: ${error.message}</td></tr>`;
            }
        });
}

// -------------------------------------------------------------
// KIBANA APM - KULLANICI ARAMA & FİLTRELEME MOTORU
// -------------------------------------------------------------
async function loadUsersForLogFilter() {
    try {
        if (typeof users !== 'undefined' && Array.isArray(users) && users.length > 0) {
            logFilterUsersCache = users.map(u => ({
                id: u.id || u.uid,
                uid: u.uid || u.id,
                displayName: u.displayName || u.username || u.nickname || 'İsimsiz Kullanıcı',
                nickname: u.nickname || '',
                email: u.email || '',
                profileImageUrl: u.profileImageUrl || ''
            }));
            renderLogsUserDropdownList('');
            return;
        }

        const snapshot = await db.collection('users').limit(100).get();
        logFilterUsersCache = snapshot.docs.map(doc => {
            const data = doc.data();
            return {
                id: doc.id,
                uid: data.uid || doc.id,
                displayName: data.displayName || data.username || data.nickname || 'İsimsiz Kullanıcı',
                nickname: data.nickname || '',
                email: data.email || '',
                profileImageUrl: typeof cleanProfileImageUrl === 'function' ? cleanProfileImageUrl(data.profileImageUrl) : (data.profileImageUrl || '')
            };
        });
        renderLogsUserDropdownList('');
    } catch (err) {
        console.warn('⚠️ Log kullanıcıları önbelleğe alınamadı:', err);
    }
}

window.toggleLogsUserDropdown = function() {
    const popover = document.getElementById('logsUserDropdownPopover');
    if (!popover) return;
    const isHidden = popover.classList.contains('hidden');
    if (isHidden) {
        popover.classList.remove('hidden');
        if (logFilterUsersCache.length === 0) {
            loadUsersForLogFilter();
        } else {
            renderLogsUserDropdownList(document.getElementById('logsUserSearchInput')?.value || '');
        }
        const searchInp = document.getElementById('logsUserSearchInput');
        if (searchInp) setTimeout(() => searchInp.focus(), 50);
    } else {
        popover.classList.add('hidden');
    }
};

window.closeLogsUserDropdown = function() {
    const popover = document.getElementById('logsUserDropdownPopover');
    if (popover) popover.classList.add('hidden');
};

window.renderLogsUserDropdownList = function(query = '') {
    const listEl = document.getElementById('logsUserDropdownList');
    if (!listEl) return;

    const q = (query || '').trim().toLowerCase();
    const filtered = logFilterUsersCache.filter(u => {
        if (!q) return true;
        const target = `${u.displayName} ${u.nickname} ${u.email} ${u.uid}`.toLowerCase();
        return target.includes(q);
    });

    let html = `
        <button type="button" onclick="window.clearUserLogFilter()" class="w-full flex items-center gap-2.5 p-2 rounded-xl text-left hover:bg-slate-100 dark:hover:bg-slate-800 transition-colors text-slate-600 dark:text-slate-300 font-bold border-b border-slate-100 dark:border-slate-800 mb-1">
            <span class="material-symbols-outlined text-[18px] text-slate-400">group</span>
            <span>Tüm Kullanıcılar (Filtreyi Temizle)</span>
        </button>
    `;

    if (filtered.length === 0) {
        html += `<div class="p-3 text-center text-slate-400 text-xs">Aramaya uygun kullanıcı bulunamadı.</div>`;
    } else {
        filtered.forEach(u => {
            const avatarSrc = u.profileImageUrl || '/assets/icons/avatar_default.png';
            const isSelected = selectedLogUserIdFilter === u.uid;
            const activeBg = isSelected ? 'bg-primary/10 border-primary/30 text-primary' : 'hover:bg-slate-50 dark:hover:bg-slate-800/60 text-slate-800 dark:text-slate-200 border-transparent';

            html += `
                <button type="button" onclick="window.filterLogsByUser('${u.uid}')" class="w-full flex items-center gap-2.5 p-2 rounded-xl text-left transition-colors border ${activeBg}">
                    <img src="${avatarSrc}" class="w-7 h-7 rounded-full object-cover border border-slate-200 dark:border-slate-700 shrink-0 bg-white" onerror="this.onerror=null; this.src='/assets/icons/avatar_default.png';" />
                    <div class="min-w-0 flex-1">
                        <div class="font-bold text-xs truncate">${escapeHtml(u.displayName)}</div>
                        <div class="text-[10px] text-slate-400 font-mono truncate">${u.uid}</div>
                    </div>
                    ${isSelected ? '<span class="material-symbols-outlined text-primary text-[16px]">check</span>' : ''}
                </button>
            `;
        });
    }

    listEl.innerHTML = html;
};

window.filterLogsByUser = function(uid, userObj = null) {
    selectedLogUserIdFilter = uid;
    
    if (!userObj) {
        userObj = logFilterUsersCache.find(u => u.uid === uid || u.id === uid) || {
            uid,
            displayName: uid.substring(0, 8),
            profileImageUrl: ''
        };
    }
    selectedLogUserObj = userObj;

    const btnText = document.getElementById('logsUserDropdownBtnText');
    if (btnText) {
        btnText.textContent = `👤 ${userObj.displayName || userObj.nickname || uid.substring(0, 8)}`;
    }

    window.closeLogsUserDropdown();

    // Active User Banner Güncelle
    const banner = document.getElementById('logsActiveUserBanner');
    const bannerName = document.getElementById('logsActiveUserName');
    const bannerUid = document.getElementById('logsActiveUserUid');
    const bannerAvatar = document.getElementById('logsActiveUserAvatar');

    if (banner) {
        banner.classList.remove('hidden');
        if (bannerName) bannerName.textContent = userObj.displayName || userObj.nickname || 'Kullanıcı';
        if (bannerUid) bannerUid.textContent = uid;
        if (bannerAvatar) {
            bannerAvatar.onerror = function() { this.onerror = null; this.src = '/assets/icons/avatar_default.png'; };
            bannerAvatar.src = userObj.profileImageUrl || '/assets/icons/avatar_default.png';
        }
    }

    renderSystemLogs();
};

window.clearUserLogFilter = function() {
    selectedLogUserIdFilter = null;
    selectedLogUserObj = null;

    const btnText = document.getElementById('logsUserDropdownBtnText');
    if (btnText) btnText.textContent = '👤 Kullanıcı: Tümü';

    const banner = document.getElementById('logsActiveUserBanner');
    if (banner) banner.classList.add('hidden');

    window.closeLogsUserDropdown();
    renderSystemLogs();
};

window.deepSearchUserLogs = async function() {
    if (!selectedLogUserIdFilter) return;

    const btn = document.getElementById('logsDeepSearchBtn');
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<span class="material-symbols-outlined text-[16px] animate-spin">sync</span><span>Taranıyor...</span>';
    }

    try {
        console.log(`🔎 Firestore'dan ${selectedLogUserIdFilter} kullanıcısına ait tüm geçmiş hatalar sorgulanıyor...`);
        const snapshot = await db.collection('systemErrors')
            .where('userId', '==', selectedLogUserIdFilter)
            .limit(50)
            .get();

        let addedCount = 0;
        snapshot.forEach(doc => {
            if (!allErrorsList.some(e => e.id === doc.id)) {
                allErrorsList.unshift({ id: doc.id, ...doc.data() });
                addedCount++;
            }
        });

        renderSystemLogs();
        if (addedCount > 0) {
            showSuccess(`🔎 Firestore'dan geçmiş ${addedCount} adet hata kaydı hafızaya çekildi.`);
        } else {
            showSuccess(`Geçmiş kayıtlarda bu kullanıcıya ait ek hata bulunamadı.`);
        }
    } catch (err) {
        console.error('❌ Derin kullanıcı hata araması başarısız:', err);
        showError('Geçmiş hata taraması yapılamadı: ' + err.message);
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<span class="material-symbols-outlined text-[16px]">travel_explore</span><span>Tüm Geçmişte Ara</span>';
        }
    }
};

window.resetAllLogFilters = function() {
    const searchInp = document.getElementById('logsSearchInput');
    if (searchInp) searchInp.value = '';

    const timeRangeFilter = document.getElementById('logsTimeRangeFilter');
    if (timeRangeFilter) timeRangeFilter.value = 'all';
    selectedLogTimeRange = 'all';

    const platformFilter = document.getElementById('logsPlatformFilter');
    if (platformFilter) platformFilter.value = 'all';
    selectedLogPlatform = 'all';

    const serviceFilter = document.getElementById('logsServiceFilter');
    if (serviceFilter) serviceFilter.value = 'all';

    const severityFilter = document.getElementById('logsSeverityFilter');
    if (severityFilter) severityFilter.value = 'all';

    const statusFilter = document.getElementById('logsStatusFilter');
    if (statusFilter) statusFilter.value = 'unresolved';

    const envFilter = document.getElementById('logsEnvironmentFilter');
    if (envFilter) envFilter.value = 'current';

    window.clearUserLogFilter();
    window.switchLogCategoryTab('all');
    showSuccess('Filtreler varsayılana sıfırlandı.');
};

window.switchLogCategoryTab = function(tabKey) {
    currentLogCategoryTab = tabKey;
    document.querySelectorAll('.log-tab-btn').forEach(btn => {
        btn.className = 'log-tab-btn flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all text-slate-600 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-slate-800 shrink-0';
    });
    const activeBtn = document.getElementById(`logTab-${tabKey}`);
    if (activeBtn) {
        activeBtn.className = 'log-tab-btn flex items-center gap-1.5 px-3.5 py-2 rounded-xl text-xs font-bold transition-all bg-primary text-white shadow-sm shadow-primary/20 shrink-0';
    }
    renderSystemLogs();
};

function renderSystemLogs() {
    const tbody = document.getElementById('logsTableBody');
    if (!tbody) return;

    const currentEnv = getAdminCurrentEnvironment();
    const searchVal = (document.getElementById('logsSearchInput')?.value || '').trim().toLowerCase();
    const serviceFilter = document.getElementById('logsServiceFilter')?.value || 'all';
    const severityFilter = document.getElementById('logsSeverityFilter')?.value || 'all';
    const statusFilter = document.getElementById('logsStatusFilter')?.value || 'unresolved';
    const envFilter = document.getElementById('logsEnvironmentFilter')?.value || 'current';
    const timeRangeFilter = document.getElementById('logsTimeRangeFilter')?.value || 'all';
    const platformFilter = document.getElementById('logsPlatformFilter')?.value || 'all';
    selectedLogTimeRange = timeRangeFilter;
    selectedLogPlatform = platformFilter;

    const now = new Date();

    // 1. Calculate Environment Matching
    const envFilteredList = allErrorsList.filter(e => {
        const itemEnv = e.environment || 'dev'; // Legacy logs default to dev
        if (envFilter === 'all') return true;
        if (envFilter === 'dev') return itemEnv === 'dev';
        if (envFilter === 'prod') return itemEnv === 'prod';
        return itemEnv === currentEnv; // 'current'
    });

    // 2. Calculate Category Tab Badges (based on current env)
    const categoryCounts = {
        all: envFilteredList.length,
        mobile: 0,
        scraper: 0,
        catalogs_coupons: 0,
        ai: 0,
        notifications: 0,
        backend: 0,
        admin: 0
    };

    envFilteredList.forEach(e => {
        const cat = e.category || e.service || 'backend';
        if (cat === 'mobile') categoryCounts.mobile++;
        else if (cat === 'scraper') categoryCounts.scraper++;
        else if (cat === 'catalogs_coupons') categoryCounts.catalogs_coupons++;
        else if (cat === 'ai') categoryCounts.ai++;
        else if (cat === 'notifications') categoryCounts.notifications++;
        else if (cat === 'backend' || cat === 'functions') categoryCounts.backend++;
        else if (cat === 'admin' || cat === 'web') categoryCounts.admin++;
        else if (e.service === 'bot') categoryCounts.scraper++;
        else categoryCounts.backend++;
    });

    Object.keys(categoryCounts).forEach(k => {
        const badge = document.getElementById(`logTabBadge-${k}`);
        if (badge) badge.textContent = categoryCounts[k];
    });

    // 3. Calculate 4 Bento Metric Cards (based on active environment)
    const unresolvedErrors = envFilteredList.filter(e => e.status === 'unresolved');
    const fatalErrors = envFilteredList.filter(e => e.status === 'unresolved' && e.severity === 'fatal');
    
    const oneDayAgo = new Date(now.getTime() - 24 * 60 * 60 * 1000);
    const todayErrors = envFilteredList.filter(e => {
        if (!e.createdAt) return false;
        const d = e.createdAt.toDate ? e.createdAt.toDate() : new Date(e.createdAt);
        return d >= oneDayAgo;
    });

    const statUnresolvedEl = document.getElementById('logsStatUnresolved');
    if (statUnresolvedEl) statUnresolvedEl.textContent = unresolvedErrors.length;
    const statFatalEl = document.getElementById('logsStatFatal');
    if (statFatalEl) statFatalEl.textContent = fatalErrors.length;
    const statTodayEl = document.getElementById('logsStatToday');
    if (statTodayEl) statTodayEl.textContent = todayErrors.length;

    // Determine Top Error Category
    const categoryFrequencies = {};
    unresolvedErrors.forEach(e => {
        const catName = getCategoryDisplayName(e.category || e.service);
        categoryFrequencies[catName] = (categoryFrequencies[catName] || 0) + 1;
    });
    let topCatName = '-';
    let topCatMax = 0;
    Object.entries(categoryFrequencies).forEach(([cName, count]) => {
        if (count > topCatMax) {
            topCatName = `${cName} (${count})`;
            topCatMax = count;
        }
    });
    const statTopCatEl = document.getElementById('logsStatTopCategory');
    if (statTopCatEl) statTopCatEl.textContent = topCatMax > 0 ? topCatName : 'Hata Yok';

    // 4. Filter List for Table Display (Kibana APM Multi-Criteria)
    let userMatchCount = 0;
    const filteredRows = envFilteredList.filter(e => {
        // Tab Filter
        if (currentLogCategoryTab !== 'all') {
            const cat = e.category || e.service || 'backend';
            let isTabMatch = false;
            if (currentLogCategoryTab === 'mobile' && cat === 'mobile') isTabMatch = true;
            else if (currentLogCategoryTab === 'scraper' && (cat === 'scraper' || e.service === 'bot')) isTabMatch = true;
            else if (currentLogCategoryTab === 'catalogs_coupons' && cat === 'catalogs_coupons') isTabMatch = true;
            else if (currentLogCategoryTab === 'ai' && cat === 'ai') isTabMatch = true;
            else if (currentLogCategoryTab === 'notifications' && cat === 'notifications') isTabMatch = true;
            else if (currentLogCategoryTab === 'backend' && (cat === 'backend' || cat === 'functions')) isTabMatch = true;
            else if (currentLogCategoryTab === 'admin' && (cat === 'admin' || cat === 'web')) isTabMatch = true;
            if (!isTabMatch) return false;
        }

        // Service Filter
        if (serviceFilter !== 'all') {
            const matchService = (e.service === serviceFilter) || (e.category === serviceFilter);
            if (!matchService) return false;
        }

        // Severity Filter
        if (severityFilter !== 'all') {
            const sev = e.severity || 'error';
            if (sev !== severityFilter) return false;
        }

        // Status Filter
        if (statusFilter !== 'all') {
            if (statusFilter === 'unresolved' && e.status !== 'unresolved') return false;
            if (statusFilter === 'resolved' && e.status !== 'resolved') return false;
        }

        // Time Range Filter (Kibana Style)
        if (selectedLogTimeRange !== 'all' && e.createdAt) {
            const d = e.createdAt.toDate ? e.createdAt.toDate() : new Date(e.createdAt);
            const diffMs = now.getTime() - d.getTime();
            if (selectedLogTimeRange === '15m' && diffMs > 15 * 60 * 1000) return false;
            if (selectedLogTimeRange === '1h' && diffMs > 60 * 60 * 1000) return false;
            if (selectedLogTimeRange === '24h' && diffMs > 24 * 60 * 60 * 1000) return false;
            if (selectedLogTimeRange === '7d' && diffMs > 7 * 24 * 60 * 60 * 1000) return false;
            if (selectedLogTimeRange === '30d' && diffMs > 30 * 24 * 60 * 60 * 1000) return false;
        }

        // Platform Filter
        if (selectedLogPlatform !== 'all') {
            const itemPlatform = (e.platform || e.metadata?.platform || '').toLowerCase();
            const itemService = (e.service || '').toLowerCase();
            if (selectedLogPlatform === 'android' && itemPlatform !== 'android') return false;
            if (selectedLogPlatform === 'ios' && itemPlatform !== 'ios') return false;
            if (selectedLogPlatform === 'web' && itemPlatform !== 'web' && itemService !== 'web' && itemService !== 'admin') return false;
            if (selectedLogPlatform === 'backend' && itemService !== 'backend' && itemService !== 'functions') return false;
            if (selectedLogPlatform === 'bot' && itemService !== 'bot') return false;
        }

        // User ID Filter (Kibana APM Style)
        if (selectedLogUserIdFilter) {
            const target = selectedLogUserIdFilter.toLowerCase();
            const itemUid = (e.userId || e.metadata?.userId || e.metadata?.uid || '').toLowerCase();
            const itemEmail = (e.userEmail || e.metadata?.userEmail || e.metadata?.email || '').toLowerCase();
            const inMessage = (e.message || '').toLowerCase().includes(target);
            if (itemUid !== target && !itemEmail.includes(target) && !inMessage) {
                return false;
            }
            userMatchCount++;
        }

        // Search Filter (Message, Type, Category, Service, Stack, Store, User)
        if (searchVal) {
            const targetText = [
                e.errorType || '',
                e.message || '',
                e.category || '',
                e.service || '',
                e.subCategory || '',
                e.userId || '',
                e.userEmail || '',
                e.metadata?.store || '',
                e.metadata?.userId || '',
                e.metadata?.uid || '',
                e.stack || ''
            ].join(' ').toLowerCase();
            if (!targetText.includes(searchVal)) return false;
        }

        return true;
    });

    // Update Active User Banner Statistics
    if (selectedLogUserIdFilter) {
        const statsEl = document.getElementById('logsActiveUserStats');
        if (statsEl) {
            statsEl.textContent = `${userMatchCount} adet hata kaydı bulundu.`;
        }
        const deepSearchBtn = document.getElementById('logsDeepSearchBtn');
        if (deepSearchBtn) {
            if (userMatchCount === 0) deepSearchBtn.classList.remove('hidden');
            else deepSearchBtn.classList.add('hidden');
        }
    }

    if (filteredRows.length === 0) {
        tbody.innerHTML = `<tr><td colspan="6" class="px-6 py-12 text-center text-slate-400 dark:text-slate-500">Kriterlere uygun sistem logu bulunamadı.</td></tr>`;
        return;
    }

    let html = '';
    filteredRows.forEach(e => {
        const createdDate = e.createdAt ? (e.createdAt.toDate ? e.createdAt.toDate() : new Date(e.createdAt)) : null;
        const lastOccurredDate = e.lastOccurredAt ? (e.lastOccurredAt.toDate ? e.lastOccurredAt.toDate() : new Date(e.lastOccurredAt)) : null;

        const dateStr = createdDate ? createdDate.toLocaleDateString('tr-TR', { day: '2-digit', month: 'short' }) + ' ' + createdDate.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' }) : '-';
        const lastStr = lastOccurredDate && createdDate && (lastOccurredDate.getTime() - createdDate.getTime() > 60000) 
            ? `<div class="text-[10px] text-slate-400">Son: ${lastOccurredDate.toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })}</div>` 
            : '';

        const itemEnv = (e.environment || 'dev').toUpperCase();
        const envBadge = itemEnv === 'PROD'
            ? `<span class="px-1.5 py-0.2 rounded text-[10px] font-black bg-rose-500/10 text-rose-500 border border-rose-500/20">PROD</span>`
            : `<span class="px-1.5 py-0.2 rounded text-[10px] font-black bg-emerald-500/10 text-emerald-500 border border-emerald-500/20">DEV</span>`;

        const serviceBadge = getServiceBadgeHtml(e.service, e.category);
        const severityBadge = getSeverityBadgeHtml(e.severity);

        const occurrenceBadge = (e.occurrenceCount && e.occurrenceCount > 1)
            ? `<span class="px-1.5 py-0.2 rounded-full text-[10px] font-extrabold bg-slate-200 dark:bg-slate-700 text-slate-700 dark:text-slate-300">x${e.occurrenceCount}</span>`
            : '';

        let contextTag = '';
        if (e.metadata?.store) {
            contextTag = `<span class="px-1.5 py-0.2 rounded text-[10px] font-bold bg-blue-50 dark:bg-blue-950/30 text-blue-600 dark:text-blue-400 uppercase">${e.metadata.store}</span>`;
        } else if (e.subCategory) {
            contextTag = `<span class="px-1.5 py-0.2 rounded text-[10px] font-semibold bg-slate-100 dark:bg-slate-800 text-slate-600 dark:text-slate-300">${e.subCategory}</span>`;
        }

        const logUserId = e.userId || e.metadata?.userId || e.metadata?.uid || null;
        let userBadgeHtml = '';
        if (logUserId) {
            const shortUid = logUserId.length > 8 ? `${logUserId.substring(0, 6)}...` : logUserId;
            userBadgeHtml = `<button type="button" onclick="window.filterLogsByUser('${logUserId}', null)" class="inline-flex items-center gap-1 px-1.5 py-0.2 rounded text-[10px] font-mono font-bold bg-blue-50 text-blue-600 dark:bg-blue-950/40 dark:text-blue-300 hover:bg-blue-100 dark:hover:bg-blue-900/50 transition-colors" title="Bu Kullanıcıyı Filtrele">👤 ${shortUid}</button>`;
        }

        const isResolved = e.status === 'resolved';
        const statusIcon = isResolved ? 'check_circle' : 'radio_button_unchecked';
        const statusColor = isResolved ? 'text-emerald-500 hover:text-emerald-600' : 'text-slate-400 hover:text-emerald-500';
        const statusTitle = isResolved ? 'Yeniden Aç' : 'Çözüldü Olarak İşaretle';

        html += `
            <tr class="hover:bg-slate-50/80 dark:hover:bg-surface-darker/60 transition-colors">
                <td class="px-5 py-3.5 whitespace-nowrap text-slate-500 dark:text-slate-400">
                    <div class="font-medium">${dateStr}</div>
                    ${lastStr}
                </td>
                <td class="px-5 py-3.5 whitespace-nowrap">
                    <div class="flex items-center gap-1.5 flex-wrap">
                        ${envBadge}
                        ${serviceBadge}
                    </div>
                </td>
                <td class="px-5 py-3.5 whitespace-nowrap">
                    ${severityBadge}
                </td>
                <td class="px-5 py-3.5 whitespace-nowrap">
                    <div class="flex items-center gap-1.5">
                        <span class="font-bold text-slate-900 dark:text-white truncate max-w-[170px]" title="${e.errorType}">${e.errorType}</span>
                        ${occurrenceBadge}
                    </div>
                    <div class="flex items-center gap-1.5 mt-0.5 flex-wrap">
                        ${contextTag}
                        ${userBadgeHtml}
                    </div>
                </td>
                <td class="px-5 py-3.5 text-slate-700 dark:text-slate-300">
                    <div class="line-clamp-2 break-words font-sans text-xs leading-relaxed max-w-xl" title="${escapeHtml(e.message)}">
                        ${escapeHtml(e.message)}
                    </div>
                </td>
                <td class="px-5 py-3.5 whitespace-nowrap text-right">
                    <div class="flex items-center justify-end gap-1">
                        <button onclick="window.openLogDetailModal('${e.id}')" class="p-1.5 text-blue-600 dark:text-blue-400 hover:bg-blue-50 dark:hover:bg-blue-950/30 rounded-lg transition-colors" title="Detayları İncele">
                            <span class="material-symbols-outlined text-[18px]">visibility</span>
                        </button>
                        <button onclick="window.toggleErrorResolved('${e.id}')" class="p-1.5 ${statusColor} hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors" title="${statusTitle}">
                            <span class="material-symbols-outlined text-[18px]">${statusIcon}</span>
                        </button>
                        <button onclick="window.copyErrorSummary('${e.id}')" class="p-1.5 text-slate-400 hover:text-slate-600 dark:hover:text-slate-200 hover:bg-slate-100 dark:hover:bg-slate-800 rounded-lg transition-colors" title="Özeti Kopyala">
                            <span class="material-symbols-outlined text-[18px]">content_copy</span>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    });

    tbody.innerHTML = html;
}

function getCategoryDisplayName(cat) {
    switch (cat) {
        case 'mobile': return 'Mobil Uygulama';
        case 'bot': return 'Telegram Botu';
        case 'scraper': return 'Mağaza Kazıyıcılar';
        case 'catalogs_coupons': return 'Katalog & Kupon';
        case 'ai': return 'AI / Gemini';
        case 'notifications': return 'Bildirim Motoru';
        case 'backend':
        case 'functions': return 'Cloud Functions';
        case 'admin':
        case 'web': return 'Web Admin';
        default: return cat || 'Sistem';
    }
}

function getServiceBadgeHtml(service, category) {
    const key = category || service || 'backend';
    switch (key) {
        case 'mobile':
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-purple-100 text-purple-800 dark:bg-purple-950/40 dark:text-purple-300">📱 Mobil</span>`;
        case 'bot':
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-sky-100 text-sky-800 dark:bg-sky-950/40 dark:text-sky-300">📡 Bot</span>`;
        case 'scraper':
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-indigo-100 text-indigo-800 dark:bg-indigo-950/40 dark:text-indigo-300">🕷️ Scraper</span>`;
        case 'catalogs_coupons':
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-teal-100 text-teal-800 dark:bg-teal-950/40 dark:text-teal-300">📰 Katalog</span>`;
        case 'ai':
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-fuchsia-100 text-fuchsia-800 dark:bg-fuchsia-950/40 dark:text-fuchsia-300">🧠 AI</span>`;
        case 'notifications':
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-orange-100 text-orange-800 dark:bg-orange-950/40 dark:text-orange-300">🔔 Push</span>`;
        case 'admin':
        case 'web':
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/40 dark:text-amber-300">💻 Admin</span>`;
        default:
            return `<span class="px-2 py-0.5 rounded-lg text-[10px] font-bold bg-blue-100 text-blue-800 dark:bg-blue-950/40 dark:text-blue-300">⚡ Functions</span>`;
    }
}

function getSeverityBadgeHtml(severity) {
    switch (severity) {
        case 'fatal':
            return `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-black bg-rose-500/10 text-rose-600 dark:text-rose-400 border border-rose-500/20"><span class="w-1.5 h-1.5 rounded-full bg-rose-500 animate-pulse"></span>Kritik</span>`;
        case 'warning':
            return `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-amber-500/10 text-amber-600 dark:text-amber-400 border border-amber-500/20">⚠️ Uyarı</span>`;
        case 'info':
            return `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-blue-500/10 text-blue-600 dark:text-blue-400 border border-blue-500/20">ℹ️ Bilgi</span>`;
        default:
            return `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-md text-[10px] font-bold bg-rose-100 text-rose-700 dark:bg-rose-950/30 dark:text-rose-400">❌ Hata</span>`;
    }
}

// Modal Controllers
window.openLogDetailModal = function(errorId) {
    const error = allErrorsList.find(e => e.id === errorId);
    if (!error) {
        showError('Hata kaydı bulunamadı.');
        return;
    }
    currentSelectedError = error;

    const modal = document.getElementById('logDetailModal');
    const titleEl = document.getElementById('logModalTitle');
    const subtitleEl = document.getElementById('logModalSubtitle');
    const severityBadgeEl = document.getElementById('logModalSeverityBadge');
    const envBadgeEl = document.getElementById('logModalEnvBadge');
    const resolveTextEl = document.getElementById('logModalResolveBtnText');
    const contentEl = document.getElementById('logModalContent');

    if (titleEl) titleEl.textContent = error.errorType || 'Sistem Hatası';
    if (subtitleEl) subtitleEl.textContent = `${getCategoryDisplayName(error.category || error.service)} • ID: ${error.id}`;

    if (severityBadgeEl) severityBadgeEl.innerHTML = getSeverityBadgeHtml(error.severity);
    if (envBadgeEl) {
        const itemEnv = (error.environment || 'dev').toUpperCase();
        envBadgeEl.innerHTML = itemEnv === 'PROD'
            ? `<span class="px-2 py-0.5 rounded text-[10px] font-black bg-rose-500 text-white">PROD</span>`
            : `<span class="px-2 py-0.5 rounded text-[10px] font-black bg-emerald-500 text-white">DEV</span>`;
    }

    if (resolveTextEl) {
        resolveTextEl.textContent = error.status === 'resolved' ? 'Tekrar Aç' : 'Çözüldü Olarak İşaretle';
    }

    const createdDate = error.createdAt ? (error.createdAt.toDate ? error.createdAt.toDate().toLocaleString('tr-TR') : new Date(error.createdAt).toLocaleString('tr-TR')) : '-';
    const lastDate = error.lastOccurredAt ? (error.lastOccurredAt.toDate ? error.lastOccurredAt.toDate().toLocaleString('tr-TR') : new Date(error.lastOccurredAt).toLocaleString('tr-TR')) : createdDate;

    // User Profile Card in Modal
    const logUserId = error.userId || error.metadata?.userId || error.metadata?.uid || null;
    let userCardHtml = '';
    if (logUserId) {
        userCardHtml = `
            <div class="p-3 bg-blue-50/80 dark:bg-blue-950/30 border border-blue-200 dark:border-blue-900/50 rounded-xl flex flex-col sm:flex-row sm:items-center justify-between gap-3">
                <div class="flex items-center gap-2.5">
                    <span class="material-symbols-outlined text-blue-600 dark:text-blue-400 text-2xl">person</span>
                    <div>
                        <span class="text-[10px] text-slate-400 font-bold uppercase block">Etkilenen Kullanıcı</span>
                        <span class="text-xs font-mono font-bold text-blue-700 dark:text-blue-300 select-all">${escapeHtml(logUserId)}</span>
                    </div>
                </div>
                <button type="button" onclick="window.filterLogsByUser('${escapeHtml(logUserId)}', null); window.closeLogDetailModal();" class="px-3 py-1.5 rounded-lg bg-blue-600 hover:bg-blue-700 text-white font-bold text-xs flex items-center gap-1.5 shadow-sm transition-colors shrink-0">
                    <span class="material-symbols-outlined text-[16px]">filter_alt</span>
                    <span>Bu Kullanıcının Hatalarını Filtrele</span>
                </button>
            </div>
        `;
    }

    let metadataGridHtml = '';
    if (error.metadata && Object.keys(error.metadata).length > 0) {
        const metaItems = Object.entries(error.metadata)
            .map(([k, v]) => `<div class="p-2 rounded-lg bg-slate-50 dark:bg-surface-darker border border-slate-200/70 dark:border-slate-800"><span class="text-[10px] text-slate-400 block font-semibold uppercase">${k}</span><span class="text-xs font-mono font-bold text-slate-800 dark:text-slate-200 break-all">${escapeHtml(String(v))}</span></div>`)
            .join('');
        metadataGridHtml = `
            <div class="space-y-1.5">
                <span class="text-xs font-bold text-slate-700 dark:text-slate-300">Ekstra Bağlam & Metadata:</span>
                <div class="grid grid-cols-2 sm:grid-cols-3 gap-2">
                    ${metaItems}
                </div>
            </div>
        `;
    }

    const stackTraceHtml = error.stack
        ? `<div class="space-y-1.5">
            <span class="text-xs font-bold text-slate-700 dark:text-slate-300">Stack Trace:</span>
            <pre id="logModalRawStack" class="p-4 bg-slate-950 text-rose-300 rounded-xl font-mono text-[11px] leading-relaxed overflow-x-auto whitespace-pre-wrap max-h-72 border border-slate-800 select-all">${escapeHtml(error.stack)}</pre>
           </div>`
        : '';

    if (contentEl) {
        contentEl.innerHTML = `
            <!-- Summary Info Row -->
            <div class="grid grid-cols-2 sm:grid-cols-4 gap-3 p-3.5 rounded-xl bg-slate-50 dark:bg-surface-darker border border-slate-200 dark:border-slate-800">
                <div>
                    <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">İlk Görülme</span>
                    <span class="font-bold text-slate-900 dark:text-white text-xs">${createdDate}</span>
                </div>
                <div>
                    <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Son Görülme</span>
                    <span class="font-bold text-slate-900 dark:text-white text-xs">${lastDate}</span>
                </div>
                <div>
                    <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Tekrar Sayısı</span>
                    <span class="font-bold text-slate-900 dark:text-white text-xs">${error.occurrenceCount || 1} kez</span>
                </div>
                <div>
                    <span class="text-[10px] font-bold text-slate-400 uppercase tracking-wider block">Durum</span>
                    <span class="font-bold text-xs ${error.status === 'resolved' ? 'text-emerald-500' : 'text-rose-500'}">${error.status === 'resolved' ? 'Çözüldü' : 'Açık / Çözülmemiş'}</span>
                </div>
            </div>

            ${userCardHtml}

            <!-- Error Message Box -->
            <div class="space-y-1.5">
                <span class="text-xs font-bold text-slate-700 dark:text-slate-300">Hata Mesajı:</span>
                <div class="p-3.5 bg-rose-50/60 dark:bg-rose-950/20 border border-rose-200 dark:border-rose-900/40 rounded-xl text-rose-900 dark:text-rose-200 text-xs font-medium leading-relaxed select-all">
                    ${escapeHtml(error.message || 'Mesaj bulunmuyor')}
                </div>
            </div>

            ${metadataGridHtml}
            ${stackTraceHtml}
        `;
    }

    if (modal) modal.classList.remove('hidden');
};

window.closeLogDetailModal = function() {
    const modal = document.getElementById('logDetailModal');
    if (modal) modal.classList.add('hidden');
    currentSelectedError = null;
};

window.copyModalStackTrace = function() {
    if (!currentSelectedError) return;
    const textToCopy = currentSelectedError.stack || currentSelectedError.message;
    navigator.clipboard.writeText(textToCopy).then(() => {
        showSuccess('📋 Stack trace panoya kopyalandı.');
    }).catch(() => {
        showError('Kopyalama başarısız oldu.');
    });
};

window.toggleModalErrorResolve = async function() {
    if (!currentSelectedError) return;
    await toggleErrorResolved(currentSelectedError.id);
    closeLogDetailModal();
};

window.toggleErrorResolved = async function(errorId) {
    const error = allErrorsList.find(e => e.id === errorId);
    if (!error) return;

    const newStatus = error.status === 'resolved' ? 'unresolved' : 'resolved';
    try {
        await db.collection('systemErrors').doc(errorId).update({
            status: newStatus,
            resolvedAt: newStatus === 'resolved' ? firebase.firestore.FieldValue.serverTimestamp() : null,
            resolvedBy: auth.currentUser?.email || auth.currentUser?.uid || 'admin'
        });
        showSuccess(newStatus === 'resolved' ? '✅ Hata çözüldü olarak işaretlendi.' : 'ℹ️ Hata yeniden açıldı.');
    } catch (err) {
        console.error('❌ Error updating error status:', err);
        showError('Hata güncellenemedi: ' + err.message);
    }
};

window.copyErrorSummary = function(errorId) {
    const error = allErrorsList.find(e => e.id === errorId);
    if (!error) return;
    const summary = `[${error.environment || 'DEV'}] [${error.service}/${error.category}] ${error.errorType}\nMesaj: ${error.message}\nTarih: ${error.createdAt?.toDate ? error.createdAt.toDate().toISOString() : ''}`;
    navigator.clipboard.writeText(summary).then(() => {
        showSuccess('📋 Hata özeti kopyalandı.');
    });
};

window.resolveAllErrors = async function() {
    const currentEnv = getAdminCurrentEnvironment();
    const envFilter = document.getElementById('logsEnvironmentFilter')?.value || 'current';
    const unresolved = allErrorsList.filter(e => {
        if (e.status !== 'unresolved') return false;
        const itemEnv = e.environment || 'dev';
        if (envFilter === 'all') return true;
        if (envFilter === 'dev') return itemEnv === 'dev';
        if (envFilter === 'prod') return itemEnv === 'prod';
        return itemEnv === currentEnv;
    });

    if (unresolved.length === 0) {
        showSuccess('Seçili ortamda çözülmemiş hata bulunmuyor.');
        return;
    }

    if (!confirm(`Seçili ortamdaki ${unresolved.length} açık hatayı "Çözüldü" olarak işaretlemek istediğinize emin misiniz?`)) return;

    const btn = document.getElementById('resolveAllErrorsBtn');
    if (btn) {
        btn.disabled = true;
        btn.textContent = 'Güncelleniyor...';
    }

    try {
        const batch = db.batch();
        unresolved.forEach(e => {
            const ref = db.collection('systemErrors').doc(e.id);
            batch.update(ref, {
                status: 'resolved',
                resolvedAt: firebase.firestore.FieldValue.serverTimestamp(),
                resolvedBy: auth.currentUser?.email || 'admin'
            });
        });
        await batch.commit();
        showSuccess(`✅ ${unresolved.length} hata toplu olarak çözüldü işaretlendi.`);
    } catch (err) {
        console.error('❌ Error resolving all errors:', err);
        showError('Toplu güncelleme hatası: ' + err.message);
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<span class="material-symbols-outlined text-[18px]">done_all</span><span>Tümünü Çözüldü İşaretle</span>';
        }
    }
};

window.purgeOldSystemLogs = async function() {
    if (!confirm('30 günden eski veya "Çözüldü" işaretlenmiş sistem logları kalıcı olarak silinecektir. Devam edilsin mi?')) return;

    const btn = document.getElementById('purgeOldErrorsBtn');
    if (btn) {
        btn.disabled = true;
        btn.textContent = 'Temizleniyor...';
    }

    try {
        const thirtyDaysAgo = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
        const snapshot = await db.collection('systemErrors').limit(300).get();
        const toDelete = snapshot.docs.filter(doc => {
            const d = doc.data();
            if (d.status === 'resolved') return true;
            if (d.createdAt) {
                const date = d.createdAt.toDate ? d.createdAt.toDate() : new Date(d.createdAt);
                if (date < thirtyDaysAgo) return true;
            }
            return false;
        });

        if (toDelete.length === 0) {
            showSuccess('Temizlenecek eski veya çözülmüş log bulunamadı.');
            return;
        }

        const batch = db.batch();
        toDelete.forEach(doc => batch.delete(doc.ref));
        await batch.commit();
        showSuccess(`🧹 Toplam ${toDelete.length} eski/çözülmüş sistem logu temizlendi.`);
    } catch (err) {
        console.error('❌ Error purging logs:', err);
        showError('Temizleme hatası: ' + err.message);
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = '<span class="material-symbols-outlined text-[18px]">delete_sweep</span><span>30+ Gün Temizle</span>';
        }
    }
};

async function logErrorToFirestore(service, errorType, message, stack, severity = 'error', options = {}) {
    try {
        const env = getAdminCurrentEnvironment();
        const category = options.category || (service === 'web' ? 'admin' : service);
        const shortMsg = (message || '').substring(0, 80);
        const fingerprint = `${service}_${category}_${errorType}_${shortMsg}`;
        const currentUid = auth.currentUser?.uid || null;
        const currentEmail = auth.currentUser?.email || null;

        await db.collection('systemErrors').add({
            environment: env,
            service,
            category,
            errorType: String(errorType || 'AdminError'),
            message: String(message || '').substring(0, 500),
            stack: stack ? String(stack).substring(0, 2000) : null,
            status: 'unresolved',
            severity: severity || 'error',
            fingerprint,
            occurrenceCount: 1,
            platform: 'web',
            ...(currentUid ? { userId: currentUid } : {}),
            ...(currentEmail ? { userEmail: currentEmail } : {}),
            metadata: {
                userAgent: navigator.userAgent,
                currentView: typeof currentView !== 'undefined' ? currentView : 'unknown',
                ...(currentUid ? { userId: currentUid } : {}),
                ...options.metadata
            },
            lastOccurredAt: firebase.firestore.FieldValue.serverTimestamp(),
            createdAt: firebase.firestore.FieldValue.serverTimestamp()
        });
        console.log(`💾 Error logged to Firestore [${env}]: [${service}] (${severity}) ${errorType}`);
    } catch (err) {
        console.error('❌ Failed to log error to Firestore:', err.message);
    }
}

function initLogsEventListeners() {
    console.log('🐛 Initializing Modernized Logs Event Listeners...');

    // Sidebar navigation hook
    const logsMenuBtn = document.getElementById('logsMenuBtn');
    if (logsMenuBtn) {
        logsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showLogsView();
        });
    }

    // Search and filter change listeners
    const logsSearchInput = document.getElementById('logsSearchInput');
    if (logsSearchInput) {
        logsSearchInput.addEventListener('input', () => {
            renderSystemLogs();
        });
    }

    const logsServiceFilter = document.getElementById('logsServiceFilter');
    if (logsServiceFilter) {
        logsServiceFilter.addEventListener('change', () => {
            renderSystemLogs();
        });
    }

    const logsSeverityFilter = document.getElementById('logsSeverityFilter');
    if (logsSeverityFilter) {
        logsSeverityFilter.addEventListener('change', () => {
            renderSystemLogs();
        });
    }

    const logsStatusFilter = document.getElementById('logsStatusFilter');
    if (logsStatusFilter) {
        logsStatusFilter.addEventListener('change', () => {
            renderSystemLogs();
        });
    }

    const logsEnvironmentFilter = document.getElementById('logsEnvironmentFilter');
    if (logsEnvironmentFilter) {
        logsEnvironmentFilter.addEventListener('change', () => {
            renderSystemLogs();
        });
    }

    const logsTimeRangeFilter = document.getElementById('logsTimeRangeFilter');
    if (logsTimeRangeFilter) {
        logsTimeRangeFilter.addEventListener('change', () => {
            renderSystemLogs();
        });
    }

    const logsPlatformFilter = document.getElementById('logsPlatformFilter');
    if (logsPlatformFilter) {
        logsPlatformFilter.addEventListener('change', () => {
            renderSystemLogs();
        });
    }

    // Click outside user dropdown popover to close it
    document.addEventListener('click', (e) => {
        const popover = document.getElementById('logsUserDropdownPopover');
        const btn = document.getElementById('logsUserDropdownBtn');
        if (popover && !popover.classList.contains('hidden')) {
            if (!popover.contains(e.target) && !btn.contains(e.target)) {
                popover.classList.add('hidden');
            }
        }
    });

    // Global keyboard listener (ESC to close modal or dropdown)
    window.addEventListener('keydown', (e) => {
        if (e.key === 'Escape') {
            closeLogDetailModal();
            window.closeLogsUserDropdown();
        }
    });

    // Global window runtime error listener
    window.addEventListener('error', (event) => {
        if (event.message && event.message.includes('systemErrors')) return;
        logErrorToFirestore('web', 'Window Runtime Error', event.message, event.error ? event.error.stack : null, 'fatal');
    });
}

window.showLogsView = showLogsView;
window.loadSystemLogs = loadSystemLogs;
window.renderSystemLogs = renderSystemLogs;


// Geliştirici & Test Otomasyon Araçları Fonksiyonları
window.generateTestDataAdmin = async function() {
    const emailPrefixInput = document.getElementById('testUserEmail');
    const displayNameInput = document.getElementById('testUserNick');
    const dealsCountInput = document.getElementById('testDealsCount');
    const logEl = document.getElementById('testResultLog');

    const emailPrefix = emailPrefixInput ? emailPrefixInput.value.trim() : 'testuser';
    const displayName = displayNameInput ? displayNameInput.value.trim() : 'Test Kullanıcı';
    const dealsCount = dealsCountInput ? parseInt(dealsCountInput.value) : 3;

    if (!emailPrefix) {
        showError('Test kullanıcı adı prefix giriniz!');
        return;
    }

    const btn = document.getElementById('btnGenerateTestData');
    const originalHTML = btn ? btn.innerHTML : '';
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<span class="material-symbols-outlined text-[18px] animate-spin">sync</span><span>Oluşturuluyor...</span>';
    }

    if (logEl) {
        logEl.classList.remove('hidden');
        logEl.textContent = '🔄 Test verisi oluşturuluyor... Lütfen bekleyin...';
        logEl.className = 'p-3 bg-purple-50 dark:bg-purple-950/20 border border-purple-100 dark:border-purple-900/50 rounded-lg text-purple-800 dark:text-purple-400 text-xs font-mono whitespace-pre-wrap';
    }

    try {
        console.log('🧪 Calling generateTestData Cloud Function...');
        const generateFunc = firebase.functions().httpsCallable('generateTestData');
        const result = await generateFunc({
            email: emailPrefix,
            username: displayName,
            dealsCount: dealsCount
        });

        console.log('✅ Test data creation result:', result.data);

        if (result.data && result.data.success) {
            showSuccess('Test kullanıcısı ve mock fırsatlar başarıyla oluşturuldu!');
            if (logEl) {
                let logText = `✅ BAŞARILI!\n`;
                logText += `----------------------------------------\n`;
                logText += `UID: ${result.data.uid}\n`;
                logText += `E-posta: ${result.data.email}\n`;
                logText += `Şifre: password123\n`;
                logText += `Görünen Ad: ${result.data.username}\n`;
                logText += `----------------------------------------\n`;
                logText += `Oluşturulan Mock Fırsatlar:\n`;
                if (result.data.dealsCreated && result.data.dealsCreated.length > 0) {
                    result.data.dealsCreated.forEach((deal, idx) => {
                        logText += ` ${idx + 1}. [ID: ${deal.id}] ${deal.title}\n`;
                    });
                } else {
                    logText += ` (Hiç fırsat oluşturulmadı)\n`;
                }
                logEl.textContent = logText;
                logEl.className = 'p-3 bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-100 dark:border-emerald-900/50 rounded-lg text-emerald-800 dark:text-emerald-400 text-xs font-mono whitespace-pre-wrap';
            }
            // Yenile
            await loadDeals();
        } else {
            throw new Error('Yanıt başarısız oldu.');
        }
    } catch (error) {
        console.error('❌ Test verisi oluşturulurken hata:', error);
        showError('Test verisi oluşturma hatası: ' + error.message);
        if (logEl) {
            logEl.textContent = `❌ HATA!\n${error.message}`;
            logEl.className = 'p-3 bg-rose-50 dark:bg-rose-950/20 border border-rose-100 dark:border-rose-900/50 rounded-lg text-rose-800 dark:text-rose-400 text-xs font-mono whitespace-pre-wrap';
        }
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = originalHTML;
        }
    }
};

window.cleanupTestDataAdmin = async function() {
    if (!confirm('E-postası "@test.firsatkolik.com" ile biten TÜM test kullanıcılarını ve ilişkili verileri (fırsatlar, yorumlar, abonelikler vb.) kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz.')) {
        return;
    }

    const btn = document.getElementById('btnClearTestData');
    const originalHTML = btn ? btn.innerHTML : '';
    if (btn) {
        btn.disabled = true;
        btn.innerHTML = '<span class="material-symbols-outlined text-[18px] animate-spin">sync</span><span>Temizleniyor...</span>';
    }

    const logEl = document.getElementById('testResultLog');
    if (logEl) {
        logEl.classList.remove('hidden');
        logEl.textContent = '🔄 Test verileri temizleniyor... Lütfen bekleyin...';
        logEl.className = 'p-3 bg-purple-50 dark:bg-purple-950/20 border border-purple-100 dark:border-purple-900/50 rounded-lg text-purple-800 dark:text-purple-400 text-xs font-mono whitespace-pre-wrap';
    }

    try {
        console.log('🧪 Calling cleanupTestData Cloud Function...');
        const cleanupFunc = firebase.functions().httpsCallable('cleanupTestData');
        const result = await cleanupFunc();

        console.log('✅ Test data cleanup result:', result.data);

        if (result.data && result.data.success) {
            showSuccess(`Temizleme başarılı! Toplam ${result.data.cleanedCount} test hesabı ve tüm ilişkili verileri temizlendi.`);
            if (logEl) {
                logEl.textContent = `✅ TEMİZLEME BAŞARILI!\nSilinen Test Hesap Sayısı: ${result.data.cleanedCount}\nİlişkili veritabanı kayıtları (fırsatlar, cihazlar, abonelikler) onUserDeleted tetikleyicisi tarafından arka planda temizlendi.`;
                logEl.className = 'p-3 bg-emerald-50 dark:bg-emerald-950/20 border border-emerald-100 dark:border-emerald-900/50 rounded-lg text-emerald-800 dark:text-emerald-400 text-xs font-mono whitespace-pre-wrap';
            }
            await loadDeals();
        } else {
            throw new Error('Yanıt başarısız oldu.');
        }
    } catch (error) {
        console.error('❌ Test verileri temizlenirken hata:', error);
        showError('Temizleme hatası: ' + error.message);
        if (logEl) {
            logEl.textContent = `❌ HATA!\n${error.message}`;
            logEl.className = 'p-3 bg-rose-50 dark:bg-rose-950/20 border border-rose-100 dark:border-rose-900/50 rounded-lg text-rose-800 dark:text-rose-400 text-xs font-mono whitespace-pre-wrap';
        }
    } finally {
        if (btn) {
            btn.disabled = false;
            btn.innerHTML = originalHTML;
        }
    }
};

// ==========================================
// COUPONS MANAGEMENT SECTION (KUPONLAR)
// ==========================================

function showCouponsView() {
    currentView = 'coupons';
    showView('couponsView');
    updateMenuActiveState('coupons');
    if (coupons.length === 0) {
        loadCoupons();
    } else {
        renderCoupons();
    }
}

// =========================================================================
// FAZ 5 - KUPONLAR YÖNETİMİ (COUPONS SUBSYSTEM - TOPLULUK VS RADAR)
// =========================================================================

let currentCouponSourceTab = 'all'; // 'all' | 'topluluk' | 'web'
let currentCouponStoreFilter = 'all';
let currentCouponStatusFilter = 'all'; // 'all' | 'active' | 'invalid' | 'expired'
let currentCouponSort = 'newest'; // 'newest' | 'score' | 'expiry'

function showCouponsView() {
    currentView = 'coupons';
    showView('couponsView');
    updateMenuActiveState('coupons');
    if (coupons.length === 0) {
        loadCoupons();
    } else {
        renderCoupons();
    }
}

function loadCoupons() {
    const loadingEl = document.getElementById('couponsLoadingIndicator');
    const emptyEl = document.getElementById('couponsEmptyState');
    const listEl = document.getElementById('couponsList');

    if (loadingEl) {
        loadingEl.style.display = 'block';
        loadingEl.textContent = 'Kuponlar yükleniyor...';
    }
    if (emptyEl) emptyEl.classList.add('hidden');

    if (couponsUnsubscribe) {
        couponsUnsubscribe();
        couponsUnsubscribe = null;
    }

    try {
        couponsUnsubscribe = db.collection('kuponlar')
            .orderBy('olusturulmaTarihi', 'desc')
            .onSnapshot((snapshot) => {
                coupons = snapshot.docs.map(doc => {
                    const data = doc.data();
                    
                    // Parse creation date
                    let createDate = new Date();
                    if (data.olusturulmaTarihi) {
                        if (typeof data.olusturulmaTarihi.toDate === 'function') {
                            createDate = data.olusturulmaTarihi.toDate();
                        } else if (data.olusturulmaTarihi instanceof Date) {
                            createDate = data.olusturulmaTarihi;
                        } else {
                            createDate = new Date(data.olusturulmaTarihi);
                        }
                    }

                    // Parse expiration date
                    let expiryDate = null;
                    const rawExpiry = data.bitisTarihi || data.sonKullanimTarihi;
                    if (rawExpiry) {
                        if (typeof rawExpiry.toDate === 'function') {
                            expiryDate = rawExpiry.toDate();
                        } else if (rawExpiry instanceof Date) {
                            expiryDate = rawExpiry;
                        } else {
                            expiryDate = new Date(rawExpiry);
                        }
                    }

                    // Resolve source: 'topluluk' vs 'web'
                    let kaynakTipi = data.kaynakTipi;
                    if (!kaynakTipi) {
                        kaynakTipi = (data.paylasanKullaniciId && data.paylasanKullaniciId !== 'admin' && data.paylasanKullaniciId !== 'botkolik')
                            ? 'topluluk'
                            : 'web';
                    }

                    return {
                        id: doc.id,
                        magazaAdi: data.magazaAdi || 'Diğer',
                        baslik: data.baslik || '',
                        aciklama: data.aciklama || '',
                        kuponKodu: data.kuponKodu || '',
                        olusturulmaTarihi: createDate,
                        bitisTarihi: expiryDate,
                        paylasanKullaniciId: data.paylasanKullaniciId || 'admin',
                        paylasanKullaniciAdi: data.paylasanKullaniciAdi || data.paylasanKullanici || '',
                        kaynakTipi: kaynakTipi,
                        sicakOySayisi: parseInt(data.sicakOySayisi, 10) || 0,
                        sogukOySayisi: parseInt(data.sogukOySayisi, 10) || 0,
                        durum: data.durum || 'aktif'
                    };
                });

                if (loadingEl) loadingEl.style.display = 'none';

                updateCouponsSummaryStats();
                populateCouponStoreFilter();

                if (coupons.length === 0) {
                    if (emptyEl) {
                        emptyEl.classList.remove('hidden');
                        emptyEl.textContent = 'Henüz kupon bulunamadı';
                    }
                    if (listEl) listEl.innerHTML = '';
                } else {
                    renderCoupons();
                }
            }, (error) => {
                console.error("Error loading coupons:", error);
                if (loadingEl) loadingEl.textContent = 'Hata: ' + error.message;
                showError("Kuponlar yüklenirken hata oluştu: " + error.message);
            });
    } catch (err) {
        console.error("Error setting up coupons listener:", err);
        if (loadingEl) loadingEl.textContent = 'Hata: ' + err.message;
    }
}

// Update Top Quick Stat Counters & Tab Badges
function updateCouponsSummaryStats() {
    const now = new Date();
    const total = coupons.length;
    const communityCount = coupons.filter(c => c.kaynakTipi === 'topluluk').length;
    const radarCount = coupons.filter(c => c.kaynakTipi === 'web').length;
    const activeCount = coupons.filter(c => c.durum !== 'gecersiz' && (!c.bitisTarihi || c.bitisTarihi >= now)).length;
    const invalidCount = coupons.filter(c => c.durum === 'gecersiz' || (c.bitisTarihi && c.bitisTarihi < now)).length;

    const elTotal = document.getElementById('couponStatTotal');
    if (elTotal) elTotal.textContent = total;

    const elCommunity = document.getElementById('couponStatCommunity');
    if (elCommunity) elCommunity.textContent = communityCount;

    const elRadar = document.getElementById('couponStatRadar');
    if (elRadar) elRadar.textContent = radarCount;

    const elActive = document.getElementById('couponStatActive');
    if (elActive) elActive.textContent = activeCount;

    const elInvalid = document.getElementById('couponStatInvalid');
    if (elInvalid) elInvalid.textContent = invalidCount;

    // Tab Badges
    const badgeAll = document.getElementById('couponTabAllBadge');
    if (badgeAll) badgeAll.textContent = total;

    const badgeCommunity = document.getElementById('couponTabCommunityBadge');
    if (badgeCommunity) badgeCommunity.textContent = communityCount;

    const badgeRadar = document.getElementById('couponTabRadarBadge');
    if (badgeRadar) badgeRadar.textContent = radarCount;
}

// Dynamically populate coupon store dropdown from existing data
function populateCouponStoreFilter() {
    const storeFilter = document.getElementById('couponStoreFilter');
    if (!storeFilter) return;

    const currentVal = storeFilter.value;
    const storesSet = new Set();
    coupons.forEach(c => {
        if (c.magazaAdi && c.magazaAdi.trim()) {
            storesSet.add(c.magazaAdi.trim());
        }
    });

    const sortedStores = Array.from(storesSet).sort();
    let optionsHtml = '<option value="all">Tüm Mağazalar</option>';
    sortedStores.forEach(s => {
        optionsHtml += `<option value="${escapeHtml(s)}">${escapeHtml(s)}</option>`;
    });

    storeFilter.innerHTML = optionsHtml;
    if (storesSet.has(currentVal) || currentVal === 'all') {
        storeFilter.value = currentVal;
    } else {
        storeFilter.value = 'all';
    }
}

// Switch between 'all', 'topluluk', and 'web'
window.switchCouponSourceTab = function(tab) {
    currentCouponSourceTab = tab;

    const tabs = document.querySelectorAll('.coupon-source-tab');
    tabs.forEach(btn => {
        btn.className = 'coupon-source-tab px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 transition-all text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white hover:bg-slate-100 dark:hover:bg-surface-darker';
    });

    let activeBtnId = 'couponTabAll';
    if (tab === 'topluluk') activeBtnId = 'couponTabCommunity';
    else if (tab === 'web') activeBtnId = 'couponTabRadar';

    const activeBtn = document.getElementById(activeBtnId);
    if (activeBtn) {
        activeBtn.className = 'coupon-source-tab px-4 py-2.5 rounded-xl font-bold text-xs flex items-center gap-2 transition-all bg-primary text-white shadow-xs';
    }

    renderCoupons();
};

function renderCoupons() {
    const listEl = document.getElementById('couponsList');
    const emptyEl = document.getElementById('couponsEmptyState');
    const countEl = document.getElementById('couponFilteredCount');
    if (!listEl) return;

    listEl.innerHTML = '';
    const now = new Date();

    const searchQuery = (document.getElementById('couponSearchInput')?.value || '').toLowerCase().trim();
    currentCouponStoreFilter = document.getElementById('couponStoreFilter')?.value || 'all';
    currentCouponStatusFilter = document.getElementById('couponStatusFilter')?.value || 'all';
    currentCouponSort = document.getElementById('couponSortSelect')?.value || 'newest';

    let filtered = coupons.filter(c => {
        // 1. Source Tab Filter
        if (currentCouponSourceTab === 'topluluk' && c.kaynakTipi !== 'topluluk') return false;
        if (currentCouponSourceTab === 'web' && c.kaynakTipi !== 'web') return false;

        // 2. Store Filter
        if (currentCouponStoreFilter !== 'all' && c.magazaAdi.toLowerCase() !== currentCouponStoreFilter.toLowerCase()) return false;

        // 3. Status Filter
        const isExpired = (c.bitisTarihi && c.bitisTarihi < now);
        const isInvalid = (c.durum === 'gecersiz');
        const isActive = (!isInvalid && !isExpired);

        if (currentCouponStatusFilter === 'active' && !isActive) return false;
        if (currentCouponStatusFilter === 'invalid' && !isInvalid) return false;
        if (currentCouponStatusFilter === 'expired' && !isExpired) return false;

        // 4. Search Filter
        if (searchQuery) {
            const matchStore = c.magazaAdi.toLowerCase().includes(searchQuery);
            const matchTitle = c.baslik.toLowerCase().includes(searchQuery);
            const matchDesc = c.aciklama.toLowerCase().includes(searchQuery);
            const matchCode = c.kuponKodu.toLowerCase().includes(searchQuery);
            const matchUser = (c.paylasanKullaniciAdi || '').toLowerCase().includes(searchQuery) ||
                              (c.paylasanKullaniciId || '').toLowerCase().includes(searchQuery);
            if (!matchStore && !matchTitle && !matchDesc && !matchCode && !matchUser) return false;
        }

        return true;
    });

    // Sort logic
    if (currentCouponSort === 'score') {
        filtered.sort((a, b) => (b.sicakOySayisi - b.sogukOySayisi) - (a.sicakOySayisi - a.sogukOySayisi));
    } else if (currentCouponSort === 'expiry') {
        filtered.sort((a, b) => {
            if (!a.bitisTarihi) return 1;
            if (!b.bitisTarihi) return -1;
            return a.bitisTarihi.getTime() - b.bitisTarihi.getTime();
        });
    } else {
        // newest
        filtered.sort((a, b) => b.olusturulmaTarihi.getTime() - a.olusturulmaTarihi.getTime());
    }

    if (countEl) {
        countEl.textContent = `Gösterilen: ${filtered.length} / ${coupons.length} kupon`;
    }

    if (filtered.length === 0) {
        if (emptyEl) {
            emptyEl.classList.remove('hidden');
            emptyEl.textContent = searchQuery || currentCouponSourceTab !== 'all' || currentCouponStatusFilter !== 'all'
                ? 'Filtrelerle eşleşen kupon bulunamadı.'
                : 'Henüz kupon yok';
        }
        return;
    }

    if (emptyEl) emptyEl.classList.add('hidden');

    filtered.forEach(kupon => {
        const tr = document.createElement('tr');
        const isInvalid = (kupon.durum === 'gecersiz');
        const isExpired = (kupon.bitisTarihi && kupon.bitisTarihi < now);
        
        tr.className = `hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors border-b border-slate-100 dark:border-slate-800/80 ${isInvalid ? 'opacity-60 bg-rose-500/5' : ''}`;

        // Store badge color
        const storeBadgeClass = getStoreColorClass(kupon.magazaAdi);

        // Source badge
        let sourceBadgeHtml = '';
        if (kupon.kaynakTipi === 'topluluk') {
            const author = kupon.paylasanKullaniciAdi ? `@${kupon.paylasanKullaniciAdi}` : (kupon.paylasanKullaniciId ? kupon.paylasanKullaniciId.substring(0, 8) : 'Avcı');
            sourceBadgeHtml = `
                <div class="flex flex-col gap-0.5">
                    <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-indigo-100 text-indigo-800 dark:bg-indigo-950/50 dark:text-indigo-300 w-fit">
                        <span class="material-symbols-outlined text-[12px]">person</span> Topluluk
                    </span>
                    <span class="text-[11px] text-slate-500 font-medium truncate max-w-[130px]" title="${escapeHtml(author)}">${escapeHtml(author)}</span>
                </div>
            `;
        } else {
            sourceBadgeHtml = `
                <div class="flex flex-col gap-0.5">
                    <span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-300 w-fit">
                        <span class="material-symbols-outlined text-[12px]">smart_toy</span> Botkolik Radarı
                    </span>
                    <span class="text-[10px] text-slate-400 font-mono">Otomasyon</span>
                </div>
            `;
        }

        // Net score & votes
        const netScore = kupon.sicakOySayisi - kupon.sogukOySayisi;
        const netScoreColor = netScore > 0 ? 'text-emerald-600 dark:text-emerald-400' : (netScore < 0 ? 'text-rose-600 dark:text-rose-400' : 'text-slate-500');

        // Dates
        let expiryHtml = '<span class="text-slate-400">Süresiz</span>';
        if (kupon.bitisTarihi) {
            const expDateStr = kupon.bitisTarihi.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' });
            expiryHtml = `<span class="${isExpired ? 'text-rose-500 font-bold' : 'text-slate-600 dark:text-slate-300'}">${expDateStr}</span>`;
        }

        // Status badge
        let statusBadgeHtml = '';
        if (isInvalid) {
            statusBadgeHtml = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-rose-100 text-rose-800 dark:bg-rose-950/50 dark:text-rose-400">Geçersiz</span>`;
        } else if (isExpired) {
            statusBadgeHtml = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/50 dark:text-amber-400">Süresi Doldu</span>`;
        } else {
            statusBadgeHtml = `<span class="inline-flex items-center gap-1 px-2 py-0.5 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-400">Aktif</span>`;
        }

        tr.innerHTML = `
            <td class="p-3.5">
                <span class="px-2.5 py-1 rounded-lg text-xs font-black uppercase tracking-wide inline-block ${storeBadgeClass}">
                    ${escapeHtml(kupon.magazaAdi)}
                </span>
            </td>
            <td class="p-3.5 max-w-[240px]">
                <div class="font-bold text-slate-900 dark:text-white line-clamp-1" title="${escapeHtml(kupon.baslik)}">${escapeHtml(kupon.baslik)}</div>
                <div class="text-[11px] text-slate-500 dark:text-slate-400 line-clamp-1 mt-0.5" title="${escapeHtml(kupon.aciklama || '-')}">${escapeHtml(kupon.aciklama || '-')}</div>
            </td>
            <td class="p-3.5">
                <div class="flex items-center gap-1.5">
                    <span class="font-mono font-black text-xs bg-slate-100 dark:bg-surface-darker px-2.5 py-1 rounded border border-slate-200 dark:border-slate-700 text-slate-900 dark:text-slate-100 select-all">
                        ${escapeHtml(kupon.kuponKodu)}
                    </span>
                    <button type="button" onclick="window.copyCouponCode('${escapeHtml(kupon.kuponKodu)}')" class="p-1 hover:bg-slate-200 dark:hover:bg-slate-700 rounded text-slate-400 hover:text-slate-700 dark:hover:text-white transition-colors" title="Kodu Kopyala">
                        <span class="material-symbols-outlined text-[15px]">content_copy</span>
                    </button>
                </div>
            </td>
            <td class="p-3.5 whitespace-nowrap">
                ${sourceBadgeHtml}
            </td>
            <td class="p-3.5 whitespace-nowrap">
                <div class="flex items-center gap-1 text-[11px]">
                    <span class="text-orange-500 font-bold" title="Sıcak Oylar">🔥 ${kupon.sicakOySayisi}</span>
                    <span class="text-slate-300 dark:text-slate-700">/</span>
                    <span class="text-blue-500 font-bold" title="Soğuk Oylar">❄️ ${kupon.sogukOySayisi}</span>
                </div>
                <div class="text-[10px] font-bold ${netScoreColor} mt-0.5">Net: ${netScore > 0 ? '+' : ''}${netScore}</div>
            </td>
            <td class="p-3.5 text-xs whitespace-nowrap">
                ${expiryHtml}
            </td>
            <td class="p-3.5 whitespace-nowrap">
                ${statusBadgeHtml}
            </td>
            <td class="p-3.5 text-right whitespace-nowrap">
                <div class="flex items-center justify-end gap-1.5">
                    <button type="button" onclick="window.toggleCouponStatus('${kupon.id}')" class="p-1.5 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-surface-dark text-slate-500 hover:text-amber-600 transition-colors" title="${isInvalid ? 'Kuponu Aktif Yap' : 'Kuponu Geçersiz / Çöp Yap'}">
                        <span class="material-symbols-outlined text-[16px]">${isInvalid ? 'check_circle' : 'block'}</span>
                    </button>
                    <button type="button" onclick="editCoupon('${kupon.id}')" class="p-1.5 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-surface-dark hover:text-primary transition-colors" title="Düzenle">
                        <span class="material-symbols-outlined text-[16px]">edit</span>
                    </button>
                    <button type="button" onclick="deleteCoupon('${kupon.id}')" class="p-1.5 rounded-lg border border-red-200 dark:border-red-900/30 bg-red-50 dark:bg-red-900/10 text-red-600 hover:bg-red-100 transition-colors" title="Sil">
                        <span class="material-symbols-outlined text-[16px]">delete</span>
                    </button>
                </div>
            </td>
        `;
        listEl.appendChild(tr);
    });
}

function getStoreColorClass(store) {
    const s = (store || '').toLowerCase();
    if (s.includes('trendyol')) return 'bg-orange-500/10 text-orange-600 border border-orange-500/20';
    if (s.includes('hepsiburada')) return 'bg-amber-500/10 text-amber-600 border border-amber-500/20';
    if (s.includes('amazon')) return 'bg-amber-600/10 text-amber-700 dark:text-amber-400 border border-amber-600/20';
    if (s.includes('n11')) return 'bg-red-500/10 text-red-600 border border-red-500/20';
    if (s.includes('teknosa')) return 'bg-orange-600/10 text-orange-700 dark:text-orange-400 border border-orange-600/20';
    if (s.includes('mediamarkt')) return 'bg-red-700/10 text-red-700 dark:text-red-400 border border-red-700/20';
    if (s.includes('pazarama')) return 'bg-blue-600/10 text-blue-600 border border-blue-600/20';
    if (s.includes('incehesap')) return 'bg-cyan-600/10 text-cyan-600 border border-cyan-600/20';
    if (s.includes('migros')) return 'bg-orange-500/10 text-orange-600 border border-orange-500/20';
    if (s.includes('getir')) return 'bg-purple-600/10 text-purple-600 border border-purple-600/20';
    return 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 border border-slate-200 dark:border-slate-700';
}

window.copyCouponCode = function(code) {
    if (navigator.clipboard) {
        navigator.clipboard.writeText(code).then(() => {
            showSuccess(`Kupon kodu (${code}) panoya kopyalandı!`);
        }).catch(() => {
            prompt('Kupon Kodu:', code);
        });
    } else {
        prompt('Kupon Kodu:', code);
    }
};

window.toggleCouponStatus = async function(id) {
    const kupon = coupons.find(c => c.id === id);
    if (!kupon) return;

    const newDurum = (kupon.durum === 'gecersiz') ? 'aktif' : 'gecersiz';
    try {
        await db.collection('kuponlar').doc(id).update({
            durum: newDurum,
            guncellenmeTarihi: firebase.firestore.FieldValue.serverTimestamp()
        });
        showSuccess(`Kupon durumu '${newDurum === 'aktif' ? 'Aktif' : 'Geçersiz'}' olarak güncellendi.`);
    } catch (e) {
        showError('Durum güncellenirken hata oluştu: ' + e.message);
    }
};

function deleteCoupon(id) {
    if (confirm("Bu kuponu silmek istediğinize emin misiniz? Bu işlem geri alınamaz.")) {
        db.collection('kuponlar').doc(id).delete()
            .then(() => {
                showSuccess("Kupon başarıyla silindi!");
            })
            .catch(error => {
                showError("Kupon silinirken hata oluştu: " + error.message);
            });
    }
}

function openAddCouponModal() {
    const modal = document.getElementById('couponModal');
    
    document.getElementById('couponIdInput').value = '';
    document.getElementById('couponStoreSelect').value = 'Trendyol';
    document.getElementById('couponSourceSelect').value = 'topluluk';
    document.getElementById('couponStatusSelect').value = 'aktif';
    document.getElementById('couponTitleInput').value = '';
    document.getElementById('couponDescriptionInput').value = '';
    document.getElementById('couponCodeInput').value = '';
    document.getElementById('couponExpiryInput').value = '';
    document.getElementById('couponUsernameInput').value = 'admin';
    document.getElementById('couponModalTitle').textContent = 'Yeni Kupon Ekle';

    if (modal) modal.classList.remove('hidden');
}

function editCoupon(id) {
    const kupon = coupons.find(c => c.id === id);
    if (!kupon) return;

    const modal = document.getElementById('couponModal');
    
    document.getElementById('couponIdInput').value = kupon.id;
    document.getElementById('couponStoreSelect').value = kupon.magazaAdi || 'Trendyol';
    document.getElementById('couponSourceSelect').value = kupon.kaynakTipi || 'topluluk';
    document.getElementById('couponStatusSelect').value = kupon.durum || 'aktif';
    document.getElementById('couponTitleInput').value = kupon.baslik || '';
    document.getElementById('couponDescriptionInput').value = kupon.aciklama || '';
    document.getElementById('couponCodeInput').value = kupon.kuponKodu || '';
    document.getElementById('couponUsernameInput').value = kupon.paylasanKullaniciAdi || kupon.paylasanKullaniciId || '';

    // Set date input YYYY-MM-DD
    if (kupon.bitisTarihi instanceof Date && !isNaN(kupon.bitisTarihi.getTime())) {
        const y = kupon.bitisTarihi.getFullYear();
        const m = String(kupon.bitisTarihi.getMonth() + 1).padStart(2, '0');
        const d = String(kupon.bitisTarihi.getDate()).padStart(2, '0');
        document.getElementById('couponExpiryInput').value = `${y}-${m}-${d}`;
    } else {
        document.getElementById('couponExpiryInput').value = '';
    }

    document.getElementById('couponModalTitle').textContent = 'Kupon Düzenle';

    if (modal) modal.classList.remove('hidden');
}

function closeCouponModal() {
    const modal = document.getElementById('couponModal');
    if (modal) modal.classList.add('hidden');
}

function deleteAllCoupons() {
    if (confirm("Tüm kuponları veritabanından kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz!")) {
        const deleteBtn = document.getElementById('deleteAllCouponsBtn');
        if (!deleteBtn) return;
        const originalHtml = deleteBtn.innerHTML;
        deleteBtn.disabled = true;
        deleteBtn.innerHTML = `<span class="material-symbols-outlined animate-spin text-[18px]">sync</span> Siliniyor...`;

        db.collection('kuponlar').get()
            .then(async (querySnapshot) => {
                const docs = querySnapshot.docs;
                if (docs.length === 0) {
                    showSuccess("Silecek kupon bulunamadı.");
                    deleteBtn.disabled = false;
                    deleteBtn.innerHTML = originalHtml;
                    return;
                }

                const chunks = [];
                for (let i = 0; i < docs.length; i += 500) {
                    chunks.push(docs.slice(i, i + 500));
                }

                for (const chunk of chunks) {
                    const batch = db.batch();
                    chunk.forEach((doc) => {
                        batch.delete(doc.ref);
                    });
                    await batch.commit();
                }

                showSuccess("Tüm kuponlar başarıyla silindi!");
                deleteBtn.disabled = false;
                deleteBtn.innerHTML = originalHtml;
                loadCoupons();
            })
            .catch((error) => {
                deleteBtn.disabled = false;
                deleteBtn.innerHTML = originalHtml;
                showError("Kuponlar silinirken hata oluştu: " + error.message);
            });
    }
}

// Register Coupon Event Listeners
function initCouponsListeners() {
    const couponsMenuBtn = document.getElementById('couponsMenuBtn');
    if (couponsMenuBtn) {
        couponsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showCouponsView();
        });
    }

    const refreshCouponsBtn = document.getElementById('refreshCouponsBtn');
    if (refreshCouponsBtn) {
        refreshCouponsBtn.addEventListener('click', () => {
            loadCoupons();
        });
    }

    const addCouponBtn = document.getElementById('addCouponBtn');
    if (addCouponBtn) {
        addCouponBtn.addEventListener('click', () => {
            openAddCouponModal();
        });
    }

    const couponSearchInput = document.getElementById('couponSearchInput');
    if (couponSearchInput) {
        couponSearchInput.addEventListener('input', () => {
            renderCoupons();
        });
    }

    const couponStoreFilter = document.getElementById('couponStoreFilter');
    if (couponStoreFilter) {
        couponStoreFilter.addEventListener('change', () => {
            renderCoupons();
        });
    }

    const couponStatusFilter = document.getElementById('couponStatusFilter');
    if (couponStatusFilter) {
        couponStatusFilter.addEventListener('change', () => {
            renderCoupons();
        });
    }

    const couponSortSelect = document.getElementById('couponSortSelect');
    if (couponSortSelect) {
        couponSortSelect.addEventListener('change', () => {
            renderCoupons();
        });
    }

    const couponForm = document.getElementById('couponForm');
    if (couponForm) {
        couponForm.addEventListener('submit', (e) => {
            e.preventDefault();
            
            const id = document.getElementById('couponIdInput').value;
            const magazaAdi = document.getElementById('couponStoreSelect').value;
            const kaynakTipi = document.getElementById('couponSourceSelect').value;
            const durum = document.getElementById('couponStatusSelect').value;
            const baslik = document.getElementById('couponTitleInput').value.trim();
            const aciklama = document.getElementById('couponDescriptionInput').value.trim();
            const kuponKodu = document.getElementById('couponCodeInput').value.trim().toUpperCase();
            const expiryStr = document.getElementById('couponExpiryInput').value;
            const usernameStr = document.getElementById('couponUsernameInput').value.trim();

            if (!baslik || !kuponKodu) {
                showError("Lütfen tüm zorunlu alanları doldurun.");
                return;
            }

            let bitisTarihi = null;
            if (expiryStr) {
                bitisTarihi = firebase.firestore.Timestamp.fromDate(new Date(`${expiryStr}T23:59:59`));
            }

            const payload = {
                magazaAdi,
                kaynakTipi,
                durum,
                baslik,
                aciklama,
                kuponKodu,
                bitisTarihi: bitisTarihi,
                paylasanKullaniciAdi: usernameStr || (kaynakTipi === 'web' ? 'Botkolik' : 'admin'),
                guncellenmeTarihi: firebase.firestore.FieldValue.serverTimestamp()
            };

            if (id) {
                // Update
                db.collection('kuponlar').doc(id).update(payload)
                    .then(() => {
                        showSuccess("Kupon başarıyla güncellendi!");
                        closeCouponModal();
                    })
                    .catch(err => {
                        showError("Güncelleme hatası: " + err.message);
                    });
            } else {
                // Create
                payload.olusturulmaTarihi = firebase.firestore.FieldValue.serverTimestamp();
                payload.paylasanKullaniciId = 'admin';
                payload.sicakOySayisi = 0;
                payload.sogukOySayisi = 0;

                db.collection('kuponlar').add(payload)
                    .then(() => {
                        showSuccess("Kupon başarıyla oluşturuldu!");
                        closeCouponModal();
                    })
                    .catch(err => {
                        showError("Ekleme hatası: " + err.message);
                    });
            }
        });
    }

    const scrapeCouponsBtn = document.getElementById('scrapeCouponsBtn');
    if (scrapeCouponsBtn) {
        scrapeCouponsBtn.addEventListener('click', () => {
            if (!confirm("Kuponları DonanımHaber ve diğer kaynaklardan otomatik çekmek istediğinize emin misiniz? Bu işlem mevcuttaki web kaynaklı (radar) kuponları güncelleyecektir. Topluluk kuponları kesinlikle silinmez.")) {
                return;
            }

            const originalHtml = scrapeCouponsBtn.innerHTML;
            scrapeCouponsBtn.disabled = true;
            scrapeCouponsBtn.innerHTML = `
                <span class="material-symbols-outlined animate-spin text-[18px]">sync</span>
                <span class="hidden sm:inline">Kazınıyor...</span>
            `;

            const scrapeCouponsManual = firebase.functions().httpsCallable('scrapeCouponsManual', { timeout: 540000 });
            scrapeCouponsManual()
                .then((res) => {
                    scrapeCouponsBtn.disabled = false;
                    scrapeCouponsBtn.innerHTML = originalHtml;
                    if (res.data && res.data.success) {
                        showSuccess(`${res.data.count} adet kupon başarıyla çekildi ve güncellendi.`);
                        loadCoupons();
                    } else {
                        showError(res.data.message || "Kupon çekme işlemi başarısız.");
                    }
                })
                .catch((err) => {
                    scrapeCouponsBtn.disabled = false;
                    scrapeCouponsBtn.innerHTML = originalHtml;
                    showError("Kupon çekme hatası: " + err.message);
                });
        });
    }

    const deleteAllCouponsBtn = document.getElementById('deleteAllCouponsBtn');
    if (deleteAllCouponsBtn) {
        deleteAllCouponsBtn.addEventListener('click', () => {
            deleteAllCoupons();
        });
    }

    const settingsToggleCouponsBtn = document.getElementById('settingsToggleCouponsBtn');
    if (settingsToggleCouponsBtn) {
        settingsToggleCouponsBtn.addEventListener('change', () => {
            toggleCouponsEnabled();
        });
    }
}

// =========================================================================
// FAZ 6 - AKTÜEL KATALOGLAR & BROŞÜRLER YÖNETİMİ (CATALOGS SUBSYSTEM)
// =========================================================================

let currentCatalogStoreFilter = 'all';
let currentCatalogStatusFilter = 'all'; // 'all' | 'active' | 'upcoming' | 'expired'
let catalogSearchQuery = '';

function showCatalogsView() {
    currentView = 'catalogs';
    showView('catalogsView');
    updateMenuActiveState('catalogs');
    if (catalogs.length === 0) {
        loadCatalogs();
    } else {
        renderCatalogs();
    }
}

function loadCatalogs() {
    const loadingEl = document.getElementById('catalogsLoadingIndicator');
    const emptyEl = document.getElementById('catalogsEmptyState');
    const listEl = document.getElementById('catalogsList');

    if (loadingEl) {
        loadingEl.style.display = 'block';
        loadingEl.textContent = 'Kataloglar yükleniyor...';
    }
    if (emptyEl) emptyEl.classList.add('hidden');

    if (catalogsUnsubscribe) {
        catalogsUnsubscribe();
        catalogsUnsubscribe = null;
    }

    try {
        catalogsUnsubscribe = db.collection('kataloglar')
            .orderBy('baslangicTarihi', 'desc')
            .onSnapshot((snapshot) => {
                catalogs = snapshot.docs.map(doc => {
                    const data = doc.data();
                    let startDate = new Date();
                    let endDate = new Date();
                    
                    if (data.baslangicTarihi) {
                        startDate = typeof data.baslangicTarihi.toDate === 'function' 
                            ? data.baslangicTarihi.toDate() 
                            : new Date(data.baslangicTarihi);
                    }
                    if (data.bitisTarihi) {
                        endDate = typeof data.bitisTarihi.toDate === 'function' 
                            ? data.bitisTarihi.toDate() 
                            : new Date(data.bitisTarihi);
                    }

                    return {
                        id: doc.id,
                        magazaKodu: (data.magazaKodu || '').toLowerCase(),
                        katalogBasligi: data.katalogBasligi || '',
                        baslangicTarihi: startDate,
                        bitisTarihi: endDate,
                        sayfaResimleri: Array.isArray(data.sayfaResimleri) ? data.sayfaResimleri : [],
                        kapakResmi: data.kapakResmi || ''
                    };
                });

                if (loadingEl) loadingEl.style.display = 'none';

                updateCatalogsSummaryStats();
                populateCatalogStoreFilter();

                if (catalogs.length === 0) {
                    if (emptyEl) {
                        emptyEl.classList.remove('hidden');
                        emptyEl.textContent = 'Henüz katalog bulunamadı';
                    }
                    if (listEl) listEl.innerHTML = '';
                } else {
                    renderCatalogs();
                }
            }, (error) => {
                console.error("Error loading catalogs:", error);
                if (loadingEl) loadingEl.textContent = 'Hata: ' + error.message;
                showError("Kataloglar yüklenirken hata oluştu: " + error.message);
            });
    } catch (err) {
        console.error("Error setting up catalogs listener:", err);
        if (loadingEl) loadingEl.textContent = 'Hata: ' + err.message;
    }
}

// Update Top Quick Stat Counters for Catalogs
function updateCatalogsSummaryStats() {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const total = catalogs.length;
    let activeCount = 0;
    let upcomingCount = 0;
    let totalPages = 0;
    const storesSet = new Set();

    catalogs.forEach(k => {
        if (k.magazaKodu) storesSet.add(k.magazaKodu);
        totalPages += (k.sayfaResimleri ? k.sayfaResimleri.length : 0);

        const sDate = new Date(k.baslangicTarihi.getFullYear(), k.baslangicTarihi.getMonth(), k.baslangicTarihi.getDate());
        const eDate = new Date(k.bitisTarihi.getFullYear(), k.bitisTarihi.getMonth(), k.bitisTarihi.getDate());

        if (today < sDate) {
            upcomingCount++;
        } else if (today <= eDate) {
            activeCount++;
        }
    });

    const elTotal = document.getElementById('catalogStatTotal');
    if (elTotal) elTotal.textContent = total;

    const elActive = document.getElementById('catalogStatActive');
    if (elActive) elActive.textContent = activeCount;

    const elUpcoming = document.getElementById('catalogStatUpcoming');
    if (elUpcoming) elUpcoming.textContent = upcomingCount;

    const elPages = document.getElementById('catalogStatPages');
    if (elPages) elPages.textContent = totalPages;

    const elStores = document.getElementById('catalogStatStores');
    if (elStores) elStores.textContent = storesSet.size;
}

// Populate Store Filter dropdown for Catalogs
function populateCatalogStoreFilter() {
    const filterEl = document.getElementById('catalogStoreFilter');
    if (!filterEl) return;

    const currentVal = filterEl.value;
    const storesSet = new Set();
    catalogs.forEach(k => {
        if (k.magazaKodu) storesSet.add(k.magazaKodu);
    });

    const sortedStores = Array.from(storesSet).sort();
    let optionsHtml = '<option value="all">Tüm Mağazalar</option>';
    sortedStores.forEach(s => {
        optionsHtml += `<option value="${escapeHtml(s)}">${escapeHtml(s.toUpperCase())}</option>`;
    });

    filterEl.innerHTML = optionsHtml;
    if (storesSet.has(currentVal) || currentVal === 'all') {
        filterEl.value = currentVal;
    } else {
        filterEl.value = 'all';
    }
}

function getCatalogValidityBadge(katalog) {
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const start = new Date(katalog.baslangicTarihi.getFullYear(), katalog.baslangicTarihi.getMonth(), katalog.baslangicTarihi.getDate());
    const expiry = new Date(katalog.bitisTarihi.getFullYear(), katalog.bitisTarihi.getMonth(), katalog.bitisTarihi.getDate());

    if (today < start) {
        const daysToStart = Math.round((start - today) / (1000 * 60 * 60 * 24));
        if (daysToStart === 1) {
            return `<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/50 dark:text-amber-400">Yarın başlıyor</span>`;
        }
        return `<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold bg-amber-100 text-amber-800 dark:bg-amber-950/50 dark:text-amber-400">${daysToStart} gün sonra</span>`;
    }

    if (today > expiry) {
        return `<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold bg-slate-100 text-slate-600 dark:bg-slate-800 dark:text-slate-400">Süresi Bitti</span>`;
    }

    const daysLeft = Math.round((expiry - today) / (1000 * 60 * 60 * 24));
    if (daysLeft === 0) {
        return `<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold bg-rose-100 text-rose-800 dark:bg-rose-950/50 dark:text-rose-400">Son Gün!</span>`;
    }
    return `<span class="inline-flex items-center gap-1 px-2.5 py-1 rounded-full text-[10px] font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-400">Yayında (${daysLeft} gün kaldı)</span>`;
}

function getCatalogStoreBadgeClass(storeCode) {
    const s = (storeCode || '').toLowerCase();
    if (s === 'bim') return 'bg-cyan-500/10 text-cyan-600 border border-cyan-500/20';
    if (s === 'a101') return 'bg-blue-500/10 text-blue-600 border border-blue-500/20';
    if (s === 'sok') return 'bg-amber-500/10 text-amber-600 border border-amber-500/20';
    if (s === 'migros') return 'bg-orange-500/10 text-orange-600 border border-orange-500/20';
    if (s === 'carrefoursa') return 'bg-indigo-500/10 text-indigo-600 border border-indigo-500/20';
    if (s === 'gratis') return 'bg-purple-500/10 text-purple-600 border border-purple-500/20';
    if (s === 'watsons') return 'bg-teal-500/10 text-teal-600 border border-teal-500/20';
    if (s === 'rossmann') return 'bg-red-500/10 text-red-600 border border-red-500/20';
    return 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300 border border-slate-200 dark:border-slate-700';
}

function renderCatalogs() {
    const listEl = document.getElementById('catalogsList');
    const emptyEl = document.getElementById('catalogsEmptyState');
    const countEl = document.getElementById('catalogFilteredCount');
    if (!listEl) return;

    listEl.innerHTML = '';
    const now = new Date();
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());

    const searchQuery = (document.getElementById('catalogSearchInput')?.value || '').toLowerCase().trim();
    currentCatalogStoreFilter = document.getElementById('catalogStoreFilter')?.value || 'all';
    currentCatalogStatusFilter = document.getElementById('catalogStatusFilter')?.value || 'all';

    const filtered = catalogs.filter(katalog => {
        // 1. Store Filter
        if (currentCatalogStoreFilter !== 'all' && katalog.magazaKodu !== currentCatalogStoreFilter) return false;

        // 2. Status Filter
        const sDate = new Date(katalog.baslangicTarihi.getFullYear(), katalog.baslangicTarihi.getMonth(), katalog.baslangicTarihi.getDate());
        const eDate = new Date(katalog.bitisTarihi.getFullYear(), katalog.bitisTarihi.getMonth(), katalog.bitisTarihi.getDate());

        if (currentCatalogStatusFilter === 'active' && (today < sDate || today > eDate)) return false;
        if (currentCatalogStatusFilter === 'upcoming' && today >= sDate) return false;
        if (currentCatalogStatusFilter === 'expired' && today <= eDate) return false;

        // 3. Search Filter
        if (searchQuery) {
            const matchTitle = (katalog.katalogBasligi || '').toLowerCase().includes(searchQuery);
            const matchStore = (katalog.magazaKodu || '').toLowerCase().includes(searchQuery);
            if (!matchTitle && !matchStore) return false;
        }

        return true;
    });

    if (countEl) {
        countEl.textContent = `Gösterilen: ${filtered.length} / ${catalogs.length} katalog`;
    }

    if (filtered.length === 0) {
        if (emptyEl) {
            emptyEl.classList.remove('hidden');
            emptyEl.textContent = searchQuery || currentCatalogStoreFilter !== 'all' || currentCatalogStatusFilter !== 'all'
                ? 'Filtrelerle eşleşen katalog bulunamadı.'
                : 'Henüz katalog yok';
        }
        return;
    }

    if (emptyEl) emptyEl.classList.add('hidden');

    filtered.forEach(katalog => {
        const tr = document.createElement('tr');
        tr.className = 'hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors border-b border-slate-100 dark:border-slate-800/80';

        const startDateStr = katalog.baslangicTarihi.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' });
        const endDateStr = katalog.bitisTarihi.toLocaleDateString('tr-TR', { day: '2-digit', month: '2-digit', year: 'numeric' });
        const validityBadge = getCatalogValidityBadge(katalog);
        const storeBadgeClass = getCatalogStoreBadgeClass(katalog.magazaKodu);

        const coverSrc = katalog.kapakResmi || (katalog.sayfaResimleri && katalog.sayfaResimleri.length > 0 ? katalog.sayfaResimleri[0] : '//cdn.akakce.com/t.gif');

        tr.innerHTML = `
            <td class="p-3.5">
                <div class="relative group cursor-pointer w-12 h-16 rounded-lg overflow-hidden border border-slate-200 dark:border-slate-800 shadow-xs" onclick="window.openCatalogDetailModal('${katalog.id}')" title="Büyüt / Sayfaları İncele">
                    <img src="${coverSrc}" class="w-full h-full object-contain group-hover:scale-110 transition-transform" alt="Kapak" onerror="this.onerror=null; this.src='//cdn.akakce.com/t.gif'"/>
                    <div class="absolute inset-0 bg-black/30 opacity-0 group-hover:opacity-100 flex items-center justify-center transition-opacity">
                        <span class="material-symbols-outlined text-white text-[18px]">zoom_in</span>
                    </div>
                </div>
            </td>
            <td class="p-3.5">
                <span class="px-2.5 py-1 rounded-lg text-xs font-black uppercase tracking-wide inline-block ${storeBadgeClass}">
                    ${escapeHtml(katalog.magazaKodu)}
                </span>
            </td>
            <td class="p-3.5 max-w-[260px]">
                <a href="javascript:void(0)" onclick="window.openCatalogDetailModal('${katalog.id}')" class="font-bold text-slate-900 dark:text-white hover:text-primary transition-colors line-clamp-2" title="${escapeHtml(katalog.katalogBasligi)}">
                    ${escapeHtml(katalog.katalogBasligi)}
                </a>
                <span class="text-[10px] text-slate-400 font-mono mt-0.5 block truncate">ID: ${katalog.id}</span>
            </td>
            <td class="p-3.5 whitespace-nowrap">
                ${validityBadge}
            </td>
            <td class="p-3.5 text-xs text-slate-600 dark:text-slate-300 whitespace-nowrap">${startDateStr}</td>
            <td class="p-3.5 text-xs text-slate-600 dark:text-slate-300 whitespace-nowrap">${endDateStr}</td>
            <td class="p-3.5 whitespace-nowrap">
                <button type="button" onclick="window.openCatalogDetailModal('${katalog.id}')" class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-lg bg-slate-100 dark:bg-surface-darker text-slate-700 dark:text-slate-300 font-bold hover:bg-primary/10 hover:text-primary transition-colors cursor-pointer text-xs">
                    <span class="material-symbols-outlined text-[15px]">auto_stories</span>
                    <span>${katalog.sayfaResimleri ? katalog.sayfaResimleri.length : 0} sayfa</span>
                </button>
            </td>
            <td class="p-3.5 text-right whitespace-nowrap">
                <div class="flex items-center justify-end gap-1.5">
                    <button type="button" onclick="window.openCatalogDetailModal('${katalog.id}')" class="p-1.5 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-surface-dark hover:text-primary transition-colors" title="Sayfaları İncele">
                        <span class="material-symbols-outlined text-[16px]">visibility</span>
                    </button>
                    <button type="button" onclick="window.openEditCatalogModal('${katalog.id}')" class="p-1.5 rounded-lg border border-slate-200 dark:border-slate-700 bg-white dark:bg-surface-dark hover:text-primary transition-colors" title="Düzenle">
                        <span class="material-symbols-outlined text-[16px]">edit</span>
                    </button>
                    <button type="button" onclick="window.deleteSingleCatalog('${katalog.id}')" class="p-1.5 rounded-lg border border-red-200 dark:border-red-900/30 bg-red-50 dark:bg-red-900/10 text-red-600 hover:bg-red-100 transition-colors" title="Sil">
                        <span class="material-symbols-outlined text-[16px]">delete</span>
                    </button>
                </div>
            </td>
        `;
        listEl.appendChild(tr);
    });
}

// Lightbox Modal for Catalog Pages
window.openCatalogDetailModal = function(catalogId) {
    const katalog = catalogs.find(k => k.id === catalogId);
    if (!katalog) return;

    const modal = document.getElementById('catalogDetailModal');
    const storeBadge = document.getElementById('catalogDetailStoreBadge');
    const titleEl = document.getElementById('catalogDetailTitle');
    const subtitleEl = document.getElementById('catalogDetailSubtitle');
    const pageBadge = document.getElementById('catalogDetailPageCountBadge');
    const docIdEl = document.getElementById('catalogDetailDocId');
    const gridEl = document.getElementById('catalogDetailPagesGrid');

    if (storeBadge) storeBadge.textContent = (katalog.magazaKodu || 'MAĞAZA').toUpperCase();
    if (titleEl) titleEl.textContent = katalog.katalogBasligi || 'Katalog';
    
    const startStr = katalog.baslangicTarihi.toLocaleDateString('tr-TR');
    const endStr = katalog.bitisTarihi.toLocaleDateString('tr-TR');
    if (subtitleEl) subtitleEl.textContent = `Başlangıç: ${startStr} | Bitiş: ${endStr}`;
    
    const pages = katalog.sayfaResimleri || [];
    if (pageBadge) pageBadge.textContent = `${pages.length} Sayfa`;
    if (docIdEl) docIdEl.textContent = `Katalog ID: ${katalog.id}`;

    if (gridEl) {
        gridEl.innerHTML = '';
        if (pages.length === 0) {
            gridEl.innerHTML = `<div class="col-span-full py-12 text-center text-slate-400">Bu katalogda kayıtlı sayfa resmi bulunamadı.</div>`;
        } else {
            pages.forEach((url, idx) => {
                const pageCard = document.createElement('div');
                pageCard.className = 'group relative rounded-xl border border-slate-200 dark:border-slate-800 bg-slate-50 dark:bg-surface-darker overflow-hidden shadow-xs hover:shadow-md transition-all flex flex-col';
                pageCard.innerHTML = `
                    <div class="relative w-full aspect-[3/4] overflow-hidden bg-slate-200 dark:bg-slate-900">
                        <img src="${url}" alt="Sayfa ${idx + 1}" class="w-full h-full object-contain group-hover:scale-105 transition-transform" loading="lazy" onerror="this.onerror=null; this.src='//cdn.akakce.com/t.gif'"/>
                        <div class="absolute inset-0 bg-black/40 opacity-0 group-hover:opacity-100 transition-opacity flex items-center justify-center gap-2">
                            <a href="${url}" target="_blank" rel="noopener noreferrer" class="px-3 py-1.5 rounded-lg bg-white/90 dark:bg-surface-dark/90 text-slate-900 dark:text-white font-bold text-xs shadow-lg hover:bg-white flex items-center gap-1">
                                <span class="material-symbols-outlined text-[16px]">open_in_new</span> Tam Boyut
                            </a>
                        </div>
                    </div>
                    <div class="p-2.5 flex items-center justify-between border-t border-slate-200 dark:border-slate-800 bg-white dark:bg-surface-dark">
                        <span class="font-bold text-slate-800 dark:text-slate-200 text-xs">Sayfa ${idx + 1}</span>
                        <span class="text-[10px] text-slate-400 font-mono">${idx + 1} / ${pages.length}</span>
                    </div>
                `;
                gridEl.appendChild(pageCard);
            });
        }
    }

    if (modal) modal.classList.remove('hidden');
};

window.closeCatalogDetailModal = function() {
    const modal = document.getElementById('catalogDetailModal');
    if (modal) modal.classList.add('hidden');
};

// Add / Edit Catalog Modals
window.openAddCatalogModal = function() {
    const modal = document.getElementById('catalogEditModal');
    const titleEl = document.getElementById('catalogEditModalTitle');
    if (titleEl) titleEl.textContent = 'Yeni Katalog Ekle';

    document.getElementById('catalogEditIdInput').value = '';
    document.getElementById('catalogEditStoreInput').value = '';
    document.getElementById('catalogEditTitleInput').value = '';
    document.getElementById('catalogEditStartDateInput').value = '';
    document.getElementById('catalogEditEndDateInput').value = '';
    document.getElementById('catalogEditCoverInput').value = '';

    if (modal) modal.classList.remove('hidden');
};

window.openEditCatalogModal = function(catalogId) {
    const katalog = catalogs.find(k => k.id === catalogId);
    if (!katalog) return;

    const modal = document.getElementById('catalogEditModal');
    const titleEl = document.getElementById('catalogEditModalTitle');
    if (titleEl) titleEl.textContent = 'Katalog Düzenle';

    document.getElementById('catalogEditIdInput').value = katalog.id;
    document.getElementById('catalogEditStoreInput').value = katalog.magazaKodu || '';
    document.getElementById('catalogEditTitleInput').value = katalog.katalogBasligi || '';
    document.getElementById('catalogEditCoverInput').value = katalog.kapakResmi || '';

    // Date formatting YYYY-MM-DD
    if (katalog.baslangicTarihi instanceof Date && !isNaN(katalog.baslangicTarihi.getTime())) {
        const y = katalog.baslangicTarihi.getFullYear();
        const m = String(katalog.baslangicTarihi.getMonth() + 1).padStart(2, '0');
        const d = String(katalog.baslangicTarihi.getDate()).padStart(2, '0');
        document.getElementById('catalogEditStartDateInput').value = `${y}-${m}-${d}`;
    } else {
        document.getElementById('catalogEditStartDateInput').value = '';
    }

    if (katalog.bitisTarihi instanceof Date && !isNaN(katalog.bitisTarihi.getTime())) {
        const y = katalog.bitisTarihi.getFullYear();
        const m = String(katalog.bitisTarihi.getMonth() + 1).padStart(2, '0');
        const d = String(katalog.bitisTarihi.getDate()).padStart(2, '0');
        document.getElementById('catalogEditEndDateInput').value = `${y}-${m}-${d}`;
    } else {
        document.getElementById('catalogEditEndDateInput').value = '';
    }

    if (modal) modal.classList.remove('hidden');
};

window.closeCatalogEditModal = function() {
    const modal = document.getElementById('catalogEditModal');
    if (modal) modal.classList.add('hidden');
};

// Delete single catalog
window.deleteSingleCatalog = function(catalogId) {
    if (confirm("Bu kataloğu ve tüm sayfalarını silmek istediğinize emin misiniz?")) {
        db.collection('kataloglar').doc(catalogId).delete()
            .then(() => {
                showSuccess("Katalog başarıyla silindi!");
            })
            .catch((err) => {
                showError("Katalog silinirken hata oluştu: " + err.message);
            });
    }
};

function deleteAllCatalogs() {
    if (confirm("Tüm katalogları veritabanından kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz!")) {
        const deleteBtn = document.getElementById('deleteAllCatalogsBtn');
        if (!deleteBtn) return;
        const originalHtml = deleteBtn.innerHTML;
        deleteBtn.disabled = true;
        deleteBtn.innerHTML = `<span class="material-symbols-outlined animate-spin text-[18px]">sync</span> Siliniyor...`;

        db.collection('kataloglar').get()
            .then(async (querySnapshot) => {
                const docs = querySnapshot.docs;
                if (docs.length === 0) {
                    showSuccess("Silecek katalog bulunamadı.");
                    deleteBtn.disabled = false;
                    deleteBtn.innerHTML = originalHtml;
                    return;
                }

                const chunks = [];
                for (let i = 0; i < docs.length; i += 500) {
                    chunks.push(docs.slice(i, i + 500));
                }

                for (const chunk of chunks) {
                    const batch = db.batch();
                    chunk.forEach((doc) => {
                        batch.delete(doc.ref);
                    });
                    await batch.commit();
                }

                showSuccess("Tüm kataloglar başarıyla silindi!");
                deleteBtn.disabled = false;
                deleteBtn.innerHTML = originalHtml;
                loadCatalogs();
            })
            .catch((error) => {
                deleteBtn.disabled = false;
                deleteBtn.innerHTML = originalHtml;
                showError("Kataloglar silinirken hata oluştu: " + error.message);
            });
    }
}

function initCatalogsListeners() {
    const refreshCatalogsBtn = document.getElementById('refreshCatalogsBtn');
    if (refreshCatalogsBtn) {
        refreshCatalogsBtn.addEventListener('click', () => {
            loadCatalogs();
        });
    }

    const catalogSearchInput = document.getElementById('catalogSearchInput');
    if (catalogSearchInput) {
        catalogSearchInput.addEventListener('input', () => {
            renderCatalogs();
        });
    }

    const catalogStoreFilter = document.getElementById('catalogStoreFilter');
    if (catalogStoreFilter) {
        catalogStoreFilter.addEventListener('change', () => {
            renderCatalogs();
        });
    }

    const catalogStatusFilter = document.getElementById('catalogStatusFilter');
    if (catalogStatusFilter) {
        catalogStatusFilter.addEventListener('change', () => {
            renderCatalogs();
        });
    }

    const catalogEditForm = document.getElementById('catalogEditForm');
    if (catalogEditForm) {
        catalogEditForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            const id = document.getElementById('catalogEditIdInput').value;
            const magazaKodu = document.getElementById('catalogEditStoreInput').value.trim().toLowerCase();
            const katalogBasligi = document.getElementById('catalogEditTitleInput').value.trim();
            const startDateStr = document.getElementById('catalogEditStartDateInput').value;
            const endDateStr = document.getElementById('catalogEditEndDateInput').value;
            const kapakResmi = document.getElementById('catalogEditCoverInput').value.trim();

            if (!magazaKodu || !katalogBasligi || !startDateStr || !endDateStr) {
                showError("Lütfen tüm zorunlu alanları doldurun.");
                return;
            }

            const baslangicTarihi = firebase.firestore.Timestamp.fromDate(new Date(`${startDateStr}T00:00:00`));
            const bitisTarihi = firebase.firestore.Timestamp.fromDate(new Date(`${endDateStr}T23:59:59`));

            const payload = {
                magazaKodu,
                katalogBasligi,
                baslangicTarihi,
                bitisTarihi,
                kapakResmi,
                guncellenmeTarihi: firebase.firestore.FieldValue.serverTimestamp()
            };

            try {
                if (id) {
                    await db.collection('kataloglar').doc(id).update(payload);
                    showSuccess("Katalog başarıyla güncellendi!");
                } else {
                    payload.olusturulmaTarihi = firebase.firestore.FieldValue.serverTimestamp();
                    payload.sayfaResimleri = kapakResmi ? [kapakResmi] : [];
                    const newDocId = `${magazaKodu}_${Date.now()}`;
                    await db.collection('kataloglar').doc(newDocId).set(payload);
                    showSuccess("Yeni katalog başarıyla eklendi!");
                }
                closeCatalogEditModal();
            } catch (err) {
                showError("Katalog kaydedilirken hata: " + err.message);
            }
        });
    }

    const scrapeCatalogsBtn = document.getElementById('scrapeCatalogsBtn');
    if (scrapeCatalogsBtn) {
        scrapeCatalogsBtn.addEventListener('click', () => {
            if (!confirm("Katalogları Akakçe'den otomatik çekmek istediğinize emin misiniz? Bu işlem tüm mevcuttaki katalogları silecek ve yenilerini yükleyecektir. İşlem 1-2 dakika sürebilir.")) {
                return;
            }

            const originalHtml = scrapeCatalogsBtn.innerHTML;
            scrapeCatalogsBtn.disabled = true;
            scrapeCatalogsBtn.innerHTML = `
                <span class="material-symbols-outlined animate-spin text-[18px]">sync</span>
                <span class="hidden sm:inline">Kazınıyor...</span>
            `;

            const scrapeCatalogsManual = firebase.functions().httpsCallable('scrapeCatalogsManual', { timeout: 540000 });
            scrapeCatalogsManual()
                .then((res) => {
                    scrapeCatalogsBtn.disabled = false;
                    scrapeCatalogsBtn.innerHTML = originalHtml;
                    if (res.data && res.data.success) {
                        showSuccess(`${res.data.count} adet katalog başarıyla çekildi ve güncellendi.`);
                        loadCatalogs();
                    } else {
                        showError(res.data.message || "Katalog çekme işlemi başarısız.");
                    }
                })
                .catch((err) => {
                    scrapeCatalogsBtn.disabled = false;
                    scrapeCatalogsBtn.innerHTML = originalHtml;
                    showError("Katalog çekme hatası: " + err.message);
                });
        });
    }

    const deleteAllCatalogsBtn = document.getElementById('deleteAllCatalogsBtn');
    if (deleteAllCatalogsBtn) {
        deleteAllCatalogsBtn.addEventListener('click', () => {
            deleteAllCatalogs();
        });
    }
}

if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', () => {
        initCouponsListeners();
        initCatalogsListeners();
    });
} else {
    initCouponsListeners();
    initCatalogsListeners();
}

window.triggerCleanVmExecution = async function() {
    if (!confirm('Sunucu bellek ve performans temizliğini başlatmak istediğinize emin misiniz?')) {
        return;
    }
    const btn = document.getElementById('triggerCleanVmBtn');
    if (btn) btn.disabled = true;

    try {
        await db.collection('settings').doc('telegramBot').set({
            cleanVmTrigger: Date.now()
        }, { merge: true });
        
        if (typeof showSuccess === 'function') {
            showSuccess('Sunucu temizlik komutu gönderildi. İşlem takip ediliyor...');
        }
    } catch (e) {
        if (btn) btn.disabled = false;
        if (typeof showError === 'function') {
            showError('Temizlik başlatılamadı: ' + e.message);
        } else {
            alert('Hata: ' + e.message);
        }
    }
};

window.toggleCleanVmLogs = function() {
    const logsEl = document.getElementById('cleanVmLogsContainer');
    if (logsEl) {
        logsEl.classList.toggle('hidden');
    }
};

// ============================================================================
// 🤖 TELEGRAM BOT OPERASYON & TEŞHİS MERKEZİ (telegramBotView)
// ============================================================================

let botDetailUnsubscribe = null;
let botDetailCurrentTab = 'channels';
let botDetailDealsLoaded = false;
let botDetailLogsLoaded = false;
let lastBotDetailData = null;

function showTelegramBotView() {
    currentView = 'telegramBot';
    showView('telegramBotView');
    updateMenuActiveState('telegramBot');
    loadTelegramBotDetailedView();
}
window.showTelegramBotView = showTelegramBotView;

function showObservabilityView() {
    currentView = 'observability';
    showView('observabilityView');
    updateMenuActiveState('observability');
    if (window.ObservabilityManager) {
        window.ObservabilityManager.init();
    }
}
window.showObservabilityView = showObservabilityView;

// ---------- Real-time Firestore Listener for settings/telegramBot ----------

function loadTelegramBotDetailedView() {
    console.log('🤖 Loading Telegram Bot detailed view...');

    // Unsubscribe previous listener if any
    if (botDetailUnsubscribe) {
        botDetailUnsubscribe();
        botDetailUnsubscribe = null;
    }

    botDetailUnsubscribe = db.collection('settings').doc('telegramBot').onSnapshot(snapshot => {
        if (!snapshot.exists) {
            console.warn('⚠️ settings/telegramBot document not found');
            return;
        }
        const data = snapshot.data();
        lastBotDetailData = data;
        renderBotDetailTelemetry(data);
        renderBotDetailChannels(data);
        renderBotDetailCleanVmStatus(data);
        updateBotDetailMasterToggle(data);
        updateSidebarBotPulse(data);
    }, err => {
        console.error('❌ Bot detail listener error:', err);
    });

    // Reset tab-specific loaded flags
    botDetailDealsLoaded = false;
    botDetailLogsLoaded = false;

    // Load deals if on deals tab
    if (botDetailCurrentTab === 'deals') {
        loadBotRecentDeals();
    }
    // Load logs if on logs tab
    if (botDetailCurrentTab === 'logs') {
        loadBotApmLogs();
    }
}
window.loadTelegramBotDetailedView = loadTelegramBotDetailedView;

// ---------- Render Telemetry Cards ----------

function renderBotDetailTelemetry(data) {
    const lastHb = data.lastHeartbeatAt?.toDate ? data.lastHeartbeatAt.toDate() : (data.lastHeartbeatAt ? new Date(data.lastHeartbeatAt._seconds * 1000) : null);
    const isOnline = lastHb && (Math.abs(Date.now() - lastHb.getTime()) < 15 * 60 * 1000) && (data.status === 'online');
    const environment = data.environment || 'DEV';
    const isProd = environment.toUpperCase() === 'PROD';

    // Environment badge
    const envBadge = document.getElementById('botDetailEnvBadge');
    if (envBadge) {
        const port = isProd ? '8082' : '8081';
        const container = isProd ? 'prod-bot' : 'dev-bot';
        envBadge.textContent = `${environment.toUpperCase()} (${container} • Port ${port})`;
        if (isProd) {
            envBadge.className = 'px-2.5 py-0.5 rounded-full text-xs font-black bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-400 border border-emerald-300 dark:border-emerald-800';
        } else {
            envBadge.className = 'px-2.5 py-0.5 rounded-full text-xs font-black bg-blue-100 text-blue-800 dark:bg-blue-950/60 dark:text-blue-400 border border-blue-300 dark:border-blue-800';
        }
    }

    // Status badge
    const statusBadge = document.getElementById('botDetailStatusBadge');
    if (statusBadge) {
        if (isOnline) {
            statusBadge.className = 'inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full text-xs font-bold bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-400 border border-emerald-300 dark:border-emerald-800';
            statusBadge.innerHTML = '<span class="w-2 h-2 rounded-full bg-emerald-500 animate-pulse"></span>Çevrimiçi';
        } else {
            statusBadge.className = 'inline-flex items-center gap-1.5 px-3 py-0.5 rounded-full text-xs font-bold bg-red-100 text-red-800 dark:bg-red-950/60 dark:text-red-400 border border-red-300 dark:border-red-800';
            statusBadge.innerHTML = '<span class="w-2 h-2 rounded-full bg-red-500"></span>Çevrimdışı';
        }
    }

    // Container info
    const containerInfo = document.getElementById('botContainerInfoText');
    if (containerInfo) {
        containerInfo.textContent = isProd ? 'prod-bot (Port 8082)' : 'dev-bot (Port 8081)';
    }

    // Telemetry counters
    const msgCount = data.msgCount || 0;
    const dealCount = data.dealCount || 0;
    const dupCount = data.dupCount || 0;
    const errCount = data.errCount || 0;

    const setEl = (id, text) => { const el = document.getElementById(id); if (el) el.textContent = text; };
    const setHtml = (id, html) => { const el = document.getElementById(id); if (el) el.innerHTML = html; };

    setEl('botDetailMsgCount', msgCount.toLocaleString('tr-TR'));
    setEl('botDetailDealCount', dealCount.toLocaleString('tr-TR'));
    setEl('botDetailDupCount', dupCount.toLocaleString('tr-TR'));
    setEl('botDetailErrCount', errCount.toLocaleString('tr-TR'));

    // Conversion rate
    const convRate = msgCount > 0 ? ((dealCount / msgCount) * 100).toFixed(1) : '0';
    setEl('botDetailConversionRate', `%${convRate} Dönüşüm`);

    // Filter rate
    const filterRate = msgCount > 0 ? ((dupCount / msgCount) * 100).toFixed(1) : '0';
    setEl('botDetailFilterRate', `%${filterRate} Filtrelendi`);

    // Last message time
    const lastMsgTime = data.lastMessageTime?.toDate ? data.lastMessageTime.toDate() : (data.lastMessageTime ? new Date(data.lastMessageTime._seconds * 1000) : null);
    if (lastMsgTime) {
        setEl('botDetailLastMsgTime', `Son: ${formatRelativeTime(lastMsgTime)}`);
    } else {
        setEl('botDetailLastMsgTime', 'Son: Henüz yok');
    }

    // Error badge
    if (errCount === 0) {
        setHtml('botDetailErrorBadge', '<span class="text-emerald-600 dark:text-emerald-400">0 Hata • Stabil</span>');
    } else {
        setHtml('botDetailErrorBadge', `<span class="text-rose-500">${errCount} Hata Oluştu</span>`);
    }

    // Heap & memory from cleanVmStatus
    if (data.cleanVmStatus) {
        const st = data.cleanVmStatus;
        setEl('botDetailHeapUsed', st.heapUsedMb ? `${st.heapUsedMb} MB` : '—');
        if (st.freedHeapMb && parseFloat(st.freedHeapMb) > 0) {
            setEl('botDetailFreedHeap', `${st.freedHeapMb} MB Serbest`);
        } else {
            setEl('botDetailFreedHeap', 'V8 Optimize');
        }
    }

    // Channel count
    const channels = data.monitoredChannelsMeta || data.monitoredChannels || [];
    const channelCount = Array.isArray(channels) ? channels.length : 0;
    setEl('botDetailChannelCount', channelCount);
    setEl('botTabBadgeChannels', channelCount);

    // Total subscribers
    let totalSubs = 0;
    if (data.monitoredChannelsMeta && Array.isArray(data.monitoredChannelsMeta)) {
        data.monitoredChannelsMeta.forEach(meta => {
            if (meta.subscribers) totalSubs += Number(meta.subscribers);
        });
    }
    setEl('botDetailTotalSubscribers', `${totalSubs.toLocaleString('tr-TR')} Toplam Abone`);
}

// ---------- Render Channel Cards ----------

function renderBotDetailChannels(data) {
    const container = document.getElementById('botChannelsCardsContainer');
    if (!container) return;

    const meta = data.monitoredChannelsMeta;
    if (!meta || !Array.isArray(meta) || meta.length === 0) {
        container.innerHTML = `
            <div class="col-span-full p-8 text-center bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800">
                <span class="material-symbols-outlined text-4xl text-slate-300 dark:text-slate-600 mb-2">podcasts</span>
                <p class="text-sm text-slate-500 dark:text-slate-400">Henüz dinlenen kanal bulunmuyor.</p>
                <p class="text-xs text-slate-400 mt-1">Aşağıdaki alandan yeni kanal ekleyebilirsiniz.</p>
            </div>
        `;
        return;
    }

    container.innerHTML = meta.map(ch => {
        const isError = ch.status === 'error';
        const isPublic = ch.isPublic !== false;
        const iconBg = isError ? 'bg-rose-500/10 text-rose-500' : (isPublic ? 'bg-blue-500/10 text-blue-500' : 'bg-amber-500/10 text-amber-500');
        const iconName = isError ? 'error' : (isPublic ? 'campaign' : 'lock');
        const statusBadge = isError
            ? '<span class="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-rose-500/10 text-rose-500 border border-rose-500/20">Bağlantı Hatası</span>'
            : '<span class="px-2 py-0.5 text-[10px] font-semibold rounded-full bg-emerald-500/10 text-emerald-500 border border-emerald-500/20">Aktif Dinleniyor</span>';

        const subsText = ch.subscribers
            ? `<span class="material-symbols-outlined text-[14px] text-primary">groups</span>${Number(ch.subscribers).toLocaleString('tr-TR')} Abone`
            : '<span class="material-symbols-outlined text-[14px]">lock</span>Gizli';

        const telegramLink = ch.username && ch.username.startsWith('@')
            ? `https://t.me/${ch.username.replace('@', '')}`
            : null;

        return `
            <div class="bg-white dark:bg-surface-dark p-5 rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm flex flex-col gap-3 hover:border-primary/40 transition-all">
                <div class="flex items-start justify-between gap-3">
                    <div class="flex items-center gap-3">
                        <div class="w-10 h-10 rounded-full ${iconBg} flex items-center justify-center shrink-0">
                            <span class="material-symbols-outlined text-xl">${iconName}</span>
                        </div>
                        <div class="flex flex-col min-w-0">
                            <div class="flex items-center gap-2 flex-wrap">
                                <span class="text-sm font-bold text-slate-900 dark:text-white truncate">${ch.title || 'Bilinmeyen'}</span>
                                ${statusBadge}
                            </div>
                            <span class="text-xs text-slate-500 dark:text-slate-400 font-mono mt-0.5">${ch.username || ch.input}</span>
                        </div>
                    </div>
                </div>
                <div class="flex items-center gap-3 text-xs text-slate-500 dark:text-slate-400 border-t border-slate-100 dark:border-slate-800/60 pt-3">
                    <div class="flex items-center gap-1 bg-slate-50 dark:bg-surface-darker px-2 py-1 rounded-lg border border-slate-100 dark:border-slate-800/60">
                        ${subsText}
                    </div>
                    <span class="text-slate-300 dark:text-slate-700">•</span>
                    <span>${ch.type || 'Kanal'}</span>
                    <span class="text-slate-300 dark:text-slate-700">•</span>
                    <span class="font-mono text-[10px] text-slate-400">ID: ${ch.id || '—'}</span>
                </div>
                <div class="flex items-center gap-2 border-t border-slate-100 dark:border-slate-800/60 pt-2.5">
                    ${telegramLink ? `
                        <a href="${telegramLink}" target="_blank" class="flex items-center gap-1 text-xs text-blue-500 hover:text-blue-600 font-semibold hover:underline">
                            <span class="material-symbols-outlined text-[14px]">open_in_new</span>
                            Telegram'da Aç
                        </a>
                        <span class="text-slate-300 dark:text-slate-700">•</span>
                    ` : ''}
                    <button onclick="window.removeTelegramChannel && window.removeTelegramChannel('${ch.input}')" class="flex items-center gap-1 text-xs text-rose-500 hover:text-rose-600 font-semibold hover:underline cursor-pointer">
                        <span class="material-symbols-outlined text-[14px]">link_off</span>
                        Kanalı Kaldır
                    </button>
                </div>
            </div>
        `;
    }).join('');
}

// ---------- Render Clean VM Status ----------

function renderBotDetailCleanVmStatus(data) {
    if (!data.cleanVmStatus) return;
    const st = data.cleanVmStatus;

    const setEl = (id, text) => { const el = document.getElementById(id); if (el) el.textContent = text; };

    // Badge
    const badge = document.getElementById('botCleanStatusBadge');
    if (badge) {
        if (st.status === 'running') {
            badge.className = 'px-2.5 py-0.5 text-[10px] font-bold rounded-full bg-amber-100 text-amber-800 dark:bg-amber-950/60 dark:text-amber-400 animate-pulse';
            badge.textContent = 'Çalışıyor...';
        } else if (st.status === 'success') {
            badge.className = 'px-2.5 py-0.5 text-[10px] font-bold rounded-full bg-emerald-100 text-emerald-800 dark:bg-emerald-950/60 dark:text-emerald-400';
            badge.textContent = 'Tamamlandı';
        } else if (st.status === 'error') {
            badge.className = 'px-2.5 py-0.5 text-[10px] font-bold rounded-full bg-rose-100 text-rose-800 dark:bg-rose-950/60 dark:text-rose-400';
            badge.textContent = 'Hata';
        }
    }

    // Details
    if (st.completedAt) {
        setEl('botCleanLastTime', new Date(st.completedAt).toLocaleString('tr-TR'));
    } else if (st.startedAt) {
        setEl('botCleanLastTime', new Date(st.startedAt).toLocaleString('tr-TR'));
    }
    setEl('botCleanDuration', st.durationSec ? `${st.durationSec} saniye` : '—');
    setEl('botCleanHeapUsed', st.heapUsedMb ? `${st.heapUsedMb} MB` : '—');
    setEl('botCleanFreedHeap', st.freedHeapMb ? `${st.freedHeapMb} MB` : '—');

    // Terminal logs
    const logsEl = document.getElementById('botVmTerminalLogs');
    if (logsEl && Array.isArray(st.logs) && st.logs.length > 0) {
        logsEl.textContent = st.logs.join('\n');
    }
}

// ---------- Update Master Toggle & Sidebar Pulse ----------

function updateBotDetailMasterToggle(data) {
    const toggle = document.getElementById('botDetailMasterToggle');
    const label = document.getElementById('botMasterToggleLabel');
    if (toggle) {
        toggle.checked = data.botEnabled !== false;
    }
    if (label) {
        label.textContent = data.botEnabled !== false ? 'Bot Servisi: Aktif' : 'Bot Servisi: Durduruldu';
    }
}

function updateSidebarBotPulse(data) {
    const pulse = document.getElementById('sidebarBotPulse');
    if (!pulse) return;
    const lastHb = data.lastHeartbeatAt?.toDate ? data.lastHeartbeatAt.toDate() : (data.lastHeartbeatAt ? new Date(data.lastHeartbeatAt._seconds * 1000) : null);
    const isOnline = lastHb && (Math.abs(Date.now() - lastHb.getTime()) < 15 * 60 * 1000) && (data.status === 'online');
    if (isOnline) {
        pulse.className = 'size-2 rounded-full bg-emerald-500 animate-pulse';
        pulse.title = 'Bot Çevrimiçi';
    } else {
        pulse.className = 'size-2 rounded-full bg-red-500';
        pulse.title = 'Bot Çevrimdışı';
    }
}

// ---------- Tab Switching ----------

window.switchBotDetailTab = function(tabId) {
    botDetailCurrentTab = tabId;
    const tabs = ['channels', 'deals', 'server', 'logs'];
    tabs.forEach(t => {
        const btn = document.getElementById(`botTabBtn${t.charAt(0).toUpperCase() + t.slice(1)}`);
        const content = document.getElementById(`botTabContent${t.charAt(0).toUpperCase() + t.slice(1)}`);
        if (btn) {
            if (t === tabId) {
                btn.className = 'flex items-center gap-2 px-4 py-3 text-sm font-bold border-b-2 border-primary text-primary transition-all whitespace-nowrap cursor-pointer';
            } else {
                btn.className = 'flex items-center gap-2 px-4 py-3 text-sm font-bold border-b-2 border-transparent text-slate-500 dark:text-slate-400 hover:text-slate-900 dark:hover:text-white transition-all whitespace-nowrap cursor-pointer';
            }
        }
        if (content) {
            if (t === tabId) {
                content.classList.remove('hidden');
            } else {
                content.classList.add('hidden');
            }
        }
    });

    // Lazy load tab data
    if (tabId === 'deals' && !botDetailDealsLoaded) {
        loadBotRecentDeals();
    }
    if (tabId === 'logs' && !botDetailLogsLoaded) {
        loadBotApmLogs();
    }
};

// ---------- Toggle Bot Master Switch ----------

window.toggleTelegramBotMaster = async function(enabled) {
    try {
        await db.collection('settings').doc('telegramBot').set({
            botEnabled: enabled
        }, { merge: true });
        console.log(`✅ Bot ${enabled ? 'başlatıldı' : 'durduruldu'}`);
        if (typeof showSuccess === 'function') {
            showSuccess(enabled ? 'Bot başarıyla başlatıldı.' : 'Bot durduruldu.');
        }
    } catch (err) {
        console.error('❌ Bot toggle error:', err);
        if (typeof showError === 'function') {
            showError('Bot durumu değiştirilemedi: ' + err.message);
        }
    }
};

// ---------- Add New Channel(s) ----------

window.addNewTelegramChannel = async function() {
    const input = document.getElementById('botNewChannelInput');
    if (!input || !input.value.trim()) {
        if (typeof showError === 'function') showError('Lütfen en az bir kanal adı veya ID girin.');
        return;
    }
    const rawVal = input.value.trim();

    // Split by comma or newline for bulk channel adding
    const rawChannels = rawVal.split(/[\n,]+/).map(s => s.trim()).filter(Boolean);
    if (rawChannels.length === 0) {
        if (typeof showError === 'function') showError('Geçerli bir kanal girişi bulunamadı.');
        return;
    }

    // Clean channels (extract handle from URL, ensure @ for usernames)
    const parsedChannels = rawChannels.map(ch => {
        let c = ch.replace(/^(https?:\/\/)?(www\.)?t\.me\//i, '').replace(/^\/+|\/+$/g, '').trim();
        if (!c.startsWith('@') && !c.startsWith('-') && !/^\d+$/.test(c)) {
            c = '@' + c;
        }
        return c;
    }).filter(Boolean);

    try {
        const docRef = db.collection('settings').doc('telegramBot');
        const snap = await docRef.get();
        const existingChannels = snap.exists && Array.isArray(snap.data().monitoredChannels) ? [...snap.data().monitoredChannels] : [];

        const newlyAdded = [];
        const alreadyExisting = [];

        for (const ch of parsedChannels) {
            if (existingChannels.some(ex => ex.toLowerCase() === ch.toLowerCase())) {
                alreadyExisting.push(ch);
            } else {
                existingChannels.push(ch);
                newlyAdded.push(ch);
            }
        }

        if (newlyAdded.length === 0) {
            if (typeof showError === 'function') {
                showError(`Girdiğiniz kanal(lar) zaten dinleme listesinde mevcut: ${alreadyExisting.join(', ')}`);
            }
            return;
        }

        await docRef.set({ monitoredChannels: existingChannels }, { merge: true });

        input.value = '';
        if (typeof showSuccess === 'function') {
            const skippedText = alreadyExisting.length > 0 ? ` (${alreadyExisting.length} mükerrer atlandı)` : '';
            if (newlyAdded.length === 1) {
                showSuccess(`"${newlyAdded[0]}" başarıyla eklendi. Bot kısa süre içinde kanala abone olacak.${skippedText}`);
            } else {
                showSuccess(`✅ ${newlyAdded.length} yeni kanal başarıyla eklendi ve dinlemeye alındı!${skippedText}`);
            }
        }
    } catch (err) {
        console.error('❌ Add channel error:', err);
        if (typeof showError === 'function') showError('Kanal(lar) eklenirken hata: ' + err.message);
    }
};

// ---------- Copy All Monitored Channels to Clipboard ----------

window.copyAllTelegramChannels = async function() {
    try {
        let channels = [];
        if (lastBotDetailData && Array.isArray(lastBotDetailData.monitoredChannels) && lastBotDetailData.monitoredChannels.length > 0) {
            channels = lastBotDetailData.monitoredChannels;
        } else {
            const doc = await db.collection('settings').doc('telegramBot').get();
            if (doc.exists && Array.isArray(doc.data().monitoredChannels)) {
                channels = doc.data().monitoredChannels;
            }
        }

        if (!channels || channels.length === 0) {
            if (typeof showError === 'function') showError('Kopyalanacak aktif dinlenen kanal bulunamadı.');
            return;
        }

        const text = channels.join(', ');
        await navigator.clipboard.writeText(text);
        if (typeof showSuccess === 'function') {
            showSuccess(`📋 ${channels.length} aktif kanal kullanıcı adı panoya kopyalandı!`);
        }
    } catch (err) {
        console.error('❌ Copy channels error:', err);
        if (typeof showError === 'function') showError('Kanallar kopyalanırken hata oluştu: ' + err.message);
    }
};

// ---------- Remove Channel ----------

window.removeTelegramChannel = async function(channelInput) {
    if (!confirm(`"${channelInput}" kanalını dinleme listesinden kaldırmak istediğinize emin misiniz?`)) return;

    try {
        const docRef = db.collection('settings').doc('telegramBot');
        const snap = await docRef.get();
        if (!snap.exists) return;

        const channels = snap.data().monitoredChannels || [];
        const updated = channels.filter(c => c.trim().toLowerCase() !== channelInput.trim().toLowerCase());

        // Also clean meta
        const meta = snap.data().monitoredChannelsMeta || [];
        const updatedMeta = meta.filter(m => m.input.trim().toLowerCase() !== channelInput.trim().toLowerCase());

        await docRef.set({
            monitoredChannels: updated,
            monitoredChannelsMeta: updatedMeta
        }, { merge: true });

        if (typeof showSuccess === 'function') {
            showSuccess(`"${channelInput}" başarıyla kaldırıldı.`);
        }
    } catch (err) {
        console.error('❌ Remove channel error:', err);
        if (typeof showError === 'function') showError('Kanal kaldırılırken hata: ' + err.message);
    }
};

// ---------- Clean VM Trigger from Bot View ----------

window.triggerCleanVmFromBotView = async function() {
    if (!confirm('Sunucu bellek ve performans temizliğini başlatmak istediğinize emin misiniz?')) return;

    const btn = document.getElementById('botDetailCleanVmBtn');
    if (btn) btn.disabled = true;

    try {
        await db.collection('settings').doc('telegramBot').set({
            cleanVmTrigger: Date.now()
        }, { merge: true });

        if (typeof showSuccess === 'function') {
            showSuccess('Sunucu temizlik komutu gönderildi. Sonuçlar terminal konsolunda görünecek.');
        }
    } catch (e) {
        if (btn) btn.disabled = false;
        if (typeof showError === 'function') {
            showError('Temizlik başlatılamadı: ' + e.message);
        }
    }
};

// ---------- Copy Terminal Logs ----------

window.copyBotTerminalLogs = function() {
    const logsEl = document.getElementById('botVmTerminalLogs');
    if (!logsEl) return;

    const text = logsEl.textContent;
    navigator.clipboard.writeText(text).then(() => {
        if (typeof showSuccess === 'function') {
            showSuccess('Terminal logları panoya kopyalandı.');
        }
    }).catch(err => {
        console.error('Copy error:', err);
    });
};

// ---------- Load Bot Recent Deals (Tab 2) ----------

window.loadBotRecentDeals = async function() {
    botDetailDealsLoaded = true;
    const container = document.getElementById('botDealsGridContainer');
    if (!container) return;

    container.innerHTML = `
        <div class="col-span-full p-12 text-center text-slate-400 bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800">
            <span class="material-symbols-outlined text-3xl animate-spin">sync</span>
            <p class="mt-2">Fırsatlar yükleniyor...</p>
        </div>
    `;

    try {
        let docs = [];
        try {
            const snapshot = await db.collection('deals')
                .where('source', '==', 'telegram')
                .orderBy('createdAt', 'desc')
                .limit(12)
                .get();
            docs = snapshot.docs;
        } catch (idxErr) {
            console.warn('⚠️ Composite index henüz oluşturulmadı/hazırlanıyor, istemci tarafı filtreleme devrede:', idxErr.message);
            const fallbackSnap = await db.collection('deals')
                .orderBy('createdAt', 'desc')
                .limit(60)
                .get();
            docs = fallbackSnap.docs.filter(doc => {
                const d = doc.data();
                return d.source === 'telegram' || d.telegramChatId || d.telegramMessageId || d.postedBy === 'botkolik';
            }).slice(0, 12);
        }

        if (!docs || docs.length === 0) {
            container.innerHTML = `
                <div class="col-span-full p-12 text-center bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800">
                    <span class="material-symbols-outlined text-4xl text-slate-300 dark:text-slate-600 mb-2">inbox</span>
                    <p class="text-sm text-slate-500 dark:text-slate-400">Bot henüz fırsat yakalamamış veya bu ortamda kayıt yok.</p>
                </div>
            `;
            const badge = document.getElementById('botTabBadgeDeals');
            if (badge) badge.textContent = '0';
            return;
        }

        const badge = document.getElementById('botTabBadgeDeals');
        if (badge) badge.textContent = docs.length;

        container.innerHTML = docs.map(doc => {
            const d = doc.data();
            const price = d.price ? `${parseFloat(d.price).toLocaleString('tr-TR', {minimumFractionDigits: 2})} ₺` : '';
            const origPrice = d.originalPrice ? `${parseFloat(d.originalPrice).toLocaleString('tr-TR', {minimumFractionDigits: 2})} ₺` : '';
            const discount = d.discountRate ? `%${d.discountRate}` : '';
            const store = d.store || '—';
            const channelSrc = d.telegramChatTitle || d.telegramChatUsername || '—';
            const img = d.imageUrl || '';
            const approved = d.isApproved;
            const createdAt = d.createdAt?.toDate ? d.createdAt.toDate() : null;
            const timeAgo = createdAt ? formatRelativeTime(createdAt) : '—';

            return `
                <div class="bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800 shadow-sm overflow-hidden flex flex-col hover:border-primary/40 transition-all group">
                    ${img ? `
                        <div class="h-36 bg-slate-50 dark:bg-surface-darker flex items-center justify-center overflow-hidden">
                            <img src="${img}" alt="${d.title || ''}" class="w-full h-full object-contain p-2 group-hover:scale-105 transition-transform" onerror="this.parentElement.innerHTML='<span class=\\'material-symbols-outlined text-4xl text-slate-300 dark:text-slate-600\\'>image_not_supported</span>'"/>
                        </div>
                    ` : `
                        <div class="h-36 bg-slate-50 dark:bg-surface-darker flex items-center justify-center">
                            <span class="material-symbols-outlined text-4xl text-slate-300 dark:text-slate-600">image_not_supported</span>
                        </div>
                    `}
                    <div class="p-4 flex flex-col gap-2 flex-1">
                        <h4 class="text-xs font-bold text-slate-900 dark:text-white leading-snug line-clamp-2">${d.title || 'Başlıksız Fırsat'}</h4>
                        <div class="flex items-center gap-2 flex-wrap">
                            ${price ? `<span class="text-sm font-black text-primary">${price}</span>` : ''}
                            ${origPrice ? `<span class="text-[11px] text-slate-400 line-through">${origPrice}</span>` : ''}
                            ${discount ? `<span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-rose-50 text-rose-600 dark:bg-rose-950/40 dark:text-rose-400">${discount}</span>` : ''}
                        </div>
                        <div class="flex items-center gap-2 flex-wrap text-[10px] text-slate-400 mt-auto border-t border-slate-100 dark:border-slate-800/60 pt-2">
                            <span class="bg-slate-100 dark:bg-slate-800 px-1.5 py-0.5 rounded font-semibold text-slate-600 dark:text-slate-300">${store}</span>
                            <span>📢 ${channelSrc}</span>
                            <span>${timeAgo}</span>
                            ${approved ? '<span class="text-emerald-500 font-bold">✓ Onaylı</span>' : '<span class="text-amber-500 font-bold">⏳ Bekliyor</span>'}
                        </div>
                    </div>
                </div>
            `;
        }).join('');

    } catch (err) {
        console.error('❌ Load bot deals error:', err);
        container.innerHTML = `
            <div class="col-span-full p-8 text-center text-rose-500 bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800">
                <p class="text-sm font-bold">Fırsatlar yüklenemedi</p>
                <p class="text-xs mt-1">${err.message}</p>
            </div>
        `;
    }
};

// ---------- Load Bot APM Logs (Tab 4) ----------

async function loadBotApmLogs() {
    botDetailLogsLoaded = true;
    const container = document.getElementById('botApmLogsContainer');
    if (!container) return;

    container.innerHTML = `
        <div class="p-8 text-center text-slate-400 bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800">
            <span class="material-symbols-outlined text-3xl animate-spin">sync</span>
            <p class="mt-2">Hata logları yükleniyor...</p>
        </div>
    `;

    try {
        let docs = [];
        try {
            const snapshot = await db.collection('systemErrors')
                .where('category', '==', 'bot')
                .orderBy('createdAt', 'desc')
                .limit(20)
                .get();
            docs = snapshot.docs;
        } catch (idxErr) {
            console.warn('⚠️ systemErrors bot composite index sorgusu yerine bellek içi filtreleme devrede:', idxErr.message);
            const fallbackSnap = await db.collection('systemErrors')
                .orderBy('createdAt', 'desc')
                .limit(80)
                .get();
            docs = fallbackSnap.docs.filter(doc => {
                const d = doc.data();
                const cat = (d.category || '').toLowerCase();
                const srv = (d.service || d.errorType || '').toLowerCase();
                return cat === 'bot' || srv.includes('bot') || srv.includes('telegram');
            }).slice(0, 20);
        }

        if (!docs || docs.length === 0) {
            container.innerHTML = `
                <div class="p-8 text-center bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800">
                    <span class="material-symbols-outlined text-4xl text-emerald-400 mb-2">check_circle</span>
                    <p class="text-sm text-slate-700 dark:text-slate-300 font-bold">Mükemmel! Bot kategorisinde aktif hata kaydı yok.</p>
                    <p class="text-xs text-slate-400 mt-1">Telegram botu ve scraper motoru sorunsuz çalışıyor.</p>
                </div>
            `;
            return;
        }

        container.innerHTML = docs.map(doc => {
            const d = doc.data();
            const severity = (d.severity || 'error').toLowerCase();
            const createdAt = d.createdAt?.toDate ? d.createdAt.toDate() : null;
            const timeStr = createdAt ? createdAt.toLocaleString('tr-TR') : '—';

            const severityColors = {
                error: 'bg-rose-50 text-rose-700 border-rose-200 dark:bg-rose-950/20 dark:text-rose-400 dark:border-rose-900/40',
                warning: 'bg-amber-50 text-amber-700 border-amber-200 dark:bg-amber-950/20 dark:text-amber-400 dark:border-amber-900/40',
                info: 'bg-blue-50 text-blue-700 border-blue-200 dark:bg-blue-950/20 dark:text-blue-400 dark:border-blue-900/40'
            };
            const cardClass = severityColors[severity] || severityColors.error;

            const severityBadge = severity === 'error'
                ? '<span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-rose-100 text-rose-600 dark:bg-rose-900/40 dark:text-rose-400">HATA</span>'
                : severity === 'warning'
                ? '<span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-amber-100 text-amber-600 dark:bg-amber-900/40 dark:text-amber-400">UYARI</span>'
                : '<span class="text-[10px] font-bold px-1.5 py-0.5 rounded bg-blue-100 text-blue-600 dark:bg-blue-900/40 dark:text-blue-400">BİLGİ</span>';

            return `
                <div class="p-4 rounded-xl border ${cardClass} flex flex-col gap-2">
                    <div class="flex items-center justify-between gap-2 flex-wrap">
                        <div class="flex items-center gap-2">
                            ${severityBadge}
                            <span class="text-xs font-mono font-bold">${d.errorType || d.service || 'bot'}</span>
                        </div>
                        <span class="text-[10px] font-mono opacity-70">${timeStr}</span>
                    </div>
                    <p class="text-xs leading-relaxed">${d.message || 'Hata mesajı yok'}</p>
                    ${d.stack ? `
                        <details class="mt-1">
                            <summary class="text-[10px] font-bold cursor-pointer hover:underline opacity-70">Stack Trace Göster</summary>
                            <pre class="mt-1.5 p-2 bg-black/10 dark:bg-black/30 rounded-lg text-[10px] font-mono overflow-x-auto max-h-32 whitespace-pre-wrap">${d.stack}</pre>
                        </details>
                    ` : ''}
                </div>
            `;
        }).join('');

    } catch (err) {
        console.error('❌ Load bot APM logs error:', err);
        container.innerHTML = `
            <div class="p-8 text-center text-slate-400 bg-white dark:bg-surface-dark rounded-2xl border border-slate-200 dark:border-slate-800">
                <p class="text-sm text-slate-700 dark:text-slate-300 font-bold">Bot logları yüklenemedi</p>
                <p class="text-xs mt-1">${err.message}</p>
            </div>
        `;
    }
}

// ---------- Utility: Relative Time Formatter ----------

function formatRelativeTime(date) {
    if (!date) return '—';
    const now = new Date();
    const diffMs = now.getTime() - date.getTime();
    const diffSec = Math.floor(diffMs / 1000);
    const diffMin = Math.floor(diffSec / 60);
    const diffHr = Math.floor(diffMin / 60);
    const diffDay = Math.floor(diffHr / 24);

    if (diffSec < 60) return `${diffSec} sn önce`;
    if (diffMin < 60) return `${diffMin} dk önce`;
    if (diffHr < 24) return `${diffHr} saat önce`;
    if (diffDay < 7) return `${diffDay} gün önce`;
    return date.toLocaleDateString('tr-TR');
}


