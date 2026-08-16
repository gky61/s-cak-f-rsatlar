import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/report.dart';
import '../services/report_service.dart';
import '../services/firestore_service.dart';
import '../screens/deal_detail_screen.dart';
import '../screens/profile_screen.dart';

class AdminReportsList extends StatefulWidget {
  final String status; // 'pending' veya 'dismissed'/'action_taken'

  const AdminReportsList({super.key, this.status = 'pending'});

  @override
  State<AdminReportsList> createState() => _AdminReportsListState();
}

class _AdminReportsListState extends State<AdminReportsList> {
  final ReportService _reportService = ReportService();
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Report>>(
      stream: _reportService.getReportsStream(status: widget.status),
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
                   const Text(
                    'Veriler yüklenirken bir hata oluştu.',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                   const SizedBox(height: 8),
                   Text(
                    'Hata detayı: ${snapshot.error}',
                    style: const TextStyle(fontSize: 12, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {});
                    },
                    child: const Text('Tekrar Dene'),
                  ),
                ],
              ),
            ),
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data ?? [];

        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.report_off_outlined,
                  size: 64,
                  color: Colors.grey[300],
                ),
                const SizedBox(height: 16),
                Text(
                  widget.status == 'pending'
                      ? 'Bekleyen rapor yok'
                      : 'İşlem yapılmış rapor yok',
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            return _buildReportCard(reports[index]);
          },
        );
      },
    );
  }

  Widget _buildReportCard(Report report) {
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    final isPending = widget.status == 'pending';

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

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: typeColor.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              children: [
                Icon(typeIcon, size: 16, color: typeColor),
                const SizedBox(width: 8),
                Text(
                  typeLabel,
                  style: TextStyle(
                    color: typeColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                Text(
                  dateFormat.format(report.createdAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Sebep: ${report.reason}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          if (report.description != null && report.description!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              report.description!,
                              style: TextStyle(color: Colors.grey[800], fontSize: 13),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Raporlayan: ${report.reportedBy}', // İsim çekmek için ekstra sorgu gerekebilir ama şimdilik ID
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
                 Text(
                  'Raporlanan ID: ${report.reportedId}',
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          
          if (isPending) ...[
            const Divider(height: 1),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _viewContent(report),
                    icon: const Icon(Icons.visibility, color: Colors.blue, size: 18),
                    label: const Text('Görüntüle', style: TextStyle(fontSize: 12)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _updateStatus(report, 'dismissed'),
                    icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                    label: const Text('Yoksay', style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => _takeAction(report),
                    icon: const Icon(Icons.check_circle, color: Colors.red, size: 18),
                    label: const Text('İşlem Yap', style: TextStyle(color: Colors.red, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _viewContent(Report report) {
    if (report.type == 'deal') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DealDetailScreen(dealId: report.reportedId)),
      );
    } else if (report.type == 'user') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => ProfileScreen(userId: report.reportedId)),
      );
    } else if (report.type == 'comment') {
      // Yorum görüntüleme (Şimdilik DealDetailScreen'e gidiyor, yorum ID'si ile scroll edilebilir)
      // Ancak comment raporlarında dealId'ye ihtiyacımız var. 
      // Report modeline dealId eklemek iyi olabilir veya Firestore'dan yorumu çekip dealId'sini bulmak gerek.
      // Şimdilik basitçe:
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yorum detayına gitmek için yorumun bağlı olduğu fırsat ID\'si gerekiyor.')),
      );
    }
  }

  Future<void> _updateStatus(Report report, String status) async {
    final success = await _reportService.updateReportStatus(report.id, status);
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(status == 'dismissed' ? 'Rapor yoksayıldı' : 'Rapor durumu güncellendi'),
            backgroundColor: Colors.grey,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Hata oluştu'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _takeAction(Report report) async {
    // İşlem yap diyaloğu
    // Örneğin: Fırsatı sil, kullanıcıyı engelle vb.
    
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('İşlem Seçin'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (report.type == 'deal')
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Fırsatı Yayından Kaldır'),
                onTap: () async {
                  Navigator.pop(context);
                  await _firestoreService.updateDeal(report.reportedId, {'isExpired': true});
                  await _updateStatus(report, 'action_taken');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Fırsat yayından kaldırıldı ve rapor kapatıldı'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
              
             if (report.type == 'user')
              ListTile(
                leading: const Icon(Icons.block, color: Colors.red),
                title: const Text('Kullanıcıyı Engelle'),
                onTap: () async {
                  Navigator.pop(context);
                  await _firestoreService.blockUser(report.reportedId);
                  await _updateStatus(report, 'action_taken');
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Kullanıcı engellendi ve rapor kapatıldı'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),

             if (report.type == 'message')
              ListTile(
                leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                title: const Text('Mesajı Kalıcı Olarak Sil'),
                onTap: () async {
                  Navigator.pop(context);
                  await _firestoreService.deleteUserMessage(report.reportedId);
                  await _updateStatus(report, 'action_taken');
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Mesaj silindi ve rapor kapatıldı'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
              
              const Divider(),
               ListTile(
                leading: const Icon(Icons.check, color: Colors.green),
                title: const Text('Sadece Raporu Kapat'),
                subtitle: const Text('İçeriğe dokunmadan raporu "çözüldü" olarak işaretle'),
                onTap: () async {
                  Navigator.pop(context);
                  await _updateStatus(report, 'action_taken');
                   if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rapor çözüldü olarak işaretlendi'), backgroundColor: Colors.green),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}
