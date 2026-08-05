import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';

void main() {
  group('MaintenanceRecord 検証フィールド (C1)', () {
    MaintenanceRecord base() => MaintenanceRecord(
          id: 'r1',
          vehicleId: 'v1',
          userId: 'u1',
          type: MaintenanceType.oilChange,
          title: 'オイル交換',
          cost: 3000,
          date: DateTime(2024, 6, 1),
          createdAt: DateTime(2024, 6, 1),
        );

    group('verificationSource', () {
      test('デフォルトは selfReported', () {
        final record = base();
        expect(record.verificationSource, VerificationSource.selfReported);
      });

      test('inquiryId が設定されている場合は shopImported', () {
        final record = base().copyWith(inquiryId: 'inq_123');
        expect(record.verificationSource, VerificationSource.shopImported);
      });

      test('明示的に shopVerified を設定できる', () {
        final record = base().copyWith(
          verificationSourceOverride: VerificationSource.shopVerified,
          verifiedByShopId: 'shop_1',
          verifiedAt: DateTime(2024, 6, 2),
        );
        expect(record.verificationSource, VerificationSource.shopVerified);
      });

      test('shopImported は shopVerified より優先度が低い（明示 shopVerified が勝つ）', () {
        final record = base().copyWith(
          inquiryId: 'inq_456',
          verificationSourceOverride: VerificationSource.shopVerified,
          verifiedByShopId: 'shop_1',
          verifiedAt: DateTime(2024, 6, 2),
        );
        expect(record.verificationSource, VerificationSource.shopVerified);
      });
    });

    group('isVerified', () {
      test('selfReported は false', () {
        expect(base().isVerified, isFalse);
      });

      test('shopImported は true', () {
        final record = base().copyWith(inquiryId: 'inq_001');
        expect(record.isVerified, isTrue);
      });

      test('shopVerified は true', () {
        final record = base().copyWith(
          verificationSourceOverride: VerificationSource.shopVerified,
          verifiedByShopId: 'shop_x',
          verifiedAt: DateTime(2024, 6, 2),
        );
        expect(record.isVerified, isTrue);
      });
    });

    group('verifiedByShopId / verifiedAt', () {
      test('未設定の場合は null', () {
        expect(base().verifiedByShopId, isNull);
        expect(base().verifiedAt, isNull);
      });

      test('shopId を設定できる', () {
        final record = base().copyWith(verifiedByShopId: 'shop_abc');
        expect(record.verifiedByShopId, 'shop_abc');
      });

      test('verifiedAt を設定できる', () {
        final dt = DateTime(2025, 1, 15);
        final record = base().copyWith(verifiedAt: dt);
        expect(record.verifiedAt, dt);
      });
    });

    group('fromFirestore / toMap 後方互換', () {
      test('verificationSource フィールドが無い旧データは selfReported になる', () {
        // No verificationSource key in old data → defaults to selfReported
        final record = base();
        final map = record.toMap();
        expect(map.containsKey('verificationSource'), isTrue);
        expect(map['verificationSource'], 'selfReported');
      });

      test('toMap に shopImported が反映される', () {
        final record = base().copyWith(inquiryId: 'inq_789');
        final map = record.toMap();
        expect(map['verificationSource'], 'shopImported');
      });

      test('toMap に shopVerified が反映される', () {
        final record = base().copyWith(
          verificationSourceOverride: VerificationSource.shopVerified,
          verifiedByShopId: 'shop_1',
          verifiedAt: DateTime(2024, 6, 2),
        );
        final map = record.toMap();
        expect(map['verificationSource'], 'shopVerified');
        expect(map['verifiedByShopId'], 'shop_1');
        expect(map['verifiedAt'], isNotNull);
      });
    });

    group('Edge Cases', () {
      test('verifiedByShopId が空文字の場合は null 扱い', () {
        final record = base().copyWith(verifiedByShopId: '');
        expect(record.verifiedByShopId, isEmpty);
      });

      test('copyWith で verificationSourceOverride を上書きできる', () {
        final r1 = base().copyWith(
          verificationSourceOverride: VerificationSource.shopVerified,
        );
        final r2 = r1.copyWith(
          verificationSourceOverride: VerificationSource.selfReported,
        );
        // inquiryId is null, override is selfReported → selfReported
        expect(r2.verificationSource, VerificationSource.selfReported);
      });
    });
  });
}
