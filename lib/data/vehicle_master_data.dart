import '../models/vehicle_master.dart';

/// 車種マスタ（国産全社 + 商用車）。
///
/// Firestore のシードと、オフライン時のフォールバックを兼ねる。
///
/// 2026-08-25 に 9メーカー / 88車種から拡張した。それまでは
/// 商用専業メーカー（いすゞ・日野・UD・三菱ふそう）が1社も無く、
/// `BodyType.truck` / `BodyType.van` の車種が**1件も無かった**。
/// 自分の車が一覧に無い人は、そこで登録をやめる。
///
/// **`productionEndYear` は確かなものだけ入れる。** null は絞り込みで
/// 「現行」扱いになり候補から消えないが、誤った終了年を入れると
/// その年式の車が一覧から消え、**登録できなくなる**。
class VehicleMasterData {
  VehicleMasterData._();

  /// Vehicle makers.
  static const List<Map<String, dynamic>> makers = [
    {
      'id': 'toyota',
      'name': 'トヨタ',
      'nameEn': 'Toyota',
      'country': 'JP',
      'displayOrder': 1,
    },
    {
      'id': 'honda',
      'name': 'ホンダ',
      'nameEn': 'Honda',
      'country': 'JP',
      'displayOrder': 2,
    },
    {
      'id': 'nissan',
      'name': '日産',
      'nameEn': 'Nissan',
      'country': 'JP',
      'displayOrder': 3,
    },
    {
      'id': 'mazda',
      'name': 'マツダ',
      'nameEn': 'Mazda',
      'country': 'JP',
      'displayOrder': 4,
    },
    {
      'id': 'subaru',
      'name': 'スバル',
      'nameEn': 'Subaru',
      'country': 'JP',
      'displayOrder': 5,
    },
    {
      'id': 'suzuki',
      'name': 'スズキ',
      'nameEn': 'Suzuki',
      'country': 'JP',
      'displayOrder': 6,
    },
    {
      'id': 'daihatsu',
      'name': 'ダイハツ',
      'nameEn': 'Daihatsu',
      'country': 'JP',
      'displayOrder': 7,
    },
    {
      'id': 'mitsubishi',
      'name': '三菱',
      'nameEn': 'Mitsubishi',
      'country': 'JP',
      'displayOrder': 8,
    },
    {
      'id': 'lexus',
      'name': 'レクサス',
      'nameEn': 'Lexus',
      'country': 'JP',
      'displayOrder': 9,
    },
    {
      'id': 'mitsuoka',
      'name': '光岡自動車',
      'nameEn': 'Mitsuoka',
      'country': 'JP',
      'displayOrder': 10,
    },
    {
      'id': 'isuzu',
      'name': 'いすゞ',
      'nameEn': 'Isuzu',
      'country': 'JP',
      'displayOrder': 11,
    },
    {
      'id': 'hino',
      'name': '日野',
      'nameEn': 'Hino',
      'country': 'JP',
      'displayOrder': 12,
    },
    {
      'id': 'fuso',
      'name': '三菱ふそう',
      'nameEn': 'Fuso',
      'country': 'JP',
      'displayOrder': 13,
    },
    {
      'id': 'ud',
      'name': 'UDトラックス',
      'nameEn': 'UD Trucks',
      'country': 'JP',
      'displayOrder': 14,
    },
    {
      'id': 'other',
      'name': 'その他',
      'nameEn': 'Other',
      'country': 'JP',
      'displayOrder': 99,
    },
  ];

