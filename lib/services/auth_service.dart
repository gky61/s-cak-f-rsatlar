import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import '../models/user.dart' as app_user;

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  // Mevcut kullanıcı
  User? get currentUser => _auth.currentUser;

  // Kullanıcı durumu stream'i
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Google ile giriş
  Future<app_user.AppUser?> signInWithGoogle() async {
    try {
      // Google Sign-In işlemini başlat
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      
      if (googleUser == null) {
        // Kullanıcı iptal etti
        return null;
      }

      // Google'dan authentication bilgilerini al
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // Firebase için credential oluştur
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Firebase'e giriş yap
      final UserCredential userCredential = await _auth.signInWithCredential(credential);

      if (userCredential.user != null) {
        // Kullanıcı bilgilerini Firestore'a kaydet/güncelle
        final appUser = app_user.AppUser(
          uid: userCredential.user!.uid,
          username: userCredential.user!.displayName ?? 'Kullanıcı',
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
      print('Google giriş hatası: $e');
      return null;
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
    await _googleSignIn.signOut();
    await _auth.signOut();
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
}
