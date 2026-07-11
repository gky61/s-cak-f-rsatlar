import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:permission_handler/permission_handler.dart';
import '../services/notification_service.dart';
import '../services/auth_service.dart';

class NotificationDebugScreen extends StatefulWidget {
  const NotificationDebugScreen({super.key});

  @override
  State<NotificationDebugScreen> createState() => _NotificationDebugScreenState();
}

class _NotificationDebugScreenState extends State<NotificationDebugScreen> {
  final NotificationService _notificationService = NotificationService();
  final AuthService _authService = AuthService();
  String _log = 'Başlatılıyor...';
  String _fcmToken = 'Yükleniyor...';
  String _permissionStatus = 'Kontrol ediliyor...';

  @override
  void initState() {
    super.initState();
    _loadInfo();
    
    // Servis loglarını dinle
    NotificationService.logStream.stream.listen((message) {
         _addLog('[Service] $message');
    });
  }

  Future<void> _loadInfo() async {
    _addLog('Bilgiler güncelleniyor...');
    
    // 1. FCM Token
    try {
      final token = await FirebaseMessaging.instance.getToken();
      setState(() => _fcmToken = token ?? 'Token yok');
      _addLog('Token alındı: ${token?.substring(0, 10)}...');
    } catch (e) {
      setState(() => _fcmToken = 'Hata: $e');
      _addLog('❌ Token hatası: $e');
    }

    // 2. İzin Durumu (Firebase)
    try {
      final settings = await FirebaseMessaging.instance.getNotificationSettings();
      setState(() => _permissionStatus = settings.authorizationStatus.toString().split('.').last);
      _addLog('İzin durumu: $_permissionStatus');
    } catch (e) {
      _addLog('❌ İzin kontrol hatası: $e');
    }
  }

  void _addLog(String message) {
    if (mounted) {
      setState(() {
        _log = '${DateTime.now().toString().substring(11, 19)}: $message\n$_log';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bildirim Tanı Aracı v2'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _log = '');
              _loadInfo();
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // İzin Kartı
            Card(
              color: _permissionStatus == 'authorized' ? Colors.green[50] : Colors.red[50],
              child: ListTile(
                leading: Icon(
                  _permissionStatus == 'authorized' ? Icons.check_circle : Icons.warning,
                  color: _permissionStatus == 'authorized' ? Colors.green : Colors.red,
                ),
                title: const Text('Bildirim İzni'),
                subtitle: Text(_permissionStatus.toUpperCase()),
                trailing: _permissionStatus != 'authorized' 
                    ? ElevatedButton(
                        child: const Text('İzin İste'),
                        onPressed: () async {
                          _addLog('İzin isteniyor...');
                          await FirebaseMessaging.instance.requestPermission(
                            alert: true,
                            badge: true,
                            sound: true,
                            provisional: false,
                          );
                          // Android 13+ için FirebaseMessaging genellikle yeterlidir
                          _loadInfo();
                        },
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 10),
            
            // Token Kartı
            Card(
              child: ListTile(
                title: const Text('FCM Token'),
                subtitle: Text(_fcmToken, maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _fcmToken));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kopyalandı')));
                  },
                ),
              ),
            ),
            const Divider(),
            const Text('Admin Araçları', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.notifications_active),
              label: const Text('Admin Bildirimlerine Abone Ol (Zorla)'),
              onPressed: () async {
                _addLog('🔄 Admin topic\'ine (admin_deals) abone olunuyor...');
                try {
                  await FirebaseMessaging.instance.subscribeToTopic('admin_deals');
                  _addLog('✅ Abonelik isteği gönderildi.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Abone olundu! 5-10 dk bekleyin.')),
                  );
                } catch (e) {
                  _addLog('❌ Abonelik hatası: $e');
                }
              },
            ),
            const SizedBox(height: 10),
            
            const Text('Test İşlemleri', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.notifications_active),
                  label: const Text('Test Bildirimi'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white),
                  onPressed: () async {
                     _addLog('Test bildirimi gönderiliyor...');
                     try {
                       await _notificationService.testLocalNotification();
                       _addLog('✅ Komut başarılı. Ekrana bakın.');
                     } catch (e) {
                       _addLog('❌ Hata: $e');
                     }
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: const Text('Servisi Yenile'),
                  onPressed: () async {
                    await _notificationService.initializeForUser(
                      userId: _authService.currentUser?.uid,
                      isAdmin: await _authService.isAdmin(),
                    );
                    _addLog(' ✅ Servis başlatıldı.');
                  },
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.search),
                  label: const Text('Son Mesajı Kontrol Et'),
                  onPressed: () async {
                    final userId = _authService.currentUser?.uid;
                    if (userId == null) {
                      _addLog('❌ Giriş yapılmamış.');
                      return;
                    }
                    _addLog('🔍 Son mesaj aranıyor...');
                    try {
                      // Index hatası olmaması için orderBy kaldırdık. 
                      // Sadece son eklenenleri client tarafında süzelim veya rastgele birini alalım.
                      final snapshot = await FirebaseFirestore.instance
                          .collection('messages')
                          .where('receiverId', isEqualTo: userId)
                          .orderBy('createdAt', descending: true)
                          .limit(5)
                          .get();
                      
                      if (snapshot.docs.isNotEmpty) {
                        final docs = snapshot.docs.toList();

                        final data = docs.first.data();
                        _addLog('📄 Mesaj Bulundu (ID: ${docs.first.id}):');
                        _addLog(' - Gönderen: ${data['senderName']}');
                        _addLog(' - Okundu mu: ${data['isRead']}');
                        final time = (data['createdAt'] as Timestamp?)?.toDate();
                        _addLog(' - Zaman: $time');

                        if (data['isRead'] == true) {
                          _addLog('⚠️ Bu mesaj OKUNMUŞ. Yeni mesaj atın.');
                        } else {
                          _addLog('✅ Mesaj OKUNMAMIŞ. Bildirim gelmeliydi.');
                        }
                      } else {
                        _addLog('❌ Hiç mesaj bulunamadı.');
                        _addLog('Emin misiniz? User ID: $userId');
                      }
                    } catch (e) {
                      _addLog('❌ Sorgu hatası: $e');
                      _addLog('Index eksik olabilir. Link varsa tıklayın.');
                    }
                  },
                ),
              ],
            ),
            
            const Divider(),
             const Text('Canlı Loglar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
             Expanded(
               child: Container(
                 width: double.infinity,
                 padding: const EdgeInsets.all(8),
                 decoration: BoxDecoration(
                   color: Colors.black87,
                   borderRadius: BorderRadius.circular(8),
                 ),
                 child: SingleChildScrollView(
                   child: Text(
                     _log, 
                     style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Colors.greenAccent),
                   ),
                 ),
               ),
             ),
          ],
        ),
      ),
    );
  }
}
