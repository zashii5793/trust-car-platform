import 'package:cloud_firestore/cloud_firestore.dart';

/// Reason a user reports a showcase comment.
enum ReportReason {
  spam('スパム・宣伝'),
  harassment('嫌がらせ・誹謗中傷'),
  inappropriate('不適切な内容'),
  other('その他');

  final String label;
  const ReportReason(this.label);

  static ReportReason fromString(String? value) {
    return ReportReason.values.firstWhere(
      (r) => r.name == value,
      orElse: () => ReportReason.other,
    );
  }
}

/// A user's report of a [ShowcaseComment] for manual moderation.
///
/// Reports are write-only for clients (one per user per comment); reading and
/// moderation happen server-side (Admin SDK / Cloud Functions). No automatic
/// hiding is applied in this MVP — see Issue #37.
class CommentReport {
  final String id;
  final String showcaseId;
  final String commentId;
  final String reporterId;
  final ReportReason reason;
  final String status; // 'pending' until a moderator acts
  final DateTime createdAt;

  const CommentReport({
    required this.id,
    required this.showcaseId,
    required this.commentId,
    required this.reporterId,
    required this.reason,
    this.status = 'pending',
    required this.createdAt,
  });

  factory CommentReport.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return CommentReport(
      id: doc.id,
      showcaseId: data['showcaseId'] ?? '',
      commentId: data['commentId'] ?? '',
      reporterId: data['reporterId'] ?? '',
      reason: ReportReason.fromString(data['reason']),
      status: data['status'] ?? 'pending',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'showcaseId': showcaseId,
      'commentId': commentId,
      'reporterId': reporterId,
      'reason': reason.name,
      'status': status,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}
