import 'package:flutter_test/flutter_test.dart';
import 'package:sicak_firsatlar/services/auth_service.dart';

void main() {
  group('Email Authentication Logic & Validation Tests', () {
    // 1. Email Regex Validation
    test('Email format regex accurately validates standard email formats', () {
      final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

      expect(emailRegex.hasMatch('test@firsatkolik.app'), isTrue);
      expect(emailRegex.hasMatch('user.name@domain.co'), isTrue);
      expect(emailRegex.hasMatch('avci123@gmail.com'), isTrue);
      expect(emailRegex.hasMatch('destek@firsatkolik.com.tr'), isTrue);
      expect(emailRegex.hasMatch('avci+kampanya@firsatkolik.istanbul'), isTrue);

      // Geçersiz formatlar
      expect(emailRegex.hasMatch('gecersiz-email'), isFalse);
      expect(emailRegex.hasMatch('@domain.com'), isFalse);
      expect(emailRegex.hasMatch('test@.com'), isFalse);
      expect(emailRegex.hasMatch('test@domain'), isFalse);
      expect(emailRegex.hasMatch(''), isFalse);
    });

    // 2. Password Length Validation
    test('Password length requirement enforces minimum 6 characters', () {
      bool isValidPassword(String password) => password.length >= 6;

      expect(isValidPassword('12345'), isFalse);
      expect(isValidPassword(''), isFalse);
      expect(isValidPassword('123456'), isTrue);
      expect(isValidPassword('gucluSifre2026!'), isTrue);
    });

    // 3. Username Validation
    test('Username rule enforces minimum 3 characters and trimming', () {
      bool isValidUsername(String username) {
        final clean = username.trim();
        return clean.length >= 3 && clean.length <= 30;
      }

      expect(isValidUsername('ab'), isFalse);
      expect(isValidUsername('  a  '), isFalse);
      expect(isValidUsername('ali'), isTrue);
      expect(isValidUsername('  firsat_avcisi  '), isTrue);
      expect(isValidUsername('a' * 31), isFalse);
    });

    // 4. AuthException Error Formatting
    test('AuthException retains clear message string', () {
      final ex = AuthException('E-posta adresi veya şifre hatalı.');
      expect(ex.message, 'E-posta adresi veya şifre hatalı.');
      expect(ex.toString(), 'E-posta adresi veya şifre hatalı.');
    });
  });
}
