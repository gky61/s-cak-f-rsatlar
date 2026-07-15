import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import '../models/deal.dart';
import '../models/category.dart';
import '../services/firestore_service.dart';
import '../services/link_preview_service.dart';
import '../services/category_detection_service.dart';
import '../services/ai_service.dart';
import '../utils/test_logger.dart';
import '../firebase_options.dart';

enum TestMode { mobile, bot }

class TestAutomationWidget extends StatefulWidget {
  const TestAutomationWidget({super.key});

  @override
  State<TestAutomationWidget> createState() => _TestAutomationWidgetState();
}

class _TestAutomationWidgetState extends State<TestAutomationWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  final LinkPreviewService _linkPreviewService = LinkPreviewService();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _customTextController = TextEditingController();

  TestMode _selectedMode = TestMode.mobile;
  bool _isRunning = false;

  // Real-time terminal logs list
  final List<Map<String, dynamic>> _terminalLogs = [];
  final ScrollController _terminalScrollController = ScrollController();
  StreamSubscription<String>? _localLogSubscription;
  Timer? _botLogPollTimer;
  DateTime? _testStartTime;

  // Selection states for batch operations
  final Set<String> _selectedDealIds = {};
  List<Deal> _currentTestDeals = [];

  // Determine Bot URL based on environment flavor
  String get _defaultBotUrl {
    return isProductionFlavor
        ? 'https://telegram-bot-228657473310.us-central1.run.app'
        : 'https://telegram-bot-560592268193.us-central1.run.app';
  }

  // Get active Bot URL (allows dynamically loading from Firestore settings/telegramBot if available)
  Future<String> _getBotUrl() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('settings').doc('telegramBot').get();
      if (doc.exists && doc.data()?.containsKey('botUrl') == true) {
        final overrideUrl = doc.data()?['botUrl'] as String;
        if (overrideUrl.isNotEmpty) return overrideUrl;
      }
    } catch (_) {}
    return _defaultBotUrl;
  }

  @override
  void initState() {
    super.initState();
    // Start listening to local log stream by default (so any system preview logs show up)
    _subscribeToLocalLogs();
  }

  @override
  void dispose() {
    _localLogSubscription?.cancel();
    _botLogPollTimer?.cancel();
    _urlController.dispose();
    _customTextController.dispose();
    _terminalScrollController.dispose();
    super.dispose();
  }

  void _subscribeToLocalLogs() {
    _localLogSubscription?.cancel();
    _localLogSubscription = LinkPreviewLogger.logStream.listen((logMessage) {
      if (!mounted) return;
      setState(() {
        String level = 'info';
        if (logMessage.toLowerCase().contains('error') || logMessage.toLowerCase().contains('hata') || logMessage.contains('❌')) {
          level = 'error';
        } else if (logMessage.toLowerCase().contains('warn') || logMessage.toLowerCase().contains('uyarı') || logMessage.contains('⚠️')) {
          level = 'warn';
        } else if (logMessage.contains('✅') || logMessage.contains('🎉') || logMessage.toLowerCase().contains('başarılı')) {
          level = 'success';
        }
        _terminalLogs.add({
          'timestamp': DateTime.now().toIso8601String(),
          'level': level,
          'message': logMessage,
        });
      });
      _scrollToTerminalBottom();
    });
  }

  void _scrollToTerminalBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_terminalScrollController.hasClients) {
        _terminalScrollController.animateTo(
          _terminalScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _clearTerminal() {
    setState(() {
      _terminalLogs.clear();
    });
    LinkPreviewLogger.clear();
  }

  void _addTerminalLog(String message, {String level = 'info'}) {
    if (!mounted) return;
    setState(() {
      _terminalLogs.add({
        'timestamp': DateTime.now().toIso8601String(),
        'level': level,
        'message': message,
      });
    });
    _scrollToTerminalBottom();
  }

  // --- MOBIL (DART) SCRAPING FLOW ---
  Future<void> _runMobileScrape(String url) async {
    _addTerminalLog("⚡ Mobil (Dart) Scraping başlatılıyor...", level: 'info');
    _addTerminalLog("🔗 URL: $url", level: 'info');

    try {
      // 1. Fetch metadata & run scrapers
      _addTerminalLog("🔍 Sayfa içeriği ve metadata yükleniyor...", level: 'info');
      final preview = await _linkPreviewService.fetchMetadata(url).timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          _addTerminalLog("⏱️ Scraping zaman aşımına uğradı (15s)", level: 'error');
          throw TimeoutException("LinkPreview timeout");
        },
      );

      if (preview == null) {
        _addTerminalLog("❌ Sayfa kazınamadı veya boş veri döndü.", level: 'error');
        return;
      }

      _addTerminalLog("🎉 Temel kazıma işlemi tamamlandı. Değerler:", level: 'success');
      _addTerminalLog("   ↳ Başlık: ${preview.title ?? 'BULUNAMADI'}", level: 'info');
      _addTerminalLog("   ↳ Fiyat: ${preview.price ?? 'BULUNAMADI'} TL", level: 'info');
      _addTerminalLog("   ↳ Mağaza: ${preview.provider ?? 'BULUNAMADI'}", level: 'info');
      _addTerminalLog("   ↳ Görsel URL: ${preview.imageUrl ?? 'BULUNAMADI'}", level: 'info');

      // 2. Category Detection
      String category = 'diger';
      String? subCategory;
      if (preview.breadcrumbs != null && preview.breadcrumbs!.isNotEmpty) {
        final joined = preview.breadcrumbs!.join(' ');
        final textToClassify = '$joined ${preview.title ?? ""}';
        _addTerminalLog("🔍 Kategori sınıflandırması yapılıyor: '$textToClassify'", level: 'info');
        final catResult = CategoryDetectionService.detectCategory(textToClassify);
        if (catResult != null) {
          category = catResult['categoryId']!;
          subCategory = catResult['subCategory'];
          _addTerminalLog("✅ Kategori tespit edildi: $category -> $subCategory", level: 'success');
        }
      } else {
        _addTerminalLog("⚠️ Sayfada breadcrumb (kırıntı) bulunamadı, başlık üzerinden kategori taranıyor...", level: 'warn');
        final catResult = CategoryDetectionService.detectCategory(preview.title ?? "");
        if (catResult != null) {
          category = catResult['categoryId']!;
          subCategory = catResult['subCategory'];
          _addTerminalLog("✅ Kategori tespit edildi: $category -> $subCategory", level: 'success');
        }
      }

      // 3. Gemini AI Analysis
      _addTerminalLog("🤖 Gemini AI analizi başlatılıyor...", level: 'info');
      final aiResult = await AIService.analyzeProduct(
        url: url,
        title: preview.title ?? "",
        description: preview.description ?? "",
      );

      String finalTitle = preview.title ?? "Fırsat Ürünü";
      double finalPrice = preview.price ?? 0.0;
      String finalStore = preview.provider ?? "Diğer";

      if (aiResult['success'] == true) {
        _addTerminalLog("✅ Gemini AI analizi başarılı!", level: 'success');
        if (aiResult.containsKey('title') && aiResult['title'] != null) {
          finalTitle = aiResult['title'];
          _addTerminalLog("   ↳ AI Başlık: '$finalTitle'", level: 'info');
        }
        if (aiResult.containsKey('price') && aiResult['price'] != null) {
          finalPrice = double.tryParse(aiResult['price'].toString()) ?? finalPrice;
          _addTerminalLog("   ↳ AI Fiyat: $finalPrice TL", level: 'info');
        }
        if (aiResult.containsKey('store') && aiResult['store'] != null) {
          finalStore = aiResult['store'];
          _addTerminalLog("   ↳ AI Mağaza: $finalStore", level: 'info');
        }
        if (aiResult.containsKey('category') && aiResult['category'] != null) {
          category = aiResult['category'];
          subCategory = null; // AI root kategori döner
          _addTerminalLog("   ↳ AI Kategori: $category", level: 'info');
        }
      } else {
        _addTerminalLog("⚠️ Gemini AI analizi başarısız oldu (Proxy hatası veya limit). Scraper verileri kullanılacak.", level: 'warn');
      }

      // 4. Save test deal to Firestore
      _addTerminalLog("💾 Test verisi Firestore'a kaydediliyor...", level: 'info');
      final deal = Deal(
        id: '',
        title: finalTitle,
        description: preview.description ?? 'Mobil test açıklaması',
        price: finalPrice,
        originalPrice: finalPrice > 0 ? finalPrice * 1.2 : 0.0,
        discountRate: finalPrice > 0 ? 20 : 0,
        store: finalStore,
        category: category,
        subCategory: subCategory,
        link: url,
        imageUrl: preview.imageUrl ?? '',
        hotVotes: 0,
        coldVotes: 0,
        commentCount: 0,
        postedBy: 'admin_test_mobil',
        createdAt: DateTime.now(),
        isEditorPick: false,
        isApproved: false,
        isUserSubmitted: false,
        isTest: true,
      );

      final docRef = await FirebaseFirestore.instance.collection('deals').add(deal.toFirestore());
      _addTerminalLog("🎉 MOBİL TEST BAŞARIYLA TAMAMLANDI! Belge ID: ${docRef.id}", level: 'success');
    } catch (e) {
      _addTerminalLog("❌ Hata oluştu: $e", level: 'error');
    }
  }

  // --- BOT (GCP / CLOUD RUN) SIMULATION FLOW ---
  Future<void> _runBotScrape(String url, String customText) async {
    _addTerminalLog("📡 Bot (Google Cloud Run) Testi başlatılıyor...", level: 'info');
    _testStartTime = DateTime.now();

    final botBaseUrl = await _getBotUrl();
    _addTerminalLog("🤖 Deployed Bot URL: $botBaseUrl", level: 'info');

    // Start polling logs in background
    _startBotLogPolling(botBaseUrl);

    try {
      String simulateEndpoint = '$botBaseUrl/simulate?url=${Uri.encodeComponent(url)}';
      if (customText.isNotEmpty) {
        simulateEndpoint += '&text=${Uri.encodeComponent(customText)}';
      }

      _addTerminalLog("⏱️ HTTP /simulate isteği gönderiliyor (İşlem 5-25 saniye sürebilir)...", level: 'info');
      
      final response = await http.get(Uri.parse(simulateEndpoint)).timeout(
        const Duration(seconds: 45),
        onTimeout: () {
          throw TimeoutException("Bot simulation timed out (45s)");
        },
      );

      final result = jsonDecode(response.body);

      // Stop log poll timer after a small delay to catch remaining logs
      Future.delayed(const Duration(seconds: 2), () {
        _botLogPollTimer?.cancel();
      });

      if (response.statusCode == 200 && result['success'] == true) {
        _addTerminalLog("🎉 BOT TESTİ BAŞARIYLA TAMAMLANDI!", level: 'success');
        final data = result['data'] ?? {};
        _addTerminalLog("📌 Belge ID:    ${result['docId']}", level: 'success');
        _addTerminalLog("🏢 Mağaza:      ${data['store'] ?? 'YOK'}", level: 'info');
        _addTerminalLog("🏷️ Başlık:      \"${data['title'] ?? 'YOK'}\"", level: 'info');
        _addTerminalLog("💰 Fiyat:       ${data['price'] ?? 'YOK'} TL", level: 'info');
        _addTerminalLog("📁 Kategori:    ${data['category'] ?? 'YOK'}", level: 'info');
      } else {
        _addTerminalLog("❌ BOT TESTİ BAŞARISIZ OLDU!", level: 'error');
        if (result != null && result['error'] != null) {
          _addTerminalLog("Detay: ${result['error']}", level: 'error');
        } else {
          _addTerminalLog("Status Code: ${response.statusCode}, Body: ${response.body}", level: 'error');
        }
      }
    } catch (e) {
      _botLogPollTimer?.cancel();
      _addTerminalLog("❌ Bot test hatası: $e", level: 'error');
    }
  }

  void _startBotLogPolling(String botBaseUrl) {
    _botLogPollTimer?.cancel();
    final pollStartTime = _testStartTime ?? DateTime.now();

    // Poll logs every 2 seconds
    _botLogPollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      try {
        final logsEndpoint = '$botBaseUrl/bot-logs?startTime=${Uri.encodeComponent(pollStartTime.toIso8601String())}&limit=50';
        final response = await http.get(Uri.parse(logsEndpoint));
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true && data['logs'] != null) {
            final List<dynamic> logs = data['logs'];
            
            if (!mounted) return;
            setState(() {
              // Add only new logs (by comparing timestamps and message contents)
              for (final log in logs) {
                final timestamp = log['timestamp'] as String;
                final level = log['level'] as String;
                final message = log['message'] as String;

                // Check if already in local list
                final exists = _terminalLogs.any((existingLog) =>
                    existingLog['timestamp'] == timestamp &&
                    existingLog['message'] == message);

                if (!exists) {
                  _terminalLogs.add({
                    'timestamp': timestamp,
                    'level': level,
                    'message': '[Bot Server] $message',
                  });
                }
              }
            });
            _scrollToTerminalBottom();
          }
        }
      } catch (e) {
        // Silently ignore poll errors to keep flow uninterrupted
      }
    });
  }

  // --- ACTIONS ---
  Future<void> _startTest() async {
    final url = _urlController.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen geçerli bir ürün linki girin!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isRunning = true;
    });

    _clearTerminal();

    if (_selectedMode == TestMode.mobile) {
      await _runMobileScrape(url);
    } else {
      await _runBotScrape(url, _customTextController.text.trim());
    }

    setState(() {
      _isRunning = false;
    });
  }

  Future<void> _deleteDeal(String id) async {
    final success = await _firestoreService.deleteDeal(id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Test fırsatı başarıyla silindi.' : 'Fırsat silinemedi!'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteSelectedDeals() async {
    if (_selectedDealIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Toplu Silme Onayı'),
        content: Text('Seçilen ${_selectedDealIds.length} test fırsatını tamamen silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRunning = true);
    final success = await _firestoreService.deleteDealsBatch(_selectedDealIds.toList());
    setState(() {
      _isRunning = false;
      if (success) {
        _selectedDealIds.clear();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Seçilen test verileri başarıyla temizlendi.' : 'Toplu silme hatası!'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _deleteAllTestDeals() async {
    if (_currentTestDeals.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Test Verilerini Sil'),
        content: Text('Sistemdeki tüm test fırsatlarını (${_currentTestDeals.length} adet) tamamen temizlemek istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Tümünü Temizle'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isRunning = true);
    final allIds = _currentTestDeals.map((d) => d.id).toList();
    final success = await _firestoreService.deleteDealsBatch(allIds);
    setState(() {
      _isRunning = false;
      if (success) {
        _selectedDealIds.clear();
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Tüm test verileri başarıyla silindi.' : 'Temizleme hatası!'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  // --- UI BUILDING HELPERS ---
  Color _getLogColor(String level) {
    switch (level) {
      case 'error':
        return Colors.redAccent;
      case 'warn':
        return Colors.amberAccent;
      case 'success':
        return Colors.lightGreenAccent;
      default:
        return Colors.cyanAccent;
    }
  }

  String _getCategoryDisplayName(String categoryIdOrName) {
    final normalizedValue = categoryIdOrName.toLowerCase().trim();
    for (final cat in Category.categories) {
      if (cat.id.toLowerCase() == normalizedValue && cat.id != 'tumu') {
        return cat.name;
      }
    }
    return categoryIdOrName;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // LEFT PANEL: Controls and Terminal Log Viewer (Width: 60%)
          Expanded(
            flex: 6,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Controls Header Card
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Test Parametreleri',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              // Environment Indicator Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: isProductionFlavor ? Colors.red[100] : Colors.green[100],
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isProductionFlavor ? Colors.red : Colors.green,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  isProductionFlavor ? 'PROD ORTAMI' : 'DEV ORTAMI',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: isProductionFlavor ? Colors.red[800] : Colors.green[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // URL Input
                          TextField(
                            controller: _urlController,
                            decoration: InputDecoration(
                              labelText: 'Ürün Detay Linki (Scraping URL)',
                              hintText: 'https://www.trendyol.com/... veya https://ty.gl/...',
                              prefixIcon: const Icon(Icons.link),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Scraper Mode Selector
                          Row(
                            children: [
                              const Text('Kazıma Yöntemi: ', style: TextStyle(fontWeight: FontWeight.bold)),
                              const SizedBox(width: 12),
                              ChoiceChip(
                                label: const Row(
                                  children: [
                                    Icon(Icons.phone_android, size: 16),
                                    SizedBox(width: 6),
                                    Text('Mobil (Dart Scraper)'),
                                  ],
                                ),
                                selected: _selectedMode == TestMode.mobile,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedMode = TestMode.mobile);
                                  }
                                },
                              ),
                              const SizedBox(width: 12),
                              ChoiceChip(
                                label: const Row(
                                  children: [
                                    Icon(Icons.smart_toy, size: 16),
                                    SizedBox(width: 6),
                                    Text('Bot (GCP / JS)'),
                                  ],
                                ),
                                selected: _selectedMode == TestMode.bot,
                                onSelected: (val) {
                                  if (val) {
                                    setState(() => _selectedMode = TestMode.bot);
                                  }
                                },
                              ),
                            ],
                          ),
                          // Custom text field only for Bot Mode
                          if (_selectedMode == TestMode.bot) ...[
                            const SizedBox(height: 12),
                            TextField(
                              controller: _customTextController,
                              decoration: InputDecoration(
                                labelText: 'Simüle Telegram Mesaj Metni (Opsiyonel)',
                                hintText: 'Üründe sepette %20 indirim var! https://ty.gl/...',
                                prefixIcon: const Icon(Icons.chat_bubble_outline),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              // Run Test Button
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _isRunning ? null : _startTest,
                                  icon: _isRunning
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                        )
                                      : const Icon(Icons.play_arrow),
                                  label: Text(_isRunning ? 'İşlem Sürüyor...' : 'Kazı ve Test Et'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: primaryColor,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Clear Terminal Button
                              OutlinedButton.icon(
                                onPressed: _clearTerminal,
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('Terminali Temizle'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // 2. Terminal Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Konsol / Scraping Log Çıktıları',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      if (_isRunning)
                        const Row(
                          children: [
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(width: 8),
                            Text('Canlı dinleniyor...', style: TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )
                    ],
                  ),
                  const SizedBox(height: 8),
                  // 3. Monospace Terminal Console Widget
                  Expanded(
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E1E2E), // Monokai-ish dark purple/blue
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.15),
                            blurRadius: 6,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _terminalLogs.isEmpty
                            ? const Center(
                                child: Text(
                                  'Konsol boş. Yukarıdan "Kazı ve Test Et" butonuna basarak test akışını başlatabilirsiniz.',
                                  style: TextStyle(
                                    fontFamily: 'Courier',
                                    color: Colors.grey,
                                    fontSize: 13,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                controller: _terminalScrollController,
                                padding: EdgeInsets.zero,
                                itemCount: _terminalLogs.length,
                                itemBuilder: (context, index) {
                                  final log = _terminalLogs[index];
                                  final timestamp = log['timestamp'] as String;
                                  final level = log['level'] as String;
                                  final message = log['message'] as String;

                                  final displayTime = timestamp.length > 19
                                      ? timestamp.substring(11, 19)
                                      : timestamp;

                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2.0),
                                    child: Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // Timestamp
                                        Text(
                                          '[$displayTime] ',
                                          style: const TextStyle(
                                            fontFamily: 'Courier',
                                            color: Colors.grey,
                                            fontSize: 12,
                                          ),
                                        ),
                                        // Level / Message payload
                                        Expanded(
                                          child: Text(
                                            message,
                                            style: TextStyle(
                                              fontFamily: 'Courier',
                                              color: _getLogColor(level),
                                              fontSize: 13,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // RIGHT PANEL: Test Data Manager List (Width: 40%)
          Expanded(
            flex: 4,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
              ),
              child: StreamBuilder<List<Deal>>(
                stream: _firestoreService.getTestDealsStream(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final deals = snapshot.data ?? [];
                  _currentTestDeals = deals;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // List Title & Stats Header
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Test Fırsatları',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Toplam: ${deals.length} test datası',
                                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                                ),
                              ],
                            ),
                            // Quick Batch Delete Actions
                            if (deals.isNotEmpty)
                              IconButton(
                                tooltip: 'Tümünü Temizle',
                                icon: const Icon(Icons.delete_forever, color: Colors.red),
                                onPressed: _deleteAllTestDeals,
                              )
                          ],
                        ),
                      ),
                      const Divider(height: 1),
                      // Batch Control Strip (Select All & Delete Selected)
                      if (deals.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selectedDealIds.length == deals.length && deals.isNotEmpty,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedDealIds.addAll(deals.map((d) => d.id));
                                    } else {
                                      _selectedDealIds.clear();
                                    }
                                  });
                                },
                              ),
                              const Text('Tümünü Seç', style: TextStyle(fontSize: 13)),
                              const Spacer(),
                              if (_selectedDealIds.isNotEmpty)
                                ElevatedButton.icon(
                                  onPressed: _deleteSelectedDeals,
                                  icon: const Icon(Icons.delete, size: 16),
                                  label: Text('Seçilenleri Sil (${_selectedDealIds.length})'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                    textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      const Divider(height: 1),
                      // Active Test Deals List
                      Expanded(
                        child: deals.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.dashboard_customize_outlined, size: 48, color: Colors.grey[300]),
                                    const SizedBox(height: 12),
                                    const Text(
                                      'Kayıtlı test verisi yok.',
                                      style: TextStyle(color: Colors.grey),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.all(12),
                                itemCount: deals.length,
                                itemBuilder: (context, index) {
                                  final deal = deals[index];
                                  final currencyFormat = DynamicCurrencyFormatter();

                                  return Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(8.0),
                                      child: Row(
                                        children: [
                                          // Multi-select Checkbox
                                          Checkbox(
                                            value: _selectedDealIds.contains(deal.id),
                                            onChanged: (val) {
                                              setState(() {
                                                if (val == true) {
                                                  _selectedDealIds.add(deal.id);
                                                } else {
                                                  _selectedDealIds.remove(deal.id);
                                                }
                                              });
                                            },
                                          ),
                                          // Product Thumbnail
                                          ClipRRect(
                                            borderRadius: BorderRadius.circular(6),
                                            child: deal.imageUrl.isNotEmpty
                                                ? CachedNetworkImage(
                                                    imageUrl: deal.imageUrl,
                                                    width: 48,
                                                    height: 48,
                                                    fit: BoxFit.cover,
                                                    errorWidget: (_, __, ___) => Container(width: 48, height: 48, color: Colors.grey[200]),
                                                  )
                                                : Container(
                                                    width: 48,
                                                    height: 48,
                                                    color: Colors.grey[200],
                                                    child: const Icon(Icons.image_not_supported, size: 18),
                                                  ),
                                          ),
                                          const SizedBox(width: 12),
                                          // Details Text
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  deal.title,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  '${deal.store} • ${_getCategoryDisplayName(deal.category)}',
                                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                                ),
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Text(
                                                      currencyFormat.format(deal.price),
                                                      style: TextStyle(
                                                        fontWeight: FontWeight.w900,
                                                        fontSize: 12,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    // Source identifier tag
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                                      decoration: BoxDecoration(
                                                        color: deal.postedBy == 'admin_test_mobil'
                                                            ? Colors.blue[50]
                                                            : Colors.orange[50],
                                                        borderRadius: BorderRadius.circular(4),
                                                      ),
                                                      child: Text(
                                                        deal.postedBy == 'admin_test_mobil' ? 'MOBİL' : 'BOT',
                                                        style: TextStyle(
                                                          fontSize: 9,
                                                          fontWeight: FontWeight.bold,
                                                          color: deal.postedBy == 'admin_test_mobil'
                                                              ? Colors.blue[800]
                                                              : Colors.orange[800],
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          ),
                                          // Action Delete Button
                                          IconButton(
                                            icon: const Icon(Icons.delete, color: Colors.redAccent, size: 20),
                                            onPressed: () => _deleteDeal(deal.id),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
