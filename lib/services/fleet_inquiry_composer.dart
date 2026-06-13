import 'package:intl/intl.dart';

import '../models/vehicle.dart';

/// Draft text for a bulk inspection inquiry to a shop.
class FleetInquiryDraft {
  final String subject;
  final String message;

  const FleetInquiryDraft({required this.subject, required this.message});
}

/// Composes an inquiry message for fleet admins who want to request
/// inspections for multiple vehicles at once.
///
/// Pure functions only — no Firebase access, fully unit-testable.
class FleetInquiryComposer {
  FleetInquiryComposer._();

  /// Vehicles whose inspection expires within this window are included.
  static const int inspectionWindowDays = 60;

  /// Extracts vehicles that need an inspection soon (expired or within
  /// [inspectionWindowDays]), sorted by expiry date ascending.
  static List<Vehicle> vehiclesNeedingInspection(List<Vehicle> vehicles) {
    final targets = vehicles.where((v) {
      final days = v.daysUntilInspection;
      return days != null && days <= inspectionWindowDays;
    }).toList();
    targets.sort(
        (a, b) => a.inspectionExpiryDate!.compareTo(b.inspectionExpiryDate!));
    return targets;
  }

  /// Builds the inquiry subject and message for the given vehicles.
  static FleetInquiryDraft compose(List<Vehicle> vehicles) {
    final dateFormat = DateFormat('yyyy年M月d日');
    final buffer = StringBuffer()
      ..writeln('お世話になっております。')
      ..writeln('下記${vehicles.length}台の車検についてお見積りをお願いいたします。')
      ..writeln();

    for (var i = 0; i < vehicles.length; i++) {
      final v = vehicles[i];
      final plate = v.licensePlate ?? 'ナンバー未登録';
      final expiry = v.inspectionExpiryDate != null
          ? dateFormat.format(v.inspectionExpiryDate!)
          : '未設定';
      buffer.writeln('${i + 1}. ${v.displayName}（$plate）');
      buffer.writeln('   車検満了日: $expiry');
      if (v.useCategory != null &&
          v.useCategory != VehicleUseCategory.privatePassenger) {
        buffer.writeln('   用途区分: ${v.useCategory!.displayName}');
      }
    }

    buffer
      ..writeln()
      ..writeln('日程・費用についてご相談させてください。')
      ..writeln('よろしくお願いいたします。');

    return FleetInquiryDraft(
      subject: '車検一括見積もり依頼（${vehicles.length}台）',
      message: buffer.toString(),
    );
  }
}
