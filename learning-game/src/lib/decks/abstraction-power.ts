import type { Deck } from "../types";

export const abstractionPower: Deck = {
  id: "abstraction-power",
  title: "抽象化力を鍛える",
  subtitle: "具体⇄抽象を往復するリーダーの思考術",
  description:
    "抽象化力とは事象から規則性・パターンを捉え本質をつかむ力。具体と抽象を自在に往復する翻訳力があれば、戦略思考と実務遂行を繋げられる。「言ったつもり・聞いたつもり」のズレを防ぐ実践クイズ。",
  category: "thinking",
  tier: "paid",
  emoji: "🧠",
  accentColor: "from-violet-500 to-fuchsia-500",
  estimatedMinutes: 8,
  questions: [
    {
      id: "ap-1",
      format: "multiple_choice",
      prompt: "抽象化の正しい定義はどれか？",
      choices: [
        "曖昧にぼかすこと",
        "事象から規則性やパターンを捉え本質をつかむ力",
        "詳細を省略すること",
        "専門用語を使うこと",
      ],
      answerIndex: 1,
      explanation:
        "抽象化は「広げて本質をつかむ力」であり、曖昧化ではない。",
    },
    {
      id: "ap-2",
      format: "multiple_choice",
      prompt:
        "上司から「もっとお客様が満足する対応をしてほしい」と言われた。ロスを防ぐ最適行動は？",
      choices: [
        "笑顔を増やす",
        "アンケートで評価を確認する",
        "「具体的にどのプロセス改善を指していますか？」と確認する",
        "部下全員で議論する",
      ],
      answerIndex: 2,
      explanation:
        "抽象語「満足」は人により具体像が異なる。具体に翻訳する確認が必須。",
    },
    {
      id: "ap-3",
      format: "multiple_choice",
      prompt: "上位目的を明らかにするためのトレーニング方法として推奨されるのは？",
      choices: [
        "「いつ？」を5回繰り返す",
        "「なぜ？」を5回繰り返す",
        "「どこ？」を5回繰り返す",
        "「いくら？」を5回繰り返す",
      ],
      answerIndex: 1,
      explanation:
        "なぜを繰り返すことで手段から目的、さらに上位目的へと階層を遡れる。",
    },
    {
      id: "ap-4",
      format: "true_false",
      prompt: "抽象的なメッセージは、そのまま伝えても相手は同じイメージを持つ。",
      choices: ["○", "×"],
      answerIndex: 1,
      explanation:
        "抽象は解釈の自由度が高いため、伝えるときは具体に戻す「翻訳力」が必要。",
    },
    {
      id: "ap-5",
      format: "multiple_choice",
      prompt:
        "部下からの「だいたい問題ないです」「お客様も納得してました」という報告の問題点は？",
      choices: [
        "報告が遅い",
        "抽象的すぎて判断材料が不足し次のアクションが決められない",
        "具体的すぎる",
        "文章が長すぎる",
      ],
      answerIndex: 1,
      explanation:
        "「だいたい」「納得」が曖昧。完了項目と残課題を具体化する必要がある。",
    },
    {
      id: "ap-6",
      format: "multiple_choice",
      prompt: "上流工程の特徴として正しいものはどれか？",
      choices: [
        "部分分解と効率性重視",
        "再現性と精度重視",
        "全体理解と理念・方向性重視",
        "明確な答えがある",
      ],
      answerIndex: 2,
      explanation: "上流は抽象（戦略・創造）、下流は具体（効率・再現）。",
    },
    {
      id: "ap-7",
      format: "true_false",
      prompt: "抽象化を過度に進めると、現実と乖離した「空論」になる危険がある。",
      choices: ["○", "×"],
      answerIndex: 0,
      explanation:
        "ランダムな出来事から無理に法則を導くと抽象が独り歩きする。",
    },
    {
      id: "ap-8",
      format: "multiple_choice",
      prompt:
        "「電話は3コール以内に出て『お待たせしました』と必ず言う」を徹底したのに顧客体験が低下。原因は？",
      choices: [
        "具体ルールが少ないから",
        "具体の徹底が目的化し「お客様を大事にする」本質が抜けた",
        "抽象的すぎるから",
        "ルールが古いから",
      ],
      answerIndex: 1,
      explanation:
        "形式を守ることが目的化すると、本来の意図が失われる典型例。",
    },
    {
      id: "ap-9",
      format: "multiple_choice",
      prompt: "「営業」と「教育」に共通する原理はどれか？",
      choices: [
        "数値目標がある",
        "相手の変化を促す行為",
        "上司の指示で動く",
        "報酬が固定",
      ],
      answerIndex: 1,
      explanation:
        "抽象度を上げると、異業種の共通原理が見えてくる典型例。",
    },
    {
      id: "ap-10",
      format: "multiple_choice",
      prompt:
        "「良い職場」を具体と抽象の両面で表すとき、抽象側の表現はどれか？",
      choices: [
        "朝の挨拶が自然に出る",
        "遅刻がない",
        "心理的安全性が確保されている",
        "困った時に声をかける",
      ],
      answerIndex: 2,
      explanation: "心理的安全性は状態を概念化した抽象表現。他は具体行動。",
    },
  ],
};
