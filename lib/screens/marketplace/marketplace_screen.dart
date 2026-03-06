import 'package:flutter/material.dart';
import 'shop_list_screen.dart';
import 'part_list_screen.dart';

/// マーケットプレイス トップ画面
///
/// 工場一覧 / パーツ一覧の2タブ構成。
/// HomeScreen の BottomNavigationBar 経由でアクセスする。
class MarketplaceScreen extends StatelessWidget {
  const MarketplaceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          // タブバー（Scaffold の appBar には入らないため Column で管理）
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.store_outlined), text: '工場・業者'),
                Tab(icon: Icon(Icons.build_outlined), text: 'パーツ'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                ShopListScreen(),
                PartListScreen(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
