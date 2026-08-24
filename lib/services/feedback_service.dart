import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/firestore_collections.dart';
import '../core/error/app_error.dart';
import '../core/result/result.dart';
import '../models/user_feedback.dart';

/// Receives requests and bug reports from users.
///
/// Write-only from the client: feedback is triaged on the operations side, and
/// nobody should be able to read what other people wrote. The security rule
/// enforces the same thing.
class FeedbackService {
  final FirebaseFirestore _firestore;
  final String _appVersion;
  final String _platform;

  FeedbackService({
    required FirebaseFirestore firestore,
    required String appVersion,
    required String platform,
  })  : _firestore = firestore,
        _appVersion = appVersion,
        _platform = platform;

  CollectionReference<Map<String, dynamic>> get _ref =>
      _firestore.collection(FirestoreCollections.feedback);

  /// Sends one piece of feedback.
  ///
  /// [screen] records where the user was when they hit send — a bug report
  /// without it is much harder to act on. [contactEmail] is optional: the
  /// account address is not always one the user reads.
  Future<Result<void, AppError>> submit({
    required String userId,
    required FeedbackType type,
    required String message,
    String? screen,
    String? contactEmail,
  }) async {
    if (userId.isEmpty) {
      return const Result.failure(
        AppError.auth('ご意見を送るにはログインが必要です'),
      );
    }

    final messageError = UserFeedback.validateMessage(message);
    if (messageError != null) {
      return Result.failure(
        AppError.validation(messageError, field: 'message'),
      );
    }

    final emailError = UserFeedback.validateContactEmail(contactEmail);
    if (emailError != null) {
      return Result.failure(
        AppError.validation(emailError, field: 'contactEmail'),
      );
    }

    final trimmedEmail = (contactEmail ?? '').trim();

    try {
      final feedback = UserFeedback(
        id: '',
        userId: userId,
        type: type,
        message: message.trim(),
        appVersion: _appVersion,
        platform: _platform,
        screen: screen,
        contactEmail: trimmedEmail.isEmpty ? null : trimmedEmail,
        createdAt: DateTime.now(),
      );

      await _ref.add(feedback.toMap());
      return const Result.success(null);
    } catch (e) {
      return Result.failure(mapFirebaseError(e));
    }
  }
}
