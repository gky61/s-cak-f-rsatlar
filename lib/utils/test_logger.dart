import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;

/// Centralized logger for test scraping output to be streamed to UI in real-time.
class LinkPreviewLogger {
  static final StreamController<String> _logController = StreamController<String>.broadcast();
  static Stream<String> get logStream => _logController.stream;

  static final List<String> _logs = [];
  static List<String> get logs => List.unmodifiable(_logs);

  static void clear() {
    _logs.clear();
    _logController.add("--- Logs Cleared ---");
  }

  static void log(String message) {
    if (kDebugMode) {
      print("[LinkPreview] $message");
    }
    final formatted = "[${DateTime.now().toIso8601String().substring(11, 19)}] $message";
    _logs.add(formatted);
    if (_logs.length > 500) {
      _logs.removeAt(0);
    }
    _logController.add(formatted);
  }
}
