import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/error/app_error.dart';
import '../core/result/result.dart';

/// この端末のプッシュ通知の宛先（FCM トークン）を、ログイン中の利用者の
/// `users/{uid}.fcmTokens` に登録する。
///
/// 店からの車検案内（functions の onInspectionNoticeCreated）は、ここに
/// 登録された端末に送る。2026-10-01 まではトークンをどこにも保存して
/// いなかったので、サーバーから送る先が無かった。
///
/// - 1人で複数の端末を使えるよう配列で持つ。新しいものを末尾に足し、
///   [maxTokens] を超えたら古いものから落とす（ルールでも上限を見る）
/// - ログアウトのときは、この端末のトークンを外す。外さないと、同じ端末で
///   次にログインした別の人に、前の人宛ての案内が届く
/// - 届かなくなったトークン（アプリを消した等）は、送ったときにサーバーが外す
///
/// FirebaseMessaging には直接触らない（テストで差し替えるため、取得と
/// 更新の通知を関数で受け取る）。
class FcmTokenService {
  final FirebaseFirestore _firestore;
  final Future<String?> Function() _getToken;
  final Stream<String> Function() _onTokenRefresh;
  final DateTime Function() _now;

  StreamSubscription<String>? _refreshSub;
  String? _registeredUid;
  String? _currentToken;

  FcmTokenService({
    required FirebaseFirestore firestore,
    required Future<String?> Function() getToken,
    required Stream<String> Function() onTokenRefresh,
    DateTime Function()? now,
  })  : _firestore = firestore,
        _getToken = getToken,
        _onTokenRefresh = onTokenRefresh,
        _now = now ?? DateTime.now;

  /// 1人が持てる端末の数（firestore.rules の users の上限より小さくしておく）。
  static const int maxTokens = 10;

  /// ログインした利用者に、この端末を登録する。トークンが変わったら
  /// 付け替える（ログアウトまで）。トークンが取れない（通知を許可して
  /// いない・iOS で APNs が未設定など）ときは何もしない。
  Future<Result<void, AppError>> register(String uid) async {
    if (uid.isEmpty) {
      return const Result.failure(
          AppError.validation('ログインしてください', field: 'uid'));
    }
    try {
      final token = await _getToken();
      if (token != null && token.isNotEmpty) {
        await _save(uid, token);
      }
      if (_registeredUid != uid) {
        await _refreshSub?.cancel();
        _registeredUid = uid;
        _refreshSub = _onTokenRefresh().listen((t) async {
          final previous = _currentToken;
          // 失敗しても次の起動で登録し直すので、ここでは握りつぶす
          try {
            await _save(uid, t, replacing: previous);
          } catch (_) {}
        });
      }
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  /// ログアウトの前に呼ぶ。この端末のトークンを利用者から外す。
  /// （ログアウトしたあとはルール上もう書けない）
  Future<Result<void, AppError>> unregister(String uid) async {
    await _refreshSub?.cancel();
    _refreshSub = null;
    _registeredUid = null;
    if (uid.isEmpty) return const Result.success(null);
    try {
      final token = _currentToken ?? await _getToken();
      _currentToken = null;
      if (token == null || token.isEmpty) return const Result.success(null);
      final ref = _firestore.collection('users').doc(uid);
      final snap = await ref.get();
      if (!snap.exists) return const Result.success(null);
      await ref.update({
        'fcmTokens': FieldValue.arrayRemove([token]),
      });
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }

  Future<void> _save(String uid, String token, {String? replacing}) async {
    final ref = _firestore.collection('users').doc(uid);
    final snap = await ref.get();
    // プロフィールがまだ無い（作っている途中）なら書かない。ここで作ると、
    // 中身の無い users ができてしまう。次の起動で登録される
    if (!snap.exists) return;
    final current = [
      for (final t in (snap.data()?['fcmTokens'] as List?) ?? const [])
        if (t is String && t != token && t != replacing) t,
    ];
    final next = [...current, token];
    final kept =
        next.length > maxTokens ? next.sublist(next.length - maxTokens) : next;
    await ref.update({
      'fcmTokens': kept,
      'fcmTokenUpdatedAt': Timestamp.fromDate(_now()),
    });
    _currentToken = token;
  }

  void dispose() {
    _refreshSub?.cancel();
  }
}
