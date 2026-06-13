import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/constants/spacing.dart';
import '../core/di/service_locator.dart';
import '../models/vehicle.dart';
import '../services/firebase_service.dart';

/// 任意保険の詳細編集画面（個人・法人フリート契約に両対応）。
///
/// 保険証券はフォーマットがまちまちで OCR が難しいため、手入力前提で
/// 「自分がどんな保険に入っているか」を網羅的に記録できることを重視している。
/// 保存すると更新後の [Vehicle] を `Navigator.pop` で返す。
class InsuranceEditScreen extends StatefulWidget {
  final Vehicle vehicle;

  const InsuranceEditScreen({super.key, required this.vehicle});

  @override
  State<InsuranceEditScreen> createState() => _InsuranceEditScreenState();
}

class _InsuranceEditScreenState extends State<InsuranceEditScreen> {
  // --- text controllers ---
  final _companyCtrl = TextEditingController();
  final _policyCtrl = TextEditingController();
  final _insuredCtrl = TextEditingController();
  final _gradeCtrl = TextEditingController();
  final _accidentCtrl = TextEditingController();
  final _fleetRateCtrl = TextEditingController();
  final _bodilyCtrl = TextEditingController();
  final _propertyCtrl = TextEditingController();
  final _personalCtrl = TextEditingController();
  final _passengerCtrl = TextEditingController();
  final _vehAmountCtrl = TextEditingController();
  final _deductibleCtrl = TextEditingController();
  final _premiumCtrl = TextEditingController();

  // --- choice/state ---
  InsuranceContractType _contractType = InsuranceContractType.nonFleet;
  String? _usagePurpose;
  String? _driverScope;
  String? _driverAgeCondition;
  String? _paymentMethod;
  String? _vehicleInsuranceType;
  bool _hasVehicleInsurance = false;
  DateTime? _expiryDate;
  DateTime? _startDate;
  final Set<String> _clauses = {};
  bool _saving = false;

  static const _usageOptions = ['業務用', '通勤・通学', '日常・レジャー'];
  static const _driverScopeOptions = ['本人限定', '夫婦限定', '家族限定', '限定なし'];
  static const _ageOptions = ['全年齢補償', '21歳以上', '26歳以上', '35歳以上'];
  static const _paymentOptions = ['月払', '年払'];
  static const _vehTypeOptions = ['一般', '車対車+A（エコノミー）'];
  static const _clauseOptions = [
    '弁護士費用特約',
    'ロードサービス',
    '対物超過修理費用特約',
    '個人賠償責任特約',
    '人身傷害（車外）',
    'レンタカー費用特約',
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicle.voluntaryInsurance;
    if (v != null) {
      _companyCtrl.text = v.companyName ?? '';
      _policyCtrl.text = v.policyNumber ?? '';
      _insuredCtrl.text = v.namedInsured ?? '';
      _gradeCtrl.text = v.nonFleetGrade?.toString() ?? '';
      _accidentCtrl.text = v.accidentCoefficientPeriod?.toString() ?? '';
      _fleetRateCtrl.text = v.fleetDiscountRate?.toString() ?? '';
      _bodilyCtrl.text = v.bodilyInjuryLimit ?? '';
      _propertyCtrl.text = v.propertyDamageLimit ?? '';
      _personalCtrl.text = v.personalInjuryAmount ?? '';
      _passengerCtrl.text = v.passengerInjuryAmount ?? '';
      _vehAmountCtrl.text = v.vehicleInsuranceAmount?.toString() ?? '';
      _deductibleCtrl.text = v.vehicleInsuranceDeductible ?? '';
      _premiumCtrl.text = v.annualPremium?.toString() ?? '';
      _contractType = v.contractType ?? InsuranceContractType.nonFleet;
      _usagePurpose = _orNull(v.usagePurpose, _usageOptions);
      _driverScope = _orNull(v.driverScope, _driverScopeOptions);
      _driverAgeCondition = _orNull(v.driverAgeCondition, _ageOptions);
      _paymentMethod = _orNull(v.paymentMethod, _paymentOptions);
      _vehicleInsuranceType = _orNull(v.vehicleInsuranceType, _vehTypeOptions);
      _hasVehicleInsurance = v.hasVehicleInsurance ?? false;
      _expiryDate = v.expiryDate;
      _startDate = v.contractStartDate;
      _clauses.addAll(v.specialClauses);
    }
  }

