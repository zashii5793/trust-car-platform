import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

/// Builds a stream that follows the signed-in user.
///
/// Screens subscribe from initState, which on web runs before Firebase Auth
/// has restored its session. Reading `currentUser` once at that moment yields
/// null, and a one-shot empty stream never re-evaluates — the list stays empty
/// even after login succeeds.
///
/// `asyncExpand` is not usable here: it waits for the inner stream to complete
/// before handling the next outer event, and Firestore snapshot streams never
/// complete. That would leave the previous user's data flowing after sign-out.
/// This helper cancels the previous inner subscription on every auth change,
/// which is the `switchMap` behaviour without pulling in rxdart.
Stream<T> authScopedStream<T>({
  required Stream<User?> authChanges,
  required Stream<T> Function(User user) onSignedIn,
  required T signedOutValue,
}) {
  StreamSubscription<T>? innerSub;
  StreamSubscription<User?>? authSub;
  late StreamController<T> controller;

  Future<void> cancelInner() async {
    final sub = innerSub;
    innerSub = null;
    await sub?.cancel();
  }

  controller = StreamController<T>(
    onListen: () {
      authSub = authChanges.listen((user) async {
        await cancelInner();
        if (controller.isClosed) return;

        if (user == null) {
          controller.add(signedOutValue);
          return;
        }

        innerSub = onSignedIn(user).listen(
          controller.add,
          onError: controller.addError,
        );
      }, onError: controller.addError);
    },
    onCancel: () async {
      await cancelInner();
      await authSub?.cancel();
      authSub = null;
    },
  );

  return controller.stream;
}
