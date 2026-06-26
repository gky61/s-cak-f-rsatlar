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
            updateStats();
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
                        errorMessage = 'Bu domain için yetkilendirme yapılmamış. Firebase Console > Authentication > Settings > Authorized domains bölümüne "sicak-firsatlar-e6eae.web.app" domain\'ini ekleyin.';
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
    
    // Users menu button
    const usersMenuBtn = document.getElementById('usersMenuBtn');
    if (usersMenuBtn) {
        usersMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showUsersView();
        });
    }
    
    // Messages menu button
    const messagesMenuBtn = document.getElementById('messagesMenuBtn');
    if (messagesMenuBtn) {
        messagesMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showMessagesView();
        });
    }
    
    // Deals menu button (Fırsatlar)
    const dealsMenuBtn = document.querySelector('a[href="#"]:has(.material-symbols-outlined.icon-filled)');
    if (dealsMenuBtn && dealsMenuBtn.textContent.includes('Fırsatlar')) {
        dealsMenuBtn.addEventListener('click', (e) => {
            e.preventDefault();
            showDealsView();
        });
    }

    // Toggle Deal Sharing button
    const toggleDealSharingBtn = document.getElementById('toggleDealSharingBtn');
    console.log('🔍 Toggle Deal Sharing button element:', toggleDealSharingBtn);
    if (toggleDealSharingBtn) {
        console.log('✅ Toggle Deal Sharing button found, initializing...');
        // İlk durumu yükle
        loadDealSharingStatus();
        
        toggleDealSharingBtn.addEventListener('click', async () => {
            console.log('🖱️ Toggle Deal Sharing button clicked!');
            await toggleDealSharing();
        });
    } else {
        console.error('❌ Toggle Deal Sharing button NOT FOUND!');
    }

    // Toggle Comment Sharing button
    const toggleCommentSharingBtn = document.getElementById('toggleCommentSharingBtn');
    console.log('🔍 Toggle Comment Sharing button element:', toggleCommentSharingBtn);
    if (toggleCommentSharingBtn) {
        console.log('✅ Toggle Comment Sharing button found, initializing...');
        // İlk durumu yükle
        loadCommentSharingStatus();
        
        toggleCommentSharingBtn.addEventListener('click', async () => {
            console.log('🖱️ Toggle Comment Sharing button clicked!');
            await toggleCommentSharing();
        });
    } else {
        console.error('❌ Toggle Comment Sharing button NOT FOUND!');
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

    // Approve deal (old modal design)
    if (approveBtn) {
        approveBtn.addEventListener('click', async () => {
            if (!currentDeal) return;
            try {
                await db.collection('deals').doc(currentDeal.id).update({
                    isApproved: true
                });
                showSuccess('Deal onaylandı!');
                closeDealModal();
                loadDeals();
                updateStats();
            } catch (error) {
                showError('Onaylama hatası: ' + error.message);
            }
        });
    }

    // Reject deal (old modal design)
    if (rejectBtn) {
        rejectBtn.addEventListener('click', async () => {
            if (!currentDeal) return;
            if (!confirm('Bu deal\'i silmek istediğinize emin misiniz?')) return;
            try {
                await db.collection('deals').doc(currentDeal.id).delete();
                showSuccess('Deal silindi!');
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
        const approveBtnNew = e.target.closest('#approveBtn');
        const rejectBtnNew = e.target.closest('#rejectBtn');
        const saveBtnNew = e.target.closest('#saveBtn');
        const cancelBtnNew = e.target.closest('#cancelBtn');
        
        if (approveBtnNew && currentDeal) {
            e.preventDefault();
            try {
                await db.collection('deals').doc(currentDeal.id).update({
                    isApproved: true
                });
                showSuccess('Fırsat onaylandı!');
                closeDealModal();
                loadDeals();
                updateStats();
            } catch (error) {
                showError('Onaylama hatası: ' + error.message);
            }
        }
        
        if (rejectBtnNew && currentDeal) {
            e.preventDefault();
            if (!confirm('Bu fırsatı silmek istediğinize emin misiniz?')) return;
            try {
                await db.collection('deals').doc(currentDeal.id).delete();
                showSuccess('Fırsat silindi!');
                closeDealModal();
                loadDeals();
                updateStats();
            } catch (error) {
                showError('Silme hatası: ' + error.message);
            }
        }
        
        if (saveBtnNew) {
            e.preventDefault();
            e.stopPropagation();
            console.log('✅ Onayla butonu tıklandı (delegated)!', currentDeal?.id);
            
            if (!currentDeal) {
                console.error('❌ No current deal!');
                showError('Fırsat bulunamadı!');
                return;
            }
            
            // Butonu devre dışı bırak
            const btn = saveBtnNew;
            const originalHTML = btn.innerHTML;
            btn.disabled = true;
            btn.innerHTML = '<span>Onaylanıyor...</span>';
            
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
        }
    });

    // Unpublish deal (old modal design - may not exist in new design)
    if (unpublishBtn) {
        unpublishBtn.addEventListener('click', async () => {
            if (!currentDeal) return;
            try {
                await db.collection('deals').doc(currentDeal.id).update({
                    isApproved: false
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
                    isExpired: false
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

// Show success (simple alert for now)
function showSuccess(message) {
    alert(message);
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
                console.log('⏳ Pending deals:', deals.filter(d => !d.isApproved).length);
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
    
    dealsList.innerHTML = '';
    
    let filteredDeals = deals;
    
    if (currentFilter === 'pending') {
        filteredDeals = deals.filter(d => d.isApproved === false);
        console.log('📋 Pending filter uygulandı, filtrelenmiş deal sayısı:', filteredDeals.length);
    } else if (currentFilter === 'approved') {
        filteredDeals = deals.filter(d => d.isApproved === true);
        console.log('📋 Approved filter uygulandı, filtrelenmiş deal sayısı:', filteredDeals.length);
    } else if (currentFilter === 'all') {
        // 'all' durumunda tüm deal'leri göster
        filteredDeals = deals;
        console.log('📋 All filter uygulandı, filtrelenmiş deal sayısı:', filteredDeals.length);
    }
    
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

// Create deal table row
function createDealRow(deal) {
    const row = document.createElement('tr');
    row.className = 'group hover:bg-slate-50 dark:hover:bg-slate-800/50 transition-colors cursor-pointer';
    
    const isApproved = deal.isApproved === true;
    const isUserSubmitted = deal.isUserSubmitted === true;
    
    // Status badge
    let statusBadge = '';
    if (isApproved) {
        statusBadge = '<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-emerald-500/20 bg-emerald-500/10 text-emerald-600 dark:text-emerald-400 text-xs font-medium"><span class="inline-block w-1.5 h-1.5 rounded-full bg-emerald-500"></span>Aktif</div>';
    } else {
        statusBadge = '<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-amber-500/20 bg-amber-500/10 text-amber-600 dark:text-amber-400 text-xs font-medium"><span class="inline-block w-1.5 h-1.5 rounded-full bg-amber-500 animate-pulse"></span>Bekliyor</div>';
    }
    
    // Source badge
    const sourceBadge = isUserSubmitted
        ? `<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-purple-500/20 bg-purple-500/10 text-purple-600 dark:text-purple-400 text-xs font-medium"><span class="material-symbols-outlined text-[14px]">person</span>${escapeHtml(deal.postedBy || 'Kullanıcı')}</div>`
        : `<div class="inline-flex items-center gap-1.5 px-2.5 py-1 rounded-full border border-blue-500/20 bg-blue-500/10 text-blue-600 dark:text-blue-400 text-xs font-medium"><span class="material-symbols-outlined text-[14px]">smart_toy</span>Bot</div>`;
    
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
    const createdAt = deal.createdAt ? formatDate(deal.createdAt) : 'Bilinmiyor';
    const timeAgo = deal.createdAt ? getTimeAgo(deal.createdAt) : 'Bilinmiyor';
    
    // Price
    const price = deal.price || 0;
    const originalPrice = deal.originalPrice || price;
    const discount = originalPrice > price ? Math.round(((originalPrice - price) / originalPrice) * 100) : 0;
    
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
                    <p class="text-slate-500 dark:text-slate-400 text-xs mt-0.5">${escapeHtml(deal.category || 'Genel')} • ${escapeHtml(deal.store || 'Bilinmeyen')}</p>
                </div>
            </div>
        </td>
        <td class="p-4">${sourceBadge}</td>
        <td class="p-4">
            <p class="text-slate-900 dark:text-white font-bold">${price.toLocaleString('tr-TR')} TL</p>
            ${originalPrice > price ? `<p class="text-slate-400 text-xs line-through">${originalPrice.toLocaleString('tr-TR')} TL</p>` : ''}
        </td>
        <td class="p-4">
            ${discount > 0 ? `<span class="text-emerald-600 dark:text-emerald-400 font-bold bg-emerald-100 dark:bg-emerald-500/10 px-2 py-1 rounded text-xs">%${discount} İndirim</span>` : '<span class="text-slate-400 text-xs">-</span>'}
        </td>
        <td class="p-4">
            <p class="text-slate-700 dark:text-slate-300">${timeAgo}</p>
            <p class="text-slate-500 dark:text-slate-500 text-xs">${createdAt}</p>
        </td>
        <td class="p-4">${statusBadge}</td>
        <td class="p-4 text-right">
            <div class="flex items-center justify-end gap-2 opacity-100 sm:opacity-0 group-hover:opacity-100 transition-opacity">
                ${!isApproved ? `<button class="approve-btn p-2 rounded-lg text-emerald-500 hover:bg-emerald-500/10 hover:text-emerald-400 transition-colors" title="Onayla" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">check</span></button>` : ''}
                <button class="edit-btn p-2 rounded-lg text-slate-400 hover:bg-slate-700 hover:text-white transition-colors" title="Düzenle" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">edit</span></button>
                <button class="delete-btn p-2 rounded-lg text-rose-500 hover:bg-rose-500/10 hover:text-rose-400 transition-colors" title="Sil" data-deal-id="${deal.id}"><span class="material-symbols-outlined text-[20px]">delete</span></button>
            </div>
        </td>
    `;
    
    // Click event for row
    row.addEventListener('click', async (e) => {
        if (e.target.closest('button') || e.target.closest('input')) return;
        await showDealModal(deal);
    });
    
    // Button events
    row.querySelectorAll('.approve-btn').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const dealId = btn.dataset.dealId;
            await approveDeal(dealId);
        });
    });
    
    row.querySelectorAll('.delete-btn').forEach(btn => {
        btn.addEventListener('click', async (e) => {
            e.stopPropagation();
            const dealId = btn.dataset.dealId;
            if (confirm('Bu deal\'i silmek istediğinize emin misiniz?')) {
                await deleteDeal(dealId);
            }
        });
    });
    
    return row;
}

// Helper functions
function getTimeAgo(date) {
    const now = new Date();
    const diff = now - date;
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
        
        // Kısa link kontrolü ve otomatik çözme
        if (currentUrl) {
            try {
                const url = new URL(currentUrl);
                const hostname = url.hostname.toLowerCase();
                
                if (hostname.includes('hb.biz') || hostname.includes('app.hb.biz')) {
                    // Kısa link tespit edildi - Otomatik çöz
                    console.log('🔄 Kısa link tespit edildi, çözülüyor...', currentUrl);
                    try {
                        const functionsUrl = 'https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/resolveShortLink';
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
        }
        
        // Affiliate link'e dönüştür (eğer yapılandırılmışsa)
        let finalUrl = currentUrl;
        if (currentUrl) {
            const convertedUrl = convertToAffiliateLink(currentUrl);
            if (convertedUrl !== currentUrl) {
                finalUrl = convertedUrl;
                console.log('✅ Affiliate link\'e dönüştürüldü:', finalUrl);
            }
        }
        
        // Deal'i güncelle
        const updateData = {
            isApproved: true,
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        };
        
        // Eğer link dönüştürüldüyse güncelle
        if (finalUrl !== currentUrl) {
            updateData.url = finalUrl;
            updateData.link = finalUrl;
        }
        
        await db.collection('deals').doc(dealId).update(updateData);
        showSuccess('Deal onaylandı' + (finalUrl !== currentUrl ? ' ve affiliate link\'e dönüştürüldü!' : '!'));
        loadDeals();
        updateStats();
    } catch (error) {
        showError('Onaylama hatası: ' + error.message);
    }
}

async function deleteDeal(dealId) {
    try {
        await db.collection('deals').doc(dealId).delete();
        showSuccess('Deal silindi!');
        loadDeals();
        updateStats();
    } catch (error) {
        showError('Silme hatası: ' + error.message);
    }
}

// Affiliate Link Dönüştürme Fonksiyonları
function convertToAffiliateLink(originalUrl) {
    if (!originalUrl || typeof originalUrl !== 'string') {
        return originalUrl;
    }
    
    try {
        const url = new URL(originalUrl);
        const hostname = url.hostname.toLowerCase();
        
        // Hepsiburada kısa link kontrolü (app.hb.biz)
        // Başkasının kısa linkini kendi affiliate linkimize dönüştürmek için
        // önce gerçek ürün linkini bulmamız gerekir (bu client-side'da yapılamaz)
        // Bu yüzden kısa linkleri olduğu gibi bırakıyoruz
        // NOT: Eğer kısa linki kendi affiliate linkinize dönüştürmek istiyorsanız,
        // önce kısa linki tarayıcıda açıp gerçek ürün linkini alın, sonra admin panelinde kullanın
        if (hostname.includes('hb.biz') || hostname.includes('app.hb.biz')) {
            console.log('ℹ️ Kısa link tespit edildi:', originalUrl);
            console.log('⚠️ Kısa linkler başkasına ait olabilir. Kendi affiliate linkinize dönüştürmek için:');
            console.log('   1. Kısa linki tarayıcıda açın');
            console.log('   2. Gerçek ürün linkini kopyalayın');
            console.log('   3. Admin panelinde o linki kullanın');
            
            // Eğer config'de utmSource varsa, kısa linki değiştirmeye çalışabiliriz
            // Ama kısa linkler redirect yaptığı için client-side'da gerçek URL'yi bulamayız
            // Bu yüzden kullanıcıya uyarı gösterip linki olduğu gibi bırakıyoruz
            if (affiliateConfig.hepsiburada.utmSource) {
                // Kısa linki olduğu gibi bırak, ama kullanıcıya bilgi ver
                return originalUrl;
            }
            return originalUrl; // Kısa link olduğu gibi kalır
        }
        
        // Trendyol
        if (hostname.includes('trendyol.com')) {
            // Mevcut boutiqueId'yi temizle (başkasının affiliate linkini kendi linkimize dönüştürmek için)
            url.searchParams.delete('boutiqueId');
            
            if (affiliateConfig.trendyol.boutiqueId) {
                // Kendi boutiqueId'yi ekle
                url.searchParams.set('boutiqueId', affiliateConfig.trendyol.boutiqueId);
                return url.toString();
            }
        }
        
        // Hepsiburada (Link Gelir) - Normal ürün linkleri
        if (hostname.includes('hepsiburada.com')) {
            // Hepsiburada'nın "Tavsiyeni Paylaş" butonundan gelen linkler zaten affiliate linktir
            // Eğer link zaten kendi affiliate linkimizse (utm_source bizim ID'mizle eşleşiyorsa), değiştirme
            const existingUtmSource = url.searchParams.get('utm_source');
            const ourUtmSource = affiliateConfig.hepsiburada.utmSource;
            
            // Eğer link zaten bizim affiliate linkimizse, olduğu gibi bırak
            if (existingUtmSource && ourUtmSource && existingUtmSource === ourUtmSource) {
                console.log('ℹ️ Link zaten kendi affiliate linkiniz:', originalUrl);
                return originalUrl; // Kendi linkiniz, değiştirme
            }
            
            // Başkasının affiliate linkini kendi affiliate linkimize dönüştür
            // Mevcut affiliate parametrelerini temizle
            url.searchParams.delete('utm_source');
            url.searchParams.delete('utm_medium');
            url.searchParams.delete('utm_campaign');
            url.searchParams.delete('utm_content');
            url.searchParams.delete('wt_inf');
            
            if (affiliateConfig.hepsiburada.utmSource) {
                // Kendi affiliate parametrelerini ekle
                url.searchParams.set('utm_source', affiliateConfig.hepsiburada.utmSource);
                url.searchParams.set('utm_medium', 'referral');
                url.searchParams.set('utm_campaign', 'urun_paylasim');
                return url.toString();
            }
        }
        
        // N11
        if (hostname.includes('n11.com')) {
            // Mevcut ref parametresini temizle
            url.searchParams.delete('ref');
            
            if (affiliateConfig.n11.refId) {
                // Kendi ref ID'sini ekle
                url.searchParams.set('ref', affiliateConfig.n11.refId);
                return url.toString();
            }
        }
        
        // Amazon
        if (hostname.includes('amazon.com.tr') || hostname.includes('amazon.com')) {
            // Mevcut tag parametresini temizle
            url.searchParams.delete('tag');
            
            if (affiliateConfig.amazon.tag) {
                // Kendi tag'ini ekle
                url.searchParams.set('tag', affiliateConfig.amazon.tag);
                return url.toString();
            }
        }
        
        // GittiGidiyor
        if (hostname.includes('gittigidiyor.com')) {
            // Mevcut affiliateId parametresini temizle
            url.searchParams.delete('affiliateId');
            
            if (affiliateConfig.gittigidiyor.affiliateId) {
                // Kendi affiliateId'yi ekle
                url.searchParams.set('affiliateId', affiliateConfig.gittigidiyor.affiliateId);
                return url.toString();
            }
        }
        
        // Desteklenmeyen site veya affiliate ID yoksa orijinal linki döndür
        return originalUrl;
    } catch (error) {
        console.error('Link dönüştürme hatası:', error);
        return originalUrl;
    }
}

function detectStoreFromUrl(url) {
    if (!url || typeof url !== 'string') {
        return 'unknown';
    }
    
    try {
        const urlObj = new URL(url);
        const hostname = urlObj.hostname.toLowerCase();
        
        if (hostname.includes('trendyol.com')) return 'Trendyol';
        if (hostname.includes('hepsiburada.com')) return 'Hepsiburada';
        if (hostname.includes('n11.com')) return 'N11';
        if (hostname.includes('amazon.com')) return 'Amazon';
        if (hostname.includes('gittigidiyor.com')) return 'GittiGidiyor';
        
        return 'Bilinmeyen';
    } catch (error) {
        return 'Bilinmeyen';
    }
}

// Show deal modal
async function showDealModal(deal) {
    // Modal açılmadan önce mevcut view'ı kaydet
    previousView = currentView;
    currentDeal = deal;
    
    const createdAt = deal.createdAt ? formatDate(deal.createdAt) : 'Bilinmiyor';
    const postedBy = deal.postedBy || 'Bilinmiyor';
    const isApproved = deal.isApproved === true;
    const isUserSubmitted = deal.isUserSubmitted === true;
    
    // Kullanıcı bilgilerini Firestore'dan çek (eğer kullanıcı tarafından paylaşıldıysa)
    let userDisplayName = 'Bot';
    let userProfileImage = null;
    if (isUserSubmitted && postedBy && postedBy !== 'Bilinmiyor') {
        try {
            const userDoc = await db.collection('users').doc(postedBy).get();
            if (userDoc.exists) {
                const userData = userDoc.data();
                userDisplayName = userData.nickname || userData.username || 'Kullanıcı';
                userProfileImage = userData.profileImageUrl || null;
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
    const originalPrice = deal.originalPrice || price;
    const discount = originalPrice > price ? Math.round(((originalPrice - price) / originalPrice) * 100) : 0;
    
    // Status seçimi
    let statusValue = 'pending';
    if (isApproved) {
        statusValue = 'active';
    }
    
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
                <div class="h-px bg-slate-200 dark:bg-slate-700 w-full"></div>
                <label class="flex flex-col gap-2">
                    <div class="flex items-center justify-between">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Mağaza / Affiliate Linki</span>
                        <button type="button" id="convertToAffiliateBtn" class="flex items-center gap-1.5 px-3 py-1.5 rounded-lg bg-primary/10 hover:bg-primary/20 border border-primary/30 text-primary text-xs font-medium transition-colors">
                            <span class="material-symbols-outlined text-[16px]">swap_horiz</span>
                            <span>Affiliate Link'e Dönüştür</span>
                        </button>
                    </div>
                    <div class="flex gap-2">
                        <input id="editUrl" class="form-input flex-1 rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-primary h-12 px-4 text-base" type="url" value="${escapeHtml(deal.url || deal.link || '')}"/>
                        <a id="previewLinkBtn" class="flex items-center justify-center px-4 rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 hover:bg-gray-200 dark:hover:bg-gray-700 text-slate-500 dark:text-slate-400 transition-colors" href="${escapeHtml(deal.url || deal.link || '#')}" target="_blank">
                            <span class="material-symbols-outlined">link</span>
                        </a>
                    </div>
                    <p id="affiliateStatus" class="text-xs text-slate-500 dark:text-slate-400 mt-1"></p>
                </label>
                <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Kupon Kodu (Opsiyonel)</span>
                        <div class="relative">
                            <input id="editCouponCode" class="form-input w-full rounded-lg bg-background-light dark:bg-background-dark border border-dashed border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 px-4 text-base font-mono uppercase tracking-wider" placeholder="KOD YOK" type="text" value="${escapeHtml(deal.couponCode || '')}"/>
                            <span class="absolute right-3 top-1/2 -translate-y-1/2 material-symbols-outlined text-slate-400 dark:text-slate-500 text-lg">local_activity</span>
                        </div>
                    </label>
                    <label class="flex flex-col gap-2">
                        <span class="text-sm font-semibold text-gray-900 dark:text-white">Kargo Durumu</span>
                        <select id="editShipping" class="form-select w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-12 px-4 text-base">
                            <option value="unknown">Bilinmiyor</option>
                            <option value="free" ${deal.shipping === 'free' ? 'selected' : ''}>Ücretsiz Kargo</option>
                            <option value="paid" ${deal.shipping === 'paid' ? 'selected' : ''}>Alıcı Ödemeli</option>
                        </select>
                    </label>
                </div>
            </div>
        `;
    }
    
    // Modal Sidebar (Sağ Kolon)
    const modalSidebarEl = document.getElementById('modalSidebar');
    if (modalSidebarEl) {
        const lastUpdate = deal.updatedAt ? formatDate(deal.updatedAt) : createdAt;
        
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
                        <select id="editStatus" class="form-select w-full rounded-lg ${isApproved ? 'bg-green-50 dark:bg-green-900/10 border-green-200 dark:border-green-800 text-green-700 dark:text-green-400' : 'bg-amber-50 dark:bg-amber-900/10 border-amber-200 dark:border-amber-800 text-amber-700 dark:text-amber-400'} focus:ring-1 focus:ring-primary h-12 px-4 text-base font-semibold">
                            <option value="pending" ${!isApproved ? 'selected' : ''}>Onay Bekliyor</option>
                            <option value="active" ${isApproved ? 'selected' : ''}>Yayında</option>
                            <option value="rejected">Reddedildi</option>
                            <option value="expired">Süresi Doldu</option>
                        </select>
                    </label>
                    <div class="flex items-center justify-between text-sm py-2 border-t border-slate-200 dark:border-slate-700">
                        <span class="text-slate-500 dark:text-slate-400">Sıcak Fırsat?</span>
                        <label class="relative inline-flex items-center cursor-pointer">
                            <input id="editIsHot" class="sr-only peer" type="checkbox" ${deal.isHot ? 'checked' : ''}/>
                            <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none peer-focus:ring-4 peer-focus:ring-primary/20 dark:peer-focus:ring-primary/30 rounded-full peer dark:bg-gray-700 peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all dark:border-gray-600 peer-checked:bg-primary"></div>
                        </label>
                    </div>
                </div>
                
                <!-- Action Buttons -->
                <div class="mt-4 pt-4 border-t border-slate-200 dark:border-slate-700 flex flex-col gap-2">
                    <button id="saveBtn" onclick="handleApproveDeal(event)" class="w-full h-11 px-4 rounded-lg bg-emerald-500 hover:bg-emerald-600 text-white font-bold text-sm shadow-lg shadow-emerald-500/20 transition-all flex items-center justify-center gap-2" type="button">
                        <span class="material-symbols-outlined text-[18px]">check</span>
                        <span>Onayla</span>
                    </button>
                    <button id="cancelBtn" onclick="handleCancelDeal(event)" class="w-full h-11 px-4 rounded-lg border border-slate-200 dark:border-slate-700 bg-transparent text-gray-700 dark:text-white hover:bg-gray-100 dark:hover:bg-gray-800 font-semibold text-sm transition-colors" type="button">
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
                                <option value="moda" ${deal.category === 'moda' ? 'selected' : ''}>Giyim & Moda</option>
                                <option value="ev_yasam" ${deal.category === 'ev_yasam' ? 'selected' : ''}>Ev & Yaşam</option>
                                <option value="supermarket" ${deal.category === 'supermarket' ? 'selected' : ''}>Süpermarket</option>
                                <option value="oyun" ${deal.category === 'oyun' ? 'selected' : ''}>Oyun</option>
                                <option value="diger" ${!deal.category || !['elektronik', 'moda', 'ev_yasam', 'supermarket', 'oyun'].includes(deal.category) ? 'selected' : ''}>Diğer</option>
                            </select>
                        </div>
                    </label>
                    <label class="flex flex-col gap-2">
                        <span class="text-xs font-semibold text-slate-500 dark:text-slate-400">Alt Kategori</span>
                        <select id="editSubcategory" class="form-select w-full rounded-lg bg-background-light dark:bg-background-dark border border-slate-200 dark:border-slate-700 focus:border-primary focus:ring-1 focus:ring-primary text-gray-900 dark:text-white h-11 px-4 text-sm">
                            <option value="">Seçiniz</option>
                            <option value="${escapeHtml(deal.subcategory || '')}" selected>${escapeHtml(deal.subcategory || 'Alt kategori yok')}</option>
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
    
    // Affiliate link dönüştürme butonu
    const convertToAffiliateBtn = document.getElementById('convertToAffiliateBtn');
    const editUrlEl = document.getElementById('editUrl');
    const previewLinkBtn = document.getElementById('previewLinkBtn');
    const affiliateStatusEl = document.getElementById('affiliateStatus');
    
    if (convertToAffiliateBtn && editUrlEl) {
        convertToAffiliateBtn.addEventListener('click', async () => {
            const currentUrl = editUrlEl.value.trim();
            if (!currentUrl) {
                showError('Lütfen önce bir link girin!');
                return;
            }
            
            // Kısa link kontrolü ve otomatik çözme
            let urlToConvert = currentUrl;
            try {
                const url = new URL(currentUrl);
                const hostname = url.hostname.toLowerCase();
                
                if (hostname.includes('hb.biz') || hostname.includes('app.hb.biz')) {
                    // Kısa link tespit edildi - Otomatik çöz
                    if (affiliateStatusEl) {
                        affiliateStatusEl.innerHTML = `
                            <div style="background: #e7f3ff; padding: 10px; border-radius: 5px; border-left: 4px solid #2196F3;">
                                <strong>🔄 Kısa link çözülüyor...</strong><br>
                                <small>Gerçek ürün linki bulunuyor...</small>
                            </div>
                        `;
                        affiliateStatusEl.className = 'text-xs mt-1';
                    }
                    
                    // Firebase Function ile kısa linki çöz
                    try {
                        const functionsUrl = 'https://us-central1-sicak-firsatlar-e6eae.cloudfunctions.net/resolveShortLink';
                        const response = await fetch(`${functionsUrl}?url=${encodeURIComponent(currentUrl)}`);
                        const data = await response.json();
                        
                        if (data.success && data.resolvedUrl) {
                            urlToConvert = data.resolvedUrl;
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
            const convertedUrl = convertToAffiliateLink(urlToConvert);
            
            if (convertedUrl !== urlToConvert) {
                editUrlEl.value = convertedUrl;
                if (previewLinkBtn) {
                    previewLinkBtn.href = convertedUrl;
                }
                if (affiliateStatusEl) {
                    affiliateStatusEl.textContent = `✅ ${store} affiliate linkine dönüştürüldü`;
                    affiliateStatusEl.className = 'text-xs text-emerald-600 dark:text-emerald-400 mt-1';
                }
                showSuccess(`${store} affiliate linkine dönüştürüldü!`);
            } else {
                // Link değişmedi - affiliate ID yapılandırılmamış olabilir
                if (affiliateStatusEl) {
                    if (store === 'Bilinmeyen') {
                        affiliateStatusEl.textContent = '⚠️ Bu site için affiliate link yapılandırması bulunamadı';
                        affiliateStatusEl.className = 'text-xs text-amber-600 dark:text-amber-400 mt-1';
                    } else {
                        affiliateStatusEl.textContent = `⚠️ ${store} için affiliate ID yapılandırılmamış (config.js dosyasını kontrol edin)`;
                        affiliateStatusEl.className = 'text-xs text-amber-600 dark:text-amber-400 mt-1';
                    }
                }
                showError(`${store} için affiliate ID yapılandırılmamış. Lütfen config.js dosyasını kontrol edin.`);
            }
        });
    }
    
    // URL değiştiğinde preview link'i güncelle
    if (editUrlEl && previewLinkBtn) {
        editUrlEl.addEventListener('input', () => {
            const url = editUrlEl.value.trim();
            if (url) {
                previewLinkBtn.href = url;
            } else {
                previewLinkBtn.href = '#';
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
    }, 150);
    
    // Butonlara direkt event listener ekle (modal gösterildikten sonra)
    setTimeout(() => {
        const saveBtnEl = document.getElementById('saveBtn');
        const cancelBtnEl = document.getElementById('cancelBtn');
        
        if (saveBtnEl) {
            console.log('🔘 Adding event listener to saveBtn (Onayla button)');
            // Önceki listener'ları temizle
            const newSaveBtn = saveBtnEl.cloneNode(true);
            saveBtnEl.parentNode.replaceChild(newSaveBtn, saveBtnEl);
            
            newSaveBtn.addEventListener('click', async (e) => {
                e.preventDefault();
                e.stopPropagation();
                console.log('✅ Onayla butonu tıklandı (direct listener)!', currentDeal?.id);
                
                if (!currentDeal) {
                    console.error('❌ No current deal!');
                    showError('Fırsat bulunamadı!');
                    return;
                }
                
                // Butonu devre dışı bırak
                newSaveBtn.disabled = true;
                const originalHTML = newSaveBtn.innerHTML;
                newSaveBtn.innerHTML = '<span>Onaylanıyor...</span>';
                
                try {
                    await saveDealChanges();
                } catch (error) {
                    console.error('❌ Onaylama hatası:', error);
                    newSaveBtn.disabled = false;
                    newSaveBtn.innerHTML = originalHTML;
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
        const url = document.getElementById('editUrl')?.value || currentDeal.url || currentDeal.link || '';
        const category = document.getElementById('editCategory')?.value || currentDeal.category || '';
        const subcategoryEl = document.getElementById('editSubcategory');
        const subcategory = (subcategoryEl?.value && subcategoryEl.value !== 'none' && subcategoryEl.value !== 'Alt kategori yok') 
            ? subcategoryEl.value 
            : (currentDeal.subcategory || null);
        const status = document.getElementById('editStatus')?.value || (currentDeal.isApproved ? 'active' : 'pending');
        const isHot = document.getElementById('editIsHot')?.checked || false;
        const couponCode = document.getElementById('editCouponCode')?.value || '';
        const shipping = document.getElementById('editShipping')?.value || 'unknown';
        
        // Mevcut görselleri al (yeni görsel yüklenmişse güncellenmiş olacak)
        let imageUrls = currentDeal.imageUrls || [];
        if (!Array.isArray(imageUrls) && currentDeal.imageUrl) {
            imageUrls = [currentDeal.imageUrl];
        }
        // imageUrl'i de güncelle (ilk görsel)
        const imageUrl = imageUrls.length > 0 ? imageUrls[0] : (currentDeal.imageUrl || '');
        
        // Validasyon
        if (!title.trim()) {
            showError('Başlık gereklidir!');
            return;
        }
        if (price <= 0) {
            showError('Geçerli bir fiyat giriniz!');
            return;
        }
        if (!url.trim()) {
            showError('Ürün linki gereklidir!');
            return;
        }
        if (!category) {
            showError('Kategori seçiniz!');
            return;
        }
        
        // Firestore undefined değerleri kabul etmez, bu yüzden sadece tanımlı alanları ekle
        const dealData = {
            title: title.trim(),
            description: description.trim() || '',
            price: price || 0,
            originalPrice: originalPrice || price || 0,
            url: url.trim(),
            link: url.trim(), // link alanı da ekle (geriye dönük uyumluluk için)
            category: category,
            imageUrl: imageUrl || '',
            imageUrls: imageUrls.length > 0 ? imageUrls : [],
            isApproved: status === 'active' || status === 'pending' ? (status === 'active') : true, // Onayla butonu her zaman onaylar ve yayınlar
            isHot: isHot || false,
            couponCode: couponCode || '',
            shipping: shipping || 'unknown',
            store: currentDeal.store || 'Bilinmeyen',
            postedBy: currentUser ? currentUser.uid : 'admin',
            hotVotes: 0,
            coldVotes: 0,
            expiredVotes: 0,
            commentCount: 0,
            isEditorPick: false,
            isExpired: false,
            isUserSubmitted: false, // Admin tarafından eklenen deal'ler bot deal'i olarak işaretlenir
            createdAt: firebase.firestore.FieldValue.serverTimestamp(),
            updatedAt: firebase.firestore.FieldValue.serverTimestamp()
        };
        
        // subcategory sadece değer varsa ekle (null veya undefined değilse)
        if (subcategory && subcategory !== 'none' && subcategory !== 'Alt kategori yok') {
            dealData.subcategory = subcategory;
        } else if (currentDeal.subcategory && !isNewDeal) {
            // Mevcut subcategory varsa koru (sadece güncelleme durumunda)
            dealData.subcategory = currentDeal.subcategory;
        }
        
        if (isNewDeal) {
            // Yeni deal oluştur
            console.log('📝 Creating new deal:', dealData);
            const docRef = await db.collection('deals').add(dealData);
            console.log('✅ New deal created with ID:', docRef.id);
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
        shipping: 'unknown',
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
        const pending = deals.filter(d => d.isApproved === false).length;
        const approved = deals.filter(d => d.isApproved === true).length;
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
function showDealsView() {
    currentView = 'deals';
    const dealsView = document.getElementById('dealsView');
    const usersView = document.getElementById('usersView');
    const messagesView = document.getElementById('messagesView');
    
    if (dealsView) dealsView.classList.remove('hidden');
    if (usersView) usersView.classList.add('hidden');
    if (messagesView) messagesView.classList.add('hidden');
    
    // Aktif filter butonunu kontrol et ve currentFilter'ı ayarla
    const activeFilterBtn = document.querySelector('.filter-btn.active');
    if (activeFilterBtn) {
        currentFilter = activeFilterBtn.dataset.filter || 'all';
        console.log('🔍 Aktif filter butonu bulundu, currentFilter ayarlandı:', currentFilter);
    } else {
        // Aktif buton bulunamazsa varsayılan olarak 'all' yap
        currentFilter = 'all';
        console.log('⚠️ Aktif filter butonu bulunamadı, currentFilter varsayılan olarak "all" yapıldı');
    }
    
    // Update menu active states
    updateMenuActiveState('deals');
    
    // Eğer deal'ler zaten yüklendiyse, renderDeals'ı çağır
    if (deals && deals.length > 0) {
        console.log('📊 Deal\'ler zaten yüklü, renderDeals çağrılıyor...');
        renderDeals();
    }
}

function showUsersView() {
    currentView = 'users';
    const dealsView = document.getElementById('dealsView');
    const usersView = document.getElementById('usersView');
    const messagesView = document.getElementById('messagesView');
    
    if (dealsView) dealsView.classList.add('hidden');
    if (usersView) usersView.classList.remove('hidden');
    if (messagesView) messagesView.classList.add('hidden');
    
    // Update menu active states
    updateMenuActiveState('users');
    
    // Load users if not already loaded
    if (users.length === 0) {
        loadUsers();
    }
    
    // Arama input'una event listener ekle
    setTimeout(() => {
        const usersSearchInput = document.getElementById('usersSearchInput');
        if (usersSearchInput) {
            // Önceki listener'ı temizle
            const newInput = usersSearchInput.cloneNode(true);
            usersSearchInput.parentNode.replaceChild(newInput, usersSearchInput);
            
            newInput.addEventListener('input', (e) => {
                usersSearchQuery = e.target.value.trim().toLowerCase();
                console.log('🔍 Kullanıcı arama:', usersSearchQuery);
                renderUsers();
            });
            console.log('✅ Kullanıcı arama event listener eklendi');
        }
    }, 100);
}

function showMessagesView() {
    currentView = 'messages';
    const dealsView = document.getElementById('dealsView');
    const usersView = document.getElementById('usersView');
    const messagesView = document.getElementById('messagesView');
    
    if (dealsView) dealsView.classList.add('hidden');
    if (usersView) usersView.classList.add('hidden');
    if (messagesView) messagesView.classList.remove('hidden');
    
    // Update menu active states
    updateMenuActiveState('messages');
    
    // Load messages
    loadMessages();
}

function updateMenuActiveState(activeView) {
    // Remove active state from all menu items
    const menuItems = document.querySelectorAll('nav a');
    menuItems.forEach(item => {
        item.classList.remove('bg-primary/10', 'text-primary', 'border-primary/20');
        item.classList.add('text-slate-400');
        const icon = item.querySelector('.material-symbols-outlined');
        if (icon) {
            icon.classList.remove('icon-filled');
        }
    });
    
    // Add active state to selected menu item
    if (activeView === 'deals') {
        const dealsMenuItem = Array.from(menuItems).find(item => item.textContent.includes('Fırsatlar'));
        if (dealsMenuItem) {
            dealsMenuItem.classList.add('bg-primary/10', 'text-primary', 'border-primary/20');
            dealsMenuItem.classList.remove('text-slate-400');
            const icon = dealsMenuItem.querySelector('.material-symbols-outlined');
            if (icon) icon.classList.add('icon-filled');
        }
    } else if (activeView === 'users') {
        const usersMenuItem = Array.from(menuItems).find(item => item.textContent.includes('Kullanıcılar'));
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
    }
}

// Load messages from Firestore
function loadMessages() {
    console.log('📨 Loading messages...');
    
    const messagesTableBody = document.getElementById('messagesTableBody');
    if (!messagesTableBody) {
        console.error('❌ Messages table body not found!');
        return;
    }
    
    // Önceki listener'ı iptal et
    if (messagesUnsubscribe) {
        messagesUnsubscribe();
    }
    
    // Real-time listener ekle
    messagesUnsubscribe = db.collection('adminMessages')
        .orderBy('createdAt', 'desc')
        .limit(100)
        .onSnapshot((snapshot) => {
            messages = [];
            snapshot.forEach((doc) => {
                const data = doc.data();
                messages.push({
                    id: doc.id,
                    type: data.type || 'unknown',
                    userId: data.userId || 'unknown',
                    userName: data.userName || 'Bilinmeyen Kullanıcı',
                    content: data.content || '',
                    dealId: data.dealId || null,
                    commentId: data.commentId || null,
                    reason: data.reason || 'Uygunsuz içerik tespit edildi',
                    isRead: data.isRead || false,
                    createdAt: data.createdAt?.toDate ? data.createdAt.toDate() : new Date(data.createdAt || Date.now()),
                });
            });
            
            console.log(`✅ Loaded ${messages.length} messages`);
            renderMessages();
        }, (error) => {
            console.error('❌ Error loading messages:', error);
            if (messagesTableBody) {
                messagesTableBody.innerHTML = `
                    <tr>
                        <td colspan="6" class="px-6 py-12 text-center text-red-500">
                            <p>Mesajlar yüklenirken hata oluştu: ${error.message}</p>
                        </td>
                    </tr>
                `;
            }
        });
}

// Render messages in the table
function renderMessages() {
    const messagesTableBody = document.getElementById('messagesTableBody');
    if (!messagesTableBody) return;
    
    if (messages.length === 0) {
        messagesTableBody.innerHTML = `
            <tr>
                <td colspan="6" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
                    <div class="flex flex-col items-center gap-2">
                        <span class="material-symbols-outlined text-4xl opacity-50">mail</span>
                        <p>Henüz moderasyon mesajı yok</p>
                    </div>
                </td>
            </tr>
        `;
        return;
    }
    
    messagesTableBody.innerHTML = messages.map(message => {
        const messageDate = new Date(message.createdAt);
        const formattedDate = messageDate.toLocaleDateString('tr-TR', {
            year: 'numeric',
            month: 'long',
            day: 'numeric',
            hour: '2-digit',
            minute: '2-digit'
        });
        
        const typeLabel = message.type === 'deal' ? 'Fırsat' : 'Yorum';
        const typeColor = message.type === 'deal' ? 'text-blue-600 dark:text-blue-400' : 'text-purple-600 dark:text-purple-400';
        const typeIcon = message.type === 'deal' ? 'local_offer' : 'comment';
        
        const statusBadge = message.isRead 
            ? '<span class="px-2 py-1 bg-green-100 dark:bg-green-900/30 text-green-700 dark:text-green-400 rounded-full text-xs font-medium">Okundu</span>'
            : '<span class="px-2 py-1 bg-red-100 dark:bg-red-900/30 text-red-700 dark:text-red-400 rounded-full text-xs font-medium">Yeni</span>';
        
        return `
            <tr class="hover:bg-slate-50 dark:hover:bg-slate-900/50 transition-colors ${!message.isRead ? 'bg-red-50/50 dark:bg-red-900/10' : ''}">
                <td class="px-6 py-4">
                    <p class="text-sm text-slate-700 dark:text-slate-300">${escapeHtml(formattedDate)}</p>
                </td>
                <td class="px-6 py-4">
                    <div class="flex items-center gap-2">
                        <div class="w-8 h-8 rounded-full bg-slate-200 dark:bg-slate-700 flex items-center justify-center">
                            <span class="material-symbols-outlined text-slate-500 dark:text-slate-400 text-[16px]">person</span>
                        </div>
                        <div>
                            <button onclick="window.showUserDetail('${escapeHtml(message.userId)}')" 
                                    class="text-sm font-medium text-slate-900 dark:text-white hover:text-primary dark:hover:text-primary transition-colors cursor-pointer text-left">
                                ${escapeHtml(message.userName)}
                            </button>
                            <p class="text-xs text-slate-500 dark:text-slate-400 font-mono">${escapeHtml(message.userId)}</p>
                        </div>
                    </div>
                </td>
                <td class="px-6 py-4">
                    <div class="flex items-center gap-2">
                        <span class="material-symbols-outlined ${typeColor} text-[18px]">${typeIcon}</span>
                        <span class="text-sm font-medium ${typeColor}">${typeLabel}</span>
                    </div>
                </td>
                <td class="px-6 py-4">
                    <p class="text-sm text-slate-700 dark:text-slate-300 max-w-md truncate" title="${escapeHtml(message.content)}">
                        ${escapeHtml(message.content)}
                    </p>
                    <p class="text-xs text-red-600 dark:text-red-400 mt-1">${escapeHtml(message.reason)}</p>
                </td>
                <td class="px-6 py-4">
                    ${statusBadge}
                </td>
                <td class="px-6 py-4 text-right">
                    <div class="flex items-center justify-end gap-2">
                        ${message.dealId ? `
                            <button onclick="window.showDealDetail('${escapeHtml(message.dealId)}')" class="text-primary hover:text-primary/80 text-sm font-medium transition-colors" title="Fırsatı Görüntüle">
                                <span class="material-symbols-outlined text-[18px]">visibility</span>
                            </button>
                        ` : ''}
                        ${!message.isRead ? `
                            <button onclick="window.markMessageAsRead('${escapeHtml(message.id)}')" class="text-emerald-600 dark:text-emerald-400 hover:text-emerald-700 dark:hover:text-emerald-300 text-sm font-medium transition-colors" title="Okundu İşaretle">
                                <span class="material-symbols-outlined text-[18px]">check_circle</span>
                            </button>
                        ` : ''}
                        <button onclick="window.deleteMessage('${escapeHtml(message.id)}')" class="text-red-600 dark:text-red-400 hover:text-red-700 dark:hover:text-red-300 text-sm font-medium transition-colors" title="Mesajı Sil">
                            <span class="material-symbols-outlined text-[18px]">delete</span>
                        </button>
                    </div>
                </td>
            </tr>
        `;
    }).join('');
}

// Mark message as read
window.markMessageAsRead = async function(messageId) {
    try {
        await db.collection('adminMessages').doc(messageId).update({
            isRead: true,
        });
        showSuccess('Mesaj okundu olarak işaretlendi');
    } catch (error) {
        console.error('❌ Error marking message as read:', error);
        showError('Mesaj işaretlenirken hata oluştu: ' + error.message);
    }
}

// Delete message
window.deleteMessage = async function(messageId) {
    if (!confirm('Bu mesajı silmek istediğinize emin misiniz?')) {
        return;
    }
    
    try {
        await db.collection('adminMessages').doc(messageId).delete();
        showSuccess('Mesaj başarıyla silindi');
    } catch (error) {
        console.error('❌ Error deleting message:', error);
        showError('Mesaj silinirken hata oluştu: ' + error.message);
    }
}

// Delete all messages
window.deleteAllMessages = async function() {
    if (!confirm('TÜM moderasyon mesajlarını silmek istediğinize emin misiniz? Bu işlem geri alınamaz!')) {
        return;
    }
    
    try {
        const snapshot = await db.collection('adminMessages').get();
        
        if (snapshot.empty) {
            showError('Silinecek mesaj yok');
            return;
        }
        
        const batch = db.batch();
        snapshot.docs.forEach((doc) => {
            batch.delete(doc.ref);
        });
        
        await batch.commit();
        showSuccess(`${snapshot.docs.length} mesaj başarıyla silindi`);
    } catch (error) {
        console.error('❌ Error deleting all messages:', error);
        showError('Mesajlar silinirken hata oluştu: ' + error.message);
    }
}

// Show deal detail (for messages view)
window.showDealDetail = async function(dealId) {
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

// Load users from Firestore
async function loadUsers() {
    try {
        console.log('👥 Loading users...');
        const usersTableBody = document.getElementById('usersTableBody');
        
        if (usersTableBody) {
            usersTableBody.innerHTML = `
                <tr>
                    <td colspan="7" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
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
        
        usersUnsubscribe = db.collection('users').onSnapshot((snapshot) => {
            users = [];
            let totalDeals = 0;
            let totalPoints = 0;
            
            snapshot.forEach((doc) => {
                const userData = doc.data();
                const user = {
                    id: doc.id,
                    uid: userData.uid || doc.id,
                    username: userData.username || 'Bilinmeyen',
                    nickname: userData.nickname || null,
                    profileImageUrl: userData.profileImageUrl || '',
                    points: userData.points || 0,
                    dealCount: userData.dealCount || 0,
                    totalLikes: userData.totalLikes || 0,
                    followedCategories: userData.followedCategories || [],
                    watchKeywords: userData.watchKeywords || [],
                    following: userData.following || [],
                    followersWithNotifications: userData.followersWithNotifications || [],
                    badges: userData.badges || [],
                    email: userData.email || null
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
        }, (error) => {
            console.error('❌ Error loading users:', error);
            if (usersTableBody) {
                usersTableBody.innerHTML = `
                    <tr>
                        <td colspan="7" class="px-6 py-12 text-center text-red-500">
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
    
    // Arama sorgusuna göre filtrele
    let filteredUsers = users;
    if (usersSearchQuery && usersSearchQuery.trim() !== '') {
        filteredUsers = users.filter(user => {
            const searchLower = usersSearchQuery.toLowerCase();
            const username = (user.username || '').toLowerCase();
            const nickname = (user.nickname || '').toLowerCase();
            const email = (user.email || '').toLowerCase();
            const uid = (user.uid || user.id || '').toLowerCase();
            
            return username.includes(searchLower) || 
                   nickname.includes(searchLower) || 
                   email.includes(searchLower) || 
                   uid.includes(searchLower);
        });
    }
    
    if (filteredUsers.length === 0) {
        usersTableBody.innerHTML = `
            <tr>
                <td colspan="7" class="px-6 py-12 text-center text-slate-500 dark:text-slate-400">
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
        
        return `
            <tr class="hover:bg-slate-50 dark:hover:bg-slate-900/50 transition-colors">
                <td class="px-6 py-4">
                    <div class="flex items-center gap-3">
                        <img src="${profileImage}" alt="${displayName}" class="w-10 h-10 rounded-full object-cover bg-slate-200 dark:bg-slate-700" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=135bec&color=fff&size=128'">
                        <div class="flex flex-col">
                            <p class="font-semibold text-slate-900 dark:text-white">${escapeHtml(displayName)}</p>
                            ${user.email ? `<p class="text-xs text-slate-500 dark:text-slate-400">${escapeHtml(user.email)}</p>` : ''}
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
                    <span class="text-slate-700 dark:text-slate-300">${followingCount}</span>
                </td>
                <td class="px-6 py-4">
                    <span class="text-slate-700 dark:text-slate-300">${followedCategoriesCount}</span>
                </td>
                <td class="px-6 py-4 text-right">
                    <button onclick="showUserDetail('${user.id}')" class="text-primary hover:text-primary/80 text-sm font-medium transition-colors">
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
    
    if (!currentDeal || !currentDeal.id) {
        showError('Fırsat bulunamadı!');
        return;
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
window.swapMainImage = async function() {
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
                    ...userData
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
    
    currentUserDetail = { ...user, isBlocked, isCommentBanned, isDealBanned };
    
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
                <img src="${profileImage}" alt="${escapeHtml(displayName)}" class="w-32 h-32 rounded-full object-cover bg-slate-200 dark:bg-slate-700 border-4 border-primary/20" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(displayName)}&background=135bec&color=fff&size=256'">
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
                    ${user.followedCategories && user.followedCategories.length > 0 ? `
                        <div class="flex flex-wrap gap-2">
                            ${user.followedCategories.map(cat => `
                                <span class="px-3 py-1 bg-primary/10 text-primary rounded-full text-sm font-medium">${escapeHtml(cat)}</span>
                            `).join('')}
                        </div>
                    ` : '<p class="text-slate-500 dark:text-slate-400 text-sm">Kategori takip edilmiyor</p>'}
                </div>
                
                <div>
                    <p class="text-sm font-semibold text-slate-500 dark:text-slate-400 mb-2">Takip Edilen Anahtar Kelimeler</p>
                    ${user.watchKeywords && user.watchKeywords.length > 0 ? `
                        <div class="flex flex-wrap gap-2">
                            ${user.watchKeywords.map(keyword => `
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
        <!-- Badges Section -->
        <div class="bg-white dark:bg-surface-dark rounded-xl border border-slate-200 dark:border-slate-800 p-5 shadow-sm">
            <div class="flex items-center justify-between mb-4">
                <h3 class="text-sm font-bold text-gray-500 dark:text-gray-400 uppercase tracking-wider">Rozetler</h3>
            </div>
            
            <!-- Mevcut Rozetler -->
            ${user.badges && user.badges.length > 0 ? `
                <div class="flex flex-col gap-2 mb-4">
                    ${user.badges.map((badge, index) => `
                        <div class="flex items-center justify-between px-3 py-2 bg-amber-500/10 dark:bg-amber-500/20 rounded-lg border border-amber-500/20">
                            <span class="px-2 py-1 bg-amber-500/20 text-amber-600 dark:text-amber-400 rounded-full text-sm font-medium">${escapeHtml(badge)}</span>
                            <button onclick="removeBadge('${user.uid || user.id}', '${escapeHtml(badge)}')" class="p-1 text-red-500 hover:text-red-700 dark:hover:text-red-400 transition-colors" title="Rozeti Kaldır">
                                <span class="material-symbols-outlined text-[18px]">close</span>
                            </button>
                        </div>
                    `).join('')}
                </div>
            ` : '<p class="text-slate-500 dark:text-slate-400 text-sm mb-4">Rozet yok</p>'}
            
            <!-- Rozet Ekleme -->
            <div class="flex gap-2 w-full min-w-0">
                <input type="text" id="newBadgeInput" placeholder="Yeni rozet adı" class="flex-1 min-w-0 px-3 py-2 text-sm border border-slate-300 dark:border-slate-600 rounded-lg bg-white dark:bg-slate-800 text-slate-900 dark:text-white focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent">
                <button onclick="addBadge('${user.uid || user.id}')" class="flex-shrink-0 px-3 py-2 bg-primary text-white rounded-lg hover:bg-primary/90 transition-colors text-sm font-medium flex items-center gap-1 whitespace-nowrap">
                    <span class="material-symbols-outlined text-[18px]">add</span>
                    <span class="hidden sm:inline">Ekle</span>
                </button>
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
                                    <img src="${followedProfileImage}" alt="${escapeHtml(followedDisplayName)}" class="w-10 h-10 rounded-full object-cover border-2 border-slate-200 dark:border-slate-700" onerror="this.src='https://ui-avatars.com/api/?name=${encodeURIComponent(followedDisplayName)}&background=135bec&color=fff&size=64'">
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
window.showUserComments = async function(userId) {
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
                    ...userData
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
                                     onerror="this.src='https://via.placeholder.com/80x80?text=📷'">
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
window.deleteUserComment = async function(commentId, dealId, userId) {
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

// Add badge to user
window.addBadge = async function(userId) {
    const input = document.getElementById('newBadgeInput');
    if (!input) return;
    
    const badgeName = input.value.trim();
    if (!badgeName) {
        showError('Lütfen bir rozet adı girin!');
        return;
    }
    
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
                    ...userData
                };
                console.log('✅ Kullanıcı Firestore\'dan yüklendi:', user);
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
    if (currentBadges.includes(badgeName)) {
        showError('Bu rozet zaten mevcut!');
        input.value = '';
        return;
    }
    
    // Firestore'a ekle
    const newBadges = [...currentBadges, badgeName];
    try {
        await db.collection('users').doc(userId).update({
            badges: newBadges
        });
        
        console.log('✅ Rozet eklendi:', badgeName);
        // Kullanıcı verisini güncelle
        user.badges = newBadges;
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
        input.value = '';
        showSuccess('Rozet başarıyla eklendi!');
    } catch (error) {
        console.error('❌ Rozet ekleme hatası:', error);
        showError('Rozet eklenirken bir hata oluştu: ' + error.message);
    }
};

// Remove badge from user
window.removeBadge = async function(userId, badgeName) {
    if (!confirm(`"${badgeName}" rozetini kaldırmak istediğinize emin misiniz?`)) {
        return;
    }
    
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
                    ...userData
                };
                console.log('✅ Kullanıcı Firestore\'dan yüklendi:', user);
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
    
    try {
        await db.collection('users').doc(userId).update({
            badges: newBadges
        });
        
        console.log('✅ Rozet kaldırıldı:', badgeName);
        // Kullanıcı verisini güncelle
        user.badges = newBadges;
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
        showSuccess('Rozet başarıyla kaldırıldı!');
    } catch (error) {
        console.error('❌ Rozet kaldırma hatası:', error);
        showError('Rozet kaldırılırken bir hata oluştu: ' + error.message);
    }
};

// Block user
window.blockUser = async function(userId) {
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
        
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Kullanıcı engelleme hatası:', error);
        showError('Kullanıcı engellenirken bir hata oluştu: ' + error.message);
    }
};

// Unblock user
window.unblockUser = async function(userId) {
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
        
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Kullanıcı engeli kaldırma hatası:', error);
        showError('Kullanıcı engeli kaldırılırken bir hata oluştu: ' + error.message);
    }
};

// Ban user from commenting
window.banUserComments = async function(userId) {
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
        
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Yorum engelleme hatası:', error);
        showError('Yorum engellenirken bir hata oluştu: ' + error.message);
    }
};

// Unban user from commenting
window.unbanUserComments = async function(userId) {
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
        
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Yorum izni geri verme hatası:', error);
        showError('Yorum izni geri verilirken bir hata oluştu: ' + error.message);
    }
};

// Ban user from sharing deals
window.banUserDeals = async function(userId) {
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
        
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Paylaşım engelleme hatası:', error);
        showError('Paylaşım engellenirken bir hata oluştu: ' + error.message);
    }
};

// Unban user from sharing deals
window.unbanUserDeals = async function(userId) {
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
        
        // Modal'ı yeniden yükle
        await showUserDetail(userId);
    } catch (error) {
        console.error('❌ Paylaşım izni geri verme hatası:', error);
        showError('Paylaşım izni geri verilirken bir hata oluştu: ' + error.message);
    }
};

// Show admin message modal
window.showAdminMessageModal = function(userId, userName) {
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

// Send admin message
window.sendAdminMessage = async function(userId, title, content) {
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
        
        // Create message document
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
        showSuccess('Mesaj başarıyla gönderildi!');
        
        // Close modal
        closeAdminMessageModal();
        
    } catch (error) {
        console.error('❌ Error sending admin message:', error);
        showError('Mesaj gönderilirken hata oluştu: ' + error.message);
    }
};

// Deal Sharing durumunu yükle ve butonu güncelle
async function loadDealSharingStatus() {
    try {
        console.log('📥 Loading deal sharing status...');
        const settingsDoc = await db.collection('settings').doc('app').get();
        const dealSharingEnabled = settingsDoc.exists && settingsDoc.data() 
            ? (settingsDoc.data().dealSharingEnabled !== false) 
            : true;
        
        console.log('📊 Deal sharing enabled:', dealSharingEnabled);
        updateDealSharingButton(dealSharingEnabled);
    } catch (error) {
        console.error('❌ Error loading deal sharing status:', error);
        updateDealSharingButton(true); // Varsayılan olarak aktif
    }
}

// Deal Sharing butonunu güncelle
function updateDealSharingButton(enabled) {
    const btn = document.getElementById('toggleDealSharingBtn');
    console.log('🔄 Updating deal sharing button, enabled:', enabled, 'button:', btn);
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

