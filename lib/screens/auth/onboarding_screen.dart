import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/colors.dart';
import '../../core/constants/spacing.dart';
import '../../widgets/common/app_button.dart';
import 'login_screen.dart';

const String _kOnboardingCompletedKey = 'onboarding_completed';

/// Saves the onboarding completion flag.
///
/// When [onCompleted] is provided (the AuthWrapper flow), it is invoked so
/// the parent can swap the screen in place. Navigating with pushReplacement
/// here would destroy the AuthWrapper home route and break the auth-state
/// listener — login would then never transition to HomeScreen.
Future<void> completeOnboarding(BuildContext context,
    {VoidCallback? onCompleted}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_kOnboardingCompletedKey, true);
  if (onCompleted != null) {
    onCompleted();
    return;
  }
  if (!context.mounted) return;
  Navigator.of(context).pushReplacement(
    MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
  );
}

/// Returns true if the user has already completed onboarding.
Future<bool> hasCompletedOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_kOnboardingCompletedKey) ?? false;
}

class _OnboardingPage {
  final IconData icon;
  final String title;
  final String subtitle;

  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

const _pages = [
  _OnboardingPage(
    icon: Icons.directions_car,
    title: 'クルマのことを、\nもう考えなくていい世界へ',
    subtitle: '整備・点検・車検のすべてを、このアプリ一つで。',
  ),
  _OnboardingPage(
    icon: Icons.history,
    title: '整備履歴を、正確に記録',
    subtitle: '修理・点検・消耗品交換まで、時系列で記録。\n車検証はカメラで読み取るだけ。',
  ),
  _OnboardingPage(
    icon: Icons.notifications_active,
    title: '次の点検時期を、AIがお知らせ',
    subtitle: '走行距離と履歴からAIが分析。\nオイル交換・タイヤ交換のタイミングを見逃さない。',
  ),
  _OnboardingPage(
    icon: Icons.handshake,
    title: '信頼できる整備工場と繋がる',
    subtitle: 'AIの提案から、評価の高い工場へ。\nあなたの意思で、いつでも問い合わせ。',
  ),
];

/// First-launch onboarding screen showing core app features.
/// Shown once; SharedPreferences flag prevents re-display on subsequent launches.
class OnboardingScreen extends StatefulWidget {
  /// Called after the completion flag is saved. When provided, the screen
  /// does not navigate by itself — the parent (AuthWrapper) swaps it out.
  final VoidCallback? onCompleted;

  const OnboardingScreen({super.key, this.onCompleted});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
  }

  Future<void> _skip() =>
      completeOnboarding(context, onCompleted: widget.onCompleted);
  Future<void> _start() =>
      completeOnboarding(context, onCompleted: widget.onCompleted);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: AppColors.backgroundWhite,
      body: SafeArea(
        child: Column(
          children: [
            // Skip button row
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(
                    right: AppSpacing.md, top: AppSpacing.sm),
                child: TextButton(
                  onPressed: _skip,
                  child: Text(
                    'スキップ',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: _onPageChanged,
                itemCount: _pages.length,
                itemBuilder: (context, index) =>
                    _OnboardingPageView(page: _pages[index]),
              ),
            ),

            // Dot indicators
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_pages.length, (index) {
                  final isActive = index == _currentPage;
                  return AnimatedContainer(
                    key: Key('onboarding_dot_$index'),
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs / 2),
                    width: isActive ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.primary
                          : AppColors.backgroundSecondary,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
            ),

            // CTA button — only visible on last page.
            // AnimatedSwitcher removes the non-active child from the tree,
            // so find.text('はじめる') returns nothing on earlier pages.
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: isLastPage
                  ? Padding(
                      key: const ValueKey('cta_button'),
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.lg,
                      ),
                      child: AppButton(
                        label: 'はじめる',
                        onPressed: _start,
                        isFullWidth: true,
                        size: AppButtonSize.large,
                      ),
                    )
                  : const SizedBox(
                      key: ValueKey('cta_spacer'),
                      height: 56 + AppSpacing.lg * 2,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageView extends StatelessWidget {
  final _OnboardingPage page;

  const _OnboardingPageView({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              page.icon,
              size: 60,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
