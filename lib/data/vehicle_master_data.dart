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
      {'id': 'toyota_prius', 'name': 'プリウス', 'nameEn': 'Prius', 'bodyType': 'hatchback', 'productionStartYear': 1997, 'displayOrder': 1},
      {'id': 'toyota_rav4', 'name': 'RAV4', 'nameEn': 'RAV4', 'bodyType': 'suv', 'productionStartYear': 1994, 'displayOrder': 2},
      {'id': 'toyota_corolla', 'name': 'カローラ', 'nameEn': 'Corolla', 'bodyType': 'sedan', 'productionStartYear': 1966, 'displayOrder': 3},
      {'id': 'toyota_alphard', 'name': 'アルファード', 'nameEn': 'Alphard', 'bodyType': 'minivan', 'productionStartYear': 2002, 'displayOrder': 4},
      {'id': 'toyota_voxy', 'name': 'ヴォクシー', 'nameEn': 'Voxy', 'bodyType': 'minivan', 'productionStartYear': 2001, 'displayOrder': 5},
      {'id': 'toyota_crown', 'name': 'クラウン', 'nameEn': 'Crown', 'bodyType': 'sedan', 'productionStartYear': 1955, 'displayOrder': 6},
      {'id': 'toyota_harrier', 'name': 'ハリアー', 'nameEn': 'Harrier', 'bodyType': 'suv', 'productionStartYear': 1997, 'displayOrder': 7},
      {'id': 'toyota_yaris', 'name': 'ヤリス', 'nameEn': 'Yaris', 'bodyType': 'hatchback', 'productionStartYear': 2020, 'displayOrder': 8},
      {'id': 'toyota_aqua', 'name': 'アクア', 'nameEn': 'Aqua', 'bodyType': 'hatchback', 'productionStartYear': 2011, 'displayOrder': 9},
      {'id': 'toyota_sienta', 'name': 'シエンタ', 'nameEn': 'Sienta', 'bodyType': 'minivan', 'productionStartYear': 2003, 'displayOrder': 10},
      {'id': 'toyota_landcruiser', 'name': 'ランドクルーザー', 'nameEn': 'Land Cruiser', 'bodyType': 'suv', 'productionStartYear': 1951, 'displayOrder': 11},
      {'id': 'toyota_86', 'name': 'GR86', 'nameEn': 'GR86', 'bodyType': 'coupe', 'productionStartYear': 2012, 'displayOrder': 12},
      {'id': 'toyota_supra', 'name': 'スープラ', 'nameEn': 'Supra', 'bodyType': 'coupe', 'productionStartYear': 2019, 'displayOrder': 13},
      {'id': 'toyota_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'honda': [
      {'id': 'honda_fit', 'name': 'フィット', 'nameEn': 'Fit', 'bodyType': 'hatchback', 'productionStartYear': 2001, 'displayOrder': 1},
      {'id': 'honda_vezel', 'name': 'ヴェゼル', 'nameEn': 'Vezel', 'bodyType': 'suv', 'productionStartYear': 2013, 'displayOrder': 2},
      {'id': 'honda_freed', 'name': 'フリード', 'nameEn': 'Freed', 'bodyType': 'minivan', 'productionStartYear': 2008, 'displayOrder': 3},
      {'id': 'honda_stepwgn', 'name': 'ステップワゴン', 'nameEn': 'Step WGN', 'bodyType': 'minivan', 'productionStartYear': 1996, 'displayOrder': 4},
      {'id': 'honda_nbox', 'name': 'N-BOX', 'nameEn': 'N-BOX', 'bodyType': 'kei', 'productionStartYear': 2011, 'displayOrder': 5},
      {'id': 'honda_accord', 'name': 'アコード', 'nameEn': 'Accord', 'bodyType': 'sedan', 'productionStartYear': 1976, 'displayOrder': 6},
      {'id': 'honda_civic', 'name': 'シビック', 'nameEn': 'Civic', 'bodyType': 'sedan', 'productionStartYear': 1972, 'displayOrder': 7},
      {'id': 'honda_crv', 'name': 'CR-V', 'nameEn': 'CR-V', 'bodyType': 'suv', 'productionStartYear': 1995, 'displayOrder': 8},
      {'id': 'honda_odyssey', 'name': 'オデッセイ', 'nameEn': 'Odyssey', 'bodyType': 'minivan', 'productionStartYear': 1994, 'displayOrder': 9},
      {'id': 'honda_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'nissan': [
      {'id': 'nissan_note', 'name': 'ノート', 'nameEn': 'Note', 'bodyType': 'hatchback', 'productionStartYear': 2004, 'displayOrder': 1},
      {'id': 'nissan_serena', 'name': 'セレナ', 'nameEn': 'Serena', 'bodyType': 'minivan', 'productionStartYear': 1991, 'displayOrder': 2},
      {'id': 'nissan_xtrail', 'name': 'エクストレイル', 'nameEn': 'X-Trail', 'bodyType': 'suv', 'productionStartYear': 2000, 'displayOrder': 3},
      {'id': 'nissan_leaf', 'name': 'リーフ', 'nameEn': 'Leaf', 'bodyType': 'hatchback', 'productionStartYear': 2010, 'displayOrder': 4},
      {'id': 'nissan_kicks', 'name': 'キックス', 'nameEn': 'Kicks', 'bodyType': 'suv', 'productionStartYear': 2020, 'displayOrder': 5},
      {'id': 'nissan_skyline', 'name': 'スカイライン', 'nameEn': 'Skyline', 'bodyType': 'sedan', 'productionStartYear': 1957, 'displayOrder': 6},
      {'id': 'nissan_fairladyz', 'name': 'フェアレディZ', 'nameEn': 'Fairlady Z', 'bodyType': 'coupe', 'productionStartYear': 1969, 'displayOrder': 7},
      {'id': 'nissan_gtr', 'name': 'GT-R', 'nameEn': 'GT-R', 'bodyType': 'coupe', 'productionStartYear': 2007, 'displayOrder': 8},
      {'id': 'nissan_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'mazda': [
      {'id': 'mazda_cx5', 'name': 'CX-5', 'nameEn': 'CX-5', 'bodyType': 'suv', 'productionStartYear': 2012, 'displayOrder': 1},
      {'id': 'mazda_cx30', 'name': 'CX-30', 'nameEn': 'CX-30', 'bodyType': 'suv', 'productionStartYear': 2019, 'displayOrder': 2},
      {'id': 'mazda_mazda3', 'name': 'MAZDA3', 'nameEn': 'Mazda3', 'bodyType': 'hatchback', 'productionStartYear': 2003, 'displayOrder': 3},
      {'id': 'mazda_cx8', 'name': 'CX-8', 'nameEn': 'CX-8', 'bodyType': 'suv', 'productionStartYear': 2017, 'displayOrder': 4},
      {'id': 'mazda_roadster', 'name': 'ロードスター', 'nameEn': 'MX-5 Miata', 'bodyType': 'convertible', 'productionStartYear': 1989, 'displayOrder': 5},
      {'id': 'mazda_cx60', 'name': 'CX-60', 'nameEn': 'CX-60', 'bodyType': 'suv', 'productionStartYear': 2022, 'displayOrder': 6},
      {'id': 'mazda_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'subaru': [
      {'id': 'subaru_forester', 'name': 'フォレスター', 'nameEn': 'Forester', 'bodyType': 'suv', 'productionStartYear': 1997, 'displayOrder': 1},
      {'id': 'subaru_impreza', 'name': 'インプレッサ', 'nameEn': 'Impreza', 'bodyType': 'hatchback', 'productionStartYear': 1992, 'displayOrder': 2},
      {'id': 'subaru_levorg', 'name': 'レヴォーグ', 'nameEn': 'Levorg', 'bodyType': 'wagon', 'productionStartYear': 2014, 'displayOrder': 3},
      {'id': 'subaru_outback', 'name': 'アウトバック', 'nameEn': 'Outback', 'bodyType': 'wagon', 'productionStartYear': 1994, 'displayOrder': 4},
      {'id': 'subaru_xv', 'name': 'XV', 'nameEn': 'Crosstrek', 'bodyType': 'suv', 'productionStartYear': 2012, 'displayOrder': 5},
      {'id': 'subaru_wrx', 'name': 'WRX S4', 'nameEn': 'WRX', 'bodyType': 'sedan', 'productionStartYear': 2014, 'displayOrder': 6},
      {'id': 'subaru_brz', 'name': 'BRZ', 'nameEn': 'BRZ', 'bodyType': 'coupe', 'productionStartYear': 2012, 'displayOrder': 7},
      {'id': 'subaru_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'suzuki': [
      {'id': 'suzuki_jimny', 'name': 'ジムニー', 'nameEn': 'Jimny', 'bodyType': 'suv', 'productionStartYear': 1970, 'displayOrder': 1},
      {'id': 'suzuki_swift', 'name': 'スイフト', 'nameEn': 'Swift', 'bodyType': 'hatchback', 'productionStartYear': 2000, 'displayOrder': 2},
      {'id': 'suzuki_hustler', 'name': 'ハスラー', 'nameEn': 'Hustler', 'bodyType': 'kei', 'productionStartYear': 2014, 'displayOrder': 3},
      {'id': 'suzuki_spacia', 'name': 'スペーシア', 'nameEn': 'Spacia', 'bodyType': 'kei', 'productionStartYear': 2013, 'displayOrder': 4},
      {'id': 'suzuki_alto', 'name': 'アルト', 'nameEn': 'Alto', 'bodyType': 'kei', 'productionStartYear': 1979, 'displayOrder': 5},
      {'id': 'suzuki_solio', 'name': 'ソリオ', 'nameEn': 'Solio', 'bodyType': 'minivan', 'productionStartYear': 2010, 'displayOrder': 6},
      {'id': 'suzuki_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'daihatsu': [
      {'id': 'daihatsu_tanto', 'name': 'タント', 'nameEn': 'Tanto', 'bodyType': 'kei', 'productionStartYear': 2003, 'displayOrder': 1},
      {'id': 'daihatsu_move', 'name': 'ムーヴ', 'nameEn': 'Move', 'bodyType': 'kei', 'productionStartYear': 1995, 'displayOrder': 2},
      {'id': 'daihatsu_rocky', 'name': 'ロッキー', 'nameEn': 'Rocky', 'bodyType': 'suv', 'productionStartYear': 2019, 'displayOrder': 3},
      {'id': 'daihatsu_mira', 'name': 'ミラ', 'nameEn': 'Mira', 'bodyType': 'kei', 'productionStartYear': 1980, 'displayOrder': 4},
      {'id': 'daihatsu_taft', 'name': 'タフト', 'nameEn': 'Taft', 'bodyType': 'kei', 'productionStartYear': 2020, 'displayOrder': 5},
      {'id': 'daihatsu_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'mitsubishi': [
      {'id': 'mitsubishi_outlander', 'name': 'アウトランダー', 'nameEn': 'Outlander', 'bodyType': 'suv', 'productionStartYear': 2001, 'displayOrder': 1},
      {'id': 'mitsubishi_delica', 'name': 'デリカ', 'nameEn': 'Delica', 'bodyType': 'minivan', 'productionStartYear': 1968, 'displayOrder': 2},
      {'id': 'mitsubishi_eclipse', 'name': 'エクリプスクロス', 'nameEn': 'Eclipse Cross', 'bodyType': 'suv', 'productionStartYear': 2017, 'displayOrder': 3},
      {'id': 'mitsubishi_ek', 'name': 'eKワゴン', 'nameEn': 'eK Wagon', 'bodyType': 'kei', 'productionStartYear': 2001, 'displayOrder': 4},
      {'id': 'mitsubishi_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'lexus': [
      {'id': 'lexus_rx', 'name': 'RX', 'nameEn': 'RX', 'bodyType': 'suv', 'productionStartYear': 1998, 'displayOrder': 1},
      {'id': 'lexus_nx', 'name': 'NX', 'nameEn': 'NX', 'bodyType': 'suv', 'productionStartYear': 2014, 'displayOrder': 2},
      {'id': 'lexus_is', 'name': 'IS', 'nameEn': 'IS', 'bodyType': 'sedan', 'productionStartYear': 1999, 'displayOrder': 3},
      {'id': 'lexus_es', 'name': 'ES', 'nameEn': 'ES', 'bodyType': 'sedan', 'productionStartYear': 1989, 'displayOrder': 4},
      {'id': 'lexus_lx', 'name': 'LX', 'nameEn': 'LX', 'bodyType': 'suv', 'productionStartYear': 1996, 'displayOrder': 5},
      {'id': 'lexus_ux', 'name': 'UX', 'nameEn': 'UX', 'bodyType': 'suv', 'productionStartYear': 2018, 'displayOrder': 6},
      {'id': 'lexus_lc', 'name': 'LC', 'nameEn': 'LC', 'bodyType': 'coupe', 'productionStartYear': 2017, 'displayOrder': 7},
      {'id': 'lexus_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
    ],
    'other': [
      {'id': 'other_other', 'name': 'その他', 'nameEn': 'Other', 'displayOrder': 100},
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
    return makers.map((data) => VehicleMaker.fromMap(data, data['id'] as String)).toList();
  }

  /// Get VehicleModel list for a specific maker from static data
  static List<VehicleModel> getModelsForMaker(String makerId) {
    final modelList = models[makerId];
    if (modelList == null) return [];
    return modelList.map((data) => VehicleModel.fromMap({
      ...data,
      'makerId': makerId,
    }, data['id'] as String)).toList();
  }

  /// Get common grades as VehicleGrade list
  static List<VehicleGrade> getCommonGrades(String modelId) {
    return commonGrades.map((data) => VehicleGrade.fromMap({
      ...data,
      'modelId': modelId,
    }, '${modelId}_${data['id']}')).toList();
  }
}
