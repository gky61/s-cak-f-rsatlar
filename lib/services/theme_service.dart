import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

void _log(String message) {
  if (kDebugMode) _log(message);
}

enum CardViewMode {
  vertical,
  horizontal,
}

class ThemeService extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  static const String _viewModeKey = 'view_mode';
  static ThemeService? _instance;
  
  ThemeMode _themeMode = ThemeMode.light;
  CardViewMode _viewMode = CardViewMode.vertical;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode => _themeMode == ThemeMode.dark;
  CardViewMode get viewMode => _viewMode;

  // Singleton pattern
  factory ThemeService() {
    _instance ??= ThemeService._internal();
    return _instance!;
  }

  ThemeService._internal() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Load theme mode
      final themeModeString = prefs.getString(_themeModeKey);
      if (themeModeString != null) {
        _themeMode = ThemeMode.values.firstWhere(
          (mode) => mode.toString() == themeModeString,
          orElse: () => ThemeMode.light,
        );
      }

      // Load view mode
      final viewModeString = prefs.getString(_viewModeKey);
      if (viewModeString != null) {
        _viewMode = CardViewMode.values.firstWhere(
          (mode) => mode.toString() == viewModeString,
          orElse: () => CardViewMode.vertical,
        );
      }
      
      notifyListeners();
    } catch (e) {
      _log('Ayarlar yükleme hatası: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    
    _themeMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeModeKey, mode.toString());
    } catch (e) {
      _log('Tema modu kaydetme hatası: $e');
    }
  }

  Future<void> toggleTheme() async {
    final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    await setThemeMode(newMode);
  }

  Future<void> setViewMode(CardViewMode mode) async{
    if (_viewMode == mode) return;
    
    _viewMode = mode;
    notifyListeners();
    
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_viewModeKey, mode.toString());
    } catch (e) {
      _log('Görünüm modu kaydetme hatası: $e');
    }
  }
}
