import 'package:flutter/material.dart';

import '../../core/constants/maker_brand.dart';

/// A colored mark standing in for a maker logo.
///
/// メーカー一覧は「灰色の丸に和名の1文字目」だった。「ト」「ホ」「日」「マ」が
/// 灰色で並ぶだけで、見分けも付かないし、そもそも安っぽい（2026-08-25 の指摘）。
///
/// 実ロゴは商標なので同梱できない。色とマークで代用する。
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

  @override
  Widget build(BuildContext context) {
    final brand = MakerBrand.of(makerId);
    final label = (makerName ?? '').trim();

    return Semantics(
      label: label.isEmpty ? null : label,
      image: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: brand.color,
          shape: BoxShape.circle,
          border: isSelected
              ? Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 3,
                )
              : null,
        ),
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
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
