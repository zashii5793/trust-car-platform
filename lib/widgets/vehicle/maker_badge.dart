import 'package:flutter/material.dart';

import '../../core/constants/maker_brand.dart';

/// A colored mark standing in for a maker logo.
///
/// メーカー一覧は「灰色の丸に和名の1文字目」だった。「ト」「ホ」「日」「マ」が
/// 灰色で並ぶだけで、見分けも付かないし、そもそも安っぽい（2026-08-25 の指摘）。
///
/// 実ロゴは商標なので同梱できない。色とマークで代用する。
/// 平面の塗り潰しだとまだ素っ気ないので、上を明るくしたグラデーションと
/// 内側のハイライト、控えめな落ち影で立体感を出している。
class MakerBadge extends StatelessWidget {
  final String makerId;

  /// 読み上げ用。渡さないとマークがそのまま読まれる（「ＳＵ」など）。
  final String? makerName;

  final double size;

  /// 選択中の見せ方。枠を付けて、色は変えない
  /// （色を変えるとメーカーの見分けが付かなくなる）。
  final bool isSelected;

  const MakerBadge({
    super.key,
    required this.makerId,
    this.makerName,
    this.size = 40,
    this.isSelected = false,
  });

  /// メーカー名（和名・英名）から組み立てる。
  ///
  /// `Vehicle.maker` は makerId を持たず和名だけなので、保存済み車両の
  /// カードではこちらを使う。
  factory MakerBadge.fromName(
    String makerName, {
    Key? key,
    double size = 40,
    bool isSelected = false,
  }) {
    return MakerBadge(
      key: key,
      makerId: MakerBrand.idFromName(makerName),
      makerName: makerName,
      size: size,
      isSelected: isSelected,
    );
  }

  /// 色とマークを決めるのに使う id。
  ///
  /// 自由入力のメーカーは id が `custom_<タイムスタンプ>` になる
  /// （`_submitCustom`）。これをそのまま使うと登録のたびに色が変わり、
  /// マークは全部「C」になる。カタログに無い id は名前で引き直す。
  String get _colorKey {
    if (MakerBrand.isKnown(makerId)) return makerId;

    final name = (makerName ?? '').trim();
    return name.isEmpty ? makerId : MakerBrand.idFromName(name);
  }

  @override
  Widget build(BuildContext context) {
    final brand = MakerBrand.of(_colorKey);
    final label = (makerName ?? '').trim();

    // 選択枠は外側に足すのではなく内側に食い込ませる。外形が変わると
    // 一覧の行が選択のたびにガタつく。
    final ringWidth = isSelected ? size * 0.075 : 0.0;

    return Semantics(
      label: label.isEmpty ? null : label,
      image: true,
      child: SizedBox(
        width: size,
        height: size,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: isSelected
                ? Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: ringWidth,
                  )
                : null,
          ),
          child: Padding(
            padding: EdgeInsets.all(isSelected ? ringWidth * 0.7 : 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_lighten(brand.color), brand.color],
                ),
                // 影は塗り色を薄めたもの。黒い影だとどのメーカーも
                // 同じにくすんで、色で見分ける利点が消える。
                boxShadow: [
                  BoxShadow(
                    color: brand.color.withValues(alpha: 0.35),
                    blurRadius: size * 0.12,
                    offset: Offset(0, size * 0.05),
                  ),
                ],
              ),
              child: Center(
                child: ExcludeSemantics(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Padding(
                      padding: EdgeInsets.symmetric(horizontal: size * 0.15),
                      child: Text(
                        brand.mark,
                        style: TextStyle(
                          color: brand.onColor,
                          fontSize: size * 0.42,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                          height: 1.0,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// 塗り色の明るい側。HSL で持ち上げるので、暗いレクサス黒でも
  /// 白飛びせずに階調が付く。
  static Color _lighten(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness + 0.14).clamp(0.0, 1.0)).toColor();
  }
}
