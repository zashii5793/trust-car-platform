import 'package:flutter_test/flutter_test.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:trust_car_platform/models/user.dart';

void main() {
  group('AppUser', () {
    group('constructor', () {
      test('必須フィールドのみでAppUserを生成できる', () {
        final now = DateTime.now();
        final user = AppUser(
          id: 'user123',
          email: 'test@example.com',
          createdAt: now,
          updatedAt: now,
        );

        expect(user.id, 'user123');
        expect(user.email, 'test@example.com');
        expect(user.displayName, null);
        expect(user.photoUrl, null);
        expect(user.notificationSettings, isA<NotificationSettings>());
      });

      test('全フィールドを指定してAppUserを生成できる', () {
        final now = DateTime.now();
        final settings = NotificationSettings(pushEnabled: false);
        final user = AppUser(
          id: 'user123',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          notificationSettings: settings,
          createdAt: now,
          updatedAt: now,
        );

        expect(user.displayName, 'Test User');
        expect(user.photoUrl, 'https://example.com/photo.jpg');
        expect(user.notificationSettings.pushEnabled, false);
      });
    });

    group('toMap', () {
      test('AppUserをMapに変換できる', () {
        final now = DateTime.now();
        final user = AppUser(
          id: 'user123',
          email: 'test@example.com',
          displayName: 'Test User',
          photoUrl: 'https://example.com/photo.jpg',
          createdAt: now,
          updatedAt: now,
        );

        final map = user.toMap();

        expect(map['email'], 'test@example.com');
        expect(map['displayName'], 'Test User');
        expect(map['photoUrl'], 'https://example.com/photo.jpg');
        expect(map['notificationSettings'], isA<Map<String, dynamic>>());
        expect(map['createdAt'], isA<Timestamp>());
        expect(map['updatedAt'], isA<Timestamp>());
        // idはtoMapに含まれない（Firestoreのドキュメントキーとして使用）
        expect(map.containsKey('id'), false);
      });
    });

    group('copyWith', () {
      test('一部フィールドを変更したコピーを作成できる', () {
        final now = DateTime.now();
        final original = AppUser(
          id: 'user123',
          email: 'test@example.com',
          displayName: 'Original Name',
          createdAt: now,
          updatedAt: now,
        );

        final copied = original.copyWith(displayName: 'New Name');

        expect(copied.displayName, 'New Name');
        expect(copied.id, original.id);
        expect(copied.email, original.email);
      });
    });
  });

  group('NotificationSettings', () {
    group('constructor defaults', () {
      test('デフォルト値で全ての通知が有効', () {
        final settings = NotificationSettings();

        expect(settings.pushEnabled, true);
        expect(settings.inspectionReminder, true);
        expect(settings.maintenanceReminder, true);
        expect(settings.oilChangeReminder, true);
        expect(settings.tireChangeReminder, true);
        expect(settings.carInspectionReminder, true);
      });

      test('個別に無効化できる', () {
        final settings = NotificationSettings(
          pushEnabled: false,
          oilChangeReminder: false,
        );

        expect(settings.pushEnabled, false);
        expect(settings.oilChangeReminder, false);
        expect(settings.inspectionReminder, true);
      });
    });

    group('fromMap', () {
      test('Mapから NotificationSettingsを生成できる', () {
        final map = {
          'pushEnabled': false,
          'inspectionReminder': false,
          'maintenanceReminder': true,
          'oilChangeReminder': true,
          'tireChangeReminder': false,
          'carInspectionReminder': true,
        };

        final settings = NotificationSettings.fromMap(map);

        expect(settings.pushEnabled, false);
        expect(settings.inspectionReminder, false);
        expect(settings.maintenanceReminder, true);
        expect(settings.tireChangeReminder, false);
      });

      test('欠けているフィールドはデフォルト値を使用', () {
        final map = <String, dynamic>{};

        final settings = NotificationSettings.fromMap(map);

        expect(settings.pushEnabled, true);
        expect(settings.inspectionReminder, true);
      });
    });

    group('toMap', () {
      test('NotificationSettingsをMapに変換できる', () {
        final settings = NotificationSettings(
          pushEnabled: false,
          inspectionReminder: true,
        );

        final map = settings.toMap();

        expect(map['pushEnabled'], false);
        expect(map['inspectionReminder'], true);
        expect(map.length, 6);
      });
    });

    group('copyWith', () {
      test('一部フィールドを変更したコピーを作成できる', () {
        final original = NotificationSettings(pushEnabled: true);
        final copied = original.copyWith(pushEnabled: false);

        expect(copied.pushEnabled, false);
        expect(copied.inspectionReminder, original.inspectionReminder);
      });
    });
  });

  group('居住地（prefecture / city）', () {
    AppUser make({String? prefecture, String? city}) => AppUser(
          id: 'u1',
          email: 'a@example.com',
          prefecture: prefecture,
          city: city,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        );

    test('regionLabel joins prefecture and city', () {
      expect(make(prefecture: '東京都', city: '世田谷区').regionLabel, '東京都世田谷区');
    });

    test('is persisted in toMap', () {
      final map = make(prefecture: '大阪府', city: '吹田市').toMap();
      expect(map['prefecture'], '大阪府');
      expect(map['city'], '吹田市');
    });

    test('copyWith replaces the region', () {
      final updated = make(prefecture: '東京都').copyWith(prefecture: '北海道');
      expect(updated.prefecture, '北海道');
    });

    group('Edge Cases', () {
      test('regionLabel is null when nothing is set', () {
        expect(make().regionLabel, isNull);
      });

      test('regionLabel uses whichever half is set', () {
        expect(make(prefecture: '沖縄県').regionLabel, '沖縄県');
        expect(make(city: '那覇市').regionLabel, '那覇市');
      });

      test('blank values are treated as unset', () {
        expect(make(prefecture: '  ', city: '').regionLabel, isNull);
      });

      test('unset region keys are omitted from the map', () {
        // null を書き戻すと既存の値を消してしまう。
        expect(make().toMap().containsKey('prefecture'), isFalse);
        expect(make().toMap().containsKey('city'), isFalse);
      });
    });
  });
}
