/// Preset coverage sets that pre-fill the insurance form with one tap, so
/// users don't have to type common combinations from scratch.
///
/// These are入力補助のたたき台であり、実際の契約内容で上書きされる前提。
class InsuranceTemplate {
  final String name; // ボタン表示名
  final String description; // 補足説明
  final String bodilyInjuryLimit;
  final String propertyDamageLimit;
  final String personalInjuryAmount;
  final bool hasVehicleInsurance;
  final String? vehicleInsuranceType;
  final List<String> specialClauses;

  const InsuranceTemplate({
    required this.name,
    required this.description,
    required this.bodilyInjuryLimit,
    required this.propertyDamageLimit,
    required this.personalInjuryAmount,
    required this.hasVehicleInsurance,
    this.vehicleInsuranceType,
    this.specialClauses = const [],
  });
}

/// Built-in templates, ordered from most to least comprehensive.
const List<InsuranceTemplate> insuranceTemplates = [
  InsuranceTemplate(
    name: '手厚い',
    description: '対人対物無制限・車両保険一般型・主要特約あり',
    bodilyInjuryLimit: '無制限',
    propertyDamageLimit: '無制限',
    personalInjuryAmount: '5000万円',
    hasVehicleInsurance: true,
    vehicleInsuranceType: '一般',
    specialClauses: ['弁護士費用特約', 'ロードサービス', '個人賠償責任特約'],
  ),
  InsuranceTemplate(
    name: '標準',
    description: '対人対物無制限・車両保険車対車+A・弁護士特約',
    bodilyInjuryLimit: '無制限',
    propertyDamageLimit: '無制限',
    personalInjuryAmount: '3000万円',
    hasVehicleInsurance: true,
    vehicleInsuranceType: '車対車+A（エコノミー）',
    specialClauses: ['弁護士費用特約', 'ロードサービス'],
  ),
  InsuranceTemplate(
    name: '最小',
    description: '対人対物無制限・車両保険なし',
    bodilyInjuryLimit: '無制限',
    propertyDamageLimit: '無制限',
    personalInjuryAmount: '3000万円',
    hasVehicleInsurance: false,
    specialClauses: ['弁護士費用特約'],
  ),
];
