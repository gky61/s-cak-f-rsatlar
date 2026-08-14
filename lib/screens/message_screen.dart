import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/link_preview_service.dart';
import '../utils/asset_path_migration.dart';
import '../theme/app_theme.dart';
import '../widgets/report_dialog.dart';
import 'profile_screen.dart';
import 'deal_detail_screen.dart';

class AttachedDealInfo {
  final String id;
  final String title;
  final String? imageUrl;
  final String? price;
  final String? store;

  AttachedDealInfo({
    required this.id,
    required this.title,
    this.imageUrl,
    this.price,
    this.store,
  });
}

class MessageScreen extends StatefulWidget {
  final String otherUserId;
  final String otherUserName;
  final String otherUserImageUrl;
  final bool isAdminMessage;
  final String? initialText;
  final String? initialDealTitle;
  final String? initialDealId;
  final String? initialDealImageUrl;
  final String? initialDealPrice;
  final String? initialDealStore;

  const MessageScreen({
    super.key,
    required this.otherUserId,
    required this.otherUserName,
    required this.otherUserImageUrl,
    this.isAdminMessage = false,
    this.initialText,
    this.initialDealTitle,
    this.initialDealId,
    this.initialDealImageUrl,
    this.initialDealPrice,
    this.initialDealStore,
  });

  @override
  State<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends State<MessageScreen> with TickerProviderStateMixin {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final LinkPreviewService _linkPreviewService = LinkPreviewService();

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();

  bool _isSending = false;
  bool _isBlockedByMe = false;
  bool _isMuted = false;
  int _messageLimit = 60;
  bool _isLoadingMore = false;

  final Set<String> _markedAsRead = {};
  Message? _replyingToMessage;
  final List<Message> _optimisticMessages = [];
  final Map<String, LinkPreviewResult?> _urlPreviews = {};

  Timer? _typingTimer;
  bool _isCurrentlyTyping = false;

  bool _showScrollToBottomBtn = false;
  int _newIncomingCount = 0;
  int _lastKnownMessageCount = 0;

  AttachedDealInfo? _attachedDeal;

  String _liveOtherUserImageUrl = '';
  String _liveOtherUserName = '';
  bool _liveIsUserDeleted = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _otherUserSubscription;

  Stream<DocumentSnapshot<Map<String, dynamic>>>? _otherUserStream;
  Stream<List<Message>>? _messagesStream;
  Stream<bool>? _typingStream;

  @override
  void initState() {
    super.initState();
    NotificationService.activeChatUserId = widget.otherUserId;

    _liveOtherUserImageUrl = widget.otherUserImageUrl;
    _liveOtherUserName = widget.otherUserName;

    if (widget.initialDealId != null && widget.initialDealId!.isNotEmpty) {
      _attachedDeal = AttachedDealInfo(
        id: widget.initialDealId!,
        title: widget.initialDealTitle ?? 'Fırsat',
        imageUrl: widget.initialDealImageUrl,
        price: widget.initialDealPrice,
        store: widget.initialDealStore,
      );
    }

    if (widget.initialText != null && widget.initialText!.isNotEmpty) {
      _messageController.text = widget.initialText!;
    }

    _checkBlockAndMuteStatus();
    _initStreams();

    _scrollController.addListener(_handleScroll);
    _messageController.addListener(_onTextChanged);
  }

  void _initStreams() {
    final currentUserId = _authService.currentUser?.uid;

    if (!widget.isAdminMessage && widget.otherUserId.isNotEmpty) {
      _otherUserStream = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUserId)
          .snapshots();

      _otherUserSubscription?.cancel();
      _otherUserSubscription = _otherUserStream?.listen((snapshot) {
        if (mounted) {
          if (snapshot.exists && snapshot.data() != null) {
            final data = snapshot.data()!;
            final img = data['profileImageUrl'] ?? '';
            final name = data['username'] ?? data['displayName'] ?? '';
            setState(() {
              _liveOtherUserImageUrl = migrateAssetPath(img.toString());
              _liveOtherUserName = name.toString();
              _liveIsUserDeleted = false;
            });
          } else {
            setState(() {
              _liveIsUserDeleted = true;
              _liveOtherUserName = 'Silinmiş Kullanıcı';
              _liveOtherUserImageUrl = '';
            });
          }
        }
      });

      if (currentUserId != null) {
        _typingStream = _firestoreService.getTypingStream(
          currentUserId: currentUserId,
          otherUserId: widget.otherUserId,
        );
      }
    }

    _updateMessagesStream();
  }

