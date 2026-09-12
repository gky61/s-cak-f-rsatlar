import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../models/report.dart';
import '../models/admin_moderation_alarm.dart';
import '../services/report_service.dart';
import '../services/firestore_service.dart';
import '../services/user_service.dart';
import '../services/comment_service.dart';
import '../services/message_service.dart';
import '../screens/deal_detail_screen.dart';
import '../screens/profile_screen.dart';
import 'skeletons/notification_list_skeleton.dart';

class AdminReportsList extends StatefulWidget {
  final String status; // 'pending' veya 'all'

  const AdminReportsList({super.key, this.status = 'all'});

  @override
  State<AdminReportsList> createState() => _AdminReportsListState();
}

class _AdminReportsListState extends State<AdminReportsList> with SingleTickerProviderStateMixin {
  final ReportService _reportService = ReportService();
  final FirestoreService _firestoreService = FirestoreService();
  final UserService _userService = UserService();
  final CommentService _commentService = CommentService();
  final MessageService _messageService = MessageService();

  late TabController _segmentTabController;

  // Tab 1 (Şikayetler) filtreleme durumları
  String _complaintsSearchQuery = '';
  String _complaintsStatusFilter = 'all'; // 'all', 'pending', 'action_taken', 'dismissed'
  String _complaintsTypeFilter = 'all';   // 'all', 'deal', 'comment', 'user', 'message'
  final TextEditingController _complaintsSearchController = TextEditingController();

