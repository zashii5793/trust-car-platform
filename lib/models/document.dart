import 'package:cloud_firestore/cloud_firestore.dart';

/// 書類種別
enum DocumentType {
  // 車両関連書類
  vehicleRegistration('車検証'),
  liabilityInsuranceCert('自賠責保険証明書'),
  voluntaryInsuranceCert('任意保険証券'),
  inspectionRecord('点検整備記録簿'),

  // 取引関連書類
  estimate('見積書'),
  invoice('請求書'),
  receipt('領収書'),

  // 車検関連書類
  safetyStandardsCert('保安基準適合証'),
  inspectionCert('車検合格証'),

  // その他書類
  contract('契約書'),
  consentForm('同意書'),
  warranty('保証書'),
  manual('取扱説明書'),
  other('その他');

  final String displayName;
  const DocumentType(this.displayName);

  static DocumentType fromString(String? value) {
    if (value == null) return DocumentType.other;
    try {
      return DocumentType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return DocumentType.other;
    }
  }
}

/// ファイル形式
enum FileMimeType {
  pdf('application/pdf', 'PDF'),
  jpeg('image/jpeg', 'JPEG画像'),
  png('image/png', 'PNG画像'),
  webp('image/webp', 'WebP画像'),
  other('application/octet-stream', 'その他');

  final String mimeType;
  final String displayName;
  const FileMimeType(this.mimeType, this.displayName);

  static FileMimeType fromMimeType(String? mimeType) {
    if (mimeType == null) return FileMimeType.other;
    try {
      return FileMimeType.values.firstWhere((e) => e.mimeType == mimeType);
    } catch (_) {
      return FileMimeType.other;
    }
  }

  static FileMimeType fromString(String? value) {
    if (value == null) return FileMimeType.other;
    try {
      return FileMimeType.values.firstWhere((e) => e.name == value);
    } catch (_) {
      return FileMimeType.other;
    }
  }
}

/// 書類モデル
class Document {
  final String id;
  final String userId;
  final String? vehicleId;                 // 車両に紐付く場合
  final String? maintenanceRecordId;       // 整備記録に紐付く場合
  final String? invoiceId;                 // 請求書に紐付く場合

  final DocumentType type;
  final String title;                      // タイトル
  final String? description;               // 説明
  final String fileUrl;                    // ファイルURL (Firebase Storage)
  final String? thumbnailUrl;              // サムネイルURL（画像の場合）
  final FileMimeType mimeType;             // ファイル形式
  final int? fileSize;                     // ファイルサイズ（バイト）

  final DateTime? documentDate;            // 書類の日付（発行日等）
  final DateTime? expiryDate;              // 有効期限（保険証など）

  final String? uploadedBy;                // アップロード者ID
  final String? uploadedByName;            // アップロード者名
  final DateTime uploadedAt;               // アップロード日時

  final bool isArchived;                   // アーカイブ済みか
  final Map<String, dynamic>? metadata;    // その他メタデータ

  final DateTime createdAt;
  final DateTime updatedAt;

  const Document({
    required this.id,
    required this.userId,
    this.vehicleId,
    this.maintenanceRecordId,
    this.invoiceId,
    required this.type,
    required this.title,
    this.description,
    required this.fileUrl,
    this.thumbnailUrl,
    required this.mimeType,
    this.fileSize,
    this.documentDate,
    this.expiryDate,
    this.uploadedBy,
    this.uploadedByName,
    required this.uploadedAt,
    this.isArchived = false,
    this.metadata,
    required this.createdAt,
    required this.updatedAt,
  });

  /// 画像ファイルかどうか
  bool get isImage => [
    FileMimeType.jpeg,
    FileMimeType.png,
    FileMimeType.webp,
  ].contains(mimeType);

  /// PDFかどうか
  bool get isPdf => mimeType == FileMimeType.pdf;

  /// 有効期限切れか
  bool get isExpired {
    if (expiryDate == null) return false;
    return DateTime.now().isAfter(expiryDate!);
  }

  /// 有効期限が近いか（30日以内）
  bool get isExpiringSoon {
    if (expiryDate == null) return false;
    if (isExpired) return false;
    final days = expiryDate!.difference(DateTime.now()).inDays;
    return days <= 30;
  }

  /// ファイルサイズの表示用文字列
  String get fileSizeDisplay {
    if (fileSize == null) return '不明';
    if (fileSize! < 1024) return '$fileSize B';
    if (fileSize! < 1024 * 1024) return '${(fileSize! / 1024).toStringAsFixed(1)} KB';
    return '${(fileSize! / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  factory Document.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Document(
      id: doc.id,
      userId: data['userId'] ?? '',
      vehicleId: data['vehicleId'],
      maintenanceRecordId: data['maintenanceRecordId'],
      invoiceId: data['invoiceId'],
      type: DocumentType.fromString(data['type']),
      title: data['title'] ?? '',
      description: data['description'],
      fileUrl: data['fileUrl'] ?? '',
      thumbnailUrl: data['thumbnailUrl'],
      mimeType: FileMimeType.fromString(data['mimeType']),
      fileSize: data['fileSize'],
      documentDate: (data['documentDate'] as Timestamp?)?.toDate(),
      expiryDate: (data['expiryDate'] as Timestamp?)?.toDate(),
      uploadedBy: data['uploadedBy'],
      uploadedByName: data['uploadedByName'],
      uploadedAt: (data['uploadedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isArchived: data['isArchived'] ?? false,
      metadata: data['metadata'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vehicleId': vehicleId,
      'maintenanceRecordId': maintenanceRecordId,
      'invoiceId': invoiceId,
      'type': type.name,
      'title': title,
      'description': description,
      'fileUrl': fileUrl,
      'thumbnailUrl': thumbnailUrl,
      'mimeType': mimeType.name,
      'fileSize': fileSize,
      'documentDate': documentDate != null ? Timestamp.fromDate(documentDate!) : null,
      'expiryDate': expiryDate != null ? Timestamp.fromDate(expiryDate!) : null,
      'uploadedBy': uploadedBy,
      'uploadedByName': uploadedByName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isArchived': isArchived,
      'metadata': metadata,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  Document copyWith({
    String? id,
    String? userId,
    String? vehicleId,
    String? maintenanceRecordId,
    String? invoiceId,
    DocumentType? type,
    String? title,
    String? description,
    String? fileUrl,
    String? thumbnailUrl,
    FileMimeType? mimeType,
    int? fileSize,
    DateTime? documentDate,
    DateTime? expiryDate,
    String? uploadedBy,
    String? uploadedByName,
    DateTime? uploadedAt,
    bool? isArchived,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Document(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleId: vehicleId ?? this.vehicleId,
      maintenanceRecordId: maintenanceRecordId ?? this.maintenanceRecordId,
      invoiceId: invoiceId ?? this.invoiceId,
      type: type ?? this.type,
      title: title ?? this.title,
      description: description ?? this.description,
      fileUrl: fileUrl ?? this.fileUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      mimeType: mimeType ?? this.mimeType,
      fileSize: fileSize ?? this.fileSize,
      documentDate: documentDate ?? this.documentDate,
      expiryDate: expiryDate ?? this.expiryDate,
      uploadedBy: uploadedBy ?? this.uploadedBy,
      uploadedByName: uploadedByName ?? this.uploadedByName,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      isArchived: isArchived ?? this.isArchived,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'Document(id: $id, type: ${type.displayName}, title: $title)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Document && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