  void _updateMessagesStream() {
    final currentUserId = _authService.currentUser?.uid;
    if (widget.isAdminMessage) {
      _messagesStream = FirebaseFirestore.instance
          .collection('adminToUserMessages')
          .where('userId', isEqualTo: currentUserId)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => Message.fromAdminFirestore(d)).toList();
        list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return list;
      });
    } else if (currentUserId != null) {
      _messagesStream = _firestoreService.getConversationStream(
        currentUserId,
        widget.otherUserId,
        limit: _messageLimit,
      );
    } else {
      _messagesStream = Stream.value([]);
    }
  }

  Future<void> _checkBlockAndMuteStatus() async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null || widget.isAdminMessage) return;

    final isBlocked = await _firestoreService.isUserBlockedForChat(currentUserId, widget.otherUserId);
    final isMuted = await _firestoreService.isConversationMuted(currentUserId, widget.otherUserId);

    if (mounted) {
      setState(() {
        _isBlockedByMe = isBlocked;
        _isMuted = isMuted;
      });
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) return;
    final currentOffset = _scrollController.position.pixels;

    // reverse: true -> 0.0 en alt (en yeni mesaj) demektir.
    final shouldShowBtn = currentOffset > 180;
    if (shouldShowBtn != _showScrollToBottomBtn) {
      setState(() {
        _showScrollToBottomBtn = shouldShowBtn;
        if (!shouldShowBtn) _newIncomingCount = 0;
      });
    }

    // reverse: true -> maxScrollExtent en üst (en eski mesajlar) demektir.
    if (currentOffset > _scrollController.position.maxScrollExtent - 250 &&
        !_isLoadingMore &&
        _lastKnownMessageCount >= _messageLimit) {
      _isLoadingMore = true;
      _messageLimit += 40;
      _updateMessagesStream();
      setState(() {});
      Future.delayed(const Duration(milliseconds: 600), () {
        if (mounted) setState(() => _isLoadingMore = false);
      });
    }
  }

  void _onTextChanged() {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null || widget.isAdminMessage) return;

    final text = _messageController.text;
    if (text.isNotEmpty && !_isCurrentlyTyping) {
      _isCurrentlyTyping = true;
      _firestoreService.setTypingStatus(
        currentUserId: currentUserId,
        otherUserId: widget.otherUserId,
        isTyping: true,
      );
    }

    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      if (_isCurrentlyTyping && mounted) {
        _isCurrentlyTyping = false;
        _firestoreService.setTypingStatus(
          currentUserId: currentUserId,
          otherUserId: widget.otherUserId,
          isTyping: false,
        );
      }
    });
  }

  @override
  void dispose() {
    if (NotificationService.activeChatUserId == widget.otherUserId) {
      NotificationService.activeChatUserId = null;
    }
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId != null && !widget.isAdminMessage && widget.otherUserId.isNotEmpty) {
      _firestoreService.setTypingStatus(
        currentUserId: currentUserId,
        otherUserId: widget.otherUserId,
        isTyping: false,
      );
      _firestoreService.markConversationAsRead(currentUserId, widget.otherUserId);
    }
    _otherUserSubscription?.cancel();
    _typingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _markMessagesAsRead(List<Message> messages) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    if (!widget.isAdminMessage && widget.otherUserId.isNotEmpty) {
      _firestoreService.markConversationAsRead(currentUserId, widget.otherUserId);
    }

    for (final message in messages) {
      if (!message.isRead && !_markedAsRead.contains(message.id)) {
        _markedAsRead.add(message.id);
        if (message.isAdminMessage) {
          await _firestoreService.markAdminToUserMessageAsRead(message.id);
        } else if (message.receiverId == currentUserId) {
          await _firestoreService.markMessageAsRead(message.id);
        }
      }
    }
  }

  void _scrollToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    if (animated) {
      _scrollController.animateTo(
        0.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
      );
    } else {
      _scrollController.jumpTo(0.0);
    }
    setState(() => _newIncomingCount = 0);
  }

  Future<void> _sendMessage({String? quickText}) async {
    if (widget.isAdminMessage || _isBlockedByMe) return;

    final rawText = (quickText ?? _messageController.text).trim();
    if (rawText.isEmpty || _isSending) return;

    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Mesaj göndermek için giriş yapmalısınız'),
          backgroundColor: Colors.orange[800],
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final reply = _replyingToMessage;
    final attached = _attachedDeal;
    final dealId = attached?.id;
    final dealTitle = attached?.title;
    final dealImage = attached?.imageUrl;
    final dealPrice = attached?.price;
    final dealStore = attached?.store;

    // Optimistic Message Oluştur (Anında ekranda göster)
    final tempId = 'optimistic_${DateTime.now().millisecondsSinceEpoch}';
    final optimisticMsg = Message(
      id: tempId,
      senderId: currentUserId,
      senderName: _authService.currentUser?.displayName ?? 'Ben',
      senderImageUrl: _authService.currentUser?.photoURL ?? '',
      receiverId: widget.otherUserId,
      receiverName: widget.otherUserName,
      receiverImageUrl: widget.otherUserImageUrl,
      text: rawText,
      createdAt: DateTime.now(),
      isRead: false,
      dealId: dealId,
      dealTitle: dealTitle,
      dealImageUrl: dealImage,
      dealPrice: dealPrice,
      dealStore: dealStore,
      replyToMessageId: reply?.id,
      replyToSenderName: reply?.senderName,
      replyToText: reply != null ? (reply.text.length > 80 ? '${reply.text.substring(0, 80)}...' : reply.text) : null,
      status: 'sending',
    );

    HapticFeedback.lightImpact();
    setState(() {
      _optimisticMessages.insert(0, optimisticMsg);
      _replyingToMessage = null;
      _attachedDeal = null; // Mesaja iliştirildi, çubuğu temizle
      _isSending = true;
    });

    if (quickText == null) {
      _messageController.clear();
    }

    // reverse: true olduğu için en alta gitmek = 0.0'a gitmektir
    _scrollToBottom(animated: true);

    // Arka planda URL varsa Link Preview önbelleğe al
    _detectAndFetchUrlPreview(rawText);

    try {
      final docId = await _firestoreService.sendMessage(
        senderId: currentUserId,
        receiverId: widget.otherUserId,
        text: rawText,
        dealId: dealId,
        dealTitle: dealTitle,
        dealImageUrl: dealImage,
        dealPrice: dealPrice,
        dealStore: dealStore,
        replyToMessageId: reply?.id,
        replyToSenderName: reply?.senderName,
        replyToText: reply != null ? (reply.text.length > 80 ? '${reply.text.substring(0, 80)}...' : reply.text) : null,
      );

      if (mounted) {
        if (docId == null) {
          // Başarısız -> status: 'failed'
          setState(() {
            final idx = _optimisticMessages.indexWhere((m) => m.id == tempId);
            if (idx != -1) {
              _optimisticMessages[idx] = _optimisticMessages[idx].copyWith(status: 'failed');
            }
            _isSending = false;
          });
        } else {
          // Başarılı -> Optimistic listeden çıkar (Firestore stream'e geçti)
          setState(() {
            _optimisticMessages.removeWhere((m) => m.id == tempId);
            _isSending = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _optimisticMessages.indexWhere((m) => m.id == tempId);
          if (idx != -1) {
            _optimisticMessages[idx] = _optimisticMessages[idx].copyWith(status: 'failed');
          }
          _isSending = false;
        });
      }
    }
  }

  void _detectAndFetchUrlPreview(String text) {
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final match = urlRegex.firstMatch(text);
    if (match != null) {
      final url = match.group(0)!;
      if (!_urlPreviews.containsKey(url)) {
        _linkPreviewService.fetchMetadata(url).then((preview) {
          if (mounted && preview != null) {
            setState(() {
              _urlPreviews[url] = preview;
            });
          }
        }).catchError((_) {});
      }
    }
  }

  void _showMessageOptionsModal(Message message, bool isMe) {
    if (widget.isAdminMessage) return;
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUserId = _authService.currentUser?.uid;

    final diffMinutes = DateTime.now().difference(message.createdAt).inMinutes;
    final canDeleteForEveryone = isMe && diffMinutes <= 15;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Tutamaç (Handle)
                Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Mesaj Önizleme
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F3F5),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[300]!,
                    ),
                  ),
                  child: Text(
                    message.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[300] : Colors.grey[800],
                    ),
                  ),
                ),
                // 1. Kopyala
                ListTile(
                  leading: Icon(Icons.copy_rounded, color: primaryColor),
                  title: const Text('Metni Kopyala', style: TextStyle(fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: message.text));
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('📋 Mesaj panoya kopyalandı'),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        margin: const EdgeInsets.all(16),
                      ),
                    );
                  },
                ),
                // 2. Yanıtla / Alıntı
                ListTile(
                  leading: Icon(Icons.reply_rounded, color: primaryColor),
                  title: const Text('Yanıtla', style: TextStyle(fontWeight: FontWeight.w600)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingToMessage = message;
                    });
                    _focusNode.requestFocus();
                  },
                ),
                // 3. Benden Sil (Soft Delete)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded, color: Colors.orange),
                  title: const Text('Benden Sil', style: TextStyle(color: Colors.orange, fontWeight: FontWeight.w600)),
                  subtitle: const Text('Sadece sizin sohbet geçmişinizden silinir', style: TextStyle(fontSize: 11)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    if (currentUserId != null) {
                      await _firestoreService.softDeleteMessageForUser(message.id, currentUserId);
                    }
                  },
                ),
                // 4. Herkesten Sil (15 Dakika kuralı)
                if (canDeleteForEveryone)
                  ListTile(
                    leading: const Icon(Icons.delete_forever_rounded, color: Colors.red),
                    title: const Text('Herkesten Sil (Geri Al)', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600)),
                    subtitle: Text('İlk 15 dakika içinde silinebilir (${15 - diffMinutes} dk kaldı)', style: const TextStyle(fontSize: 11)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      final ok = await _firestoreService.deleteMessageForEveryone(message.id, currentUserId!);
                      if (!ok && mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Süre dolduğu için herkesten silinemedi.')),
                        );
                      }
                    },
                  ),
                // 5. Şikayet Et
                if (!isMe)
                  ListTile(
                    leading: const Icon(Icons.flag_outlined, color: Colors.redAccent),
                    title: const Text('Mesajı Şikayet Et', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    onTap: () {
                      Navigator.pop(ctx);
                      showReportDialog(
                        context,
                        reportedId: message.id,
                        type: 'message',
                      );
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAppBarOverflowMenu() {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null || widget.isAdminMessage) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).brightness == Brightness.dark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline_rounded),
                title: const Text('Profili Görüntüle'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.otherUserId)));
                },
              ),
              ListTile(
                leading: Icon(_isMuted ? Icons.notifications_active_outlined : Icons.notifications_off_outlined),
                title: Text(_isMuted ? 'Bildirimleri Aç' : 'Sohbeti Sessize Al 🔕'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _firestoreService.toggleMuteConversation(currentUserId, widget.otherUserId, !_isMuted);
                  setState(() => _isMuted = !_isMuted);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(_isMuted ? '🔕 Sohbet sessize alındı' : '🔔 Bildirimler açıldı')),
                    );
                  }
                },
              ),
              ListTile(
                leading: Icon(_isBlockedByMe ? Icons.lock_open_rounded : Icons.block_rounded, color: Colors.orange),
                title: Text(_isBlockedByMe ? 'Engeli Kaldır' : 'Kullanıcıyı Engelle 🚫', style: const TextStyle(color: Colors.orange)),
                onTap: () async {
                  Navigator.pop(ctx);
                  if (_isBlockedByMe) {
                    await _firestoreService.unblockUserForChat(currentUserId, widget.otherUserId);
                    setState(() => _isBlockedByMe = false);
                  } else {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (c) => AlertDialog(
                        title: const Text('Kullanıcıyı Engelle'),
                        content: Text('${widget.otherUserName} kullanıcısını engellemek istediğinize emin misiniz?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Vazgeç')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                            onPressed: () => Navigator.pop(c, true),
                            child: const Text('Engelle'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await _firestoreService.blockUserForChat(currentUserId, widget.otherUserId);
                      setState(() => _isBlockedByMe = true);
                    }
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.flag_outlined, color: Colors.red),
                title: const Text('Kullanıcıyı Şikayet Et', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  showReportDialog(
                    context,
                    reportedId: widget.otherUserId,
                    type: 'user',
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUserId = _authService.currentUser?.uid;
    final textMain = isDark ? Colors.white : AppTheme.textPrimary;
    final textSub = isDark ? Colors.grey[400] : AppTheme.textSecondary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? AppTheme.darkBackground : const Color(0xFFF6F8FA),
      appBar: AppBar(
        backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
        foregroundColor: textMain,
        elevation: 0,
        titleSpacing: 0,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: _otherUserStream,
          builder: (context, otherUserSnapshot) {
            String otherUserImageUrl = widget.otherUserImageUrl;
            String otherUserName = widget.otherUserName;
            bool isUserDeleted = false;

            if (!widget.isAdminMessage) {
              if (otherUserSnapshot.hasData && otherUserSnapshot.data!.exists) {
                final data = otherUserSnapshot.data!.data();
                otherUserImageUrl = migrateAssetPath(data?['profileImageUrl'] ?? otherUserImageUrl);
                otherUserName = data?['username'] ?? data?['displayName'] ?? otherUserName;
              } else if (otherUserSnapshot.connectionState == ConnectionState.active &&
                  (!otherUserSnapshot.hasData || !otherUserSnapshot.data!.exists)) {
                isUserDeleted = true;
                otherUserName = 'Silinmiş Kullanıcı';
                otherUserImageUrl = '';
              }
            }

            return InkWell(
              onTap: widget.isAdminMessage || isUserDeleted
                  ? null
                  : () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProfileScreen(userId: widget.otherUserId)),
                      );
                    },
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: ClipOval(
                        child: widget.isAdminMessage
                            ? Container(
                                color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                child: Icon(Icons.shield_outlined, color: primaryColor, size: 22),
                              )
                            : _buildAvatar(otherUserImageUrl, 40, isDeleted: isUserDeleted),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.isAdminMessage ? 'FırsatKolik Yönetim' : otherUserName,
                                  style: TextStyle(
                                    fontSize: 15.5,
                                    fontWeight: FontWeight.w700,
                                    color: textMain,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (widget.isAdminMessage) ...[
                                const SizedBox(width: 5),
                                Icon(Icons.verified_user_rounded, color: primaryColor, size: 15),
                              ],
                              if (_isMuted) ...[
                                const SizedBox(width: 5),
                                Icon(Icons.notifications_off_outlined, size: 14, color: textSub),
                              ],
                            ],
                          ),
                          // Typing veya Durum
                          if (!widget.isAdminMessage && currentUserId != null)
                            StreamBuilder<bool>(
                              stream: _typingStream,
                              builder: (context, typingSnap) {
                                final isTyping = typingSnap.data == true;
                                if (isTyping) {
                                  return Row(
                                    children: [
                                      Text(
                                        'yazıyor',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: primaryColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      _buildAnimatedTypingDots(primaryColor),
                                    ],
                                  );
                                }

                                if (isUserDeleted) {
                                  return Row(
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        decoration: const BoxDecoration(
                                          color: Colors.grey,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Hesap Silindi',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: textSub,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        actions: [
          if (!widget.isAdminMessage)
            IconButton(
              icon: const Icon(Icons.more_vert_rounded),
              onPressed: _showAppBarOverflowMenu,
            ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // Mesaj Akışı (REVERSE: TRUE - SIFIR TAKILMA VE DOĞAL AŞAĞIDAN BAŞLAMA)
              Expanded(
                child: StreamBuilder<List<Message>>(
                  stream: _messagesStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting && _lastKnownMessageCount == 0) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final serverMessages = snapshot.data ?? [];
                    _lastKnownMessageCount = serverMessages.length;

                    // Okundu olarak işaretle (Post Frame Callback ile güvenli)
                    if (serverMessages.isNotEmpty) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) _markMessagesAsRead(serverMessages);
                      });
                    }

                    // Optimistic mesajları server mesajları ile birleştir
                    // Dedup: 'sending' durumundaki optimistic mesajı, aynı içerikte server mesajı zaten varsa ekleme
                    // (Firestore stream, sendMessage'ın docId dönüşünden önce yayınlayabilir → anlık çift görünme önlemi)
                    final Map<String, Message> mergedMap = {};
                    for (var m in serverMessages) {
                      mergedMap[m.id] = m;
                    }
                    for (var m in _optimisticMessages) {
                      if (m.status == 'sending') {
                        final hasDuplicate = serverMessages.any((sm) =>
                          sm.senderId == m.senderId &&
                          sm.text == m.text &&
                          sm.createdAt.difference(m.createdAt).inSeconds.abs() < 30
                        );
                        if (hasDuplicate) continue; // Server zaten bu mesajı yayınladı, optimistic kopyayı atla
                      }
                      mergedMap[m.id] = m;
                    }
                    // reverse: true için YENİDEN ESKİYE (Descending) sıralama
                    final allMessages = mergedMap.values.toList()
                      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

                    if (allMessages.isEmpty) {
                      return _buildEmptyState(widget.otherUserName, widget.otherUserImageUrl, isDark, primaryColor, textMain, textSub);
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      reverse: true, // EN ÖNEMLİ UX GELİŞTİRMESİ: Doğal olarak en son mesajdan başlar
                      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      itemCount: allMessages.length + (_isLoadingMore ? 1 : 0),
                      itemBuilder: (context, index) {
                        // Eski mesajları yukarı kaydırınca en üstte (reverse: true olduğu için listenin sonunda) loading döner
                        if (_isLoadingMore && index == allMessages.length) {
                          return const Center(
                            child: Padding(
                              padding: EdgeInsets.all(12.0),
                              child: SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                          );
                        }

                        final message = allMessages[index];
                        final isMe = !message.isAdminMessage && message.senderId == currentUserId;

                        // Tarih ayracı kontrolü (reverse: true için bir önceki gün kontrolü)
                        final bool showDate = index == allMessages.length - 1 ||
                            allMessages[index].createdAt.day != allMessages[index + 1].createdAt.day ||
                            allMessages[index].createdAt.month != allMessages[index + 1].createdAt.month ||
                            allMessages[index].createdAt.year != allMessages[index + 1].createdAt.year;

                        return Column(
                          children: [
                            if (showDate) _buildDateBadge(message.createdAt, isDark),
                            _buildMessageRow(message, isMe, isDark, primaryColor, surfaceColor, textMain, textSub),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              // Alt Giriş Alanı / Kilitli Durum
              _buildBottomBar(isDark, primaryColor, surfaceColor, textMain, textSub),
            ],
          ),

          // "1 Yeni Mesaj ↓" Floating Butonu (reverse: true ile 0.0'a iner)
          if (_showScrollToBottomBtn)
            Positioned(
              right: 16,
              bottom: 84,
              child: FloatingActionButton.extended(
                onPressed: () => _scrollToBottom(animated: true),
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                elevation: 6,
                icon: const Icon(Icons.arrow_downward_rounded, size: 18),
                label: Text(
                  _newIncomingCount > 0 ? '$_newIncomingCount Yeni Mesaj' : 'En Sona İn',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // --- WIDGET BUILDERS ---

  Widget _buildEmbeddedDealCard(
    Message message,
    bool isMe,
    bool isDark,
    Color primaryColor,
  ) {
    final cardBg = isMe
        ? (isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.18))
        : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF1F3F5));
    final borderColor = isMe
        ? Colors.white.withValues(alpha: 0.15)
        : (isDark ? Colors.white.withValues(alpha: 0.12) : Colors.black.withValues(alpha: 0.06));
    final titleColor = isMe ? Colors.white : (isDark ? Colors.white : AppTheme.textPrimary);
    final badgeTextColor = isMe ? Colors.white : primaryColor;
    final priceColor = isMe ? const Color(0xFFFFD166) : primaryColor;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => DealDetailScreen(dealId: message.dealId!),
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Fırsat Görseli
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    width: 52,
                    height: 52,
                    color: isDark ? Colors.grey[850] : Colors.grey[200],
                    child: message.dealImageUrl != null && message.dealImageUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: message.dealImageUrl!,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              color: isDark ? Colors.grey[800] : Colors.grey[300],
                              child: const Center(
                                child: SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 1.5),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Icon(Icons.local_offer_outlined, color: primaryColor, size: 22),
                          )
                        : Icon(Icons.local_offer_outlined, color: primaryColor, size: 22),
                  ),
                ),
                const SizedBox(width: 10),
                // Bilgiler (Badge, Başlık, Fiyat)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: isMe
                                  ? Colors.white.withValues(alpha: 0.15)
                                  : primaryColor.withValues(alpha: isDark ? 0.25 : 0.12),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.local_offer_rounded, size: 10, color: badgeTextColor),
                                const SizedBox(width: 3),
                                Text(
                                  'İlgili Fırsat',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w700,
                                    color: badgeTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (message.dealStore != null && message.dealStore!.isNotEmpty) ...[
                            const SizedBox(width: 5),
                            Flexible(
                              child: Text(
                                '• ${message.dealStore}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w500,
                                  color: isMe
                                      ? Colors.white.withValues(alpha: 0.8)
                                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        message.dealTitle ?? 'Fırsat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: titleColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (message.dealPrice != null && message.dealPrice!.isNotEmpty)
                            Text(
                              '${message.dealPrice} TL',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: priceColor,
                              ),
                            )
                          else
                            const SizedBox.shrink(),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Fırsata Git',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: isMe ? Colors.white.withValues(alpha: 0.9) : primaryColor,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.arrow_forward_ios_rounded,
                                size: 9,
                                color: isMe ? Colors.white.withValues(alpha: 0.9) : primaryColor,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    String otherUserName,
    String otherUserImageUrl,
    bool isDark,
    Color primaryColor,
    Color textMain,
    Color? textSub,
  ) {
    final displayName = _liveOtherUserName.isNotEmpty ? _liveOtherUserName : otherUserName;
    final displayImageUrl = _liveIsUserDeleted
        ? ''
        : (_liveOtherUserImageUrl.isNotEmpty ? _liveOtherUserImageUrl : otherUserImageUrl);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primaryColor.withValues(alpha: isDark ? 0.18 : 0.08),
                border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: isDark ? 0.25 : 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: ClipOval(
                child: _buildAvatar(displayImageUrl, 88, isDeleted: _liveIsUserDeleted),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              displayName,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: textMain),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                  width: 1,
                ),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.waving_hand_rounded, size: 16, color: primaryColor),
                      const SizedBox(width: 6),
                      Text(
                        'Sohbete Başla',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: textMain,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Bu kullanıcıyla henüz bir mesajlaşmanız bulunmuyor.\nAşağıdaki kutudan mesajınızı yazarak sohbeti başlatabilirsiniz.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: textSub,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 13, color: textSub?.withValues(alpha: 0.8)),
                const SizedBox(width: 5),
                Text(
                  'Mesajlarınız güvenle iletilir.',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w500,
                    color: textSub?.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateBadge(DateTime date, bool isDark) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey[200],
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          _formatDate(date),
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildMessageRow(
    Message message,
    bool isMe,
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color textMain,
    Color? textSub,
  ) {
    // Gönderilen mesajlar için uygulamanın koyu kahvemsi/antrasit rengi (AppTheme.accent 0xFF2D3436)
    final myBubbleColor = isDark ? const Color(0xFF2D3436) : AppTheme.accent;
    final otherBubbleColor = isDark ? const Color(0xFF1E242B) : Colors.white;
    const myTextColor = Colors.white;
    final otherTextColor = isDark ? const Color(0xFFF8FAFC) : AppTheme.textPrimary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(
                child: widget.isAdminMessage
                    ? Container(
                        color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                        child: Icon(Icons.shield_outlined, color: primaryColor, size: 18),
                      )
                    : _buildAvatar(
                        _liveIsUserDeleted
                            ? ''
                            : (_liveOtherUserImageUrl.isNotEmpty
                                ? _liveOtherUserImageUrl
                                : (message.senderImageUrl.isNotEmpty
                                    ? message.senderImageUrl
                                    : widget.otherUserImageUrl)),
                        32,
                        isDeleted: _liveIsUserDeleted,
                      ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptionsModal(message, isMe),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: isMe ? myBubbleColor : otherBubbleColor,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(18),
                    topRight: const Radius.circular(18),
                    bottomLeft: Radius.circular(isMe ? 18 : 4),
                    bottomRight: Radius.circular(isMe ? 4 : 18),
                  ),
                  border: Border.all(
                    color: isMe
                        ? (isDark ? Colors.white.withValues(alpha: 0.15) : Colors.black.withValues(alpha: 0.08))
                        : (isDark
                            ? Colors.white.withValues(alpha: 0.08)
                            : Colors.black.withValues(alpha: 0.06)),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                  children: [
                    // Alıntı Önizleme Bloğu
                    if (message.replyToSenderName != null && message.replyToText != null)
                      _buildQuotedBlock(message.replyToSenderName!, message.replyToText!, isMe, isDark, primaryColor),

                    // Gömülü Fırsat Kartı (Deal Context)
                    if (message.dealId != null && message.dealId!.isNotEmpty)
                      _buildEmbeddedDealCard(message, isMe, isDark, primaryColor),

                    // Mesaj Metni (Keskin, net ve yüksek kontrastlı)
                    Text(
                      message.text,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.35,
                        fontWeight: FontWeight.w500,
                        color: isMe ? myTextColor : otherTextColor,
                      ),
                    ),

                    // Rich Link Preview
                    _buildLinkPreviewSection(message.text, isMe, isDark, surfaceColor, primaryColor),

                    const SizedBox(height: 4),

                    // Saat & Durum İkonu
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w500,
                            color: isMe ? Colors.white.withValues(alpha: 0.82) : (isDark ? Colors.grey[400] : textSub),
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 4),
                          _buildStatusIcon(message),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildQuotedBlock(
    String senderName,
    String snippet,
    bool isMe,
    bool isDark,
    Color primaryColor,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.black.withValues(alpha: 0.22)
            : (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05)),
        borderRadius: BorderRadius.circular(10),
        border: Border(
          left: BorderSide(
            color: isMe ? Colors.white.withValues(alpha: 0.85) : (isDark ? const Color(0xFFFF8A65) : primaryColor),
            width: 3,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: isMe ? Colors.white : (isDark ? const Color(0xFFFF8A65) : primaryColor),
            ),
          ),
          const SizedBox(height: 1),
          Text(
            snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11.5,
              fontStyle: FontStyle.italic,
              color: isMe ? Colors.white.withValues(alpha: 0.9) : (isDark ? Colors.grey[300] : Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkPreviewSection(
    String text,
    bool isMe,
    bool isDark,
    Color surfaceColor,
    Color primaryColor,
  ) {
    final urlRegex = RegExp(r'https?:\/\/[^\s]+');
    final match = urlRegex.firstMatch(text);
    if (match == null) return const SizedBox.shrink();

    final url = match.group(0)!;
    final preview = _urlPreviews[url];
    if (preview == null || preview.title == null || preview.title!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: isMe ? Colors.black.withValues(alpha: 0.25) : (isDark ? Colors.black.withValues(alpha: 0.3) : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            final uri = Uri.tryParse(url);
            if (uri != null && await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                if (preview.imageUrl != null && preview.imageUrl!.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CachedNetworkImage(
                      imageUrl: preview.imageUrl!,
                      width: 42,
                      height: 42,
                      fit: BoxFit.cover,
                    ),
                  ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preview.title ?? '',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isMe ? Colors.white : (isDark ? Colors.white : AppTheme.textPrimary),
                        ),
                      ),
                      if (preview.provider != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          preview.provider!,
                          style: TextStyle(
                            fontSize: 10,
                            color: isMe ? Colors.white.withValues(alpha: 0.75) : Colors.grey[400],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.open_in_new_rounded,
                  size: 14,
                  color: isMe ? Colors.white.withValues(alpha: 0.9) : (isDark ? const Color(0xFFFF8A65) : primaryColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIcon(Message message) {
    if (message.status == 'sending') {
      return const Icon(Icons.access_time_rounded, size: 13, color: Colors.white70);
    }
    if (message.status == 'failed') {
      return const Icon(Icons.error_outline_rounded, size: 13, color: Colors.amberAccent);
    }
    if (message.isRead) {
      return const Icon(Icons.done_all_rounded, size: 14, color: Colors.white);
    }
    return Icon(Icons.done_rounded, size: 14, color: Colors.white.withValues(alpha: 0.85));
  }

  Widget _buildAnimatedTypingDots(Color color) {
    return SizedBox(
      width: 24,
      height: 12,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(3, (index) {
          return Container(
            width: 4,
            height: 4,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          );
        }),
      ),
    );
  }

  Widget _buildBottomBar(
    bool isDark,
    Color primaryColor,
    Color surfaceColor,
    Color textMain,
    Color? textSub,
  ) {
    if (_isBlockedByMe) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        color: surfaceColor,
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Bu kullanıcıyı engellediniz.',
                style: TextStyle(color: textSub, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              TextButton(
                onPressed: () async {
                  final uid = _authService.currentUser?.uid;
                  if (uid != null) {
                    await _firestoreService.unblockUserForChat(uid, widget.otherUserId);
                    setState(() => _isBlockedByMe = false);
                  }
                },
                child: const Text('Engeli Kaldır', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      );
    }

    if (widget.isAdminMessage) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: surfaceColor,
        child: SafeArea(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F3F5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded, size: 15, color: textSub),
                const SizedBox(width: 8),
                Text(
                  'Resmi Yönetici Bildirimi (Yanıt verilemez)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textSub),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: surfaceColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Yanıtlama / Alıntı Barı
            if (_replyingToMessage != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.grey[100],
                  borderRadius: BorderRadius.circular(12),
                  border: Border(left: BorderSide(color: primaryColor, width: 3.5)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.reply_rounded, size: 16, color: primaryColor),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _replyingToMessage!.senderName,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: primaryColor),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _replyingToMessage!.text,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11.5, color: textSub),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => setState(() => _replyingToMessage = null),
                      borderRadius: BorderRadius.circular(16),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(Icons.close_rounded, size: 16, color: textSub),
                      ),
                    ),
                  ],
                ),
              ),

            // Ekli Fırsat Önizleme Barı (Attachment Bar)
            if (_attachedDeal != null)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.07) : primaryColor.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: isDark ? 0.3 : 0.25),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 40,
                        height: 40,
                        color: isDark ? Colors.grey[800] : Colors.grey[200],
                        child: _attachedDeal!.imageUrl != null && _attachedDeal!.imageUrl!.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: _attachedDeal!.imageUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(Icons.local_offer_outlined, color: primaryColor, size: 18),
                              )
                            : Icon(Icons.local_offer_outlined, color: primaryColor, size: 18),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '📌 İlgili Fırsat Ekli',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: primaryColor,
                                ),
                              ),
                              if (_attachedDeal!.store != null && _attachedDeal!.store!.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '• ${_attachedDeal!.store}',
                                  style: TextStyle(fontSize: 10.5, color: textSub, fontWeight: FontWeight.w500),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _attachedDeal!.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      color: textSub,
                      splashRadius: 18,
                      tooltip: 'Fırsatı Kaldır',
                      onPressed: () {
                        setState(() => _attachedDeal = null);
                      },
                    ),
                  ],
                ),
              ),

            // Mesaj Giriş Alanı (Auto-expanding 1-5 lines)
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F3F5),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[300]!,
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      maxLines: 5,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: textMain, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Bir mesaj yazın...',
                        hintStyle: TextStyle(color: textSub?.withValues(alpha: 0.7), fontSize: 13.5),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: _isSending ? null : () => _sendMessage(),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: primaryColor,
                      shape: BoxShape.circle,
                    ),
                    child: _isSending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(date.year, date.month, date.day);

    if (messageDate == today) {
      return 'Bugün';
    } else if (messageDate == today.subtract(const Duration(days: 1))) {
      return 'Dün';
    } else {
      return DateFormat('d MMMM yyyy', 'tr_TR').format(date);
    }
  }

  String _formatTime(DateTime date) {
    return DateFormat('HH:mm', 'tr_TR').format(date);
  }

  Widget _buildAvatar(String imageUrl, double size, {bool isDeleted = false}) {
    if (isDeleted || imageUrl.isEmpty || imageUrl == 'assets/kullanıcı pp.jpg') {
      return Container(
        color: Colors.grey[300],
        child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
      );
    }
    if (imageUrl.startsWith('assets/')) {
      return Image.asset(imageUrl, width: size, height: size, fit: BoxFit.cover);
    }
    return CachedNetworkImage(
      imageUrl: imageUrl,
      width: size,
      height: size,
      fit: BoxFit.cover,
      placeholder: (_, __) => Container(color: Colors.grey[300]),
      errorWidget: (_, __, ___) => Icon(Icons.person, size: size * 0.6, color: Colors.grey[400]),
    );
  }
}
