import 'package:flutter/material.dart';

import '../../../core/constants/spacing.dart';
import '../../../core/error/app_error.dart';
import '../../../core/result/result.dart';
import '../../../services/shop_ledger_service.dart';

/// 1ページ分を読む関数。[cursor] が null なら先頭から。
typedef LedgerPageLoader<T> = Future<Result<LedgerPage<T>, AppError>> Function(
    Object? cursor);

/// 20件ずつ読み、下までスクロールしたら続きを読む一覧。
///
/// **顧客が何千人いても、最初に読むのは20件だけ。** 全件を読んでから
/// 並べる作りにすると、画面を開くたびに顧客数ぶんの読み取りが発生する。
///
/// [loader] が変わったら（検索語や並べ方が変わったら）先頭から読み直す。
/// 呼び出し側は [reloadKey] を変えて読み直しを指示する。
class LedgerPagedList<T> extends StatefulWidget {
  final LedgerPageLoader<T> loader;
  final Widget Function(BuildContext context, T item) itemBuilder;
  final Widget empty;
  final Object? reloadKey;

  const LedgerPagedList({
    super.key,
    required this.loader,
    required this.itemBuilder,
    required this.empty,
    this.reloadKey,
  });

  @override
  State<LedgerPagedList<T>> createState() => _LedgerPagedListState<T>();
}

class _LedgerPagedListState<T> extends State<LedgerPagedList<T>> {
  final List<T> _items = [];
  Object? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  /// 読み直しの世代。古い読み込みの結果が、新しい一覧に混ざらないようにする。
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  @override
  void didUpdateWidget(covariant LedgerPagedList<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.reloadKey != widget.reloadKey) {
      _reset();
    }
  }

  void _reset() {
    setState(() {
      _generation++;
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _loading = false;
      _error = null;
    });
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });

    final result = await widget.loader(_cursor);
    if (!mounted || generation != _generation) return;

    result.when(
      success: (page) => setState(() {
        _items.addAll(page.items);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        _loading = false;
      }),
      failure: (error) => setState(() {
        _error = error.userMessage;
        _loading = false;
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_items.isEmpty && !_loading && _error == null) {
      return RefreshIndicator(
        onRefresh: () async => _reset(),
        child: ListView(children: [widget.empty]),
      );
    }

    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        // 下端の少し手前で次を読む。端に着いてから読むと、毎回止まって見える。
        if (n.metrics.pixels >= n.metrics.maxScrollExtent - 200) {
          _loadMore();
        }
        return false;
      },
      child: RefreshIndicator(
        onRefresh: () async => _reset(),
        child: ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: _items.length + 1,
          itemBuilder: (context, index) {
            if (index < _items.length) {
              return widget.itemBuilder(context, _items[index]);
            }
            return _footer(context);
          },
        ),
      ),
    );
  }

  Widget _footer(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(AppSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          children: [
            Text(_error!, textAlign: TextAlign.center),
            TextButton(
              onPressed: _loadMore,
              child: const Text('もう一度読み込む'),
            ),
          ],
        ),
      );
    }
    if (_hasMore) {
      // スクロールできないほど短い画面でも続きを読めるように。
      return TextButton(
        key: const Key('ledger_load_more'),
        onPressed: _loadMore,
        child: const Text('続きを読み込む'),
      );
    }
    return const SizedBox(height: AppSpacing.xl);
  }
}
