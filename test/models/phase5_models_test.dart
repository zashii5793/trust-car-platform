import 'package:flutter_test/flutter_test.dart';
import 'package:trust_car_platform/models/vehicle.dart';
import 'package:trust_car_platform/models/maintenance_record.dart';
import 'package:trust_car_platform/models/invoice.dart';
import 'package:trust_car_platform/models/document.dart';
import 'package:trust_car_platform/models/service_menu.dart';

void main() {
  group('Phase 5 Vehicle Extensions', () {
    test('DriveType enum has correct values', () {
      expect(DriveType.ff.displayName, 'FF（前輪駆動）');
      expect(DriveType.fr.displayName, 'FR（後輪駆動）');
      expect(DriveType.fourWd.displayName, '4WD/AWD');
      expect(DriveType.fromString('ff'), DriveType.ff);
      expect(DriveType.fromString('invalid'), null);
    });

    test('TransmissionType enum has correct values', () {
      expect(TransmissionType.at.displayName, 'AT（オートマチック）');
      expect(TransmissionType.mt.displayName, 'MT（マニュアル）');
      expect(TransmissionType.cvt.displayName, 'CVT（無段変速）');
      expect(TransmissionType.fromString('cvt'), TransmissionType.cvt);
      expect(TransmissionType.fromString(null), null);
    });

    test('VoluntaryInsurance can be created and serialized', () {
      final insurance = VoluntaryInsurance(
        companyName: '東京海上日動',
        policyNumber: 'ABC-123456',
        expiryDate: DateTime.now().add(const Duration(days: 365)), // 1年後
        coverageType: '対人対物無制限',
        agentName: 'サンプル代理店',
        agentPhone: '03-1234-5678',
      );

      expect(insurance.companyName, '東京海上日動');
      expect(insurance.isExpiringSoon, false); // 1年後なので近くない
      expect(insurance.isExpired, false);

      final map = insurance.toMap();
      expect(map['companyName'], '東京海上日動');
      expect(map['policyNumber'], 'ABC-123456');
    });

    test('VoluntaryInsurance expiry detection works', () {
      final expiredInsurance = VoluntaryInsurance(
        expiryDate: DateTime.now().subtract(const Duration(days: 10)),
      );
      expect(expiredInsurance.isExpired, true);

      final soonExpiringInsurance = VoluntaryInsurance(
        expiryDate: DateTime.now().add(const Duration(days: 15)),
      );
      expect(soonExpiringInsurance.isExpiringSoon, true);
      expect(soonExpiringInsurance.isExpired, false);
    });

    test('Vehicle with new Phase 5 fields', () {
      final vehicle = Vehicle(
        id: 'test-id',
        userId: 'user-1',
        maker: 'Toyota',
        model: 'Crown',
        year: 2023,
        grade: 'RS',
        mileage: 15000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        driveType: DriveType.fr,
        transmissionType: TransmissionType.at,
        vehicleWeight: 1800,
        seatingCapacity: 5,
        firstRegistrationDate: DateTime(2023, 4, 1),
        voluntaryInsurance: const VoluntaryInsurance(
          companyName: 'あいおいニッセイ',
        ),
      );

      expect(vehicle.driveType, DriveType.fr);
      expect(vehicle.transmissionType, TransmissionType.at);
      expect(vehicle.vehicleWeight, 1800);
      expect(vehicle.seatingCapacity, 5);
      expect(vehicle.voluntaryInsurance?.companyName, 'あいおいニッセイ');
    });
  });

  group('Phase 5 MaintenanceType Extensions', () {
    test('New maintenance types exist', () {
      expect(MaintenanceType.bodyRepair.displayName, '板金・塗装');
      expect(MaintenanceType.glassCoating.displayName, 'ガラスコーティング');
      expect(MaintenanceType.carFilm.displayName, 'カーフィルム');
      expect(MaintenanceType.customization.displayName, 'カスタム・ドレスアップ');
      expect(MaintenanceType.audioInstall.displayName, 'オーディオ取付');
    });

    test('isBodyWork property works correctly', () {
      expect(MaintenanceType.bodyRepair.isBodyWork, true);
      expect(MaintenanceType.glassCoating.isBodyWork, true);
      expect(MaintenanceType.carFilm.isBodyWork, true);
      expect(MaintenanceType.oilChange.isBodyWork, false);
    });

    test('isCustomization property works correctly', () {
      expect(MaintenanceType.customization.isCustomization, true);
      expect(MaintenanceType.audioInstall.isCustomization, true);
      expect(MaintenanceType.accessoryInstall.isCustomization, true);
      expect(MaintenanceType.repair.isCustomization, false);
    });

    test('groupedTypes includes new categories', () {
      final groups = MaintenanceType.groupedTypes;
      expect(groups.containsKey('板金・塗装'), true);
      expect(groups.containsKey('コーティング'), true);
      expect(groups.containsKey('フィルム施工'), true);
      expect(groups.containsKey('カスタム'), true);
    });
  });

  group('Phase 5 MaintenanceRecord Extensions', () {
    test('InspectionResult enum works correctly', () {
      expect(InspectionResult.passed.displayName, '合格');
      expect(InspectionResult.failed.displayName, '不合格');
      expect(InspectionResult.conditionalPass.displayName, '条件付合格');
      expect(InspectionResult.fromString('passed'), InspectionResult.passed);
      expect(InspectionResult.fromString('invalid'), null);
    });

    test('WorkItem can be created and serialized', () {
      final workItem = WorkItem(
        name: 'オイル交換',
        description: 'エンジンオイル交換作業',
        laborCost: 3000,
        laborHours: 0.5,
        workerName: '田中',
      );

      expect(workItem.name, 'オイル交換');
      expect(workItem.laborCost, 3000);

      final map = workItem.toMap();
      expect(map['name'], 'オイル交換');
      expect(map['laborHours'], 0.5);

      final restored = WorkItem.fromMap(map);
      expect(restored.name, 'オイル交換');
      expect(restored.laborHours, 0.5);
    });

    test('Part can be created and calculates subtotal', () {
      final part = Part(
        partNumber: 'OIL-001',
        name: 'エンジンオイル 5W-30',
        manufacturer: 'Mobil',
        unitPrice: 2500,
        quantity: 4,
      );

      expect(part.subtotal, 10000); // 2500 * 4

      final map = part.toMap();
      expect(map['partNumber'], 'OIL-001');

      final restored = Part.fromMap(map);
      expect(restored.subtotal, 10000);
    });

    test('MaintenanceRecord with Phase 5 fields', () {
      final record = MaintenanceRecord(
        id: 'record-1',
        vehicleId: 'vehicle-1',
        userId: 'user-1',
        type: MaintenanceType.carInspection,
        title: '車検',
        cost: 80000,
        date: DateTime.now(),
        createdAt: DateTime.now(),
        staffName: '山田太郎',
        inspectionResult: InspectionResult.passed,
        certificateUpdated: true,
        workItems: const [
          WorkItem(name: '24ヶ月点検', laborCost: 15000),
          WorkItem(name: '下回り洗浄', laborCost: 3000),
        ],
        parts: const [
          Part(partNumber: 'FILTER-001', name: 'オイルフィルター', unitPrice: 1500, quantity: 1),
          Part(partNumber: 'OIL-001', name: 'エンジンオイル', unitPrice: 2500, quantity: 4),
        ],
      );

      expect(record.staffName, '山田太郎');
      expect(record.inspectionResult, InspectionResult.passed);
      expect(record.certificateUpdated, true);
      expect(record.calculatedLaborCost, 18000); // 15000 + 3000
      expect(record.calculatedPartsCost, 11500); // 1500 + 10000
    });
  });

  group('Invoice Model', () {
    test('PaymentMethod enum has correct values', () {
      expect(PaymentMethod.cash.displayName, '現金');
      expect(PaymentMethod.creditCard.displayName, 'クレジットカード');
      expect(PaymentMethod.fromString('cash'), PaymentMethod.cash);
    });

    test('PaymentStatus enum has correct values', () {
      expect(PaymentStatus.unpaid.displayName, '未払い');
      expect(PaymentStatus.paid.displayName, '入金済');
      expect(PaymentStatus.fromString('paid'), PaymentStatus.paid);
    });

    test('Invoice can be created with all fields', () {
      final invoice = Invoice(
        id: 'inv-001',
        maintenanceRecordId: 'record-1',
        vehicleId: 'vehicle-1',
        userId: 'user-1',
        invoiceNumber: 'INV-2024-0001',
        issueDate: DateTime.now(),
        dueDate: DateTime.now().add(const Duration(days: 30)),
        partsCost: 15000,
        laborCost: 20000,
        miscCost: 5000,
        subtotal: 40000,
        taxAmount: 4000,
        discountAmount: 0,
        totalAmount: 44000,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(invoice.invoiceNumber, 'INV-2024-0001');
      expect(invoice.totalAmount, 44000);
      expect(invoice.remainingAmount, 44000);
      expect(invoice.isOverdue, false);
    });

    test('Invoice remaining amount calculation', () {
      final partiallyPaidInvoice = Invoice(
        id: 'inv-002',
        maintenanceRecordId: 'record-1',
        vehicleId: 'vehicle-1',
        userId: 'user-1',
        invoiceNumber: 'INV-2024-0002',
        issueDate: DateTime.now(),
        partsCost: 0,
        laborCost: 0,
        miscCost: 0,
        subtotal: 0,
        taxAmount: 0,
        discountAmount: 0,
        totalAmount: 50000,
        paymentStatus: PaymentStatus.partiallyPaid,
        paidAmount: 20000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(partiallyPaidInvoice.remainingAmount, 30000);
    });

    test('Invoice overdue detection', () {
      final overdueInvoice = Invoice(
        id: 'inv-003',
        maintenanceRecordId: 'record-1',
        vehicleId: 'vehicle-1',
        userId: 'user-1',
        invoiceNumber: 'INV-2024-0003',
        issueDate: DateTime.now().subtract(const Duration(days: 60)),
        dueDate: DateTime.now().subtract(const Duration(days: 30)),
        partsCost: 0,
        laborCost: 0,
        miscCost: 0,
        subtotal: 0,
        taxAmount: 0,
        discountAmount: 0,
        totalAmount: 10000,
        paymentStatus: PaymentStatus.unpaid,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(overdueInvoice.isOverdue, true);
    });
  });

  group('Document Model', () {
    test('DocumentType enum has correct values', () {
      expect(DocumentType.vehicleRegistration.displayName, '車検証');
      expect(DocumentType.invoice.displayName, '請求書');
      expect(DocumentType.fromString('invoice'), DocumentType.invoice);
    });

    test('FileMimeType enum works correctly', () {
      expect(FileMimeType.pdf.mimeType, 'application/pdf');
      expect(FileMimeType.jpeg.displayName, 'JPEG画像');
      expect(FileMimeType.fromMimeType('image/png'), FileMimeType.png);
    });

    test('Document can be created and serialized', () {
      final doc = Document(
        id: 'doc-001',
        userId: 'user-1',
        vehicleId: 'vehicle-1',
        type: DocumentType.vehicleRegistration,
        title: '車検証コピー',
        fileUrl: 'https://storage.example.com/docs/shaken.pdf',
        mimeType: FileMimeType.pdf,
        fileSize: 1024 * 500, // 500KB
        uploadedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(doc.title, '車検証コピー');
      expect(doc.isPdf, true);
      expect(doc.isImage, false);
      expect(doc.fileSizeDisplay, '500.0 KB');
    });

    test('Document expiry detection', () {
      final expiredDoc = Document(
        id: 'doc-002',
        userId: 'user-1',
        type: DocumentType.liabilityInsuranceCert,
        title: '自賠責保険証',
        fileUrl: 'https://example.com/cert.pdf',
        mimeType: FileMimeType.pdf,
        expiryDate: DateTime.now().subtract(const Duration(days: 10)),
        uploadedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(expiredDoc.isExpired, true);

      final soonExpiringDoc = Document(
        id: 'doc-003',
        userId: 'user-1',
        type: DocumentType.voluntaryInsuranceCert,
        title: '任意保険証券',
        fileUrl: 'https://example.com/cert.pdf',
        mimeType: FileMimeType.pdf,
        expiryDate: DateTime.now().add(const Duration(days: 20)),
        uploadedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      expect(soonExpiringDoc.isExpiringSoon, true);
      expect(soonExpiringDoc.isExpired, false);
    });
  });

  group('ServiceMenu Model', () {
    test('ServiceCategory enum has correct values', () {
      expect(ServiceCategory.inspection.displayName, '車検・点検');
      expect(ServiceCategory.bodyRepair.displayName, '板金・塗装');
      expect(ServiceCategory.coating.displayName, 'コーティング');
      expect(ServiceCategory.fromString('coating'), ServiceCategory.coating);
    });

    test('PricingType enum works correctly', () {
      expect(PricingType.fixed.displayName, '固定料金');
      expect(PricingType.estimate.displayName, '要見積');
      expect(PricingType.fromString('perHour'), PricingType.perHour);
    });

    test('ServiceMenu price display formatting', () {
      final fixedPriceMenu = ServiceMenu(
        id: 'menu-001',
        category: ServiceCategory.oilChange,
        name: 'オイル交換',
        pricingType: PricingType.fixed,
        basePrice: 5000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(fixedPriceMenu.priceDisplay, '¥5,000');

      final fromPriceMenu = ServiceMenu(
        id: 'menu-002',
        category: ServiceCategory.coating,
        name: 'ガラスコーティング',
        pricingType: PricingType.fromPrice,
        basePrice: 30000,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(fromPriceMenu.priceDisplay, '¥30,000〜');

      final estimateMenu = ServiceMenu(
        id: 'menu-003',
        category: ServiceCategory.bodyRepair,
        name: '板金修理',
        pricingType: PricingType.estimate,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(estimateMenu.priceDisplay, '要見積');
    });

    test('ServiceMenu time display formatting', () {
      final quickService = ServiceMenu(
        id: 'menu-004',
        category: ServiceCategory.oilChange,
        name: 'オイル交換',
        estimatedHours: 0.5,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(quickService.estimatedTimeDisplay, '約30分');

      final longerService = ServiceMenu(
        id: 'menu-005',
        category: ServiceCategory.inspection,
        name: '車検',
        estimatedHours: 3.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(longerService.estimatedTimeDisplay, '約3.0時間');

      final rangeService = ServiceMenu(
        id: 'menu-006',
        category: ServiceCategory.bodyRepair,
        name: '板金',
        minHours: 2.0,
        maxHours: 5.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      expect(rangeService.estimatedTimeDisplay, '2.0〜5.0時間');
    });

    test('ServiceMenu serialization', () {
      final menu = ServiceMenu(
        id: 'menu-007',
        shopId: 'shop-001',
        category: ServiceCategory.coating,
        name: 'プレミアムコーティング',
        description: '最高級ガラスコーティング',
        pricingType: PricingType.fixed,
        basePrice: 80000,
        estimatedHours: 4.0,
        isPopular: true,
        isRecommended: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final map = menu.toMap();
      expect(map['name'], 'プレミアムコーティング');
      expect(map['category'], 'coating');
      expect(map['isPopular'], true);
      expect(map['basePrice'], 80000);
    });
  });
}
