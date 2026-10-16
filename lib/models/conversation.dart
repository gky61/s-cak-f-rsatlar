import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/asset_path_migration.dart';

/// Konuşma katılımcısının anlık denormalize profil bilgisi
class ConversationParticipant {
  final String name;
  final String avatar;
  final bool isDeleted;

  const ConversationParticipant({
    required this.name,
    required this.avatar,
    this.isDeleted = false,
  });

  factory ConversationParticipant.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const ConversationParticipant(name: 'Kullanıcı', avatar: '');
    }
    return ConversationParticipant(
      name: (map['name'] ?? map['username'] ?? map['displayName'] ?? 'Kullanıcı').toString(),
      avatar: migrateAssetPath((map['avatar'] ?? map['profileImageUrl'] ?? map['photoURL'] ?? '').toString()),
      isDeleted: map['isDeleted'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'avatar': avatar,
      if (isDeleted) 'isDeleted': true,
    };
  }
}

/// 100k DAU Ölçeğinde Gelen Kutusu Kayıplarını (Inbox Truncation) ve
/// N+1 User Snapshot Dinleyici Patlamasını Önleyen Üst Seviye Konuşma Modeli.
class Conversation {
  final String id;
  final List<String> participants;
  final String lastMessageText;
  final String lastMessageSenderId;
  final String lastMessageSenderName;
  final DateTime lastMessageCreatedAt;
  final bool lastMessageIsRead;
  final String? lastMessageDealId;
  final String? lastMessageDealTitle;
  final DateTime updatedAt;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime?> clearedAt;
  final Map<String, ConversationParticipant> participantDetails;

  const Conversation({
    required this.id,
    required this.participants,
    required this.lastMessageText,
    required this.lastMessageSenderId,
    required this.lastMessageSenderName,
    required this.lastMessageCreatedAt,
    required this.lastMessageIsRead,
    this.lastMessageDealId,
    this.lastMessageDealTitle,
    required this.updatedAt,
    this.unreadCounts = const {},
    this.clearedAt = const {},
    this.participantDetails = const {},
  });

  /// Deterministik Alfabetik Konuşma Kimliği (UID_A_UID_B)
  static String computeConversationId(String u1, String u2) {
    if (u1.isEmpty || u2.isEmpty) return '';
    final list = [u1, u2]..sort();
    return '${list[0]}_${list[1]}';
  }

  /// Karşı tarafın UID'sini döner
  String getOtherUserId(String currentUserId) {
    return participants.firstWhere(
      (uid) => uid != currentUserId,
      orElse: () => participants.isNotEmpty ? participants.first : '',
    );
  }

  /// Karşı tarafın güncel kullanıcı adını döner
  String getOtherUserName(String currentUserId) {
    final otherUid = getOtherUserId(currentUserId);
    if (otherUid == 'admin') return 'FırsatKolik Yönetim';
    if (otherUid == 'botkolik') return 'Botkolik';
    if (otherUid == 'test_user_ahmet') return 'Ahmet Yılmaz (Test)';
    if (otherUid == 'test_user_zeynep') return 'Zeynep Kaya (Test)';

    final detail = participantDetails[otherUid];
    if (detail != null && detail.name.isNotEmpty) {
      if (detail.isDeleted) return 'Silinmiş Kullanıcı';
      return detail.name;
    }
    return 'Kullanıcı';
  }

  /// Karşı tarafın güncel avatar URL'sini döner
  String getOtherUserAvatar(String currentUserId) {
    final otherUid = getOtherUserId(currentUserId);
    if (otherUid == 'admin') return 'assets/logo.webp';
    if (otherUid == 'botkolik') return 'assets/botkolik.webp';
    if (otherUid == 'test_user_zeynep') return 'assets/avatars/avatar_duck.webp';

    final detail = participantDetails[otherUid];
    if (detail != null && detail.avatar.isNotEmpty) {
      if (detail.isDeleted) return '';
      return migrateAssetPath(detail.avatar);
    }
    return '';
  }

  /// Belirli bir kullanıcı için okunmamış mesaj sayısı
  int getUnreadCount(String currentUserId) {
    return unreadCounts[currentUserId] ?? 0;
  }

  /// Kullanıcı bu sohbeti daha önce temizlemiş mi denetler
  bool isClearedFor(String currentUserId) {
    final cTime = clearedAt[currentUserId];
    if (cTime == null) return false;
    return updatedAt.isBefore(cTime);
  }

  /// Belirli bir mesajın, kullanıcının sohbeti temizlediği zamandan önce olup olmadığını denetler
  bool isClearedForMessage(String currentUserId, DateTime messageCreatedAt) {
    final cTime = clearedAt[currentUserId];
    if (cTime == null) return false;
    return messageCreatedAt.isBefore(cTime);
  }

  factory Conversation.fromFirestore(DocumentSnapshot doc) {
    final data = (doc.data() as Map<String, dynamic>?) ?? {};
    return Conversation.fromMap(doc.id, data);
  }

