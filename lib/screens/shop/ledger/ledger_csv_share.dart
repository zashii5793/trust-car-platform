import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// 書き出した CSV を店の人に渡す関数。テストで差し替える。
///
/// 渡せたら true。共有の画面を閉じて取り消したときは false
/// （そのときは「案内した日」を付けない）。
typedef CsvSharer = Future<bool> Function({
  required String csv,
  required String fileName,
  required String subject,
});

/// 既定の渡し方。
///
/// - モバイル: 一時ファイルに書いて共有シートを出す。**渡したら消す**
///   （名前・住所・電話が入る。平文を端末に残さない。整備記録の書き出しと同じ）
/// - Web: ファイルとしてダウンロードさせる（店のパソコンで Excel に開く）。
///   share_plus は、ブラウザが共有に対応していなければダウンロードに切り替える
Future<bool> shareLedgerCsv({
  required String csv,
  required String fileName,
  required String subject,
}) async {
  if (kIsWeb) {
    final result = await Share.shareXFiles(
      [
        XFile.fromData(
          Uint8List.fromList(utf8.encode(csv)),
          mimeType: 'text/csv',
          name: fileName,
        ),
      ],
      subject: subject,
      fileNameOverrides: [fileName],
    );
    return result.status != ShareResultStatus.dismissed;
  }

  File? file;
  try {
    final dir = await getTemporaryDirectory();
    file = File('${dir.path}/$fileName');
    await file.writeAsString(csv);
    final result = await Share.shareXFiles(
      [XFile(file.path, mimeType: 'text/csv')],
      subject: subject,
    );
    return result.status != ShareResultStatus.dismissed;
  } finally {
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {}
  }
}

/// ファイル名に付ける日付（20260930）。
String ledgerFileStamp(DateTime d) => '${d.year}'
    '${d.month.toString().padLeft(2, '0')}'
    '${d.day.toString().padLeft(2, '0')}';
