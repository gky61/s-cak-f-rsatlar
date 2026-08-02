import 'package:flutter/material.dart';
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/deal.dart';
import '../models/comment.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../utils/badge_helper.dart';
import '../theme/app_theme.dart';
import '../widgets/report_dialog.dart';
import '../widgets/guest_login_bottom_sheet.dart';
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
    if (isBlocked) {
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
    try {
      final userData = await _authService.getUserData(user.uid);
      if (userData != null) {
        // Firestore'daki username'i kullan (güncel kullanıcı adı)
        displayName = userData.username.isNotEmpty ? userData.username : userData.displayName;
        profileImageUrl = userData.profileImageUrl;
        userBadges = userData.badges;
        _log('🔍 Yorum eklerken rozetler alındı: ${userBadges.length} rozet - $userBadges');
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
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Yorumunuz eklendi'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
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
                    // İlk yükleme sırasında loading göster
                    if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
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
                          final itemHeight = 100.0; // Yaklaşık yorum yüksekliği
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
        final double estimatedItemHeight = 90.0;
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

  Widget _buildCommentItem(Comment comment, bool isAdmin, List<Comment> allComments, ScrollController scrollController) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final isReply = comment.parentCommentId != null;
    final key = _commentKeys.putIfAbsent(comment.id, () => GlobalKey());

    return Dismissible(
      key: Key('comment_${comment.id}'),
      direction: DismissDirection.startToEnd,
      confirmDismiss: (direction) async {
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
        return false; // Prevent removing the item from list
      },
      background: Container(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.only(left: 20),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: primaryColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.reply_rounded, color: primaryColor),
      ),
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
                  child: comment.userProfileImageUrl.isNotEmpty
                      ? CircleAvatar(
                          radius: 14,
                          backgroundColor: primaryColor.withValues(alpha: 0.1),
                          backgroundImage: comment.userProfileImageUrl.startsWith('assets/')
                              ? AssetImage(comment.userProfileImageUrl) as ImageProvider
                              : CachedNetworkImageProvider(comment.userProfileImageUrl),
                          onBackgroundImageError: (exception, stackTrace) {
                            // Hata durumunda harf göster
                          },
                        )
                      : CircleAvatar(
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
                          // Rozetler
                          if (comment.userBadges.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Builder(
                              builder: (context) {
                                _log('🔍 Yorumda rozetler gösteriliyor: ${comment.userBadges}');
                                final badgeInfos = BadgeHelper.getBadgeInfos(comment.userBadges);
                                _log('🔍 BadgeHelper.getBadgeInfos sonucu: ${badgeInfos.length} rozet');
                                return Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: badgeInfos.take(3).map(
                                    (badge) => Padding(
                                      padding: const EdgeInsets.only(left: 3),
                                      child: Tooltip(
                                        message: badge.name,
                                        child: Container(
                                          padding: const EdgeInsets.all(2),
                                          decoration: BoxDecoration(
                                            color: badge.color.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            badge.icon,
                                            style: const TextStyle(fontSize: 12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ).toList(),
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
                // Admin butonları veya kullanıcının kendi yorumu
                Builder(
                  builder: (context) {
                    final currentUser = _authService.currentUser;
                    final isOwnComment = currentUser != null && comment.userId == currentUser.uid;
                    
                    if (currentUser != null) {
                      return PopupMenuButton<String>(
                        icon: Icon(
                          Icons.more_vert_rounded,
                          color: isDark ? AppTheme.darkTextSecondary : Colors.grey[600],
                          size: 16,
                        ),
                        onSelected: (value) {
                          if (value == 'delete') {
                            _deleteComment(comment);
                          } else if (value == 'block' && isAdmin) {
                            _blockUser(comment.userId, comment.userName);
                          } else if (value == 'report') {
                            showReportDialog(
                              context,
                              reportedId: comment.id,
                              type: 'comment',
                            );
                          }
                        },
                        itemBuilder: (context) => [
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
                          if (isAdmin)
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
          ],
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
