import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../models/maintenance_record.dart';

/// 整備記録の明細表示。
///
/// `MaintenanceRecord` は44項目を持つが、画面に出ていたのは
/// 整備店 / 走行距離 / メモ / 作業項目名だけだった。請求書OCRが読み取る
/// 部品名・数量・単価・税額も、次回交換時期も、保存されるだけで
/// 誰も見られない状態だった。ここでその受け皿を作る。
///
/// 値が無い項目は行ごと出さない。空欄が並ぶより、あるものだけが
/// 並んでいるほうが読める。
class MaintenanceDetailBreakdown extends StatelessWidget {
  final MaintenanceRecord record;

  const MaintenanceDetailBreakdown({super.key, required this.record});

  static final _yen = NumberFormat('#,###');
  static final _date = DateFormat('yyyy年MM月dd日');

  @override
  Widget build(BuildContext context) {
    final sections = <Widget>[
      ..._partsSection(context),
      ..._costSection(context),
      ..._nextReplacementSection(context),
      ..._inspectionSection(context),
      ..._tireSection(context),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const Key('maintenance_detail_breakdown'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sections,
    );
  }

  // ---------------------------------------------------------------------------
  // 部品明細
  // ---------------------------------------------------------------------------

  List<Widget> _partsSection(BuildContext context) {
    if (record.parts.isEmpty) return const [];
    final theme = Theme.of(context);
    return [
      AppSpacing.verticalMd,
      _label(context, '使用部品'),
      AppSpacing.verticalXxs,
      ...record.parts.map(
        (part) => Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.settings_outlined, size: 16),
              AppSpacing.horizontalXs,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(part.name, style: theme.textTheme.bodyMedium),
                    if (_partSubtitle(part) != null)
                      Text(
                        _partSubtitle(part)!,
                        style: theme.textTheme.bodySmall
                            ?.copyWith(color: AppColors.textSecondary),
                      ),
                  ],
                ),
              ),
              AppSpacing.horizontalXs,
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '¥${_yen.format(part.subtotal)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (part.quantity > 1)
                    Text(
                      '¥${_yen.format(part.unitPrice)} × ${part.quantity}',
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: AppColors.textSecondary),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ];
  }

  /// 部品番号とメーカーを1行にまとめる。どちらも無ければ行を出さない。
  String? _partSubtitle(Part part) {
    final parts = <String>[
      if (part.manufacturer != null && part.manufacturer!.isNotEmpty)
        part.manufacturer!,
      if (part.partNumber.isNotEmpty) '品番 ${part.partNumber}',
    ];
    return parts.isEmpty ? null : parts.join(' / ');
  }

  // ---------------------------------------------------------------------------
  // 金額内訳
  // ---------------------------------------------------------------------------

  List<Widget> _costSection(BuildContext context) {
    final rows = <Widget>[
      if (record.partsCost != null) _costRow(context, '部品代', record.partsCost!),
      if (record.laborCost != null) _costRow(context, '工賃', record.laborCost!),
      if (record.miscCost != null)
        _costRow(context, '諸費用（印紙代等）', record.miscCost!),
      if (record.discountAmount != null)
        _costRow(context, '割引', -record.discountAmount!),
      if (record.taxAmount != null) _costRow(context, '消費税', record.taxAmount!),
    ];
    if (rows.isEmpty) return const [];

    final theme = Theme.of(context);
    return [
      AppSpacing.verticalMd,
      _label(context, '金額内訳'),
      AppSpacing.verticalXxs,
      ...rows,
      const Divider(height: AppSpacing.md),
      Row(
        children: [
          Expanded(
            child: Text(
              '合計',
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
          ),
          Text(
            '¥${_yen.format(record.cost)}',
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      // 内訳の合計と請求額がずれている場合だけ注記する。読み取り漏れや
      // 入力漏れに気付ける唯一の手がかりになる。
      if (record.calculatedTotal != record.cost)
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xxs),
          child: Text(
            '内訳の合計は ¥${_yen.format(record.calculatedTotal)} です。'
            '請求額と一致しません。',
            style:
                theme.textTheme.bodySmall?.copyWith(color: AppColors.warning),
          ),
        ),
    ];
  }

  Widget _costRow(BuildContext context, String label, int amount) {
    final theme = Theme.of(context);
    final sign = amount < 0 ? '-' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            '$sign¥${_yen.format(amount.abs())}',
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 次回交換時期
  // ---------------------------------------------------------------------------

  List<Widget> _nextReplacementSection(BuildContext context) {
    final date = record.nextReplacementDate;
    final mileage = record.nextReplacementMileage;
    if (date == null && mileage == null) return const [];

    final theme = Theme.of(context);
    final isDueSoon = record.isReplacementDueSoon;
    final values = <String>[
      if (date != null) _date.format(date),
      if (mileage != null) '${_yen.format(mileage)} km',
    ];

    return [
      AppSpacing.verticalMd,
      Container(
        padding: const EdgeInsets.all(AppSpacing.sm),
        decoration: BoxDecoration(
          color: (isDueSoon ? AppColors.warning : AppColors.info)
              .withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AppSpacing.radiusSm),
        ),
        child: Row(
          children: [
            Icon(
              isDueSoon ? Icons.notification_important : Icons.event_repeat,
              size: 18,
              color: isDueSoon ? AppColors.warning : AppColors.info,
            ),
            AppSpacing.horizontalXs,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '次回交換の目安',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: isDueSoon ? AppColors.warning : AppColors.info,
                    ),
                  ),
                  Text(
                    values.join(' / '),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ];
  }

  // ---------------------------------------------------------------------------
  // 点検・車検の結果
  // ---------------------------------------------------------------------------

  List<Widget> _inspectionSection(BuildContext context) {
    final rows = <Widget>[
      if (record.inspectionResult != null)
        _infoRow(
          context,
          Icons.fact_check_outlined,
          '判定',
          record.inspectionResult!.displayName,
          valueColor: record.inspectionResult == InspectionResult.failed
              ? AppColors.error
              : record.inspectionResult == InspectionResult.passed
                  ? AppColors.success
                  : AppColors.warning,
        ),
      if (record.safetyStandardsCertificate != null &&
          record.safetyStandardsCertificate!.isNotEmpty)
        _infoRow(context, Icons.description_outlined, '保安基準適合証',
            record.safetyStandardsCertificate!),
      if (record.certificateUpdated)
        _infoRow(context, Icons.assignment_turned_in_outlined, '車検証', '更新済み'),
      if (record.staffName != null && record.staffName!.isNotEmpty)
        _infoRow(context, Icons.person_outline, '担当者', record.staffName!),
    ];
    if (rows.isEmpty) return const [];
    return [
      AppSpacing.verticalMd,
      _label(context, '点検・証明'),
      AppSpacing.verticalXxs,
      ...rows,
    ];
  }

  // ---------------------------------------------------------------------------
  // タイヤ
  // ---------------------------------------------------------------------------

  List<Widget> _tireSection(BuildContext context) {
    final rows = <Widget>[
      if (record.tireSize != null && record.tireSize!.isNotEmpty)
        _infoRow(context, Icons.straighten, 'サイズ', record.tireSize!),
      if (record.tirePosition != null && record.tirePosition!.isNotEmpty)
        _infoRow(context, Icons.swap_horiz, '装着位置', record.tirePosition!),
      if (record.tireTreadDepth != null)
        _infoRow(
          context,
          Icons.height,
          '溝の深さ',
          '${record.tireTreadDepth} mm',
          // 1.6mm が保安基準の限度。下回っていれば整備が必要。
          valueColor: record.tireTreadDepth! <= 2 ? AppColors.warning : null,
        ),
    ];
    if (rows.isEmpty) return const [];
    return [
      AppSpacing.verticalMd,
      _label(context, 'タイヤ'),
      AppSpacing.verticalXxs,
      ...rows,
    ];
  }

  // ---------------------------------------------------------------------------
  // 共通パーツ
  // ---------------------------------------------------------------------------

  Widget _label(BuildContext context, String text) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Text(
      text,
      style: theme.textTheme.labelLarge?.copyWith(
        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
      ),
    );
  }

  Widget _infoRow(
    BuildContext context,
    IconData icon,
    String label,
    String value, {
    Color? valueColor,
  }) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          AppSpacing.horizontalXs,
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: theme.textTheme.bodyMedium?.copyWith(color: valueColor),
            ),
          ),
        ],
      ),
    );
  }
}
