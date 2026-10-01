import 'package:flutter/foundation.dart';

import '../core/error/app_error.dart';
import '../models/shop.dart';
import '../models/shop_plan_request.dart';
import '../services/shop_plan_request_service.dart';

/// 店舗プランの申し込み（請求書払い）の状態。
///
/// プラン画面が使う。受付中の申し込みがあれば、画面に「受付中」を出す。
class ShopPlanRequestProvider with ChangeNotifier {
  final ShopPlanRequestService _service;

  ShopPlanRequestProvider({required ShopPlanRequestService service})
      : _service = service;

  ShopPlanRequest? _pending;
  bool _isSubmitting = false;
  AppError? _error;

  /// 受付中の申し込み（いちばん新しいもの）。
  ShopPlanRequest? get pending => _pending;
  bool get isSubmitting => _isSubmitting;
  AppError? get error => _error;

  /// 店の受付中の申し込みを読む。
  Future<void> loadPending(String shopId) async {
    if (_pending?.shopId != shopId) {
      _pending = null;
    }
    if (shopId.isEmpty) return;
    final result = await _service.latestPending(shopId);
    result.when(
      success: (req) {
        _pending = req;
        _error = null;
      },
      // 読めなくても申し込みはできる。表示が出ないだけにする
      failure: (err) => _error = err,
    );
    notifyListeners();
  }

  /// 申し込む。受け付けたら true。
  Future<bool> submit({
    required String shopId,
    required String requesterUid,
    required ShopPlanType plan,
    required ShopPlanType currentPlan,
    required String contactEmail,
    required String billingName,
    String? note,
  }) async {
    _isSubmitting = true;
    _error = null;
    notifyListeners();

    final result = await _service.submit(
      shopId: shopId,
      requesterUid: requesterUid,
      plan: plan,
      currentPlan: currentPlan,
      contactEmail: contactEmail,
      billingName: billingName,
      note: note,
    );

    _isSubmitting = false;
    final ok = result.when(
      success: (req) {
        _pending = req;
        return true;
      },
      failure: (err) {
        _error = err;
        return false;
      },
    );
    notifyListeners();
    return ok;
  }
}