  /// Keep a stored value only if it matches a known option (avoids dropdown
  /// assertion errors when legacy free-text values don't match).
  String? _orNull(String? value, List<String> options) =>
      (value != null && options.contains(value)) ? value : null;

  @override
  void dispose() {
    for (final c in [
      _companyCtrl,
      _policyCtrl,
      _insuredCtrl,
      _gradeCtrl,
      _accidentCtrl,
      _fleetRateCtrl,
      _bodilyCtrl,
      _propertyCtrl,
      _personalCtrl,
      _passengerCtrl,
      _vehAmountCtrl,
      _deductibleCtrl,
      _premiumCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();
  int? _int(TextEditingController c) => int.tryParse(c.text.trim());
  double? _double(TextEditingController c) => double.tryParse(c.text.trim());

  Future<void> _pickDate({
    required DateTime? current,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: current ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) onPicked(picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final existing = widget.vehicle.voluntaryInsurance;
    final isFleet = _contractType == InsuranceContractType.fleet;

    final insurance = VoluntaryInsurance(
      companyName: _text(_companyCtrl),
      policyNumber: _text(_policyCtrl),
      expiryDate: _expiryDate,
      // Carry forward legacy fields not surfaced in this form.
      coverageType: existing?.coverageType,
      agentName: existing?.agentName,
      agentPhone: existing?.agentPhone,
      contractStartDate: _startDate,
      annualPremium: _int(_premiumCtrl),
      paymentMethod: _paymentMethod,
      contractType: _contractType,
      usagePurpose: _usagePurpose,
      namedInsured: _text(_insuredCtrl),
      nonFleetGrade: isFleet ? null : _int(_gradeCtrl),
      accidentCoefficientPeriod: isFleet ? null : _int(_accidentCtrl),
      fleetDiscountRate: isFleet ? _double(_fleetRateCtrl) : null,
      bodilyInjuryLimit: _text(_bodilyCtrl),
      propertyDamageLimit: _text(_propertyCtrl),
      personalInjuryAmount: _text(_personalCtrl),
      passengerInjuryAmount: _text(_passengerCtrl),
      hasVehicleInsurance: _hasVehicleInsurance,
      vehicleInsuranceType: _hasVehicleInsurance ? _vehicleInsuranceType : null,
      vehicleInsuranceAmount:
          _hasVehicleInsurance ? _int(_vehAmountCtrl) : null,
      vehicleInsuranceDeductible:
          _hasVehicleInsurance ? _text(_deductibleCtrl) : null,
      driverScope: _driverScope,
      driverAgeCondition: _driverAgeCondition,
      specialClauses: _clauses.toList(),
    );

    final updated = widget.vehicle.copyWith(
      voluntaryInsurance: insurance,
      updatedAt: DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      final result =
          await sl.get<FirebaseService>().updateVehicle(updated.id, updated);
      if (!mounted) return;
      result.when(
        success: (_) {
          messenger.showSnackBar(
            const SnackBar(content: Text('保険情報を保存しました')),
          );
          navigator.pop(updated);
        },
        failure: (_) {
          messenger.showSnackBar(
            const SnackBar(content: Text('保存に失敗しました')),
          );
        },
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isFleet = _contractType == InsuranceContractType.fleet;

    return Scaffold(
      appBar: AppBar(title: const Text('任意保険の編集')),
      body: ListView(
        padding: AppSpacing.paddingScreen,
        children: [
          _sectionHeader('契約'),
          SegmentedButton<InsuranceContractType>(
            segments: const [
              ButtonSegment(
                value: InsuranceContractType.nonFleet,
                label: Text('ノンフリート'),
              ),
              ButtonSegment(
                value: InsuranceContractType.fleet,
                label: Text('フリート（法人）'),
              ),
            ],
            selected: {_contractType},
            onSelectionChanged: (s) => setState(() => _contractType = s.first),
          ),
          AppSpacing.verticalSm,
          _textField(_companyCtrl, '保険会社名'),
          _textField(_policyCtrl, '証券番号'),
          _textField(_insuredCtrl, isFleet ? '記名被保険者（法人名）' : '記名被保険者（契約者）'),
          _dateField(
            label: '契約開始日',
            value: _startDate,
            onTap: () => _pickDate(
                current: _startDate,
                onPicked: (d) {
                  setState(() => _startDate = d);
                }),
          ),
          _dateField(
            label: '満期日',
            value: _expiryDate,
            onTap: () => _pickDate(
                current: _expiryDate,
                onPicked: (d) {
                  setState(() => _expiryDate = d);
                }),
          ),
          _dropdown(
            label: '使用目的',
            value: _usagePurpose,
            options: _usageOptions,
            onChanged: (v) => setState(() => _usagePurpose = v),
          ),
          AppSpacing.verticalMd,
          _sectionHeader(isFleet ? '料率' : '等級'),
          if (isFleet)
            _textField(_fleetRateCtrl, 'フリート割増引率（%）',
                keyboard: TextInputType.number)
          else ...[
            _textField(_gradeCtrl, 'ノンフリート等級（6〜20）',
                keyboard: TextInputType.number),
            _textField(_accidentCtrl, '事故有係数適用期間（年）',
                keyboard: TextInputType.number),
          ],
          AppSpacing.verticalMd,
          _sectionHeader('補償額'),
          _textField(_bodilyCtrl, '対人賠償', hint: '例: 無制限'),
          _textField(_propertyCtrl, '対物賠償', hint: '例: 無制限'),
          _textField(_personalCtrl, '人身傷害', hint: '例: 3000万円'),
          _textField(_passengerCtrl, '搭乗者傷害', hint: '例: 1000万円'),
          AppSpacing.verticalMd,
          _sectionHeader('車両保険'),
          SwitchListTile(
            key: const Key('has_vehicle_insurance_switch'),
            contentPadding: EdgeInsets.zero,
            title: const Text('車両保険に加入している'),
            value: _hasVehicleInsurance,
            onChanged: (v) => setState(() => _hasVehicleInsurance = v),
          ),
          if (_hasVehicleInsurance) ...[
            _dropdown(
              label: '車両保険の型',
              value: _vehicleInsuranceType,
              options: _vehTypeOptions,
              onChanged: (v) => setState(() => _vehicleInsuranceType = v),
            ),
            _textField(_vehAmountCtrl, '車両保険金額（円）',
                keyboard: TextInputType.number),
            _textField(_deductibleCtrl, '免責金額（自己負担）', hint: '例: 5-10万円'),
          ],
          AppSpacing.verticalMd,
          _sectionHeader('運転者条件'),
          _dropdown(
            label: '運転者範囲',
            value: _driverScope,
            options: _driverScopeOptions,
            onChanged: (v) => setState(() => _driverScope = v),
          ),
          _dropdown(
            label: '年齢条件',
            value: _driverAgeCondition,
            options: _ageOptions,
            onChanged: (v) => setState(() => _driverAgeCondition = v),
          ),
          AppSpacing.verticalMd,
          _sectionHeader('保険料'),
          _textField(_premiumCtrl, '年間保険料（円）', keyboard: TextInputType.number),
          _dropdown(
            label: '支払方法',
            value: _paymentMethod,
            options: _paymentOptions,
            onChanged: (v) => setState(() => _paymentMethod = v),
          ),
          AppSpacing.verticalMd,
          _sectionHeader('特約'),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: _clauseOptions.map((c) {
              final selected = _clauses.contains(c);
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (on) => setState(() {
                  if (on) {
                    _clauses.add(c);
                  } else {
                    _clauses.remove(c);
                  }
                }),
              );
            }).toList(),
          ),
          AppSpacing.verticalLg,
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              key: const Key('save_insurance_btn'),
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('保存する'),
            ),
          ),
          AppSpacing.verticalMd,
        ],
      ),
    );
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleSmall
            ?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }

  Widget _textField(
    TextEditingController controller,
    String label, {
    String? hint,
    TextInputType? keyboard,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: TextField(
        controller: controller,
        keyboardType: keyboard,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
      ),
    );
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required List<String> options,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: DropdownButtonFormField<String?>(
        initialValue: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label, isDense: true),
        items: [
          const DropdownMenuItem<String?>(
            value: null,
            child: Text('未選択'),
          ),
          ...options.map(
            (o) => DropdownMenuItem<String?>(value: o, child: Text(o)),
          ),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: InkWell(
        onTap: onTap,
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, isDense: true),
          child: Text(
            value != null ? DateFormat('yyyy年MM月dd日').format(value) : '未設定',
          ),
        ),
      ),
    );
  }
}
