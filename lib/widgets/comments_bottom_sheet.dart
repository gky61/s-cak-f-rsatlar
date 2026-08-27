import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/deal.dart';
import '../models/comment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/badge_helper.dart';
import '../utils/asset_path_migration.dart';
import '../theme/app_theme.dart';
import '../widgets/report_dialog.dart';
import '../widgets/guest_login_bottom_sheet.dart';
import '../widgets/skeletons/comments_skeleton.dart';
import '../widgets/swipe_to_reply.dart';
import '../widgets/reaction_picker_sheet.dart';
import '../screens/profile_screen.dart';

void _log(String message) {
  if (kDebugMode) print(message);
}

class CommentsBottomSheet extends StatefulWidget {
  final Deal deal;
  final String? scrollToCommentId; // Belirli bir yoruma scroll etmek için

  const CommentsBottomSheet({
    super.key,
    required this.deal,
    this.scrollToCommentId,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  bool _isSubmitting = false;
  bool _isAdmin = false;
  Comment? _replyingTo; // Cevap verilen yorum
  ScrollController? _scrollController; // Yorum listesi scroll controller'ı
  final Map<String, GlobalKey> _commentKeys = {}; // Yorum ID'leri için GlobalKey'ler
  bool _hasScrolledToComment = false; // Belirli bir yoruma scroll edildi mi?

  StreamSubscription? _authSub;

  @override
  void initState() {
    super.initState();
    _checkAdminStatus();
    _authSub = _authService.authStateChanges.listen((user) {
      if (mounted) {
        _checkAdminStatus();
        setState(() {});
      }
    });
  }

  Future<void> _checkAdminStatus() async {
    final isAdmin = await _authService.isAdmin();
    if (mounted) {
      setState(() {
        _isAdmin = isAdmin;
      });
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _commentController.dispose();
    _commentFocusNode.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen bir yorum yazın')),
      );
      return;
    }

    final user = _authService.currentUser;
    if (user == null) {
      final loggedIn = await showGuestLoginBottomSheet(
        context,
        title: 'Yorum Yapmak İçin Giriş Yap! 💬',
        message: 'Fırsat hakkındaki düşüncelerini paylaşmak ve diğer avcılarla tartışmak için hemen giriş yap.',
        primaryButtonText: '🚀 Google ile Giriş Yap',
      );
      if (loggedIn == true && mounted) {
        _checkAdminStatus();
        setState(() {});
        if (_commentController.text.trim().isNotEmpty) {
          _submitComment();
        }
      }
      return;
    }

    // Engellenen kullanıcı kontrolü
    final isBlocked = await _firestoreService.isUserBlocked(user.uid);
    if (isBlocked && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hesabınız engellenmiş. Yorum yapamazsınız.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    // Kullanıcının username'ini, profil resmini ve rozetlerini al
    String displayName = user.displayName ?? 'Kullanıcı';
    String profileImageUrl = '';
    List<String> userBadges = [];
    String? userPinnedBadge;
    try {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        // Firestore'daki username'i kullan (güncel kullanıcı adı)
        displayName = userData.username.isNotEmpty ? userData.username : userData.displayName;
        profileImageUrl = userData.profileImageUrl;
        userBadges = userData.badges;
        userPinnedBadge = userData.pinnedBadge;
        _log('🔍 Yorum eklerken rozetler alındı: ${userBadges.length} rozet - vitrin: $userPinnedBadge');
      } else {
        _log('⚠️ getUserData null döndü');
      }
    } catch (e) {
      _log('❌ Kullanıcı bilgisi alınamadı: $e');
    }

    try {
      final success = await _firestoreService.addComment(
        dealId: widget.deal.id,
        userId: user.uid,
        userName: displayName,
        userEmail: user.email ?? '',
        text: _commentController.text.trim(),
        parentCommentId: _replyingTo?.id,
        replyToUserName: _replyingTo?.userName,
        quotedCommentText: _replyingTo?.text,
        userProfileImageUrl: profileImageUrl,
        userBadges: userBadges,
        userPinnedBadge: userPinnedBadge,
      );

      setState(() {
        _isSubmitting = false;
        _replyingTo = null; // Cevap verme durumunu sıfırla
      });

      if (success && mounted) {
        _commentController.clear();
        // Yorum eklendikten sonra state'i güncellemek için kısa bir bekleme
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Yeni yorum eklendikten sonra listeyi en alta kaydır
        if (_scrollController != null && _scrollController!.hasClients) {
          // Kısa bir gecikme ile scroll yap (yorum listesi güncellensin)
          Future.delayed(const Duration(milliseconds: 300), () {
            if (_scrollController != null && _scrollController!.hasClients) {
              _scrollController!.animateTo(
                _scrollController!.position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
          });
        }
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Yorumunuz eklendi'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorum eklenirken bir hata oluştu'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _replyingTo = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', '')),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        // Scroll controller'ı state'te sakla
        _scrollController = scrollController;
        
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final primaryColor = Theme.of(context).colorScheme.primary;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkBackground : AppTheme.background,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: Row(
                  children: [
                    Text(
                      'Yorumlar',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: isDark ? AppTheme.darkTextPrimary : AppTheme.accent,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Yorum listesi
              Expanded(
                child: StreamBuilder<List<Comment>>(
                  stream: _firestoreService.getCommentsStream(widget.deal.id),
                  builder: (context, snapshot) {
                    // İlk yükleme sırasında skeleton göster
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const CommentsSkeleton();
                    }

                    // Hata durumu
                    if (snapshot.hasError) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Text(
                                'Hata: ${snapshot.error}',
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Yorumları al
                    final comments = snapshot.data ?? [];

                    // Yorumlar boşsa
                    if (comments.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.comment_outlined,
                              size: 64,
                              color: isDark ? AppTheme.darkTextSecondary : Colors.grey[400],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Henüz yorum yok',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark ? AppTheme.darkTextPrimary : Colors.grey[600],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'İlk yorumu siz yapın!',
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? AppTheme.darkTextSecondary : Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    // Belirli bir yoruma scroll et (sadece bir kez)
                    if (widget.scrollToCommentId != null && 
                        !_hasScrolledToComment && 
                        comments.isNotEmpty &&
                        scrollController.hasClients) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        final targetIndex = comments.indexWhere(
                          (c) => c.id == widget.scrollToCommentId,
                        );
                        if (targetIndex != -1 && scrollController.hasClients) {
                          _hasScrolledToComment = true;
                          // Yorumun görünür olması için biraz yukarıdan başla
                          const itemHeight = 100.0; // Yaklaşık yorum yüksekliği
                          final targetOffset = (targetIndex * itemHeight).clamp(
                            0.0,
                            scrollController.position.maxScrollExtent,
                          );
                          scrollController.animateTo(
                            targetOffset,
                            duration: const Duration(milliseconds: 500),
                            curve: Curves.easeInOut,
                          );
                          _log('📍 Yorum cevabına scroll edildi: ${widget.scrollToCommentId}');
                        }
                      });
                    }

                    // Yorum listesi
                    return ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.all(12),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final comment = comments[index];
                        return _buildCommentItem(comment, _isAdmin, comments, scrollController);
                      },
                    );
                  },
                ),
              ),

              // Yorum ekleme formu - Klavye açıldığında görünür olması için padding eklendi
              Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewInsets.bottom,
                ),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppTheme.darkSurface : Colors.white,
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
                      ),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_replyingTo != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.05) 
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(10),
                              border: Border(
                                left: BorderSide(
                                  color: primaryColor,
                                  width: 4,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _replyingTo!.userName,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 12,
                                          color: primaryColor,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _replyingTo!.text,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: isDark ? Colors.grey[300] : Colors.grey[700],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.close, size: 18),
                                  onPressed: () {
                                    setState(() {
                                      _replyingTo = null;
                                    });
                                  },
                                  constraints: const BoxConstraints(),
                                  padding: EdgeInsets.zero,
                                ),
                              ],
                            ),
                          ),
                        ],
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                focusNode: _commentFocusNode,
                                controller: _commentController,
                                style: TextStyle(
                                  color: isDark ? AppTheme.darkTextPrimary : Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: _replyingTo != null 
                                      ? '@${_replyingTo!.userName} kullanıcısına cevap verin...' 
                                      : 'Yorumunuzu yazın...',
                                  hintStyle: TextStyle(
                                    color: isDark ? AppTheme.darkTextSecondary : Colors.grey[500],
                                  ),
                                  filled: true,
                                  fillColor: isDark ? AppTheme.darkBackground : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: isDark ? AppTheme.darkBorder : Colors.grey[300]!,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    borderSide: BorderSide(
                                      color: primaryColor,
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                ),
                                maxLines: null,
                                minLines: 1,
                                textInputAction: TextInputAction.newline,
                                keyboardType: TextInputType.multiline,
                                onSubmitted: (_) => _submitComment(),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              decoration: BoxDecoration(
                                color: primaryColor,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: _isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Icon(Icons.send_rounded, color: Colors.white),
                                onPressed: _isSubmitting ? null : _submitComment,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _scrollToComment(String commentId, List<Comment> allComments) {
    final key = _commentKeys[commentId];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    } else {
      final index = allComments.indexWhere((c) => c.id == commentId);
      if (index != -1 && _scrollController != null && _scrollController!.hasClients) {
        const double estimatedItemHeight = 90.0;
        final double targetOffset = (index * estimatedItemHeight).clamp(
          0.0,
          _scrollController!.position.maxScrollExtent,
        );
        _scrollController!.animateTo(
          targetOffset,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeInOut,
        );
      }
    }
  }

  String _getQuotedCommentText(Comment comment, List<Comment> allComments) {
    if (comment.quotedCommentText != null && comment.quotedCommentText!.isNotEmpty) {
      return comment.quotedCommentText!;
    }
    try {
      final original = allComments.firstWhere((c) => c.id == comment.parentCommentId);
      return original.text;
    } catch (_) {
      return 'Yoruma cevap verdi';
    }
  }

  Widget _buildQuoteBox(BuildContext context, Comment comment, List<Comment> allComments, bool isDark, Color primaryColor) {
    final quoteText = _getQuotedCommentText(comment, allComments);
    return GestureDetector(
      onTap: () => _scrollToComment(comment.parentCommentId!, allComments),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isDark 
              ? Colors.white.withValues(alpha: 0.04) 
              : Colors.grey[50],
          borderRadius: BorderRadius.circular(8),
          border: Border(
            left: BorderSide(
              color: primaryColor,
              width: 3.5,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              comment.replyToUserName!,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 11,
                color: primaryColor,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              quoteText,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.grey[400] : Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGuestLoginPrompt() {
    showGuestLoginBottomSheet(
      context,
      title: 'Tepki Ver',
      message: 'Yorumlara emoji tepkisi vermek için Giriş Yap! 🚀',
    );
  }

  void _toggleCommentReaction(String commentId, String emoji) {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      _showGuestLoginPrompt();
      return;
    }
    HapticFeedback.lightImpact();
    _firestoreService.toggleCommentReaction(
      dealId: widget.deal.id,
      commentId: commentId,
      userId: currentUserId,
      emoji: emoji,
    );
  }

  void _showCommentReactionPicker(Comment comment) {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      _showGuestLoginPrompt();
      return;
    }
    final myReaction = comment.reactions[currentUserId];

    showReactionPickerBottomSheet(
      context: context,
      title: 'Yoruma Tepki Ver',
      currentEmoji: myReaction,
      onEmojiSelected: (emoji) => _toggleCommentReaction(comment.id, emoji),
    );
  }

  void _showCommentOptionsModal(Comment comment, bool isOwnComment, bool isAdmin) {
    HapticFeedback.mediumImpact();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final currentUserId = _authService.currentUser?.uid;
    final myReaction = currentUserId != null ? comment.reactions[currentUserId] : null;

    const quickEmojis = ['👍', '❤️', '🔥', '😂', '😮', '😢'];

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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tutma Çubuğu
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Hızlı Emoji Barı (WhatsApp / Telegram Stili)
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ...quickEmojis.map((emoji) {
                        final isSelected = myReaction == emoji;
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.lightImpact();
                              Navigator.pop(ctx);
                              _toggleCommentReaction(comment.id, emoji);
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: isDark ? 0.35 : 0.2)
                                    : Colors.transparent,
                                shape: BoxShape.circle,
                                border: isSelected
                                    ? Border.all(color: primaryColor, width: 1.5)
                                    : null,
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 24),
                              ),
                            ),
                          ),
                        );
                      }),
                      // Daha Fazla Emoji (+) Butonu
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            Navigator.pop(ctx);
                            _showCommentReactionPicker(comment);
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.add_rounded,
                              size: 24,
                              color: isDark ? Colors.white70 : const Color(0xFF475569),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Yorum Önizleme Kutusu
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border(left: BorderSide(color: primaryColor, width: 3.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        comment.userName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        comment.text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? Colors.grey[300] : const Color(0xFF334155),
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),

                // İşlem Seçenekleri
                // 1. Metni Kopyala
                ListTile(
                  leading: const Icon(Icons.copy_rounded, size: 20),
                  title: const Text('Metni Kopyala', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: comment.text));
                    HapticFeedback.lightImpact();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Yorum metni kopyalandı 📋'),
                        duration: Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),

                // 2. Yanıtla
                ListTile(
                  leading: Icon(Icons.reply_rounded, color: primaryColor, size: 20),
                  title: Text(
                    'Yanıtla',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: primaryColor),
                  ),
                  dense: true,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      _replyingTo = comment;
                    });
                    _commentFocusNode.requestFocus();
                  },
                ),

                // 3. Yorumu Sil
                if (isOwnComment || isAdmin)
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                    title: const Text(
                      'Yorumu Sil',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                    ),
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _deleteComment(comment);
                    },
                  ),

                // 4. Kullanıcıyı Engelle (Admin)
                if (isAdmin && !isOwnComment)
                  ListTile(
                    leading: const Icon(Icons.block_rounded, color: Colors.orange, size: 20),
                    title: const Text(
                      'Kullanıcıyı Engelle',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.orange),
                    ),
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      Navigator.pop(ctx);
                      _blockUser(comment.userId, comment.userName);
                    },
                  ),

                // 5. Raporla
                if (!isOwnComment)
                  ListTile(
                    leading: const Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                    title: const Text(
                      'Raporla',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.red),
                    ),
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    onTap: () {
                      Navigator.pop(ctx);
                      showReportDialog(
                        context,
                        reportedId: comment.id,
                        type: 'comment',
                        targetDealId: widget.deal.id,
                        targetContent: comment.text,
                        targetAuthor: comment.userName,
                        targetAuthorId: comment.userId,
                      );
                    },
                  ),

                const SizedBox(height: 6),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentReactionChips(Comment comment, bool isDark, Color primaryColor, String? currentUserId) {
    if (comment.reactions.isEmpty) return const SizedBox.shrink();

    final Map<String, int> counts = {};
    for (var emoji in comment.reactions.values) {
      if (emoji.isNotEmpty) {
        counts[emoji] = (counts[emoji] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return const SizedBox.shrink();

    final myReaction = currentUserId != null ? comment.reactions[currentUserId] : null;

    return Container(
      margin: const EdgeInsets.only(top: 8),
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: counts.entries.map((entry) {
          final emoji = entry.key;
          final count = entry.value;
          final isMine = myReaction == emoji;

          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _toggleCommentReaction(comment.id, emoji),
              onLongPress: () => _showCommentReactionDetailsModal(comment),
              borderRadius: BorderRadius.circular(12),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                decoration: BoxDecoration(
                  color: isMine
                      ? (isDark ? primaryColor.withValues(alpha: 0.3) : primaryColor.withValues(alpha: 0.15))
                      : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isMine
                        ? primaryColor
                        : (isDark ? Colors.white.withValues(alpha: 0.12) : const Color(0xFFCBD5E1)),
                    width: isMine ? 1.2 : 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(emoji, style: const TextStyle(fontSize: 13)),
                    if (count > 1) ...[
                      const SizedBox(width: 4),
                      Text(
                        '$count',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isMine ? FontWeight.w800 : FontWeight.w600,
                          color: isMine
                              ? (isDark ? Colors.white : primaryColor)
                              : (isDark ? Colors.grey[300] : const Color(0xFF475569)),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _showCommentReactionDetailsModal(Comment comment) {
    if (comment.reactions.isEmpty) return;
    HapticFeedback.selectionClick();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUserId = _authService.currentUser?.uid;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppTheme.darkSurface : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[700] : Colors.grey[300],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Text(
                  'Yorum Tepkileri (${comment.reactions.length})',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                ...comment.reactions.entries.map((entry) {
                  final uid = entry.key;
                  final emoji = entry.value;
                  final isMe = uid == currentUserId;
                  final name = isMe ? 'Siz' : 'Kullanıcı';

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isMe ? FontWeight.w700 : FontWeight.w500,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                        if (isMe)
                          TextButton(
                            onPressed: () {
                              Navigator.pop(ctx);
                              _toggleCommentReaction(comment.id, emoji);
                            },
                            child: const Text('Kaldır', style: TextStyle(color: Colors.red, fontSize: 12)),
                          ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentItem(Comment comment, bool isAdmin, List<Comment> allComments, ScrollController scrollController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isReply = comment.parentCommentId != null;
    final currentUserId = _authService.currentUser?.uid;
    final isOwnComment = currentUserId != null && comment.userId == currentUserId;
    final key = _commentKeys.putIfAbsent(comment.id, () => GlobalKey());

    return SwipeToReply(
      key: Key('comment_${comment.id}'),
      onReply: () {
        setState(() {
          _replyingTo = comment;
        });
        _commentFocusNode.requestFocus();
        Future.delayed(const Duration(milliseconds: 300), () {
          if (scrollController.hasClients) {
            scrollController.animateTo(
              scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      },
      child: GestureDetector(
        onDoubleTap: () => _showCommentReactionPicker(comment),
        onLongPress: () => _showCommentOptionsModal(comment, isOwnComment, isAdmin),
        child: Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? AppTheme.darkSurface : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? AppTheme.darkBorder : Colors.grey[200]!,
              width: 0.8,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(userId: comment.userId),
                        ),
                      );
                    },
                    child: Builder(
                      builder: (context) {
                        final avatarUrl = migrateAssetPath(comment.userProfileImageUrl);
                        if (avatarUrl.isNotEmpty) {
                          return CircleAvatar(
                            radius: 14,
                            backgroundColor: primaryColor.withValues(alpha: 0.1),
                            backgroundImage: avatarUrl.startsWith('assets/')
                                ? AssetImage(avatarUrl) as ImageProvider
                                : CachedNetworkImageProvider(avatarUrl),
                            onBackgroundImageError: (exception, stackTrace) {},
                          );
                        }
                        return CircleAvatar(
                          radius: 14,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          child: Text(
                            comment.userName.isNotEmpty
                                ? comment.userName[0].toUpperCase()
                                : 'U',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ProfileScreen(userId: comment.userId),
                                    ),
                                  );
                                },
                                child: Text(
                                  comment.userName.isNotEmpty
                                      ? comment.userName
                                      : 'Kullanıcı',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                    color: isDark ? AppTheme.darkTextPrimary : AppTheme.accent,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                            // Vitrin Rozeti (Yalnızca kullanıcı vitrine sabitlediyse gösterilir)
                            if (comment.userPinnedBadge != null && comment.userPinnedBadge!.isNotEmpty) ...[
                              const SizedBox(width: 6),
                              Builder(
                                builder: (context) {
                                  final badge = BadgeHelper.getBadgeInfo(comment.userPinnedBadge!);
                                  if (badge == null) return const SizedBox.shrink();
                                  return Tooltip(
                                    message: '${badge.name} (${badge.tier.label})',
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: badge.color.withValues(alpha: isDark ? 0.2 : 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(
                                          color: badge.color.withValues(alpha: 0.35),
                                          width: 0.8,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(badge.iconData, size: 10.5, color: badge.color),
                                          const SizedBox(width: 3),
                                          Text(
                                            badge.name,
                                            style: TextStyle(
                                              fontSize: 9.5,
                                              fontWeight: FontWeight.w700,
                                              color: badge.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ],
                        ),
                        Text(
                          _formatCommentTime(comment.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey[500],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Menü Butonu (3 Nokta)
                  Builder(
                    builder: (context) {
                      if (currentUserId != null) {
                        return PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
                            size: 16,
                          ),
                          onSelected: (value) {
                            if (value == 'copy') {
                              Clipboard.setData(ClipboardData(text: comment.text));
                              HapticFeedback.lightImpact();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Yorum metni kopyalandı 📋'),
                                  duration: Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            } else if (value == 'reply') {
                              setState(() {
                                _replyingTo = comment;
                              });
                              _commentFocusNode.requestFocus();
                            } else if (value == 'react') {
                              _showCommentReactionPicker(comment);
                            } else if (value == 'delete') {
                              _deleteComment(comment);
                            } else if (value == 'block' && isAdmin) {
                              _blockUser(comment.userId, comment.userName);
                            } else if (value == 'report') {
                              showReportDialog(
                                context,
                                reportedId: comment.id,
                                type: 'comment',
                                targetDealId: widget.deal.id,
                                targetContent: comment.text,
                                targetAuthor: comment.userName,
                                targetAuthorId: comment.userId,
                              );
                            }
                          },
                          itemBuilder: (context) => [
                            const PopupMenuItem(
                              value: 'copy',
                              child: Row(
                                children: [
                                  Icon(Icons.copy_rounded, color: Colors.blue, size: 20),
                                  SizedBox(width: 8),
                                  Text('Metni Kopyala'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'reply',
                              child: Row(
                                children: [
                                  Icon(Icons.reply_rounded, color: Colors.indigo, size: 20),
                                  SizedBox(width: 8),
                                  Text('Yanıtla'),
                                ],
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'react',
                              child: Row(
                                children: [
                                  Icon(Icons.add_reaction_outlined, color: Colors.amber, size: 20),
                                  SizedBox(width: 8),
                                  Text('Tepki Ver'),
                                ],
                              ),
                            ),
                            if (isOwnComment || isAdmin)
                              const PopupMenuItem(
                                value: 'delete',
                                child: Row(
                                  children: [
                                    Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Yorumu Sil'),
                                  ],
                                ),
                              ),
                            if (isAdmin && !isOwnComment)
                              const PopupMenuItem(
                                value: 'block',
                                child: Row(
                                  children: [
                                    Icon(Icons.block_rounded, color: Colors.orange, size: 20),
                                    SizedBox(width: 8),
                                    Text('Kullanıcıyı Engelle'),
                                  ],
                                ),
                              ),
                            if (!isOwnComment)
                              const PopupMenuItem(
                                value: 'report',
                                child: Row(
                                  children: [
                                    Icon(Icons.flag_outlined, color: Colors.red, size: 20),
                                    SizedBox(width: 8),
                                    Text('Raporla'),
                                  ],
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
              if (isReply && comment.replyToUserName != null) ...[
                const SizedBox(height: 8),
                _buildQuoteBox(context, comment, allComments, isDark, primaryColor),
              ],
              const SizedBox(height: 6),
              Text(
                comment.text,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppTheme.darkTextPrimary : AppTheme.accent,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
                ),
              ),

              // Emoji Tepkileri (Rozet Çipleri)
              _buildCommentReactionChips(comment, isDark, primaryColor, currentUserId),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteComment(Comment comment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yorumu Sil'),
        content: const Text('Bu yorumu silmek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Sil'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _firestoreService.deleteComment(comment.id, widget.deal.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Yorum silindi' : 'Yorum silinirken hata oluştu'),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _blockUser(String userId, String userName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kullanıcıyı Engelle'),
        content: Text('$userName kullanıcısını engellemek istediğinize emin misiniz?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Engelle'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final success = await _firestoreService.blockUser(userId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(success ? 'Kullanıcı engellendi' : 'Kullanıcı engellenirken hata oluştu'),
            backgroundColor: success ? Colors.orange : Colors.red,
          ),
        );
      }
    }
  }

  String _formatCommentTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inMinutes < 1) {
      return 'Az önce';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} dakika önce';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} saat önce';
    } else if (difference.inDays == 1) {
      return 'Dün';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} gün önce';
    }

    return DateFormat('d MMM yyyy').format(date);
  }
}
