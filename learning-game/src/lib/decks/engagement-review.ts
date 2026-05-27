import type { Deck } from "../types";

export const engagementReview: Deck = {
  id: "engagement-review",
  title: "エンゲージメント振り返り",
  subtitle: "「点」から「線」へ — コンサル支援の磨き込み",
  description:
    "クライアント支援を7視点で自己評価し、「点」の支援から「線」の支援への転換、技術力強化とスタンス磨き込みの二本柱、OKRによる成果可視化を扱う、コンサル／管理職向けの実践的な振り返り術。",
  category: "strategy",
  tier: "paid",
  emoji: "🎯",
  accentColor: "from-amber-500 to-rose-500",
  estimatedMinutes: 8,
  priceJpy: 240,
  questions: [
    {
      id: "er-1",
      format: "multiple_choice",
      prompt: "クライアント支援振り返りで最大の課題とされたのは？",
      choices: [
        "人間関係構築の失敗",
        "成長戦略を読み取り整合性ある課題を特定するのに時間を要した",
        "研修日程の遅延",
        "予算超過",
      ],
      answerIndex: 1,
      explanation:
        "良好な関係構築という成果の一方で、本質的な戦略課題特定に時間を要したと明記。",
    },
    {
      id: "er-2",
      format: "multiple_choice",
      prompt: "振り返りに用いられた7視点に含まれないものはどれか？",
      choices: [
        "成果・インパクト",
        "クライアント理解の深さ",
        "価格設定の妥当性",
        "フィードバックの質",
      ],
      answerIndex: 2,
      explanation:
        "価格は7視点に含まれない。立ち位置・伝え方・巻き込み・研修設計が他の構成要素。",
    },
    {
      id: "er-3",
      format: "multiple_choice",
      prompt: "「点」の支援から「線」の支援への転換とは何を意味するか？",
      choices: [
        "図解を多用する",
        "単発研修から長期的に成長を促す連続プログラムへの転換",
        "講師を1人に集約",
        "オンラインに切替える",
      ],
      answerIndex: 1,
      explanation:
        "断片的だった反省から、継続性と一貫性を担保する設計を提案。",
    },
    {
      id: "er-4",
      format: "multiple_choice",
      prompt: "次期エンゲージメントが集約すべき「二本柱」の正しい組み合わせは？",
      choices: [
        "営業強化と広報強化",
        "技術力強化とスタンス／スキル磨き込み",
        "コスト削減と利益拡大",
        "採用強化と離職防止",
      ],
      answerIndex: 1,
      explanation:
        "全ての課題はこの2軸に集約されると分析されている。",
    },
    {
      id: "er-5",
      format: "multiple_choice",
      prompt: "個別フォロー充実のアプローチとして本資料が挙げていないものは？",
      choices: [
        "定期的な1-on-1セッション",
        "スキルマップに基づく成長計画策定支援",
        "全員一律の集合研修のみ実施",
        "個別の課題に合わせたコーチング",
      ],
      answerIndex: 2,
      explanation:
        "「成長度合いは1人1人異なる」ため、画一的な集合研修だけでは不十分。",
    },
    {
      id: "er-6",
      format: "multiple_choice",
      prompt: "貢献の可視化のためのObjective例として挙げられているのはどれか？",
      choices: [
        "顧客満足度を主観評価で確認",
        "プロダクト開発の生産性を15%向上",
        "研修参加率100%",
        "コスト30%削減",
      ],
      answerIndex: 1,
      explanation:
        "定量的Objectiveに加えKR（導入率80%、バグ修正時間20%短縮等）で明確化。",
    },
    {
      id: "er-7",
      format: "true_false",
      prompt:
        "フィードバックは相手との関係を悪化させないため、核心を避けて伝えるべきである。",
      choices: ["○", "×"],
      answerIndex: 1,
      explanation:
        "「課題の核心を遠慮なく突けたか」が改善点として挙げられており、遠慮は成長機会を奪う。",
    },
    {
      id: "er-8",
      format: "multiple_choice",
      prompt: "目指すべき人材像を明確化するために連携させるべき3要素はどれか？",
      choices: [
        "経営理念・行動指針・評価制度",
        "売上・利益・コスト",
        "採用・配置・退職",
        "商品・価格・流通",
      ],
      answerIndex: 0,
      explanation:
        "スタッフ像を経営理念・行動指針・評価制度と連動させ明確に打ち出す必要がある。",
    },
    {
      id: "er-9",
      format: "multiple_choice",
      prompt: "研修参加者の「主体性」を引き出すために重要な要素はどれか？",
      choices: [
        "一方通行の講義",
        "質問やワークによる双方向性",
        "配布資料の充実",
        "講師の権威性",
      ],
      answerIndex: 1,
      explanation:
        "双方向性が十分だったかが振り返りの改善点として挙がっている。",
    },
    {
      id: "er-10",
      format: "true_false",
      prompt: "定量目標は感想や満足度評価を置き換えるべきものである。",
      choices: ["○", "×"],
      answerIndex: 1,
      explanation:
        "qualitativeな評価「に加え」quantitativeな目標を共同設定すべきと述べられている。両者は補完関係。",
    },
  ],
};
