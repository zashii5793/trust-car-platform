import 'package:cloud_firestore/cloud_firestore.dart';

/// 走行距離の更新履歴の1件。
///
/// 走行距離は更新の都度「値＋日時」を記録し、推移を後から追えるようにする。
/// 監査用途のため履歴は不変（作成のみ／更新・削除しない）。
class MileageRecord {
  final String id;
  final String userId;
  final int mileage;
  final DateTime recordedAt;

  /// 任意メモ（例: 給油時・車検時など、記録のきっかけ）
  final String? note;

  const MileageRecord({
    required this.id,
    required this.userId,
    required this.mileage,
    required this.recordedAt,
    this.note,
  });

  factory MileageRecord.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return MileageRecord(
      id: doc.id,
      userId: (data['userId'] ?? '') as String,
      mileage: (data['mileage'] ?? 0) as int,
      recordedAt:
          (data['recordedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      note: data['note'] as String?,
    );
  }

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'mileage': mileage,
        'recordedAt': Timestamp.fromDate(recordedAt),
        if (note != null) 'note': note,
      };
}