  /// Models by maker id.
  static const Map<String, List<Map<String, dynamic>>> models = {
    'toyota': [
      {
        'id': 'toyota_prius',
        'name': 'プリウス',
        'nameEn': 'Prius',
        'bodyType': 'hatchback',
        'productionStartYear': 1997,
        'displayOrder': 1
      },
      {
        'id': 'toyota_rav4',
        'name': 'RAV4',
        'nameEn': 'RAV4',
        'bodyType': 'suv',
        'productionStartYear': 1994,
        'displayOrder': 2
      },
      {
        'id': 'toyota_corolla',
        'name': 'カローラ',
        'nameEn': 'Corolla',
        'bodyType': 'sedan',
        'productionStartYear': 1966,
        'displayOrder': 3
      },
      {
        'id': 'toyota_alphard',
        'name': 'アルファード',
        'nameEn': 'Alphard',
        'bodyType': 'minivan',
        'productionStartYear': 2002,
        'displayOrder': 4
      },
      {
        'id': 'toyota_voxy',
        'name': 'ヴォクシー',
        'nameEn': 'Voxy',
        'bodyType': 'minivan',
        'productionStartYear': 2001,
        'displayOrder': 5
      },
      {
        'id': 'toyota_crown',
        'name': 'クラウン',
        'nameEn': 'Crown',
        'bodyType': 'sedan',
        'productionStartYear': 1955,
        'displayOrder': 6
      },
      {
        'id': 'toyota_harrier',
        'name': 'ハリアー',
        'nameEn': 'Harrier',
        'bodyType': 'suv',
        'productionStartYear': 1997,
        'displayOrder': 7
      },
      {
        'id': 'toyota_yaris',
        'name': 'ヤリス',
        'nameEn': 'Yaris',
        'bodyType': 'hatchback',
        'productionStartYear': 2020,
        'displayOrder': 8
      },
      {
        'id': 'toyota_aqua',
        'name': 'アクア',
        'nameEn': 'Aqua',
        'bodyType': 'hatchback',
        'productionStartYear': 2011,
        'displayOrder': 9
      },
      {
        'id': 'toyota_sienta',
        'name': 'シエンタ',
        'nameEn': 'Sienta',
        'bodyType': 'minivan',
        'productionStartYear': 2003,
        'displayOrder': 10
      },
      {
        'id': 'toyota_landcruiser',
        'name': 'ランドクルーザー',
        'nameEn': 'Land Cruiser',
        'bodyType': 'suv',
        'productionStartYear': 1951,
        'displayOrder': 11
      },
      {
        'id': 'toyota_86',
        'name': '86',
        'nameEn': '86',
        'bodyType': 'coupe',
        'productionStartYear': 2012,
        'displayOrder': 12
      },
      {
        'id': 'toyota_supra',
        'name': 'スープラ',
        'nameEn': 'Supra',
        'bodyType': 'coupe',
        'productionStartYear': 1978,
        'displayOrder': 13
      },
      {
        'id': 'toyota_gr86',
        'name': 'GR86',
        'nameEn': 'GR86',
        'bodyType': 'coupe',
        'productionStartYear': 2021,
        'displayOrder': 14
      },
      {
        'id': 'toyota_corolla_touring',
        'name': 'カローラツーリング',
        'nameEn': 'Corolla Touring',
        'bodyType': 'wagon',
        'productionStartYear': 2019,
        'displayOrder': 15
      },
      {
        'id': 'toyota_corolla_sport',
        'name': 'カローラスポーツ',
        'nameEn': 'Corolla Sport',
        'bodyType': 'hatchback',
        'productionStartYear': 2018,
        'displayOrder': 16
      },
      {
        'id': 'toyota_corolla_cross',
        'name': 'カローラクロス',
        'nameEn': 'Corolla Cross',
        'bodyType': 'suv',
        'productionStartYear': 2021,
        'displayOrder': 17
      },
      {
        'id': 'toyota_corolla_fielder',
        'name': 'カローラフィールダー',
        'nameEn': 'Corolla Fielder',
        'bodyType': 'wagon',
        'productionStartYear': 2000,
        'displayOrder': 18
      },
      {
        'id': 'toyota_corolla_axio',
        'name': 'カローラアクシオ',
        'nameEn': 'Corolla Axio',
        'bodyType': 'sedan',
        'productionStartYear': 2006,
        'displayOrder': 19
      },
      {
        'id': 'toyota_yaris_cross',
        'name': 'ヤリスクロス',
        'nameEn': 'Yaris Cross',
        'bodyType': 'suv',
        'productionStartYear': 2020,
        'displayOrder': 20
      },
      {
        'id': 'toyota_chr',
        'name': 'C-HR',
        'nameEn': 'C-HR',
        'bodyType': 'suv',
        'productionStartYear': 2016,
        'displayOrder': 21
      },
      {
        'id': 'toyota_raize',
        'name': 'ライズ',
        'nameEn': 'Raize',
        'bodyType': 'suv',
        'productionStartYear': 2019,
        'displayOrder': 22
      },
      {
        'id': 'toyota_roomy',
        'name': 'ルーミー',
        'nameEn': 'Roomy',
        'bodyType': 'minivan',
        'productionStartYear': 2016,
        'displayOrder': 23
      },
      {
        'id': 'toyota_passo',
        'name': 'パッソ',
        'nameEn': 'Passo',
        'bodyType': 'hatchback',
        'productionStartYear': 2004,
        'displayOrder': 24
      },
      {
        'id': 'toyota_noah',
        'name': 'ノア',
        'nameEn': 'Noah',
        'bodyType': 'minivan',
        'productionStartYear': 2001,
        'displayOrder': 25
      },
      {
        'id': 'toyota_vellfire',
        'name': 'ヴェルファイア',
        'nameEn': 'Vellfire',
        'bodyType': 'minivan',
        'productionStartYear': 2008,
        'displayOrder': 26
      },
      {
        'id': 'toyota_esquire',
        'name': 'エスクァイア',
        'nameEn': 'Esquire',
        'bodyType': 'minivan',
        'productionStartYear': 2014,
        'productionEndYear': 2021,
        'displayOrder': 27
      },
      {
        'id': 'toyota_camry',
        'name': 'カムリ',
        'nameEn': 'Camry',
        'bodyType': 'sedan',
        'productionStartYear': 1980,
        'displayOrder': 28
      },
      {
        'id': 'toyota_century',
        'name': 'センチュリー',
        'nameEn': 'Century',
        'bodyType': 'sedan',
        'productionStartYear': 1967,
        'displayOrder': 29
      },
      {
        'id': 'toyota_mirai',
        'name': 'MIRAI',
        'nameEn': 'Mirai',
        'bodyType': 'sedan',
        'productionStartYear': 2014,
        'displayOrder': 30
      },
      {
        'id': 'toyota_bz4x',
        'name': 'bZ4X',
        'nameEn': 'bZ4X',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 31
      },
      {
        'id': 'toyota_prius_alpha',
        'name': 'プリウスα',
        'nameEn': 'Prius Alpha',
        'bodyType': 'wagon',
        'productionStartYear': 2011,
        'productionEndYear': 2021,
        'displayOrder': 32
      },
      {
        'id': 'toyota_prius_phv',
        'name': 'プリウスPHV',
        'nameEn': 'Prius PHV',
        'bodyType': 'hatchback',
        'productionStartYear': 2012,
        'displayOrder': 33
      },
      {
        'id': 'toyota_estima',
        'name': 'エスティマ',
        'nameEn': 'Estima',
        'bodyType': 'minivan',
        'productionStartYear': 1990,
        'productionEndYear': 2019,
        'displayOrder': 34
      },
      {
        'id': 'toyota_wish',
        'name': 'ウィッシュ',
        'nameEn': 'Wish',
        'bodyType': 'minivan',
        'productionStartYear': 2003,
        'productionEndYear': 2017,
        'displayOrder': 35
      },
      {
        'id': 'toyota_isis',
        'name': 'アイシス',
        'nameEn': 'Isis',
        'bodyType': 'minivan',
        'productionStartYear': 2004,
        'productionEndYear': 2017,
        'displayOrder': 36
      },
      {
        'id': 'toyota_ractis',
        'name': 'ラクティス',
        'nameEn': 'Ractis',
        'bodyType': 'hatchback',
        'productionStartYear': 2005,
        'productionEndYear': 2016,
        'displayOrder': 37
      },
      {
        'id': 'toyota_vitz',
        'name': 'ヴィッツ',
        'nameEn': 'Vitz',
        'bodyType': 'hatchback',
        'productionStartYear': 1999,
        'productionEndYear': 2020,
        'displayOrder': 38
      },
      {
        'id': 'toyota_auris',
        'name': 'オーリス',
        'nameEn': 'Auris',
        'bodyType': 'hatchback',
        'productionStartYear': 2006,
        'productionEndYear': 2018,
        'displayOrder': 39
      },
      {
        'id': 'toyota_ist',
        'name': 'ist',
        'nameEn': 'ist',
        'bodyType': 'hatchback',
        'productionStartYear': 2002,
        'productionEndYear': 2016,
        'displayOrder': 40
      },
      {
        'id': 'toyota_porte',
        'name': 'ポルテ',
        'nameEn': 'Porte',
        'bodyType': 'minivan',
        'productionStartYear': 2004,
        'productionEndYear': 2020,
        'displayOrder': 41
      },
      {
        'id': 'toyota_spade',
        'name': 'スペイド',
        'nameEn': 'Spade',
        'bodyType': 'minivan',
        'productionStartYear': 2012,
        'productionEndYear': 2020,
        'displayOrder': 42
      },
      {
        'id': 'toyota_premio',
        'name': 'プレミオ',
        'nameEn': 'Premio',
        'bodyType': 'sedan',
        'productionStartYear': 2001,
        'productionEndYear': 2021,
        'displayOrder': 43
      },
      {
        'id': 'toyota_allion',
        'name': 'アリオン',
        'nameEn': 'Allion',
        'bodyType': 'sedan',
        'productionStartYear': 2001,
        'productionEndYear': 2021,
        'displayOrder': 44
      },
      {
        'id': 'toyota_markx',
        'name': 'マークX',
        'nameEn': 'Mark X',
        'bodyType': 'sedan',
        'productionStartYear': 2004,
        'productionEndYear': 2019,
        'displayOrder': 45
      },
      {
        'id': 'toyota_mark2',
        'name': 'マークII',
        'nameEn': 'Mark II',
        'bodyType': 'sedan',
        'productionStartYear': 1968,
        'productionEndYear': 2004,
        'displayOrder': 46
      },
      {
        'id': 'toyota_chaser',
        'name': 'チェイサー',
        'nameEn': 'Chaser',
        'bodyType': 'sedan',
        'productionStartYear': 1977,
        'productionEndYear': 2001,
        'displayOrder': 47
      },
      {
        'id': 'toyota_cresta',
        'name': 'クレスタ',
        'nameEn': 'Cresta',
        'bodyType': 'sedan',
        'productionStartYear': 1980,
        'productionEndYear': 2001,
        'displayOrder': 48
      },
      {
        'id': 'toyota_soarer',
        'name': 'ソアラ',
        'nameEn': 'Soarer',
        'bodyType': 'coupe',
        'productionStartYear': 1981,
        'productionEndYear': 2005,
        'displayOrder': 49
      },
      {
        'id': 'toyota_celica',
        'name': 'セリカ',
        'nameEn': 'Celica',
        'bodyType': 'coupe',
        'productionStartYear': 1970,
        'productionEndYear': 2006,
        'displayOrder': 50
      },
      {
        'id': 'toyota_mr2',
        'name': 'MR2',
        'nameEn': 'MR2',
        'bodyType': 'coupe',
        'productionStartYear': 1984,
        'productionEndYear': 1999,
        'displayOrder': 51
      },
      {
        'id': 'toyota_mrs',
        'name': 'MR-S',
        'nameEn': 'MR-S',
        'bodyType': 'convertible',
        'productionStartYear': 1999,
        'productionEndYear': 2007,
        'displayOrder': 52
      },
      {
        'id': 'toyota_sai',
        'name': 'SAI',
        'nameEn': 'SAI',
        'bodyType': 'sedan',
        'productionStartYear': 2009,
        'productionEndYear': 2017,
        'displayOrder': 53
      },
      {
        'id': 'toyota_blade',
        'name': 'ブレイド',
        'nameEn': 'Blade',
        'bodyType': 'hatchback',
        'productionStartYear': 2006,
        'productionEndYear': 2012,
        'displayOrder': 54
      },
      {
        'id': 'toyota_vanguard',
        'name': 'ヴァンガード',
        'nameEn': 'Vanguard',
        'bodyType': 'suv',
        'productionStartYear': 2007,
        'productionEndYear': 2013,
        'displayOrder': 55
      },
      {
        'id': 'toyota_kluger',
        'name': 'クルーガー',
        'nameEn': 'Kluger',
        'bodyType': 'suv',
        'productionStartYear': 2000,
        'productionEndYear': 2007,
        'displayOrder': 56
      },
      {
        'id': 'toyota_prado',
        'name': 'ランドクルーザープラド',
        'nameEn': 'Land Cruiser Prado',
        'bodyType': 'suv',
        'productionStartYear': 1990,
        'displayOrder': 57
      },
      {
        'id': 'toyota_fjcruiser',
        'name': 'FJクルーザー',
        'nameEn': 'FJ Cruiser',
        'bodyType': 'suv',
        'productionStartYear': 2006,
        'productionEndYear': 2018,
        'displayOrder': 58
      },
      {
        'id': 'toyota_hilux',
        'name': 'ハイラックス',
        'nameEn': 'Hilux',
        'bodyType': 'truck',
        'productionStartYear': 1968,
        'displayOrder': 59
      },
      {
        'id': 'toyota_hilux_surf',
        'name': 'ハイラックスサーフ',
        'nameEn': 'Hilux Surf',
        'bodyType': 'suv',
        'productionStartYear': 1983,
        'productionEndYear': 2009,
        'displayOrder': 60
      },
      {
        'id': 'toyota_hiace',
        'name': 'ハイエース',
        'nameEn': 'HiAce',
        'bodyType': 'van',
        'productionStartYear': 1967,
        'displayOrder': 61
      },
      {
        'id': 'toyota_regiusace',
        'name': 'レジアスエース',
        'nameEn': 'RegiusAce',
        'bodyType': 'van',
        'productionStartYear': 1999,
        'productionEndYear': 2020,
        'displayOrder': 62
      },
      {
        'id': 'toyota_townace',
        'name': 'タウンエース',
        'nameEn': 'TownAce',
        'bodyType': 'van',
        'productionStartYear': 1976,
        'displayOrder': 63
      },
      {
        'id': 'toyota_liteace',
        'name': 'ライトエース',
        'nameEn': 'LiteAce',
        'bodyType': 'van',
        'productionStartYear': 1970,
        'displayOrder': 64
      },
      {
        'id': 'toyota_probox',
        'name': 'プロボックス',
        'nameEn': 'Probox',
        'bodyType': 'van',
        'productionStartYear': 2002,
        'displayOrder': 65
      },
      {
        'id': 'toyota_succeed',
        'name': 'サクシード',
        'nameEn': 'Succeed',
        'bodyType': 'van',
        'productionStartYear': 2002,
        'productionEndYear': 2020,
        'displayOrder': 66
      },
      {
        'id': 'toyota_granace',
        'name': 'グランエース',
        'nameEn': 'GranAce',
        'bodyType': 'van',
        'productionStartYear': 2019,
        'displayOrder': 67
      },
      {
        'id': 'toyota_dyna',
        'name': 'ダイナ',
        'nameEn': 'Dyna',
        'bodyType': 'truck',
        'productionStartYear': 1959,
        'displayOrder': 68
      },
      {
        'id': 'toyota_toyoace',
        'name': 'トヨエース',
        'nameEn': 'ToyoAce',
        'bodyType': 'truck',
        'productionStartYear': 1954,
        'displayOrder': 69
      },
      {
        'id': 'toyota_coaster',
        'name': 'コースター',
        'nameEn': 'Coaster',
        'bodyType': 'other',
        'productionStartYear': 1969,
        'displayOrder': 70
      },
      {
        'id': 'toyota_japantaxi',
        'name': 'JPN TAXI',
        'nameEn': 'JPN Taxi',
        'bodyType': 'other',
        'productionStartYear': 2017,
        'displayOrder': 71
      },
      {
        'id': 'toyota_comfort',
        'name': 'コンフォート',
        'nameEn': 'Comfort',
        'bodyType': 'sedan',
        'productionStartYear': 1995,
        'productionEndYear': 2018,
        'displayOrder': 72
      },
      {
        'id': 'toyota_starlet',
        'name': 'スターレット',
        'nameEn': 'Starlet',
        'bodyType': 'hatchback',
        'productionStartYear': 1973,
        'productionEndYear': 1999,
        'displayOrder': 73
      },
      {
        'id': 'toyota_tercel',
        'name': 'ターセル',
        'nameEn': 'Tercel',
        'bodyType': 'sedan',
        'productionStartYear': 1978,
        'productionEndYear': 1999,
        'displayOrder': 74
      },
      {
        'id': 'toyota_caldina',
        'name': 'カルディナ',
        'nameEn': 'Caldina',
        'bodyType': 'wagon',
        'productionStartYear': 1992,
        'productionEndYear': 2007,
        'displayOrder': 75
      },
      {
        'id': 'toyota_nadia',
        'name': 'ナディア',
        'nameEn': 'Nadia',
        'bodyType': 'minivan',
        'productionStartYear': 1998,
        'productionEndYear': 2003,
        'displayOrder': 76
      },
      {
        'id': 'toyota_opa',
        'name': 'オーパ',
        'nameEn': 'Opa',
        'bodyType': 'hatchback',
        'productionStartYear': 2000,
        'productionEndYear': 2005,
        'displayOrder': 77
      },
      {
        'id': 'toyota_bb',
        'name': 'bB',
        'nameEn': 'bB',
        'bodyType': 'minivan',
        'productionStartYear': 2000,
        'productionEndYear': 2016,
        'displayOrder': 78
      },
      {
        'id': 'toyota_rush',
        'name': 'ラッシュ',
        'nameEn': 'Rush',
        'bodyType': 'suv',
        'productionStartYear': 2006,
        'productionEndYear': 2016,
        'displayOrder': 79
      },
      {
        'id': 'toyota_crown_estate',
        'name': 'クラウンエステート',
        'nameEn': 'Crown Estate',
        'bodyType': 'wagon',
        'productionStartYear': 1999,
        'displayOrder': 80
      },
      {
        'id': 'toyota_crown_sport',
        'name': 'クラウンスポーツ',
        'nameEn': 'Crown Sport',
        'bodyType': 'suv',
        'productionStartYear': 2023,
        'displayOrder': 81
      },
      {
        'id': 'toyota_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'honda': [
      {
        'id': 'honda_fit',
        'name': 'フィット',
        'nameEn': 'Fit',
        'bodyType': 'hatchback',
        'productionStartYear': 2001,
        'displayOrder': 1
      },
      {
        'id': 'honda_vezel',
        'name': 'ヴェゼル',
        'nameEn': 'Vezel',
        'bodyType': 'suv',
        'productionStartYear': 2013,
        'displayOrder': 2
      },
      {
        'id': 'honda_freed',
        'name': 'フリード',
        'nameEn': 'Freed',
        'bodyType': 'minivan',
        'productionStartYear': 2008,
        'displayOrder': 3
      },
      {
        'id': 'honda_stepwgn',
        'name': 'ステップワゴン',
        'nameEn': 'StepWGN',
        'bodyType': 'minivan',
        'productionStartYear': 1996,
        'displayOrder': 4
      },
      {
        'id': 'honda_nbox',
        'name': 'N-BOX',
        'nameEn': 'N-BOX',
        'bodyType': 'kei',
        'productionStartYear': 2011,
        'displayOrder': 5
      },
      {
        'id': 'honda_accord',
        'name': 'アコード',
        'nameEn': 'Accord',
        'bodyType': 'sedan',
        'productionStartYear': 1976,
        'displayOrder': 6
      },
      {
        'id': 'honda_civic',
        'name': 'シビック',
        'nameEn': 'Civic',
        'bodyType': 'hatchback',
        'productionStartYear': 1972,
        'displayOrder': 7
      },
      {
        'id': 'honda_crv',
        'name': 'CR-V',
        'nameEn': 'CR-V',
        'bodyType': 'suv',
        'productionStartYear': 1995,
        'displayOrder': 8
      },
      {
        'id': 'honda_odyssey',
        'name': 'オデッセイ',
        'nameEn': 'Odyssey',
        'bodyType': 'minivan',
        'productionStartYear': 1994,
        'displayOrder': 9
      },
      {
        'id': 'honda_nwgn',
        'name': 'N-WGN',
        'nameEn': 'N-WGN',
        'bodyType': 'kei',
        'productionStartYear': 2013,
        'displayOrder': 10
      },
      {
        'id': 'honda_none',
        'name': 'N-ONE',
        'nameEn': 'N-ONE',
        'bodyType': 'kei',
        'productionStartYear': 2012,
        'displayOrder': 11
      },
      {
        'id': 'honda_nvan',
        'name': 'N-VAN',
        'nameEn': 'N-VAN',
        'bodyType': 'van',
        'productionStartYear': 2018,
        'displayOrder': 12
      },
      {
        'id': 'honda_shuttle',
        'name': 'シャトル',
        'nameEn': 'Shuttle',
        'bodyType': 'wagon',
        'productionStartYear': 2015,
        'productionEndYear': 2022,
        'displayOrder': 13
      },
      {
        'id': 'honda_grace',
        'name': 'グレイス',
        'nameEn': 'Grace',
        'bodyType': 'sedan',
        'productionStartYear': 2014,
        'productionEndYear': 2020,
        'displayOrder': 14
      },
      {
        'id': 'honda_insight',
        'name': 'インサイト',
        'nameEn': 'Insight',
        'bodyType': 'sedan',
        'productionStartYear': 1999,
        'productionEndYear': 2022,
        'displayOrder': 15
      },
      {
        'id': 'honda_legend',
        'name': 'レジェンド',
        'nameEn': 'Legend',
        'bodyType': 'sedan',
        'productionStartYear': 1985,
        'productionEndYear': 2022,
        'displayOrder': 16
      },
      {
        'id': 'honda_zrv',
        'name': 'ZR-V',
        'nameEn': 'ZR-V',
        'bodyType': 'suv',
        'productionStartYear': 2023,
        'displayOrder': 17
      },
      {
        'id': 'honda_wrv',
        'name': 'WR-V',
        'nameEn': 'WR-V',
        'bodyType': 'suv',
        'productionStartYear': 2024,
        'displayOrder': 18
      },
      {
        'id': 'honda_s660',
        'name': 'S660',
        'nameEn': 'S660',
        'bodyType': 'kei',
        'productionStartYear': 2015,
        'productionEndYear': 2022,
        'displayOrder': 19
      },
      {
        'id': 'honda_s2000',
        'name': 'S2000',
        'nameEn': 'S2000',
        'bodyType': 'convertible',
        'productionStartYear': 1999,
        'productionEndYear': 2009,
        'displayOrder': 20
      },
      {
        'id': 'honda_nsx',
        'name': 'NSX',
        'nameEn': 'NSX',
        'bodyType': 'coupe',
        'productionStartYear': 1990,
        'productionEndYear': 2022,
        'displayOrder': 21
      },
      {
        'id': 'honda_crz',
        'name': 'CR-Z',
        'nameEn': 'CR-Z',
        'bodyType': 'coupe',
        'productionStartYear': 2010,
        'productionEndYear': 2016,
        'displayOrder': 22
      },
      {
        'id': 'honda_jade',
        'name': 'ジェイド',
        'nameEn': 'Jade',
        'bodyType': 'minivan',
        'productionStartYear': 2015,
        'productionEndYear': 2020,
        'displayOrder': 23
      },
      {
        'id': 'honda_elysion',
        'name': 'エリシオン',
        'nameEn': 'Elysion',
        'bodyType': 'minivan',
        'productionStartYear': 2004,
        'productionEndYear': 2013,
        'displayOrder': 24
      },
      {
        'id': 'honda_mobilio',
        'name': 'モビリオ',
        'nameEn': 'Mobilio',
        'bodyType': 'minivan',
        'productionStartYear': 2001,
        'productionEndYear': 2008,
        'displayOrder': 25
      },
      {
        'id': 'honda_stream',
        'name': 'ストリーム',
        'nameEn': 'Stream',
        'bodyType': 'minivan',
        'productionStartYear': 2000,
        'productionEndYear': 2014,
        'displayOrder': 26
      },
      {
        'id': 'honda_airwave',
        'name': 'エアウェイブ',
        'nameEn': 'Airwave',
        'bodyType': 'wagon',
        'productionStartYear': 2005,
        'productionEndYear': 2010,
        'displayOrder': 27
      },
      {
        'id': 'honda_capa',
        'name': 'キャパ',
        'nameEn': 'Capa',
        'bodyType': 'hatchback',
        'productionStartYear': 1998,
        'productionEndYear': 2002,
        'displayOrder': 28
      },
      {
        'id': 'honda_logo',
        'name': 'ロゴ',
        'nameEn': 'Logo',
        'bodyType': 'hatchback',
        'productionStartYear': 1996,
        'productionEndYear': 2001,
        'displayOrder': 29
      },
      {
        'id': 'honda_life',
        'name': 'ライフ',
        'nameEn': 'Life',
        'bodyType': 'kei',
        'productionStartYear': 1971,
        'productionEndYear': 2014,
        'displayOrder': 30
      },
      {
        'id': 'honda_zest',
        'name': 'ゼスト',
        'nameEn': 'Zest',
        'bodyType': 'kei',
        'productionStartYear': 2006,
        'productionEndYear': 2012,
        'displayOrder': 31
      },
      {
        'id': 'honda_that',
        'name': 'ザッツ',
        'nameEn': 'That\'s',
        'bodyType': 'kei',
        'productionStartYear': 2002,
        'productionEndYear': 2007,
        'displayOrder': 32
      },
      {
        'id': 'honda_vamos',
        'name': 'バモス',
        'nameEn': 'Vamos',
        'bodyType': 'van',
        'productionStartYear': 1999,
        'productionEndYear': 2018,
        'displayOrder': 33
      },
      {
        'id': 'honda_acty_truck',
        'name': 'アクティトラック',
        'nameEn': 'Acty Truck',
        'bodyType': 'truck',
        'productionStartYear': 1977,
        'productionEndYear': 2021,
        'displayOrder': 34
      },
      {
        'id': 'honda_acty_van',
        'name': 'アクティバン',
        'nameEn': 'Acty Van',
        'bodyType': 'van',
        'productionStartYear': 1979,
        'productionEndYear': 2018,
        'displayOrder': 35
      },
      {
        'id': 'honda_beat',
        'name': 'ビート',
        'nameEn': 'Beat',
        'bodyType': 'kei',
        'productionStartYear': 1991,
        'productionEndYear': 1996,
        'displayOrder': 36
      },
      {
        'id': 'honda_integra',
        'name': 'インテグラ',
        'nameEn': 'Integra',
        'bodyType': 'coupe',
        'productionStartYear': 1985,
        'productionEndYear': 2006,
        'displayOrder': 37
      },
      {
        'id': 'honda_prelude',
        'name': 'プレリュード',
        'nameEn': 'Prelude',
        'bodyType': 'coupe',
        'productionStartYear': 1978,
        'productionEndYear': 2001,
        'displayOrder': 38
      },
      {
        'id': 'honda_torneo',
        'name': 'トルネオ',
        'nameEn': 'Torneo',
        'bodyType': 'sedan',
        'productionStartYear': 1997,
        'productionEndYear': 2002,
        'displayOrder': 39
      },
      {
        'id': 'honda_inspire',
        'name': 'インスパイア',
        'nameEn': 'Inspire',
        'bodyType': 'sedan',
        'productionStartYear': 1989,
        'productionEndYear': 2012,
        'displayOrder': 40
      },
      {
        'id': 'honda_avancier',
        'name': 'アヴァンシア',
        'nameEn': 'Avancier',
        'bodyType': 'wagon',
        'productionStartYear': 1999,
        'productionEndYear': 2003,
        'displayOrder': 41
      },
      {
        'id': 'honda_hrv',
        'name': 'HR-V',
        'nameEn': 'HR-V',
        'bodyType': 'suv',
        'productionStartYear': 1998,
        'productionEndYear': 2006,
        'displayOrder': 42
      },
      {
        'id': 'honda_crossroad',
        'name': 'クロスロード',
        'nameEn': 'Crossroad',
        'bodyType': 'suv',
        'productionStartYear': 2007,
        'productionEndYear': 2010,
        'displayOrder': 43
      },
      {
        'id': 'honda_edix',
        'name': 'エディックス',
        'nameEn': 'Edix',
        'bodyType': 'minivan',
        'productionStartYear': 2004,
        'productionEndYear': 2009,
        'displayOrder': 44
      },
      {
        'id': 'honda_fitshuttle',
        'name': 'フィットシャトル',
        'nameEn': 'Fit Shuttle',
        'bodyType': 'wagon',
        'productionStartYear': 2011,
        'productionEndYear': 2015,
        'displayOrder': 45
      },
      {
        'id': 'honda_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'nissan': [
      {
        'id': 'nissan_note',
        'name': 'ノート',
        'nameEn': 'Note',
        'bodyType': 'hatchback',
        'productionStartYear': 2004,
        'displayOrder': 1
      },
      {
        'id': 'nissan_serena',
        'name': 'セレナ',
        'nameEn': 'Serena',
        'bodyType': 'minivan',
        'productionStartYear': 1991,
        'displayOrder': 2
      },
      {
        'id': 'nissan_xtrail',
        'name': 'エクストレイル',
        'nameEn': 'X-Trail',
        'bodyType': 'suv',
        'productionStartYear': 2000,
        'displayOrder': 3
      },
      {
        'id': 'nissan_leaf',
        'name': 'リーフ',
        'nameEn': 'Leaf',
        'bodyType': 'hatchback',
        'productionStartYear': 2010,
        'displayOrder': 4
      },
      {
        'id': 'nissan_kicks',
        'name': 'キックス',
        'nameEn': 'Kicks',
        'bodyType': 'suv',
        'productionStartYear': 2020,
        'displayOrder': 5
      },
      {
        'id': 'nissan_skyline',
        'name': 'スカイライン',
        'nameEn': 'Skyline',
        'bodyType': 'sedan',
        'productionStartYear': 1957,
        'displayOrder': 6
      },
      {
        'id': 'nissan_fairladyz',
        'name': 'フェアレディZ',
        'nameEn': 'Fairlady Z',
        'bodyType': 'coupe',
        'productionStartYear': 1969,
        'displayOrder': 7
      },
      {
        'id': 'nissan_gtr',
        'name': 'GT-R',
        'nameEn': 'GT-R',
        'bodyType': 'coupe',
        'productionStartYear': 2007,
        'displayOrder': 8
      },
      {
        'id': 'nissan_aura',
        'name': 'ノート オーラ',
        'nameEn': 'Note Aura',
        'bodyType': 'hatchback',
        'productionStartYear': 2021,
        'displayOrder': 9
      },
      {
        'id': 'nissan_ariya',
        'name': 'アリア',
        'nameEn': 'Ariya',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 10
      },
      {
        'id': 'nissan_sakura',
        'name': 'サクラ',
        'nameEn': 'Sakura',
        'bodyType': 'kei',
        'productionStartYear': 2022,
        'displayOrder': 11
      },
      {
        'id': 'nissan_dayz',
        'name': 'デイズ',
        'nameEn': 'Dayz',
        'bodyType': 'kei',
        'productionStartYear': 2013,
        'displayOrder': 12
      },
      {
        'id': 'nissan_dayz_roox',
        'name': 'デイズルークス',
        'nameEn': 'Dayz Roox',
        'bodyType': 'kei',
        'productionStartYear': 2014,
        'productionEndYear': 2020,
        'displayOrder': 13
      },
      {
        'id': 'nissan_roox',
        'name': 'ルークス',
        'nameEn': 'Roox',
        'bodyType': 'kei',
        'productionStartYear': 2020,
        'displayOrder': 14
      },
      {
        'id': 'nissan_juke',
        'name': 'ジューク',
        'nameEn': 'Juke',
        'bodyType': 'suv',
        'productionStartYear': 2010,
        'productionEndYear': 2020,
        'displayOrder': 15
      },
      {
        'id': 'nissan_march',
        'name': 'マーチ',
        'nameEn': 'March',
        'bodyType': 'hatchback',
        'productionStartYear': 1982,
        'productionEndYear': 2022,
        'displayOrder': 16
      },
      {
        'id': 'nissan_cube',
        'name': 'キューブ',
        'nameEn': 'Cube',
        'bodyType': 'hatchback',
        'productionStartYear': 1998,
        'productionEndYear': 2020,
        'displayOrder': 17
      },
      {
        'id': 'nissan_tiida',
        'name': 'ティーダ',
        'nameEn': 'Tiida',
        'bodyType': 'hatchback',
        'productionStartYear': 2004,
        'productionEndYear': 2012,
        'displayOrder': 18
      },
      {
        'id': 'nissan_lafesta',
        'name': 'ラフェスタ',
        'nameEn': 'Lafesta',
        'bodyType': 'minivan',
        'productionStartYear': 2004,
        'productionEndYear': 2018,
        'displayOrder': 19
      },
      {
        'id': 'nissan_wingroad',
        'name': 'ウイングロード',
        'nameEn': 'Wingroad',
        'bodyType': 'wagon',
        'productionStartYear': 1996,
        'productionEndYear': 2018,
        'displayOrder': 20
      },
      {
        'id': 'nissan_elgrand',
        'name': 'エルグランド',
        'nameEn': 'Elgrand',
        'bodyType': 'minivan',
        'productionStartYear': 1997,
        'displayOrder': 21
      },
      {
        'id': 'nissan_stagea',
        'name': 'ステージア',
        'nameEn': 'Stagea',
        'bodyType': 'wagon',
        'productionStartYear': 1996,
        'productionEndYear': 2007,
        'displayOrder': 22
      },
      {
        'id': 'nissan_teana',
        'name': 'ティアナ',
        'nameEn': 'Teana',
        'bodyType': 'sedan',
        'productionStartYear': 2003,
        'productionEndYear': 2020,
        'displayOrder': 23
      },
      {
        'id': 'nissan_sylphy',
        'name': 'シルフィ',
        'nameEn': 'Sylphy',
        'bodyType': 'sedan',
        'productionStartYear': 2000,
        'productionEndYear': 2020,
        'displayOrder': 24
      },
      {
        'id': 'nissan_bluebird',
        'name': 'ブルーバード',
        'nameEn': 'Bluebird',
        'bodyType': 'sedan',
        'productionStartYear': 1959,
        'productionEndYear': 2001,
        'displayOrder': 25
      },
      {
        'id': 'nissan_fuga',
        'name': 'フーガ',
        'nameEn': 'Fuga',
        'bodyType': 'sedan',
        'productionStartYear': 2004,
        'productionEndYear': 2022,
        'displayOrder': 26
      },
      {
        'id': 'nissan_cima',
        'name': 'シーマ',
        'nameEn': 'Cima',
        'bodyType': 'sedan',
        'productionStartYear': 1988,
        'productionEndYear': 2022,
        'displayOrder': 27
      },
      {
        'id': 'nissan_president',
        'name': 'プレジデント',
        'nameEn': 'President',
        'bodyType': 'sedan',
        'productionStartYear': 1965,
        'productionEndYear': 2010,
        'displayOrder': 28
      },
      {
        'id': 'nissan_laurel',
        'name': 'ローレル',
        'nameEn': 'Laurel',
        'bodyType': 'sedan',
        'productionStartYear': 1968,
        'productionEndYear': 2002,
        'displayOrder': 29
      },
      {
        'id': 'nissan_cedric',
        'name': 'セドリック',
        'nameEn': 'Cedric',
        'bodyType': 'sedan',
        'productionStartYear': 1960,
        'productionEndYear': 2004,
        'displayOrder': 30
      },
      {
        'id': 'nissan_gloria',
        'name': 'グロリア',
        'nameEn': 'Gloria',
        'bodyType': 'sedan',
        'productionStartYear': 1959,
        'productionEndYear': 2004,
        'displayOrder': 31
      },
      {
        'id': 'nissan_silvia',
        'name': 'シルビア',
        'nameEn': 'Silvia',
        'bodyType': 'coupe',
        'productionStartYear': 1965,
        'productionEndYear': 2002,
        'displayOrder': 32
      },
      {
        'id': 'nissan_180sx',
        'name': '180SX',
        'nameEn': '180SX',
        'bodyType': 'coupe',
        'productionStartYear': 1989,
        'productionEndYear': 1998,
        'displayOrder': 33
      },
      {
        'id': 'nissan_pulsar',
        'name': 'パルサー',
        'nameEn': 'Pulsar',
        'bodyType': 'hatchback',
        'productionStartYear': 1978,
        'productionEndYear': 2000,
        'displayOrder': 34
      },
      {
        'id': 'nissan_sunny',
        'name': 'サニー',
        'nameEn': 'Sunny',
        'bodyType': 'sedan',
        'productionStartYear': 1966,
        'productionEndYear': 2004,
        'displayOrder': 35
      },
      {
        'id': 'nissan_primera',
        'name': 'プリメーラ',
        'nameEn': 'Primera',
        'bodyType': 'sedan',
        'productionStartYear': 1990,
        'productionEndYear': 2005,
        'displayOrder': 36
      },
      {
        'id': 'nissan_murano',
        'name': 'ムラーノ',
        'nameEn': 'Murano',
        'bodyType': 'suv',
        'productionStartYear': 2002,
        'productionEndYear': 2015,
        'displayOrder': 37
      },
      {
        'id': 'nissan_dualis',
        'name': 'デュアリス',
        'nameEn': 'Dualis',
        'bodyType': 'suv',
        'productionStartYear': 2007,
        'productionEndYear': 2014,
        'displayOrder': 38
      },
      {
        'id': 'nissan_terrano',
        'name': 'テラノ',
        'nameEn': 'Terrano',
        'bodyType': 'suv',
        'productionStartYear': 1986,
        'productionEndYear': 2002,
        'displayOrder': 39
      },
      {
        'id': 'nissan_safari',
        'name': 'サファリ',
        'nameEn': 'Safari',
        'bodyType': 'suv',
        'productionStartYear': 1980,
        'productionEndYear': 2007,
        'displayOrder': 40
      },
      {
        'id': 'nissan_caravan',
        'name': 'キャラバン',
        'nameEn': 'Caravan',
        'bodyType': 'van',
        'productionStartYear': 1973,
        'displayOrder': 41
      },
      {
        'id': 'nissan_nv350',
        'name': 'NV350キャラバン',
        'nameEn': 'NV350 Caravan',
        'bodyType': 'van',
        'productionStartYear': 2012,
        'productionEndYear': 2021,
        'displayOrder': 42
      },
      {
        'id': 'nissan_nv200',
        'name': 'NV200バネット',
        'nameEn': 'NV200 Vanette',
        'bodyType': 'van',
        'productionStartYear': 2009,
        'displayOrder': 43
      },
      {
        'id': 'nissan_ad',
        'name': 'AD',
        'nameEn': 'AD',
        'bodyType': 'van',
        'productionStartYear': 1982,
        'productionEndYear': 2021,
        'displayOrder': 44
      },
      {
        'id': 'nissan_clipper_van',
        'name': 'クリッパーバン',
        'nameEn': 'Clipper Van',
        'bodyType': 'van',
        'productionStartYear': 2003,
        'displayOrder': 45
      },
      {
        'id': 'nissan_clipper_truck',
        'name': 'クリッパートラック',
        'nameEn': 'Clipper Truck',
        'bodyType': 'truck',
        'productionStartYear': 2003,
        'displayOrder': 46
      },
      {
        'id': 'nissan_atlas',
        'name': 'アトラス',
        'nameEn': 'Atlas',
        'bodyType': 'truck',
        'productionStartYear': 1981,
        'displayOrder': 47
      },
      {
        'id': 'nissan_vanette_truck',
        'name': 'バネットトラック',
        'nameEn': 'Vanette Truck',
        'bodyType': 'truck',
        'productionStartYear': 1978,
        'productionEndYear': 2016,
        'displayOrder': 48
      },
      {
        'id': 'nissan_moco',
        'name': 'モコ',
        'nameEn': 'Moco',
        'bodyType': 'kei',
        'productionStartYear': 2002,
        'productionEndYear': 2016,
        'displayOrder': 49
      },
      {
        'id': 'nissan_otti',
        'name': 'オッティ',
        'nameEn': 'Otti',
        'bodyType': 'kei',
        'productionStartYear': 2005,
        'productionEndYear': 2013,
        'displayOrder': 50
      },
      {
        'id': 'nissan_pino',
        'name': 'ピノ',
        'nameEn': 'Pino',
        'bodyType': 'kei',
        'productionStartYear': 2007,
        'productionEndYear': 2010,
        'displayOrder': 51
      },
      {
        'id': 'nissan_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'mazda': [
      {
        'id': 'mazda_cx5',
        'name': 'CX-5',
        'nameEn': 'CX-5',
        'bodyType': 'suv',
        'productionStartYear': 2012,
        'displayOrder': 1
      },
      {
        'id': 'mazda_cx30',
        'name': 'CX-30',
        'nameEn': 'CX-30',
        'bodyType': 'suv',
        'productionStartYear': 2019,
        'displayOrder': 2
      },
      {
        'id': 'mazda_mazda3',
        'name': 'MAZDA3',
        'nameEn': 'Mazda3',
        'bodyType': 'hatchback',
        'productionStartYear': 2019,
        'displayOrder': 3
      },
      {
        'id': 'mazda_cx8',
        'name': 'CX-8',
        'nameEn': 'CX-8',
        'bodyType': 'suv',
        'productionStartYear': 2017,
        'displayOrder': 4
      },
      {
        'id': 'mazda_roadster',
        'name': 'ロードスター',
        'nameEn': 'Roadster',
        'bodyType': 'convertible',
        'productionStartYear': 1989,
        'displayOrder': 5
      },
      {
        'id': 'mazda_cx60',
        'name': 'CX-60',
        'nameEn': 'CX-60',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 6
      },
      {
        'id': 'mazda_cx3',
        'name': 'CX-3',
        'nameEn': 'CX-3',
        'bodyType': 'suv',
        'productionStartYear': 2015,
        'displayOrder': 7
      },
      {
        'id': 'mazda_cx80',
        'name': 'CX-80',
        'nameEn': 'CX-80',
        'bodyType': 'suv',
        'productionStartYear': 2024,
        'displayOrder': 8
      },
      {
        'id': 'mazda_mazda2',
        'name': 'MAZDA2',
        'nameEn': 'Mazda2',
        'bodyType': 'hatchback',
        'productionStartYear': 2019,
        'displayOrder': 9
      },
      {
        'id': 'mazda_mazda6',
        'name': 'MAZDA6',
        'nameEn': 'Mazda6',
        'bodyType': 'sedan',
        'productionStartYear': 2019,
        'displayOrder': 10
      },
      {
        'id': 'mazda_demio',
        'name': 'デミオ',
        'nameEn': 'Demio',
        'bodyType': 'hatchback',
        'productionStartYear': 1996,
        'productionEndYear': 2019,
        'displayOrder': 11
      },
      {
        'id': 'mazda_axela',
        'name': 'アクセラ',
        'nameEn': 'Axela',
        'bodyType': 'hatchback',
        'productionStartYear': 2003,
        'productionEndYear': 2019,
        'displayOrder': 12
      },
      {
        'id': 'mazda_atenza',
        'name': 'アテンザ',
        'nameEn': 'Atenza',
        'bodyType': 'sedan',
        'productionStartYear': 2002,
        'productionEndYear': 2019,
        'displayOrder': 13
      },
      {
        'id': 'mazda_verisa',
        'name': 'ベリーサ',
        'nameEn': 'Verisa',
        'bodyType': 'hatchback',
        'productionStartYear': 2004,
        'productionEndYear': 2015,
        'displayOrder': 14
      },
      {
        'id': 'mazda_premacy',
        'name': 'プレマシー',
        'nameEn': 'Premacy',
        'bodyType': 'minivan',
        'productionStartYear': 1999,
        'productionEndYear': 2018,
        'displayOrder': 15
      },
      {
        'id': 'mazda_biante',
        'name': 'ビアンテ',
        'nameEn': 'Biante',
        'bodyType': 'minivan',
        'productionStartYear': 2008,
        'productionEndYear': 2018,
        'displayOrder': 16
      },
      {
        'id': 'mazda_mpv',
        'name': 'MPV',
        'nameEn': 'MPV',
        'bodyType': 'minivan',
        'productionStartYear': 1988,
        'productionEndYear': 2016,
        'displayOrder': 17
      },
      {
        'id': 'mazda_rx7',
        'name': 'RX-7',
        'nameEn': 'RX-7',
        'bodyType': 'coupe',
        'productionStartYear': 1978,
        'productionEndYear': 2002,
        'displayOrder': 18
      },
      {
        'id': 'mazda_rx8',
        'name': 'RX-8',
        'nameEn': 'RX-8',
        'bodyType': 'coupe',
        'productionStartYear': 2003,
        'productionEndYear': 2012,
        'displayOrder': 19
      },
      {
        'id': 'mazda_carol',
        'name': 'キャロル',
        'nameEn': 'Carol',
        'bodyType': 'kei',
        'productionStartYear': 1962,
        'displayOrder': 20
      },
      {
        'id': 'mazda_flair',
        'name': 'フレア',
        'nameEn': 'Flair',
        'bodyType': 'kei',
        'productionStartYear': 2012,
        'displayOrder': 21
      },
      {
        'id': 'mazda_flair_wagon',
        'name': 'フレアワゴン',
        'nameEn': 'Flair Wagon',
        'bodyType': 'kei',
        'productionStartYear': 2012,
        'displayOrder': 22
      },
      {
        'id': 'mazda_flair_crossover',
        'name': 'フレアクロスオーバー',
        'nameEn': 'Flair Crossover',
        'bodyType': 'kei',
        'productionStartYear': 2014,
        'displayOrder': 23
      },
      {
        'id': 'mazda_scrum_van',
        'name': 'スクラムバン',
        'nameEn': 'Scrum Van',
        'bodyType': 'van',
        'productionStartYear': 1989,
        'displayOrder': 24
      },
      {
        'id': 'mazda_scrum_truck',
        'name': 'スクラムトラック',
        'nameEn': 'Scrum Truck',
        'bodyType': 'truck',
        'productionStartYear': 1989,
        'displayOrder': 25
      },
      {
        'id': 'mazda_bongo',
        'name': 'ボンゴ',
        'nameEn': 'Bongo',
        'bodyType': 'van',
        'productionStartYear': 1966,
        'displayOrder': 26
      },
      {
        'id': 'mazda_bongo_brawny',
        'name': 'ボンゴブローニイ',
        'nameEn': 'Bongo Brawny',
        'bodyType': 'van',
        'productionStartYear': 1983,
        'productionEndYear': 2019,
        'displayOrder': 27
      },
      {
        'id': 'mazda_bongo_truck',
        'name': 'ボンゴトラック',
        'nameEn': 'Bongo Truck',
        'bodyType': 'truck',
        'productionStartYear': 1966,
        'displayOrder': 28
      },
      {
        'id': 'mazda_titan',
        'name': 'タイタン',
        'nameEn': 'Titan',
        'bodyType': 'truck',
        'productionStartYear': 1971,
        'displayOrder': 29
      },
      {
        'id': 'mazda_familia',
        'name': 'ファミリア',
        'nameEn': 'Familia',
        'bodyType': 'hatchback',
        'productionStartYear': 1963,
        'productionEndYear': 2004,
        'displayOrder': 30
      },
      {
        'id': 'mazda_familia_van',
        'name': 'ファミリアバン',
        'nameEn': 'Familia Van',
        'bodyType': 'van',
        'productionStartYear': 1994,
        'displayOrder': 31
      },
      {
        'id': 'mazda_capella',
        'name': 'カペラ',
        'nameEn': 'Capella',
        'bodyType': 'sedan',
        'productionStartYear': 1970,
        'productionEndYear': 2002,
        'displayOrder': 32
      },
      {
        'id': 'mazda_lantis',
        'name': 'ランティス',
        'nameEn': 'Lantis',
        'bodyType': 'sedan',
        'productionStartYear': 1993,
        'productionEndYear': 1997,
        'displayOrder': 33
      },
      {
        'id': 'mazda_eunos_cosmo',
        'name': 'ユーノスコスモ',
        'nameEn': 'Eunos Cosmo',
        'bodyType': 'coupe',
        'productionStartYear': 1990,
        'productionEndYear': 1996,
        'displayOrder': 34
      },
      {
        'id': 'mazda_az_wagon',
        'name': 'AZ-ワゴン',
        'nameEn': 'AZ-Wagon',
        'bodyType': 'kei',
        'productionStartYear': 1994,
        'productionEndYear': 2012,
        'displayOrder': 35
      },
      {
        'id': 'mazda_spiano',
        'name': 'スピアーノ',
        'nameEn': 'Spiano',
        'bodyType': 'kei',
        'productionStartYear': 2002,
        'productionEndYear': 2008,
        'displayOrder': 36
      },
      {
        'id': 'mazda_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'subaru': [
      {
        'id': 'subaru_forester',
        'name': 'フォレスター',
        'nameEn': 'Forester',
        'bodyType': 'suv',
        'productionStartYear': 1997,
        'displayOrder': 1
      },
      {
        'id': 'subaru_impreza',
        'name': 'インプレッサ',
        'nameEn': 'Impreza',
        'bodyType': 'hatchback',
        'productionStartYear': 1992,
        'displayOrder': 2
      },
      {
        'id': 'subaru_levorg',
        'name': 'レヴォーグ',
        'nameEn': 'Levorg',
        'bodyType': 'wagon',
        'productionStartYear': 2014,
        'displayOrder': 3
      },
      {
        'id': 'subaru_outback',
        'name': 'レガシィアウトバック',
        'nameEn': 'Legacy Outback',
        'bodyType': 'suv',
        'productionStartYear': 1995,
        'displayOrder': 4
      },
      {
        'id': 'subaru_xv',
        'name': 'XV',
        'nameEn': 'XV',
        'bodyType': 'suv',
        'productionStartYear': 2010,
        'productionEndYear': 2022,
        'displayOrder': 5
      },
      {
        'id': 'subaru_wrx',
        'name': 'WRX',
        'nameEn': 'WRX',
        'bodyType': 'sedan',
        'productionStartYear': 2014,
        'displayOrder': 6
      },
      {
        'id': 'subaru_brz',
        'name': 'BRZ',
        'nameEn': 'BRZ',
        'bodyType': 'coupe',
        'productionStartYear': 2012,
        'displayOrder': 7
      },
      {
        'id': 'subaru_crosstrek',
        'name': 'クロストレック',
        'nameEn': 'Crosstrek',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 8
      },
      {
        'id': 'subaru_solterra',
        'name': 'ソルテラ',
        'nameEn': 'Solterra',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 9
      },
      {
        'id': 'subaru_levorg_layback',
        'name': 'レヴォーグレイバック',
        'nameEn': 'Levorg Layback',
        'bodyType': 'wagon',
        'productionStartYear': 2023,
        'displayOrder': 10
      },
      {
        'id': 'subaru_legacy',
        'name': 'レガシィ',
        'nameEn': 'Legacy',
        'bodyType': 'sedan',
        'productionStartYear': 1989,
        'displayOrder': 11
      },
      {
        'id': 'subaru_legacy_b4',
        'name': 'レガシィB4',
        'nameEn': 'Legacy B4',
        'bodyType': 'sedan',
        'productionStartYear': 1998,
        'productionEndYear': 2020,
        'displayOrder': 12
      },
      {
        'id': 'subaru_legacy_touring',
        'name': 'レガシィツーリングワゴン',
        'nameEn': 'Legacy Touring Wagon',
        'bodyType': 'wagon',
        'productionStartYear': 1989,
        'productionEndYear': 2014,
        'displayOrder': 13
      },
      {
        'id': 'subaru_exiga',
        'name': 'エクシーガ',
        'nameEn': 'Exiga',
        'bodyType': 'minivan',
        'productionStartYear': 2008,
        'productionEndYear': 2018,
        'displayOrder': 14
      },
      {
        'id': 'subaru_sambar_van',
        'name': 'サンバーバン',
        'nameEn': 'Sambar Van',
        'bodyType': 'van',
        'productionStartYear': 1961,
        'displayOrder': 15
      },
      {
        'id': 'subaru_sambar_truck',
        'name': 'サンバートラック',
        'nameEn': 'Sambar Truck',
        'bodyType': 'truck',
        'productionStartYear': 1961,
        'displayOrder': 16
      },
      {
        'id': 'subaru_dias_wagon',
        'name': 'ディアスワゴン',
        'nameEn': 'Dias Wagon',
        'bodyType': 'van',
        'productionStartYear': 1981,
        'productionEndYear': 2020,
        'displayOrder': 17
      },
      {
        'id': 'subaru_stella',
        'name': 'ステラ',
        'nameEn': 'Stella',
        'bodyType': 'kei',
        'productionStartYear': 2006,
        'displayOrder': 18
      },
      {
        'id': 'subaru_pleo',
        'name': 'プレオ',
        'nameEn': 'Pleo',
        'bodyType': 'kei',
        'productionStartYear': 1998,
        'productionEndYear': 2018,
        'displayOrder': 19
      },
      {
        'id': 'subaru_r2',
        'name': 'R2',
        'nameEn': 'R2',
        'bodyType': 'kei',
        'productionStartYear': 2003,
        'productionEndYear': 2010,
        'displayOrder': 20
      },
      {
        'id': 'subaru_r1',
        'name': 'R1',
        'nameEn': 'R1',
        'bodyType': 'kei',
        'productionStartYear': 2005,
        'productionEndYear': 2010,
        'displayOrder': 21
      },
      {
        'id': 'subaru_vivio',
        'name': 'ヴィヴィオ',
        'nameEn': 'Vivio',
        'bodyType': 'kei',
        'productionStartYear': 1992,
        'productionEndYear': 1998,
        'displayOrder': 22
      },
      {
        'id': 'subaru_rex',
        'name': 'レックス',
        'nameEn': 'Rex',
        'bodyType': 'kei',
        'productionStartYear': 1972,
        'displayOrder': 23
      },
      {
        'id': 'subaru_justy',
        'name': 'ジャスティ',
        'nameEn': 'Justy',
        'bodyType': 'minivan',
        'productionStartYear': 1984,
        'productionEndYear': 2020,
        'displayOrder': 24
      },
      {
        'id': 'subaru_trezia',
        'name': 'トレジア',
        'nameEn': 'Trezia',
        'bodyType': 'hatchback',
        'productionStartYear': 2010,
        'productionEndYear': 2016,
        'displayOrder': 25
      },
      {
        'id': 'subaru_alcyone',
        'name': 'アルシオーネ',
        'nameEn': 'Alcyone',
        'bodyType': 'coupe',
        'productionStartYear': 1985,
        'productionEndYear': 1996,
        'displayOrder': 26
      },
      {
        'id': 'subaru_tribeca',
        'name': 'トライベッカ',
        'nameEn': 'Tribeca',
        'bodyType': 'suv',
        'productionStartYear': 2005,
        'productionEndYear': 2014,
        'displayOrder': 27
      },
      {
        'id': 'subaru_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'suzuki': [
      {
        'id': 'suzuki_jimny',
        'name': 'ジムニー',
        'nameEn': 'Jimny',
        'bodyType': 'kei',
        'productionStartYear': 1970,
        'displayOrder': 1
      },
      {
        'id': 'suzuki_swift',
        'name': 'スイフト',
        'nameEn': 'Swift',
        'bodyType': 'hatchback',
        'productionStartYear': 2000,
        'displayOrder': 2
      },
      {
        'id': 'suzuki_hustler',
        'name': 'ハスラー',
        'nameEn': 'Hustler',
        'bodyType': 'kei',
        'productionStartYear': 2014,
        'displayOrder': 3
      },
      {
        'id': 'suzuki_spacia',
        'name': 'スペーシア',
        'nameEn': 'Spacia',
        'bodyType': 'kei',
        'productionStartYear': 2013,
        'displayOrder': 4
      },
      {
        'id': 'suzuki_alto',
        'name': 'アルト',
        'nameEn': 'Alto',
        'bodyType': 'kei',
        'productionStartYear': 1979,
        'displayOrder': 5
      },
      {
        'id': 'suzuki_solio',
        'name': 'ソリオ',
        'nameEn': 'Solio',
        'bodyType': 'minivan',
        'productionStartYear': 2010,
        'displayOrder': 6
      },
      {
        'id': 'suzuki_wagonr',
        'name': 'ワゴンR',
        'nameEn': 'Wagon R',
        'bodyType': 'kei',
        'productionStartYear': 1993,
        'displayOrder': 7
      },
      {
        'id': 'suzuki_wagonr_smile',
        'name': 'ワゴンRスマイル',
        'nameEn': 'Wagon R Smile',
        'bodyType': 'kei',
        'productionStartYear': 2021,
        'displayOrder': 8
      },
      {
        'id': 'suzuki_lapin',
        'name': 'アルトラパン',
        'nameEn': 'Alto Lapin',
        'bodyType': 'kei',
        'productionStartYear': 2002,
        'displayOrder': 9
      },
      {
        'id': 'suzuki_jimny_sierra',
        'name': 'ジムニーシエラ',
        'nameEn': 'Jimny Sierra',
        'bodyType': 'suv',
        'productionStartYear': 1993,
        'displayOrder': 10
      },
      {
        'id': 'suzuki_crossbee',
        'name': 'クロスビー',
        'nameEn': 'XBEE',
        'bodyType': 'suv',
        'productionStartYear': 2017,
        'displayOrder': 11
      },
      {
        'id': 'suzuki_ignis',
        'name': 'イグニス',
        'nameEn': 'Ignis',
        'bodyType': 'suv',
        'productionStartYear': 2016,
        'displayOrder': 12
      },
      {
        'id': 'suzuki_baleno',
        'name': 'バレーノ',
        'nameEn': 'Baleno',
        'bodyType': 'hatchback',
        'productionStartYear': 2016,
        'productionEndYear': 2020,
        'displayOrder': 13
      },
      {
        'id': 'suzuki_sx4',
        'name': 'SX4',
        'nameEn': 'SX4',
        'bodyType': 'suv',
        'productionStartYear': 2006,
        'productionEndYear': 2014,
        'displayOrder': 14
      },
      {
        'id': 'suzuki_sx4_scross',
        'name': 'SX4 Sクロス',
        'nameEn': 'SX4 S-Cross',
        'bodyType': 'suv',
        'productionStartYear': 2015,
        'productionEndYear': 2020,
        'displayOrder': 15
      },
      {
        'id': 'suzuki_escudo',
        'name': 'エスクード',
        'nameEn': 'Escudo',
        'bodyType': 'suv',
        'productionStartYear': 1988,
        'displayOrder': 16
      },
      {
        'id': 'suzuki_every_van',
        'name': 'エブリイ',
        'nameEn': 'Every',
        'bodyType': 'van',
        'productionStartYear': 1982,
        'displayOrder': 17
      },
      {
        'id': 'suzuki_every_wagon',
        'name': 'エブリイワゴン',
        'nameEn': 'Every Wagon',
        'bodyType': 'van',
        'productionStartYear': 1999,
        'displayOrder': 18
      },
      {
        'id': 'suzuki_carry',
        'name': 'キャリイ',
        'nameEn': 'Carry',
        'bodyType': 'truck',
        'productionStartYear': 1961,
        'displayOrder': 19
      },
      {
        'id': 'suzuki_super_carry',
        'name': 'スーパーキャリイ',
        'nameEn': 'Super Carry',
        'bodyType': 'truck',
        'productionStartYear': 2018,
        'displayOrder': 20
      },
      {
        'id': 'suzuki_landy',
        'name': 'ランディ',
        'nameEn': 'Landy',
        'bodyType': 'minivan',
        'productionStartYear': 2007,
        'displayOrder': 21
      },
      {
        'id': 'suzuki_palette',
        'name': 'パレット',
        'nameEn': 'Palette',
        'bodyType': 'kei',
        'productionStartYear': 2008,
        'productionEndYear': 2013,
        'displayOrder': 22
      },
      {
        'id': 'suzuki_mrwagon',
        'name': 'MRワゴン',
        'nameEn': 'MR Wagon',
        'bodyType': 'kei',
        'productionStartYear': 2001,
        'productionEndYear': 2016,
        'displayOrder': 23
      },
      {
        'id': 'suzuki_cervo',
        'name': 'セルボ',
        'nameEn': 'Cervo',
        'bodyType': 'kei',
        'productionStartYear': 1977,
        'productionEndYear': 2009,
        'displayOrder': 24
      },
      {
        'id': 'suzuki_kei',
        'name': 'Kei',
        'nameEn': 'Kei',
        'bodyType': 'kei',
        'productionStartYear': 1998,
        'productionEndYear': 2009,
        'displayOrder': 25
      },
      {
        'id': 'suzuki_twin',
        'name': 'ツイン',
        'nameEn': 'Twin',
        'bodyType': 'kei',
        'productionStartYear': 2003,
        'productionEndYear': 2005,
        'displayOrder': 26
      },
      {
        'id': 'suzuki_cappuccino',
        'name': 'カプチーノ',
        'nameEn': 'Cappuccino',
        'bodyType': 'kei',
        'productionStartYear': 1991,
        'productionEndYear': 1998,
        'displayOrder': 27
      },
      {
        'id': 'suzuki_splash',
        'name': 'スプラッシュ',
        'nameEn': 'Splash',
        'bodyType': 'hatchback',
        'productionStartYear': 2008,
        'productionEndYear': 2014,
        'displayOrder': 28
      },
      {
        'id': 'suzuki_kizashi',
        'name': 'キザシ',
        'nameEn': 'Kizashi',
        'bodyType': 'sedan',
        'productionStartYear': 2009,
        'productionEndYear': 2015,
        'displayOrder': 29
      },
      {
        'id': 'suzuki_aerio',
        'name': 'エリオ',
        'nameEn': 'Aerio',
        'bodyType': 'sedan',
        'productionStartYear': 2001,
        'productionEndYear': 2007,
        'displayOrder': 30
      },
      {
        'id': 'suzuki_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'daihatsu': [
      {
        'id': 'daihatsu_tanto',
        'name': 'タント',
        'nameEn': 'Tanto',
        'bodyType': 'kei',
        'productionStartYear': 2003,
        'displayOrder': 1
      },
      {
        'id': 'daihatsu_move',
        'name': 'ムーヴ',
        'nameEn': 'Move',
        'bodyType': 'kei',
        'productionStartYear': 1995,
        'displayOrder': 2
      },
      {
        'id': 'daihatsu_rocky',
        'name': 'ロッキー',
        'nameEn': 'Rocky',
        'bodyType': 'suv',
        'productionStartYear': 2019,
        'displayOrder': 3
      },
      {
        'id': 'daihatsu_mira',
        'name': 'ミラ',
        'nameEn': 'Mira',
        'bodyType': 'kei',
        'productionStartYear': 1980,
        'displayOrder': 4
      },
      {
        'id': 'daihatsu_taft',
        'name': 'タフト',
        'nameEn': 'Taft',
        'bodyType': 'kei',
        'productionStartYear': 2020,
        'displayOrder': 5
      },
      {
        'id': 'daihatsu_move_canbus',
        'name': 'ムーヴキャンバス',
        'nameEn': 'Move Canbus',
        'bodyType': 'kei',
        'productionStartYear': 2016,
        'displayOrder': 6
      },
      {
        'id': 'daihatsu_move_conte',
        'name': 'ムーヴコンテ',
        'nameEn': 'Move Conte',
        'bodyType': 'kei',
        'productionStartYear': 2008,
        'productionEndYear': 2017,
        'displayOrder': 7
      },
      {
        'id': 'daihatsu_mira_es',
        'name': 'ミラ イース',
        'nameEn': 'Mira e:S',
        'bodyType': 'kei',
        'productionStartYear': 2011,
        'displayOrder': 8
      },
      {
        'id': 'daihatsu_mira_tocot',
        'name': 'ミラ トコット',
        'nameEn': 'Mira Tocot',
        'bodyType': 'kei',
        'productionStartYear': 2018,
        'displayOrder': 9
      },
      {
        'id': 'daihatsu_mira_cocoa',
        'name': 'ミラ ココア',
        'nameEn': 'Mira Cocoa',
        'bodyType': 'kei',
        'productionStartYear': 2009,
        'productionEndYear': 2018,
        'displayOrder': 10
      },
      {
        'id': 'daihatsu_wake',
        'name': 'ウェイク',
        'nameEn': 'Wake',
        'bodyType': 'kei',
        'productionStartYear': 2014,
        'productionEndYear': 2022,
        'displayOrder': 11
      },
      {
        'id': 'daihatsu_cast',
        'name': 'キャスト',
        'nameEn': 'Cast',
        'bodyType': 'kei',
        'productionStartYear': 2015,
        'productionEndYear': 2023,
        'displayOrder': 12
      },
      {
        'id': 'daihatsu_copen',
        'name': 'コペン',
        'nameEn': 'Copen',
        'bodyType': 'kei',
        'productionStartYear': 2002,
        'displayOrder': 13
      },
      {
        'id': 'daihatsu_boon',
        'name': 'ブーン',
        'nameEn': 'Boon',
        'bodyType': 'hatchback',
        'productionStartYear': 2004,
        'displayOrder': 14
      },
      {
        'id': 'daihatsu_thor',
        'name': 'トール',
        'nameEn': 'Thor',
        'bodyType': 'minivan',
        'productionStartYear': 2016,
        'displayOrder': 15
      },
      {
        'id': 'daihatsu_sonica',
        'name': 'ソニカ',
        'nameEn': 'Sonica',
        'bodyType': 'kei',
        'productionStartYear': 2006,
        'productionEndYear': 2009,
        'displayOrder': 16
      },
      {
        'id': 'daihatsu_esse',
        'name': 'エッセ',
        'nameEn': 'Esse',
        'bodyType': 'kei',
        'productionStartYear': 2005,
        'productionEndYear': 2011,
        'displayOrder': 17
      },
      {
        'id': 'daihatsu_naked',
        'name': 'ネイキッド',
        'nameEn': 'Naked',
        'bodyType': 'kei',
        'productionStartYear': 1999,
        'productionEndYear': 2004,
        'displayOrder': 18
      },
      {
        'id': 'daihatsu_max',
        'name': 'MAX',
        'nameEn': 'MAX',
        'bodyType': 'kei',
        'productionStartYear': 2001,
        'productionEndYear': 2005,
        'displayOrder': 19
      },
      {
        'id': 'daihatsu_opti',
        'name': 'オプティ',
        'nameEn': 'Opti',
        'bodyType': 'kei',
        'productionStartYear': 1992,
        'productionEndYear': 2002,
        'displayOrder': 20
      },
      {
        'id': 'daihatsu_storia',
        'name': 'ストーリア',
        'nameEn': 'Storia',
        'bodyType': 'hatchback',
        'productionStartYear': 1998,
        'productionEndYear': 2004,
        'displayOrder': 21
      },
      {
        'id': 'daihatsu_yrv',
        'name': 'YRV',
        'nameEn': 'YRV',
        'bodyType': 'hatchback',
        'productionStartYear': 2000,
        'productionEndYear': 2005,
        'displayOrder': 22
      },
      {
        'id': 'daihatsu_bego',
        'name': 'ビーゴ',
        'nameEn': 'Be-go',
        'bodyType': 'suv',
        'productionStartYear': 2006,
        'productionEndYear': 2016,
        'displayOrder': 23
      },
      {
        'id': 'daihatsu_terios_kid',
        'name': 'テリオスキッド',
        'nameEn': 'Terios Kid',
        'bodyType': 'kei',
        'productionStartYear': 1998,
        'productionEndYear': 2012,
        'displayOrder': 24
      },
      {
        'id': 'daihatsu_atrai',
        'name': 'アトレー',
        'nameEn': 'Atrai',
        'bodyType': 'van',
        'productionStartYear': 1981,
        'displayOrder': 25
      },
      {
        'id': 'daihatsu_atrai_wagon',
        'name': 'アトレーワゴン',
        'nameEn': 'Atrai Wagon',
        'bodyType': 'van',
        'productionStartYear': 1999,
        'productionEndYear': 2021,
        'displayOrder': 26
      },
      {
        'id': 'daihatsu_hijet_cargo',
        'name': 'ハイゼットカーゴ',
        'nameEn': 'Hijet Cargo',
        'bodyType': 'van',
        'productionStartYear': 1960,
        'displayOrder': 27
      },
      {
        'id': 'daihatsu_hijet_truck',
        'name': 'ハイゼットトラック',
        'nameEn': 'Hijet Truck',
        'bodyType': 'truck',
        'productionStartYear': 1960,
        'displayOrder': 28
      },
      {
        'id': 'daihatsu_hijet_jumbo',
        'name': 'ハイゼットジャンボ',
        'nameEn': 'Hijet Jumbo',
        'bodyType': 'truck',
        'productionStartYear': 1999,
        'displayOrder': 29
      },
      {
        'id': 'daihatsu_gran_max',
        'name': 'グランマックス',
        'nameEn': 'Gran Max',
        'bodyType': 'van',
        'productionStartYear': 2020,
        'displayOrder': 30
      },
      {
        'id': 'daihatsu_gran_max_truck',
        'name': 'グランマックストラック',
        'nameEn': 'Gran Max Truck',
        'bodyType': 'truck',
        'productionStartYear': 2020,
        'displayOrder': 31
      },
      {
        'id': 'daihatsu_delta_truck',
        'name': 'デルタトラック',
        'nameEn': 'Delta Truck',
        'bodyType': 'truck',
        'productionStartYear': 1968,
        'productionEndYear': 2002,
        'displayOrder': 32
      },
      {
        'id': 'daihatsu_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'mitsubishi': [
      {
        'id': 'mitsubishi_outlander',
        'name': 'アウトランダー',
        'nameEn': 'Outlander',
        'bodyType': 'suv',
        'productionStartYear': 2005,
        'displayOrder': 1
      },
      {
        'id': 'mitsubishi_delica',
        'name': 'デリカD:5',
        'nameEn': 'Delica D:5',
        'bodyType': 'minivan',
        'productionStartYear': 2007,
        'displayOrder': 2
      },
      {
        'id': 'mitsubishi_eclipse',
        'name': 'エクリプスクロス',
        'nameEn': 'Eclipse Cross',
        'bodyType': 'suv',
        'productionStartYear': 2018,
        'displayOrder': 3
      },
      {
        'id': 'mitsubishi_ek',
        'name': 'eKワゴン',
        'nameEn': 'eK Wagon',
        'bodyType': 'kei',
        'productionStartYear': 2001,
        'displayOrder': 4
      },
      {
        'id': 'mitsubishi_ek_cross',
        'name': 'eKクロス',
        'nameEn': 'eK X',
        'bodyType': 'kei',
        'productionStartYear': 2019,
        'displayOrder': 5
      },
      {
        'id': 'mitsubishi_ek_space',
        'name': 'eKスペース',
        'nameEn': 'eK Space',
        'bodyType': 'kei',
        'productionStartYear': 2014,
        'displayOrder': 6
      },
      {
        'id': 'mitsubishi_ek_cross_space',
        'name': 'eKクロススペース',
        'nameEn': 'eK X Space',
        'bodyType': 'kei',
        'productionStartYear': 2020,
        'displayOrder': 7
      },
      {
        'id': 'mitsubishi_delica_mini',
        'name': 'デリカミニ',
        'nameEn': 'Delica Mini',
        'bodyType': 'kei',
        'productionStartYear': 2023,
        'displayOrder': 8
      },
      {
        'id': 'mitsubishi_delica_d2',
        'name': 'デリカD:2',
        'nameEn': 'Delica D:2',
        'bodyType': 'minivan',
        'productionStartYear': 2011,
        'displayOrder': 9
      },
      {
        'id': 'mitsubishi_mirage',
        'name': 'ミラージュ',
        'nameEn': 'Mirage',
        'bodyType': 'hatchback',
        'productionStartYear': 1978,
        'displayOrder': 10
      },
      {
        'id': 'mitsubishi_rvr',
        'name': 'RVR',
        'nameEn': 'RVR',
        'bodyType': 'suv',
        'productionStartYear': 1991,
        'displayOrder': 11
      },
      {
        'id': 'mitsubishi_pajero',
        'name': 'パジェロ',
        'nameEn': 'Pajero',
        'bodyType': 'suv',
        'productionStartYear': 1982,
        'productionEndYear': 2019,
        'displayOrder': 12
      },
      {
        'id': 'mitsubishi_pajero_mini',
        'name': 'パジェロミニ',
        'nameEn': 'Pajero Mini',
        'bodyType': 'kei',
        'productionStartYear': 1994,
        'productionEndYear': 2012,
        'displayOrder': 13
      },
      {
        'id': 'mitsubishi_pajero_io',
        'name': 'パジェロイオ',
        'nameEn': 'Pajero iO',
        'bodyType': 'suv',
        'productionStartYear': 1998,
        'productionEndYear': 2007,
        'displayOrder': 14
      },
      {
        'id': 'mitsubishi_triton',
        'name': 'トライトン',
        'nameEn': 'Triton',
        'bodyType': 'truck',
        'productionStartYear': 2006,
        'displayOrder': 15
      },
      {
        'id': 'mitsubishi_lancer',
        'name': 'ランサー',
        'nameEn': 'Lancer',
        'bodyType': 'sedan',
        'productionStartYear': 1973,
        'productionEndYear': 2010,
        'displayOrder': 16
      },
      {
        'id': 'mitsubishi_lancer_evolution',
        'name': 'ランサーエボリューション',
        'nameEn': 'Lancer Evolution',
        'bodyType': 'sedan',
        'productionStartYear': 1992,
        'productionEndYear': 2016,
        'displayOrder': 17
      },
      {
        'id': 'mitsubishi_galant',
        'name': 'ギャラン',
        'nameEn': 'Galant',
        'bodyType': 'sedan',
        'productionStartYear': 1969,
        'productionEndYear': 2005,
        'displayOrder': 18
      },
      {
        'id': 'mitsubishi_galant_fortis',
        'name': 'ギャランフォルティス',
        'nameEn': 'Galant Fortis',
        'bodyType': 'sedan',
        'productionStartYear': 2007,
        'productionEndYear': 2015,
        'displayOrder': 19
      },
      {
        'id': 'mitsubishi_colt',
        'name': 'コルト',
        'nameEn': 'Colt',
        'bodyType': 'hatchback',
        'productionStartYear': 1962,
        'productionEndYear': 2012,
        'displayOrder': 20
      },
      {
        'id': 'mitsubishi_imiev',
        'name': 'i-MiEV',
        'nameEn': 'i-MiEV',
        'bodyType': 'kei',
        'productionStartYear': 2009,
        'productionEndYear': 2021,
        'displayOrder': 21
      },
      {
        'id': 'mitsubishi_i',
        'name': 'アイ',
        'nameEn': 'i',
        'bodyType': 'kei',
        'productionStartYear': 2006,
        'productionEndYear': 2013,
        'displayOrder': 22
      },
      {
        'id': 'mitsubishi_town_box',
        'name': 'タウンボックス',
        'nameEn': 'Town Box',
        'bodyType': 'van',
        'productionStartYear': 1999,
        'displayOrder': 23
      },
      {
        'id': 'mitsubishi_minicab_van',
        'name': 'ミニキャブバン',
        'nameEn': 'Minicab Van',
        'bodyType': 'van',
        'productionStartYear': 1968,
        'displayOrder': 24
      },
      {
        'id': 'mitsubishi_minicab_truck',
        'name': 'ミニキャブトラック',
        'nameEn': 'Minicab Truck',
        'bodyType': 'truck',
        'productionStartYear': 1968,
        'displayOrder': 25
      },
      {
        'id': 'mitsubishi_minicab_miev',
        'name': 'ミニキャブMiEV',
        'nameEn': 'Minicab MiEV',
        'bodyType': 'van',
        'productionStartYear': 2011,
        'displayOrder': 26
      },
      {
        'id': 'mitsubishi_diamante',
        'name': 'ディアマンテ',
        'nameEn': 'Diamante',
        'bodyType': 'sedan',
        'productionStartYear': 1990,
        'productionEndYear': 2005,
        'displayOrder': 27
      },
      {
        'id': 'mitsubishi_gto',
        'name': 'GTO',
        'nameEn': 'GTO',
        'bodyType': 'coupe',
        'productionStartYear': 1990,
        'productionEndYear': 2001,
        'displayOrder': 28
      },
      {
        'id': 'mitsubishi_fto',
        'name': 'FTO',
        'nameEn': 'FTO',
        'bodyType': 'coupe',
        'productionStartYear': 1994,
        'productionEndYear': 2000,
        'displayOrder': 29
      },
      {
        'id': 'mitsubishi_airtrek',
        'name': 'エアトレック',
        'nameEn': 'Airtrek',
        'bodyType': 'suv',
        'productionStartYear': 2001,
        'productionEndYear': 2005,
        'displayOrder': 30
      },
      {
        'id': 'mitsubishi_dion',
        'name': 'ディオン',
        'nameEn': 'Dion',
        'bodyType': 'minivan',
        'productionStartYear': 2000,
        'productionEndYear': 2005,
        'displayOrder': 31
      },
      {
        'id': 'mitsubishi_chariot',
        'name': 'シャリオ',
        'nameEn': 'Chariot',
        'bodyType': 'minivan',
        'productionStartYear': 1983,
        'productionEndYear': 2003,
        'displayOrder': 32
      },
      {
        'id': 'mitsubishi_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'lexus': [
      {
        'id': 'lexus_rx',
        'name': 'RX',
        'nameEn': 'RX',
        'bodyType': 'suv',
        'productionStartYear': 2005,
        'displayOrder': 1
      },
      {
        'id': 'lexus_nx',
        'name': 'NX',
        'nameEn': 'NX',
        'bodyType': 'suv',
        'productionStartYear': 2014,
        'displayOrder': 2
      },
      {
        'id': 'lexus_is',
        'name': 'IS',
        'nameEn': 'IS',
        'bodyType': 'sedan',
        'productionStartYear': 2005,
        'displayOrder': 3
      },
      {
        'id': 'lexus_es',
        'name': 'ES',
        'nameEn': 'ES',
        'bodyType': 'sedan',
        'productionStartYear': 2018,
        'displayOrder': 4
      },
      {
        'id': 'lexus_lx',
        'name': 'LX',
        'nameEn': 'LX',
        'bodyType': 'suv',
        'productionStartYear': 2007,
        'displayOrder': 5
      },
      {
        'id': 'lexus_ux',
        'name': 'UX',
        'nameEn': 'UX',
        'bodyType': 'suv',
        'productionStartYear': 2018,
        'displayOrder': 6
      },
      {
        'id': 'lexus_lc',
        'name': 'LC',
        'nameEn': 'LC',
        'bodyType': 'coupe',
        'productionStartYear': 2017,
        'displayOrder': 7
      },
      {
        'id': 'lexus_ls',
        'name': 'LS',
        'nameEn': 'LS',
        'bodyType': 'sedan',
        'productionStartYear': 2006,
        'displayOrder': 8
      },
      {
        'id': 'lexus_gs',
        'name': 'GS',
        'nameEn': 'GS',
        'bodyType': 'sedan',
        'productionStartYear': 2005,
        'productionEndYear': 2020,
        'displayOrder': 9
      },
      {
        'id': 'lexus_lm',
        'name': 'LM',
        'nameEn': 'LM',
        'bodyType': 'minivan',
        'productionStartYear': 2020,
        'displayOrder': 10
      },
      {
        'id': 'lexus_rz',
        'name': 'RZ',
        'nameEn': 'RZ',
        'bodyType': 'suv',
        'productionStartYear': 2023,
        'displayOrder': 11
      },
      {
        'id': 'lexus_rc',
        'name': 'RC',
        'nameEn': 'RC',
        'bodyType': 'coupe',
        'productionStartYear': 2014,
        'displayOrder': 12
      },
      {
        'id': 'lexus_ct',
        'name': 'CT',
        'nameEn': 'CT',
        'bodyType': 'hatchback',
        'productionStartYear': 2011,
        'productionEndYear': 2022,
        'displayOrder': 13
      },
      {
        'id': 'lexus_gx',
        'name': 'GX',
        'nameEn': 'GX',
        'bodyType': 'suv',
        'productionStartYear': 2024,
        'displayOrder': 14
      },
      {
        'id': 'lexus_lfa',
        'name': 'LFA',
        'nameEn': 'LFA',
        'bodyType': 'coupe',
        'productionStartYear': 2010,
        'productionEndYear': 2012,
        'displayOrder': 15
      },
      {
        'id': 'lexus_hs',
        'name': 'HS',
        'nameEn': 'HS',
        'bodyType': 'sedan',
        'productionStartYear': 2009,
        'productionEndYear': 2018,
        'displayOrder': 16
      },
      {
        'id': 'lexus_sc',
        'name': 'SC',
        'nameEn': 'SC',
        'bodyType': 'convertible',
        'productionStartYear': 2005,
        'productionEndYear': 2010,
        'displayOrder': 17
      },
      {
        'id': 'lexus_lbx',
        'name': 'LBX',
        'nameEn': 'LBX',
        'bodyType': 'suv',
        'productionStartYear': 2023,
        'displayOrder': 18
      },
      {
        'id': 'lexus_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'mitsuoka': [
      {
        'id': 'mitsuoka_viewt',
        'name': 'ビュート',
        'nameEn': 'Viewt',
        'bodyType': 'sedan',
        'productionStartYear': 1993,
        'displayOrder': 1
      },
      {
        'id': 'mitsuoka_rockstar',
        'name': 'ロックスター',
        'nameEn': 'Rock Star',
        'bodyType': 'convertible',
        'productionStartYear': 2018,
        'displayOrder': 2
      },
      {
        'id': 'mitsuoka_ryugi',
        'name': 'リューギ',
        'nameEn': 'Ryugi',
        'bodyType': 'sedan',
        'productionStartYear': 2014,
        'displayOrder': 3
      },
      {
        'id': 'mitsuoka_himiko',
        'name': 'ヒミコ',
        'nameEn': 'Himiko',
        'bodyType': 'convertible',
        'productionStartYear': 2008,
        'displayOrder': 4
      },
      {
        'id': 'mitsuoka_orochi',
        'name': 'オロチ',
        'nameEn': 'Orochi',
        'bodyType': 'coupe',
        'productionStartYear': 2006,
        'productionEndYear': 2014,
        'displayOrder': 5
      },
      {
        'id': 'mitsuoka_galue',
        'name': 'ガリュー',
        'nameEn': 'Galue',
        'bodyType': 'sedan',
        'productionStartYear': 1996,
        'displayOrder': 6
      },
      {
        'id': 'mitsuoka_lesseps',
        'name': 'ラ・セード',
        'nameEn': 'La Seyde',
        'bodyType': 'coupe',
        'productionStartYear': 1990,
        'productionEndYear': 1999,
        'displayOrder': 7
      },
      {
        'id': 'mitsuoka_buddy',
        'name': 'バディ',
        'nameEn': 'Buddy',
        'bodyType': 'suv',
        'productionStartYear': 2021,
        'displayOrder': 8
      },
      {
        'id': 'mitsuoka_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'isuzu': [
      {
        'id': 'isuzu_elf',
        'name': 'エルフ',
        'nameEn': 'Elf',
        'bodyType': 'truck',
        'productionStartYear': 1959,
        'displayOrder': 1
      },
      {
        'id': 'isuzu_forward',
        'name': 'フォワード',
        'nameEn': 'Forward',
        'bodyType': 'truck',
        'productionStartYear': 1970,
        'displayOrder': 2
      },
      {
        'id': 'isuzu_giga',
        'name': 'ギガ',
        'nameEn': 'Giga',
        'bodyType': 'truck',
        'productionStartYear': 1994,
        'displayOrder': 3
      },
      {
        'id': 'isuzu_erga',
        'name': 'エルガ',
        'nameEn': 'Erga',
        'bodyType': 'other',
        'productionStartYear': 2000,
        'displayOrder': 4
      },
      {
        'id': 'isuzu_gala',
        'name': 'ガーラ',
        'nameEn': 'Gala',
        'bodyType': 'other',
        'productionStartYear': 1996,
        'displayOrder': 5
      },
      {
        'id': 'isuzu_bighorn',
        'name': 'ビッグホーン',
        'nameEn': 'Bighorn',
        'bodyType': 'suv',
        'productionStartYear': 1981,
        'productionEndYear': 2002,
        'displayOrder': 6
      },
      {
        'id': 'isuzu_mu',
        'name': 'ミュー',
        'nameEn': 'MU',
        'bodyType': 'suv',
        'productionStartYear': 1989,
        'productionEndYear': 2001,
        'displayOrder': 7
      },
      {
        'id': 'isuzu_wizard',
        'name': 'ウィザード',
        'nameEn': 'Wizard',
        'bodyType': 'suv',
        'productionStartYear': 1998,
        'productionEndYear': 2002,
        'displayOrder': 8
      },
      {
        'id': 'isuzu_fargo',
        'name': 'ファーゴ',
        'nameEn': 'Fargo',
        'bodyType': 'van',
        'productionStartYear': 1980,
        'productionEndYear': 2001,
        'displayOrder': 9
      },
      {
        'id': 'isuzu_como',
        'name': 'コモ',
        'nameEn': 'Como',
        'bodyType': 'van',
        'productionStartYear': 2001,
        'displayOrder': 10
      },
      {
        'id': 'isuzu_dmax',
        'name': 'D-MAX',
        'nameEn': 'D-MAX',
        'bodyType': 'truck',
        'productionStartYear': 2002,
        'displayOrder': 11
      },
      {
        'id': 'isuzu_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'hino': [
      {
        'id': 'hino_dutro',
        'name': 'デュトロ',
        'nameEn': 'Dutro',
        'bodyType': 'truck',
        'productionStartYear': 1999,
        'displayOrder': 1
      },
      {
        'id': 'hino_ranger',
        'name': 'レンジャー',
        'nameEn': 'Ranger',
        'bodyType': 'truck',
        'productionStartYear': 1969,
        'displayOrder': 2
      },
      {
        'id': 'hino_profia',
        'name': 'プロフィア',
        'nameEn': 'Profia',
        'bodyType': 'truck',
        'productionStartYear': 1992,
        'displayOrder': 3
      },
      {
        'id': 'hino_liesse',
        'name': 'リエッセ',
        'nameEn': 'Liesse',
        'bodyType': 'other',
        'productionStartYear': 1995,
        'displayOrder': 4
      },
      {
        'id': 'hino_poncho',
        'name': 'ポンチョ',
        'nameEn': 'Poncho',
        'bodyType': 'other',
        'productionStartYear': 2002,
        'displayOrder': 5
      },
      {
        'id': 'hino_selega',
        'name': 'セレガ',
        'nameEn': 'Selega',
        'bodyType': 'other',
        'productionStartYear': 1990,
        'displayOrder': 6
      },
      {
        'id': 'hino_melpha',
        'name': 'メルファ',
        'nameEn': 'Melpha',
        'bodyType': 'other',
        'productionStartYear': 1999,
        'displayOrder': 7
      },
      {
        'id': 'hino_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'fuso': [
      {
        'id': 'fuso_canter',
        'name': 'キャンター',
        'nameEn': 'Canter',
        'bodyType': 'truck',
        'productionStartYear': 1963,
        'displayOrder': 1
      },
      {
        'id': 'fuso_canter_guts',
        'name': 'キャンターガッツ',
        'nameEn': 'Canter Guts',
        'bodyType': 'truck',
        'productionStartYear': 2002,
        'productionEndYear': 2012,
        'displayOrder': 2
      },
      {
        'id': 'fuso_fighter',
        'name': 'ファイター',
        'nameEn': 'Fighter',
        'bodyType': 'truck',
        'productionStartYear': 1984,
        'displayOrder': 3
      },
      {
        'id': 'fuso_super_great',
        'name': 'スーパーグレート',
        'nameEn': 'Super Great',
        'bodyType': 'truck',
        'productionStartYear': 1996,
        'displayOrder': 4
      },
      {
        'id': 'fuso_rosa',
        'name': 'ローザ',
        'nameEn': 'Rosa',
        'bodyType': 'other',
        'productionStartYear': 1960,
        'displayOrder': 5
      },
      {
        'id': 'fuso_aero_star',
        'name': 'エアロスター',
        'nameEn': 'Aero Star',
        'bodyType': 'other',
        'productionStartYear': 1984,
        'displayOrder': 6
      },
      {
        'id': 'fuso_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'ud': [
      {
        'id': 'ud_quon',
        'name': 'クオン',
        'nameEn': 'Quon',
        'bodyType': 'truck',
        'productionStartYear': 2004,
        'displayOrder': 1
      },
      {
        'id': 'ud_condor',
        'name': 'コンドル',
        'nameEn': 'Condor',
        'bodyType': 'truck',
        'productionStartYear': 1975,
        'displayOrder': 2
      },
      {
        'id': 'ud_quester',
        'name': 'クエスター',
        'nameEn': 'Quester',
        'bodyType': 'truck',
        'productionStartYear': 2013,
        'displayOrder': 3
      },
      {
        'id': 'ud_bigthumb',
        'name': 'ビッグサム',
        'nameEn': 'Big Thumb',
        'bodyType': 'truck',
        'productionStartYear': 1990,
        'productionEndYear': 2005,
        'displayOrder': 4
      },
      {
        'id': 'ud_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
    'other': [
      {
        'id': 'other_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'displayOrder': 999
      },
    ],
  };

  /// 軽貨物（4ナンバーの軽）の車種ID。
  ///
  /// 車検が「初回2年・以降2年」で、普通貨物の「初回2年・以降1年」とは
  /// 違う。`BodyType.truck` / `BodyType.van` というだけでは区別できないので
  /// ここで持つ。**間違えると車検リマインドが1年ずれる。**
  static const Set<String> keiCargoModelIds = {
    'daihatsu_hijet_cargo',
    'daihatsu_hijet_truck',
    'daihatsu_hijet_jumbo',
    'daihatsu_atrai',
    'daihatsu_atrai_wagon',
    'suzuki_every_van',
    'suzuki_every_wagon',
    'suzuki_carry',
    'suzuki_super_carry',
    'honda_nvan',
    'honda_acty_truck',
    'honda_acty_van',
    'honda_vamos',
    'subaru_sambar_van',
    'subaru_sambar_truck',
    'subaru_dias_wagon',
    'mazda_scrum_van',
    'mazda_scrum_truck',
    'mitsubishi_minicab_van',
    'mitsubishi_minicab_truck',
    'mitsubishi_minicab_miev',
    'mitsubishi_town_box',
    'nissan_clipper_van',
    'nissan_clipper_truck',
  };

  /// 汎用グレード。
  ///
  /// ⚠️ 車種に紐づかない汎用名なので、**グレード候補の提示に使わないこと**。
  ///
  /// ここに並ぶ S / G / X / Z はトヨタ系の呼称で、ホンダにもマツダにも
  /// 当てはまらない。以前 `getGradesForModel` がカタログ未整備時にこれへ
  /// フォールバックしており、シビックに「S・G・X・Z」が出るなど、
  /// 車種と噛み合わない候補を全車種に見せていた。
  ///
  /// カタログにグレードが無い場合は空を返し、自由入力に委ねる方針に
  /// 変更済み（`VehicleMasterService.getGradesForModel` を参照）。
  static const List<Map<String, dynamic>> commonGrades = [
    {'id': 'grade_s', 'name': 'S', 'displayOrder': 1},
    {'id': 'grade_g', 'name': 'G', 'displayOrder': 2},
    {'id': 'grade_x', 'name': 'X', 'displayOrder': 3},
    {'id': 'grade_z', 'name': 'Z', 'displayOrder': 4},
    {'id': 'grade_hybrid', 'name': 'ハイブリッド', 'displayOrder': 5},
    {'id': 'grade_4wd', 'name': '4WD', 'displayOrder': 6},
    {'id': 'grade_turbo', 'name': 'ターボ', 'displayOrder': 7},
    {'id': 'grade_custom', 'name': 'カスタム', 'displayOrder': 8},
    {'id': 'grade_other', 'name': 'その他', 'displayOrder': 100},
  ];

  /// Get VehicleMaker list from static data
  static List<VehicleMaker> getMakers() {
    return makers
        .map((data) => VehicleMaker.fromMap(data, data['id'] as String))
        .toList();
  }

  /// Get VehicleModel list for a specific maker from static data
  static List<VehicleModel> getModelsForMaker(String makerId) {
    final modelList = models[makerId];
    if (modelList == null) return [];
    return modelList
        .map((data) => VehicleModel.fromMap({
              ...data,
              'makerId': makerId,
            }, data['id'] as String))
        .toList();
  }

  /// 汎用グレードを [VehicleGrade] にして返す。
  ///
  /// ⚠️ 車種に紐づかない汎用名なので、**グレード候補の提示に使わないこと**。
  /// 詳細は [commonGrades] のコメントを参照。
  static List<VehicleGrade> getCommonGrades(String modelId) {
    return commonGrades
        .map((data) => VehicleGrade.fromMap({
              ...data,
              'modelId': modelId,
            }, '${modelId}_${data['id']}'))
        .toList();
  }
}
