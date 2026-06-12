import 'package:cloud_firestore/cloud_firestore.dart';

/// Category of safety information
enum SafetyTipCategory {
  drivingBasics('基本的な安全運転'),
  seasonalDriving('季節別の注意事項'),
  vehicleCheck('乗車前点検'),
  emergencyResponse('緊急時の対応'),
  childSafety('チャイルドシート・子どもの安全'),
  elderlyDriving('高齢ドライバー向け');

  final String displayName;
  const SafetyTipCategory(this.displayName);

  static SafetyTipCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return SafetyTipCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Authoritative source for safety information
enum SafetyTipSource {
  jaf('JAF（日本自動車連盟）'),
  npa('警察庁'),
  mlit('国土交通省'),
  fdma('総務省消防庁'),
  itarda('交通事故総合分析センター（ITARDA）');

  final String displayName;
  const SafetyTipSource(this.displayName);

  static SafetyTipSource? fromString(String? value) {
    if (value == null) return null;
    try {
      return SafetyTipSource.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// Safety information entry sourced exclusively from official Japanese authorities.
///
/// Legal note: all content MUST originate from an official source (JAF, NPA,
/// MLIT, etc.). User-generated safety claims are NOT permitted.
/// Each tip MUST include a [sourceUrl] linking to the original authority page.
class SafetyTip {
  final String id;
  final String title;
  final String body;
  final SafetyTipCategory category;
  final SafetyTipSource source;
  final String sourceUrl; // Direct link to official source page
  final bool isActive;
  final DateTime publishedAt;

  /// Mandatory disclaimer shown with every safety tip.
  static const disclaimer =
      '本情報は公式機関の情報に基づいていますが、最新の法令・規制は各機関の公式サイトでご確認ください。'
      '本アプリは安全運転の代替とはなりません。';

  const SafetyTip({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    required this.source,
    required this.sourceUrl,
    this.isActive = true,
    required this.publishedAt,
  });

  factory SafetyTip.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SafetyTip(
      id: doc.id,
      title: data['title'] ?? '',
      body: data['body'] ?? '',
      category: SafetyTipCategory.fromString(data['category']) ??
          SafetyTipCategory.drivingBasics,
      source: SafetyTipSource.fromString(data['source']) ?? SafetyTipSource.jaf,
      sourceUrl: data['sourceUrl'] ?? '',
      isActive: data['isActive'] ?? true,
      publishedAt:
          (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'body': body,
      'category': category.name,
      'source': source.name,
      'sourceUrl': sourceUrl,
      'isActive': isActive,
      'publishedAt': Timestamp.fromDate(publishedAt),
    };
  }
}
