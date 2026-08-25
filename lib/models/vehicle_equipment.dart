/// 車両のオプション・装備。
///
/// 設計方針:
/// - ナビ / ドライブレコーダー / ETC は **メーカーと型番を持つ**。
///   「付いている / 付いていない」だけでは、買い替え相談も売却査定も
///   整備依頼もできないため。
/// - メーカーは候補を出すが、**カタログに無いものを手入力できる**こと。
///   メーカー・車種・グレードと同じ方針。一覧を網羅できる前提を置かない。
/// - その他の装備（バックカメラ、サンルーフ等）は有無のみのフラグ。
/// - 上記に当てはまらないものは [VehicleEquipment.others] に自由記述で入る。
library;

/// 有無だけを記録する装備。
///
/// 名前は Firestore に保存されるため、**変更・削除してはいけない**。
/// 未知の名前は読み込み時に無視されるので、追加は安全。
enum VehicleFeature {
  backCamera('バックカメラ'),
  aroundViewMonitor('全方位カメラ'),
  etcCard('ETC2.0'),
  cruiseControl('クルーズコントロール'),
  collisionMitigationBrake('衝突被害軽減ブレーキ'),
  laneKeepAssist('車線逸脱防止支援'),
  parkingSensor('コーナーセンサー'),
  keylessEntry('スマートキー'),
  powerSlideDoor('電動スライドドア'),
  powerBackDoor('電動バックドア'),
  sunroof('サンルーフ'),
  leatherSeat('本革シート'),
  seatHeater('シートヒーター'),
  alloyWheel('アルミホイール'),
  towHitch('けん引フック'),
  studlessTire('スタッドレスタイヤ'),
  roofRack('ルーフレール/キャリア'),
  rearMonitor('後席モニター');

  const VehicleFeature(this.label);

  /// 画面に出す日本語名。
  final String label;

  /// 保存済みの名前から復元する。未知の値は null（無視される）。
  static VehicleFeature? fromString(String? value) {
    if (value == null) return null;
    for (final f in VehicleFeature.values) {
      if (f.name == value) return f;
    }
    return null;
  }
}

/// メーカー・型番を持つ装備1点（ナビ、ドラレコ、ETC）。
class EquipmentItem {
  /// 装備しているか。
  final bool installed;

  /// メーカー名。候補から選んでもよいし、手入力でもよい。
  final String? _maker;

  /// 型番。カタログを持てないので常に手入力。
  final String? _modelNumber;

  const EquipmentItem({
    this.installed = false,
    String? maker,
    String? modelNumber,
  })  : _maker = maker,
        _modelNumber = modelNumber;

  /// 空白のみ・空文字は「未入力」として扱う。
  String? get maker => _blankToNull(_maker);

  String? get modelNumber => _blankToNull(_modelNumber);

  static String? _blankToNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  /// 何か1つでも入力されているか。
  bool get hasAnyValue => installed || maker != null || modelNumber != null;

  /// 一覧に出す短い表記。
  String get displayLabel {
    final parts = [maker, modelNumber].whereType<String>().toList();
    if (parts.isEmpty) return installed ? '装備あり' : '無し';
    return parts.join(' ');
  }

  factory EquipmentItem.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const EquipmentItem();
    return EquipmentItem(
      installed: map['installed'] is bool ? map['installed'] as bool : false,
      maker: map['maker'] is String ? map['maker'] as String : null,
      modelNumber:
          map['modelNumber'] is String ? map['modelNumber'] as String : null,
    );
  }

  Map<String, dynamic> toMap() => {
        'installed': installed,
        'maker': maker,
        'modelNumber': modelNumber,
      };

  EquipmentItem copyWith({
    bool? installed,
    String? maker,
    String? modelNumber,
  }) =>
      EquipmentItem(
        installed: installed ?? this.installed,
        maker: maker ?? this.maker,
        modelNumber: modelNumber ?? this.modelNumber,
      );

  @override
  bool operator ==(Object other) =>
      other is EquipmentItem &&
      other.installed == installed &&
      other.maker == maker &&
      other.modelNumber == modelNumber;

  @override
  int get hashCode => Object.hash(installed, maker, modelNumber);
}

/// 1台ぶんのオプション・装備一式。
class VehicleEquipment {
  /// カーナビ。
  final EquipmentItem navigation;

  /// ドライブレコーダー。
  final EquipmentItem driveRecorder;

  /// ETC車載器。
  final EquipmentItem etc;

  /// 有無だけの装備。
  final Set<VehicleFeature> features;

  /// 上記に当てはまらない装備の自由記述。
  final List<String> others;

  const VehicleEquipment({
    this.navigation = const EquipmentItem(),
    this.driveRecorder = const EquipmentItem(),
    this.etc = const EquipmentItem(),
    this.features = const {},
    this.others = const [],
  });

  bool get hasAnyValue =>
      navigation.hasAnyValue ||
      driveRecorder.hasAnyValue ||
      etc.hasAnyValue ||
      features.isNotEmpty ||
      others.isNotEmpty;

  /// 車両詳細に並べる装備名の一覧。
  List<String> get summaryLabels {
    final labels = <String>[];
    if (navigation.hasAnyValue) {
      labels.add('カーナビ: ${navigation.displayLabel}');
    }
    if (driveRecorder.hasAnyValue) {
      labels.add('ドライブレコーダー: ${driveRecorder.displayLabel}');
    }
    if (etc.hasAnyValue) {
      labels.add('ETC: ${etc.displayLabel}');
    }
    labels.addAll(features.map((f) => f.label));
    labels.addAll(others);
    return labels;
  }

  factory VehicleEquipment.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const VehicleEquipment();
    return VehicleEquipment(
      navigation: EquipmentItem.fromMap(_asMap(map['navigation'])),
      driveRecorder: EquipmentItem.fromMap(_asMap(map['driveRecorder'])),
      etc: EquipmentItem.fromMap(_asMap(map['etc'])),
      features: _parseFeatures(map['features']),
      others: _parseOthers(map['others']),
    );
  }

  static Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.map((k, v) => MapEntry('$k', v));
    return null;
  }

  static Set<VehicleFeature> _parseFeatures(dynamic value) {
    if (value is! List) return const {};
    return value
        .map((e) => VehicleFeature.fromString(e is String ? e : null))
        .whereType<VehicleFeature>()
        .toSet();
  }

  static List<String> _parseOthers(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toMap() => {
        'navigation': navigation.toMap(),
        'driveRecorder': driveRecorder.toMap(),
        'etc': etc.toMap(),
        'features': features.map((f) => f.name).toList(),
        'others': others,
      };

  @override
  bool operator ==(Object other) {
    if (other is! VehicleEquipment) return false;
    if (other.navigation != navigation ||
        other.driveRecorder != driveRecorder ||
        other.etc != etc) {
      return false;
    }
    if (other.features.length != features.length ||
        !other.features.containsAll(features)) {
      return false;
    }
    if (other.others.length != others.length) return false;
    for (var i = 0; i < others.length; i++) {
      if (other.others[i] != others[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
        navigation,
        driveRecorder,
        etc,
        Object.hashAllUnordered(features),
        Object.hashAll(others),
      );

  VehicleEquipment copyWith({
    EquipmentItem? navigation,
    EquipmentItem? driveRecorder,
    EquipmentItem? etc,
    Set<VehicleFeature>? features,
    List<String>? others,
  }) =>
      VehicleEquipment(
        navigation: navigation ?? this.navigation,
        driveRecorder: driveRecorder ?? this.driveRecorder,
        etc: etc ?? this.etc,
        features: features ?? this.features,
        others: others ?? this.others,
      );
}
