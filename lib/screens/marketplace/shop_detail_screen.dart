import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/shop.dart';
import '../../providers/shop_provider.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/loading_indicator.dart';
import 'inquiry_screen.dart';

/// 工場詳細画面
///
/// 設計思想:
/// - 「問い合わせる」ボタンが唯一の接触起点（ユーザー側から起動）
/// - 業者側から押し付けない（電話発信も外部リンクとして任意）
class ShopDetailScreen extends StatefulWidget {
  final String shopId;

  const ShopDetailScreen({super.key, required this.shopId});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ShopProvider>().loadShop(widget.shopId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ShopProvider>(
      builder: (context, provider, _) {
        final shop = provider.selectedShop;

        if (provider.isLoading) {
          return Scaffold(
            appBar: AppBar(title: const Text('工場詳細')),
            body: const AppLoadingCenter(message: '情報を読み込み中...'),
          );
        }

        if (provider.error != null || shop == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('工場詳細')),
            body: AppErrorState(
              message: provider.error?.userMessage ?? '店舗情報が見つかりません',
              onRetry: () => provider.loadShop(widget.shopId),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(shop.name),
            actions: [
              if (shop.isVerified)
                const Padding(
                  padding: EdgeInsets.only(right: AppSpacing.sm),
                  child: Icon(Icons.verified, color: Colors.blue),
                ),
            ],
          ),
          body: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ImageCarousel(imageUrls: shop.imageUrls),
                Padding(
                  padding: AppSpacing.paddingScreen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShopHeader(shop: shop),
                      AppSpacing.verticalMd,
                      if (shop.services.isNotEmpty) _ServiceChips(shop: shop),
                      AppSpacing.verticalMd,
                      _BusinessHoursCard(shop: shop),
                      AppSpacing.verticalMd,
                      _ContactInfo(shop: shop),
                      AppSpacing.verticalMd,
                      if (shop.displayAddress.isNotEmpty)
                        _AddressSection(shop: shop),
                      AppSpacing.verticalXl,
                    ],
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: FilledButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => InquiryScreen(shop: shop),
                  ),
                ),
                icon: const Icon(Icons.mail_outline),
                label: const Text('この工場に問い合わせる'),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 画像カルーセル
// ---------------------------------------------------------------------------

class _ImageCarousel extends StatelessWidget {
  final List<String> imageUrls;

  const _ImageCarousel({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return Container(
        height: 200,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.store, size: 64, color: Colors.grey),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Image.network(
            imageUrls[index],
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey.shade200,
              child: const Icon(Icons.broken_image, color: Colors.grey),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 工場ヘッダー（名前・評価）
// ---------------------------------------------------------------------------

class _ShopHeader extends StatelessWidget {
  final Shop shop;

  const _ShopHeader({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                shop.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            // isFeatured は「広告」ラベルで明示
            if (shop.isFeatured && !shop.isVerified)
              Chip(
                label: const Text('広告'),
                labelStyle: const TextStyle(fontSize: 12),
                visualDensity: VisualDensity.compact,
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppSpacing.xs),
              ),
              child: Text(
                shop.type.displayName,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            if (shop.isVerified) ...[
              const Icon(Icons.verified, size: 16, color: Colors.blue),
              const SizedBox(width: 4),
              Text(
                '認証済み',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
            ],
          ],
        ),
        if (shop.rating != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              const Icon(Icons.star, size: 16, color: Colors.amber),
              const SizedBox(width: 4),
              Text(
                '${shop.rating!.toStringAsFixed(1)} (${shop.reviewCount}件)',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ],
        if (shop.description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            shop.description!,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// サービス Chips
// ---------------------------------------------------------------------------

class _ServiceChips extends StatelessWidget {
  final Shop shop;

  const _ServiceChips({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '提供サービス',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.sm),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          children: shop.services.map((service) {
            return Chip(
              label: Text(service.displayName),
              visualDensity: VisualDensity.compact,
              labelStyle: const TextStyle(fontSize: 12),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 営業時間カード
// ---------------------------------------------------------------------------

class _BusinessHoursCard extends StatelessWidget {
  final Shop shop;

  const _BusinessHoursCard({required this.shop});

  static const _dayNames = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayWeekday = DateTime.now().weekday % 7;

    if (shop.businessHours.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('営業時間', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Card(
          child: Padding(
            padding: AppSpacing.paddingCard,
            child: Column(
              children: List.generate(7, (index) {
                final hours = shop.businessHours[index];
                final isToday = index == todayWeekday;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: Text(
                          _dayNames[index],
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: isToday
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: isToday
                                ? theme.colorScheme.primary
                                : null,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        hours?.displayText ?? '-',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: isToday ? FontWeight.bold : null,
                          color: isToday ? theme.colorScheme.primary : null,
                        ),
                      ),
                      if (isToday && shop.isOpenNow) ...[
                        const SizedBox(width: AppSpacing.xs),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.green.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '営業中',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: Colors.green.shade800,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
        if (shop.businessHoursNote != null) ...[
          const SizedBox(height: AppSpacing.xs),
          Text(
            shop.businessHoursNote!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 連絡先情報
// ---------------------------------------------------------------------------

class _ContactInfo extends StatelessWidget {
  final Shop shop;

  const _ContactInfo({required this.shop});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (shop.phone == null && shop.website == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('連絡先', style: theme.textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        if (shop.phone != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.phone_outlined),
            title: Text(shop.phone!, style: theme.textTheme.bodyMedium),
            dense: true,
          ),
        if (shop.website != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.language_outlined),
            title: Text(
              shop.website!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
                decoration: TextDecoration.underline,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            dense: true,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 住所セクション
// ---------------------------------------------------------------------------

class _AddressSection extends StatelessWidget {
  final Shop shop;

  const _AddressSection({required this.shop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('所在地', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AppSpacing.sm),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, size: 18, color: Colors.grey),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                shop.displayAddress,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

