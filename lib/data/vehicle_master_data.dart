import '../models/vehicle_master.dart';

/// Initial vehicle master data for Japanese domestic makers
/// This data is used to seed the Firestore database and for offline fallback
class VehicleMasterData {
  VehicleMasterData._();

  /// Japanese domestic vehicle makers
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
      'id': 'mercedes',
      'name': 'メルセデス・ベンツ',
      'nameEn': 'Mercedes-Benz',
      'country': 'DE',
      'displayOrder': 11,
    },
    {
      'id': 'bmw',
      'name': 'BMW',
      'nameEn': 'BMW',
      'country': 'DE',
      'displayOrder': 12,
    },
    {
      'id': 'volkswagen',
      'name': 'フォルクスワーゲン',
      'nameEn': 'Volkswagen',
      'country': 'DE',
      'displayOrder': 13,
    },
    {
      'id': 'audi',
      'name': 'アウディ',
      'nameEn': 'Audi',
      'country': 'DE',
      'displayOrder': 14,
    },
    {
      'id': 'volvo',
      'name': 'ボルボ',
      'nameEn': 'Volvo',
      'country': 'SE',
      'displayOrder': 15,
    },
    {
      'id': 'mini',
      'name': 'MINI',
      'nameEn': 'MINI',
      'country': 'GB',
      'displayOrder': 16,
    },
    {
      'id': 'tesla',
      'name': 'テスラ',
      'nameEn': 'Tesla',
      'country': 'US',
      'displayOrder': 17,
    },
    {
      'id': 'peugeot',
      'name': 'プジョー',
      'nameEn': 'Peugeot',
      'country': 'FR',
      'displayOrder': 18,
    },
    {
      'id': 'other',
      'name': 'その他',
      'nameEn': 'Other',
      'country': 'OTHER',
      'displayOrder': 100,
    },
  ];

  /// Vehicle models by maker
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
        'name': 'GR86',
        'nameEn': 'GR86',
        'bodyType': 'coupe',
        'productionStartYear': 2012,
        'displayOrder': 12
      },
      {
        'id': 'toyota_supra',
        'name': 'スープラ',
        'nameEn': 'Supra',
        'bodyType': 'coupe',
        'productionStartYear': 2019,
        'displayOrder': 13
      },
      {
        'id': 'toyota_noah',
        'name': 'ノア',
        'nameEn': 'Noah',
        'bodyType': 'minivan',
        'productionStartYear': 2001,
        'displayOrder': 50
      },
      {
        'id': 'toyota_vellfire',
        'name': 'ヴェルファイア',
        'nameEn': 'Vellfire',
        'bodyType': 'minivan',
        'productionStartYear': 2008,
        'displayOrder': 51
      },
      {
        'id': 'toyota_chr',
        'name': 'C-HR',
        'nameEn': 'C-HR',
        'bodyType': 'suv',
        'productionStartYear': 2016,
        'displayOrder': 52
      },
      {
        'id': 'toyota_raize',
        'name': 'ライズ',
        'nameEn': 'Raize',
        'bodyType': 'suv',
        'productionStartYear': 2019,
        'displayOrder': 53
      },
      {
        'id': 'toyota_roomy',
        'name': 'ルーミー',
        'nameEn': 'Roomy',
        'bodyType': 'minivan',
        'productionStartYear': 2016,
        'displayOrder': 54
      },
      {
        'id': 'toyota_passo',
        'name': 'パッソ',
        'nameEn': 'Passo',
        'bodyType': 'hatchback',
        'productionStartYear': 2004,
        'displayOrder': 55
      },
      {
        'id': 'toyota_corolla_cross',
        'name': 'カローラクロス',
        'nameEn': 'Corolla Cross',
        'bodyType': 'suv',
        'productionStartYear': 2021,
        'displayOrder': 56
      },
      {
        'id': 'toyota_hiace',
        'name': 'ハイエース',
        'nameEn': 'Hiace',
        'bodyType': 'van',
        'productionStartYear': 1967,
        'displayOrder': 57
      },
      {
        'id': 'toyota_bz4x',
        'name': 'bZ4X',
        'nameEn': 'bZ4X',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 58
      },
      {
        'id': 'toyota_noah_vitz',
        'name': 'ヴィッツ',
        'nameEn': 'Vitz',
        'bodyType': 'hatchback',
        'productionStartYear': 1999,
        'displayOrder': 59
      },
      {
        'id': 'toyota_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
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
        'nameEn': 'Step WGN',
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
        'bodyType': 'sedan',
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
        'displayOrder': 50
      },
      {
        'id': 'honda_none',
        'name': 'N-ONE',
        'nameEn': 'N-ONE',
        'bodyType': 'kei',
        'productionStartYear': 2012,
        'displayOrder': 51
      },
      {
        'id': 'honda_nvan',
        'name': 'N-VAN',
        'nameEn': 'N-VAN',
        'bodyType': 'van',
        'productionStartYear': 2018,
        'displayOrder': 52
      },
      {
        'id': 'honda_zrv',
        'name': 'ZR-V',
        'nameEn': 'ZR-V',
        'bodyType': 'suv',
        'productionStartYear': 2023,
        'displayOrder': 53
      },
      {
        'id': 'honda_wrv',
        'name': 'WR-V',
        'nameEn': 'WR-V',
        'bodyType': 'suv',
        'productionStartYear': 2024,
        'displayOrder': 54
      },
      {
        'id': 'honda_shuttle',
        'name': 'シャトル',
        'nameEn': 'Shuttle',
        'bodyType': 'wagon',
        'productionStartYear': 2015,
        'displayOrder': 55
      },
      {
        'id': 'honda_s660',
        'name': 'S660',
        'nameEn': 'S660',
        'bodyType': 'coupe',
        'productionStartYear': 2015,
        'displayOrder': 56
      },
      {
        'id': 'honda_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
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
        'name': 'ノートオーラ',
        'nameEn': 'Note Aura',
        'bodyType': 'hatchback',
        'productionStartYear': 2021,
        'displayOrder': 50
      },
      {
        'id': 'nissan_dayz',
        'name': 'デイズ',
        'nameEn': 'Dayz',
        'bodyType': 'kei',
        'productionStartYear': 2013,
        'displayOrder': 51
      },
      {
        'id': 'nissan_roox',
        'name': 'ルークス',
        'nameEn': 'Roox',
        'bodyType': 'kei',
        'productionStartYear': 2009,
        'displayOrder': 52
      },
      {
        'id': 'nissan_sakura',
        'name': 'サクラ',
        'nameEn': 'Sakura',
        'bodyType': 'kei',
        'productionStartYear': 2022,
        'displayOrder': 53
      },
      {
        'id': 'nissan_aria',
        'name': 'アリア',
        'nameEn': 'Ariya',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 54
      },
      {
        'id': 'nissan_march',
        'name': 'マーチ',
        'nameEn': 'March',
        'bodyType': 'hatchback',
        'productionStartYear': 1982,
        'displayOrder': 55
      },
      {
        'id': 'nissan_juke',
        'name': 'ジューク',
        'nameEn': 'Juke',
        'bodyType': 'suv',
        'productionStartYear': 2010,
        'displayOrder': 56
      },
      {
        'id': 'nissan_elgrand',
        'name': 'エルグランド',
        'nameEn': 'Elgrand',
        'bodyType': 'minivan',
        'productionStartYear': 1997,
        'displayOrder': 57
      },
      {
        'id': 'nissan_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
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
        'productionStartYear': 2003,
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
        'nameEn': 'MX-5 Miata',
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
        'id': 'mazda_mazda2',
        'name': 'MAZDA2',
        'nameEn': 'Mazda2',
        'bodyType': 'hatchback',
        'productionStartYear': 1996,
        'displayOrder': 50
      },
      {
        'id': 'mazda_cx3',
        'name': 'CX-3',
        'nameEn': 'CX-3',
        'bodyType': 'suv',
        'productionStartYear': 2015,
        'displayOrder': 51
      },
      {
        'id': 'mazda_mazda6',
        'name': 'MAZDA6',
        'nameEn': 'Mazda6',
        'bodyType': 'sedan',
        'productionStartYear': 2002,
        'displayOrder': 52
      },
      {
        'id': 'mazda_mx30',
        'name': 'MX-30',
        'nameEn': 'MX-30',
        'bodyType': 'suv',
        'productionStartYear': 2020,
        'displayOrder': 53
      },
      {
        'id': 'mazda_cx90',
        'name': 'CX-90',
        'nameEn': 'CX-90',
        'bodyType': 'suv',
        'productionStartYear': 2023,
        'displayOrder': 54
      },
      {
        'id': 'mazda_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
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
        'name': 'アウトバック',
        'nameEn': 'Outback',
        'bodyType': 'wagon',
        'productionStartYear': 1994,
        'displayOrder': 4
      },
      {
        'id': 'subaru_xv',
        'name': 'XV',
        'nameEn': 'Crosstrek',
        'bodyType': 'suv',
        'productionStartYear': 2012,
        'displayOrder': 5
      },
      {
        'id': 'subaru_wrx',
        'name': 'WRX S4',
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
        'id': 'subaru_legacy',
        'name': 'レガシィ',
        'nameEn': 'Legacy',
        'bodyType': 'wagon',
        'productionStartYear': 1989,
        'displayOrder': 50
      },
      {
        'id': 'subaru_solterra',
        'name': 'ソルテラ',
        'nameEn': 'Solterra',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 51
      },
      {
        'id': 'subaru_sambar',
        'name': 'サンバー',
        'nameEn': 'Sambar',
        'bodyType': 'van',
        'productionStartYear': 1961,
        'displayOrder': 52
      },
      {
        'id': 'subaru_justy',
        'name': 'ジャスティ',
        'nameEn': 'Justy',
        'bodyType': 'minivan',
        'productionStartYear': 2016,
        'displayOrder': 53
      },
      {
        'id': 'subaru_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
      },
    ],
    'suzuki': [
      {
        'id': 'suzuki_jimny',
        'name': 'ジムニー',
        'nameEn': 'Jimny',
        'bodyType': 'suv',
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
        'displayOrder': 50
      },
      {
        'id': 'suzuki_every',
        'name': 'エブリイ',
        'nameEn': 'Every',
        'bodyType': 'van',
        'productionStartYear': 1982,
        'displayOrder': 51
      },
      {
        'id': 'suzuki_xbee',
        'name': 'クロスビー',
        'nameEn': 'Xbee',
        'bodyType': 'suv',
        'productionStartYear': 2017,
        'displayOrder': 52
      },
      {
        'id': 'suzuki_lapin',
        'name': 'アルトラパン',
        'nameEn': 'Alto Lapin',
        'bodyType': 'kei',
        'productionStartYear': 2002,
        'displayOrder': 53
      },
      {
        'id': 'suzuki_jimny_sierra',
        'name': 'ジムニーシエラ',
        'nameEn': 'Jimny Sierra',
        'bodyType': 'suv',
        'productionStartYear': 2018,
        'displayOrder': 54
      },
      {
        'id': 'suzuki_escudo',
        'name': 'エスクード',
        'nameEn': 'Escudo',
        'bodyType': 'suv',
        'productionStartYear': 1988,
        'displayOrder': 55
      },
      {
        'id': 'suzuki_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
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
        'id': 'daihatsu_mira_es',
        'name': 'ミライース',
        'nameEn': 'Mira e:S',
        'bodyType': 'kei',
        'productionStartYear': 2011,
        'displayOrder': 50
      },
      {
        'id': 'daihatsu_hijet',
        'name': 'ハイゼット',
        'nameEn': 'Hijet',
        'bodyType': 'van',
        'productionStartYear': 1960,
        'displayOrder': 51
      },
      {
        'id': 'daihatsu_copen',
        'name': 'コペン',
        'nameEn': 'Copen',
        'bodyType': 'convertible',
        'productionStartYear': 2002,
        'displayOrder': 52
      },
      {
        'id': 'daihatsu_thor',
        'name': 'トール',
        'nameEn': 'Thor',
        'bodyType': 'minivan',
        'productionStartYear': 2016,
        'displayOrder': 53
      },
      {
        'id': 'daihatsu_wake',
        'name': 'ウェイク',
        'nameEn': 'Wake',
        'bodyType': 'kei',
        'productionStartYear': 2014,
        'displayOrder': 54
      },
      {
        'id': 'daihatsu_cast',
        'name': 'キャスト',
        'nameEn': 'Cast',
        'bodyType': 'kei',
        'productionStartYear': 2015,
        'displayOrder': 55
      },
      {
        'id': 'daihatsu_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
      },
    ],
    'mitsubishi': [
      {
        'id': 'mitsubishi_outlander',
        'name': 'アウトランダー',
        'nameEn': 'Outlander',
        'bodyType': 'suv',
        'productionStartYear': 2001,
        'displayOrder': 1
      },
      {
        'id': 'mitsubishi_delica',
        'name': 'デリカ',
        'nameEn': 'Delica',
        'bodyType': 'minivan',
        'productionStartYear': 1968,
        'displayOrder': 2
      },
      {
        'id': 'mitsubishi_eclipse',
        'name': 'エクリプスクロス',
        'nameEn': 'Eclipse Cross',
        'bodyType': 'suv',
        'productionStartYear': 2017,
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
        'displayOrder': 50
      },
      {
        'id': 'mitsubishi_delica_mini',
        'name': 'デリカミニ',
        'nameEn': 'Delica Mini',
        'bodyType': 'kei',
        'productionStartYear': 2023,
        'displayOrder': 51
      },
      {
        'id': 'mitsubishi_mirage',
        'name': 'ミラージュ',
        'nameEn': 'Mirage',
        'bodyType': 'hatchback',
        'productionStartYear': 1978,
        'displayOrder': 52
      },
      {
        'id': 'mitsubishi_rvr',
        'name': 'RVR',
        'nameEn': 'RVR',
        'bodyType': 'suv',
        'productionStartYear': 1991,
        'displayOrder': 53
      },
      {
        'id': 'mitsubishi_pajero',
        'name': 'パジェロ',
        'nameEn': 'Pajero',
        'bodyType': 'suv',
        'productionStartYear': 1982,
        'displayOrder': 54
      },
      {
        'id': 'mitsubishi_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
      },
    ],
    'lexus': [
      {
        'id': 'lexus_rx',
        'name': 'RX',
        'nameEn': 'RX',
        'bodyType': 'suv',
        'productionStartYear': 1998,
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
        'productionStartYear': 1999,
        'displayOrder': 3
      },
      {
        'id': 'lexus_es',
        'name': 'ES',
        'nameEn': 'ES',
        'bodyType': 'sedan',
        'productionStartYear': 1989,
        'displayOrder': 4
      },
      {
        'id': 'lexus_lx',
        'name': 'LX',
        'nameEn': 'LX',
        'bodyType': 'suv',
        'productionStartYear': 1996,
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
        'productionStartYear': 1989,
        'displayOrder': 50
      },
      {
        'id': 'lexus_rc',
        'name': 'RC',
        'nameEn': 'RC',
        'bodyType': 'coupe',
        'productionStartYear': 2014,
        'displayOrder': 51
      },
      {
        'id': 'lexus_rz',
        'name': 'RZ',
        'nameEn': 'RZ',
        'bodyType': 'suv',
        'productionStartYear': 2022,
        'displayOrder': 52
      },
      {
        'id': 'lexus_lm',
        'name': 'LM',
        'nameEn': 'LM',
        'bodyType': 'minivan',
        'productionStartYear': 2019,
        'displayOrder': 53
      },
      {
        'id': 'lexus_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
      },
    ],
    'mercedes': [
      {
        'id': 'mercedes_cclass',
        'name': 'Cクラス',
        'nameEn': 'C-Class',
        'bodyType': 'sedan',
        'productionStartYear': 1993,
        'displayOrder': 1
      },
      {
        'id': 'mercedes_eclass',
        'name': 'Eクラス',
        'nameEn': 'E-Class',
        'bodyType': 'sedan',
        'productionStartYear': 1953,
        'displayOrder': 2
      },
      {
        'id': 'mercedes_aclass',
        'name': 'Aクラス',
        'nameEn': 'A-Class',
        'bodyType': 'hatchback',
        'productionStartYear': 1997,
        'displayOrder': 3
      },
      {
        'id': 'mercedes_glc',
        'name': 'GLC',
        'nameEn': 'GLC',
        'bodyType': 'suv',
        'productionStartYear': 2015,
        'displayOrder': 4
      },
      {
        'id': 'mercedes_gla',
        'name': 'GLA',
        'nameEn': 'GLA',
        'bodyType': 'suv',
        'productionStartYear': 2013,
        'displayOrder': 5
      },
      {
        'id': 'mercedes_cla',
        'name': 'CLA',
        'nameEn': 'CLA',
        'bodyType': 'sedan',
        'productionStartYear': 2013,
        'displayOrder': 6
      },
      {
        'id': 'mercedes_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'bmw': [
      {
        'id': 'bmw_series3',
        'name': '3シリーズ',
        'nameEn': '3 Series',
        'bodyType': 'sedan',
        'productionStartYear': 1975,
        'displayOrder': 1
      },
      {
        'id': 'bmw_series5',
        'name': '5シリーズ',
        'nameEn': '5 Series',
        'bodyType': 'sedan',
        'productionStartYear': 1972,
        'displayOrder': 2
      },
      {
        'id': 'bmw_series1',
        'name': '1シリーズ',
        'nameEn': '1 Series',
        'bodyType': 'hatchback',
        'productionStartYear': 2004,
        'displayOrder': 3
      },
      {
        'id': 'bmw_x1',
        'name': 'X1',
        'nameEn': 'X1',
        'bodyType': 'suv',
        'productionStartYear': 2009,
        'displayOrder': 4
      },
      {
        'id': 'bmw_x3',
        'name': 'X3',
        'nameEn': 'X3',
        'bodyType': 'suv',
        'productionStartYear': 2003,
        'displayOrder': 5
      },
      {
        'id': 'bmw_x5',
        'name': 'X5',
        'nameEn': 'X5',
        'bodyType': 'suv',
        'productionStartYear': 1999,
        'displayOrder': 6
      },
      {
        'id': 'bmw_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'volkswagen': [
      {
        'id': 'volkswagen_golf',
        'name': 'ゴルフ',
        'nameEn': 'Golf',
        'bodyType': 'hatchback',
        'productionStartYear': 1974,
        'displayOrder': 1
      },
      {
        'id': 'volkswagen_polo',
        'name': 'ポロ',
        'nameEn': 'Polo',
        'bodyType': 'hatchback',
        'productionStartYear': 1975,
        'displayOrder': 2
      },
      {
        'id': 'volkswagen_tcross',
        'name': 'T-Cross',
        'nameEn': 'T-Cross',
        'bodyType': 'suv',
        'productionStartYear': 2019,
        'displayOrder': 3
      },
      {
        'id': 'volkswagen_tiguan',
        'name': 'ティグアン',
        'nameEn': 'Tiguan',
        'bodyType': 'suv',
        'productionStartYear': 2007,
        'displayOrder': 4
      },
      {
        'id': 'volkswagen_passat',
        'name': 'パサート',
        'nameEn': 'Passat',
        'bodyType': 'sedan',
        'productionStartYear': 1973,
        'displayOrder': 5
      },
      {
        'id': 'volkswagen_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'audi': [
      {
        'id': 'audi_a3',
        'name': 'A3',
        'nameEn': 'A3',
        'bodyType': 'hatchback',
        'productionStartYear': 1996,
        'displayOrder': 1
      },
      {
        'id': 'audi_a4',
        'name': 'A4',
        'nameEn': 'A4',
        'bodyType': 'sedan',
        'productionStartYear': 1994,
        'displayOrder': 2
      },
      {
        'id': 'audi_q3',
        'name': 'Q3',
        'nameEn': 'Q3',
        'bodyType': 'suv',
        'productionStartYear': 2011,
        'displayOrder': 3
      },
      {
        'id': 'audi_q5',
        'name': 'Q5',
        'nameEn': 'Q5',
        'bodyType': 'suv',
        'productionStartYear': 2008,
        'displayOrder': 4
      },
      {
        'id': 'audi_a1',
        'name': 'A1',
        'nameEn': 'A1',
        'bodyType': 'hatchback',
        'productionStartYear': 2010,
        'displayOrder': 5
      },
      {
        'id': 'audi_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'volvo': [
      {
        'id': 'volvo_xc40',
        'name': 'XC40',
        'nameEn': 'XC40',
        'bodyType': 'suv',
        'productionStartYear': 2017,
        'displayOrder': 1
      },
      {
        'id': 'volvo_xc60',
        'name': 'XC60',
        'nameEn': 'XC60',
        'bodyType': 'suv',
        'productionStartYear': 2008,
        'displayOrder': 2
      },
      {
        'id': 'volvo_xc90',
        'name': 'XC90',
        'nameEn': 'XC90',
        'bodyType': 'suv',
        'productionStartYear': 2002,
        'displayOrder': 3
      },
      {
        'id': 'volvo_v60',
        'name': 'V60',
        'nameEn': 'V60',
        'bodyType': 'wagon',
        'productionStartYear': 2010,
        'displayOrder': 4
      },
      {
        'id': 'volvo_v40',
        'name': 'V40',
        'nameEn': 'V40',
        'bodyType': 'hatchback',
        'productionStartYear': 2012,
        'displayOrder': 5
      },
      {
        'id': 'volvo_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'mini': [
      {
        'id': 'mini_mini3door',
        'name': '3ドア',
        'nameEn': '3 Door',
        'bodyType': 'hatchback',
        'productionStartYear': 2001,
        'displayOrder': 1
      },
      {
        'id': 'mini_crossover',
        'name': 'クロスオーバー',
        'nameEn': 'Crossover',
        'bodyType': 'suv',
        'productionStartYear': 2010,
        'displayOrder': 2
      },
      {
        'id': 'mini_clubman',
        'name': 'クラブマン',
        'nameEn': 'Clubman',
        'bodyType': 'wagon',
        'productionStartYear': 2007,
        'displayOrder': 3
      },
      {
        'id': 'mini_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'tesla': [
      {
        'id': 'tesla_model3',
        'name': 'モデル3',
        'nameEn': 'Model 3',
        'bodyType': 'sedan',
        'productionStartYear': 2017,
        'displayOrder': 1
      },
      {
        'id': 'tesla_modely',
        'name': 'モデルY',
        'nameEn': 'Model Y',
        'bodyType': 'suv',
        'productionStartYear': 2020,
        'displayOrder': 2
      },
      {
        'id': 'tesla_models',
        'name': 'モデルS',
        'nameEn': 'Model S',
        'bodyType': 'sedan',
        'productionStartYear': 2012,
        'displayOrder': 3
      },
      {
        'id': 'tesla_modelx',
        'name': 'モデルX',
        'nameEn': 'Model X',
        'bodyType': 'suv',
        'productionStartYear': 2015,
        'displayOrder': 4
      },
      {
        'id': 'tesla_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'peugeot': [
      {
        'id': 'peugeot_p208',
        'name': '208',
        'nameEn': '208',
        'bodyType': 'hatchback',
        'productionStartYear': 2012,
        'displayOrder': 1
      },
      {
        'id': 'peugeot_p308',
        'name': '308',
        'nameEn': '308',
        'bodyType': 'hatchback',
        'productionStartYear': 2007,
        'displayOrder': 2
      },
      {
        'id': 'peugeot_p2008',
        'name': '2008',
        'nameEn': '2008',
        'bodyType': 'suv',
        'productionStartYear': 2013,
        'displayOrder': 3
      },
      {
        'id': 'peugeot_p3008',
        'name': '3008',
        'nameEn': '3008',
        'bodyType': 'suv',
        'productionStartYear': 2009,
        'displayOrder': 4
      },
      {
        'id': 'peugeot_other',
        'name': 'その他',
        'nameEn': 'Other',
        'bodyType': 'other',
        'productionStartYear': 1900,
        'displayOrder': 100
      },
    ],
    'other': [
      {
        'id': 'other_other',
        'name': 'その他',
        'nameEn': 'Other',
        'displayOrder': 100
      },
    ],
  };

  /// Common grades that apply to most models
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

  /// Get common grades as VehicleGrade list
  static List<VehicleGrade> getCommonGrades(String modelId) {
    return commonGrades
        .map((data) => VehicleGrade.fromMap({
              ...data,
              'modelId': modelId,
            }, '${modelId}_${data['id']}'))
        .toList();
  }
}
