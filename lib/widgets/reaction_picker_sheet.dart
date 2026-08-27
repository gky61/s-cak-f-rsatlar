import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';

/// Hem Mesajlar (Chat) hem de Yorumlar (Comments) için paylaşılan,
/// WhatsApp / Telegram standardında, kategorize edilmiş, aramalı ve
/// son kullanılanları hatırlayan zengin Emoji Tepki Seçici Modal BottomSheet.
Future<void> showReactionPickerBottomSheet({
  required BuildContext context,
  String title = 'Tepki Ver',
  String? currentEmoji,
  required Function(String emoji) onEmojiSelected,
}) async {
  HapticFeedback.lightImpact();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => _ReactionPickerSheet(
      title: title,
      currentEmoji: currentEmoji,
      onEmojiSelected: onEmojiSelected,
    ),
  );
}

class _EmojiCategory {
  final String id;
  final String name;
  final String icon;
  final List<String> emojis;

  const _EmojiCategory({
    required this.id,
    required this.name,
    required this.icon,
    required this.emojis,
  });
}

class _ReactionPickerSheet extends StatefulWidget {
  final String title;
  final String? currentEmoji;
  final Function(String emoji) onEmojiSelected;

  const _ReactionPickerSheet({
    required this.title,
    this.currentEmoji,
    required this.onEmojiSelected,
  });

  @override
  State<_ReactionPickerSheet> createState() => _ReactionPickerSheetState();
}

class _ReactionPickerSheetState extends State<_ReactionPickerSheet> {
  static const String _recentsKey = 'recent_reaction_emojis_v1';
  static const List<String> _quickEmojis = ['👍', '❤️', '🔥', '😂', '😮', '😢'];

