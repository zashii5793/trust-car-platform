import type { Deck } from "../types";

export const readingHabit: Deck = {
  id: "reading-habit",
  title: "本を読んで書こう",
  subtitle: "知の資産を積み上げる読書習慣",
  description:
    "読書は「面白い自学習」。書くことで初めて理解と思考が定着する。読みっぱなしではなく自分の言葉でアウトプットする習慣によって、記憶定着・思考力・価値観の明確化・行動への気づきが得られる。",
  category: "growth",
  tier: "free",
  emoji: "📚",
  accentColor: "from-emerald-500 to-teal-500",
  estimatedMinutes: 6,
  priceJpy: 0,
  questions: [
    {
      id: "rh-1",
      format: "multiple_choice",
      prompt: "著者が読書で得られる最大のメリットとしているものはどれか？",
      choices: [
        "知名度の向上",
        "豊富な知的財産を得ること",
        "速読スキル",
        "暗記力の向上",
      ],
      answerIndex: 1,
      explanation:
        "「あらかたの悩みの解決方法は本（先人の知恵）にある」が著者の持論。",
    },
    {
      id: "rh-2",
      format: "multiple_choice",
      prompt: "ショーペンハウアーが警告する「多読の害」とは何か？",
      choices: [
        "目が悪くなる",
        "精神の弾力性を奪い自分で考える力を衰えさせる",
        "お金がかかる",
        "時間を浪費する",
      ],
      answerIndex: 1,
      explanation:
        "「読書とは他人の頭で考えることだ」—深く考え自分なりに解釈することを忘れるなとの教え。",
    },
    {
      id: "rh-3",
      format: "multiple_choice",
      prompt: "著者の読書ルールとして正しくないものはどれか？",
      choices: [
        "ジャンルは何でもOK",
        "合わない本は途中でやめてよい",
        "必ず岩波文庫から読み始める",
        "書くのは箇条書きからでOK",
      ],
      answerIndex: 2,
      explanation:
        "著者は「岩波文庫じゃなきゃダメ」という押し付けを明確に否定している。",
    },
    {
      id: "rh-4",
      format: "true_false",
      prompt: "本の要約サービスを使えば、本を読んだのと同じ効果が得られる。",
      choices: ["○", "×"],
      answerIndex: 1,
      explanation:
        "要約は他人のフィルターを通した情報。刺さるポイントは人それぞれであり、購入前チェックまでが推奨用途。",
    },
    {
      id: "rh-5",
      format: "multiple_choice",
      prompt:
        "学習を自発的にしてこなかった人に現れやすい傾向として、本書が挙げていないものは？",
      choices: [
        "「自分が正しい」という思い込みが強い",
        "同じ失敗をし続ける",
        "他責思考になる",
        "健康診断の数値が悪化する",
      ],
      answerIndex: 3,
      explanation:
        "健康面は本書の論点外。視野狭窄・偏屈・被害者意識などが指摘されている。",
    },
    {
      id: "rh-6",
      format: "multiple_choice",
      prompt: "「書く」ことが思考力に与える効果として最も正しいものは？",
      choices: [
        "タイピングが速くなる",
        "内容の整理・要点抽出・考察のプロセスで思考力が養われる",
        "漢字を覚えられる",
        "文章が長くなる",
      ],
      answerIndex: 1,
      explanation:
        "書くプロセスを繰り返すことで自然と思考力・分析力が鍛えられる。",
    },
    {
      id: "rh-7",
      format: "multiple_choice",
      prompt: "著者は年間どれくらいのペースで読書しブログに上げているか？",
      choices: ["年間20冊", "年間50冊", "年間80冊", "年間200冊"],
      answerIndex: 2,
      explanation:
        "ここ数年は年間80冊読んでブログにアップすることが目標と明記されている。",
    },
    {
      id: "rh-8",
      format: "multiple_choice",
      prompt: "著者の読書記録は累計約何件か？",
      choices: ["約100件", "約500件", "約990件", "約3,000件"],
      answerIndex: 2,
      explanation:
        "20代後半からブログに投稿し続けて990件と明記。",
    },
    {
      id: "rh-9",
      format: "true_false",
      prompt: "読書は修行であり、途中でやめてはいけない。",
      choices: ["○", "×"],
      answerIndex: 1,
      explanation:
        "義務感は読書を苦行に変える。合わない本はやめてOK、数年後に再読すれば良書になることもある。",
    },
    {
      id: "rh-10",
      format: "multiple_choice",
      prompt: "本を読んで「行動に結びつく」ようにするために最も大切な問いは？",
      choices: [
        "「この本いくらだった？」",
        "「じゃあ、自分はどうする？」",
        "「誰が書いた？」",
        "「何ページあった？」",
      ],
      answerIndex: 1,
      explanation:
        "「読んでよかった」で終わらせず、自分の行動に落とすことで知識が活きる。",
    },
  ],
};
