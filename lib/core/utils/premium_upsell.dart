import '../config/app_config.dart';

/// B2C のプレミアムプランを売れる状態かどうか。
///
/// **既定は false（凍結）。** 価格が決まっておらず、RevenueCat にも各ストアにも
/// 商品が無い（`docs/PRICING_DECISION_B2C.md`）。この状態で購入ボタンを出すと、
/// 金額を見せないまま購入フローに入ることになる。
///
/// Remote Config の `premium_features` で開ける（`c2c_parts_marketplace` と
/// 同じ扱い）。
bool get canPurchasePremium => isFeatureEnabled(FeatureFlag.premiumFeatures);

/// 「この機能はプレミアム」と伝える文。
///
/// 凍結中に「アップグレードしてください」と書くと、**買えないものを勧める**
/// ことになる。案内文をそこで切り替える。
///
/// [feature] は「PDF出力」「データのエクスポート」のような機能名。
String premiumUpsellMessage(String feature) {
  if (canPurchasePremium) {
    return '$featureはプレミアムプランの機能です。\n'
        'プレミアムプランにアップグレードしてご利用ください。';
  }
  return '$featureはプレミアムプランの機能です。\n'
      'プレミアムプランは現在ご案内を準備中です。開始しましたらアプリ内でお知らせします。';
}
