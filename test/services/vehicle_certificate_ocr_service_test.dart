import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/services/vehicle_certificate_ocr_service.dart';
import 'package:trust_car_platform/models/vehicle.dart';

void main() {
  group('VehicleCertificateData', () {
    test('全フィールドがnullの場合、hasVehicleInfoはfalseを返す', () {
      final data = VehicleCertificateData();
      expect(data.hasVehicleInfo, false);
    });

    test('makerがある場合、hasVehicleInfoはtrueを返す', () {
      final data = VehicleCertificateData(maker: 'トヨタ');
      expect(data.hasVehicleInfo, true);
    });

    test('modelがある場合、hasVehicleInfoはtrueを返す', () {
      final data = VehicleCertificateData(model: 'プリウス');
      expect(data.hasVehicleInfo, true);
    });

    test('vinNumberがある場合、hasVehicleInfoはtrueを返す', () {
      final data = VehicleCertificateData(vinNumber: 'ZN6-012345');
      expect(data.hasVehicleInfo, true);
    });

    test('inspectionExpiryDateがある場合、hasVehicleInfoはtrueを返す', () {
      final data = VehicleCertificateData(
        inspectionExpiryDate: DateTime(2025, 5, 20),
      );
      expect(data.hasVehicleInfo, true);
    });

    test('confidenceScoreが正しく計算される（全項目null）', () {
      final data = VehicleCertificateData();
      expect(data.confidenceScore, 0.0);
    });

    test('confidenceScoreが正しく計算される（一部項目あり）', () {
      final data = VehicleCertificateData(
        maker: 'トヨタ',
        model: 'プリウス',
        year: 2020,
        inspectionExpiryDate: DateTime(2025, 5, 20),
        vinNumber: 'ZVW50-1234567',
      );
      // 5項目 / 15項目 = 0.333...
      expect(data.confidenceScore, closeTo(0.333, 0.01));
    });

    test('confidenceScoreが正しく計算される（全項目あり）', () {
      final data = VehicleCertificateData(
        registrationNumber: '品川 300 あ 12-34',
        vinNumber: 'ZVW50-1234567',
        modelCode: 'DBA-ZVW50',
        maker: 'トヨタ',
        model: 'プリウス',
        year: 2020,
        inspectionExpiryDate: DateTime(2025, 5, 20),
        ownerName: '山田太郎',
        ownerAddress: '東京都品川区',
        engineDisplacement: 1800,
        fuelType: 'ハイブリッド',
        color: '白',
        maxCapacity: 5,
        vehicleWeight: 1380,
        grossWeight: 1655,
      );
      expect(data.confidenceScore, 1.0);
    });
  });

  group('VehicleCertificateDataExtension', () {
    test('fuelTypeEnumがガソリンを正しく変換する', () {
      final data = VehicleCertificateData(fuelType: 'ガソリン');
      expect(data.fuelTypeEnum, FuelType.gasoline);
    });

    test('fuelTypeEnumが軽油をディーゼルに変換する', () {
      final data = VehicleCertificateData(fuelType: '軽油');
      expect(data.fuelTypeEnum, FuelType.diesel);
    });

    test('fuelTypeEnumがディーゼルを正しく変換する', () {
      final data = VehicleCertificateData(fuelType: 'ディーゼル');
      expect(data.fuelTypeEnum, FuelType.diesel);
    });

    test('fuelTypeEnumがハイブリッドを正しく変換する', () {
      final data = VehicleCertificateData(fuelType: 'ハイブリッド');
      expect(data.fuelTypeEnum, FuelType.hybrid);
    });

    test('fuelTypeEnumが電気を正しく変換する', () {
      final data = VehicleCertificateData(fuelType: '電気');
      expect(data.fuelTypeEnum, FuelType.electric);
    });

    test('fuelTypeEnumが水素を正しく変換する', () {
      final data = VehicleCertificateData(fuelType: '水素');
      expect(data.fuelTypeEnum, FuelType.hydrogen);
    });

    test('fuelTypeEnumが不明な燃料タイプの場合nullを返す', () {
      final data = VehicleCertificateData(fuelType: 'LPG');
      expect(data.fuelTypeEnum, null);
    });

    test('fuelTypeEnumがnullの場合nullを返す', () {
      final data = VehicleCertificateData();
      expect(data.fuelTypeEnum, null);
    });

    test('isReadyForRegistrationがメーカーと車検日がある場合trueを返す', () {
      final data = VehicleCertificateData(
        maker: 'トヨタ',
        inspectionExpiryDate: DateTime(2025, 5, 20),
      );
      expect(data.isReadyForRegistration, true);
    });

    test('isReadyForRegistrationがモデルと車検日がある場合trueを返す', () {
      final data = VehicleCertificateData(
        model: 'プリウス',
        inspectionExpiryDate: DateTime(2025, 5, 20),
      );
      expect(data.isReadyForRegistration, true);
    });

    test('isReadyForRegistrationが車検日がない場合falseを返す', () {
      final data = VehicleCertificateData(
        maker: 'トヨタ',
        model: 'プリウス',
      );
      expect(data.isReadyForRegistration, false);
    });

    test('isReadyForRegistrationがメーカーもモデルもない場合falseを返す', () {
      final data = VehicleCertificateData(
        inspectionExpiryDate: DateTime(2025, 5, 20),
      );
      expect(data.isReadyForRegistration, false);
    });
  });

  group('VehicleCertificateData toString', () {
    test('toStringが正しくフォーマットされる', () {
      final data = VehicleCertificateData(
        maker: 'トヨタ',
        model: 'プリウス',
        year: 2020,
      );
      final str = data.toString();
      expect(str.contains('maker: トヨタ'), true);
      expect(str.contains('model: プリウス'), true);
      expect(str.contains('year: 2020'), true);
      expect(str.contains('confidenceScore:'), true);
    });
  });
}
