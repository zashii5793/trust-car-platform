/// ブラウザの userAgent を返す。ウェブ以外・取れないときは null。
///
/// `dart:js_interop` はウェブでしか読み込めないので、条件付き import で分ける。
library;

export 'browser_user_agent_stub.dart'
    if (dart.library.js_interop) 'browser_user_agent_web.dart';
