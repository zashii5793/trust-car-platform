// 台帳の画面で使う表示の書式。
//
// ロケールの初期化に頼らない形にしてある（テストで intl の初期化を
// 忘れると、日付だけ英語になる）。

String ledgerDate(DateTime d) => '${d.year}/${d.month}/${d.day}';

/// [target] まで何日か。今日が満了日なら0、過ぎていれば負。
int ledgerDaysUntil(DateTime target, DateTime today) {
  final a = DateTime(today.year, today.month, today.day);
  final b = DateTime(target.year, target.month, target.day);
  return b.difference(a).inDays;
}

/// 「3か月前」「2年前」のような言い方。
String ledgerMonthsAgo(DateTime past, DateTime today) {
  final months = (today.year - past.year) * 12 + (today.month - past.month);
  if (months < 1) return '今月';
  if (months < 24) return '$monthsか月前';
  return '${months ~/ 12}年前';
}

/// 入力から数字だけを取り出す（全角も半角にする）。
String ledgerDigits(String input) {
  final b = StringBuffer();
  for (final r in input.runes) {
    if (r >= 0x30 && r <= 0x39) b.writeCharCode(r);
    if (r >= 0xFF10 && r <= 0xFF19) b.writeCharCode(r - 0xFEE0);
  }
  return b.toString();
}

/// 3桁区切り（48,210 など）。
String ledgerNumber(int v) => v.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'),
      (m) => '${m[1]},',
    );
