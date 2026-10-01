import 'package:cloud_firestore/cloud_firestore.dart';

/// ウェブ版で起きた不具合1件分（`client_errors` に書く中身）。
///
/// Crashlytics は Web 非対応なので、ウェブ版の不具合は Firestore に直接残す。
/// `client_errors` はログイン中の誰でも書ける場所（2026-10-01 からログイン必須）なので、ここで作る中身は
/// ルール（firestore.rules の `client_errors`）の上限に必ず収める。
///
/// **個人情報を持ち込まない。** 入力値・メール・電話・住所は入れない：
/// - メッセージはエラーの**1行目だけ**。FlutterError の2行目以降には
///   ウィジェットの中身（`Text("山田太郎")` など）が出ることがある
/// - メールアドレスと、7桁以上の数字の並び（電話・郵便番号）は伏せる
/// - URL はパスだけ。クエリ（トークンやメールが載りうる）は落とす
class ClientErrorReport {
  /// 各項目の上限。firestore.rules の `client_errors` と揃えること。
  static const int maxMessageLength = 500;
  static const int maxStackLines = 30;
  static const int maxStackLength = 4000;
  static const int maxPathLength = 200;
  static const int maxUserAgentLength = 300;
  static const int maxBuildIdLength = 40;

  /// 保存期間。`expireAt` に入れ、Firestore の TTL ポリシーで消す。
  /// ルール側は「今から 120 日以内」まで許す（端末の時計のずれの分）。
  static const Duration retention = Duration(days: 90);

  /// どの入口で拾ったか。
  static const String sourceFlutter = 'flutter';
  static const String sourcePlatform = 'platform';
  static const String sourceZone = 'zone';

  final String message;
  final String stack;
  final String source;
  final String buildId;
  final String path;
  final String? userAgent;
  final String? uid;

  const ClientErrorReport._({
    required this.message,
    required this.stack,
    required this.source,
    required this.buildId,
    required this.path,
    required this.userAgent,
    required this.uid,
  });

  factory ClientErrorReport.from({
    required Object error,
    required StackTrace? stackTrace,
    required String source,
    required String buildId,
    required Uri url,
    required String? userAgent,
    required String? uid,
  }) {
    final ua = (userAgent ?? '').trim();
    final id = (uid ?? '').trim();
    final build = buildId.trim();

    return ClientErrorReport._(
      message: _messageOf(error),
      stack: _stackOf(stackTrace),
      source: source,
      buildId: build.isEmpty ? 'unknown' : _cut(build, maxBuildIdLength),
      path: _pathOf(url),
      userAgent: ua.isEmpty ? null : _cut(ua, maxUserAgentLength),
      uid: id.isEmpty ? null : id,
    );
  }

  /// Firestore に書く形。`createdAt` はサーバ時刻（ルールで request.time と照合）。
  Map<String, dynamic> toMap({required DateTime now}) => {
        'message': message,
        'stack': stack,
        'source': source,
        'buildId': buildId,
        'path': path,
        'userAgent': userAgent,
        'uid': uid,
        'platform': 'web',
        'createdAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(now.add(retention)),
      };

  static final RegExp _email = RegExp(r'[\w.+-]+@[\w-]+(?:\.[\w-]+)+');

  /// 電話・郵便番号の候補。区切り（- と空白）を含めて数字が7桁以上なら伏せる。
  static final RegExp _numberRun = RegExp(r'\+?\d[\d\- ]*\d');

  static String _messageOf(Object error) {
    String text;
    try {
      text = error.toString();
    } catch (_) {
      // toString 自体が壊れているエラーもある。型名だけ残す。
      text = 'Unprintable ${error.runtimeType}';
    }

    final firstLine = text
        .split('\n')
        .map((l) => l.trim())
        .firstWhere((l) => l.isNotEmpty, orElse: () => '');
    if (firstLine.isEmpty) return '(empty)';

    final masked = _maskNumbers(_maskEmails(firstLine));
    return _cut(masked, maxMessageLength);
  }

  static String _stackOf(StackTrace? stackTrace) {
    if (stackTrace == null) return '';
    // スタックの数字（main.dart.js の行・列）は手掛かりなので伏せない。
    // メールだけは念のため伏せる。
    final lines = stackTrace
        .toString()
        .split('\n')
        .where((l) => l.trim().isNotEmpty)
        .take(maxStackLines)
        .map(_maskEmails);
    return _cut(lines.join('\n'), maxStackLength);
  }

  static String _pathOf(Uri url) {
    final path = url.path.isEmpty ? '/' : url.path;
    // ハッシュ形式のルート（/#/vehicles）も、クエリを落として残す。
    final fragment = url.fragment.split('?').first;
    final full = fragment.isEmpty ? path : '$path#$fragment';
    return _cut(full, maxPathLength);
  }

  static String _maskEmails(String text) => text.replaceAll(_email, '[email]');

  static String _maskNumbers(String text) =>
      text.replaceAllMapped(_numberRun, (m) {
        final digits = m[0]!.replaceAll(RegExp(r'\D'), '').length;
        return digits >= 7 ? '[number]' : m[0]!;
      });

  static String _cut(String text, int max) {
    if (text.length <= max) return text;
    var end = max;
    // サロゲートペアの片割れを残さない（絵文字の途中で切らない）。
    final last = text.codeUnitAt(end - 1);
    if (last >= 0xD800 && last <= 0xDBFF) end--;
    return text.substring(0, end);
  }
}
