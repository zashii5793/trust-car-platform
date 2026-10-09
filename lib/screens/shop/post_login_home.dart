import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/shop_entry_service.dart';

/// The first screen after sign-in.
///
/// Shop owners and staff open the customer ledger; everyone else gets the
/// customer-side home ("マイカー"). 2026-10-08 usability test: an owner
/// signing in landed on "マイカー / まず愛車を登録しよう" and needed five
/// taps (market → shop icon → 掲載管理 → 顧客台帳) to reach the ledger.
///
/// The customer side stays one tap away from the ledger
/// ([ledgerBuilder] receives `openUserHome`). If the shop cannot be read
/// (offline, slow), the customer home is shown rather than a spinner
/// that never ends.
class PostLoginHome extends StatefulWidget {
  final String uid;

  /// Null where it is not registered (tests, very old setups): treated as
  /// "not a shop".
  final ShopEntryService? entryService;
  final WidgetBuilder userHome;
  final Widget Function(
    BuildContext context,
    ShopEntry entry,
    VoidCallback openUserHome,
  ) ledgerBuilder;

  /// How long to wait for the shop check before showing the customer home.
  final Duration timeout;

  const PostLoginHome({
    super.key,
    required this.uid,
    required this.entryService,
    required this.userHome,
    required this.ledgerBuilder,
    this.timeout = const Duration(seconds: 8),
  });

  @override
  State<PostLoginHome> createState() => _PostLoginHomeState();
}

class _PostLoginHomeState extends State<PostLoginHome> {
  bool _resolved = false;
  ShopEntry? _entry;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  Future<void> _resolve() async {
    final service = widget.entryService;
    ShopEntry? entry;
    if (service != null && widget.uid.isNotEmpty) {
      try {
        final r = await service.resolve(widget.uid).timeout(widget.timeout);
        entry = r.valueOrNull;
      } on TimeoutException {
        entry = null;
      }
    }
    if (!mounted) return;
    setState(() {
      _entry = entry;
      _resolved = true;
    });
  }

  void _openUserHome() {
    Navigator.of(context).push(MaterialPageRoute<void>(
      builder: widget.userHome,
    ));
  }

  @override
  Widget build(BuildContext context) {
    if (!_resolved) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final entry = _entry;
    if (entry == null) return widget.userHome(context);
    return widget.ledgerBuilder(context, entry, _openUserHome);
  }
}