  static const List<_EmojiCategory> _categories = [
    _EmojiCategory(
      id: 'smileys',
      name: 'İfadeler & Yüzler',
      icon: '😃',
      emojis: [
        '😀', '😃', '😄', '😁', '😆', '😅', '😂', '🤣',
        '🥹', '😊', '😇', '🙂', '🙃', '😉', '😌', '😍',
        '🥰', '😘', '😗', '😙', '😚', '😋', '😛', '😝',
        '😜', '🤪', '🤨', '🧐', '🤓', '😎', '🥸', '🤩',
        '🥳', '😏', '😒', '😞', '😔', '😟', '😕', '🙁',
        '☹️', '😣', '😖', '😫', '😩', '🥺', '😢', '😭',
        '😮‍💨', '😤', '😠', '😡', '🤬', '🤯', '😳', '🥵',
        '🥶', '😱', '😨', '😰', '😥', '😓', '🤗', '🤔',
        '🫣', '🤭', '🫢', '🫡', '🤫', '🫠', '🤥', '😶',
        '😐', '😑', '🫨', '😬', '🙄', '😯', '😦', '😧',
        '😮', '😲', '🥱', '😴', '🤤', '😪', '😵', '😵‍💫',
        '🤐', '🥴', '🤢', '🤮', '🤧', '😷', '🤒', '🤕',
        '🤑', '🤠', '😈', '👿', '👹', '👺', '🤡', '💩',
        '👻', '💀', '☠️', '👽', '👾', '🤖', '🎃', '😺',
      ],
    ),
    _EmojiCategory(
      id: 'gestures',
      name: 'Jestler & İnsanlar',
      icon: '👍',
      emojis: [
        '👍', '👎', '👏', '🙌', '👐', '🤲', '🤝', '🤜',
        '🤛', '✊', '👊', '🤌', '🤏', '✌️', '🤞', '🫰',
        '🤟', '🤘', '🤙', '👈', '👉', '👆', '🖕', '👇',
        '☝️', '✋', '🤚', '🖐️', '🖖', '👋', '✍️', '🫲',
        '🫱', '🫵', '🫳', '🫴', '🙏', '💅', '🤳', '💪',
        '🦾', '🦿', '🦵', '🦶', '👂', '🦻', '👃', '🫀',
        '🫁', '🧠', '👀', '👁️', '👅', '👄', '👑', '👒',
        '🧢', '🎓', '🪖', '💄', '💍', '💼', '🫡', '🤷',
      ],
    ),
    _EmojiCategory(
      id: 'hearts',
      name: 'Kalpler & Duygular',
      icon: '❤️',
      emojis: [
        '❤️', '🧡', '💛', '💚', '💙', '💜', '🖤', '🤍',
        '🤎', '💔', '❤️‍🔥', '❤️‍🩹', '💖', '💗', '💓', '💞',
        '💕', '💌', '💘', '💝', '💟', '♥️', '💯', '💢',
        '💥', '💫', '💦', '💨', '🕳️', '💣', '💬', '👁️‍🗨️',
        '🗯️', '💭', '💤', '✨', '⭐', '🌟', '🔥', '⚡',
      ],
    ),
    _EmojiCategory(
      id: 'deals',
      name: 'Fırsat & Objeler',
      icon: '🚀',
      emojis: [
        '🚀', '💸', '💰', '💵', '💳', '🛒', '🛍️', '🏷️',
        '📦', '🎁', '🎉', '🎊', '🏆', '🥇', '🥈', '🥉',
        '🎯', '⚡', '🔥', '💎', '🔔', '💡', '📢', '🔑',
        '🔒', '📈', '📉', '📊', '🧾', '⏳', '⏰', '📱',
        '💻', '🖥️', '⌨️', '🎧', '📸', '🕹️', '🎮', '🔋',
      ],
    ),
    _EmojiCategory(
      id: 'food',
      name: 'Yiyecek & İçecek',
      icon: '🍕',
      emojis: [
        '☕', '🍵', '🧃', '🥤', '🧋', '🍺', '🍻', '🥂',
        '🍷', '🥃', '🍸', '🍹', '🍔', '🍟', '🍕', '🌭',
        '🥪', '🌮', '🌯', '🥙', '🧆', '🍳', '🥞', '🧇',
        '🍩', '🍪', '🎂', '🍰', '🧁', '🍫', '🍬', '🍭',
        '🍦', '🍧', '🍨', '🍿', '🥐', '🥯', '🍞', '🥑',
      ],
    ),
    _EmojiCategory(
      id: 'symbols',
      name: 'Semboller & Doğa',
      icon: '🌟',
      emojis: [
        '✨', '🌟', '⭐', '☀️', '🌙', '☁️', '🌧️', '⛈️',
        '❄️', '🌈', '⚡', '🌊', '🌸', '🌹', '🌺', '🌻',
        '🍀', '🍁', '🍂', '🌴', '🌲', '🚗', '🚕', '🚙',
        '🏎️', '✈️', '🚲', '🛴', '🛵', '⛵', '🚢', '🚀',
        '🏠', '🏡', '🏢', '🏛️', '⚽', '🏀', '🏈', '🎾',
      ],
    ),
  ];

