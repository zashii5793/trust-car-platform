import 'package:cloud_firestore/cloud_firestore.dart';

enum FaqCategory {
  maintenance('整備・メンテナンス'),
  inspection('車検・点検'),
  parts('部品・パーツ'),
  trouble('トラブル・故障'),
  general('一般質問');

  final String displayName;
  const FaqCategory(this.displayName);

  static FaqCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return FaqCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

class Faq {
  final String id;
  final String question;
  final String? detail;
  final FaqCategory category;
  final String authorId;
  final DateTime createdAt;
  final int viewCount;
  final int answerCount;
  final bool allowShopResponse;
  final String? vehicleMaker;
  final String? vehicleModel;
  final List<String> tags;

  const Faq({
    required this.id,
    required this.question,
    this.detail,
    required this.category,
    required this.authorId,
    required this.createdAt,
    this.viewCount = 0,
    this.answerCount = 0,
    this.allowShopResponse = false,
    this.vehicleMaker,
    this.vehicleModel,
    this.tags = const [],
  });

  factory Faq.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Faq(
      id: doc.id,
      question: data['question'] as String? ?? '',
      detail: data['detail'] as String?,
      category: FaqCategory.fromString(data['category'] as String?) ??
          FaqCategory.general,
      authorId: data['authorId'] as String? ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      viewCount: data['viewCount'] as int? ?? 0,
      answerCount: data['answerCount'] as int? ?? 0,
      allowShopResponse: data['allowShopResponse'] as bool? ?? false,
      vehicleMaker: data['vehicleMaker'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      tags: List<String>.from(data['tags'] as List<dynamic>? ?? []),
    );
  }

  Map<String, dynamic> toMap() => {
        'question': question,
        if (detail != null) 'detail': detail,
        'category': category.name,
        'authorId': authorId,
        'createdAt': Timestamp.fromDate(createdAt),
        'viewCount': viewCount,
        'answerCount': answerCount,
        'allowShopResponse': allowShopResponse,
        if (vehicleMaker != null) 'vehicleMaker': vehicleMaker,
        if (vehicleModel != null) 'vehicleModel': vehicleModel,
        'tags': tags,
      };
}

class FaqAnswer {
  final String id;
  final String faqId;
  final String content;
  final String authorId;
  final String? authorName;
  final bool isShopResponse;
  final String? shopId;
  final int helpfulCount;
  final bool isBestAnswer;
  final DateTime createdAt;

  const FaqAnswer({
    required this.id,
    required this.faqId,
    required this.content,
    required this.authorId,
    this.authorName,
    this.isShopResponse = false,
    this.shopId,
    this.helpfulCount = 0,
    this.isBestAnswer = false,
    required this.createdAt,
  });

  factory FaqAnswer.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return FaqAnswer(
      id: doc.id,
      faqId: data['faqId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      authorId: data['authorId'] as String? ?? '',
      authorName: data['authorName'] as String?,
      isShopResponse: data['isShopResponse'] as bool? ?? false,
      shopId: data['shopId'] as String?,
      helpfulCount: data['helpfulCount'] as int? ?? 0,
      isBestAnswer: data['isBestAnswer'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'faqId': faqId,
        'content': content,
        'authorId': authorId,
        if (authorName != null) 'authorName': authorName,
        'isShopResponse': isShopResponse,
        if (shopId != null) 'shopId': shopId,
        'helpfulCount': helpfulCount,
        'isBestAnswer': isBestAnswer,
        'createdAt': Timestamp.fromDate(createdAt),
      };
}
