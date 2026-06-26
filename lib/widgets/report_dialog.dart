import 'package:flutter/material.dart';
import '../services/report_service.dart';
import '../theme/app_theme.dart';

class ReportDialog extends StatefulWidget {
  final String reportedId;
  final String type; // 'deal', 'comment', 'user'

  const ReportDialog({
    super.key,
    required this.reportedId,
    required this.type,
  });

  @override
  State<ReportDialog> createState() => _ReportDialogState();
}

class _ReportDialogState extends State<ReportDialog> {
  final ReportService _reportService = ReportService();
  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedReason;
  bool _isLoading = false;

  final List<String> _reasons = [
    'Spam veya yanıltıcı',
    'Uygunsuz içerik / görsel',
    'Hakaret veya zorbalık',
    'Nefret söylemi',
    'Yasadışı ürün / hizmet',
    'Diğer',
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitReport() async {
    if (_selectedReason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir sebep seçiniz.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final success = await _reportService.submitReport(
      reportedId: widget.reportedId,
      type: widget.type,
      reason: _selectedReason!,
      description: _descriptionController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context); // Dialog'u kapat
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bildiriminiz alındı. Teşekkür ederiz.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Bir hata oluştu. Lütfen tekrar deneyin.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: EdgeInsets.only(
        top: 16,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          
          Text(
            'İçeriği Raporla',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Lütfen bu içeriği neden raporladığınızı belirtin. Bildiriminiz anonim tutulacaktır.',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 24),

          // Sebepler Listesi
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: _reasons.map((reason) {
              final isSelected = _selectedReason == reason;
              return ChoiceChip(
                label: Text(reason),
                selected: isSelected,
                onSelected: (selected) {
                  setState(() {
                    _selectedReason = selected ? reason : null;
                  });
                },
                selectedColor: primaryColor.withOpacity(0.2),
                backgroundColor: isDark ? Colors.grey[800] : Colors.grey[200],
                labelStyle: TextStyle(
                  color: isSelected 
                      ? primaryColor 
                      : (isDark ? Colors.white : Colors.black87),
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
                side: BorderSide(
                  color: isSelected ? primaryColor : Colors.transparent,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              );
            }).toList(),
          ),
          
          const SizedBox(height: 20),

          // Açıklama Alanı (Diğer seçildiyse zorunlu olabilir veya opsiyonel)
          TextField(
            controller: _descriptionController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: 'Ek açıklama (opsiyonel)',
              hintStyle: TextStyle(color: Colors.grey[500]),
              filled: true,
              fillColor: isDark ? AppTheme.darkSurfaceElevated : Colors.grey[100],
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
          ),

          const SizedBox(height: 24),

          // Gönder Butonu
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submitReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red[600], // Raporlama olduğu için kırmızı tonu
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text(
                      'Raporla',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'İptal',
                style: TextStyle(
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Helper function to show the report dialog
void showReportDialog(BuildContext context, {required String reportedId, required String type}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => ReportDialog(
      reportedId: reportedId,
      type: type,
    ),
  );
}
