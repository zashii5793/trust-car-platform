import 'package:flutter/material.dart';
import '../../models/maintenance_record.dart';
import '../../core/constants/colors.dart';

/// 証跡（元画像）を全画面で表示する。複数枚はスワイプで切り替え。
/// 「抽出が誤っても原本は残る」という証跡担保をユーザーがいつでも確認できる。
void showMaintenanceEvidence(BuildContext context, List<String> imageUrls) {
  if (imageUrls.isEmpty) return;
  showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          children: [
            PageView.builder(
              itemCount: imageUrls.length,
              itemBuilder: (_, i) => InteractiveViewer(
                child: Center(
                  child: Image.network(
                    imageUrls[i],
                    fit: BoxFit.contain,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 64,
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(dialogContext).pop(),
              ),
            ),
            if (imageUrls.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Text(
                  '${imageUrls.length}枚 — スワイプで切替',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
          ],
        ),
      );
    },
  );
}

/// 整備記録の「来歴（出所）」と「証跡（元画像）」を一目で示すバッジ。
///
/// 売却時の信頼性を可視化するため、工場確認済み／自己申告／記録簿写真を色とアイコンで
/// 区別し、元画像が添付されていれば 📎 を表示する。
///
/// 履歴タイムライン（compact）と詳細シート（full）の両方で共用する。
class MaintenanceProvenanceBadge extends StatelessWidget {
  final MaintenanceRecordSource source;
  final bool hasEvidence;

  /// 元画像を見るアクション。指定時のみ 📎「証跡」をタップ可能にする（詳細画面向け）。
  final VoidCallback? onViewEvidence;

  const MaintenanceProvenanceBadge({
    super.key,
    required this.source,
    this.hasEvidence = false,
    this.onViewEvidence,
  });

  ({Color color, IconData icon, String label}) get _style {
    switch (source) {
      case MaintenanceRecordSource.shopVerified:
        return (
          color: AppColors.secondary,
          icon: Icons.verified,
          label: '工場確認済み',
        );
      case MaintenanceRecordSource.recordBookPhoto:
        return (
          color: AppColors.info,
          icon: Icons.menu_book_outlined,
          label: '記録簿（写真）',
        );
      case MaintenanceRecordSource.ocrInvoice:
      case MaintenanceRecordSource.ocrCertificate:
        return (
          color: AppColors.textSecondary,
          icon: Icons.document_scanner_outlined,
          label: '自己申告（読み取り）',
        );
      case MaintenanceRecordSource.manual:
        return (
          color: AppColors.textSecondary,
          icon: Icons.edit_outlined,
          label: '自己申告',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _style;
    return Wrap(
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _Pill(color: s.color, icon: s.icon, label: s.label),
        if (hasEvidence)
          _EvidencePill(
            color: AppColors.primary,
            onTap: onViewEvidence,
          ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  const _Pill({required this.color, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EvidencePill extends StatelessWidget {
  final Color color;
  final VoidCallback? onTap;
  const _EvidencePill({required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.attach_file, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            onTap != null ? '証跡を見る' : '証跡あり',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
    if (onTap == null) return pill;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: pill,
    );
  }
}
