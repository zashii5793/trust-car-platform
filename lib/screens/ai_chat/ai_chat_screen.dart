import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../core/di/service_locator.dart';
import '../../models/chat_message.dart';
import '../../models/vehicle.dart';
import '../../providers/ai_chat_provider.dart';
import '../../providers/vehicle_provider.dart';
import '../../services/ai_chat_service.dart';

/// AI chat screen — lets users ask a car expert AI questions about their vehicle.
///
/// Wraps a ChangeNotifierProvider<AiChatProvider> so each navigation to this
/// screen starts with a fresh conversation.
class AiChatScreen extends StatelessWidget {
  const AiChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AiChatProvider(
        service: ServiceLocator.instance.get<AiChatService>(),
      ),
      child: const _AiChatView(),
    );
  }
}

class _AiChatView extends StatefulWidget {
  const _AiChatView();

  @override
  State<_AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<_AiChatView> {
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _inputFocusNode = FocusNode();

  static const _suggestedQuestions = [
    'ワイパー交換の時期は？',
    'オイル交換はいつ？',
    'タイヤの寿命は？',
    'バッテリー上がりの対処法',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<AiChatProvider>().loadHistory();
      }
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) {
      return;
    }
    _inputController.clear();
    _inputFocusNode.unfocus();

    final vehicle = context.read<VehicleProvider>().selectedVehicle;
    await context.read<AiChatProvider>().sendMessage(text, vehicle: vehicle);

    _scrollToBottom();

