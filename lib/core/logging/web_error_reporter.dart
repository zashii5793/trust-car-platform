import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../constants/firestore_collections.dart';
import '../error/app_error.dart';
import '../result/result.dart';
import 'client_error_report.dart';

/// ウェブ版の不具合を Firestore の `client_errors` に送る。
///
/// モバイルは Crashlytics（`CrashlyticsWrapper`）で集めているが、Crashlytics は
/// Web 非対応。店主が使っているウェブ版だけ、落ちても誰にも分からなかった。
///
/// **暴れないことを最優先にする：**
/// - 1回の起動で送るのは [maxReportsPerSession] 件まで（失敗した分も数える）
/// - 同じメッセージは1回だけ
/// - どこで失敗しても例外を投げない。投げると onError に戻って回り続ける
///
/// 読むのは運営者だけ（Firebase Console / Admin SDK）。クライアントからは
/// 読めない（ルールで禁止）。
class WebErrorReporter {
  WebErrorReporter({
    required FirebaseFirestore firestore,
    required String buildId,
    required Uri Function() currentUrl,
    required String? Function() userAgent,
    required String? Function() currentUid,
    DateTime Function()? clock,
    int maxReportsPerSession = defaultMaxReportsPerSession,
  })  : _firestore = firestore,
        _buildId = buildId,
        _currentUrl = currentUrl,
        _userAgent = userAgent,
        _currentUid = currentUid,
        _clock = clock ?? DateTime.now,
        _maxReports = maxReportsPerSession < 0 ? 0 : maxReportsPerSession;

  static const int defaultMaxReportsPerSession = 10;

  final FirebaseFirestore _firestore;
  final String _buildId;
  final Uri Function() _currentUrl;
  final String? Function() _userAgent;
  final String? Function() _currentUid;
  final DateTime Function() _clock;
  final int _maxReports;

  final Set<String> _seenMessages = {};
  int _attempts = 0;
  int _sent = 0;

  /// 送ろうとした数（失敗を含む）。上限の判定はこちらで行う。
  int get attemptCount => _attempts;

  /// 実際に書けた数。
  int get sentCount => _sent;

  /// ウェブのリリース版だけで使う。デバッグ中はコンソールで見えるので送らない。
  static bool isEnabledFor({required bool isWeb, required bool isRelease}) =>
      isWeb && isRelease;

  /// 1件送る。
  ///
  /// 送れたら `true`、重複や上限で送らなかったら `false`。
  /// 書き込みに失敗したら failure を返す（例外は投げない）。
  Future<Result<bool, AppError>> report(
    Object error,
    StackTrace? stackTrace, {
    String source = ClientErrorReport.sourceFlutter,
  }) async {
    try {
      if (_attempts >= _maxReports) return const Result.success(false);

      final entry = ClientErrorReport.from(
        error: error,
        stackTrace: stackTrace,
        source: source,
        buildId: _buildId,
        url: _safe(_currentUrl) ?? Uri(path: '/'),
        userAgent: _safe(_userAgent),
        uid: _safe(_currentUid),
      );

      if (!_seenMessages.add(entry.message)) {
        return const Result.success(false);
      }

      // 書く前に数える。書き込みが失敗し続けても上限で止まる。
      _attempts++;
      await _firestore
          .collection(FirestoreCollections.clientErrors)
          .add(entry.toMap(now: _clock()));
      _sent++;
      return const Result.success(true);
    } catch (e) {
      // mapFirebaseError は使わない（ログ経由で自分に戻ってくる経路を作らない）。
      return Result.failure(
        AppError.unknown('client_errors write failed', originalError: e),
      );
    }
  }

  /// `FlutterError.onError` から呼ぶ。
  void handleFlutterError(FlutterErrorDetails details) {
    _fireAndForget(
      details.exception,
      details.stack,
      ClientErrorReport.sourceFlutter,
    );
  }

  /// `PlatformDispatcher.instance.onError` から呼ぶ。処理済みとして true を返す。
  bool handlePlatformError(Object error, StackTrace stackTrace) {
    _fireAndForget(error, stackTrace, ClientErrorReport.sourcePlatform);
    return true;
  }

  /// `runZonedGuarded` の onError から呼ぶ。
  ///
  /// Web では PlatformDispatcher.onError が呼ばれない
  /// （flutter/flutter#100277）ので、非同期の例外はこちらで拾う。
  void handleZoneError(Object error, StackTrace stackTrace) {
    _fireAndForget(error, stackTrace, ClientErrorReport.sourceZone);
  }

  void _fireAndForget(Object error, StackTrace? stack, String source) {
    try {
      unawaited(report(error, stack, source: source));
    } catch (_) {
      // 送信の中の失敗は握りつぶす（再帰させない）。
    }
  }

  static T? _safe<T>(T? Function() read) {
    try {
      return read();
    } catch (_) {
      return null;
    }
  }
}
