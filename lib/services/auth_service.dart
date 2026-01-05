import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import '../models/user.dart' as app_user;

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
  
  // Lazy initialization - sadece gerektiğinde oluştur
  GoogleSignIn get _googleSignInInstance {
    _googleSignIn ??= GoogleSignIn();
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
          
          // Mevcut kullanıcıyı güncelle (following listesi korunur)
          appUser = existingUser.copyWith(
            username: currentUser.displayName ?? existingUser.username,
            profileImageUrl: currentUser.photoURL ?? existingUser.profileImageUrl,
          );
          
          // Sadece değişen alanları güncelle (following listesi korunur)
          final updateData = <String, dynamic>{};
          if (currentUser.displayName != null && currentUser.displayName != existingUser.username) {
            updateData['username'] = currentUser.displayName;
          }
          if (currentUser.photoURL != null && currentUser.photoURL != existingUser.profileImageUrl) {
            updateData['profileImageUrl'] = currentUser.photoURL;
          }
          
          if (updateData.isNotEmpty) {
            await _firestore
                .collection('users')
                .doc(currentUser.uid)
                .update(updateData);
          }
          
          _log('✅ Kullanıcı verileri düzeltildi. Following listesi korunuyor: ${appUser.following.length} kişi');
        } catch (parseError) {
          _log('Parse hatası, yeni kullanıcı oluşturuluyor: $parseError');
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
              .set(appUser.toFirestore(), SetOptions(merge: true));
        }
      } else {
        // Yeni kullanıcı ise tam veriyi oluştur
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
            .set(appUser.toFirestore());
      }
      
      return appUser;
    } catch (e) {
      _log('❌ Veri düzeltme hatası: $e');
      return null;
    }
  }

  /// Hatayı kullanıcı dostu mesaja çevir
  AuthException _convertToUserFriendlyError(dynamic e) {
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
    
    if (errorString.contains('sign_in_failed') || 
        errorString.contains('sign_in')) {
      return AuthException('Giriş başarısız oldu. Lütfen tekrar deneyin.');
    }
    
    if (errorString.contains('too_many_requests') || 
        errorString.contains('too-many-requests')) {
      return AuthException('Çok fazla deneme. Lütfen biraz bekleyin.');
    }
    
    if (e is AuthException) {
      return e;
    }
    
    return AuthException('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
  }

  // Kullanıcı giriş sonrası işlemleri (ortak metod)
  Future<app_user.AppUser> _handleUserAfterSignIn(User firebaseUser) async {
    try {
      final existingUserDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      app_user.AppUser appUser;
      
      if (existingUserDoc.exists) {
        try {
          final existingUser = app_user.AppUser.fromFirestore(existingUserDoc);
          _log('📋 Mevcut kullanıcı bulundu. Following listesi: ${existingUser.following.length} kişi');
          
          appUser = existingUser.copyWith(
            username: firebaseUser.displayName ?? existingUser.username,
            profileImageUrl: firebaseUser.photoURL ?? existingUser.profileImageUrl,
          );
          
          // Mevcut kullanıcı varsa, sadece değişen alanları güncelle (takip verileri korunur)
          final updateData = <String, dynamic>{};
          if (firebaseUser.displayName != null && firebaseUser.displayName != existingUser.username) {
            updateData['username'] = firebaseUser.displayName;
          }
          if (firebaseUser.photoURL != null && firebaseUser.photoURL != existingUser.profileImageUrl) {
            updateData['profileImageUrl'] = firebaseUser.photoURL;
          }
          
          // Sadece değişen alanlar varsa güncelle (following listesi korunur çünkü update() sadece belirtilen alanları günceller)
          if (updateData.isNotEmpty) {
            await _firestore
                .collection('users')
                .doc(firebaseUser.uid)
                .update(updateData);
            _log('✅ Kullanıcı güncellendi. Following listesi korunuyor: ${appUser.following.length} kişi');
            
            // Following listesinin korunduğunu doğrula
            final verifyDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
            if (verifyDoc.exists) {
              final verifyData = verifyDoc.data();
              final verifyFollowing = List<String>.from(verifyData?['following'] ?? []);
              _log('🔍 Doğrulama: Firestore\'da following listesi: ${verifyFollowing.length} kişi');
              if (verifyFollowing.length != existingUser.following.length) {
                _log('⚠️ UYARI: Following listesi kaybolmuş olabilir! Önce: ${existingUser.following.length}, Şimdi: ${verifyFollowing.length}');
              }
            }
          } else {
            _log('ℹ️ Güncellenecek alan yok. Following listesi korunuyor: ${appUser.following.length} kişi');
          }
        } catch (parseError) {
          _log('Kullanıcı parse hatası, yeni oluşturuluyor: $parseError');
          appUser = _createDefaultUser(firebaseUser);
          await _firestore
              .collection('users')
              .doc(firebaseUser.uid)
              .set(appUser.toFirestore(), SetOptions(merge: true));
        }
      } else {
        // Yeni kullanıcı ise tam veriyi oluştur
        appUser = _createDefaultUser(firebaseUser);
        await _firestore
            .collection('users')
            .doc(firebaseUser.uid)
            .set(appUser.toFirestore());
      }

      _log('✅ Giriş başarılı: ${firebaseUser.email}');
      _log('📋 Final appUser following listesi: ${appUser.following.length} kişi');
      if (appUser.following.isNotEmpty) {
        _log('📋 Takip edilen kullanıcılar: ${appUser.following.join(", ")}');
      }
      return appUser;
    } catch (e) {
      _log('❌ Kullanıcı kaydetme hatası: $e');
      return _createDefaultUser(firebaseUser);
    }
  }

  /// Varsayılan kullanıcı oluştur
  app_user.AppUser _createDefaultUser(User firebaseUser) {
    return app_user.AppUser(
      uid: firebaseUser.uid,
      username: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
      profileImageUrl: firebaseUser.photoURL ?? '',
      badges: [],
      points: 0,
      dealCount: 0,
      totalLikes: 0,
    );
  }

  // Apple ile giriş (iOS için) - Production Ready
  Future<app_user.AppUser?> signInWithApple() async {
    try {
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);

      if (userCredential.user != null) {
        // Apple Sign-In'de username oluştur
        String username = 'Kullanıcı';
        if (appleCredential.givenName != null && appleCredential.familyName != null) {
          username = '${appleCredential.givenName} ${appleCredential.familyName}';
        } else if (userCredential.user!.displayName != null) {
          username = userCredential.user!.displayName!;
        }
        
        // Mevcut kullanıcıyı kontrol et
        final existingUserDoc = await _firestore.collection('users').doc(userCredential.user!.uid).get();
        app_user.AppUser appUser;
        
        if (existingUserDoc.exists) {
          try {
            final existingUser = app_user.AppUser.fromFirestore(existingUserDoc);
            appUser = existingUser;
            
            // Sadece username değiştiyse güncelle (takip verileri korunur)
            if (username != existingUser.username) {
              await _firestore
                  .collection('users')
                  .doc(userCredential.user!.uid)
                  .update({'username': username});
              appUser = existingUser.copyWith(username: username);
            }
          } catch (parseError) {
            _log('Kullanıcı parse hatası, yeni oluşturuluyor: $parseError');
            appUser = _createDefaultUser(userCredential.user!);
            await _firestore
                .collection('users')
                .doc(userCredential.user!.uid)
                .set(appUser.toFirestore(), SetOptions(merge: true));
          }
        } else {
          // Yeni kullanıcı ise tam veriyi oluştur
          appUser = app_user.AppUser(
            uid: userCredential.user!.uid,
            username: username,
            profileImageUrl: userCredential.user!.photoURL ?? '',
            badges: [],
            points: 0,
            dealCount: 0,
            totalLikes: 0,
          );
          await _firestore
              .collection('users')
              .doc(userCredential.user!.uid)
              .set(appUser.toFirestore());
        }
        
        _log('✅ Apple ile giriş başarılı');
        return appUser;
      }
      return null;
    } catch (e) {
      _log('Apple giriş hatası: $e');
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('canceled') || errorString.contains('cancelled')) {
        throw AuthException('Giriş iptal edildi.');
      }
      throw AuthException('Apple ile giriş yapılamadı. Lütfen tekrar deneyin.');
    }
  }

  // Email ve şifre ile kayıt - Production Ready
  Future<app_user.AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Email validasyonu
      if (!_isValidEmail(email)) {
        throw AuthException('Geçersiz e-posta adresi.');
      }
      
      // Şifre validasyonu
      if (password.length < 6) {
        throw AuthException('Şifre en az 6 karakter olmalıdır.');
      }
      
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        final appUser = app_user.AppUser(
          uid: credential.user!.uid,
          username: username,
          profileImageUrl: '',
          badges: [],
          points: 0,
          dealCount: 0,
          totalLikes: 0,
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(appUser.toFirestore());

        _log('✅ Kayıt başarılı: $email');
        return appUser;
      }
      return null;
    } catch (e) {
      _log('Kayıt hatası: $e');
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('email-already-in-use')) {
        throw AuthException('Bu e-posta adresi zaten kullanımda.');
      } else if (errorString.contains('invalid-email')) {
        throw AuthException('Geçersiz e-posta adresi.');
      } else if (errorString.contains('weak-password')) {
        throw AuthException('Şifre çok zayıf. Daha güçlü bir şifre seçin.');
      } else if (e is AuthException) {
        rethrow;
      }
      
      throw AuthException('Kayıt yapılamadı. Lütfen tekrar deneyin.');
    }
  }

  // Email ve şifre ile giriş - Production Ready
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      _log('✅ Email ile giriş başarılı: $email');
      return credential.user;
    } catch (e) {
      _log('Giriş hatası: $e');
      
      final errorString = e.toString().toLowerCase();
      if (errorString.contains('user-not-found')) {
        throw AuthException('Bu e-posta adresiyle kayıtlı kullanıcı bulunamadı.');
      } else if (errorString.contains('wrong-password')) {
        throw AuthException('Hatalı şifre.');
      } else if (errorString.contains('invalid-email')) {
        throw AuthException('Geçersiz e-posta adresi.');
      } else if (errorString.contains('user-disabled')) {
        throw AuthException('Bu hesap devre dışı bırakılmış.');
      } else if (errorString.contains('too-many-requests')) {
        throw AuthException('Çok fazla başarısız deneme. Lütfen biraz bekleyin.');
      }
      
      throw AuthException('Giriş yapılamadı. Lütfen bilgilerinizi kontrol edin.');
    }
  }

  // Çıkış - Production Ready
  Future<void> signOut() async {
    try {
      // Google Sign-In oturumunu temizle
      if (_googleSignIn != null) {
        try {
          await _googleSignIn!.signOut();
        } catch (e) {
          _log('Google Sign-Out: $e');
        }
      }
      
      // Firebase Auth oturumunu temizle
      await _auth.signOut();
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
    } catch (e) {
      _log('Kullanıcı bilgisi getirme hatası: $e');
      return null;
    }
  }

  // Admin kontrolü
  Future<bool> isAdmin() async {
    try {
      final user = currentUser;
      if (user == null) return false;
      
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        return data?['isAdmin'] == true;
      }
      return false;
    } catch (e) {
      _log('Admin kontrolü hatası: $e');
      return false;
    }
  }

  /// Email formatı kontrolü
  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}

