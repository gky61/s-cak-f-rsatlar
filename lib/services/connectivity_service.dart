import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;

void _log(String message) {
  if (kDebugMode) print(message);
}

/// İnternet bağlantı durumunu yöneten servis
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  /// Servisi başlat
  Future<void> initialize() async {
    // İlk durumu kontrol et
    await _checkConnection();
    
    // Bağlantı değişikliklerini dinle
    _connectivity.onConnectivityChanged.listen((result) {
      _updateConnectionStatus(result);
    });
  }

  Future<void> _checkConnection() async {
    final result = await _connectivity.checkConnectivity();
    _updateConnectionStatus(result);
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final wasConnected = _isConnected;
    _isConnected = result.isNotEmpty && !result.contains(ConnectivityResult.none);
    
    if (wasConnected != _isConnected) {
      _log('📶 Bağlantı durumu: ${_isConnected ? "Çevrimiçi" : "Çevrimdışı"}');
      _connectionStatusController.add(_isConnected);
    }
  }

  /// Bağlantıyı manuel kontrol et
  Future<bool> checkConnectivity() async {
    await _checkConnection();
    return _isConnected;
  }

  void dispose() {
    _connectionStatusController.close();
  }
}

