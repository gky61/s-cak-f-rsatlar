import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../models/deal.dart';
import '../models/message.dart';
import '../services/firestore_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/asset_path_migration.dart';
import '../screens/message_screen.dart';
import '../screens/deal_detail/deal_share_sheet.dart';
import 'guest_login_bottom_sheet.dart';
import 'skeletons/chat_list_skeleton.dart';

/// Kullanıcının bir fırsatı uygulama içi sohbet üzerinden istediği kişiye veya Botkolik'e
/// iletmesini sağlayan ultra-modern ve akışkan paylaşım Bottom Sheet'i.
class DealForwardBottomSheet extends StatefulWidget {
  final Deal deal;

  const DealForwardBottomSheet({
    super.key,
    required this.deal,
  });

  static Future<void> show(BuildContext context, Deal deal) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DealForwardBottomSheet(deal: deal),
    );
  }

  @override
  State<DealForwardBottomSheet> createState() => _DealForwardBottomSheetState();
}

class _DealForwardBottomSheetState extends State<DealForwardBottomSheet> {
  final FirestoreService _firestoreService = FirestoreService();
  final AuthService _authService = AuthService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _searchQuery = '';
  final Set<String> _sentUserIds = {};
  final Set<String> _sendingUserIds = {};
  bool _isBotkolikChatEnabled = true;
  StreamSubscription<bool>? _botkolikChatSub;