  List<String> _recentEmojis = [];
  int _selectedCategoryIndex = 0;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadRecents();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadRecents() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_recentsKey);
      if (list != null && list.isNotEmpty && mounted) {
        setState(() {
          _recentEmojis = list;
        });
      }
    } catch (_) {}
  }

  Future<void> _saveToRecents(String emoji) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final updated = [emoji, ..._recentEmojis.where((e) => e != emoji)].take(14).toList();
      await prefs.setStringList(_recentsKey, updated);
    } catch (_) {}
  }

  void _onEmojiTapped(String emoji) {
    HapticFeedback.lightImpact();
    _saveToRecents(emoji);
    Navigator.pop(context);
    widget.onEmojiSelected(emoji);
  }

  List<String> _getFilteredEmojis() {
    if (_searchQuery.isEmpty) {
      if (_selectedCategoryIndex == 0 && _recentEmojis.isNotEmpty) {
        return _recentEmojis;
      }
      final catIndex = _recentEmojis.isNotEmpty ? _selectedCategoryIndex - 1 : _selectedCategoryIndex;
      if (catIndex >= 0 && catIndex < _categories.length) {
        return _categories[catIndex].emojis;
      }
      return _categories[0].emojis;
    }

    // Arama modunda tüm kategorilerde arar
    final results = <String>{};
    for (var cat in _categories) {
      for (var emoji in cat.emojis) {
        if (emoji.contains(_searchQuery)) {
          results.add(emoji);
        }
      }
    }
    return results.toList();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final screenHeight = MediaQuery.of(context).size.height;
    final filteredEmojis = _getFilteredEmojis();

    final List<_EmojiCategory> availableCategories = [
      if (_recentEmojis.isNotEmpty)
        const _EmojiCategory(
          id: 'recents',
          name: 'Son Kullanılanlar',
          icon: '🕒',
          emojis: [],
        ),
      ..._categories,
    ];

    return Container(
      height: screenHeight * 0.68,
      decoration: BoxDecoration(
        color: isDark ? AppTheme.darkSurface : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.4 : 0.12),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Üst Tutma Çubuğu (Handle)
            Center(
              child: Container(
                width: 40,
                height: 4.5,
                margin: const EdgeInsets.only(top: 10, bottom: 8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),

            // Başlık Çubuğu & Tepkiyi Kaldır Butonu
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.add_reaction_rounded,
                          size: 18,
                          color: primaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  if (widget.currentEmoji != null && widget.currentEmoji!.isNotEmpty)
                    TextButton.icon(
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        Navigator.pop(context);
                        widget.onEmojiSelected(widget.currentEmoji!); // Toggle off
                      },
                      icon: const Icon(Icons.close_rounded, size: 14, color: Colors.red),
                      label: const Text(
                        'Tepkiyi Kaldır',
                        style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                ],
              ),
            ),

            // Hızlı Tepki Barı (Popular Quick Reactions)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
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
                  children: _quickEmojis.map((emoji) {
                    final isSelected = widget.currentEmoji == emoji;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _onEmojiTapped(emoji),
                        borderRadius: BorderRadius.circular(18),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 160),
                          padding: const EdgeInsets.all(7),
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
                  }).toList(),
                ),
              ),
            ),

            // Kategori Sekmeleri (Horizontal Pill Bar)
            if (_searchQuery.isEmpty)
              Container(
                height: 42,
                margin: const EdgeInsets.symmetric(vertical: 4),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  itemCount: availableCategories.length,
                  itemBuilder: (context, i) {
                    final cat = availableCategories[i];
                    final isSelected = _selectedCategoryIndex == i;

                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            setState(() {
                              _selectedCategoryIndex = i;
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? primaryColor.withValues(alpha: isDark ? 0.3 : 0.15)
                                  : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isSelected
                                    ? primaryColor
                                    : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
                                width: isSelected ? 1.2 : 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(cat.icon, style: const TextStyle(fontSize: 15)),
                                const SizedBox(width: 5),
                                Text(
                                  cat.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                    color: isSelected
                                        ? (isDark ? Colors.white : primaryColor)
                                        : (isDark ? Colors.grey[400] : const Color(0xFF64748B)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

            // Emoji Izgarası (Grid)
            Expanded(
              child: filteredEmojis.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.sentiment_dissatisfied_rounded,
                            size: 40,
                            color: isDark ? Colors.grey[600] : Colors.grey[400],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Emoji bulunamadı',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? Colors.grey[500] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 7,
                        crossAxisSpacing: 6,
                        mainAxisSpacing: 6,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: filteredEmojis.length,
                      itemBuilder: (context, i) {
                        final emoji = filteredEmojis[i];
                        final isSelected = widget.currentEmoji == emoji;

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _onEmojiTapped(emoji),
                            borderRadius: BorderRadius.circular(14),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryColor.withValues(alpha: isDark ? 0.3 : 0.18)
                                    : (isDark ? Colors.white.withValues(alpha: 0.04) : const Color(0xFFF8FAFC)),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? primaryColor
                                      : (isDark ? Colors.white.withValues(alpha: 0.06) : const Color(0xFFE2E8F0)),
                                  width: isSelected ? 1.4 : 0.6,
                                ),
                              ),
                              child: Text(
                                emoji,
                                style: const TextStyle(fontSize: 22),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
