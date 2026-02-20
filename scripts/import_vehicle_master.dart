#!/usr/bin/env dart
// ignore_for_file: avoid_print
/// Vehicle Master CSV → Firestore Import Script
///
/// Usage:
///   dart scripts/import_vehicle_master.dart [--csv data/vehicle_masters.csv] [--dry-run]
///
/// Options:
///   --csv <path>   CSV file path (default: data/vehicle_masters.csv)
///   --dry-run      Preview changes without writing to Firestore
///   --clear        Clear existing Firestore data before import
///
/// CSV Format:
///   type,id,parent_id,name,name_en,body_type,production_start_year,production_end_year,display_order,country
///
/// Requirements:
///   - Firebase service account key at: .env or GOOGLE_APPLICATION_CREDENTIALS
///   - Run from project root
///
/// When to run:
///   - Initial setup: dart scripts/import_vehicle_master.dart
///   - New model year: add row to CSV, then re-run
///   - New maker added: add maker + models to CSV, then re-run

import 'dart:io';

// NOTE: This script uses firebase_admin SDK (Node.js) via shell, OR
// can be adapted to use Firestore REST API directly.
// For Flutter projects, the recommended approach is:
//
// Option A: Use FlutterFire CLI + Dart Firebase Admin (dart_firebase_admin)
// Option B: Use firebase CLI: firebase firestore:import
// Option C: Run as Flutter integration test that calls VehicleMasterService.seedMasterData()
//
// This script implements Option C (safest for Flutter projects):
// It generates a Dart test file that seeds data using the existing VehicleMasterService.

void main(List<String> args) async {
  final csvPath = _getArg(args, '--csv') ?? 'data/vehicle_masters.csv';
  final isDryRun = args.contains('--dry-run');
  final doClear = args.contains('--clear');

  print('=== Trust Car Platform: Vehicle Master Import ===');
  print('CSV: $csvPath');
  if (isDryRun) print('[DRY RUN] No data will be written.');
  print('');

  // Parse CSV
  final file = File(csvPath);
  if (!file.existsSync()) {
    print('ERROR: CSV file not found: $csvPath');
    exit(1);
  }

  final records = _parseCsv(file.readAsStringSync());

  final makers = records.where((r) => r['type'] == 'maker').toList();
  final models = records.where((r) => r['type'] == 'model').toList();
  final grades = records.where((r) => r['type'] == 'grade').toList();

  print('Parsed records:');
  print('  Makers: ${makers.length}');
  print('  Models: ${models.length}');
  print('  Grades: ${grades.length}');
  print('');

  if (isDryRun) {
    print('[DRY RUN] Makers:');
    for (final m in makers) {
      print('  ${m['id']} | ${m['name']} (${m['name_en']}) | country: ${m['country']} | order: ${m['display_order']}');
    }
    print('');
    print('[DRY RUN] Models (first 10):');
    for (final m in models.take(10)) {
      print('  ${m['id']} | ${m['name']} | maker: ${m['parent_id']} | body: ${m['body_type']} | from: ${m['production_start_year']}');
    }
    print('  ... (${models.length} total)');
    print('');
    print('[DRY RUN] Grades:');
    for (final g in grades) {
      print('  ${g['id']} | ${g['name']}');
    }
    print('');
    print('[DRY RUN] Complete. No changes made.');
    return;
  }

  // Generate seed script
  _generateSeedFile(makers, models, grades, doClear);

  print('');
  print('Generated: scripts/_seed_vehicle_master_generated.dart');
  print('');
  print('Next step: Run the app and trigger seed from debug menu,');
  print('OR run the generated integration test:');
  print('  flutter test scripts/_seed_vehicle_master_generated.dart');
  print('');
  print('TIP: VehicleMasterService.seedMasterData() reads from VehicleMasterData');
  print('     (lib/data/vehicle_master_data.dart) and writes to Firestore.');
  print('     Update that file AND this CSV together when adding new models.');
}

/// Parse CSV, skip comment lines and blank lines
List<Map<String, String>> _parseCsv(String content) {
  final lines = content.split('\n');
  final records = <Map<String, String>>[];

  String? headerLine;
  List<String> headers = [];

  for (var line in lines) {
    line = line.trim();
    if (line.isEmpty || line.startsWith('#')) continue;

    if (headerLine == null) {
      headerLine = line;
      headers = line.split(',').map((h) => h.trim()).toList();
      continue;
    }

    // Skip comment-only data lines
    final withoutInlineComment = line.contains('#')
        ? line.substring(0, line.indexOf('#')).trim()
        : line;
    if (withoutInlineComment.isEmpty) continue;

    final values = withoutInlineComment.split(',').map((v) => v.trim()).toList();
    if (values.length < headers.length) {
      // Pad with empty strings
      while (values.length < headers.length) {
        values.add('');
      }
    }

    final record = <String, String>{};
    for (var i = 0; i < headers.length; i++) {
      record[headers[i]] = i < values.length ? values[i] : '';
    }

    if (record['type']?.isNotEmpty == true && record['id']?.isNotEmpty == true) {
      records.add(record);
    }
  }

  return records;
}

