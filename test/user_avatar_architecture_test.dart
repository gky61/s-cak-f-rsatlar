import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/models/user.dart';
import 'package:sicak_firsatlar/utils/asset_path_migration.dart';

void main() {
  group('AppUser Avatar & Source of Truth Tests', () {
    test('Yeni kullanıcı Google fotoğrafı ile başlatıldığında Source of Truth ve Presentation layer doğru eşleşir', () {
      final user = AppUser(
        uid: 'user_123',
        username: 'Ahmet Yılmaz',
        profileImageUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
        providerPhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
      );

      expect(user.hasProviderPhoto, isTrue);
      expect(user.isUsingProviderPhoto, isTrue);
      expect(user.isUsingReadyAvatar, isFalse);
      expect(user.hasCustomAvatar, isTrue);
      expect(user.providerPhotoUrl, equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));
      expect(user.profileImageUrl, equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));
    });

    test('Kullanıcı hazır avatar seçtiğinde providerPhotoUrl ASLA silinmez veya bozulmaz', () {
      final initialUser = AppUser(
        uid: 'user_123',
        username: 'Ahmet Yılmaz',
        profileImageUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
        providerPhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
        following: ['uid_999'],
        pinnedBadge: 'gold',
      );

      // Hazır avatar seçimi (copyWith ile güncellenir)
      final updatedUser = initialUser.copyWith(
        profileImageUrl: AppAvatars.kuponKrali,
      );

      expect(updatedUser.profileImageUrl, equals(AppAvatars.kuponKrali));
      expect(updatedUser.providerPhotoUrl, equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));
      expect(updatedUser.hasProviderPhoto, isTrue);
      expect(updatedUser.isUsingProviderPhoto, isFalse);
      expect(updatedUser.isUsingReadyAvatar, isTrue);
      expect(updatedUser.hasCustomAvatar, isTrue);
      // Diğer alanların kaybolmadığı doğrulanır
      expect(updatedUser.following, equals(['uid_999']));
      expect(updatedUser.pinnedBadge, equals('gold'));
    });

    test('Kullanıcı profil fotoğrafını kaldırdığında providerPhotoUrl korunur ve varsayılan görünüme geçer', () {
      final initialUser = AppUser(
        uid: 'user_123',
        username: 'Ahmet Yılmaz',
        profileImageUrl: AppAvatars.cat,
        providerPhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
      );

      // Avatar kaldırma
      final clearedUser = initialUser.copyWith(profileImageUrl: '');

      expect(clearedUser.profileImageUrl, isEmpty);
      expect(clearedUser.providerPhotoUrl, equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));
      expect(clearedUser.hasProviderPhoto, isTrue);
      expect(clearedUser.isUsingProviderPhoto, isFalse);
      expect(clearedUser.isUsingReadyAvatar, isFalse);
      expect(clearedUser.hasCustomAvatar, isFalse);
    });

    test('Kullanıcı Google orijinal fotoğrafına tek tıkla geri dönebilir', () {
      final userWithoutAvatar = AppUser(
        uid: 'user_123',
        username: 'Ahmet Yılmaz',
        profileImageUrl: '',
        providerPhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
      );

      // Google fotoğrafını geri yükleme
      final restoredUser = userWithoutAvatar.copyWith(
        profileImageUrl: userWithoutAvatar.providerPhotoUrl,
      );

      expect(restoredUser.profileImageUrl, equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));
      expect(restoredUser.isUsingProviderPhoto, isTrue);
    });

    test('toFirestore serializes providerPhotoUrl and photoURL correctly', () {
      final user = AppUser(
        uid: 'user_123',
        username: 'Test User',
        profileImageUrl: AppAvatars.duck,
        providerPhotoUrl: 'https://lh3.googleusercontent.com/a/google_photo.jpg',
      );

      final map = user.toFirestore();
      expect(map['providerPhotoUrl'], equals('https://lh3.googleusercontent.com/a/google_photo.jpg'));
      expect(map['profileImageUrl'], equals(AppAvatars.duck));
      expect(map['photoURL'], equals(AppAvatars.duck));
    });

    test('Unicode initials extraction never throws on emojis or Turkish characters', () {
      String getInitials(String displayName) {
        final cleanName = displayName.trim();
        String initials = '';
        if (cleanName.isNotEmpty) {
          final parts = cleanName.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
          if (parts.length >= 2) {
            final firstChar = parts[0].characters.firstOrNull ?? '';
            final secondChar = parts[1].characters.firstOrNull ?? '';
            initials = '$firstChar$secondChar'.toUpperCase();
          } else if (parts.isNotEmpty) {
            final firstChar = parts[0].characters.firstOrNull ?? '';
            initials = firstChar.toUpperCase();
          }
        }
        return initials;
      }

      expect(getInitials('Ahmet Yılmaz'), equals('AY'));
      expect(getInitials('Şule Çetin'), equals('ŞÇ'));
      expect(getInitials('İlker Öztürk'), equals('İÖ'));
      expect(getInitials('TekIsim'), equals('T'));
      expect(getInitials('🚀 Fırsat'), equals('🚀F'));
      expect(getInitials('   '), equals(''));
      expect(getInitials('👨‍👩‍👧‍👦 Ailesi'), equals('👨‍👩‍👧‍👦A'));
    });

    test('displayName handles fallback gracefully', () {
      final userWithNickname = AppUser(
        uid: '1',
        username: 'user123',
        profileImageUrl: '',
        nickname: 'Fırsat Canavarı',
      );
      expect(userWithNickname.displayName, equals('Fırsat Canavarı'));

      final userWithoutNickname = AppUser(
        uid: '2',
        username: 'firsatci_ali',
        profileImageUrl: '',
      );
      expect(userWithoutNickname.displayName, equals('firsatci_ali'));

      final userEmpty = AppUser(
        uid: '3',
        username: '',
        profileImageUrl: '',
      );
      expect(userEmpty.displayName, equals('Kullanıcı'));
    });
  });
}