  // Tab 2 (Otomatik Alarmlar) filtreleme durumları
  String _autoModSearchQuery = '';
  String _autoModFilter = 'all'; // 'all', 'unread', 'deals', 'comments'
  final TextEditingController _autoModSearchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _segmentTabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _segmentTabController.dispose();
    _complaintsSearchController.dispose();
    _autoModSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Column(
      children: [
        // Üst Segmentli Sekme Seçici
        Container(
          color: theme.colorScheme.surface,
          child: TabBar(
            controller: _segmentTabController,
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            unselectedLabelColor: Colors.grey,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            unselectedLabelStyle: const TextStyle(fontSize: 13),
            tabs: const [
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.report_problem_outlined, size: 18),
                    SizedBox(width: 6),
                    Text('Kullanıcı Şikayetleri'),
                  ],
                ),
              ),
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.security, size: 18),
                    SizedBox(width: 6),
                    Text('Otomatik Alarmlar'),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Sekme İçerikleri
        Expanded(
          child: TabBarView(
            controller: _segmentTabController,
            children: [
              _buildComplaintsTab(),
              _buildAutoModTab(),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================================================
  // 📢 SEKME 1: KULLANICI ŞİKAYETLERİ (reports)
  // ============================================================================

  Widget _buildComplaintsTab() {
    return StreamBuilder<List<Report>>(
      stream: _reportService.getRecentReportsStream(limit: 100),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Şikayetler yüklenirken hata oluştu.', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Hata detayı: ${snapshot.error}', style: const TextStyle(fontSize: 12, color: Colors.red), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => setState(() {}), child: const Text('Tekrar Dene')),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const NotificationListSkeleton();
        }

        final allReports = snapshot.data ?? [];
        final totalCount = allReports.length;
        final pendingCount = allReports.where((r) => r.status == 'pending').length;
        final actionCount = allReports.where((r) => r.status == 'action_taken').length;
        final dismissedCount = allReports.where((r) => r.status == 'dismissed').length;

        // Filtreleme
        final filteredReports = allReports.filterReports(
          searchQuery: _complaintsSearchQuery,
          statusFilter: _complaintsStatusFilter,
          typeFilter: _complaintsTypeFilter,
        );

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // 1. İstatistik Sayaçları Kartları
              _buildComplaintsStats(
                total: totalCount,
                pending: pendingCount,
                action: actionCount,
                dismissed: dismissedCount,
              ),
              const SizedBox(height: 12),

              // 2. Arama ve Filtre Kontrolleri
              _buildComplaintsFilterBar(),
              const SizedBox(height: 12),

              // 3. Şikayet Listesi
              if (filteredReports.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.report_off_outlined, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        _complaintsSearchQuery.isNotEmpty || _complaintsStatusFilter != 'all' || _complaintsTypeFilter != 'all'
                            ? 'Kriterlere uygun şikayet kaydı bulunamadı'
                            : 'Henüz bildirilmiş şikayet yok',
                        style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              else
                ...filteredReports.map((report) => _buildComplaintCard(report)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildComplaintsStats({required int total, required int pending, required int action, required int dismissed}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Row(
          children: [
            _buildStatItem('Toplam', total.toString(), Colors.blue, Icons.report),
            const SizedBox(width: 8),
            _buildStatItem('Bekleyen', pending.toString(), Colors.amber[800]!, Icons.pending_actions),
            const SizedBox(width: 8),
            _buildStatItem('İşlem', action.toString(), Colors.green, Icons.check_circle),
            const SizedBox(width: 8),
            _buildStatItem('Yoksayılan', dismissed.toString(), Colors.grey[600]!, Icons.cancel),
          ],
        );
      },
    );
  }

  Widget _buildStatItem(String label, String count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 13, color: color),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              count,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildComplaintsFilterBar() {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Arama Kutusu
            TextField(
              controller: _complaintsSearchController,
              decoration: InputDecoration(
                hintText: 'Şikayet nedeni, içerik, ID veya kullanıcı ara...',
                hintStyle: const TextStyle(fontSize: 12),
                prefixIcon: const Icon(Icons.search, size: 18),
                suffixIcon: _complaintsSearchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _complaintsSearchController.clear();
                          setState(() => _complaintsSearchQuery = '');
                        },
                      )
                    : null,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              ),
              style: const TextStyle(fontSize: 12),
              onChanged: (val) => setState(() => _complaintsSearchQuery = val.trim().toLowerCase()),
            ),
            const SizedBox(height: 10),

            // Durum Filtreleri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Durum: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  _buildFilterChip('Tümü', 'all', _complaintsStatusFilter, (v) => setState(() => _complaintsStatusFilter = v)),
                  _buildFilterChip('🟡 Bekleyenler', 'pending', _complaintsStatusFilter, (v) => setState(() => _complaintsStatusFilter = v)),
                  _buildFilterChip('🟢 İşlem Yapılanlar', 'action_taken', _complaintsStatusFilter, (v) => setState(() => _complaintsStatusFilter = v)),
                  _buildFilterChip('⚪ Yoksayılanlar', 'dismissed', _complaintsStatusFilter, (v) => setState(() => _complaintsStatusFilter = v)),
                ],
              ),
            ),
            const SizedBox(height: 6),

            // Tür Filtreleri
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Tür: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                  _buildFilterChip('Tümü', 'all', _complaintsTypeFilter, (v) => setState(() => _complaintsTypeFilter = v)),
                  _buildFilterChip('🏷️ Fırsatlar', 'deal', _complaintsTypeFilter, (v) => setState(() => _complaintsTypeFilter = v)),
                  _buildFilterChip('💬 Yorumlar', 'comment', _complaintsTypeFilter, (v) => setState(() => _complaintsTypeFilter = v)),
                  _buildFilterChip('👤 Kullanıcılar', 'user', _complaintsTypeFilter, (v) => setState(() => _complaintsTypeFilter = v)),
                  _buildFilterChip('✉️ Mesajlar', 'message', _complaintsTypeFilter, (v) => setState(() => _complaintsTypeFilter = v)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, String currentValue, ValueChanged<String> onSelected) {
    final isSelected = value == currentValue;
    final primary = Theme.of(context).colorScheme.primary;

    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label, style: TextStyle(fontSize: 11, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, color: isSelected ? Colors.white : null)),
        selected: isSelected,
        selectedColor: primary,
        showCheckmark: false,
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        onSelected: (selected) {
          if (selected) onSelected(value);
        },
      ),
    );
  }

  Widget _buildComplaintCard(Report report) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isPending = report.status == 'pending';

    IconData typeIcon;
    Color typeColor;
    String typeLabel;

    switch (report.type) {
      case 'deal':
        typeIcon = Icons.local_offer;
        typeColor = Colors.orange;
        typeLabel = 'Fırsat';
        break;
      case 'comment':
        typeIcon = Icons.comment;
        typeColor = Colors.blue;
        typeLabel = 'Yorum';
        break;
      case 'user':
        typeIcon = Icons.person;
        typeColor = Colors.purple;
        typeLabel = 'Kullanıcı';
        break;
      case 'message':
        typeIcon = Icons.chat_bubble_outline_rounded;
        typeColor = Colors.teal;
        typeLabel = 'Mesaj';
        break;
      default:
        typeIcon = Icons.report;
        typeColor = Colors.grey;
        typeLabel = 'Diğer';
    }

    Widget statusBadge;
    if (report.status == 'pending') {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.amber.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: const Text('Bekliyor', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 10)),
      );
    } else if (report.status == 'action_taken') {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: const Text('İşlem Yapıldı', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
      );
    } else {
      statusBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
        child: const Text('Yoksayıldı', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)),
      );
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık Çubuğu
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Icon(typeIcon, size: 16, color: typeColor),
                const SizedBox(width: 8),
                Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 12)),
                const Spacer(),
                statusBadge,
                const SizedBox(width: 8),
                Text(dateFormat.format(report.createdAt), style: TextStyle(color: Colors.grey[600], fontSize: 11)),
              ],
            ),
          ),

          // İçerik Detayı
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Şikayet Nedeni
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '⚠️ ${report.reason}',
                        style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Açıklama
                if (report.description != null && report.description!.isNotEmpty) ...[
                  Text(
                    'Açıklama: "${report.description!}"',
                    style: TextStyle(color: Colors.grey[800], fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 6),
                ],

                // Hedef İçerik Önizlemesi (Varsa)
                if (report.targetContent != null && report.targetContent!.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'İçerik: "${report.targetContent!}"',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],

                // Kimlik Bilgileri
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Raporlayan: #${report.reportedBy.take(6)}...',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace'),
                    ),
                    Text(
                      'Hedef ID: #${report.reportedId.take(8)}...',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11, fontFamily: 'monospace'),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Aksiyon Butonları
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // İncele
                TextButton.icon(
                  onPressed: () => _showReportInspectionBottomSheet(report),
                  icon: const Icon(Icons.visibility, size: 16, color: Colors.blue),
                  label: const Text('İncele', style: TextStyle(fontSize: 12, color: Colors.blue)),
                ),

                if (isPending) ...[
                  const SizedBox(width: 4),
                  // İşlem Yap
                  FilledButton.icon(
                    onPressed: () => _showReportActionBottomSheet(report),
                    icon: const Icon(Icons.gavel, size: 16),
                    label: const Text('İşlem Yap', style: TextStyle(fontSize: 12)),
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red[700],
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Yoksay
                  IconButton(
                    icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                    tooltip: 'Yoksay',
                    onPressed: () => _confirmDismissReport(report),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================================
  // 🚨 SEKME 2: OTOMATİK MODERASYON ALARMLARI (adminMessages)
  // ============================================================================

  Widget _buildAutoModTab() {
    return StreamBuilder<List<AdminModerationAlarm>>(
      stream: _reportService.getAutoModAlarmsStream(limit: 150),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  const Text('Alarmlar yüklenirken hata oluştu.', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text('Hata detayı: ${snapshot.error}', style: const TextStyle(fontSize: 12, color: Colors.red), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(onPressed: () => setState(() {}), child: const Text('Tekrar Dene')),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const NotificationListSkeleton();
        }

        final allAlarms = snapshot.data ?? [];
        final totalCount = allAlarms.length;
        final unreadCount = allAlarms.where((a) => !a.isRead).length;

        // Filtreleme
        final filteredAlarms = allAlarms.filterAlarms(
          searchQuery: _autoModSearchQuery,
          filter: _autoModFilter,
        );

        return RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              // Başlık & Tümünü Temizle Barı
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Otomatik Yakalanan İçerikler',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                      Text(
                        'Toplam $totalCount alarm ($unreadCount yeni/incelenmemiş)',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  if (totalCount > 0)
                    TextButton.icon(
                      onPressed: _confirmDeleteAllAlarms,
                      icon: const Icon(Icons.delete_sweep, size: 16, color: Colors.red),
                      label: const Text('Tümünü Sil', style: TextStyle(color: Colors.red, fontSize: 12)),
                    ),
                ],
              ),
              const SizedBox(height: 10),

              // Arama ve Filtre Kontrolleri
              Card(
                margin: EdgeInsets.zero,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      TextField(
                        controller: _autoModSearchController,
                        decoration: InputDecoration(
                          hintText: 'Kullanıcı, sebep veya içerik ara...',
                          hintStyle: const TextStyle(fontSize: 12),
                          prefixIcon: const Icon(Icons.search, size: 18),
                          suffixIcon: _autoModSearchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _autoModSearchController.clear();
                                    setState(() => _autoModSearchQuery = '');
                                  },
                                )
                              : null,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 12),
                        onChanged: (val) => setState(() => _autoModSearchQuery = val.trim().toLowerCase()),
                      ),
                      const SizedBox(height: 10),
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildFilterChip('Tümü', 'all', _autoModFilter, (v) => setState(() => _autoModFilter = v)),
                            _buildFilterChip('🔴 Yeni / İncelenmemiş', 'unread', _autoModFilter, (v) => setState(() => _autoModFilter = v)),
                            _buildFilterChip('🏷️ Fırsatlar', 'deals', _autoModFilter, (v) => setState(() => _autoModFilter = v)),
                            _buildFilterChip('💬 Yorumlar', 'comments', _autoModFilter, (v) => setState(() => _autoModFilter = v)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Alarm Kartları
              if (filteredAlarms.isEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 48),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.verified_user_outlined, size: 64, color: Colors.green[300]),
                      const SizedBox(height: 16),
                      const Text(
                        'Kriterlere uygun moderasyon alarmı bulunamadı.',
                        style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                )
              else
                ...filteredAlarms.map((alarm) => _buildAutoModCard(alarm)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAutoModCard(AdminModerationAlarm alarm) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isDeal = alarm.type == 'deal';
    final typeColor = isDeal ? Colors.orange : Colors.blue;
    final typeLabel = isDeal ? 'Fırsat' : 'Yorum';
    final typeIcon = isDeal ? Icons.local_offer : Icons.comment;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: !alarm.isRead ? Colors.red.withValues(alpha: 0.04) : null,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Üst Satır: Tarih & Durum Rozeti
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: typeColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(typeIcon, size: 12, color: typeColor),
                      const SizedBox(width: 4),
                      Text(typeLabel, style: TextStyle(color: typeColor, fontWeight: FontWeight.bold, fontSize: 11)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (!alarm.isRead)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
                    child: const Text('🔴 Yeni', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                    child: const Text('İncelendi', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 10)),
                  ),
                const Spacer(),
                Text(dateFormat.format(alarm.createdAt), style: TextStyle(fontSize: 11, color: Colors.grey[600])),
              ],
            ),
            const SizedBox(height: 10),

            // Kullanıcı Bilgisi
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.grey[300],
                  child: const Icon(Icons.person, size: 16, color: Colors.white),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        alarm.userName,
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      Text(
                        'UID: ${alarm.userId}',
                        style: TextStyle(fontSize: 10, color: Colors.grey[500], fontFamily: 'monospace'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Tespit Nedeni & İçerik
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('⚠️ ${alarm.reason}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text('"${alarm.content}"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Aksiyon Butonları
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (alarm.dealId != null)
                  TextButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: alarm.dealId!)),
                      );
                    },
                    icon: const Icon(Icons.visibility, size: 16),
                    label: const Text('Fırsatı Gör', style: TextStyle(fontSize: 12)),
                  ),
                if (!alarm.isRead)
                  IconButton(
                    icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                    tooltip: 'İncelendi Olarak İşaretle',
                    onPressed: () async {
                      await _reportService.markAutoModAlarmAsRead(alarm.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Alarm incelendi olarak işaretlendi.')),
                        );
                      }
                    },
                  ),
                IconButton(
                  icon: const Icon(Icons.mail_outline, color: Colors.blue, size: 20),
                  tooltip: 'Kullanıcıya Uyarı Gönder',
                  onPressed: () => _showSendWarningDialog(alarm.userId, alarm.userName),
                ),
                IconButton(
                  icon: const Icon(Icons.account_circle_outlined, color: Colors.purple, size: 20),
                  tooltip: 'Kullanıcı Profili',
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ProfileScreen(userId: alarm.userId)),
                    );
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                  tooltip: 'Alarmı Sil',
                  onPressed: () async {
                    await _reportService.deleteAutoModAlarm(alarm.id);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Alarm silindi.')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================================
  // 🔍 MODALLAR: İNCELEME & AKSİYON BOTTOM SHEET'LERİ
  // ============================================================================

  /// Şikayet Detaylı İnceleme BottomSheet'i
  void _showReportInspectionBottomSheet(Report report) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (sheetContext) {
        return DraggableScrollableSheet(
          initialChildSize: 0.75,
          minChildSize: 0.4,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return FutureBuilder<Map<String, dynamic>?>(
              future: _fetchReportTargetDetails(report),
              builder: (context, snapshot) {
                final targetDetails = snapshot.data;
                final isLoading = snapshot.connectionState == ConnectionState.waiting;

                String? targetUserId = report.targetAuthorId;
                String targetUserName = report.targetAuthor ?? 'Kullanıcı';

                if (report.type == 'user') {
                  targetUserId = report.reportedId;
                } else if (targetDetails != null && targetDetails['userId'] != null) {
                  targetUserId = targetDetails['userId'] as String;
                  targetUserName = (targetDetails['userName'] as String?) ?? targetUserName;
                }

                return Column(
                  children: [
                    // Tutma Çubuğu
                    Container(
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                    ),

                    // Başlık
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Row(
                        children: [
                          Icon(
                            report.type == 'deal'
                                ? Icons.local_offer
                                : report.type == 'comment'
                                    ? Icons.comment
                                    : report.type == 'user'
                                        ? Icons.person
                                        : Icons.chat_bubble,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${report.type.toUpperCase()} Şikayeti İnceleme',
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),

                    // İçerik Listesi
                    Expanded(
                      child: ListView(
                        controller: scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          // 1. Şikayet Özeti
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text('ŞİKAYET NEDENİ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(6)),
                                      child: Text(report.reason, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11)),
                                    ),
                                  ],
                                ),
                                if (report.description != null && report.description!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text('Açıklama: "${report.description!}"', style: const TextStyle(fontSize: 13)),
                                ],
                                const SizedBox(height: 8),
                                Text('Raporlayan UID: ${report.reportedBy}', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'monospace')),
                                Text('Tarih: ${DateFormat('dd.MM.yyyy HH:mm').format(report.createdAt)}', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // 2. Hedef İçerik Detayı
                          const Text('ŞİKAYET EDİLEN İÇERİK DETAYI', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.grey)),
                          const SizedBox(height: 8),

                          if (isLoading)
                            const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            _buildTargetDetailsWidget(report, targetDetails),
                        ],
                      ),
                    ),

                    // Alt Aksiyon Butonları
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
                      ),
                      child: SafeArea(
                        top: false,
                        child: Row(
                          children: [
                            if (targetUserId != null && targetUserId.isNotEmpty && targetUserId != 'botkolik')
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _showSendWarningDialog(targetUserId!, targetUserName);
                                  },
                                  icon: const Icon(Icons.mail_outline, size: 16),
                                  label: const Text('Uyarı Gönder', style: TextStyle(fontSize: 12)),
                                ),
                              ),
                            if (targetUserId != null && targetUserId.isNotEmpty && targetUserId != 'botkolik')
                              const SizedBox(width: 8),
                            if (report.status == 'pending')
                              Expanded(
                                child: FilledButton.icon(
                                  onPressed: () {
                                    Navigator.pop(sheetContext);
                                    _showReportActionBottomSheet(report);
                                  },
                                  icon: const Icon(Icons.gavel, size: 16),
                                  label: const Text('İşlem Yap', style: TextStyle(fontSize: 12)),
                                  style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildTargetDetailsWidget(Report report, Map<String, dynamic>? details) {
    if (report.type == 'deal') {
      if (details == null) {
        return const Text('Fırsat veritabanında bulunamadı (silinmiş olabilir).', style: TextStyle(color: Colors.grey));
      }
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (details['imageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      details['imageUrl'] as String,
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image, size: 40),
                    ),
                  ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(details['title'] as String? ?? 'Fırsat', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(height: 2),
                      Text('${details['store'] ?? ''} • ${details['price'] != null ? '${details['price']} TL' : ''}', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: report.reportedId)));
              },
              icon: const Icon(Icons.open_in_new, size: 16),
              label: const Text('Fırsat Detayına Git', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    } else if (report.type == 'comment') {
      final commentText = details?['content'] ?? report.targetContent ?? 'Yorum metni bulunamadı.';
      final authorName = details?['userName'] ?? report.targetAuthor ?? 'Kullanıcı';
      final authorId = details?['userId'] ?? report.targetAuthorId ?? '-';
      final parentDealId = details?['dealId'] as String?;

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.blue.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.blue,
                  child: Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U', style: const TextStyle(color: Colors.white, fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('UID: $authorId', style: TextStyle(fontSize: 10, color: Colors.grey[600], fontFamily: 'monospace')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
              child: Text('"$commentText"', style: const TextStyle(fontSize: 13, fontStyle: FontStyle.italic)),
            ),
            if (parentDealId != null && parentDealId.isNotEmpty) ...[
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: parentDealId)));
                },
                icon: const Icon(Icons.open_in_new, size: 16),
                label: const Text('İlgili Fırsata Git', style: TextStyle(fontSize: 12)),
              ),
            ],
          ],
        ),
      );
    } else if (report.type == 'user') {
      final userName = details?['nickname'] ?? details?['username'] ?? 'Kullanıcı';
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.purple.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kullanıcı: $userName', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 4),
            Text('UID: ${report.reportedId}', style: TextStyle(fontSize: 11, color: Colors.grey[600], fontFamily: 'monospace')),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: report.reportedId)));
              },
              icon: const Icon(Icons.person, size: 16),
              label: const Text('Kullanıcı Profilini Aç', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    return Text(report.targetContent ?? 'İçerik detayı bulunamadı.');
  }

  Future<Map<String, dynamic>?> _fetchReportTargetDetails(Report report) async {
    try {
      if (report.type == 'deal') {
        final doc = await FirebaseFirestore.instance.collection('deals').doc(report.reportedId).get();
        return doc.data();
      } else if (report.type == 'comment') {
        return await _reportService.findCommentAndParent(report.reportedId, report.targetDealId);
      } else if (report.type == 'user') {
        final doc = await FirebaseFirestore.instance.collection('users').doc(report.reportedId).get();
        return doc.data();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Şikayet İçin Granüler Aksiyon BottomSheet'i
  void _showReportActionBottomSheet(Report report) {
    String selectedAction = 'resolve_only';
    final noteController = TextEditingController();
    bool isSubmitting = false;

    // Rapor tipine göre aksiyon listesi
    final List<_ActionOption> options = [];

    if (report.type == 'deal') {
      options.addAll([
        _ActionOption(
          id: 'expire_deal',
          title: 'Fırsatı Yayından Kaldır (Süresi Dolan Yap)',
          subtitle: 'Fırsat feed akışından kaldırılıp süresi dolmuş yapılır.',
          icon: Icons.timer_off,
          isDanger: false,
        ),
        _ActionOption(
          id: 'delete_deal',
          title: 'Fırsatı Kalıcı Olarak Sil',
          subtitle: 'Fırsat Firestore veritabanından tamamen silinir.',
          icon: Icons.delete_forever,
          isDanger: true,
        ),
        _ActionOption(
          id: 'ban_deal_poster',
          title: 'Paylaşanın Fırsat Paylaşmasını Engelle',
          subtitle: 'Kullanıcının yeni fırsat eklemesi engellenir.',
          icon: Icons.block,
          isDanger: true,
        ),
        _ActionOption(
          id: 'resolve_only',
          title: 'Sadece Şikayeti "Çözüldü" Olarak Kapat',
          subtitle: 'Fırsata dokunulmaz, şikayet kapatılır.',
          icon: Icons.check_circle,
          isDanger: false,
        ),
      ]);
      selectedAction = 'expire_deal';
    } else if (report.type == 'comment') {
      options.addAll([
        _ActionOption(
          id: 'delete_comment',
          title: 'Yorumu Kalıcı Olarak Sil ve Sayacı Düşür',
          subtitle: 'Yorum dokümanı silinir ve fırsat yorum sayacı 1 azaltılır.',
          icon: Icons.delete_sweep,
          isDanger: true,
        ),
        _ActionOption(
          id: 'ban_commenter',
          title: 'Yazarın Yeni Yorum Yapmasını Yasakla',
          subtitle: 'Kullanıcının yorum ekleme yetkisi elinden alınır.',
          icon: Icons.speaker_notes_off,
          isDanger: true,
        ),
        _ActionOption(
          id: 'ban_user_full',
          title: 'Yazarı Tamamen Engelle (Sisteme Girişini Yasakla)',
          subtitle: 'Kullanıcı hesabı tamamen bloke edilir.',
          icon: Icons.person_off,
          isDanger: true,
        ),
        _ActionOption(
          id: 'resolve_only',
          title: 'Sadece Şikayeti "Çözüldü" Olarak Kapat',
          subtitle: 'Yoruma dokunulmaz, şikayet kapatılır.',
          icon: Icons.check_circle,
          isDanger: false,
        ),
      ]);
      selectedAction = 'delete_comment';
    } else if (report.type == 'user') {
      options.addAll([
        _ActionOption(
          id: 'ban_user_full',
          title: 'Kullanıcıyı Tamamen Engelle',
          subtitle: 'Kullanıcının uygulamaya girişi tamamen engellenir.',
          icon: Icons.person_off,
          isDanger: true,
        ),
        _ActionOption(
          id: 'ban_user_deals',
          title: 'Kullanıcının Fırsat Paylaşmasını Engelle',
          subtitle: 'Kullanıcının yeni fırsat eklemesi yasaklanır.',
          icon: Icons.local_offer,
          isDanger: true,
        ),
        _ActionOption(
          id: 'ban_user_comments',
          title: 'Kullanıcının Yorum Yapmasını Engelle',
          subtitle: 'Kullanıcının yorum eklemesi yasaklanır.',
          icon: Icons.comment,
          isDanger: true,
        ),
        _ActionOption(
          id: 'resolve_only',
          title: 'Sadece Şikayeti Kapat',
          subtitle: 'Kullanıcıya yaptırım uygulanmaz.',
          icon: Icons.check_circle,
          isDanger: false,
        ),
      ]);
      selectedAction = 'ban_user_full';
    } else if (report.type == 'message') {
      options.addAll([
        _ActionOption(
          id: 'delete_message',
          title: 'Mesajı Kalıcı Olarak Sil',
          subtitle: 'Şikayet edilen mesaj veritabanından kalıcı olarak silinir.',
          icon: Icons.delete_outline,
          isDanger: true,
        ),
        _ActionOption(
          id: 'ban_sender',
          title: 'Mesajı Gönderen Kullanıcıyı Engelle',
          subtitle: 'Gönderenin sisteme girişi tamamen engellenir.',
          icon: Icons.person_off,
          isDanger: true,
        ),
        _ActionOption(
          id: 'resolve_only',
          title: 'Sadece Şikayeti Kapat',
          subtitle: 'Mesaja dokunulmaz, şikayet kapatılır.',
          icon: Icons.check_circle,
          isDanger: false,
        ),
      ]);
      selectedAction = 'delete_message';
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (actionSheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Başlık
                      Row(
                        children: [
                          const Icon(Icons.gavel, color: Colors.red),
                          const SizedBox(width: 8),
                          const Text('Şikayet İçin İşlem Seçin', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          const Spacer(),
                          IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(actionSheetContext)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text('Uygulanacak moderasyon aksiyonunu belirleyin:', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      const SizedBox(height: 12),

                      // Seçenekler Listesi
                      ...options.map((opt) {
                        final isSelected = selectedAction == opt.id;
                        return InkWell(
                          onTap: () => setSheetState(() => selectedAction = opt.id),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected ? (opt.isDanger ? Colors.red.withValues(alpha: 0.08) : Colors.blue.withValues(alpha: 0.08)) : null,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? (opt.isDanger ? Colors.red : Colors.blue) : Colors.grey.withValues(alpha: 0.2),
                                width: isSelected ? 1.5 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(opt.icon, size: 20, color: opt.isDanger ? Colors.red : Colors.blue),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opt.title,
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: opt.isDanger ? Colors.red[800] : null,
                                        ),
                                      ),
                                      Text(opt.subtitle, style: TextStyle(fontSize: 10, color: Colors.grey[600])),
                                    ],
                                  ),
                                ),
                                Radio<String>(
                                  value: opt.id,
                                  groupValue: selectedAction,
                                  onChanged: (val) {
                                    if (val != null) setSheetState(() => selectedAction = val);
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                      }),

                      const SizedBox(height: 8),
                      // Yönetici Notu Girişi
                      TextField(
                        controller: noteController,
                        decoration: InputDecoration(
                          labelText: 'Yönetici Notu / Açıklama (İsteğe Bağlı)',
                          labelStyle: const TextStyle(fontSize: 12),
                          hintText: 'Aksiyon gerekçesi...',
                          hintStyle: const TextStyle(fontSize: 11),
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 16),

                      // Onay Butonu
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: isSubmitting
                              ? null
                              : () async {
                                  setSheetState(() => isSubmitting = true);
                                  await _executeReportAction(report, selectedAction, noteController.text.trim());
                                  if (actionSheetContext.mounted) {
                                    Navigator.pop(actionSheetContext);
                                  }
                                },
                          icon: isSubmitting
                              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check),
                          label: Text(isSubmitting ? 'Uygulanıyor...' : 'İşlemi Uygula'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  /// Seçilen aksiyonu yürütme
  Future<void> _executeReportAction(Report report, String actionType, String note) async {
    try {
      if (actionType == 'expire_deal') {
        await _firestoreService.updateDeal(report.reportedId, {
          'isExpired': true,
          'status': 'expired',
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else if (actionType == 'delete_deal') {
        await FirebaseFirestore.instance.collection('deals').doc(report.reportedId).delete();
      } else if (actionType == 'ban_deal_poster') {
        final dealDoc = await FirebaseFirestore.instance.collection('deals').doc(report.reportedId).get();
        final posterId = dealDoc.data()?['postedBy'] as String?;
        if (posterId != null && posterId != 'botkolik') {
          await _userService.banUserDeals(posterId);
        }
      } else if (actionType == 'delete_comment') {
        final commentDetails = await _reportService.findCommentAndParent(report.reportedId, report.targetDealId);
        final dealId = commentDetails?['dealId'] as String? ?? report.targetDealId;
        if (dealId != null && dealId.isNotEmpty) {
          await _commentService.deleteComment(report.reportedId, dealId);
        }
      } else if (actionType == 'ban_commenter') {
        final commentDetails = await _reportService.findCommentAndParent(report.reportedId, report.targetDealId);
        final userId = commentDetails?['userId'] as String? ?? report.targetAuthorId;
        if (userId != null && userId.isNotEmpty) {
          await _userService.banUserComments(userId);
        }
      } else if (actionType == 'ban_user_full') {
        String? targetId;
        if (report.type == 'user') {
          targetId = report.reportedId;
        } else if (report.type == 'comment') {
          final commentDetails = await _reportService.findCommentAndParent(report.reportedId, report.targetDealId);
          targetId = commentDetails?['userId'] as String? ?? report.targetAuthorId;
        }
        if (targetId != null && targetId.isNotEmpty) {
          await _userService.blockUser(targetId);
        }
      } else if (actionType == 'ban_user_deals') {
        await _userService.banUserDeals(report.reportedId);
      } else if (actionType == 'ban_user_comments') {
        await _userService.banUserComments(report.reportedId);
      } else if (actionType == 'delete_message') {
        await _firestoreService.deleteUserMessage(report.reportedId);
      } else if (actionType == 'ban_sender') {
        final msgDoc = await FirebaseFirestore.instance.collection('messages').doc(report.reportedId).get();
        final senderId = msgDoc.data()?['senderId'] as String?;
        if (senderId != null && senderId != 'botkolik') {
          await _userService.blockUser(senderId);
        }
      }

      // Rapor dokümanını güncelle
      await _reportService.executeReportAction(
        reportId: report.id,
        actionType: actionType,
        actionNote: note,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem başarıyla uygulandı ve şikayet kapatıldı.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('İşlem uygulanırken hata oluştu: $cleanMsg'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Şikayeti yoksayma onayı
  void _confirmDismissReport(Report report) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Şikayeti Yoksay'),
        content: const Text('Bu şikayeti kapatmak istediğinize emin misiniz?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _reportService.dismissReport(report.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Şikayet yoksayıldı ve kapatıldı.')),
                );
              }
            },
            child: const Text('Yoksay'),
          ),
        ],
      ),
    );
  }

  /// Kullanıcıya Resmi Yönetici Uyarısı Gönderme Diyalogu
  void _showSendWarningDialog(String userId, String userName) {
    final titleController = TextEditingController(text: 'Moderasyon Uyarısı');
    final contentController = TextEditingController();
    bool isSending = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.mail, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text('$userName - Uyarı Gönder', style: const TextStyle(fontSize: 15)),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kullanıcıya bildirim ve resmi yönetici mesajı iletilir:',
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Başlık',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: contentController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Uyarı İçeriği',
                      hintText: 'İçeriğiniz kurallarımıza aykırı bulunmuştur...',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('İptal'),
                ),
                FilledButton(
                  onPressed: isSending
                      ? null
                      : () async {
                          final title = titleController.text.trim();
                          final content = contentController.text.trim();
                          if (title.isEmpty || content.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Lütfen başlık ve mesaj içeriği girin.')),
                            );
                            return;
                          }

                          setDialogState(() => isSending = true);
                          final currentAdmin = FirebaseAuth.instance.currentUser;
                          final adminId = currentAdmin?.uid ?? 'admin';
                          final adminName = currentAdmin?.displayName ?? 'Admin';

                          final messenger = ScaffoldMessenger.of(context);
                          final success = await _messageService.sendAdminToUserMessage(
                            targetUserId: userId,
                            adminId: adminId,
                            adminName: adminName,
                            title: title,
                            content: content,
                          );

                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text(success ? 'Uyarı başarıyla gönderildi.' : 'Uyarı gönderilemedi.'),
                              backgroundColor: success ? Colors.green : Colors.red,
                            ),
                          );
                        },
                  child: Text(isSending ? 'Gönderiliyor...' : 'Gönder'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Tüm Alarmları Temizleme Onayı
  void _confirmDeleteAllAlarms() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tüm Alarmları Temizle'),
        content: const Text('TÜM otomatik moderasyon alarmlarını kalıcı olarak silmek istediğinize emin misiniz? Bu işlem geri alınamaz!'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Vazgeç')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(ctx);
              await _reportService.deleteAllAutoModAlarms();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Tüm alarmlar başarıyla temizlendi.')),
                );
              }
            },
            child: const Text('Tümünü Sil'),
          ),
        ],
      ),
    );
  }
}

