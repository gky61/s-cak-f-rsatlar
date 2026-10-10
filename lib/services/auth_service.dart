import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, defaultTargetPlatform, TargetPlatform;
import 'notification_service.dart';
import 'app_badge_service.dart';
import 'analytics_service.dart';
import '../models/user.dart' as app_user;
import '../firebase_options.dart';
import 'system_log_service.dart';

/// Production-ready log fonksiyonu
void _log(String message) {
  if (kDebugMode) {
    print(message);
  }
}

/// Özel auth exception sınıfı
class AuthException implements Exception {
  final String message;
  AuthException(this.message);
  
  @override
  String toString() => message;
}

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  GoogleSignIn? _googleSignIn;

  // In-memory admin cache (Firestore okuma maliyetlerini ve latency'yi minimize eder)
  static bool? _cachedIsAdmin;
  static String? _cachedAdminUid;
  static DateTime? _lastAdminCheck;
  static Future<bool>? _inFlightAdminCheck;
  static const Duration _adminCacheTTL = Duration(minutes: 5);

  /// Admin önbelleğini sıfırla (Çıkışta veya rol güncellendiğinde çağrılır)
  static void clearAdminCache() {
    _cachedIsAdmin = null;
    _cachedAdminUid = null;
    _lastAdminCheck = null;
    _inFlightAdminCheck = null;
  }
  
  // Lazy initialization - sadece gerektiğinde oluştur
  GoogleSignIn get _googleSignInInstance {
    if (_googleSignIn == null) {
      final iosClientId = defaultTargetPlatform == TargetPlatform.iOS
          ? (DefaultFirebaseOptions.isProductionFlavor
              ? DefaultFirebaseOptions.iosProd.iosClientId
              : DefaultFirebaseOptions.iosDev.iosClientId)
          : null;
      _googleSignIn = GoogleSignIn(
        clientId: iosClientId,
      );
    }
    return _googleSignIn!;
  }

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  // Kullanıcı durumu stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile giriş - Production Ready
  Future<app_user.AppUser?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      } else {
        return await _signInWithGoogleMobile();
      }
    } catch (e, stackTrace) {
      _log('❌ Google giriş hatası: $e');
      _log('Stack trace: $stackTrace');
      
      // Veri tipi hatası durumunda kurtarma dene
      if (_isDataTypeError(e.toString())) {
        final recovered = await _tryRecoverUserData();
        if (recovered != null) return recovered;
        throw AuthException('Kullanıcı verileri okunurken bir hata oluştu. Lütfen tekrar deneyin.');
      }
      
      // Kullanıcı dostu hata fırlat
      throw _convertToUserFriendlyError(e);
    }
  }

  /// Web platformu için Google Sign-In
  Future<app_user.AppUser?> _signInWithGoogleWeb() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider();
    googleProvider.addScope('email');
    googleProvider.addScope('profile');
    
    final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
    
    if (userCredential.user != null) {
      return await _handleUserAfterSignIn(userCredential.user!);
    }
    return null;
  }

  /// Mobil platformlar için Google Sign-In
  Future<app_user.AppUser?> _signInWithGoogleMobile() async {
    final googleSignIn = _googleSignInInstance;
    
    // Mevcut oturum varsa temizle
    await _clearExistingGoogleSession(googleSignIn);
    
    // Google Sign-In işlemini başlat
    final googleUser = await _attemptGoogleSignIn(googleSignIn);
    
    if (googleUser == null) {
      // Kullanıcı iptal etti - null döndür, hata fırlatma
      return null;
    }

    // Authentication bilgilerini al
    final googleAuth = await _getGoogleAuthentication(googleUser);
    
    // Firebase credential oluştur ve giriş yap
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final userCredential = await _signInToFirebase(credential, googleSignIn);
    
    if (userCredential?.user != null) {
      return await _handleUserAfterSignIn(userCredential!.user!);
    }
    
    return null;
  }

  /// Mevcut Google oturumunu temizle
  Future<void> _clearExistingGoogleSession(GoogleSignIn googleSignIn) async {
    if (_auth.currentUser != null) {
      try {
        await googleSignIn.signOut();
      } catch (e) {
        _log('Google oturum temizleme: $e');
      }
    }
  }

  /// Google Sign-In denemesi (retry destekli)
  Future<GoogleSignInAccount?> _attemptGoogleSignIn(GoogleSignIn googleSignIn) async {
    try {
      return await googleSignIn.signIn();
    } catch (e) {
      _log('İlk Google Sign-In denemesi başarısız: $e');
      
      // Retry mekanizması
      try {
        await googleSignIn.signOut();
        await Future.delayed(const Duration(milliseconds: 500));
        return await googleSignIn.signIn();
      } catch (retryError) {
        _log('Google Sign-In retry başarısız: $retryError');
        throw AuthException('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
      }
    }
  }

  /// Google authentication bilgilerini al
  Future<GoogleSignInAuthentication> _getGoogleAuthentication(GoogleSignInAccount googleUser) async {
    try {
      final googleAuth = await googleUser.authentication;
      
      if (googleAuth.idToken == null) {
        throw AuthException('Kimlik doğrulama token\'ı alınamadı.');
      }
      
      return googleAuth;
    } catch (e) {
      _log('Google authentication hatası: $e');
      throw AuthException('Kimlik doğrulama bilgileri alınamadı.');
    }
  }

  /// Firebase'e credential ile giriş yap
  Future<UserCredential?> _signInToFirebase(AuthCredential credential, GoogleSignIn googleSignIn) async {
    try {
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      _log('Firebase giriş hatası: $e');
      
      // Hata durumunda Google oturumunu temizle
      try {
        await googleSignIn.signOut();
      } catch (_) {}
      
      final errorString = e.toString().toLowerCase();
      
      if (errorString.contains('account-exists-with-different-credential')) {
        throw AuthException('Bu e-posta adresi başka bir giriş yöntemiyle kayıtlı.');
      } else if (errorString.contains('invalid-credential')) {
        throw AuthException('Geçersiz kimlik bilgisi. Lütfen tekrar deneyin.');
      } else if (errorString.contains('network')) {
        throw AuthException('İnternet bağlantınızı kontrol edin.');
      }
      
      rethrow;
    }
  }

  /// Veri tipi hatası mı kontrol et
  bool _isDataTypeError(String errorString) {
    final lower = errorString.toLowerCase();
    return lower.contains("type 'list") || 
           lower.contains("type 'map") ||
           lower.contains('is not a subtype');
  }

  /// Bozuk kullanıcı verilerini kurtarmaya çalış
  Future<app_user.AppUser?> _tryRecoverUserData() async {
    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) return null;
      
      _log('Kullanıcı verileri düzeltiliyor...');
      
      // Mevcut kullanıcı verilerini oku (following listesini korumak için)
      final existingUserDoc = await _firestore.collection('users').doc(currentUser.uid).get();
      app_user.AppUser appUser;
      
      if (existingUserDoc.exists) {
        try {
          final existingUser = app_user.AppUser.fromFirestore(existingUserDoc);
          _log('📋 Mevcut kullanıcı bulundu. Following listesi: ${existingUser.following.length} kişi');
          
          // Mevcut kullanıcıyı güncelle (Kullanıcı kendi avatarını seçtiyse Google fotoğrafıyla ezme)
          final hasCustomAvatar = existingUser.profileImageUrl.isNotEmpty;
          final effectiveProfileImage = hasCustomAvatar
              ? existingUser.profileImageUrl
              : (currentUser.photoURL ?? '');

          appUser = existingUser.copyWith(
            username: currentUser.displayName ?? existingUser.username,
            profileImageUrl: effectiveProfileImage,
          );
          
          // Sadece değişen alanları güncelle (following listesi korunur)
          final updateData = <String, dynamic>{};
          if (currentUser.displayName != null && currentUser.displayName != existingUser.username) {
            updateData['username'] = currentUser.displayName;
            updateData['displayName'] = currentUser.displayName;
          }
          // Yalnızca kullanıcının henüz bir profil resmi yoksa Google fotoğrafını ata
          if (!hasCustomAvatar && currentUser.photoURL != null && currentUser.photoURL!.isNotEmpty) {
            updateData['profileImageUrl'] = currentUser.photoURL;
            updateData['photoURL'] = currentUser.photoURL;
          }
          
          if (updateData.isNotEmpty) {
            try {
              await _firestore
                  .collection('users')
                  .doc(currentUser.uid)
                  .update(updateData);
            } catch (writeErr) {
              _log('⚠️ Mevcut kullanıcı alan güncelleme hatası (tolere edildi): $writeErr');
            }
          }
          
          _log('✅ Kullanıcı verileri düzeltildi. Following listesi korunuyor: ${appUser.following.length} kişi');
        } catch (parseError) {
          _log('Parse hatası, mevcut profil güvenli alanları güncelleniyor: $parseError');
          appUser = app_user.AppUser(
            uid: currentUser.uid,
            username: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Kullanıcı',
            profileImageUrl: currentUser.photoURL ?? '',
            badges: [],
            points: 0,
            dealCount: 0,
            totalLikes: 0,
          );
          
          try {
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'username': appUser.username,
              'displayName': appUser.username,
              if (appUser.profileImageUrl.isNotEmpty) 'profileImageUrl': appUser.profileImageUrl,
              if (appUser.profileImageUrl.isNotEmpty) 'photoURL': appUser.profileImageUrl,
            });
          } catch (updateErr) {
            _log('⚠️ Kurtarma sonrası güvenli profil güncelleme hatası: $updateErr');
          }
        }
      } else {
        // Yeni kullanıcı ise tam veriyi oluştur (create kuralı ile uyumlu)
        appUser = app_user.AppUser(
          uid: currentUser.uid,
          username: currentUser.displayName ?? currentUser.email?.split('@')[0] ?? 'Kullanıcı',
          profileImageUrl: currentUser.photoURL ?? '',
          badges: [],
          points: 0,
          dealCount: 0,
          totalLikes: 0,
        );
        
        await _firestore
            .collection('users')
            .doc(currentUser.uid)
            .set({
          ...appUser.toFirestore(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      
      try {
        await NotificationService().saveFCMToken(userId: currentUser.uid);
      } catch (tokenErr) {
        _log('⚠️ Recovery sonrası FCM Token kaydetme hatası: $tokenErr');
      }
      
      return appUser;
    } catch (e) {
      _log('❌ Veri düzeltme hatası: $e');
      return null;
    }
  }

  /// Hatayı kullanıcı dostu mesaja çevir
  AuthException _convertToUserFriendlyError(dynamic e) {
    if (e is AuthException) {
      return e;
    }

    final errorString = e.toString().toLowerCase();
    
    if (errorString.contains('network_error') || 
        errorString.contains('network') || 
        errorString.contains('socket') ||
        errorString.contains('connection')) {
      return AuthException('İnternet bağlantınızı kontrol edin.');
    }
    
    if (errorString.contains('sign_in_canceled') || 
        errorString.contains('canceled') ||
        errorString.contains('cancelled')) {
      return AuthException('Giriş iptal edildi.');
    }
    
    if (errorString.contains('user-not-found')) {
      return AuthException('Bu e-posta adresiyle kayıtlı bir hesap bulunamadı.');
    }

    if (errorString.contains('wrong-password')) {
      return AuthException('Hatalı şifre girdiniz. Lütfen tekrar deneyin.');
    }

    if (errorString.contains('invalid-credential')) {
      return AuthException('E-posta adresi veya şifre hatalı. Lütfen bilgilerinizi kontrol edin.');
    }

    if (errorString.contains('email-already-in-use')) {
      return AuthException('Bu e-posta adresi zaten kullanımda. Lütfen giriş yapmayı deneyin.');
    }

    if (errorString.contains('invalid-email')) {
      return AuthException('Lütfen geçerli bir e-posta adresi girin.');
    }

    if (errorString.contains('weak-password')) {
      return AuthException('Şifre çok zayıf. En az 6 karakterden oluşan bir şifre belirleyin.');
    }

    if (errorString.contains('user-disabled')) {
      return AuthException('Bu hesap devre dışı bırakılmıştır. Destek ekibiyle iletişime geçin.');
    }

    if (errorString.contains('requires-recent-login')) {
      return AuthException('Güvenlik nedeniyle bu işlem için yeniden giriş yapmanız gerekmektedir.');
    }

    if (errorString.contains('operation-not-allowed')) {
      return AuthException('Bu giriş yöntemi şu anda etkin değil.');
    }

    if (errorString.contains('too_many_requests') || 
        errorString.contains('too-many-requests')) {
      return AuthException('Çok fazla başarısız deneme yapıldı. Lütfen biraz bekleyip tekrar deneyin.');
    }
    
    if (errorString.contains('sign_in_failed')) {
      return AuthException('Giriş başarısız oldu. Lütfen tekrar deneyin.');
    }
    
    return AuthException('İşlem gerçekleştirilemedi. Lütfen tekrar deneyin.');
  }

  // Kullanıcı giriş sonrası işlemleri (ortak metod)
  Future<app_user.AppUser> _handleUserAfterSignIn(User firebaseUser, {String? initialDisplayName}) async {
    try {
      // Yeni oturumda admin önbelleğini sıfırla (güvenlik ve tutarlılık)
      clearAdminCache();

      final existingUserDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      app_user.AppUser appUser;
      
      final effectiveName = initialDisplayName ?? firebaseUser.displayName;

      if (existingUserDoc.exists) {
        try {
          final existingUser = app_user.AppUser.fromFirestore(existingUserDoc);
          _log('📋 Mevcut kullanıcı bulundu. Following listesi: ${existingUser.following.length} kişi');
          
          // Mevcut kullanıcıyı güncelle (Kullanıcı kendi avatarını seçtiyse Google fotoğrafıyla ezme)
          final hasCustomAvatar = existingUser.profileImageUrl.isNotEmpty;
          final effectiveProfileImage = hasCustomAvatar
              ? existingUser.profileImageUrl
              : (firebaseUser.photoURL ?? '');

          appUser = existingUser.copyWith(
            username: (effectiveName != null && effectiveName.isNotEmpty && (existingUser.username == 'Kullanıcı' || existingUser.username.isEmpty))
                ? effectiveName
                : (firebaseUser.displayName ?? existingUser.username),
            profileImageUrl: effectiveProfileImage,
          );
          
          // Mevcut kullanıcı varsa, sadece değişen alanları güncelle (takip verileri korunur)
          final updateData = <String, dynamic>{};
          if (effectiveName != null && effectiveName.isNotEmpty && existingUser.username != effectiveName) {
            updateData['username'] = effectiveName;
            updateData['displayName'] = effectiveName;
          } else if (firebaseUser.displayName != null && firebaseUser.displayName != existingUser.username) {
            updateData['username'] = firebaseUser.displayName;
            updateData['displayName'] = firebaseUser.displayName;
          }
          // Yalnızca kullanıcının henüz bir profil resmi yoksa Google fotoğrafını ata
          if (!hasCustomAvatar && firebaseUser.photoURL != null && firebaseUser.photoURL!.isNotEmpty) {
            updateData['profileImageUrl'] = firebaseUser.photoURL;
            updateData['photoURL'] = firebaseUser.photoURL;
          }
          
          // E-posta ve üyelik tarihi eksikse ekle/güncelle
          final existingData = existingUserDoc.data();
          if (firebaseUser.email != null && (existingData == null || existingData['email'] != firebaseUser.email)) {
            updateData['email'] = firebaseUser.email;
          }
          if (existingData == null || !existingData.containsKey('createdAt')) {
            updateData['createdAt'] = FieldValue.serverTimestamp();
          }
          
          // Sadece değişen alanlar varsa güncelle (following listesi korunur çünkü update() sadece belirtilen alanları günceller)
          if (updateData.isNotEmpty) {
            try {
              await _firestore
                  .collection('users')
                  .doc(firebaseUser.uid)
                  .update(updateData);
              _log('✅ Kullanıcı güncellendi. Following listesi korunuyor: ${appUser.following.length} kişi');
            } catch (updateErr) {
              _log('⚠️ Giriş sonrası kullanıcı verileri senkronizasyon hatası (tolere edildi): $updateErr');
            }
          } else {
            _log('ℹ️ Güncellenecek alan yok. Following listesi korunuyor: ${appUser.following.length} kişi');
          }
        } catch (parseError) {
          _log('Kullanıcı parse hatası, mevcut profil güvenli alanları güncelleniyor: $parseError');
          appUser = _createDefaultUser(firebaseUser, displayName: effectiveName);
          try {
            await _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .update({
              'username': appUser.username,
              'displayName': appUser.username,
              if (appUser.profileImageUrl.isNotEmpty) 'profileImageUrl': appUser.profileImageUrl,
              if (appUser.profileImageUrl.isNotEmpty) 'photoURL': appUser.profileImageUrl,
              if (firebaseUser.email != null) 'email': firebaseUser.email,
            });
          } catch (updateErr) {
            _log('⚠️ Parse hatası sonrası güvenli profil güncelleme hatası: $updateErr');
          }
        }
      } else {
        // Yeni kullanıcı ise tam veriyi oluştur (create kuralı ile uyumlu)
        appUser = _createDefaultUser(firebaseUser, displayName: effectiveName);
        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set({
          ...appUser.toFirestore(),
          'username': appUser.username,
          'displayName': appUser.username,
          'profileImageUrl': appUser.profileImageUrl,
          'photoURL': appUser.profileImageUrl,
          if (firebaseUser.email != null) 'email': firebaseUser.email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      _log('✅ Giriş başarılı: ${firebaseUser.email ?? firebaseUser.uid}');
      
      try {
        await NotificationService().saveFCMToken(userId: firebaseUser.uid);
      } catch (tokenErr) {
        _log('⚠️ Login sonrası FCM Token kaydetme hatası: $tokenErr');
      }

      // Observability: Kullanıcı kimliğini Analytics ve Crashlytics'e eşle
      try {
        await AnalyticsService.instance.setUser(firebaseUser.uid);
      } catch (analyticsErr) {
        _log('⚠️ Login sonrası Analytics setUser hatası: $analyticsErr');
      }
      
      return appUser;
    } catch (e) {
      _log('❌ Kullanıcı kaydetme hatası: $e');
      return _createDefaultUser(firebaseUser, displayName: initialDisplayName);
    }
  }

  /// Varsayılan kullanıcı oluştur
  app_user.AppUser _createDefaultUser(User firebaseUser, {String? displayName}) {
    final effectiveName = displayName ?? firebaseUser.displayName;
    return app_user.AppUser(
      uid: firebaseUser.uid,
      username: (effectiveName != null && effectiveName.isNotEmpty)
          ? effectiveName
          : (firebaseUser.email?.split('@')[0] ?? 'Kullanıcı'),
      profileImageUrl: firebaseUser.photoURL ?? '',
      badges: [],
      points: 0,
      dealCount: 0,
      totalLikes: 0,
    );
  }

  /// Apple Sign-In için kriptografik rastgele güvenli nonce üretimi
  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }

  /// Nonce dizesini SHA-256 ile özetler (Apple Authorization istemine gönderilen form)
  String _sha256ofString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // Apple ile giriş (iOS ve Apple ekosistemi için) - Production Ready
  Future<app_user.AppUser?> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = _sha256ofString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        rawNonce: rawNonce,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);

      if (userCredential.user != null) {
        final user = userCredential.user!;
        
        // Apple yalnızca ilk girişte ad-soyad iletir
        String? appleFullName;
        if (appleCredential.givenName != null || appleCredential.familyName != null) {
          final given = appleCredential.givenName ?? '';
          final family = appleCredential.familyName ?? '';
          final combined = '$given $family'.trim();
          if (combined.isNotEmpty) {
            appleFullName = combined;
          }
        }

        if (appleFullName != null && (user.displayName == null || user.displayName!.isEmpty)) {
          try {
            await user.updateDisplayName(appleFullName);
          } catch (nameErr) {
            _log('Apple displayName güncelleme hatası: $nameErr');
          }
        }

        // Ortak pipeline: Firestore kullanıcı dokümanı, takip listesi koruma, FCM token
        final appUser = await _handleUserAfterSignIn(user, initialDisplayName: appleFullName);
        _log('✅ Apple ile giriş başarılı: ${user.email ?? user.uid}');
        return appUser;
      }
      return null;
    } catch (e, stackTrace) {
      _log('❌ Apple giriş hatası: $e');
      _log('Stack trace: $stackTrace');
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('canceled') || errorString.contains('cancelled')) {
        // Kullanıcı yetkilendirme penceresini kapattı / iptal etti
        return null;
      }
      
      if (_isDataTypeError(e.toString())) {
        final recovered = await _tryRecoverUserData();
        if (recovered != null) return recovered;
        throw AuthException('Kullanıcı verileri okunurken bir hata oluştu. Lütfen tekrar deneyin.');
      }
      
      throw _convertToUserFriendlyError(e);
    }
  }

  // Email ve şifre ile kayıt - Production Ready (Ortak Boru Hattı Entegre)
  Future<app_user.AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final cleanEmail = email.trim();
      final cleanUsername = username.trim();

      // Email validasyonu
      if (!_isValidEmail(cleanEmail)) {
        throw AuthException('Geçersiz e-posta adresi.');
      }
      
      // Kullanıcı adı validasyonu
      if (cleanUsername.length < 3) {
        throw AuthException('Kullanıcı adı en az 3 karakter olmalıdır.');
      }

      // Şifre validasyonu
      if (password.length < 6) {
        throw AuthException('Şifre en az 6 karakter olmalıdır.');
      }
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );

      if (credential.user != null) {
        try {
          await credential.user!.updateDisplayName(cleanUsername);
          await credential.user!.reload();
        } catch (_) {}

        // Ortak boru hattı: Firestore users/{uid} oluşturma/koruma, FCM token, Analytics setUser
        final appUser = await _handleUserAfterSignIn(
          credential.user!,
          initialDisplayName: cleanUsername,
        );

        _log('✅ Email ile kayıt ve boru hattı başarılı: $cleanEmail');
        return appUser;
      }
      return null;
    } catch (e, stackTrace) {
      _log('❌ Email kayıt hatası: $e');
      _log('Stack trace: $stackTrace');
      
      if (_isDataTypeError(e.toString())) {
        final recovered = await _tryRecoverUserData();
        if (recovered != null) return recovered;
        throw AuthException('Kullanıcı verileri okunurken bir hata oluştu. Lütfen tekrar deneyin.');
      }
      
      throw _convertToUserFriendlyError(e);
    }
  }

  // Email ve şifre ile giriş - Production Ready (Ortak Boru Hattı Entegre)
  Future<app_user.AppUser?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cleanEmail = email.trim();

      if (!_isValidEmail(cleanEmail)) {
        throw AuthException('Geçersiz e-posta adresi.');
      }

      if (password.isEmpty) {
        throw AuthException('Şifre alanı boş bırakılamaz.');
      }

      final credential = await _auth.signInWithEmailAndPassword(
        email: cleanEmail,
        password: password,
      );
      
      if (credential.user != null) {
        // Ortak boru hattı: Firestore kullanıcı kontrolü, takip verileri koruma, FCM token, Analytics setUser
        final appUser = await _handleUserAfterSignIn(credential.user!);
        _log('✅ Email ile giriş ve boru hattı başarılı: $cleanEmail');
        return appUser;
      }
      return null;
    } catch (e, stackTrace) {
      _log('❌ Email giriş hatası: $e');
      _log('Stack trace: $stackTrace');
      
      if (_isDataTypeError(e.toString())) {
        final recovered = await _tryRecoverUserData();
        if (recovered != null) return recovered;
        throw AuthException('Kullanıcı verileri okunurken bir hata oluştu. Lütfen tekrar deneyin.');
      }
      
      throw _convertToUserFriendlyError(e);
    }
  }

  // Şifre sıfırlama e-postası gönder
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      final cleanEmail = email.trim();
      if (!_isValidEmail(cleanEmail)) {
        throw AuthException('Geçerli bir e-posta adresi girin.');
      }

      await _auth.sendPasswordResetEmail(email: cleanEmail);
      _log('✅ Şifre sıfırlama e-postası gönderildi: $cleanEmail');
    } catch (e, stackTrace) {
      _log('❌ Şifre sıfırlama hatası: $e');
      _log('Stack trace: $stackTrace');
      throw _convertToUserFriendlyError(e);
    }
  }

  // Email ve şifre ile yeniden kimlik doğrulama (Hesap silme koruması)
  Future<void> reauthenticateWithEmailPassword({required String password}) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        throw AuthException('Oturum açık değil veya e-posta adresi bulunamadı.');
      }

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );

      await user.reauthenticateWithCredential(credential);
      _log('✅ E-posta yeniden kimlik doğrulama başarılı: ${user.email}');
    } catch (e, stackTrace) {
      _log('❌ Yeniden doğrulama hatası: $e');
      _log('Stack trace: $stackTrace');
      throw _convertToUserFriendlyError(e);
    }
  }

  // Çıkış - Production Ready
  Future<void> signOut() async {
    try {
      // Cihaz token'ını temizle
      try {
        await NotificationService().clearDeviceToken();
      } catch (e) {
        _log('NotificationService clear token: $e');
      }

      // Rozet servisini durdur ve ikondaki rozeti temizle
      try {
        AppBadgeService.instance.stopRealtimeBadgeSync();
        await AppBadgeService.instance.clearBadge();
      } catch (e) {
        _log('AppBadgeService clear error: $e');
      }

      // Google Sign-In oturumunu temizle
      try {
        await _googleSignInInstance.signOut();
      } catch (e) {
        _log('Google Sign-Out: $e');
      }
      
      // Firebase Auth oturumunu temizle
      await _auth.signOut();

      // Observability: Analytics ve Crashlytics kullanıcı kimliğini sıfırla
      try {
        await AnalyticsService.instance.setUser(null);
      } catch (e) {
        _log('Analytics clear user: $e');
      }

      clearAdminCache();
      _log('✅ Çıkış başarılı');
    } catch (e) {
      _log('Sign-Out hatası: $e');
      // Son çare olarak Firebase Auth'u temizle
      try {
        await _auth.signOut();
      } catch (_) {}
    }
  }

  // Kullanıcı bilgilerini getir
  Future<app_user.AppUser?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return app_user.AppUser.fromFirestore(doc);
      }
      return null;
    } catch (e, stack) {
      _log('Kullanıcı bilgisi getirme hatası: $e');
      SystemLogService.instance.logError(
        category: 'auth',
        errorType: 'GetUserDataException',
        message: 'Kullanıcı bilgisi alınamadı ($uid): $e',
        stack: stack,
        severity: SystemErrorSeverity.error,
        metadata: {'targetUid': uid},
      );
      return null;
    }
  }

  // Admin kontrolü (In-Memory TTL önbellekli & Single-Flight Concurrency Korumalı)
  Future<bool> isAdmin({bool forceRefresh = false}) async {
    try {
      final user = currentUser;
      if (user == null) {
        clearAdminCache();
        return false;
      }

      // Farklı bir kullanıcının önbelleği kalmışsa derhal temizle (Fail-Closed Güvenlik)
      if (_cachedAdminUid != null && _cachedAdminUid != user.uid) {
        clearAdminCache();
      }

      // TTL ve bellek önbelleği kontrolü (Firestore maliyeti ve latency optimizasyonu)
      if (!forceRefresh &&
          _cachedAdminUid == user.uid &&
          _cachedIsAdmin != null &&
          _lastAdminCheck != null &&
          DateTime.now().difference(_lastAdminCheck!) < _adminCacheTTL) {
        return _cachedIsAdmin!;
      }

      // Single-Flight Concurrency Lock: Eşzamanlı (login veya sayfa açılışı) gelen çağrıları tek bir operasyona bağla
      if (_inFlightAdminCheck != null) {
        return await _inFlightAdminCheck!;
      }

      _inFlightAdminCheck = _fetchAdminStatus(user.uid);
      return await _inFlightAdminCheck!;
    } catch (e, stack) {
      _log('Admin kontrolü hatası: $e');
      final errLower = e.toString().toLowerCase();
      final isTransient = errLower.contains('unavailable') ||
                          errLower.contains('network') ||
                          errLower.contains('socketexception') ||
                          errLower.contains('timeout') ||
                          errLower.contains('deadline-exceeded');
      if (!isTransient) {
        SystemLogService.instance.logError(
          category: 'auth',
          errorType: 'AdminCheckException',
          message: 'Admin yetki kontrolü başarısız: $e',
          stack: stack,
          severity: SystemErrorSeverity.error,
        );
      } else {
        _log('ℹ️ Admin yetki kontrolü geçici ağ kesintisinde önbellek ile tolere edildi');
      }
      // Kesinlikle yalnızca doğrulanmış mevcut UID ile eşleşen önbellek dönebilir
      if (currentUser?.uid != null && _cachedAdminUid == currentUser!.uid && _cachedIsAdmin != null) {
        return _cachedIsAdmin!;
      }
      return false;
    } finally {
      _inFlightAdminCheck = null;
    }
  }

  Future<bool> _fetchAdminStatus(String uid) async {
    DocumentSnapshot<Map<String, dynamic>> userDoc;
    try {
      userDoc = await _firestore.collection('users').doc(uid).get();
    } catch (e) {
      final errStr = e.toString().toLowerCase();
      // Geçici ağ kesintisi / socket gecikmesinde 400ms bekleyip tek seferlik retry
      if (errStr.contains('unavailable') || errStr.contains('network') || errStr.contains('deadline-exceeded')) {
        _log('⏳ Firestore admin kontrolü geçici ağ kesintisi, yeniden deneniyor...');
        await Future.delayed(const Duration(milliseconds: 400));
        userDoc = await _firestore.collection('users').doc(uid).get();
      } else {
        rethrow;
      }
    }

    if (userDoc.exists) {
      final data = userDoc.data();
      
      // Hem isAdmin (büyük A) hem de isadmin (küçük harf) kontrolü yap
      final adminValue = data?['isAdmin'] ?? data?['isadmin'];
      final isAdmin = adminValue == true || adminValue == 'true' || adminValue == 1;
      
      _cachedIsAdmin = isAdmin;
      _cachedAdminUid = uid;
      _lastAdminCheck = DateTime.now();

      _log('👮 Admin kontrolü (Firestore güncellendi): isAdmin=$isAdmin');
      
      return isAdmin;
    }

    _cachedIsAdmin = false;
    _cachedAdminUid = uid;
    _lastAdminCheck = DateTime.now();
    return false;
  }

  /// Email formatı kontrolü (Modern TLD'ler ve alt etiketleri tam destekler)
  bool _isValidEmail(String email) {
    return RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email.trim());
  }

  // Hesap silme (Opsiyonel şifre ile anında re-auth destekli)
  Future<void> deleteAccount({String? reauthPassword}) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw AuthException('Oturum açık değil.');
      }

      final uid = user.uid;

      // Eğer kullanıcı şifre ile yeniden doğrulama talep ettiyse
      if (reauthPassword != null && reauthPassword.isNotEmpty) {
        await reauthenticateWithEmailPassword(password: reauthPassword);
      }

      // P0-12 (R-PRV-08): 1. Önce Firebase Auth'dan kullanıcıyı sil.
      // Eğer oturum eski ise 'requires-recent-login' fırlatır; Firestore dokümanı zombileşmez!
      await user.delete();

      // 2. Auth silinmesi başarılı oldu; sunucudaki onUserDeleted trigger'ı tüm verileri kaskat temizler.
      // Güvence amaçlı istemciden de ana dokümanı temizlemeyi dene:
      try {
        await _firestore.collection('users').doc(uid).delete();
      } catch (_) {}

      // 3. Oturumu temizle
      if (_googleSignIn != null) {
        try {
          await _googleSignIn!.signOut();
        } catch (_) {}
      }

      _log('✅ Hesap ve veriler başarıyla silindi.');
    } catch (e) {
      _log('Hesap silme hatası: $e');
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('requires-recent-login')) {
        throw AuthException(
            'Güvenlik nedeniyle hesabınızı silmeden önce yeniden doğrulama yapmanız gerekmektedir.');
      }
      if (e is AuthException) {
        rethrow;
      }
      throw AuthException('Hesap silinirken bir hata oluştu: ${e.toString()}');
    }
  }
}

