import 'package:cloud_firestore/cloud_firestore.dart';

/// アプリへの車検案内（プッシュ）の依頼。`shops/{shopId}/inspection_notices/{id}`
///
/// 店のスタッフが「この車の持ち主に送って」と置く。送るのはサーバー
/// （functions の onInspectionNoticeCreated）で、結果もサーバーが書く。
/// クライアントは置いたあと書き換えられない（ルールで止める）。
class InspectionPushRequest {
  final String id;
  final String requesterUid;
  final List<String> vehicleIds;
  final InspectionPushStatus status;

  /// 送った結果。サーバーが書くまでは null。
  final InspectionPushResult? result;
  final DateTime? createdAt;

  const InspectionPushRequest({
    required this.id,
    required this.requesterUid,
    required this.vehicleIds,
    required this.status,
    this.result,
    this.createdAt,
  });

  bool get isFinished => status != InspectionPushStatus.pending;

  factory InspectionPushRequest.fromMap(String id, Map<String, dynamic> m) {
    final r = m['result'];
    return InspectionPushRequest(
      id: id,
      requesterUid: m['requesterUid'] as String? ?? '',
      vehicleIds: [
        for (final v in (m['vehicleIds'] as List?) ?? const [])
          if (v is String) v,
      ],
      status: InspectionPushStatus.fromName(m['status'] as String?),
      result: r is Map ? InspectionPushResult.fromMap(r) : null,
      createdAt: (m['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}

enum InspectionPushStatus {
  /// サーバーがまだ処理していない。
  pending,

  /// 処理し終えた（1台も届かなかった場合も含む。中身は result で見る）。
  done,

  /// 処理の途中で失敗した。
  failed;

  static InspectionPushStatus fromName(String? n) {
    for (final s in values) {
      if (s.name == n) return s;
    }
    return pending;
  }
}

/// 送った結果（台数）。functions/src/inspectionNotice.ts の NoticeResult と同じ形。
class InspectionPushResult {
  /// 案内が届いた（少なくとも1台の端末に送れた）車。
  final int sent;

  /// いまの満了日で、もう案内済みだった車（二度送らない）。
  final int alreadyNoticed;

  /// アプリとのつながりが切れていた車。
  final int notLinked;

  /// 利用者が通知（プッシュ・車検リマインダー）を切っている車。
  final int pushOff;

  /// 利用者の端末が登録されていない車（通知を受け取れる端末が無い）。
  final int noDevice;

  /// 満了日が案内の時期から外れていた車。
  final int outOfRange;

  /// 消された車。
  final int notFound;

  /// 送ろうとして失敗した車。
  final int failed;

  const InspectionPushResult({
    this.sent = 0,
    this.alreadyNoticed = 0,
    this.notLinked = 0,
    this.pushOff = 0,
    this.noDevice = 0,
    this.outOfRange = 0,
    this.notFound = 0,
    this.failed = 0,
  });

  factory InspectionPushResult.fromMap(Map<dynamic, dynamic> m) {
    int n(String k) {
      final v = m[k];
      return v is num ? v.toInt() : 0;
    }

    return InspectionPushResult(
      sent: n('sent'),
      alreadyNoticed: n('alreadyNoticed'),
      notLinked: n('notLinked'),
      pushOff: n('pushOff'),
      noDevice: n('noDevice'),
      outOfRange: n('outOfRange'),
      notFound: n('notFound'),
      failed: n('failed'),
    );
  }

  /// 届かなかった理由の一覧（台数の無いものは出さない）。画面の説明用。
  List<String> get skippedNotes => [
        if (alreadyNoticed > 0) '案内済みの$alreadyNoticed台',
        if (pushOff > 0) '通知を切っている$pushOff台',
        if (noDevice > 0) '通知を受け取れる端末が無い$noDevice台',
        if (notLinked > 0) 'アプリとのつながりが切れた$notLinked台',
        if (outOfRange > 0) '満了日が案内の時期でない$outOfRange台',
        if (notFound > 0) '消された$notFound台',
        if (failed > 0) '送信に失敗した$failed台',
      ];
}
