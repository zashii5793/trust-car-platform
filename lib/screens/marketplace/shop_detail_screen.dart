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
                // 画像カルーセル（ページドット付き）
                _ImageCarouselWithDots(imageUrls: shop.imageUrls),
                Padding(
                  padding: AppSpacing.paddingScreen,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShopHeader(shop: shop),
                      AppSpacing.verticalMd,
                      if (shop.services.isNotEmpty) _ServiceChips(shop: shop),
                      AppSpacing.verticalMd,
                      _BusinessHoursExpansion(shop: shop),
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
// 画像カルーセル（ページドット付き）
// ---------------------------------------------------------------------------

class _ImageCarouselWithDots extends StatefulWidget {
  final List<String> imageUrls;

  const _ImageCarouselWithDots({required this.imageUrls});

  @override
  State<_ImageCarouselWithDots> createState() => _ImageCarouselWithDotsState();
}

class _ImageCarouselWithDotsState extends State<_ImageCarouselWithDots> {
  final _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: 240,
        color: Colors.grey.shade200,
        child: const Center(
          child: Icon(Icons.store, size: 64, color: Colors.grey),
        ),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 240,
          child: PageView.builder(
            controller: _controller,
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) {
              return Image.network(
                widget.imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  color: Colors.grey.shade200,
                  child: const Icon(Icons.broken_image,
                      color: Colors.grey, size: 48),
                ),
              );
            },
          ),
        ),
        // ページドット（複数画像のときのみ表示）
        if (widget.imageUrls.length > 1)
          Positioned(
            bottom: AppSpacing.sm,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.imageUrls.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 20 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 工場ヘッダー（名前・星評価）
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
        // 名前 + 広告ラベル
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                shop.name,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            if (shop.isFeatured && !shop.isVerified)
              Padding(
                padding: const EdgeInsets.only(left: AppSpacing.xs, top: 4),
                child: Chip(
                  label: const Text('広告'),
                  labelStyle: const TextStyle(fontSize: 11),
                  visualDensity: VisualDensity.compact,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.xs),
        // 業種バッジ + 認証
        Wrap(
          spacing: AppSpacing.xs,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm, vertical: 2),
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
            if (shop.isVerified)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(AppSpacing.xs),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.verified, size: 12, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '認証済み',
                      style: theme.textTheme.labelSmall
                          ?.copyWith(color: Colors.blue),
                    ),
                  ],
                ),
              ),
          ],
        ),
        // 星評価（視覚的な星表示）
        if (shop.rating != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _StarRating(rating: shop.rating!),
              const SizedBox(width: AppSpacing.xs),
              Text(
                shop.rating!.toStringAsFixed(1),
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '(${shop.reviewCount}件のレビュー)',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
        // 説明文
        if (shop.description != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            shop.description!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 星評価ウィジェット
// ---------------------------------------------------------------------------

class _StarRating extends StatelessWidget {
  final double rating;

  const _StarRating({required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index + 1 <= rating;
        final half = !filled && index < rating && index + 1 > rating;
        return Icon(
          half ? Icons.star_half_rounded : Icons.star_rounded,
          size: 18,
          color: filled || half ? Colors.amber : Colors.grey.shade300,
        );
      }),
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
// 営業時間（今日のみ表示 → タップで全曜日展開）
// ---------------------------------------------------------------------------

class _BusinessHoursExpansion extends StatelessWidget {
  final Shop shop;

  const _BusinessHoursExpansion({required this.shop});

  static const _dayNames = ['日', '月', '火', '水', '木', '金', '土'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayWeekday = DateTime.now().weekday % 7;
    final todayHours = shop.businessHours[todayWeekday];

    if (shop.businessHours.isEmpty) return const SizedBox.shrink();

    // 今日の要約テキスト
    final todaySummary = todayHours == null
        ? '-'
        : todayHours.isClosed
            ? '定休日'
            : '${todayHours.openTime ?? '?'}〜${todayHours.closeTime ?? '?'}';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: EdgeInsets.zero,
          shape: const Border(),
          title: Row(
            children: [
              Text('営業時間', style: theme.textTheme.titleSmall),
              const SizedBox(width: AppSpacing.sm),
              // 今日の営業時間サマリー
              Text(
                '今日: $todaySummary',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: shop.isOpenNow
                      ? Colors.green.shade600
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (shop.isOpenNow) ...[
                const SizedBox(width: 4),
                Container(
                  width: 6,
                  height: 6,
                  decoration: const BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ],
          ),
          children: [
            const SizedBox(height: AppSpacing.xs),
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: AppSpacing.paddingCard,
                child: Column(
                  children: List.generate(7, (index) {
                    final hours = shop.businessHours[index];
                    final isToday = index == todayWeekday;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
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
                          Expanded(
                            child: Text(
                              hours?.displayText ?? '-',
                              style: theme.textTheme.bodySmall?.copyWith(
                                fontWeight: isToday ? FontWeight.bold : null,
                                color:
                                    isToday ? theme.colorScheme.primary : null,
                              ),
                            ),
                          ),
                          if (isToday && shop.isOpenNow)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '営業中',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: Colors.green.shade700,
                                  fontSize: 10,
                                ),
                              ),
                            ),
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
            const SizedBox(height: AppSpacing.xs),
          ],
        ),
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
            const Icon(Icons.location_on_outlined,
                size: 18, color: Colors.grey),
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
