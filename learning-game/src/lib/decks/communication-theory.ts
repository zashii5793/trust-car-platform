import type { Deck } from "../types";

export const communicationTheory: Deck = {
  id: "communication-theory",
  title: "コミュニケーション理論",
  subtitle: "誤解と手戻りをなくす5つの技術",
  description:
    "「言わなくても分かるだろう」が最大の罠。仕様確認・社内連携・お客様対応の3場面で、要約・質問・説明・返答・確認の5技術を使い分け、誤解と怠慢からくる手戻りを防ぐ実践技術。",
  category: "communication",
  tier: "free",
  emoji: "💬",
  accentColor: "from-sky-500 to-indigo-500",
  estimatedMinutes: 7,
  priceJpy: 0,
  questions: [
    {
      id: "ct-1",
      format: "multiple_choice",
      prompt: "仕様確認における「7要素」のうち、含まれないものはどれか？",
      choices: [
        "Why（なぜ必要か）",
        "What（具体的機能）",
        "Budget（予算）",
        "境界（やらないこと）",
      ],
      answerIndex: 2,
      explanation:
        "7要素は Why / Who / When / What / How / 例外 / 境界。予算は含まれない。",
    },
    {
      id: "ct-2",
      format: "multiple_choice",
      prompt: "依頼を出す時に必須の3要素のうち、最も忘れられがちなのはどれか？",
      choices: [
        "What（何を）",
        "When（いつまでに）",
        "Definition of Done（完了基準）",
        "Who（誰に）",
      ],
      answerIndex: 2,
      explanation:
        "「どういう状態になれば完了か」が抜けると不要な箇所まで修正され工数が倍増する。",
    },
    {
      id: "ct-3",
      format: "true_false",
      prompt: "仕様7要素のうち、埋まらない項目は空欄のままにしてよい。",
      choices: ["○", "×"],
      answerIndex: 1,
      explanation:
        "埋まらない項目は「未確認」と明記することで、後の認識ズレを防ぐ。",
    },
    {
      id: "ct-4",
      format: "multiple_choice",
      prompt:
        "お客様から「出欠が正しく集計されません」と問い合わせ。最も適切な初動対応は？",
      choices: [
        "すぐにFAQを送信する",
        "即座に開発チームへエスカレ",
        "仮説を選択肢として提示し質問返しする",
        "現地に駆けつける",
      ],
      answerIndex: 2,
      explanation:
        "真意（不具合か運用ルール相違か等）を引き出さずに表面回答すると再炎上する。",
    },
    {
      id: "ct-5",
      format: "multiple_choice",
      prompt: "「決まる会議」のタイムラインで、冒頭 T=00:00 に行うべき行動は？",
      choices: [
        "議事録の確認",
        "ゴールの明確化",
        "ラップアップ",
        "不明点の洗い出し",
      ],
      answerIndex: 1,
      explanation:
        "「今日のゴールは○○を決めることでよろしいですか？」と冒頭で合意を取る。",
    },
    {
      id: "ct-6",
      format: "multiple_choice",
      prompt: "ラップアップで明文化すべき3点はどれか？",
      choices: [
        "誰が／いつまでに／何を",
        "なぜ／どこで／どうやって",
        "予算／人数／場所",
        "メリット／デメリット／リスク",
      ],
      answerIndex: 0,
      explanation:
        "会議最後に「誰が・いつまでに・何を」を明文化することで実行に繋がる。",
    },
    {
      id: "ct-7",
      format: "true_false",
      prompt: "「あれ、なるはやで」は構造化された依頼である。",
      choices: ["○", "×"],
      answerIndex: 1,
      explanation:
        "What / When / DoD が全て曖昧であり、典型的な怠慢な伝達例。",
    },
    {
      id: "ct-8",
      format: "multiple_choice",
      prompt:
        "「成績管理機能を追加してほしい、Excelが大変で」と要望。最初に行うべきことは？",
      choices: [
        "ただちに機能を実装する",
        "Excelのどの作業が大変かを掘り下げる",
        "見積もりを出す",
        "上司に判断を委ねる",
      ],
      answerIndex: 1,
      explanation:
        "真の課題を特定してから仕様化に移行する。代替案がある場合もある。",
    },
    {
      id: "ct-9",
      format: "multiple_choice",
      prompt:
        "応答の3要素「受領確認・認識合わせ・ETA」のうち、認識合わせに該当する発言は？",
      choices: [
        "「承知しました」",
        "「金曜17時にお戻しします」",
        "「〜という理解で合っていますか？」",
        "「了解です」",
      ],
      answerIndex: 2,
      explanation: "認識合わせは依頼内容の解釈を相手と擦り合わせる行為。",
    },
    {
      id: "ct-10",
      format: "true_false",
      prompt: "コミュニケーションの誤解は、主に悪意よりも怠慢から生まれる。",
      choices: ["○", "×"],
      answerIndex: 0,
      explanation:
        "ゲーテの言葉通り、「言わなくても分かる」という省略こそが誤解の温床。",
    },
  ],
};
