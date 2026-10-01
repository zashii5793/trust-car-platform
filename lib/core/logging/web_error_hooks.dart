import 'package:flutter/foundation.dart';

import 'web_error_reporter.dart';

/// 送り先を引く関数。起動の途中（ServiceLocator に登録される前）は null を返す。
typedef WebErrorReporterResolver = WebErrorReporter? Function();

/// ウェブ版で、捕まらなかったエラーを [WebErrorReporter] に流す。
///
/// - `FlutterError.onError`：元のハンドラ（コンソール出力）も今までどおり呼ぶ
/// - `PlatformDispatcher.instance.onError`：Web では今は呼ばれない
///   （flutter/flutter#100277）が、直ったときに拾えるよう付けておく。
///   非同期の例外は main の `runZonedGuarded` から [reportZoneError] で拾う
///
/// 送り先は呼ばれたときに引く。起動直後で未登録なら何もしない。
void installWebErrorHooks(WebErrorReporterResolver resolve) {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    previous?.call(details);
    _resolve(resolve)?.handleFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    _resolve(resolve)?.handlePlatformError(error, stack);
    return true;
  };
}

/// `runZonedGuarded` の onError から呼ぶ。
void reportZoneError(
  WebErrorReporterResolver resolve,
  Object error,
  StackTrace stack,
) {
  _resolve(resolve)?.handleZoneError(error, stack);
}

WebErrorReporter? _resolve(WebErrorReporterResolver resolve) {
  try {
    return resolve();
  } catch (_) {
    return null;
  }
}
