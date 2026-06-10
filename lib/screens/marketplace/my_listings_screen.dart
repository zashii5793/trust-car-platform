import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/user_part_listing.dart';
import '../../providers/auth_provider.dart';
import '../../services/part_listing_service.dart';
import '../../widgets/common/loading_indicator.dart';
import 'create_listing_screen.dart';

/// Screen that shows all listings created by the current user.
class MyListingsScreen extends StatefulWidget {
  const MyListingsScreen({super.key});

  @override
  State<MyListingsScreen> createState() => _MyListingsScreenState();
}

class _MyListingsScreenState extends State<MyListingsScreen> {
  final _service = ServiceLocator.instance.get<PartListingService>();

  List<UserPartListing> _listings = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadListings();
  }

  // -------------------------------------------------------------------------
  // Data loading
  // -------------------------------------------------------------------------

  Future<void> _loadListings() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final uid = context.read<AuthProvider>().firebaseUser?.uid ?? '';
    final result = await _service.getMyListings(uid);

    if (!mounted) return;

    result.when(
      success: (listings) {
        setState(() {
          _listings = listings;
          _isLoading = false;
        });
      },
      failure: (error) {
        setState(() {
          _errorMessage = error.userMessage;
          _isLoading = false;
        });
      },
    );
  }

  // -------------------------------------------------------------------------
  // Status update actions
  // -------------------------------------------------------------------------

  Future<void> _updateStatus(
    UserPartListing listing,
    PartListingStatus newStatus,
  ) async {
    final result = await _service.updateListingStatus(listing.id, newStatus);

    if (!mounted) return;

    result.when(
      success: (_) {
        setState(() {
          final index = _listings.indexWhere((l) => l.id == listing.id);
          if (index != -1) {
            _listings[index] = listing.copyWith(status: newStatus);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text('「${listing.title}」を${newStatus.displayName}にしました')),
        );
      },
      failure: (error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.userMessage),
            backgroundColor: AppColors.error,
          ),
        );
      },
    );
  }

  Future<void> _showStatusMenu(UserPartListing listing) async {
    final action = await showModalBottomSheet<_ListingAction>(
      context: context,
      builder: (context) => _ListingActionSheet(listing: listing),
    );

    if (!mounted || action == null) return;

    switch (action) {
      case _ListingAction.soldOut:
        await _updateStatus(listing, PartListingStatus.soldOut);
      case _ListingAction.cancel:
        await _updateStatus(listing, PartListingStatus.cancelled);
      case _ListingAction.edit:
        // Navigate to CreateListingScreen in edit mode, passing the existing listing.
        final refreshed = await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => CreateListingScreen(existingListing: listing),
          ),
        );
        if (refreshed == true && mounted) {
          _loadListings();
        }
    }
  }

  // -------------------------------------------------------------------------
  // Navigation
  // -------------------------------------------------------------------------

  Future<void> _openCreateListing() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateListingScreen()),
    );
    if (created == true && mounted) {
      _loadListings();
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('マイ出品')),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateListing,
        icon: const Icon(Icons.add),
        label: const Text('出品する'),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const AppLoadingCenter();
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: AppSpacing.paddingScreen,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline,
                size: AppSpacing.iconXl,
                color: AppColors.error,
              ),
              AppSpacing.verticalMd,
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
              ),
              AppSpacing.verticalMd,
              FilledButton(
                onPressed: _loadListings,
                child: const Text('再読み込み'),
              ),
            ],
          ),
        ),
      );
    }

    if (_listings.isEmpty) {
      return AppEmptyState(
        icon: Icons.sell_outlined,
        title: '出品中のパーツがありません',
        description: 'パーツを出品して、\n他のユーザーと取引しましょう',
        buttonLabel: 'パーツを出品する',
        onButtonPressed: _openCreateListing,
      );
    }

    return RefreshIndicator(
      onRefresh: _loadListings,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          // Extra bottom padding so the FAB doesn't overlap the last item
          AppSpacing.md + AppSpacing.tapTargetRecommended + AppSpacing.md,
        ),
        itemCount: _listings.length,
        itemBuilder: (context, index) {
          return _ListingCard(
            listing: _listings[index],
            onMenuTap: () => _showStatusMenu(_listings[index]),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ListingCard
// ---------------------------------------------------------------------------

class _ListingCard extends StatelessWidget {
  final UserPartListing listing;
  final VoidCallback onMenuTap;

  const _ListingCard({required this.listing, required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: AppSpacing.marginListItem,
      shape: RoundedRectangleBorder(borderRadius: AppSpacing.borderRadiusMd),
      child: InkWell(
        borderRadius: AppSpacing.borderRadiusMd,
        onTap: onMenuTap,
        onLongPress: onMenuTap,
        child: Padding(
          padding: AppSpacing.paddingCard,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thumbnail
              _Thumbnail(imageUrl: listing.imageUrls.firstOrNull),
              AppSpacing.horizontalMd,

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title + menu
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            listing.title,
                            style: theme.textTheme.titleSmall,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          visualDensity: VisualDensity.compact,
                          onPressed: onMenuTap,
                        ),
                      ],
                    ),
                    AppSpacing.verticalXxs,

                    // Price
                    Text(
                      listing.priceDisplay,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    AppSpacing.verticalXxs,

                    // Status badge + date
                    Row(
                      children: [
                        _StatusBadge(status: listing.status),
                        const Spacer(),
                        Text(
                          _formatDate(listing.createdAt),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: AppColors.textTertiary,
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
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}/${dt.month.toString().padLeft(2, '0')}/${dt.day.toString().padLeft(2, '0')}';
  }
}

// ---------------------------------------------------------------------------
// _Thumbnail
// ---------------------------------------------------------------------------

class _Thumbnail extends StatelessWidget {
  final String? imageUrl;

  const _Thumbnail({this.imageUrl});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: AppSpacing.borderRadiusSm,
      child: SizedBox(
        width: 80,
        height: 80,
        child: imageUrl != null && imageUrl!.isNotEmpty
            ? Image.network(
                imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _placeholder(isDark),
              )
            : _placeholder(isDark),
      ),
    );
  }

  Widget _placeholder(bool isDark) {
    return Container(
      color: isDark ? AppColors.darkCard : AppColors.backgroundLight,
      child: Icon(
        Icons.inventory_2_outlined,
        size: AppSpacing.iconLg,
        color: isDark ? AppColors.darkTextTertiary : AppColors.textTertiary,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _StatusBadge
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  final PartListingStatus status;

  const _StatusBadge({required this.status});

  Color _backgroundColor() {
    switch (status) {
      case PartListingStatus.active:
        return AppColors.successBackground;
      case PartListingStatus.soldOut:
        return AppColors.warningBackground;
      case PartListingStatus.cancelled:
        return AppColors.backgroundSecondary;
    }
  }

  Color _textColor() {
    switch (status) {
      case PartListingStatus.active:
        return AppColors.secondary;
      case PartListingStatus.soldOut:
        return AppColors.warning;
      case PartListingStatus.cancelled:
        return AppColors.textSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xs,
        vertical: 2,
      ),
      decoration: BoxDecoration(
        color: _backgroundColor(),
        borderRadius: AppSpacing.borderRadiusXs,
      ),
      child: Text(
        status.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: _textColor(),
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// _ListingActionSheet
// ---------------------------------------------------------------------------

enum _ListingAction { soldOut, cancel, edit }

class _ListingActionSheet extends StatelessWidget {
  final UserPartListing listing;

  const _ListingActionSheet({required this.listing});

  @override
  Widget build(BuildContext context) {
    final isActive = listing.status == PartListingStatus.active;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text(
              listing.title,
              style: Theme.of(context).textTheme.titleSmall,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const Divider(height: 1),
          if (isActive) ...[
            ListTile(
              leading: const Icon(Icons.check_circle_outline,
                  color: AppColors.warning),
              title: const Text('売り切れにする'),
              onTap: () => Navigator.pop(context, _ListingAction.soldOut),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline,
                  color: AppColors.error),
              title: const Text('取り下げる'),
              onTap: () => Navigator.pop(context, _ListingAction.cancel),
            ),
          ],
          ListTile(
            leading: const Icon(Icons.edit_outlined),
            title: const Text('編集'),
            onTap: () => Navigator.pop(context, _ListingAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.close),
            title: const Text('キャンセル'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
