import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/migration/document_migrator.dart';

/// 車両の現在のステータス
///
/// 売却・廃車後もデータを保持したい場合は isDataRetained=true で
/// アーカイブ状態に移行する。
enum VehicleStatus {
  active('使用中'),
  sold('売却済み'),
  scrapped('廃車済み'),
  leaseReturned('リース返却済み'),
  transferred('譲渡済み');

  final String displayName;
  const VehicleStatus(this.displayName);

  static VehicleStatus fromString(String? value) {
    if (value == null) return VehicleStatus.active;
    try {
      return VehicleStatus.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return VehicleStatus.active;
    }
  }

  bool get isRetired => this != VehicleStatus.active;
}

/// 燃料タイプ
enum FuelType {
  gasoline('ガソリン'),
  diesel('ディーゼル'),
  hybrid('ハイブリッド'),
  electric('電気'),
  phev('プラグインハイブリッド'),
  hydrogen('水素');

  final String displayName;
  const FuelType(this.displayName);

  /// 文字列からFuelTypeを取得
  static FuelType? fromString(String? value) {
    if (value == null) return null;
    try {
      return FuelType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// 用途区分（ナンバー区分による車検サイクルの違い）
///
/// 車検の有効期間は道路運送車両法で用途ごとに定められている:
/// - 自家用乗用車・軽乗用車（3・5・7ナンバー）: 初回3年、以降2年
/// - 貨物車（1・4ナンバー、8t未満）: 初回2年、以降1年（毎年車検）
/// - 軽貨物（4ナンバー軽）: 初回2年、以降2年
/// - 事業用・大型貨物（緑ナンバー、8t以上）: 初回1年、以降1年
enum VehicleUseCategory {
  privatePassenger('自家用乗用車（3・5・7ナンバー）', 3, 2),
  cargo('貨物車（1・4ナンバー）', 2, 1),
  keiCargo('軽貨物（4ナンバー軽）', 2, 2),
  commercial('事業用・大型貨物（緑ナンバー等）', 1, 1);

  final String displayName;

  /// 新車登録から初回車検までの年数
  final int firstInspectionYears;

  /// 2回目以降の車検サイクル（年）
  final int inspectionCycleYears;

  const VehicleUseCategory(
    this.displayName,
    this.firstInspectionYears,
    this.inspectionCycleYears,
  );

  static VehicleUseCategory? fromString(String? value) {
    if (value == null) return null;
    try {
      return VehicleUseCategory.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// 駆動方式
enum DriveType {
  ff('FF（前輪駆動）'),
  fr('FR（後輪駆動）'),
  fourWd('4WD/AWD'),
  mr('MR（ミッドシップ）'),
  rr('RR（リアエンジン）');

  final String displayName;
  const DriveType(this.displayName);

  static DriveType? fromString(String? value) {
    if (value == null) return null;
    try {
      return DriveType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// ミッション種別
enum TransmissionType {
  at('AT（オートマチック）'),
  mt('MT（マニュアル）'),
  cvt('CVT（無段変速）'),
  dct('DCT（デュアルクラッチ）'),
  amt('AMT（自動MT）');

  final String displayName;
  const TransmissionType(this.displayName);

  static TransmissionType? fromString(String? value) {
    if (value == null) return null;
    try {
      return TransmissionType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return null;
    }
  }
}

/// 任意保険の契約形態。
/// - [nonFleet]: ノンフリート契約（所有・使用台数9台以下、車両ごとに等級管理）
/// - [fleet]: フリート契約（10台以上、契約全体の割増引率を適用＝法人で多い）
enum InsuranceContractType {
  nonFleet('ノンフリート'),
  fleet('フリート');

  final String displayName;
  const InsuranceContractType(this.displayName);

  static InsuranceContractType? fromString(String? value) {
    if (value == null) return null;
    for (final t in InsuranceContractType.values) {
      if (t.name == value) return t;
    }
    return null;
  }
}

/// 任意保険情報。
///
/// 個人・法人の双方に対応する。法人はフリート契約（[contractType] = fleet、
/// 等級ではなく [fleetDiscountRate] 割増引率を使用、[namedInsured] が法人名、
/// [usagePurpose] が業務使用）になることが多い。全フィールド任意で後方互換。
class VoluntaryInsurance {
  // --- 基本 ---
  final String? companyName; // 保険会社名
  final String? policyNumber; // 証券番号
  final DateTime? expiryDate; // 満了日
  final String? coverageType; // 補償内容（自由記述・後方互換）
  final String? agentName; // 代理店名
  final String? agentPhone; // 代理店電話番号

  // --- 契約 ---
  final DateTime? contractStartDate; // 契約開始日
  final int? annualPremium; // 年間保険料（円）
  final String? paymentMethod; // 支払方法（月払・年払）
  final InsuranceContractType? contractType; // ノンフリート / フリート
  final String? usagePurpose; // 使用目的（業務用・通勤通学・日常レジャー）
  final String? namedInsured; // 記名被保険者（個人名 or 法人名）

  // --- 等級 / 料率 ---
  final int? nonFleetGrade; // ノンフリート等級（6〜20）
  final int? accidentCoefficientPeriod; // 事故有係数適用期間（年）
  final double? fleetDiscountRate; // フリート割増引率（%）法人フリート契約用

  // --- 補償額 ---
  final String? bodilyInjuryLimit; // 対人賠償（無制限/金額）
  final String? propertyDamageLimit; // 対物賠償（無制限/金額）
  final String? personalInjuryAmount; // 人身傷害（例:3000万/5000万/無制限）
  final String? passengerInjuryAmount; // 搭乗者傷害

  // --- 車両保険 ---
  final bool? hasVehicleInsurance; // 車両保険の有無
  final String? vehicleInsuranceType; // 型（一般・車対車+A）
  final int? vehicleInsuranceAmount; // 車両保険金額（円）
  final String? vehicleInsuranceDeductible; // 免責金額（例:5-10万円）

  // --- 運転者条件 ---
  final String? driverScope; // 運転者範囲（本人/夫婦/家族/限定なし）
  final String? driverAgeCondition; // 年齢条件（全年齢/21/26/35歳以上）

  // --- 特約 ---
  final List<String> specialClauses; // 弁護士費用特約・ロードサービス等

  const VoluntaryInsurance({
    this.companyName,
    this.policyNumber,
    this.expiryDate,
    this.coverageType,
    this.agentName,
    this.agentPhone,
    this.contractStartDate,
    this.annualPremium,
    this.paymentMethod,
    this.contractType,
    this.usagePurpose,
    this.namedInsured,
    this.nonFleetGrade,
    this.accidentCoefficientPeriod,
    this.fleetDiscountRate,
    this.bodilyInjuryLimit,
    this.propertyDamageLimit,
    this.personalInjuryAmount,
    this.passengerInjuryAmount,
    this.hasVehicleInsurance,
    this.vehicleInsuranceType,
    this.vehicleInsuranceAmount,
    this.vehicleInsuranceDeductible,
    this.driverScope,
    this.driverAgeCondition,
    this.specialClauses = const [],
  });

  factory VoluntaryInsurance.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const VoluntaryInsurance();
    return VoluntaryInsurance(
      companyName: map['companyName'],
      policyNumber: map['policyNumber'],
      expiryDate: map['expiryDate'] != null
          ? (map['expiryDate'] as Timestamp).toDate()
          : null,
      coverageType: map['coverageType'],
      agentName: map['agentName'],
      agentPhone: map['agentPhone'],
      contractStartDate: map['contractStartDate'] != null
          ? (map['contractStartDate'] as Timestamp).toDate()
          : null,
      annualPremium: map['annualPremium'],
      paymentMethod: map['paymentMethod'],
      contractType: InsuranceContractType.fromString(map['contractType']),
      usagePurpose: map['usagePurpose'],
      namedInsured: map['namedInsured'],
      nonFleetGrade: map['nonFleetGrade'],
      accidentCoefficientPeriod: map['accidentCoefficientPeriod'],
      fleetDiscountRate: (map['fleetDiscountRate'] as num?)?.toDouble(),
      bodilyInjuryLimit: map['bodilyInjuryLimit'],
      propertyDamageLimit: map['propertyDamageLimit'],
      personalInjuryAmount: map['personalInjuryAmount'],
      passengerInjuryAmount: map['passengerInjuryAmount'],
      hasVehicleInsurance: map['hasVehicleInsurance'],
      vehicleInsuranceType: map['vehicleInsuranceType'],
      vehicleInsuranceAmount: map['vehicleInsuranceAmount'],
      vehicleInsuranceDeductible: map['vehicleInsuranceDeductible'],
      driverScope: map['driverScope'],
      driverAgeCondition: map['driverAgeCondition'],
      specialClauses: (map['specialClauses'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'companyName': companyName,
      'policyNumber': policyNumber,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'coverageType': coverageType,
      'agentName': agentName,
      'agentPhone': agentPhone,
      'contractStartDate': contractStartDate != null
          ? Timestamp.fromDate(contractStartDate!)
          : null,
      'annualPremium': annualPremium,
      'paymentMethod': paymentMethod,
      'contractType': contractType?.name,
      'usagePurpose': usagePurpose,
      'namedInsured': namedInsured,
      'nonFleetGrade': nonFleetGrade,
      'accidentCoefficientPeriod': accidentCoefficientPeriod,
      'fleetDiscountRate': fleetDiscountRate,
      'bodilyInjuryLimit': bodilyInjuryLimit,
      'propertyDamageLimit': propertyDamageLimit,
      'personalInjuryAmount': personalInjuryAmount,
      'passengerInjuryAmount': passengerInjuryAmount,
      'hasVehicleInsurance': hasVehicleInsurance,
      'vehicleInsuranceType': vehicleInsuranceType,
      'vehicleInsuranceAmount': vehicleInsuranceAmount,
      'vehicleInsuranceDeductible': vehicleInsuranceDeductible,
      'driverScope': driverScope,
      'driverAgeCondition': driverAgeCondition,
      'specialClauses': specialClauses,
    };
  }

  /// 任意保険期限が近いか（30日以内）
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    final days = expiryDate!.difference(DateTime.now()).inDays;
    return days <= 30 && days >= 0;
  }

  /// 任意保険期限切れか
  bool get isExpired {
    if (expiryDate == null) return false;
    return expiryDate!.difference(DateTime.now()).inDays < 0;
  }

  /// 法人で多いフリート契約か
  bool get isFleetContract => contractType == InsuranceContractType.fleet;

  /// 何らかの補償内容が入力されているか（サマリー表示の出し分け用）
  bool get hasCoverageDetails =>
      bodilyInjuryLimit != null ||
      propertyDamageLimit != null ||
      personalInjuryAmount != null ||
      passengerInjuryAmount != null ||
      hasVehicleInsurance != null;

  VoluntaryInsurance copyWith({
    String? companyName,
    String? policyNumber,
    DateTime? expiryDate,
    String? coverageType,
    String? agentName,
    String? agentPhone,
    DateTime? contractStartDate,
    int? annualPremium,
    String? paymentMethod,
    InsuranceContractType? contractType,
    String? usagePurpose,
    String? namedInsured,
    int? nonFleetGrade,
    int? accidentCoefficientPeriod,
    double? fleetDiscountRate,
    String? bodilyInjuryLimit,
    String? propertyDamageLimit,
    String? personalInjuryAmount,
    String? passengerInjuryAmount,
    bool? hasVehicleInsurance,
    String? vehicleInsuranceType,
    int? vehicleInsuranceAmount,
    String? vehicleInsuranceDeductible,
    String? driverScope,
    String? driverAgeCondition,
    List<String>? specialClauses,
  }) {
    return VoluntaryInsurance(
      companyName: companyName ?? this.companyName,
      policyNumber: policyNumber ?? this.policyNumber,
      expiryDate: expiryDate ?? this.expiryDate,
      coverageType: coverageType ?? this.coverageType,
      agentName: agentName ?? this.agentName,
      agentPhone: agentPhone ?? this.agentPhone,
      contractStartDate: contractStartDate ?? this.contractStartDate,
      annualPremium: annualPremium ?? this.annualPremium,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      contractType: contractType ?? this.contractType,
      usagePurpose: usagePurpose ?? this.usagePurpose,
      namedInsured: namedInsured ?? this.namedInsured,
      nonFleetGrade: nonFleetGrade ?? this.nonFleetGrade,
      accidentCoefficientPeriod:
          accidentCoefficientPeriod ?? this.accidentCoefficientPeriod,
      fleetDiscountRate: fleetDiscountRate ?? this.fleetDiscountRate,
      bodilyInjuryLimit: bodilyInjuryLimit ?? this.bodilyInjuryLimit,
      propertyDamageLimit: propertyDamageLimit ?? this.propertyDamageLimit,
      personalInjuryAmount: personalInjuryAmount ?? this.personalInjuryAmount,
      passengerInjuryAmount:
          passengerInjuryAmount ?? this.passengerInjuryAmount,
      hasVehicleInsurance: hasVehicleInsurance ?? this.hasVehicleInsurance,
      vehicleInsuranceType: vehicleInsuranceType ?? this.vehicleInsuranceType,
      vehicleInsuranceAmount:
          vehicleInsuranceAmount ?? this.vehicleInsuranceAmount,
      vehicleInsuranceDeductible:
          vehicleInsuranceDeductible ?? this.vehicleInsuranceDeductible,
      driverScope: driverScope ?? this.driverScope,
      driverAgeCondition: driverAgeCondition ?? this.driverAgeCondition,
      specialClauses: specialClauses ?? this.specialClauses,
    );
  }
}

/// リース契約情報（法人・個人リース車両向け）
class LeaseInfo {
  final String? lessorName; // リース会社名
  final int? monthlyFee; // 月額リース料（円）
  final DateTime? contractStartDate; // 契約開始日
  final DateTime? contractEndDate; // 契約満了日
  final String? maintenancePackDetails; // メンテナンスパック内容

  const LeaseInfo({
    this.lessorName,
    this.monthlyFee,
    this.contractStartDate,
    this.contractEndDate,
    this.maintenancePackDetails,
  });

  factory LeaseInfo.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LeaseInfo();
    return LeaseInfo(
      lessorName: map['lessorName'],
      monthlyFee: map['monthlyFee'],
      contractStartDate: map['contractStartDate'] != null
          ? (map['contractStartDate'] as Timestamp).toDate()
          : null,
      contractEndDate: map['contractEndDate'] != null
          ? (map['contractEndDate'] as Timestamp).toDate()
          : null,
      maintenancePackDetails: map['maintenancePackDetails'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lessorName': lessorName,
      'monthlyFee': monthlyFee,
      'contractStartDate': contractStartDate != null
          ? Timestamp.fromDate(contractStartDate!)
          : null,
      'contractEndDate':
          contractEndDate != null ? Timestamp.fromDate(contractEndDate!) : null,
      'maintenancePackDetails': maintenancePackDetails,
    };
  }

  /// 何か1つでも入力されているか（空のリース情報は保存しない判定に使う）
  bool get hasAnyValue =>
      lessorName != null ||
      monthlyFee != null ||
      contractStartDate != null ||
      contractEndDate != null ||
      maintenancePackDetails != null;

  /// 契約満了が近いか（60日以内）
  bool get isExpiringSoon {
    if (contractEndDate == null) return false;
    final days = contractEndDate!.difference(DateTime.now()).inDays;
    return days <= 60 && days >= 0;
  }

  LeaseInfo copyWith({
    String? lessorName,
    int? monthlyFee,
    DateTime? contractStartDate,
    DateTime? contractEndDate,
    String? maintenancePackDetails,
  }) {
    return LeaseInfo(
      lessorName: lessorName ?? this.lessorName,
      monthlyFee: monthlyFee ?? this.monthlyFee,
      contractStartDate: contractStartDate ?? this.contractStartDate,
      contractEndDate: contractEndDate ?? this.contractEndDate,
      maintenancePackDetails:
          maintenancePackDetails ?? this.maintenancePackDetails,
    );
  }
}

/// 車両情報
class Vehicle {
  final String id;
  final String userId;
  final String maker;
  final String model;
  final int year;
  final String grade;
  final int mileage;
  final DateTime? mileageUpdatedAt; // Last updated date of mileage
  final String? imageUrl;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Phase 1.5 追加フィールド: 識別情報
  final String? licensePlate; // ナンバープレート（例: "品川 300 あ 12-34"）
  final String? vinNumber; // 車台番号（17桁）
  final String? modelCode; // 型式（例: "DBA-GRB"）

  // Phase 1.5 追加フィールド: 車検・保険
  final DateTime? inspectionExpiryDate; // 車検満了日 ★最重要
  final DateTime? insuranceExpiryDate; // 自賠責保険期限

  // Phase 1.5 追加フィールド: 詳細情報
  final String? color; // 車体色
  final int? engineDisplacement; // 排気量(cc)
  final FuelType? fuelType; // 燃料タイプ
  final DateTime? purchaseDate; // 購入日/納車日

  // Phase 5 追加フィールド: 車両詳細
  final DateTime? firstRegistrationDate; // 初年度登録日
  final DriveType? driveType; // 駆動方式
  final TransmissionType? transmissionType; // ミッション種別
  final int? vehicleWeight; // 車両重量(kg)
  final int? seatingCapacity; // 乗車定員

  // Phase 5 追加フィールド: 任意保険情報
  final VoluntaryInsurance? voluntaryInsurance;

  // リース契約情報（法人・個人リース車両）
  final LeaseInfo? leaseInfo;

  // フリート管理: 法人アカウントの companyId（= 管理者の userId）
  final String? companyId;
  // フリート担当者アサイン
  final String? assigneeId;
  final String? assigneeName;

  // 用途区分（車検サイクル計算用。null = 自家用乗用車として扱う）
  final VehicleUseCategory? useCategory;

  // 廃車・売却・リース返却など（active以外はアーカイブ扱い）
  final VehicleStatus status;
  final DateTime? retiredAt; // 売却/廃車した日付
  final String? retirementNote; // 売却先・廃車理由など（任意）
  final bool isDataRetained; // true: 整備記録を保持, false: 削除済み

  Vehicle({
    required this.id,
    required this.userId,
    this.companyId,
    this.assigneeId,
    this.assigneeName,
    required this.maker,
    required this.model,
    required this.year,
    required this.grade,
    required this.mileage,
    this.mileageUpdatedAt,
    this.imageUrl,
    required this.createdAt,
    required this.updatedAt,
    // Phase 1.5 追加
    this.licensePlate,
    this.vinNumber,
    this.modelCode,
    this.inspectionExpiryDate,
    this.insuranceExpiryDate,
    this.color,
    this.engineDisplacement,
    this.fuelType,
    this.purchaseDate,
    // Phase 5 追加
    this.firstRegistrationDate,
    this.driveType,
    this.transmissionType,
    this.vehicleWeight,
    this.seatingCapacity,
    this.voluntaryInsurance,
    this.leaseInfo,
    this.useCategory,
    this.status = VehicleStatus.active,
    this.retiredAt,
    this.retirementNote,
    this.isDataRetained = true,
  });

  /// 車検までの残日数（null: 車検日未設定）
  int? get daysUntilInspection {
    if (inspectionExpiryDate == null) return null;
    return inspectionExpiryDate!.difference(DateTime.now()).inDays;
  }

  /// 用途区分（未設定時は自家用乗用車として扱う）
  VehicleUseCategory get effectiveUseCategory =>
      useCategory ?? VehicleUseCategory.privatePassenger;

  /// 次回車検の推奨日（現在の満了日 + 用途区分別サイクル）
  ///
  /// 貨物車（4ナンバー）は毎年、自家用乗用車は2年ごと。
  DateTime? get suggestedNextInspectionDate {
    final current = inspectionExpiryDate;
    if (current == null) return null;
    return DateTime(
      current.year + effectiveUseCategory.inspectionCycleYears,
      current.month,
      current.day,
    );
  }

  /// 車検期限が近いか（30日以内）
  bool get isInspectionDueSoon {
    final days = daysUntilInspection;
    return days != null && days <= 30 && days >= 0;
  }

  /// 車検期限切れか
  bool get isInspectionExpired {
    final days = daysUntilInspection;
    return days != null && days < 0;
  }

  /// 自賠責保険までの残日数
  int? get daysUntilInsuranceExpiry {
    if (insuranceExpiryDate == null) return null;
    return insuranceExpiryDate!.difference(DateTime.now()).inDays;
  }

  /// 自賠責保険期限が近いか（30日以内）
  bool get isInsuranceDueSoon {
    final days = daysUntilInsuranceExpiry;
    return days != null && days <= 30 && days >= 0;
  }

  /// 車両の表示名（メーカー + 車種）
  String get displayName => '$maker $model';

  /// 車両の完全な表示名（メーカー + 車種 + グレード）
  String get fullDisplayName =>
      grade.isNotEmpty ? '$maker $model $grade' : '$maker $model';

  // Firestoreからデータを取得
  /// Current schema version for persisted `vehicles` documents.
  /// Bump this and register a step in [_migrator] whenever the stored shape
  /// changes. See `docs/SCHEMA_MIGRATION_STRATEGY.md`.
  static const int schemaVersion = 1;

  /// Lazy migrator applied on read. Empty step map = no migration yet
  /// (currentVersion == 1), so behaviour is unchanged until the first real
  /// schema change adds a `1 -> 2` step.
  static const DocumentMigrator _migrator = DocumentMigrator(
    <int, MigrationStep>{},
    currentVersion: schemaVersion,
  );

  factory Vehicle.fromFirestore(DocumentSnapshot doc) {
    final raw = doc.data() as Map<String, dynamic>;
    final data = _migrator.migrate(raw);
    return Vehicle(
      id: doc.id,
      userId: data['userId'] ?? '',
      maker: data['maker'] ?? '',
      model: data['model'] ?? '',
      year: data['year'] ?? 0,
      grade: data['grade'] ?? '',
      mileage: data['mileage'] ?? 0,
      mileageUpdatedAt: _parseTimestampNullable(data['mileageUpdatedAt']),
      imageUrl: data['imageUrl'],
      createdAt: _parseTimestamp(data['createdAt']),
      updatedAt: _parseTimestamp(data['updatedAt']),
      // Phase 1.5 追加フィールド
      licensePlate: data['licensePlate'],
      vinNumber: data['vinNumber'],
      modelCode: data['modelCode'],
      inspectionExpiryDate:
          _parseTimestampNullable(data['inspectionExpiryDate']),
      insuranceExpiryDate: _parseTimestampNullable(data['insuranceExpiryDate']),
      color: data['color'],
      engineDisplacement: data['engineDisplacement'],
      fuelType: FuelType.fromString(data['fuelType']),
      purchaseDate: _parseTimestampNullable(data['purchaseDate']),
      // Phase 5 追加フィールド
      firstRegistrationDate:
          _parseTimestampNullable(data['firstRegistrationDate']),
      driveType: DriveType.fromString(data['driveType']),
      transmissionType: TransmissionType.fromString(data['transmissionType']),
      vehicleWeight: data['vehicleWeight'],
      seatingCapacity: data['seatingCapacity'],
      voluntaryInsurance:
          VoluntaryInsurance.fromMap(data['voluntaryInsurance']),
      leaseInfo: data['leaseInfo'] != null
          ? LeaseInfo.fromMap(data['leaseInfo'])
          : null,
      companyId: data['companyId'],
      assigneeId: data['assigneeId'],
      assigneeName: data['assigneeName'],
      useCategory: VehicleUseCategory.fromString(data['useCategory']),
      status: VehicleStatus.fromString(data['status']),
      retiredAt: _parseTimestampNullable(data['retiredAt']),
      retirementNote: data['retirementNote'],
      isDataRetained: data['isDataRetained'] ?? true,
    );
  }

  // Timestampを安全にパース（nullの場合は現在時刻を返す）
  static DateTime _parseTimestamp(dynamic value) {
    if (value == null) {
      return DateTime.now();
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return DateTime.now();
  }

  // Timestampを安全にパース（nullの場合はnullを返す）
  static DateTime? _parseTimestampNullable(dynamic value) {
    if (value == null) {
      return null;
    }
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  // Firestoreに保存するためのMap
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'maker': maker,
      'model': model,
      'year': year,
      'grade': grade,
      'mileage': mileage,
      'mileageUpdatedAt': mileageUpdatedAt != null
          ? Timestamp.fromDate(mileageUpdatedAt!)
          : null,
      'imageUrl': imageUrl,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      // Phase 1.5 追加フィールド
      'licensePlate': licensePlate,
      'vinNumber': vinNumber,
      'modelCode': modelCode,
      'inspectionExpiryDate': inspectionExpiryDate != null
          ? Timestamp.fromDate(inspectionExpiryDate!)
          : null,
      'insuranceExpiryDate': insuranceExpiryDate != null
          ? Timestamp.fromDate(insuranceExpiryDate!)
          : null,
      'color': color,
      'engineDisplacement': engineDisplacement,
      'fuelType': fuelType?.name,
      'purchaseDate':
          purchaseDate != null ? Timestamp.fromDate(purchaseDate!) : null,
      // Phase 5 追加フィールド
      'firstRegistrationDate': firstRegistrationDate != null
          ? Timestamp.fromDate(firstRegistrationDate!)
          : null,
      'driveType': driveType?.name,
      'transmissionType': transmissionType?.name,
      'vehicleWeight': vehicleWeight,
      'seatingCapacity': seatingCapacity,
      'voluntaryInsurance': voluntaryInsurance?.toMap(),
      'leaseInfo': leaseInfo?.toMap(),
      'companyId': companyId,
      'assigneeId': assigneeId,
      'assigneeName': assigneeName,
      'useCategory': useCategory?.name,
      'status': status.name,
      'retiredAt': retiredAt != null ? Timestamp.fromDate(retiredAt!) : null,
      'retirementNote': retirementNote,
      'isDataRetained': isDataRetained,
      // Always stamp the current schema version on write so future reads of
      // this document need no migration.
      DocumentMigrator.versionField: schemaVersion,
    };
  }

  // コピーメソッド
  Vehicle copyWith({
    String? id,
    String? userId,
    String? maker,
    String? model,
    int? year,
    String? grade,
    int? mileage,
    DateTime? mileageUpdatedAt,
    String? imageUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
    // Phase 1.5 追加
    String? licensePlate,
    String? vinNumber,
    String? modelCode,
    DateTime? inspectionExpiryDate,
    DateTime? insuranceExpiryDate,
    String? color,
    int? engineDisplacement,
    FuelType? fuelType,
    DateTime? purchaseDate,
    // Phase 5 追加
    DateTime? firstRegistrationDate,
    DriveType? driveType,
    TransmissionType? transmissionType,
    int? vehicleWeight,
    int? seatingCapacity,
    VoluntaryInsurance? voluntaryInsurance,
    LeaseInfo? leaseInfo,
    String? companyId,
    String? assigneeId,
    String? assigneeName,
    VehicleUseCategory? useCategory,
    VehicleStatus? status,
    DateTime? retiredAt,
    String? retirementNote,
    bool? isDataRetained,
  }) {
    return Vehicle(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      companyId: companyId ?? this.companyId,
      assigneeId: assigneeId ?? this.assigneeId,
      assigneeName: assigneeName ?? this.assigneeName,
      maker: maker ?? this.maker,
      model: model ?? this.model,
      year: year ?? this.year,
      grade: grade ?? this.grade,
      mileage: mileage ?? this.mileage,
      mileageUpdatedAt: mileageUpdatedAt ?? this.mileageUpdatedAt,
      imageUrl: imageUrl ?? this.imageUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      // Phase 1.5 追加
      licensePlate: licensePlate ?? this.licensePlate,
      vinNumber: vinNumber ?? this.vinNumber,
      modelCode: modelCode ?? this.modelCode,
      inspectionExpiryDate: inspectionExpiryDate ?? this.inspectionExpiryDate,
      insuranceExpiryDate: insuranceExpiryDate ?? this.insuranceExpiryDate,
      color: color ?? this.color,
      engineDisplacement: engineDisplacement ?? this.engineDisplacement,
      fuelType: fuelType ?? this.fuelType,
      purchaseDate: purchaseDate ?? this.purchaseDate,
      // Phase 5 追加
      firstRegistrationDate:
          firstRegistrationDate ?? this.firstRegistrationDate,
      driveType: driveType ?? this.driveType,
      transmissionType: transmissionType ?? this.transmissionType,
      vehicleWeight: vehicleWeight ?? this.vehicleWeight,
      seatingCapacity: seatingCapacity ?? this.seatingCapacity,
      voluntaryInsurance: voluntaryInsurance ?? this.voluntaryInsurance,
      leaseInfo: leaseInfo ?? this.leaseInfo,
      useCategory: useCategory ?? this.useCategory,
      status: status ?? this.status,
      retiredAt: retiredAt ?? this.retiredAt,
      retirementNote: retirementNote ?? this.retirementNote,
      isDataRetained: isDataRetained ?? this.isDataRetained,
    );
  }

  /// リース契約満了までの残日数（null: リース情報なし/満了日未設定）
  int? get daysUntilLeaseExpiry {
    if (leaseInfo?.contractEndDate == null) return null;
    return leaseInfo!.contractEndDate!.difference(DateTime.now()).inDays;
  }

  /// 任意保険期限までの残日数
  int? get daysUntilVoluntaryInsuranceExpiry {
    if (voluntaryInsurance?.expiryDate == null) return null;
    return voluntaryInsurance!.expiryDate!.difference(DateTime.now()).inDays;
  }

  /// 任意保険期限が近いか（30日以内）
  bool get isVoluntaryInsuranceDueSoon {
    return voluntaryInsurance?.isExpiringSoon ?? false;
  }

  @override
  String toString() {
    return 'Vehicle(id: $id, $displayName, year: $year, mileage: $mileage km)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Vehicle && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
