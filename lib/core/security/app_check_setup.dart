import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';

/// App Check をどう動かすか（2026-09-29 プロダクト評価 #10）。
///
/// App Check は「正規のアプリからのアクセスか」を Firebase が確かめる仕組み。
/// **まずは監視だけ**で入れる。弾くかどうか（強制）は Firebase Console で
/// サービスごとに切り替えるもので、アプリ側で有効にしただけでは誰も弾かれない。
/// Console で数週間「正規のリクエストの割合」を見てから強制に切り替える
/// （`docs/HUMAN_TASKS.md` P2-13）。
enum AppCheckMode {
  /// 動かさない（エミュレータ接続中・Web で鍵が無い）
  off,

  /// 開発用（デバッグ用トークン。Console にトークンを登録すると通る）
  debug,

  /// 本番用（Play Integrity / App Attest＋DeviceCheck / reCAPTCHA v3）
  production,
}

/// どのモードで動かすかを決める（純粋な判断。テストで確かめる）。
AppCheckMode decideAppCheckMode({
  required bool isWeb,
  required bool isDebug,
  required bool useEmulator,
  required String webSiteKey,
}) {
  if (useEmulator) return AppCheckMode.off;
  if (isWeb && webSiteKey.isEmpty) return AppCheckMode.off;
  return isDebug ? AppCheckMode.debug : AppCheckMode.production;
}

/// Web の reCAPTCHA v3 のサイトキー。`--dart-define=APP_CHECK_WEB_SITE_KEY=...`
const String _webSiteKey =
    String.fromEnvironment('APP_CHECK_WEB_SITE_KEY', defaultValue: '');

/// 起動時に呼ぶ。**失敗してもアプリの起動は止めない**（監視だけなので、
/// 動かなくても利用者に影響は無い）。
Future<void> activateAppCheck({required bool useEmulator}) async {
  final mode = decideAppCheckMode(
    isWeb: kIsWeb,
    isDebug: kDebugMode,
    useEmulator: useEmulator,
    webSiteKey: _webSiteKey,
  );
  if (mode == AppCheckMode.off) return;
  final debug = mode == AppCheckMode.debug;
  try {
    await FirebaseAppCheck.instance.activate(
      providerWeb: kIsWeb ? ReCaptchaV3Provider(_webSiteKey) : null,
      providerAndroid: debug
          ? const AndroidDebugProvider()
          : const AndroidPlayIntegrityProvider(),
      providerApple: debug
          ? const AppleDebugProvider()
          : const AppleAppAttestWithDeviceCheckFallbackProvider(),
    );
  } catch (e) {
    debugPrint('App Check を有効にできませんでした（起動は続けます）: $e');
  }
}
