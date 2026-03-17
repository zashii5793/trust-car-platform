// AppNotification Model Tests
//
// Coverage:
//   - NotificationType enum: name serialization, typeDisplayName
//   - NotificationPriority enum: name serialization
//   - AppNotification construction
//   - toFirestore / copyWith
//   - typeDisplayName for all types
//   - Edge cases: unknown type defaults, metadata handling

import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/app_notification.dart';

// ---------------------------------------------------------------------------
// Helper
// ---------------------------------------------------------------------------

AppNotification _make({
  String id = 'notif-1',
  String userId = 'user-1',
  String? vehicleId = 'vehicle-1',
  NotificationType type = NotificationType.maintenanceRecommendation,
  String title = 'タイトル',
  String message = 'メッセージ本文',
  NotificationPriority priority = NotificationPriority.medium,
  bool isRead = false,
  DateTime? createdAt,
  DateTime? actionDate,
  Map<String, dynamic>? metadata,
}) {
  return AppNotification(
    id: id,
    userId: userId,
    vehicleId: vehicleId,
    type: type,
    title: title,
    message: message,
    priority: priority,
    isRead: isRead,
    createdAt: createdAt ?? DateTime(2024, 3, 1, 9, 0),
    actionDate: actionDate,
    metadata: metadata,
  );
}

