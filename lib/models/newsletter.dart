import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';

enum NewsletterStatus {
  draft,
  scheduled,
  sent;

  String get displayName {
    switch (this) {
      case draft:
        return '下書き';
      case scheduled:
        return '配信予定';
      case sent:
        return '配信済み';
    }
  }
}

enum NewsletterAudience {
  allUsers,
  vehicleOwners,
  premiumUsers,
  shopFollowers;

  String get displayName {
    switch (this) {
      case allUsers:
        return '全ユーザー';
      case vehicleOwners:
        return '車両登録済みユーザー';
      case premiumUsers:
        return 'プレミアムユーザー';
      case shopFollowers:
        return '店舗フォロワー';
    }
  }
}

enum NewsletterCategory {
  maintenanceTips,
  shopPromotion,
  systemUpdate,
  newFeature;

  String get displayName {
    switch (this) {
      case maintenanceTips:
        return '整備・メンテナンス情報';
      case shopPromotion:
        return '整備工場からのお知らせ';
      case systemUpdate:
        return 'アプリ更新情報';
      case newFeature:
        return '新機能のご案内';
    }
  }
}

/// Newsletter document stored in Firestore `newsletters` collection.
class Newsletter {
  final String id;
  final String title;
  final String body;
  final String authorId;
  final String authorName;
  final NewsletterAudience audience;
  final NewsletterCategory category;
  final NewsletterStatus status;
  final DateTime? scheduledAt;
  final DateTime? sentAt;
  final int recipientCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  const Newsletter({
    required this.id,
    required this.title,
    required this.body,
    required this.authorId,
    required this.authorName,
    this.audience = NewsletterAudience.allUsers,
    this.category = NewsletterCategory.maintenanceTips,
    this.status = NewsletterStatus.draft,
    this.scheduledAt,
    this.sentAt,
    this.recipientCount = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Newsletter.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Newsletter(
      id: doc.id,
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String? ?? '',
      audience: NewsletterAudience.values.firstWhere(
        (e) => e.name == data['audience'],
        orElse: () => NewsletterAudience.allUsers,
      ),
      category: NewsletterCategory.values.firstWhere(
        (e) => e.name == data['category'],
        orElse: () => NewsletterCategory.maintenanceTips,
      ),
      status: NewsletterStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => NewsletterStatus.draft,
      ),
      scheduledAt: (data['scheduledAt'] as Timestamp?)?.toDate(),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate(),
      recipientCount: (data['recipientCount'] as int?) ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'body': body,
        'authorId': authorId,
        'authorName': authorName,
        'audience': audience.name,
        'category': category.name,
        'status': status.name,
        if (scheduledAt != null)
          'scheduledAt': Timestamp.fromDate(scheduledAt!),
        if (sentAt != null) 'sentAt': Timestamp.fromDate(sentAt!),
        'recipientCount': recipientCount,
        'createdAt': Timestamp.fromDate(createdAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  Newsletter copyWith({
    String? id,
    String? title,
    String? body,
    String? authorId,
    String? authorName,
    NewsletterAudience? audience,
    NewsletterCategory? category,
    NewsletterStatus? status,
    DateTime? scheduledAt,
    DateTime? sentAt,
    int? recipientCount,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      Newsletter(
        id: id ?? this.id,
        title: title ?? this.title,
        body: body ?? this.body,
        authorId: authorId ?? this.authorId,
        authorName: authorName ?? this.authorName,
        audience: audience ?? this.audience,
        category: category ?? this.category,
        status: status ?? this.status,
        scheduledAt: scheduledAt ?? this.scheduledAt,
        sentAt: sentAt ?? this.sentAt,
        recipientCount: recipientCount ?? this.recipientCount,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}

/// Per-user newsletter subscription preferences.
class NewsletterSubscription {
  final String userId;
  final String email;
  final bool isSubscribed;
  final List<NewsletterCategory> subscribedCategories;
  final String unsubscribeToken;
  final DateTime updatedAt;

  const NewsletterSubscription({
    required this.userId,
    required this.email,
    this.isSubscribed = true,
    List<NewsletterCategory>? subscribedCategories,
    String? unsubscribeToken,
    required this.updatedAt,
  })  : subscribedCategories =
            subscribedCategories ?? NewsletterCategory.values,
        unsubscribeToken = unsubscribeToken ?? '';

  factory NewsletterSubscription.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawCategories =
        (data['subscribedCategories'] as List<dynamic>?)?.cast<String>() ?? [];
    return NewsletterSubscription(
      userId: doc.id,
      email: data['email'] as String? ?? '',
      isSubscribed: data['isSubscribed'] as bool? ?? true,
      subscribedCategories: rawCategories
          .map((s) => NewsletterCategory.values.firstWhere(
                (e) => e.name == s,
                orElse: () => NewsletterCategory.maintenanceTips,
              ))
          .toList(),
      unsubscribeToken: data['unsubscribeToken'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'email': email,
        'isSubscribed': isSubscribed,
        'subscribedCategories':
            subscribedCategories.map((c) => c.name).toList(),
        'unsubscribeToken': unsubscribeToken,
        'updatedAt': Timestamp.fromDate(updatedAt),
      };

  NewsletterSubscription copyWith({
    String? userId,
    String? email,
    bool? isSubscribed,
    List<NewsletterCategory>? subscribedCategories,
    String? unsubscribeToken,
    DateTime? updatedAt,
  }) =>
      NewsletterSubscription(
        userId: userId ?? this.userId,
        email: email ?? this.email,
        isSubscribed: isSubscribed ?? this.isSubscribed,
        subscribedCategories: subscribedCategories ?? this.subscribedCategories,
        unsubscribeToken: unsubscribeToken ?? this.unsubscribeToken,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  /// Generates a secure random unsubscribe token.
  static String generateToken() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rand = Random.secure();
    return List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
