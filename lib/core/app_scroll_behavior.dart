import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// App-wide [ScrollBehavior] that allows drag-to-scroll with a mouse and
/// trackpad in addition to touch/stylus.
///
/// Flutter's default [MaterialScrollBehavior] omits [PointerDeviceKind.mouse]
/// and [PointerDeviceKind.trackpad] from [dragDevices]. On web and desktop that
/// means scrollable lists (e.g. the fleet dashboard) cannot be scrolled by
/// dragging — only via the mouse wheel or scrollbar — which reads as "the list
/// won't scroll". Adding those devices restores drag scrolling on web/desktop
/// without affecting touch platforms.
///
/// Applied via [MaterialApp.scrollBehavior].
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        ...super.dragDevices,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}
