import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/di/service_locator.dart';
import '../../../providers/auth_provider.dart';
import '../../../services/detail_delivery_service.dart';
import '../../../services/inspection_push_service.dart';
import '../../../services/ledger_link_service.dart';
import '../../../services/shop_audit_service.dart';
import '../../../services/shop_invite_service.dart';
import '../../../services/shop_ledger_service.dart';
import '../../../services/shop_staff_service.dart';
import '../../../services/vehicle_share_service.dart';
import 'customer_ledger_screen.dart';

/// The customer ledger for the signed-in person, wired from the service
/// locator. One place for the shop hub ("掲載管理") and the screen shown
/// right after sign-in, so both open the same ledger.
///
/// The owner also gets staff management and the audit log; staff do not
/// (2026-09-28: staff can link customers and send details, but managing
/// staff and reading the audit log is for the owner).
Widget buildCustomerLedgerScreen(
  BuildContext context, {
  required String shopId,
  required String shopName,
  required bool isOwner,
  String? ownerUid,
  VoidCallback? onOpenUserHome,
}) {
  final user = context.read<AuthProvider>().firebaseUser;
  return CustomerLedgerScreen(
    service: sl.get<ShopLedgerService>(),
    shareService: sl.get<VehicleShareService>(),
    staffService: isOwner ? sl.get<ShopStaffService>() : null,
    ownerUid: ownerUid,
    ownerName: isOwner ? (user?.displayName ?? '') : '',
    linkService: sl.get<LedgerLinkService>(),
    inviteService: sl.get<ShopInviteService>(),
    // Not registered in some test setups: just hide the entry.
    deliveryService: sl.isRegistered<DetailDeliveryService>()
        ? sl.get<DetailDeliveryService>()
        : null,
    currentUid: user?.uid,
    onAudit: ledgerAuditFor(context, shopId),
    auditService: isOwner ? sl.tryGet<ShopAuditService>() : null,
    pushService: sl.tryGet<InspectionPushService>(),
    onOpenUserHome: onOpenUserHome,
    shopId: shopId,
    shopName: shopName,
  );
}

/// Records shop operations as the signed-in person.
AuditRecorder? ledgerAuditFor(BuildContext context, String shopId) {
  if (!sl.isRegistered<ShopAuditService>()) return null;
  final user = context.read<AuthProvider>().firebaseUser;
  if (user == null) return null;
  return sl.get<ShopAuditService>().recorderFor(
        shopId: shopId,
        actorUid: user.uid,
        actorName: user.displayName ?? user.email ?? 'スタッフ',
      );
}