void _generateSeedFile(
  List<Map<String, String>> makers,
  List<Map<String, String>> models,
  List<Map<String, String>> grades,
  bool doClear,
) {
  final buf = StringBuffer();
  buf.writeln('// AUTO-GENERATED by scripts/import_vehicle_master.dart');
  buf.writeln('// Generated at: ${DateTime.now().toIso8601String()}');
  buf.writeln('// DO NOT EDIT MANUALLY — regenerate from CSV instead');
  buf.writeln('');
  buf.writeln('// To apply this seed:');
  buf.writeln('// 1. Ensure Firebase emulator is running (or use production with caution)');
  buf.writeln('// 2. Call VehicleMasterSeeder.seed() from your app or test');
  buf.writeln('');
  buf.writeln("import 'package:cloud_firestore/cloud_firestore.dart';");
  buf.writeln('');
  buf.writeln('class VehicleMasterSeeder {');
  buf.writeln('  VehicleMasterSeeder._();');
  buf.writeln('');
  buf.writeln('  static Future<void> seed() async {');
  buf.writeln('    final db = FirebaseFirestore.instance;');
  if (doClear) {
    buf.writeln('    await _clearCollections(db);');
  }
  buf.writeln('    final batch = db.batch();');
  buf.writeln('');

  buf.writeln('    // MAKERS');
  for (final m in makers) {
    buf.writeln("    batch.set(db.collection('vehicle_makers').doc('${m['id']}'), {");
    buf.writeln("      'name': '${m['name']}',");
    buf.writeln("      'nameEn': '${m['name_en']}',");
    buf.writeln("      'country': '${m['country']}',");
    buf.writeln("      'displayOrder': ${(m['display_order']?.isEmpty ?? true) ? '100' : m['display_order']},");
    buf.writeln("      'isActive': true,");
    buf.writeln("    });");
  }

  buf.writeln('');
  buf.writeln('    // MODELS');
  for (final m in models) {
    buf.writeln("    batch.set(db.collection('vehicle_models').doc('${m['id']}'), {");
    buf.writeln("      'makerId': '${m['parent_id']}',");
    buf.writeln("      'name': '${m['name']}',");
    buf.writeln("      'nameEn': '${m['name_en']}',");
    if (m['body_type']?.isNotEmpty == true) {
      buf.writeln("      'bodyType': '${m['body_type']}',");
    }
    if (m['production_start_year']?.isNotEmpty == true) {
      buf.writeln("      'productionStartYear': ${m['production_start_year']},");
    }
    if (m['production_end_year']?.isNotEmpty == true) {
      buf.writeln("      'productionEndYear': ${m['production_end_year']},");
    }
    buf.writeln("      'displayOrder': ${(m['display_order']?.isEmpty ?? true) ? '100' : m['display_order']},");
    buf.writeln("      'isActive': true,");
    buf.writeln("    });");
  }

  buf.writeln('');
  buf.writeln('    await batch.commit();');
  buf.writeln('    print(\'Seeded ${makers.length} makers, ${models.length} models\');');
  buf.writeln('  }');

  if (doClear) {
    buf.writeln('');
    buf.writeln('  static Future<void> _clearCollections(FirebaseFirestore db) async {');
    buf.writeln("    final collections = ['vehicle_makers', 'vehicle_models', 'vehicle_grades'];");
    buf.writeln('    for (final col in collections) {');
    buf.writeln('      final docs = await db.collection(col).get();');
    buf.writeln('      final batch = db.batch();');
    buf.writeln('      for (final doc in docs.docs) { batch.delete(doc.reference); }');
    buf.writeln('      await batch.commit();');
    buf.writeln('    }');
    buf.writeln('  }');
  }

  buf.writeln('}');

  File('scripts/_seed_vehicle_master_generated.dart').writeAsStringSync(buf.toString());
}

String? _getArg(List<String> args, String flag) {
  final idx = args.indexOf(flag);
  if (idx == -1 || idx + 1 >= args.length) return null;
  return args[idx + 1];
}