    // Show error snackbar if the provider has an error
    if (mounted) {
      final error = context.read<AiChatProvider>().error;
      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIに聞く'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: '会話をクリア',
            onPressed: () {
              context.read<AiChatProvider>().clearHistory();
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<AiChatProvider>(
              builder: (context, provider, _) {
                if (provider.isEmpty) {
                  return _EmptyState(
                    vehicle: context.read<VehicleProvider>().selectedVehicle,
                    onSuggestionTap: (q) => _sendMessage(q),
                  );
                }
                _scrollToBottom();
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  itemCount: provider.messages.length,
                  itemBuilder: (context, index) {
                    return _ChatBubble(message: provider.messages[index]);
                  },
                );
              },
            ),
          ),
          _InputBar(
            controller: _inputController,
            focusNode: _inputFocusNode,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty / first-open state with suggested question chips
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onSuggestionTap, this.vehicle});

  final void Function(String question) onSuggestionTap;
  final Vehicle? vehicle;

  /// Returns suggestions tailored to the vehicle's fuel type and characteristics.
  /// Avoids irrelevant questions (e.g. oil change for EVs).
  List<String> _buildSuggestions() {
    final fuel = vehicle?.fuelType;
    final name = vehicle != null ? '${vehicle!.maker} ${vehicle!.model}' : null;
    final km = vehicle?.mileage;

    // EV: no engine oil, no coolant, different focus
    if (fuel == FuelType.electric) {
      return [
        if (name != null) '$name のバッテリー劣化の確認方法は？'
        else 'EVバッテリーの劣化確認方法は？',
        'EVの冬場の航続距離低下対策は？',
        if (km != null) '${km}km走行後のタイヤ点検ポイントは？'
        else 'タイヤの点検ポイントは？',
        '車検でEVならではの確認事項は？',
      ];
    }

    // Hybrid: mostly gas-like but no oil change urgency
    if (fuel == FuelType.hybrid || fuel == FuelType.phev) {
      return [
        if (name != null) '$name のオイル交換時期は？'
        else 'ハイブリッド車のオイル交換時期は？',
        'ハイブリッドバッテリーの寿命と交換費用は？',
        if (km != null) '${km}km走行後に確認すべきことは？'
        else 'タイヤの寿命は？',
        'ハイブリッド車の燃費を悪化させる原因は？',
      ];
    }

    // Gasoline / diesel / hydrogen (default)
    return [
      if (name != null && km != null)
        '$name（${km}km）の次のオイル交換時期は？'
      else
        'オイル交換はいつ？',
      'ワイパー交換の時期と選び方は？',
      if (km != null) '${km}km走行後のタイヤ点検ポイントは？'
      else 'タイヤの寿命と点検方法は？',
      'バッテリー上がりのサインと対処法は？',
    ];
  }

  String _buildSubtitle() {
    if (vehicle == null) {
      return '整備・トラブル・車検など気になることを\n気軽に質問できます';
    }
    return '${vehicle!.maker} ${vehicle!.model} について\n整備・トラブル・車検など何でも聞いてください';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final suggestions = _buildSuggestions();

    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.paddingScreen,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.car_repair,
              size: AppSpacing.iconEmpty,
              color: AppColors.primary.withValues(alpha: 0.7),
            ),
            AppSpacing.verticalMd,
            Text(
              'クルマの専門家AIに\n何でも聞いてみましょう',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            AppSpacing.verticalSm,
            Text(
              _buildSubtitle(),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
            AppSpacing.verticalLg,
            Wrap(
              spacing: AppSpacing.xs,
              runSpacing: AppSpacing.xs,
              alignment: WrapAlignment.center,
              children: suggestions.map((q) {
                return ActionChip(
                  label: Text(q),
                  onPressed: () => onSuggestionTap(q),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Chat bubble — renders a single message
// ─────────────────────────────────────────────────────────────────────────────

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final isUser = message.role == ChatRole.user;
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: const Icon(
                Icons.smart_toy_outlined,
                size: 18,
                color: AppColors.primary,
              ),
            ),
            AppSpacing.horizontalXs,
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                Container(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.75,
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(AppSpacing.radiusLg),
                      topRight: const Radius.circular(AppSpacing.radiusLg),
                      bottomLeft: Radius.circular(
                          isUser ? AppSpacing.radiusLg : AppSpacing.radiusXs),
                      bottomRight: Radius.circular(
                          isUser ? AppSpacing.radiusXs : AppSpacing.radiusLg),
                    ),
                  ),
                  child: message.isLoading
                      ? const _TypingIndicator()
                      : Text(
                          message.content,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color:
                                isUser ? Colors.white : AppColors.textPrimary,
                            height: 1.5,
                          ),
                        ),
                ),
                if (!message.isLoading) ...[
                  const SizedBox(height: 3),
                  Padding(
                    padding: EdgeInsets.only(
                      left: isUser ? 0 : 4,
                      right: isUser ? 4 : 0,
                    ),
                    child: Text(
                      DateFormat('HH:mm').format(message.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (isUser) AppSpacing.horizontalXs,
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Typing indicator shown inside the assistant bubble while waiting
// ─────────────────────────────────────────────────────────────────────────────

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Stagger each dot by 200ms
            final opacity = _dotOpacity(i);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.5),
              child: Opacity(
                opacity: opacity,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.textSecondary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  double _dotOpacity(int index) {
    const phaseShift = 1.0 / 3.0;
    final phase = (_controller.value + index * phaseShift) % 1.0;
    // Sine wave between 0.2 and 1.0
    return 0.2 + 0.8 * (0.5 + 0.5 * (1 - (2 * phase - 1).abs() * 2).clamp(0.0, 1.0));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Bottom input bar
// ─────────────────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final void Function(String text) onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLoading = context.watch<AiChatProvider>().isLoading;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outlineVariant,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: !isLoading,
                maxLines: 4,
                minLines: 1,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: '車のことを何でも聞いてください',
                  hintStyle: TextStyle(color: AppColors.textTertiary),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: AppSpacing.borderRadiusLg,
                    borderSide: BorderSide.none,
                  ),
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                ),
              ),
            ),
            AppSpacing.horizontalXs,
            SizedBox(
              width: AppSpacing.tapTargetMin,
              height: AppSpacing.tapTargetMin,
              child: isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : IconButton(
                      icon: const Icon(Icons.send_rounded),
                      color: AppColors.primary,
                      tooltip: '送信',
                      onPressed: () => onSend(controller.text),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
