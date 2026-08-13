import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:cached_network_image/cached_network_image.dart';
import '../theme/app_theme.dart';
import '../utils/asset_path_migration.dart';
import '../screens/message_screen.dart';
import '../services/notification_service.dart';
import '../main.dart'; // navigatorKey

class InAppMessageBanner {
  static OverlayEntry? _currentEntry;

  static void show({
    required BuildContext? context,
    required String senderId,
    required String senderName,
    required String senderImageUrl,
    required String messageText,
    bool isAdminMessage = false,
    String? dealTitle,
    String? dealId,
  }) {
    OverlayState? overlayState;
    if (context != null) {
      overlayState = Overlay.maybeOf(context);
    }
    overlayState ??= navigatorKey.currentState?.overlay;

    if (overlayState == null) {
      if (kDebugMode) {
        print('⚠️ InAppMessageBanner: OverlayState bulunamadı!');
      }
      return;
    }

    _currentEntry?.remove();
    _currentEntry = null;

    HapticFeedback.lightImpact();

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _InAppBannerWidget(
        senderId: senderId,
        senderName: senderName,
        senderImageUrl: senderImageUrl,
        messageText: messageText,
        isAdminMessage: isAdminMessage,
        dealTitle: dealTitle,
        dealId: dealId,
        onDismiss: () {
          if (_currentEntry == entry) {
            entry.remove();
            _currentEntry = null;
          }
        },
      ),
    );

    _currentEntry = entry;
    overlayState.insert(entry);
  }

  static void hide() {
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _InAppBannerWidget extends StatefulWidget {
  final String senderId;
  final String senderName;
  final String senderImageUrl;
  final String messageText;
  final bool isAdminMessage;
  final String? dealTitle;
  final String? dealId;
  final VoidCallback onDismiss;

  const _InAppBannerWidget({
    required this.senderId,
    required this.senderName,
    required this.senderImageUrl,
    required this.messageText,
    this.isAdminMessage = false,
    this.dealTitle,
    this.dealId,
    required this.onDismiss,
  });

  @override
  State<_InAppBannerWidget> createState() => _InAppBannerWidgetState();
}

class _InAppBannerWidgetState extends State<_InAppBannerWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _offsetAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );

    _offsetAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    ));

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _animController.forward();

    // 4.2 saniye sonra otomatik kapat
    Future.delayed(const Duration(milliseconds: 4200), () {
      if (mounted) {
        _dismiss();
      }
    });
  }

  void _dismiss() async {
    if (!mounted) return;
    await _animController.reverse();
    widget.onDismiss();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 12,
      right: 12,
      child: SlideTransition(
        position: _offsetAnim,
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Dismissible(
            key: UniqueKey(),
            direction: DismissDirection.up,
            onDismissed: (_) => widget.onDismiss(),
            child: Material(
              color: Colors.transparent,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? AppTheme.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.12)
                        : Colors.black.withValues(alpha: 0.08),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.15),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    widget.onDismiss();
                    final nav = navigatorKey.currentState;
                    if (nav != null) {
                      if (widget.isAdminMessage || widget.senderId == 'admin') {
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => const MessageScreen(
                              otherUserId: 'admin',
                              otherUserName: 'FırsatKolik Yönetim',
                              otherUserImageUrl: 'assets/logo.webp',
                              isAdminMessage: true,
                            ),
                          ),
                        );
                      } else if (widget.senderId.isNotEmpty) {
                        nav.push(
                          MaterialPageRoute(
                            builder: (_) => MessageScreen(
                              otherUserId: widget.senderId,
                              otherUserName: widget.senderName.isNotEmpty ? widget.senderName : 'Kullanıcı',
                              otherUserImageUrl: widget.senderImageUrl,
                              initialDealTitle: widget.dealTitle,
                              initialDealId: widget.dealId,
                            ),
                          ),
                        );
                      } else {
                        NotificationService().handleNotificationTapPublic({
                          'type': 'message',
                        });
                      }
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        // Avatar
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: primaryColor.withValues(alpha: 0.3),
                              width: 1.5,
                            ),
                          ),
                          child: ClipOval(
                            child: _buildAvatar(widget.senderImageUrl, 44),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // İsim & Mesaj
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    widget.senderName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: isDark ? Colors.white : AppTheme.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: primaryColor.withValues(alpha: 0.15),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      'Yeni Mesaj',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: primaryColor,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.messageText,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        // Kapat Butonu
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                          onPressed: _dismiss,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(String imageUrl, double size) {
    final cleanUrl = migrateAssetPath(imageUrl);
    if (cleanUrl.isEmpty) {
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
      );
    }
    if (cleanUrl.startsWith('assets/')) {
      return Image.asset(cleanUrl, width: size, height: size, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: cleanUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[300]),
      errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.6, color: Colors.grey[400]),
    );
  }
}