class _ActionOption {
  final String id;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isDanger;

  _ActionOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isDanger,
  });
}

extension _StringExt on String {
  String take(int n) => length <= n ? this : substring(0, n);
}

extension _ReportFilterExt on List<Report> {
  List<Report> filterReports({
    required String searchQuery,
    required String statusFilter,
    required String typeFilter,
  }) {
    return where((report) {
      if (statusFilter != 'all' && report.status != statusFilter) return false;
      if (typeFilter != 'all' && report.type != typeFilter) return false;
      if (searchQuery.isNotEmpty) {
        final idMatch = report.id.toLowerCase().contains(searchQuery);
        final repIdMatch = report.reportedId.toLowerCase().contains(searchQuery);
        final reporterMatch = report.reportedBy.toLowerCase().contains(searchQuery);
        final reasonMatch = report.reason.toLowerCase().contains(searchQuery);
        final descMatch = (report.description ?? '').toLowerCase().contains(searchQuery);
        final contentMatch = (report.targetContent ?? '').toLowerCase().contains(searchQuery);
        final authorMatch = (report.targetAuthor ?? '').toLowerCase().contains(searchQuery);
        return idMatch || repIdMatch || reporterMatch || reasonMatch || descMatch || contentMatch || authorMatch;
      }
      return true;
    }).toList();
  }
}

extension _AlarmFilterExt on List<AdminModerationAlarm> {
  List<AdminModerationAlarm> filterAlarms({
    required String searchQuery,
    required String filter,
  }) {
    return where((alarm) {
      if (filter == 'unread' && alarm.isRead) return false;
      if (filter == 'deals' && alarm.type != 'deal') return false;
      if (filter == 'comments' && alarm.type != 'comment') return false;
      if (searchQuery.isNotEmpty) {
        final userMatch = alarm.userName.toLowerCase().contains(searchQuery) || alarm.userId.toLowerCase().contains(searchQuery);
        final contentMatch = alarm.content.toLowerCase().contains(searchQuery);
        final reasonMatch = alarm.reason.toLowerCase().contains(searchQuery);
        return userMatch || contentMatch || reasonMatch;
      }
      return true;
    }).toList();
  }
}
