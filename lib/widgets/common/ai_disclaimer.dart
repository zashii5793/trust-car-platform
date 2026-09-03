import 'package:flutter/material.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';

/// AI が生成した内容に添える注記。
///
/// AI の出力は誤ることがある。整備の要否や費用の見立てを鵜呑みにされると
/// 実害が出るため、**AIの出力を表示する画面には必ずこれを添える**。
///
/// 文言を1か所に集約しているのは、画面ごとに書き分けると必ず抜けが出るため。
/// 表記ゆれも防げる。
class AiDisclaimer extends StatelessWidget {
  /// 何についての注記かを補足する短い語（例: 「整備の提案」）。
  ///
  /// 省略時は汎用の文面になる。
  final String? subject;

  /// 枠や背景を省いて1行のテキストだけにする。
  /// カードの中など、既に囲みがある場所で使う。
  final bool compact;

  const AiDisclaimer({super.key, this.subject, this.compact = false});

  /// 表示する文面。
  ///
  /// 「保証しない」ことと「では何をすればよいか」を必ずセットで書く。
  /// 免責だけを並べても読み手には何の役にも立たない。
  String get message {
    final what = subject == null ? 'この内容' : '$subjectの内容';
    return '$whatはAIが生成した参考情報で、正確性を保証するものではありません。'
        '実際の判断は認証工場など専門家にご確認ください。';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = Text(
      message,
      key: const Key('ai_disclaimer_text'),
      style: theme.textTheme.bodySmall?.copyWith(
        color: AppColors.textSecondary,
      ),
    );

    if (compact) return text;

    return Container(
      key: const Key('ai_disclaimer'),
      padding: const EdgeInsets.all(AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.info.withValues(alpha: 0.08),
        borderRadius: AppSpacing.borderRadiusSm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.auto_awesome, size: 16, color: AppColors.info),
          AppSpacing.horizontalXs,
          Expanded(child: text),
        ],
      ),
    );
  }
}
