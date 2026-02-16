import 'package:flutter/material.dart';
import '../../models/part_listing.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';

/// Card widget for displaying part recommendations
class PartRecommendationCard extends StatelessWidget {
  final PartRecommendation recommendation;
  final VoidCallback? onTap;
  final VoidCallback? onInquiry;

  const PartRecommendationCard({
    super.key,
    required this.recommendation,
    this.onTap,
    this.onInquiry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final part = recommendation.part;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image section
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (part.imageUrls.isNotEmpty)
                    Image.network(
                      part.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholderImage(theme),
                    )
                  else
                    _buildPlaceholderImage(theme),

                  // Compatibility badge
                  Positioned(
                    top: 8,
                    left: 8,
                    child: _buildCompatibilityBadge(context),
                  ),

                  // Category badge
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        part.category.displayName,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Content section
            Padding(
              padding: AppSpacing.paddingCard,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Brand and name
                  if (part.brand != null)
                    Text(
                      part.brand!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  Text(
                    part.name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  AppSpacing.verticalXs,

                  // Price
                  Text(
                    part.priceDisplay,
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  AppSpacing.verticalSm,

                  // Compatibility note
                  if (recommendation.compatibilityNote != null)
                    Row(
                      children: [
                        Icon(
                          _getCompatibilityIcon(recommendation.compatibility),
                          size: 16,
                          color: _getCompatibilityColor(recommendation.compatibility),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            recommendation.compatibilityNote!,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: _getCompatibilityColor(recommendation.compatibility),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),

                  AppSpacing.verticalSm,

                  // Pros & Cons summary
                  _buildProsConsSummary(context, part),

                  AppSpacing.verticalMd,

                  // Rating and inquiry button
                  Row(
                    children: [
                      if (part.rating != null) ...[
                        Icon(Icons.star, size: 16, color: Colors.amber),
                        const SizedBox(width: 4),
                        Text(
                          part.rating!.toStringAsFixed(1),
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' (${part.reviewCount})',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                        const Spacer(),
                      ] else
                        const Spacer(),

                      if (onInquiry != null)
                        TextButton.icon(
                          onPressed: onInquiry,
                          icon: const Icon(Icons.mail_outline, size: 18),
                          label: const Text('問い合わせ'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(ThemeData theme) {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.build_outlined,
          size: 48,
          color: Colors.grey[400],
        ),
      ),
    );
  }

  Widget _buildCompatibilityBadge(BuildContext context) {
    final color = _getCompatibilityColor(recommendation.compatibility);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getCompatibilityIcon(recommendation.compatibility),
            size: 14,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
          Text(
            recommendation.compatibility.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProsConsSummary(BuildContext context, PartListing part) {
    final theme = Theme.of(context);
    final pros = part.pros.take(2).toList();
    final cons = part.cons.take(1).toList();

    if (pros.isEmpty && cons.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ...pros.map((p) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.check_circle, size: 14, color: Colors.green),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  p.text,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )),
        ...cons.map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline, size: 14, color: Colors.orange),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  c.text,
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        )),
      ],
    );
  }

  Color _getCompatibilityColor(CompatibilityLevel level) {
    switch (level) {
      case CompatibilityLevel.perfect:
        return Colors.green;
      case CompatibilityLevel.compatible:
        return Colors.blue;
      case CompatibilityLevel.conditional:
        return Colors.orange;
      case CompatibilityLevel.incompatible:
        return Colors.red;
    }
  }

  IconData _getCompatibilityIcon(CompatibilityLevel level) {
    switch (level) {
      case CompatibilityLevel.perfect:
        return Icons.check_circle;
      case CompatibilityLevel.compatible:
        return Icons.check;
      case CompatibilityLevel.conditional:
        return Icons.warning_amber;
      case CompatibilityLevel.incompatible:
        return Icons.cancel;
    }
  }
}

/// Horizontal scrollable list of part recommendations
class PartRecommendationList extends StatelessWidget {
  final List<PartRecommendation> recommendations;
  final String? title;
  final VoidCallback? onSeeAll;
  final void Function(PartRecommendation)? onPartTap;
  final void Function(PartRecommendation)? onInquiry;

  const PartRecommendationList({
    super.key,
    required this.recommendations,
    this.title,
    this.onSeeAll,
    this.onPartTap,
    this.onInquiry,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (recommendations.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  title!,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                if (onSeeAll != null)
                  TextButton(
                    onPressed: onSeeAll,
                    child: const Text('すべて見る'),
                  ),
              ],
            ),
          ),

        SizedBox(
          height: 380,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: recommendations.length,
            itemBuilder: (context, index) {
              final rec = recommendations[index];
              return SizedBox(
                width: 280,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: PartRecommendationCard(
                    recommendation: rec,
                    onTap: onPartTap != null ? () => onPartTap!(rec) : null,
                    onInquiry: onInquiry != null ? () => onInquiry!(rec) : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Compact part card for grid view
class PartCompactCard extends StatelessWidget {
  final PartListing part;
  final VoidCallback? onTap;

  const PartCompactCard({
    super.key,
    required this.part,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image
            AspectRatio(
              aspectRatio: 1,
              child: part.imageUrls.isNotEmpty
                  ? Image.network(
                      part.imageUrls.first,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (part.brand != null)
                    Text(
                      part.brand!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  Text(
                    part.name,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  AppSpacing.verticalXxs,
                  Text(
                    part.priceDisplay,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      color: Colors.grey[200],
      child: Center(
        child: Icon(
          Icons.build_outlined,
          color: Colors.grey[400],
        ),
      ),
    );
  }
}