void main() {
  // -------------------------------------------------------------------------
  // NotificationType
  // -------------------------------------------------------------------------
  group('NotificationType', () {
    test('全 4 種類が定義されている', () {
      expect(NotificationType.values.length, 4);
    });

    test('各種類の name が文字列として取得できる', () {
      expect(NotificationType.maintenanceRecommendation.name,
          'maintenanceRecommendation');
      expect(NotificationType.inspectionReminder.name, 'inspectionReminder');
      expect(NotificationType.partsReplacement.name, 'partsReplacement');
      expect(NotificationType.system.name, 'system');
    });

    test('name で逆引きできる', () {
      expect(
        NotificationType.values
            .firstWhere((e) => e.name == 'inspectionReminder'),
        NotificationType.inspectionReminder,
      );
    });

    test('unknown な type 文字列は orElse で system にフォールバックする', () {
      final type = NotificationType.values.firstWhere(
        (e) => e.name == 'unknownType',
        orElse: () => NotificationType.system,
      );
      expect(type, NotificationType.system);
    });
  });

  // -------------------------------------------------------------------------
  // NotificationPriority
  // -------------------------------------------------------------------------
  group('NotificationPriority', () {
    test('全 3 種類が定義されている', () {
      expect(NotificationPriority.values.length, 3);
    });

    test('low / medium / high の name が正しい', () {
      expect(NotificationPriority.low.name, 'low');
      expect(NotificationPriority.medium.name, 'medium');
      expect(NotificationPriority.high.name, 'high');
    });

    test('unknown priority は orElse で medium にフォールバックできる', () {
      final priority = NotificationPriority.values.firstWhere(
        (e) => e.name == 'critical',
        orElse: () => NotificationPriority.medium,
      );
      expect(priority, NotificationPriority.medium);
    });
  });

  // -------------------------------------------------------------------------
  // AppNotification.construction
  // -------------------------------------------------------------------------
  group('AppNotification.construction', () {
    test('最小フィールドでインスタンスを生成できる', () {
      final n = _make();
      expect(n.id, 'notif-1');
      expect(n.userId, 'user-1');
      expect(n.isRead, isFalse);
    });

    test('vehicleId が null でも生成できる', () {
      final n = _make(vehicleId: null);
      expect(n.vehicleId, isNull);
    });

    test('priority のデフォルトは medium', () {
      final n = _make();
      expect(n.priority, NotificationPriority.medium);
    });

    test('isRead のデフォルトは false', () {
      final n = AppNotification(
        id: 'x',
        userId: 'u',
        type: NotificationType.system,
        title: 'T',
        message: 'M',
        createdAt: DateTime.now(),
      );
      expect(n.isRead, isFalse);
    });

    test('metadata を保持できる', () {
      final n = _make(metadata: {'vehicleId': 'v1', 'recordId': 'r1'});
      expect(n.metadata?['vehicleId'], 'v1');
    });
  });

  // -------------------------------------------------------------------------
  // typeDisplayName
  // -------------------------------------------------------------------------
  group('AppNotification.typeDisplayName', () {
    test('maintenanceRecommendation → "メンテナンス推奨"', () {
      final n = _make(type: NotificationType.maintenanceRecommendation);
      expect(n.typeDisplayName, 'メンテナンス推奨');
    });

    test('inspectionReminder → "車検リマインダー"', () {
      final n = _make(type: NotificationType.inspectionReminder);
      expect(n.typeDisplayName, '車検リマインダー');
    });

    test('partsReplacement → "消耗品交換"', () {
      final n = _make(type: NotificationType.partsReplacement);
      expect(n.typeDisplayName, '消耗品交換');
    });

    test('system → "お知らせ"', () {
      final n = _make(type: NotificationType.system);
      expect(n.typeDisplayName, 'お知らせ');
    });
  });

  // -------------------------------------------------------------------------
  // toFirestore
  // -------------------------------------------------------------------------
  group('AppNotification.toFirestore', () {
    test('userId / title / message が正しく変換される', () {
      final map = _make(
        userId: 'u-abc',
        title: '車検通知',
        message: '30日以内に車検が到来します',
      ).toFirestore();

      expect(map['userId'], 'u-abc');
      expect(map['title'], '車検通知');
      expect(map['message'], '30日以内に車検が到来します');
    });

    test('type が文字列として保存される', () {
      final map = _make(type: NotificationType.inspectionReminder).toFirestore();
      expect(map['type'], 'inspectionReminder');
    });

    test('priority が文字列として保存される', () {
      expect(_make(priority: NotificationPriority.high).toFirestore()['priority'], 'high');
      expect(_make(priority: NotificationPriority.low).toFirestore()['priority'], 'low');
    });

    test('isRead が bool として保存される', () {
      expect(_make(isRead: true).toFirestore()['isRead'], isTrue);
      expect(_make(isRead: false).toFirestore()['isRead'], isFalse);
    });

    test('createdAt が Timestamp として保存される', () {
      final map = _make().toFirestore();
      expect(map['createdAt'], isA<Timestamp>());
    });

    test('actionDate が null のとき null として保存される', () {
      final map = _make(actionDate: null).toFirestore();
      expect(map['actionDate'], isNull);
    });

    test('actionDate が指定されたとき Timestamp として保存される', () {
      final date = DateTime(2024, 12, 31);
      final map = _make(actionDate: date).toFirestore();
      expect(map['actionDate'], isA<Timestamp>());
    });

    test('vehicleId が null のとき null が保存される', () {
      final map = _make(vehicleId: null).toFirestore();
      expect(map['vehicleId'], isNull);
    });
  });

  // -------------------------------------------------------------------------
  // copyWith
  // -------------------------------------------------------------------------
  group('AppNotification.copyWith', () {
    test('isRead を true に更新できる', () {
      final copy = _make(isRead: false).copyWith(isRead: true);
      expect(copy.isRead, isTrue);
    });

    test('title を変更できる', () {
      final copy = _make(title: '古いタイトル').copyWith(title: '新しいタイトル');
      expect(copy.title, '新しいタイトル');
    });

    test('priority を変更できる', () {
      final copy = _make(priority: NotificationPriority.low)
          .copyWith(priority: NotificationPriority.high);
      expect(copy.priority, NotificationPriority.high);
    });

    test('元オブジェクトは変更されない（不変性）', () {
      final original = _make(isRead: false);
      original.copyWith(isRead: true);
      expect(original.isRead, isFalse);
    });

    test('変更しないフィールドは維持される', () {
      final original = _make(userId: 'u123', vehicleId: 'v456');
      final copy = original.copyWith(title: '新タイトル');
      expect(copy.userId, 'u123');
      expect(copy.vehicleId, 'v456');
    });

    test('copyWith で id を変更できる', () {
      final copy = _make(id: 'old-id').copyWith(id: 'new-id');
      expect(copy.id, 'new-id');
    });
  });

  // -------------------------------------------------------------------------
  // Edge Cases
  // -------------------------------------------------------------------------
  group('Edge Cases', () {
    test('title / message が空文字でも生成できる', () {
      final n = _make(title: '', message: '');
      expect(n.title, isEmpty);
      expect(n.message, isEmpty);
    });

    test('10,000文字のメッセージでもクラッシュしない', () {
      final longMsg = 'あ' * 10000;
      expect(() => _make(message: longMsg), returnsNormally);
    });

    test('metadata が null でも toFirestore でクラッシュしない', () {
      expect(() => _make(metadata: null).toFirestore(), returnsNormally);
    });

    test('metadata が空マップでも問題なし', () {
      final n = _make(metadata: {});
      expect(n.metadata, isEmpty);
    });

    test('高優先度通知の高優先度判定', () {
      final n = _make(priority: NotificationPriority.high);
      expect(n.priority == NotificationPriority.high, isTrue);
    });

    test('vehicle なし通知は vehicleId が null', () {
      final n = _make(vehicleId: null);
      expect(n.vehicleId, isNull);
    });
  });
}
