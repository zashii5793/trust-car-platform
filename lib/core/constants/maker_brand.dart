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
