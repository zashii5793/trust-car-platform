import 'package:flutter/material.dart';

/// How one maker is shown.
///
/// カタログのメーカー（国産・輸入車）は公式サイトから取ったロゴを出す（[logoAsset]）。
/// ロゴが無いメーカー（自由入力の輸入車など）と、画像が読めなかったときは、
/// メーカーごとに決まった色と短いマークのバッジで代用する。
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
    // 輸入車
    'mercedes': MakerBrand(color: Color(0xFF37474F), mark: 'MB'),
    'bmw': MakerBrand(color: Color(0xFF0277BD), mark: 'B'),
    'mini': MakerBrand(color: Color(0xFF424242), mark: 'MN'),
    'volkswagen': MakerBrand(color: Color(0xFF0D47A1), mark: 'VW'),
    'audi': MakerBrand(color: Color(0xFF616161), mark: 'A'),
    'porsche': MakerBrand(color: Color(0xFFA1887F), mark: 'P'),
    'volvo': MakerBrand(color: Color(0xFF1A237E), mark: 'V'),
    'peugeot': MakerBrand(color: Color(0xFF263238), mark: 'PG'),
    'jeep': MakerBrand(color: Color(0xFF558B2F), mark: 'J'),
    'landrover': MakerBrand(color: Color(0xFF1B5E20), mark: 'LR'),
    'fiat': MakerBrand(color: Color(0xFFC62828), mark: 'FI'),
    'renault': MakerBrand(color: Color(0xFFFBC02D), mark: 'R'),
    'citroen': MakerBrand(color: Color(0xFF8E24AA), mark: 'C'),
    'tesla': MakerBrand(color: Color(0xFFD32F2F), mark: 'TE'),
    'ferrari': MakerBrand(color: Color(0xFFFFD600), mark: 'FE'),
    'lamborghini': MakerBrand(color: Color(0xFFBF9000), mark: 'LA'),
    'jaguar': MakerBrand(color: Color(0xFF004D40), mark: 'JA'),
    'abarth': MakerBrand(color: Color(0xFFFF5252), mark: 'AB'),
    'byd': MakerBrand(color: Color(0xFF4E342E), mark: 'BY'),
    'hyundai': MakerBrand(color: Color(0xFF002C5F), mark: 'HY'),
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
    // 輸入車
    'メルセデス・ベンツ': 'mercedes',
    'mercedes-benz': 'mercedes',
    'mercedes': 'mercedes',
    'メルセデス': 'mercedes',
    'ベンツ': 'mercedes',
    'mercedes benz': 'mercedes',
    'benz': 'mercedes',
    'bmw': 'bmw',
    'mini': 'mini',
    'ミニ': 'mini',
    'フォルクスワーゲン': 'volkswagen',
    'volkswagen': 'volkswagen',
    'vw': 'volkswagen',
    'ワーゲン': 'volkswagen',
    'アウディ': 'audi',
    'audi': 'audi',
    'ポルシェ': 'porsche',
    'porsche': 'porsche',
    'ボルボ': 'volvo',
    'volvo': 'volvo',
    'プジョー': 'peugeot',
    'peugeot': 'peugeot',
    'ジープ': 'jeep',
    'jeep': 'jeep',
    'ランドローバー': 'landrover',
    'land rover': 'landrover',
    'landrover': 'landrover',
    'ランド・ローバー': 'landrover',
    'フィアット': 'fiat',
    'fiat': 'fiat',
    'ルノー': 'renault',
    'renault': 'renault',
    'シトロエン': 'citroen',
    'citroën': 'citroen',
    'citroen': 'citroen',
    'テスラ': 'tesla',
    'tesla': 'tesla',
    'フェラーリ': 'ferrari',
    'ferrari': 'ferrari',
    'ランボルギーニ': 'lamborghini',
    'lamborghini': 'lamborghini',
    'ジャガー': 'jaguar',
    'jaguar': 'jaguar',
    'アバルト': 'abarth',
    'abarth': 'abarth',
    'byd': 'byd',
    'ヒョンデ': 'hyundai',
    'hyundai': 'hyundai',
    'ヒュンダイ': 'hyundai',
    'その他': 'other',
    'other': 'other',
  };

  /// ロゴ画像があるメーカー（国産14社・輸入車20社）。画像は `assets/images/makers/<id>.png`
  /// （256px 角・白地。各社の公式サイトから取得。Issue #214）。
  static const Set<String> _logoIds = {
    'toyota',
    'honda',
    'nissan',
    'mazda',
    'subaru',
    'suzuki',
    'daihatsu',
    'mitsubishi',
    'lexus',
    'mitsuoka',
    'isuzu',
    'hino',
    'fuso',
    'ud',
    'mercedes',
    'bmw',
    'mini',
    'volkswagen',
    'audi',
    'porsche',
    'volvo',
    'peugeot',
    'jeep',
    'landrover',
    'fiat',
    'renault',
    'citroen',
    'tesla',
    'ferrari',
    'lamborghini',
    'jaguar',
    'abarth',
    'byd',
    'hyundai',
  };

  /// ロゴ画像のパス。無ければ null（色とマークのバッジを出す）。
  static String? logoAsset(String makerId) =>
      _logoIds.contains(makerId) ? 'assets/images/makers/$makerId.png' : null;

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
