import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'shimmer_box.dart';

/// Sohbet İçi Mesaj Akışı Yükleme Skeleton'ı
class ChatMessagesSkeleton extends StatelessWidget {
  const ChatMessagesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sentBg = isDark ? const Color(0xFF3B2D26) : const Color(0xFFFFECE5);
    final receivedBg = isDark ? AppTheme.darkSurface : Colors.white;
    final borderColor = isDark ? AppTheme.darkBorder : const Color(0xFFE2E8F0);

    // Önceden tanımlı rastgele mesaj genişlikleri ve yönleri
    final bubbleConfigs = [
      {'isMe': false, 'width': 180.0, 'height': 44.0},
      {'isMe': true, 'width': 220.0, 'height': 60.0},
      {'isMe': false, 'width': 130.0, 'height': 38.0},
      {'isMe': false, 'width': 240.0, 'height': 56.0},
      {'isMe': true, 'width': 160.0, 'height': 42.0},
      {'isMe': true, 'width': 190.0, 'height': 50.0},
      {'isMe': false, 'width': 210.0, 'height': 58.0},
      {'isMe': true, 'width': 140.0, 'height': 38.0},
    ];

    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: bubbleConfigs.length,
      itemBuilder: (context, index) {
        final config = bubbleConfigs[index];
        final isMe = config['isMe'] as bool;
        final width = config['width'] as double;
        final height = config['height'] as double;

        return Align(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: width,
            height: height,
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isMe ? sentBg : receivedBg,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(18),
                topRight: const Radius.circular(18),
                bottomLeft: Radius.circular(isMe ? 18 : 4),
                bottomRight: Radius.circular(isMe ? 4 : 18),
              ),
              border: Border.all(
                color: isMe
                    ? AppTheme.primary.withValues(alpha: isDark ? 0.3 : 0.2)
                    : borderColor,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShimmerBox(
                  width: width * 0.75,
                  height: 11,
                  borderRadius: 4,
                ),
                if (height > 45) ...[
                  const SizedBox(height: 5),
                  ShimmerBox(
                    width: width * 0.45,
                    height: 10,
                    borderRadius: 4,
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
