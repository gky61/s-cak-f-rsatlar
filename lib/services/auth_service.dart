import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../models/user.dart' as app_user;

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

  // Google ile giriş
  Future<app_user.AppUser?> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        // Web için Firebase Auth'un direkt Google Sign-In metodunu kullan
        final GoogleAuthProvider googleProvider = GoogleAuthProvider();
        googleProvider.addScope('email');
        googleProvider.addScope('profile');
        
        final UserCredential userCredential = await _auth.signInWithPopup(googleProvider);
        
        if (userCredential.user != null) {
          return await _handleUserAfterSignIn(userCredential.user!);
        }
        return null;
      } else {
        // Mobil platformlar için Google Sign-In
        // Singleton instance kullan
        final googleSignIn = _googleSignInInstance;
        
        // Önce mevcut Firebase oturumunu kontrol et
        final currentFirebaseUser = _auth.currentUser;
        if (currentFirebaseUser != null) {
          // Firebase'de zaten oturum varsa, Google Sign-In'i temizle ve yeniden başlat
          try {
            await googleSignIn.signOut();
          } catch (e) {
            print('Google Sign-In temizleme hatası (normal olabilir): $e');
          }
        }
        
        // Google Sign-In işlemini başlat
        GoogleSignInAccount? googleUser;
        try {
          googleUser = await googleSignIn.signIn();
        } catch (e) {
          print('Google Sign-In başlatma hatası: $e');
          // Eğer signIn başarısız olursa, önce signOut yap ve tekrar dene
          try {
            await googleSignIn.signOut();
            await Future.delayed(const Duration(milliseconds: 500));
            googleUser = await googleSignIn.signIn();
          } catch (retryError) {
            print('Google Sign-In retry hatası: $retryError');
            throw Exception('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
          }
        }
        
        if (googleUser == null) {
          // Kullanıcı iptal etti
          print('Google giriş iptal edildi');
          return null;
        }

        // Google'dan authentication bilgilerini al
        GoogleSignInAuthentication googleAuth;
        try {
          googleAuth = await googleUser.authentication;
        } catch (e) {
          print('Google authentication bilgisi alma hatası: $e');
          throw Exception('Google kimlik doğrulama bilgileri alınamadı.');
        }

        if (googleAuth.idToken == null) {
          print('Google ID token alınamadı');
          throw Exception('Google ID token alınamadı. Lütfen tekrar deneyin.');
        }

        // Firebase için credential oluştur
        final credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        // Firebase'e giriş yap
        UserCredential userCredential;
        try {
          userCredential = await _auth.signInWithCredential(credential);
        } catch (e) {
          print('Firebase credential ile giriş hatası: $e');
          // Firebase hatası durumunda Google oturumunu temizle
          try {
            await googleSignIn.signOut();
          } catch (signOutError) {
            print('Google Sign-Out hatası: $signOutError');
          }
          
          if (e.toString().contains('account-exists-with-different-credential')) {
            throw Exception('Bu email adresi farklı bir giriş yöntemiyle kayıtlı.');
          } else if (e.toString().contains('invalid-credential')) {
            throw Exception('Geçersiz kimlik bilgisi. Lütfen tekrar deneyin.');
          } else if (e.toString().contains('network')) {
            throw Exception('İnternet bağlantınızı kontrol edin.');
          }
          rethrow;
        }

        if (userCredential.user != null) {
          return await _handleUserAfterSignIn(userCredential.user!);
        }
        
        print('⚠️ Firebase giriş sonrası kullanıcı null');
        return null;
      }
    } catch (e, stackTrace) {
      print('❌ Google giriş hatası: $e');
      print('Stack trace: $stackTrace');
      
      // Kullanıcı dostu hata mesajları
      final errorString = e.toString().toLowerCase();
      
      // Tip hatası (List, Map, vb.) durumunda özel mesaj
      if (errorString.contains("type 'list") || 
          errorString.contains("type 'map") ||
          errorString.contains('is not a subtype')) {
        print('⚠️ Veri tipi hatası tespit edildi, kullanıcı verileri düzeltiliyor...');
        // Veri tipi hatası durumunda, kullanıcıyı oluşturmayı tekrar dene
        try {
          final currentUser = _auth.currentUser;
          if (currentUser != null) {
            // Firebase'de kullanıcı var, Firestore'u düzeltmeyi dene
            final appUser = app_user.AppUser(
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
            print('✅ Kullanıcı verileri düzeltildi');
            return appUser;
          }
        } catch (recoveryError) {
          print('❌ Veri düzeltme hatası: $recoveryError');
        }
        throw Exception('Kullanıcı verileri okunurken bir hata oluştu. Lütfen tekrar deneyin.');
      }
      
      if (errorString.contains('network_error') || errorString.contains('network') || errorString.contains('socket')) {
        throw Exception('İnternet bağlantınızı kontrol edin');
      } else if (errorString.contains('sign_in_canceled') || errorString.contains('canceled')) {
        throw Exception('Giriş iptal edildi');
      } else if (errorString.contains('sign_in_failed') || errorString.contains('sign_in')) {
        throw Exception('Giriş başarısız oldu. Lütfen tekrar deneyin.');
      } else if (e is Exception) {
        // Hata mesajını kısalt (çok uzun olabilir)
        final errorMsg = e.toString();
        if (errorMsg.length > 100) {
          throw Exception('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
        }
        rethrow;
      }
      
      throw Exception('Google ile giriş yapılamadı. Lütfen tekrar deneyin.');
    }
  }

  // Kullanıcı giriş sonrası işlemleri (ortak metod)
  Future<app_user.AppUser> _handleUserAfterSignIn(User firebaseUser) async {
    try {
      // Mevcut kullanıcı verilerini kontrol et
      final existingUserDoc = await _firestore.collection('users').doc(firebaseUser.uid).get();
      app_user.AppUser appUser;
      
      if (existingUserDoc.exists) {
        try {
          // Mevcut kullanıcı varsa, mevcut verileri koru ve sadece güncelle
          final existingUser = app_user.AppUser.fromFirestore(existingUserDoc);
          appUser = existingUser.copyWith(
            username: firebaseUser.displayName ?? existingUser.username,
            profileImageUrl: firebaseUser.photoURL ?? existingUser.profileImageUrl,
          );
        } catch (parseError) {
          print('Mevcut kullanıcı parse hatası, yeni kullanıcı oluşturuluyor: $parseError');
          // Parse hatası durumunda yeni kullanıcı oluştur
          appUser = app_user.AppUser(
            uid: firebaseUser.uid,
            username: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
            profileImageUrl: firebaseUser.photoURL ?? '',
            badges: [],
            points: 0,
            dealCount: 0,
            totalLikes: 0,
          );
        }
      } else {
        // Yeni kullanıcı oluştur
        appUser = app_user.AppUser(
          uid: firebaseUser.uid,
          username: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
          profileImageUrl: firebaseUser.photoURL ?? '',
          badges: [],
          points: 0,
          dealCount: 0,
          totalLikes: 0,
        );
      }

      // Firestore'a kaydet/güncelle (merge ile mevcut verileri koru)
      await _firestore
          .collection('users')
          .doc(firebaseUser.uid)
          .set(appUser.toFirestore(), SetOptions(merge: true));

      print('✅ Google ile giriş başarılı: ${firebaseUser.email}');
      return appUser;
    } catch (e, stackTrace) {
      print('❌ Kullanıcı verisi kaydetme hatası: $e');
      print('Stack trace: $stackTrace');
      
      // Hata olsa bile temel kullanıcı bilgilerini döndür
      try {
        return app_user.AppUser(
          uid: firebaseUser.uid,
          username: firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'Kullanıcı',
          profileImageUrl: firebaseUser.photoURL ?? '',
          badges: [],
          points: 0,
          dealCount: 0,
          totalLikes: 0,
        );
      } catch (fallbackError) {
        print('❌ Fallback kullanıcı oluşturma hatası: $fallbackError');
        // Son çare: minimum bilgilerle kullanıcı oluştur
        return app_user.AppUser(
          uid: firebaseUser.uid,
          username: 'Kullanıcı',
          profileImageUrl: '',
          badges: [],
          points: 0,
          dealCount: 0,
          totalLikes: 0,
        );
      }
    }
  }

  // Apple ile giriş (iOS için)
  Future<app_user.AppUser?> signInWithApple() async {
    try {
      // Apple Sign-In işlemini başlat
      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );

      // Firebase için credential oluştur
      final oauthCredential = OAuthProvider("apple.com").credential(
        idToken: appleCredential.identityToken,
        accessToken: appleCredential.authorizationCode,
      );

      // Firebase'e giriş yap
      final UserCredential userCredential = await _auth.signInWithCredential(oauthCredential);

      if (userCredential.user != null) {
        // Kullanıcı adını oluştur
        String username = 'Kullanıcı';
        if (appleCredential.givenName != null && appleCredential.familyName != null) {
          username = '${appleCredential.givenName} ${appleCredential.familyName}';
        } else if (userCredential.user!.displayName != null) {
          username = userCredential.user!.displayName!;
        }

        // Kullanıcı bilgilerini Firestore'a kaydet/güncelle
        final appUser = app_user.AppUser(
          uid: userCredential.user!.uid,
          username: username,
          profileImageUrl: userCredential.user!.photoURL ?? '',
        );

        await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .set(appUser.toFirestore(), SetOptions(merge: true));

        return appUser;
      }
      return null;
    } catch (e) {
      print('Apple giriş hatası: $e');
      return null;
    }
  }

  // Email ve şifre ile kayıt
  Future<app_user.AppUser?> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (credential.user != null) {
        // Kullanıcı bilgilerini Firestore'a kaydet
        final appUser = app_user.AppUser(
          uid: credential.user!.uid,
          username: username,
          profileImageUrl: '',
        );

        await _firestore
            .collection('users')
            .doc(credential.user!.uid)
            .set(appUser.toFirestore());

        return appUser;
      }
      return null;
    } catch (e) {
      print('Kayıt hatası: $e');
      return null;
    }
  }

  // Email ve şifre ile giriş
  Future<User?> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user;
    } catch (e) {
      print('Giriş hatası: $e');
      return null;
    }
  }

  // Çıkış
  Future<void> signOut() async {
    try {
      // Önce Google Sign-In oturumunu temizle
      if (_googleSignIn != null) {
        try {
          await _googleSignIn!.signOut();
        } catch (e) {
          print('Google Sign-Out hatası (önemli değil): $e');
        }
      }
      // Firebase Auth oturumunu temizle
      await _auth.signOut();
    } catch (e) {
      print('Sign-Out hatası: $e');
      // Hata olsa bile Firebase Auth'u temizlemeyi dene
      try {
        await _auth.signOut();
      } catch (firebaseError) {
        print('Firebase Sign-Out hatası: $firebaseError');
      }
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
      print('Kullanıcı bilgisi getirme hatası: $e');
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
      print('Admin kontrolü hatası: $e');
      return false;
    }
  }
}
