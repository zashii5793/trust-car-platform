import 'package:flutter/material.dart';

/// How one maker is shown when there is no logo to show.
///
/// 実ロゴは商標なので同梱できない。代わりに、メーカーごとに決まった色と
/// 短いマークを与えて見分けられるようにする。**実ロゴの再現ではない。**
///
/// 色は「隣り合っても見分けられること」を優先している。国産メーカーは赤を
/// 使う会社が多く、各社のブランド色をそのまま当てると赤が3つ並んで用を
/// なさない。トヨタの赤とレクサスの黒だけ実際の印象に寄せ、あとは色相を
/// 散らしてある。
@immutable
class MakerBrand {
  /// Badge background.
  final Color color;

  /// Text drawn on [color]. 1〜2文字。
  final String mark;

  const MakerBrand({required this.color, required this.mark});

  /// Text color that reads on [color].
  Color get onColor =>
      color.computeLuminance() > 0.5 ? const Color(0xFF1A1A1A) : Colors.white;

  static const Map<String, MakerBrand> _brands = {
    'toyota': MakerBrand(color: Color(0xFFEB0A1E), mark: 'T'),
    'honda': MakerBrand(color: Color(0xFF1565C0), mark: 'H'),
    'nissan': MakerBrand(color: Color(0xFFB3123A), mark: 'N'),
    'mazda': MakerBrand(color: Color(0xFF1B2A6B), mark: 'M'),
    'subaru': MakerBrand(color: Color(0xFF29B6F6), mark: 'SU'),
    'suzuki': MakerBrand(color: Color(0xFFF57C00), mark: 'SZ'),
    'daihatsu': MakerBrand(color: Color(0xFFE91E63), mark: 'D'),
    'mitsubishi': MakerBrand(color: Color(0xFF7B1FA2), mark: 'MI'),
    'lexus': MakerBrand(color: Color(0xFF212121), mark: 'L'),
    'mitsuoka': MakerBrand(color: Color(0xFF6D4C41), mark: 'MO'),
    'isuzu': MakerBrand(color: Color(0xFF00897B), mark: 'I'),
    'hino': MakerBrand(color: Color(0xFF2E7D32), mark: 'HI'),
    'fuso': MakerBrand(color: Color(0xFF455A64), mark: 'F'),
    'ud': MakerBrand(color: Color(0xFF827717), mark: 'UD'),
    'other': MakerBrand(color: Color(0xFF9E9E9E), mark: '＋'),
  };

  /// 未登録のメーカー（自由入力された輸入車など）に配る色。
  /// IDから決めるので、同じメーカーには毎回同じ色が付く。
  static const List<Color> _fallbackColors = [
    Color(0xFF3949AB),
    Color(0xFF00838F),
    Color(0xFF546E7A),
    Color(0xFF8D6E63),
    Color(0xFF5E35B1),
    Color(0xFF00695C),
  ];

  /// 表示名（和名・英名）から makerId を引くための表。
  ///
  /// `Vehicle.maker` は makerId ではなく**和名の文字列**で保存されている
  /// （`Vehicle` 側に makerId が無い）。保存済みの車両にバッジを出すには
  /// ここで引き直すしかない。キーは小文字化して突き合わせる。
  ///
  /// [_brands] と対になっているので、**メーカーを足すときは両方に足すこと。**
  /// ずれたらテスト（マスタの全メーカーが和名から引ける）で落ちる。
  ///
  /// **キーは必ず小文字で書く。** 引くときに `toLowerCase()` するので、
  /// 'UDトラックス' のようにラテン文字混じりの和名を大文字のまま置くと
  /// 一生ヒットしない。
  static const Map<String, String> _idsByName = {
    'トヨタ': 'toyota',
    'toyota': 'toyota',
    'ホンダ': 'honda',
    'honda': 'honda',
    '日産': 'nissan',
    'nissan': 'nissan',
    'マツダ': 'mazda',
    'mazda': 'mazda',
    'スバル': 'subaru',
    'subaru': 'subaru',
    'スズキ': 'suzuki',
    'suzuki': 'suzuki',
    'ダイハツ': 'daihatsu',
    'daihatsu': 'daihatsu',
    '三菱': 'mitsubishi',
    'mitsubishi': 'mitsubishi',
    'レクサス': 'lexus',
    'lexus': 'lexus',
    '光岡自動車': 'mitsuoka',
    '光岡': 'mitsuoka',
    'mitsuoka': 'mitsuoka',
    'いすゞ': 'isuzu',
    'isuzu': 'isuzu',
    '日野': 'hino',
    '日野自動車': 'hino',
    'hino': 'hino',
    '三菱ふそう': 'fuso',
    'mitsubishi fuso': 'fuso',
    'fuso': 'fuso',
    'udトラックス': 'ud',
    'ud trucks': 'ud',
    'ud': 'ud',
    'その他': 'other',
    'other': 'other',
  };

  /// Whether [makerId] is in the catalog (色とマークが決め打ちされている)。
  static bool isKnown(String makerId) => _brands.containsKey(makerId);

  /// Resolves [name] (和名 or 英名) to a maker id.
  ///
  /// カタログに無いメーカーは**名前をそのまま返す**。自由入力を許している
  /// 以上、ここで null を返すと呼び出し側が毎回分岐する羽目になる。
  /// 返り値をそのまま [of] に渡せば、同じ名前には毎回同じ色が付く。
  static String idFromName(String name) {
    final trimmed = name.trim();
    return _idsByName[trimmed.toLowerCase()] ?? trimmed;
  }

  /// Looks up the badge for [makerId].
  ///
  /// カタログに無いメーカーでも必ず何かを返す。自由入力を許している以上、
  /// ここで落ちると**登録そのものができなくなる**。
  static MakerBrand of(String makerId) {
    final known = _brands[makerId];
    if (known != null) return known;

    final id = makerId.trim();
    if (id.isEmpty) {
      return const MakerBrand(color: Color(0xFF9E9E9E), mark: '?');
    }

    var hash = 0;
    for (final unit in id.codeUnits) {
      hash = (hash * 31 + unit) & 0x7FFFFFFF;
    }
    final color = _fallbackColors[hash % _fallbackColors.length];

    final head = id.substring(0, 1).toUpperCase();
    return MakerBrand(color: color, mark: head);
  }
}