  List<Map<String, dynamic>> _searchedUsers = [];
  bool _isSearchingUsers = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _botkolikChatSub = _firestoreService.botkolikChatEnabledStream().listen((enabled) {
      if (mounted) {
        setState(() {
          _isBotkolikChatEnabled = enabled;
        });
      }
    });
  }

  @override
  void dispose() {
    _botkolikChatSub?.cancel();
    _debounceTimer?.cancel();
    _searchController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.trim().toLowerCase();
    });

    _debounceTimer?.cancel();
    if (_searchQuery.length >= 2) {
      _debounceTimer = Timer(const Duration(milliseconds: 350), () {
        _searchGlobalUsers(_searchQuery);
      });
    } else {
      setState(() {
        _searchedUsers = [];
        _isSearchingUsers = false;
      });
    }
  }

  Future<void> _searchGlobalUsers(String query) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) return;

    setState(() => _isSearchingUsers = true);
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .limit(20)
          .get();

      final results = <Map<String, dynamic>>[];
      for (final doc in snap.docs) {
        if (doc.id == currentUserId) continue;
        final data = doc.data();
        final username = (data['username'] ?? '').toString().toLowerCase();
        final displayName = (data['displayName'] ?? '').toString().toLowerCase();
        if (username.contains(query) || displayName.contains(query)) {
          results.add({
            'id': doc.id,
            'name': data['username'] ?? data['displayName'] ?? 'Kullanıcı',
            'imageUrl': migrateAssetPath(data['profileImageUrl']?.toString() ?? ''),
          });
        }
      }

      if (mounted) {
        setState(() {
          _searchedUsers = results;
          _isSearchingUsers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSearchingUsers = false);
      }
    }
  }

  Future<void> _sendDealToUser({
    required String targetUserId,
    required String targetUserName,
    required String targetUserImageUrl,
  }) async {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.pop(context);
      showGuestLoginBottomSheet(
        context,
        title: 'Fırsatı Paylaş',
        message: 'Fırsatı diğer kullanıcılarla paylaşmak için lütfen giriş yapın.',
      );
      return;
    }

    if (_sendingUserIds.contains(targetUserId) || _sentUserIds.contains(targetUserId)) {
      return;
    }

    setState(() {
      _sendingUserIds.add(targetUserId);
    });

    HapticFeedback.mediumImpact();

    final note = _noteController.text.trim();
    final messageText = note.isNotEmpty
        ? note
        : '🔥 Bu fırsata göz atmalısın: ${widget.deal.title}';

    final formattedPrice = widget.deal.price > 0
        ? DynamicCurrencyFormatter().format(widget.deal.price)
        : '';

    try {
      final docId = await _firestoreService.sendMessage(
        senderId: currentUserId,
        receiverId: targetUserId,
        text: messageText,
        dealId: widget.deal.id,
        dealTitle: widget.deal.title,
        dealImageUrl: widget.deal.imageUrl,
        dealPrice: formattedPrice,
        dealStore: widget.deal.store,
      );

      if (mounted) {
        setState(() {
          _sendingUserIds.remove(targetUserId);
          if (docId != null) {
            _sentUserIds.add(targetUserId);
          }
        });

        if (docId != null) {
          _showFloatingToast('🚀 Fırsat $targetUserName kişisine iletildi!');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _sendingUserIds.remove(targetUserId);
        });
        _showFloatingToast('Mesaj gönderilemedi: $e', isError: true);
      }
    }
  }

  void _openChatWithUser({
    required String targetUserId,
    required String targetUserName,
    required String targetUserImageUrl,
  }) {
    final currentUserId = _authService.currentUser?.uid;
    if (currentUserId == null) {
      Navigator.pop(context);
      showGuestLoginBottomSheet(
        context,
        title: 'Fırsatı Paylaş',
        message: 'Fırsatı diğer kullanıcılarla paylaşmak için lütfen giriş yapın.',
      );
      return;
    }

    Navigator.pop(context);
    final note = _noteController.text.trim();
    final formattedPrice = widget.deal.price > 0
        ? DynamicCurrencyFormatter().format(widget.deal.price)
        : '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessageScreen(
          otherUserId: targetUserId,
          otherUserName: targetUserName,
          otherUserImageUrl: targetUserImageUrl,
          initialDealId: widget.deal.id,
          initialDealTitle: widget.deal.title,
          initialDealImageUrl: widget.deal.imageUrl,
          initialDealPrice: formattedPrice,
          initialDealStore: widget.deal.store,
          initialText: note.isNotEmpty ? note : null,
        ),
      ),
    );
  }

  void _showFloatingToast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
        ),
        backgroundColor: isError ? Colors.redAccent : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        duration: const Duration(milliseconds: 2000),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final surfaceColor = isDark ? AppTheme.darkSurface : Colors.white;
    final textMain = isDark ? Colors.white : AppTheme.textPrimary;
    final textSub = isDark ? Colors.grey[400] : AppTheme.textSecondary;
    final currentUserId = _authService.currentUser?.uid;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle Bar
            Center(
              child: Container(
                margin: const EdgeInsets.only(top: 12, bottom: 12),
                width: 40,
                height: 4.5,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Modal Header (Title + Close)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.send_rounded, color: primaryColor, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Fırsatı Mesaj Olarak Gönder',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: textMain,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Topluluk üyelerine doğrudan iletin',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: textSub,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 22),
                    color: textSub,
                    splashRadius: 20,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // Deal Mini-Preview Card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.04)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.08)
                        : const Color(0xFFE2E8F0),
                    width: 0.9,
                  ),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        width: 48,
                        height: 48,
                        color: isDark ? Colors.grey[850] : const Color(0xFFF1F5F9),
                        child: widget.deal.imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: widget.deal.imageUrl,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Icon(Icons.local_offer_outlined, color: primaryColor, size: 20),
                              )
                            : Icon(Icons.local_offer_outlined, color: primaryColor, size: 20),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (widget.deal.store.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFE2E8F0),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    widget.deal.store,
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: isDark ? Colors.grey[300] : const Color(0xFF475569),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                              ],
                              if (widget.deal.price > 0)
                                Text(
                                  DynamicCurrencyFormatter().format(widget.deal.price),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: primaryColor,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.deal.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w700,
                              color: textMain,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Note Input (Optional Message)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _noteController,
                  style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Mesajınız / notunuz (isteğe bağlı)...',
                    hintStyle: TextStyle(color: textSub?.withValues(alpha: 0.7), fontSize: 12),
                    prefixIcon: Icon(Icons.mode_edit_outline_rounded, size: 16, color: textSub),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Search Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _searchQuery.isNotEmpty
                        ? primaryColor.withValues(alpha: 0.6)
                        : (isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFCBD5E1)),
                    width: 0.8,
                  ),
                ),
                child: TextField(
                  controller: _searchController,
                  onChanged: _onSearchChanged,
                  style: TextStyle(color: textMain, fontSize: 12.5, fontWeight: FontWeight.w500),
                  decoration: InputDecoration(
                    hintText: 'Kişi veya sohbet ara...',
                    hintStyle: TextStyle(color: textSub?.withValues(alpha: 0.7), fontSize: 12),
                    prefixIcon: Icon(Icons.search_rounded, size: 16, color: textSub),
                    suffixIcon: _isSearchingUsers
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                          )
                        : (_searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded, size: 16),
                                onPressed: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                              )
                            : null),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            // Conversations & Users List
            Expanded(
              child: currentUserId == null
                  ? _buildGuestPrompt(primaryColor, textMain, textSub)
                  : StreamBuilder<List<Message>>(
                      stream: _firestoreService.getUserMessagesStream(currentUserId),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting && _searchedUsers.isEmpty) {
                          return const ChatListSkeleton(itemCount: 5, padding: EdgeInsets.zero);
                        }

                        final messages = snapshot.data ?? [];
                        final Map<String, Map<String, dynamic>> contactMap = {};

                        // Botkolik'i başa ekle (eğer ayar açıksa)
                        if (_isBotkolikChatEnabled) {
                          contactMap['botkolik'] = {
                            'id': 'botkolik',
                            'name': 'Botkolik',
                            'imageUrl': 'assets/botkolik.webp',
                            'isBot': true,
                            'lastMessage': 'Yapay Zeka Fırsat Radarı',
                          };
                        }

                        for (final message in messages) {
                          final otherUserId = message.senderId == currentUserId
                              ? message.receiverId
                              : message.senderId;
                          final otherUserName = message.senderId == currentUserId
                              ? message.receiverName
                              : message.senderName;
                          final otherUserImageUrl = message.senderId == currentUserId
                              ? message.receiverImageUrl
                              : message.senderImageUrl;

                          if (otherUserId == 'botkolik') continue;

                          if (!contactMap.containsKey(otherUserId)) {
                            contactMap[otherUserId] = {
                              'id': otherUserId,
                              'name': otherUserName.isNotEmpty ? otherUserName : 'Kullanıcı',
                              'imageUrl': otherUserImageUrl,
                              'isBot': false,
                              'lastMessage': message.text,
                            };
                          }
                        }

                        // Eğer global arama yapılıyorsa searchedUsers ile birleştir
                        for (final user in _searchedUsers) {
                          final uid = user['id'] as String;
                          if (!contactMap.containsKey(uid)) {
                            contactMap[uid] = {
                              'id': uid,
                              'name': user['name'],
                              'imageUrl': user['imageUrl'],
                              'isBot': false,
                              'lastMessage': 'Yeni Sohbet',
                            };
                          }
                        }

                        final allContacts = contactMap.values.toList();
                        final filteredContacts = allContacts.where((c) {
                          if (_searchQuery.isEmpty) return true;
                          final name = (c['name'] as String).toLowerCase();
                          return name.contains(_searchQuery);
                        }).toList();

                        if (filteredContacts.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_search_rounded, size: 44, color: textSub?.withValues(alpha: 0.5)),
                                  const SizedBox(height: 8),
                                  Text(
                                    _searchQuery.isNotEmpty ? 'Sonuç bulunamadı' : 'Henüz bir sohbet geçmişiniz yok',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: textSub),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }

                        return ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                          itemCount: filteredContacts.length,
                          separatorBuilder: (_, __) => Divider(
                            height: 1,
                            color: isDark ? Colors.white.withValues(alpha: 0.05) : const Color(0xFFF1F5F9),
                          ),
                          itemBuilder: (context, index) {
                            final contact = filteredContacts[index];
                            final targetId = contact['id'] as String;
                            final targetName = contact['name'] as String;
                            final targetImage = contact['imageUrl'] as String;
                            final isBot = contact['isBot'] == true;
                            final isSending = _sendingUserIds.contains(targetId);
                            final isSent = _sentUserIds.contains(targetId);

                            return Material(
                              color: Colors.transparent,
                              child: InkWell(
                                onTap: () => _openChatWithUser(
                                  targetUserId: targetId,
                                  targetUserName: targetName,
                                  targetUserImageUrl: targetImage,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                                  child: Row(
                                    children: [
                                      // Avatar
                                      Stack(
                                        children: [
                                          ClipOval(
                                            child: Container(
                                              width: 42,
                                              height: 42,
                                              color: isDark ? Colors.grey[800] : const Color(0xFFE2E8F0),
                                              child: isBot
                                                  ? Image.asset('assets/botkolik.webp', fit: BoxFit.cover)
                                                  : _buildAvatar(targetImage, 42),
                                            ),
                                          ),
                                          if (isBot)
                                            Positioned(
                                              right: 0,
                                              bottom: 0,
                                              child: Container(
                                                width: 10,
                                                height: 10,
                                                decoration: BoxDecoration(
                                                  color: const Color(0xFF10B981),
                                                  shape: BoxShape.circle,
                                                  border: Border.all(
                                                    color: surfaceColor,
                                                    width: 1.5,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(width: 12),
                                      // Name & Subtext
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Flexible(
                                                  child: Text(
                                                    targetName,
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: TextStyle(
                                                      fontSize: 13.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: textMain,
                                                    ),
                                                  ),
                                                ),
                                                if (isBot) ...[
                                                  const SizedBox(width: 4),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                                    decoration: BoxDecoration(
                                                      color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                                                      borderRadius: BorderRadius.circular(6),
                                                    ),
                                                    child: Text(
                                                      'BOT',
                                                      style: TextStyle(
                                                        fontSize: 9,
                                                        fontWeight: FontWeight.w800,
                                                        color: primaryColor,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              contact['lastMessage'] ?? '',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 11.5,
                                                color: textSub,
                                                fontWeight: FontWeight.w400,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Quick Send Button
                                      Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: (isSending || isSent)
                                              ? null
                                              : () => _sendDealToUser(
                                                    targetUserId: targetId,
                                                    targetUserName: targetName,
                                                    targetUserImageUrl: targetImage,
                                                  ),
                                          borderRadius: BorderRadius.circular(10),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 200),
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                            decoration: BoxDecoration(
                                              color: isSent
                                                  ? const Color(0xFF10B981)
                                                  : (isSending
                                                      ? primaryColor.withValues(alpha: 0.4)
                                                      : (isDark
                                                          ? primaryColor.withValues(alpha: 0.18)
                                                          : primaryColor)),
                                              borderRadius: BorderRadius.circular(10),
                                              border: isDark && !isSent
                                                  ? Border.all(color: primaryColor.withValues(alpha: 0.4), width: 0.8)
                                                  : null,
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isSending)
                                                  const SizedBox(
                                                    width: 12,
                                                    height: 12,
                                                    child: CircularProgressIndicator(strokeWidth: 1.5, color: Colors.white),
                                                  )
                                                else if (isSent) ...[
                                                  const Icon(Icons.check_rounded, size: 14, color: Colors.white),
                                                  const SizedBox(width: 4),
                                                  const Text(
                                                    'İletildi',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ] else ...[
                                                  Icon(
                                                    Icons.send_rounded,
                                                    size: 13,
                                                    color: isDark ? primaryColor : Colors.white,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    'Gönder',
                                                    style: TextStyle(
                                                      fontSize: 11.5,
                                                      fontWeight: FontWeight.w700,
                                                      color: isDark ? primaryColor : Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
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
                    ),
            ),

            // Bottom Quick Actions (Copy App Link, Copy Store Link & Native Share)
            Container(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              decoration: BoxDecoration(
                color: surfaceColor,
                border: Border(
                  top: BorderSide(
                    color: isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFF1F5F9),
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // FırsatKolik / Uygulama Linki
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        DealShareSheet.copyDealLink(context, widget.deal);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.link_rounded, size: 15, color: isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7)),
                          const SizedBox(width: 4),
                          const Flexible(
                            child: Text(
                              'Uygulama Linki',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mağaza Ürün Linki
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        DealShareSheet.copyStoreLink(context, widget.deal);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: textMain,
                        side: BorderSide(
                          color: isDark ? Colors.white.withValues(alpha: 0.15) : const Color(0xFFCBD5E1),
                          width: 1,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.storefront_rounded, size: 15, color: Color(0xFF10B981)),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Mağaza Linki',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Diğer Uygulamalarda Paylaş
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        DealShareSheet.shareToNativeApps(context, widget.deal);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.share_rounded, size: 14, color: Colors.white),
                          SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              'Paylaş',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildGuestPrompt(Color primaryColor, Color textMain, Color? textSub) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 42, color: primaryColor),
            const SizedBox(height: 10),
            Text(
              'Giriş Yapmalısınız',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: textMain),
            ),
            const SizedBox(height: 6),
            Text(
              'Fırsatları diğer kullanıcılara doğrudan göndermek için lütfen giriş yapın.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: textSub),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                showGuestLoginBottomSheet(
                  context,
                  title: 'Fırsatı Paylaş',
                  message: 'Fırsatı diğer kullanıcılarla paylaşmak için giriş yapın.',
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Giriş Yap', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
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
      return Image.asset(
        cleanUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(
          color: Colors.grey[300],
          child: Icon(Icons.person, size: size * 0.6, color: Colors.grey[600]),
        ),
      );
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
