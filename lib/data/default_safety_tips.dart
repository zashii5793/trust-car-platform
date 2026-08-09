import '../models/safety_tip.dart';

/// アプリに同梱する安全運転情報の初期コンテンツ。
///
/// 安全運転情報は Firestore の `safety_tips` から読むが、シードスクリプトを
/// 実行しない限りコレクションは空で、画面が「何も書かれていない」状態に
/// なっていた。運用作業を前提にすると、その作業が行われるまで全ユーザーに
/// 空画面が見える。編集コンテンツは同梱できるので、**Firestore が空のとき
/// はこの一覧にフォールバックする**（SafetyTipService.getTips 参照）。
///
/// Firestore に1件でも入れば、そちらが優先されてこの一覧は使われない。
/// 内容は scripts/seed_safety_tips.js と同一ソース（公的機関の公開情報に
/// 基づく）。文面を変えるときは両方を更新すること。
final List<SafetyTip> kDefaultSafetyTips = [
  SafetyTip(
    id: 'tip_seatbelt_all_seats',
    title: 'シートベルトは全席着用',
    body: '後部座席のシートベルト着用は法律で義務付けられています。'
        '一般道では反則金はありませんが、高速道路では違反となります。'
        '事故時の致死率は着用時に比べ約5倍（後席）に高まるというデータが'
        'あります。同乗者全員分を確認してから発車しましょう。',
    category: SafetyTipCategory.drivingBasics,
    source: SafetyTipSource.npa,
    sourceUrl: 'https://www.npa.go.jp/bureau/traffic/seatbelt/',
    isActive: true,
    publishedAt: DateTime(2026, 4, 1),
  ),
  SafetyTip(
    id: 'tip_rain_braking_distance',
    title: '雨天時は制動距離が2〜3倍に延びる',
    body: '雨で濡れた路面では、タイヤと路面の摩擦係数が大幅に低下します。'
        '時速60 km/h 走行時の制動距離は乾燥路の約2〜3倍になることが'
        'あります。十分な車間距離の確保と速度を落とした運転を心がけましょう。'
        '特に降り始め直後は路面の油分が浮き出るため危険です。',
    category: SafetyTipCategory.seasonalDriving,
    source: SafetyTipSource.jaf,
    sourceUrl: 'https://jaf.or.jp/common/safety-drive/car-test/index/',
    isActive: true,
    publishedAt: DateTime(2026, 4, 1),
  ),
  SafetyTip(
    id: 'tip_winter_road_driving',
    title: '冬道走行の注意点',
    body: '積雪・凍結路面では急発進・急ブレーキ・急ハンドルを避けることが'
        '重要です。冬用タイヤ（スタッドレス）への早期交換、タイヤチェーンの'
        '携行（指定区間では装着義務）も確認しましょう。ブラックアイスバーン'
        '（見た目が濡れているだけに見える凍結路面）は特に危険です。',
    category: SafetyTipCategory.seasonalDriving,
    source: SafetyTipSource.mlit,
    sourceUrl: 'https://www.mlit.go.jp/road/road/traffic/winter/',
    isActive: true,
    publishedAt: DateTime(2026, 4, 1),
  ),
  SafetyTip(
    id: 'tip_pre_drive_inspection',
    title: '乗車前の日常点検',
    body: 'エンジンオイル・冷却水・ブレーキ液・バッテリー液面、タイヤの'
        '空気圧・亀裂・溝の深さ、灯火類の点灯確認など、乗車前の日常点検は'
        '道路運送車両法で義務付けられています。点検整備記録簿に記録し、'
        '異常を感じたらすぐに整備工場へ相談しましょう。',
    category: SafetyTipCategory.vehicleCheck,
    source: SafetyTipSource.mlit,
    sourceUrl: 'https://www.mlit.go.jp/jidosha/jidosha_fr7_000007.html',
    isActive: true,
    publishedAt: DateTime(2026, 4, 1),
  ),
  SafetyTip(
    id: 'tip_highway_breakdown',
    title: '高速道路で故障・事故が起きたら',
    body: 'ハザードランプを点灯し、路肩に停車したら発炎筒と停止表示器材'
        '（三角表示板）を車の後方に設置します。高速道路上での停止表示器材の'
        '設置は義務です。設置後は車内に留まらず、ガードレールの外など'
        '安全な場所に避難してから、道路緊急ダイヤル（#9910）やJAFに'
        '連絡してください。後続車による二次事故が最も危険です。',
    category: SafetyTipCategory.emergencyResponse,
    source: SafetyTipSource.jaf,
    sourceUrl: 'https://jaf.or.jp/common/safety-drive/library/highway/',
    isActive: true,
    publishedAt: DateTime(2026, 4, 1),
  ),
  SafetyTip(
    id: 'tip_child_in_car_danger',
    title: '子どもの車内放置は危険',
    body: '夏場の密閉された車内温度は、外気温35℃の場合でも60℃を超えることが'
        'あります。子どもの体温調節機能は未発達なため、短時間でも熱中症・'
        '最悪の場合は死亡事故につながります。また、冬場のアイドリング中は'
        '一酸化炭素中毒のリスクもあります。子どもは必ず同伴して降車しましょう。',
    category: SafetyTipCategory.childSafety,
    source: SafetyTipSource.fdma,
    sourceUrl: 'https://www.fdma.go.jp/relocation/neuter/topics/heatstroke/',
    isActive: true,
    publishedAt: DateTime(2026, 4, 1),
  ),
  SafetyTip(
    id: 'tip_elderly_cognitive_check',
    title: '高齢ドライバーの認知機能チェック',
    body: '75歳以上の方は運転免許更新時に認知機能検査（30分程度）が'
        '義務付けられています。また、信号無視・逆走等の違反があった場合は'
        '臨時検査の対象となります。認知症の疑いがある場合は任意での返納・'
        '自主休止も選択肢です。警察庁の「運転免許自主返納サポート制度」を'
        '活用してください。',
    category: SafetyTipCategory.elderlyDriving,
    source: SafetyTipSource.npa,
    sourceUrl: 'https://www.npa.go.jp/bureau/traffic/koutuu/koureisha/',
    isActive: true,
    publishedAt: DateTime(2026, 4, 1),
  ),
];
