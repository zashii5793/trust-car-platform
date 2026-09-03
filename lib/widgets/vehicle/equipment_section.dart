import 'package:flutter/material.dart';

import '../../core/constants/spacing.dart';
import '../../core/constants/vehicle_equipment_catalog.dart';
import '../../models/vehicle_equipment.dart';
import '../common/app_text_field.dart';

/// オプション・装備の入力セクション。
///
/// ナビ / ドラレコ / ETC は「有無」だけでは足りない。買い替え相談も
/// 売却査定も整備依頼も、メーカーと型番が分からないと話が始まらない。
/// メーカーは候補を出すが、**候補に無いものを手入力できる**。
/// メーカー・車種・グレードと同じ方針で、候補は補助でありゲートではない。
class EquipmentSection extends StatefulWidget {
  final VehicleEquipment value;
  final ValueChanged<VehicleEquipment> onChanged;

  const EquipmentSection({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  State<EquipmentSection> createState() => _EquipmentSectionState();
}

class _EquipmentSectionState extends State<EquipmentSection> {
  late final TextEditingController _othersController;

  @override
  void initState() {
    super.initState();
    _othersController =
        TextEditingController(text: widget.value.others.join('、'));
  }

  @override
  void dispose() {
    _othersController.dispose();
    super.dispose();
  }

  void _update(VehicleEquipment next) => widget.onChanged(next);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _EquipmentItemField(
          key: const Key('equipment_navigation'),
          title: 'カーナビ',
          icon: Icons.navigation,
          makerCandidates: kNavigationMakers,
          modelNumberHint: '例: AVIC-RQ720',
          item: value.navigation,
          onChanged: (item) => _update(value.copyWith(navigation: item)),
        ),
        AppSpacing.verticalMd,
        _EquipmentItemField(
          key: const Key('equipment_drive_recorder'),
          title: 'ドライブレコーダー',
          icon: Icons.videocam,
          makerCandidates: kDriveRecorderMakers,
          modelNumberHint: '例: ZDR035',
          item: value.driveRecorder,
          onChanged: (item) => _update(value.copyWith(driveRecorder: item)),
        ),
        AppSpacing.verticalMd,
        _EquipmentItemField(
          key: const Key('equipment_etc'),
          title: 'ETC車載器',
          icon: Icons.toll,
          makerCandidates: kEtcMakers,
          modelNumberHint: '例: ETC2.0 対応品',
          item: value.etc,
          onChanged: (item) => _update(value.copyWith(etc: item)),
        ),
        AppSpacing.verticalLg,
        Text('その他の装備', style: theme.textTheme.titleSmall),
        AppSpacing.verticalSm,
        Wrap(
          key: const Key('equipment_features'),
          spacing: AppSpacing.sm,
          runSpacing: AppSpacing.xs,
          children: [
            for (final feature in VehicleFeature.values)
              FilterChip(
                label: Text(feature.label),
                selected: value.features.contains(feature),
                onSelected: (selected) {
                  final next = Set<VehicleFeature>.from(value.features);
                  if (selected) {
                    next.add(feature);
                  } else {
                    next.remove(feature);
                  }
                  _update(value.copyWith(features: next));
                },
              ),
          ],
        ),
        AppSpacing.verticalMd,
        // 一覧に無い装備の受け皿。ここが無いと「網羅できていない」ことが
        // そのまま「登録できない」になる。
        AppTextField(
          key: const Key('equipment_others'),
          controller: _othersController,
          labelText: 'その他（自由入力）',
          hintText: '例: 社外マフラー、牽引フック',
          helperText: '読点（、）で区切って複数入力できます',
          prefixIcon: const Icon(Icons.add_circle_outline),
          onChanged: (text) {
            final others = text
                .split(RegExp(r'[、,]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
            _update(value.copyWith(others: others));
          },
        ),
      ],
    );
  }
}

/// メーカー・型番を持つ装備1点の入力欄。
class _EquipmentItemField extends StatefulWidget {
  final String title;
  final IconData icon;
  final List<String> makerCandidates;
  final String modelNumberHint;
  final EquipmentItem item;
  final ValueChanged<EquipmentItem> onChanged;

  const _EquipmentItemField({
    super.key,
    required this.title,
    required this.icon,
    required this.makerCandidates,
    required this.modelNumberHint,
    required this.item,
    required this.onChanged,
  });

  @override
  State<_EquipmentItemField> createState() => _EquipmentItemFieldState();
}

class _EquipmentItemFieldState extends State<_EquipmentItemField> {
  late final TextEditingController _makerController;
  late final TextEditingController _modelNumberController;

  @override
  void initState() {
    super.initState();
    _makerController = TextEditingController(text: widget.item.maker ?? '');
    _modelNumberController =
        TextEditingController(text: widget.item.modelNumber ?? '');
  }

  @override
  void dispose() {
    _makerController.dispose();
    _modelNumberController.dispose();
    super.dispose();
  }

  /// 入力欄の現在値をそのまま親へ返す。
  ///
  /// 3つの値を個別に持つと、片方の変更で他方が消える事故が起きやすい。
  /// 常に「今画面に出ている3つ」をまとめて返す。
  void _emit({bool? installed}) {
    widget.onChanged(EquipmentItem(
      installed: installed ?? widget.item.installed,
      maker: _makerController.text,
      modelNumber: _modelNumberController.text,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(widget.icon, size: 20, color: theme.colorScheme.primary),
                AppSpacing.horizontalSm,
                Expanded(
                  child: Text(widget.title, style: theme.textTheme.titleSmall),
                ),
                Switch(
                  value: widget.item.installed,
                  onChanged: (installed) => _emit(installed: installed),
                ),
              ],
            ),
            if (widget.item.installed) ...[
              AppSpacing.verticalSm,
              // メーカーは候補から選べるが、選択肢に無いものはそのまま
              // 入力できる。候補は補助であってゲートではない。
              AppTextField(
                controller: _makerController,
                labelText: 'メーカー（任意）',
                hintText: '候補に無いメーカーもそのまま入力できます',
                prefixIcon: const Icon(Icons.business),
                onChanged: (_) => _emit(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_drop_down),
                  tooltip: '候補から選ぶ',
                  onPressed: _showMakerCandidates,
                ),
              ),
              AppSpacing.verticalSm,
              AppTextField(
                controller: _modelNumberController,
                labelText: '型番（任意）',
                hintText: widget.modelNumberHint,
                prefixIcon: const Icon(Icons.tag),
                onChanged: (_) => _emit(),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showMakerCandidates() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppSpacing.md),
              child: Text('候補に無いメーカーは入力欄に直接書けます'),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.makerCandidates.length,
                itemBuilder: (_, i) => ListTile(
                  title: Text(widget.makerCandidates[i]),
                  onTap: () {
                    _makerController.text = widget.makerCandidates[i];
                    _emit();
                    Navigator.pop(sheetContext);
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
