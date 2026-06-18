// 日付表示の共通フォーマッタ。
//
// アプリ全体で日付に曜日を併記して可読性を上げる。曜日はロケール初期化
// (initializeDateFormatting) 不要にするため日本語配列で解決する。
import 'package:intl/intl.dart';

/// 日本語の曜日（`DateTime.weekday`: 月=1 .. 日=7 に対応）。
const List<String> _weekdayJp = ['月', '火', '水', '木', '金', '土', '日'];

/// 曜日（漢字一文字）を返す。例: 木
String weekdayJp(DateTime date) => _weekdayJp[date.weekday - 1];

/// `yyyy/MM/dd(E)` 形式。例: `2026/06/18(木)`
String formatDateWithWeekday(DateTime date) =>
    '${DateFormat('yyyy/MM/dd').format(date)}(${weekdayJp(date)})';

/// `yyyy年M月d日(E)` 形式。例: `2026年6月18日(木)`
String formatDateLongWithWeekday(DateTime date) =>
    '${DateFormat('yyyy年M月d日').format(date)}(${weekdayJp(date)})';
