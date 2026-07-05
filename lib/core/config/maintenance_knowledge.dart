import '../../models/maintenance_record.dart';

/// Static, human-readable "meaning" for a maintenance type: why it is generally
/// performed, what tends to be said about neglecting it, and how owners can
/// commonly tell it may be due.
///
/// This is the knowledge layer behind the maintenance explanation feature — it
/// lets the app return meaning from the very first record, before any personal
/// history has accumulated.
///
/// Phrasing intentionally avoids assertive/absolute wording ("必ず", "絶対",
/// "危険です", "してください") — the app explains and offers context; it never
/// diagnoses or commands. Safety-critical judgement is deferred to a workshop.
class MaintenanceKnowledge {
  /// Why this maintenance is generally performed (one sentence).
  final String whyNeeded;

  /// What is generally said to happen if it is neglected (soft phrasing).
  final String riskIfSkipped;

  /// How owners can commonly tell it may be due.
  final String howToTell;

  const MaintenanceKnowledge({
    required this.whyNeeded,
    required this.riskIfSkipped,
    required this.howToTell,
  });

  /// Returns the knowledge entry for [type], or null if none is defined
  /// (e.g. cosmetic/custom entries that carry no maintenance meaning).
  static MaintenanceKnowledge? forType(MaintenanceType type) => _byType[type];