  factory Conversation.fromMap(String id, Map<String, dynamic> data) {

    // participants parse
    List<String> participants = [];
    if (data['participants'] is List) {
      participants = (data['participants'] as List).map((e) => e.toString()).toList();
    }

    // lastMessage parse
    final lm = (data['lastMessage'] as Map<String, dynamic>?) ?? {};
    final lastText = (lm['text'] ?? lm['content'] ?? data['lastMessageText'] ?? '').toString();
    final lastSenderId = (lm['senderId'] ?? data['lastMessageSenderId'] ?? '').toString();
    final lastSenderName = (lm['senderName'] ?? data['lastMessageSenderName'] ?? '').toString();
    final lastIsRead = lm['isRead'] == true || data['lastMessageIsRead'] == true;
    final dealId = lm['dealId']?.toString();
    final dealTitle = lm['dealTitle']?.toString();

    DateTime lastCreatedAt;
    try {
      final v = lm['createdAt'] ?? data['lastMessageCreatedAt'];
      if (v is Timestamp) {
        lastCreatedAt = v.toDate();
      } else if (v is DateTime) {
        lastCreatedAt = v;
      } else if (v is String && v.isNotEmpty) {
        lastCreatedAt = DateTime.tryParse(v) ?? DateTime.now();
      } else {
        lastCreatedAt = DateTime.now();
      }
    } catch (_) {
      lastCreatedAt = DateTime.now();
    }

    // updatedAt parse
    DateTime updatedAt;
    try {
      final v = data['updatedAt'];
      if (v is Timestamp) {
        updatedAt = v.toDate();
      } else if (v is DateTime) {
        updatedAt = v;
      } else {
        updatedAt = lastCreatedAt;
      }
    } catch (_) {
      updatedAt = lastCreatedAt;
    }

    // unreadCounts parse
    Map<String, int> unreadCounts = {};
    if (data['unreadCounts'] is Map) {
      (data['unreadCounts'] as Map).forEach((k, v) {
        if (k != null) {
          final count = v is num ? v.toInt() : int.tryParse(v.toString()) ?? 0;
          unreadCounts[k.toString()] = count;
        }
      });
    }

    // clearedAt parse
    Map<String, DateTime?> clearedAt = {};
    if (data['clearedAt'] is Map) {
      (data['clearedAt'] as Map).forEach((k, v) {
        if (k != null) {
          if (v is Timestamp) {
            clearedAt[k.toString()] = v.toDate();
          } else if (v is DateTime) {
            clearedAt[k.toString()] = v;
          } else {
            clearedAt[k.toString()] = null;
          }
        }
      });
    }

    // participantDetails parse
    Map<String, ConversationParticipant> participantDetails = {};
    if (data['participantDetails'] is Map) {
      (data['participantDetails'] as Map).forEach((k, v) {
        if (k != null && v is Map) {
          participantDetails[k.toString()] =
              ConversationParticipant.fromMap(Map<String, dynamic>.from(v));
        }
      });
    }

    return Conversation(
      id: id,
      participants: participants,
      lastMessageText: lastText,
      lastMessageSenderId: lastSenderId,
      lastMessageSenderName: lastSenderName,
      lastMessageCreatedAt: lastCreatedAt,
      lastMessageIsRead: lastIsRead,
      lastMessageDealId: dealId,
      lastMessageDealTitle: dealTitle,
      updatedAt: updatedAt,
      unreadCounts: unreadCounts,
      clearedAt: clearedAt,
      participantDetails: participantDetails,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': {
        'text': lastMessageText,
        'senderId': lastMessageSenderId,
        'senderName': lastMessageSenderName,
        'createdAt': Timestamp.fromDate(lastMessageCreatedAt),
        'isRead': lastMessageIsRead,
        if (lastMessageDealId != null) 'dealId': lastMessageDealId,
        if (lastMessageDealTitle != null) 'dealTitle': lastMessageDealTitle,
      },
      'updatedAt': Timestamp.fromDate(updatedAt),
      'unreadCounts': unreadCounts,
      'clearedAt': clearedAt.map((k, v) => MapEntry(k, v != null ? Timestamp.fromDate(v) : null)),
      'participantDetails': participantDetails.map((k, v) => MapEntry(k, v.toMap())),
    };
  }

  Conversation copyWith({
    String? id,
    List<String>? participants,
    String? lastMessageText,
    String? lastMessageSenderId,
    String? lastMessageSenderName,
    DateTime? lastMessageCreatedAt,
    bool? lastMessageIsRead,
    String? lastMessageDealId,
    String? lastMessageDealTitle,
    DateTime? updatedAt,
    Map<String, int>? unreadCounts,
    Map<String, DateTime?>? clearedAt,
    Map<String, ConversationParticipant>? participantDetails,
  }) {
    return Conversation(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessageText: lastMessageText ?? this.lastMessageText,
      lastMessageSenderId: lastMessageSenderId ?? this.lastMessageSenderId,
      lastMessageSenderName: lastMessageSenderName ?? this.lastMessageSenderName,
      lastMessageCreatedAt: lastMessageCreatedAt ?? this.lastMessageCreatedAt,
      lastMessageIsRead: lastMessageIsRead ?? this.lastMessageIsRead,
      lastMessageDealId: lastMessageDealId ?? this.lastMessageDealId,
      lastMessageDealTitle: lastMessageDealTitle ?? this.lastMessageDealTitle,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCounts: unreadCounts ?? this.unreadCounts,
      clearedAt: clearedAt ?? this.clearedAt,
      participantDetails: participantDetails ?? this.participantDetails,
    );
  }
}
