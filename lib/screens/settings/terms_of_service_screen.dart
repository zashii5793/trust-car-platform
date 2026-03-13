import 'package:flutter/material.dart';
import '../../core/constants/spacing.dart';

/// 利用規約画面
///
/// App Store / Google Play 審査で必須の法的ドキュメント。
class TermsOfServiceScreen extends StatelessWidget {
  const TermsOfServiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('利用規約'),
      ),
      body: SingleChildScrollView(
        padding: AppSpacing.paddingScreen,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '利用規約',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '最終更新日: 2026年4月1日',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 24),

            _TermsSection(
              title: '第1条（適用）',
              content: '本利用規約（以下「本規約」）は、TrustCar（以下「当サービス」）の利用条件を定めるものです。'
                  'ユーザーは本規約に同意のうえ、当サービスをご利用ください。',
            ),

            _TermsSection(
              title: '第2条（利用登録）',
              content: '1. 利用希望者は本規約に同意し、当サービス所定の方法により利用登録を申請します。\n'
                  '2. 当サービスは、利用登録申請者に以下の事由があると判断した場合、登録を拒否できます。\n'
                  '  ・虚偽の情報による申請\n'
                  '  ・本規約に違反したことがある者\n'
                  '  ・その他、当サービスが不適当と判断した場合\n'
                  '3. 1アカウント1人が原則です。複数アカウントの作成は禁止します。',
            ),

            _TermsSection(
              title: '第3条（アカウント管理）',
              content: '1. ユーザーはログイン情報（メールアドレス・パスワード）を自己責任で管理してください。\n'
                  '2. アカウントの第三者への譲渡・貸与・共有は禁止します。\n'
                  '3. 不正利用を発見した場合は速やかに当サービスにご連絡ください。',
            ),

            _TermsSection(
              title: '第4条（禁止事項）',
              content: 'ユーザーは以下の行為をしてはなりません。\n\n'
                  '1. 法令または公序良俗に違反する行為\n'
                  '2. 当サービス・他のユーザー・第三者の権利・利益を侵害する行為\n'
                  '3. 虚偽・誇大・誤解を招く情報の投稿\n'
                  '4. スパム・迷惑行為\n'
                  '5. 他のユーザーへのなりすまし\n'
                  '6. 当サービスのシステムへの不正アクセス・改ざん\n'
                  '7. 商業目的の無断利用（広告・宣伝・勧誘等）\n'
                  '8. その他、当サービスが不適切と判断する行為',
            ),

            _TermsSection(
              title: '第5条（投稿コンテンツ）',
              content: '1. ユーザーが投稿したコンテンツの著作権はユーザーに帰属します。\n'
                  '2. ユーザーは当サービスに対し、コンテンツを無償で利用する権利を許諾します。\n'
                  '3. 以下のコンテンツの投稿は禁止します。\n'
                  '  ・第三者の著作権・肖像権を侵害するもの\n'
                  '  ・個人を特定できる他者の情報（住所・電話番号等）\n'
                  '  ・わいせつ・暴力的・差別的なもの\n'
                  '  ・その他法令に違反するもの\n'
                  '4. 違反コンテンツは予告なく削除する場合があります。',
            ),

            _TermsSection(
              title: '第6条（位置情報の利用）',
              content: '1. ドライブログ機能の利用にはGPS位置情報の取得許可が必要です。\n'
                  '2. 収集した位置情報はドライブログの記録・表示にのみ使用します。\n'
                  '3. 位置情報の利用はデバイス設定から停止できます。\n'
                  '4. 公開設定のドライブログに含まれる位置情報は他のユーザーに公開されます。',
            ),

            _TermsSection(
              title: '第7条（サービスの変更・中断・終了）',
              content: '1. 当サービスは、ユーザーへの事前通知なしにサービス内容を変更・追加・削除できます。\n'
                  '2. システムメンテナンス・障害等によりサービスを一時中断することがあります。\n'
                  '3. サービス終了の際は、30日前にアプリ内またはメールで通知します。',
            ),

            _TermsSection(
              title: '第8条（免責事項）',
              content: '1. 当サービスは、ユーザーの利用により生じた損害について、一切の責任を負いません。\n'
                  '2. 当サービスは、投稿情報の正確性・安全性を保証しません。\n'
                  '3. ユーザー間のトラブルについては当事者間で解決するものとし、当サービスは関与しません。\n'
                  '4. 整備記録・車両情報は参考情報であり、専門家への相談を推奨します。',
            ),

            _TermsSection(
              title: '第9条（退会）',
              content: '1. ユーザーはアプリ内の退会機能からいつでも退会できます。\n'
                  '2. 退会後30日間はデータが保持され、その後削除されます。\n'
                  '3. 退会後のデータ復元はできません。',
            ),

            _TermsSection(
              title: '第10条（利用規約の変更）',
              content: '当サービスは必要に応じて本規約を変更することがあります。'
                  '変更後の規約はアプリ内での通知またはメールにてお知らせします。'
                  '変更後もサービスを継続利用された場合、変更後の規約に同意したものとみなします。',
            ),

            _TermsSection(
              title: '第11条（準拠法・管轄裁判所）',
              content: '1. 本規約は日本法を準拠法とします。\n'
                  '2. 本規約に関する紛争は、東京地方裁判所を第一審の専属的合意管轄裁判所とします。',
            ),

            _TermsSection(
              title: 'お問い合わせ',
              content: 'TrustCar サポートチーム\n'
                  'メールアドレス: support@trustcar.jp',
            ),

            const SizedBox(height: 32),
            Text(
              '© 2026 TrustCar. All rights reserved.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _TermsSection extends StatelessWidget {
  final String title;
  final String content;

  const _TermsSection({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
