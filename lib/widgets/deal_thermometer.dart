import 'package:flutter/material.dart';
import '../models/deal.dart';

class DealThermometer extends StatelessWidget {
  final Deal deal;
  final int hotVotes;
  final int coldVotes;
  final bool hasVotedHot;
  final bool hasVotedCold;
  final Function(bool isHot) onVote;

  const DealThermometer({
    super.key,
    required this.deal,
    required this.hotVotes,
    required this.coldVotes,
    required this.hasVotedHot,
    required this.hasVotedCold,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // Yorum satırlarındaki düzeltmeler
    final currentHotVotes = hotVotes > 0 ? hotVotes : deal.hotVotes;
    final currentColdVotes = coldVotes > 0 ? coldVotes : deal.coldVotes;
    final totalVotes = currentHotVotes + currentColdVotes;
    
    // Sıcaklık yüzdesi hesapla (0-100)
    final hotPercentage = totalVotes > 0 ? (currentHotVotes / totalVotes * 100).round() : 50;
    
    // Duruma göre eğlenceli mesaj ve emoji
    String getMessage() {
      if (totalVotes == 0) return 'Henüz oy yok, sen başlat! 🎯';
      if (hotPercentage >= 80) return 'EFSANE FIRSAT! 🔥🔥🔥';
      if (hotPercentage >= 60) return 'Kaçırma derim! 🏃💨';
      if (hotPercentage >= 40) return 'Fena değil aslında 🤔';
      if (hotPercentage >= 20) return 'Düşünürüm artık... 😬';
      return 'Param cebimde kalsın 💸';
    }
    
    // Sıcaklık rengini hesapla
    Color getThermometerColor() {
      if (hotPercentage >= 70) return Colors.red;
      if (hotPercentage >= 50) return Colors.orange;
      if (hotPercentage >= 30) return Colors.amber;
      return Colors.blue;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [Colors.grey[900]!, Colors.grey[850]!]
              : [Colors.grey[50]!, Colors.white],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.grey[800]! : Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Eğlenceli mesaj (kompakt)
          Text(
            getMessage(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          
          // Termometre bar'ı
          Row(
            children: [
              // Soğuk taraf
              GestureDetector(
                onTap: () => onVote(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasVotedCold 
                        ? Colors.blue.withOpacity(0.2) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasVotedCold ? Colors.blue : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🥶', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        'Geç',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.blue[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Termometre
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Skor gösterimi
                      Text(
                        totalVotes > 0 ? '$hotPercentage°' : '—',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          color: getThermometerColor(),
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Bar
                      Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: Colors.blue.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Stack(
                              children: [
                                // Doluluk
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 500),
                                  curve: Curves.easeOutCubic,
                                  width: constraints.maxWidth * (hotPercentage / 100),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [Colors.orange, Colors.red],
                                    ),
                                    borderRadius: BorderRadius.circular(4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.red.withOpacity(0.3),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 3),
                      // Oy sayısı
                      Text(
                        '$totalVotes oy',
                        style: TextStyle(
                          fontSize: 9,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Sıcak taraf
              GestureDetector(
                onTap: () => onVote(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(
                    color: hasVotedHot 
                        ? Colors.red.withOpacity(0.2) 
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: hasVotedHot ? Colors.red : Colors.transparent,
                      width: 1.5,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🔥', style: TextStyle(fontSize: 18)),
                      const SizedBox(height: 2),
                      Text(
                        'Al!',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.red[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
