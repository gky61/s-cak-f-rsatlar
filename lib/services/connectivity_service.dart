import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'system_log_service.dart';

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
  StreamSubscription<List<ConnectivityResult>>? _subscription;
  Timer? _pendingOfflineTimer;
  bool _initialized = false;
  
  bool _isConnected = true;
  bool get isConnected => _isConnected;
  
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;

  /// Servisi başlat
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    // İlk durumu kontrol et
    await _checkConnection();
    
    // Bağlantı değişikliklerini dinle
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateConnectionStatus,
      onError: (e, st) {
        _log('⚠️ [Connectivity] Dinleme hatası: $e');
        SystemLogService.instance.logError(
          category: 'network',
          errorType: 'connectivity_stream_error',
          message: 'Bağlantı dinleyicisinde platform kanal hatası: $e',
          stack: st,
          severity: SystemErrorSeverity.warning,
        );
      },
    );
  }

  Future<void> _checkConnection() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectionStatus(result);
    } catch (e, st) {
      _log('⚠️ [Connectivity] Kontrol hatası: $e');
      _isConnected = true; // Fallback: iyimser varsayım
      SystemLogService.instance.logError(
        category: 'network',
        errorType: 'connectivity_check_error',
        message: 'Bağlantı kontrolünde hata: $e',
        stack: st,
        severity: SystemErrorSeverity.warning,
      );
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> result) {
    final hasActiveNetwork = result.isNotEmpty && !result.contains(ConnectivityResult.none);

    if (hasActiveNetwork) {
      // 1. Ağ bağlantısı tespit edildi:
      // Olası cold-start veya ağ geçişi sırasındaki bekleyen sahte çevrimdışı alarmını iptal et
      _pendingOfflineTimer?.cancel();
      _pendingOfflineTimer = null;

      final wasConnected = _isConnected;
      _isConnected = true;

      if (!wasConnected) {
        _log('📶 Bağlantı durumu: Çevrimiçi');
        if (!_connectionStatusController.isClosed) {
          _connectionStatusController.add(true);
        }
      }
    } else {
      // 2. Ağ yok (none) bildirildi:
      // Cold-start başlangıç ısınması (Android NetworkCapabilities warmup lag) veya anlık baz istasyonu/Wi-Fi
      // geçişlerindeki sahte alarmları önlemek için 1500ms'lik Grace Period işletilir.
      if (_pendingOfflineTimer != null && _pendingOfflineTimer!.isActive) {
        return;
      }

      Timer? timer;
      timer = Timer(const Duration(milliseconds: 1500), () async {
        if (_pendingOfflineTimer != timer) return;
        _pendingOfflineTimer = null;
        try {
          // 1500ms sonra son durumu teyit et
          final recheck = await _connectivity.checkConnectivity();
          if (_pendingOfflineTimer != null) return;
          final stillNoNetwork = recheck.isEmpty || recheck.contains(ConnectivityResult.none);

          if (stillNoNetwork) {
            final wasConnected = _isConnected;
            _isConnected = false;

            if (wasConnected) {
              _log('📶 Bağlantı durumu: Doğrulanmış Çevrimdışı');
              if (!_connectionStatusController.isClosed) {
                _connectionStatusController.add(false);
              }
            }
          }
        } catch (_) {
          // Hata durumunda durum değiştirme
        }
      });
      _pendingOfflineTimer = timer;
    }
  }

  /// Bağlantıyı manuel kontrol et
  Future<bool> checkConnectivity() async {
    await _checkConnection();
    return _isConnected;
  }

  void dispose() {
    _pendingOfflineTimer?.cancel();
    _pendingOfflineTimer = null;
    _subscription?.cancel();
    _subscription = null;
    _initialized = false;
    if (!_connectionStatusController.isClosed) {
      _connectionStatusController.close();
    }
  }
}






