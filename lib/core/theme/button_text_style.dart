import 'package:flutter/material.dart';

/// Button label style derived from the theme.
///
/// **Do not build a bare `TextStyle` for button labels.** A style created with
/// `TextStyle(fontSize: 16)` carries no font family. On a device that falls
/// back to the system font and nothing looks wrong, but the test embedder has
/// no Japanese in its default face, so **every such label renders as tofu (□)
/// in golden images** - which makes the images useless for checking layout.
///
/// Deriving from `textTheme.labelLarge` keeps the family that the theme (and
/// `goldenTheme` in tests) provides, while still letting the caller change the
/// size and weight.
TextStyle buttonTextStyle(
  BuildContext context, {
  double? fontSize,
  FontWeight? fontWeight,
}) {
  final base = Theme.of(context).textTheme.labelLarge ?? const TextStyle();
  return base.copyWith(fontSize: fontSize, fontWeight: fontWeight);
}