  static const _byType = <MaintenanceType, MaintenanceKnowledge>{
    MaintenanceType.oilChange: MaintenanceKnowledge(
      whyNeeded: 'エンジンオイルは金属部品の潤滑と冷却を担う消耗品で、走行と時間の経過とともに少しずつ劣化していきます。',
      riskIfSkipped: '交換が大きく遅れると、燃費の悪化やエンジンの摩耗につながることがあると言われています。',
      howToTell: '走行距離の目安に加えて、オイルの色が濃く黒ずんでいたら交換時期のサインとされます。',
    ),
    MaintenanceType.oilFilterChange: MaintenanceKnowledge(
      whyNeeded: 'オイルフィルターはオイル中の汚れを取り除く部品で、一般にオイル交換2回に1回が目安とされます。',
      riskIfSkipped: '目詰まりが進むと、ろ過性能が落ちてオイルの汚れが早まることがあると言われています。',
      howToTell: 'オイル交換の回数を目安に、フィルターの交換履歴と合わせて判断されます。',
    ),
    MaintenanceType.airFilterChange: MaintenanceKnowledge(
      whyNeeded: 'エアフィルターはエンジンが吸い込む空気からゴミを取り除き、吸気効率と燃費の維持に関わります。',
      riskIfSkipped: '汚れがひどくなると、吸気効率の低下で加速や燃費に影響することがあると言われています。',
      howToTell: '走行距離の目安に加えて、フィルターがほこりで黒く汚れていたら交換の目安とされます。',
    ),
    MaintenanceType.cabinFilterChange: MaintenanceKnowledge(
      whyNeeded: 'エアコンフィルターは車内に入る空気の花粉やほこりを取り除き、空調の効きや車内の空気環境に関わります。',
      riskIfSkipped: '汚れがたまると、風量の低下やにおいの原因になることがあると言われています。',
      howToTell: '風量が弱く感じたり、エアコンからにおいが出てきたら交換の目安とされます。',
    ),
    MaintenanceType.tireRotation: MaintenanceKnowledge(
      whyNeeded: 'タイヤローテーションは前後の位置を入れ替えて摩耗を均等にし、タイヤの寿命を延ばす作業です。',
      riskIfSkipped: '位置を固定したままだと、偏った摩耗が進んで交換時期が早まることがあると言われています。',
      howToTell: '走行距離の目安に加えて、前後で溝の減り方に差が出てきたら実施の目安とされます。',
    ),
    MaintenanceType.tireChange: MaintenanceKnowledge(
      whyNeeded: 'タイヤは路面と接する唯一の部品で、ゴムの劣化と摩耗が進むとグリップや排水性能が落ちていきます。',
      riskIfSkipped: '摩耗や劣化が進んだまま使い続けると、雨天時などの安定性に影響することがあると言われています。',
      howToTell: 'スリップサイン（残り溝1.6mm）の露出や、側面のひび割れが交換の目安とされます。',
    ),
    MaintenanceType.brakePadChange: MaintenanceKnowledge(
      whyNeeded: 'ブレーキパッドは制動時に摩擦で車を止める消耗品で、使うたびに少しずつすり減っていきます。',
      riskIfSkipped: '残量が少ないまま使い続けると、制動力の低下やローターの傷みにつながることがあると言われています。',
      howToTell: '残量が薄くなると警告音が鳴る仕組みが多く、残り3mm以下が交換の目安とされます。',
    ),
    MaintenanceType.brakeFluidChange: MaintenanceKnowledge(
      whyNeeded: 'ブレーキフルードは踏む力を油圧として伝える液体で、湿気を吸って少しずつ性能が変化していきます。',
      riskIfSkipped: '劣化が進むと、高温時のブレーキの効きに影響することがあると言われています。',
      howToTell: '一般に2年ごと、または車検時の交換が目安とされます。',
    ),
    MaintenanceType.batteryChange: MaintenanceKnowledge(
      whyNeeded: 'バッテリーはエンジン始動や電装品に電力を供給する部品で、経年で少しずつ性能が落ちていきます。',
      riskIfSkipped: '弱ったまま使い続けると、寒い朝などにエンジンがかかりにくくなることがあると言われています。',
      howToTell: '一般に3〜5年が交換の目安で、始動時のセルの回りが弱く感じたらサインとされます。',
    ),
    MaintenanceType.coolantChange: MaintenanceKnowledge(
      whyNeeded: '冷却水（LLC）はエンジンの熱を逃がす液体で、防錆・防凍の性能が時間とともに変化していきます。',
      riskIfSkipped: '劣化が進むと、冷却性能の低下や内部のさびにつながることがあると言われています。',
      howToTell: '一般に2年ごと、または車検時の交換が目安とされます。',
    ),
    MaintenanceType.transmissionFluidChange: MaintenanceKnowledge(
      whyNeeded: 'ATF/CVTフルードは変速機の潤滑と動力伝達を担う液体で、走行とともに少しずつ劣化していきます。',
      riskIfSkipped: '大きく劣化すると、変速のスムーズさに影響することがあると言われています。',
      howToTell: 'メーカー指定の周期に沿った交換が目安とされます（無交換指定の車種もあります）。',
    ),
    MaintenanceType.wiperChange: MaintenanceKnowledge(
      whyNeeded: 'ワイパーブレードは雨天時の視界を確保するゴム部品で、紫外線や摩擦で少しずつ硬化していきます。',
      riskIfSkipped: '劣化が進むと、拭き残しやビビリで雨の日の視界に影響することがあると言われています。',
      howToTell: '拭き取りにスジが残る、ゴムが切れているなどが交換の目安とされます。',
    ),
    MaintenanceType.legalInspection12: MaintenanceKnowledge(
      whyNeeded: '12ヶ月点検は道路運送車両法にもとづく法定点検で、日常では気づきにくい箇所を定期的に確認するものです。',
      riskIfSkipped: '受けていなくても車検は通りますが、早期の不具合発見の機会を逃すことがあると言われています。',
      howToTell: '前回の点検からおよそ1年が経過したら実施の目安とされます。',
    ),
    MaintenanceType.legalInspection24: MaintenanceKnowledge(
      whyNeeded: '24ヶ月点検は車検と合わせて行われることが多い法定点検で、幅広い項目を点検するものです。',
      riskIfSkipped: '省略すると、車検時にまとめて整備が必要になり費用がかさむことがあると言われています。',
      howToTell: '車検のタイミングに合わせて実施されるのが一般的です。',
    ),
    MaintenanceType.carInspection: MaintenanceKnowledge(
      whyNeeded: '車検は道路運送車両法で定められた検査で、保安基準への適合を定期的に確認するものです。',
      riskIfSkipped: '有効期間が切れた車で公道を走ることはできず、更新には満了日までの受検が必要です。',
      howToTell: '車検証や車検シールに記載された満了日が期限の目安になります。',
    ),
  };
}
