import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// `navigator.userAgent` を読む。取れなければ null（例外は投げない）。
String? browserUserAgent() {
  try {
    final navigator = globalContext.getProperty<JSObject?>('navigator'.toJS);
    return navigator?.getProperty<JSString?>('userAgent'.toJS)?.toDart;
  } catch (_) {
    return null;
  }
}
