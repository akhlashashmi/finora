import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/features/intro/intro_provider.dart';

// Extracted constants for maintainability
const _kHorizontalPadding = 24.0;
const _kIllustrationSize = 80.0;
const _kIconSize = 36.0;
const _kButtonHeight = 48.0;
const _kAnimationDuration = Duration(milliseconds: 300);

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  // Pre-defined pages data (moved from didChangeDependencies for better predictability)
  late final List<IntroPage> _pages = _buildPages(context);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<IntroPage> _buildPages(BuildContext context) {
    final theme = Theme.of(context);
    return [
      IntroPage(
        title: 'Welcome to Finora Lists',
        subtitle:
        'Organize everything in one place — expenses, budgets, shopping, or wishlists.',
        color: theme.colorScheme.primary,
        illustration: Icons.account_balance_wallet_outlined,
      ),
      IntroPage(
        title: 'Track What Matters',
        subtitle:
        'Quickly create and manage lists with smart categorization and easy inputs.',
        color: theme.colorScheme.primary,
        illustration: Icons.show_chart_outlined,
      ),
      IntroPage(
        title: 'Visualize & Plan',
        subtitle:
        'Have a budget and you want to mind map with your wishlist? Let\'s continue. '
            'Plan your goals and connect them with your budget effortlessly.',
        color: theme.colorScheme.primary,
        illustration: Icons.map_outlined,
      ),
      IntroPage(
        title: 'Backup & Restore',
        subtitle:
        'Keep your lists safe with local and cloud backup options, always accessible.',
        color: theme.colorScheme.primary,
        illustration: Icons.cloud_done_outlined,
      ),
    ];
  }

  void _onPageChanged(int index) {
    setState(() => _currentPage = index);
  }

  Future<void> _onNextPressed() async {
    if (_currentPage < _pages.length - 1) {
      _pageController.nextPage(
        duration: _kAnimationDuration,
        curve: Curves.easeOut,
      );
    } else {
      await ref
          .read(introCompletedNotifierProvider.notifier)
          .completeIntro();
    }
  }

  void _onSkipPressed() {
    _pageController.jumpToPage(_pages.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentPage = _pages[_currentPage];
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _IntroHeader(
              showSkip: !isLastPage,
              onSkip: _onSkipPressed,
              accentColor: currentPage.color,
            ),

            // Content
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: _onPageChanged,
                itemBuilder: (context, index) {
                  return _IntroPageContent(page: _pages[index]);
                },
              ),
            ),

            // Footer
            _IntroFooter(
              currentPage: _currentPage,
              totalPages: _pages.length,
              accentColor: currentPage.color,
              isLastPage: isLastPage,
              onNext: _onNextPressed,
            ),
          ],
        ),
      ),
    );
  }
}

// Extracted header widget for better separation of concerns
class _IntroHeader extends StatelessWidget {
  final bool showSkip;
  final VoidCallback onSkip;
  final Color accentColor;

  const _IntroHeader({
    required this.showSkip,
    required this.onSkip,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        _kHorizontalPadding, 16, _kHorizontalPadding, 0,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Logo
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.attach_money,
                    color: Theme.of(context).colorScheme.surface,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Finora',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: accentColor,
                  ),
                ),
              ],
            ),

            // Skip button
            if (showSkip)
              TextButton(
                onPressed: onSkip,
                child: Text(
                  'Skip',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              )
            else
              const SizedBox(width: 48), // Placeholder for layout consistency
          ],
        ),
      ),
    );
  }
}

// Extracted footer widget
class _IntroFooter extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final Color accentColor;
  final bool isLastPage;
  final VoidCallback onNext;

  const _IntroFooter({
    required this.currentPage,
    required this.totalPages,
    required this.accentColor,
    required this.isLastPage,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(_kHorizontalPadding),
      child: Column(
        children: [
          // Page indicator
          _MinimalPageIndicator(
            currentPage: currentPage,
            pageCount: totalPages,
            color: accentColor,
          ),
          const SizedBox(height: 32),

          // Action button
          SizedBox(
            width: double.infinity,
            height: _kButtonHeight,
            child: ElevatedButton(
              onPressed: onNext,
              style: ElevatedButton.styleFrom(
                backgroundColor: accentColor,
                foregroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
              child: Text(
                isLastPage ? 'Get Started' : 'Continue',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Page content widget
class _IntroPageContent extends StatelessWidget {
  final IntroPage page;

  const _IntroPageContent({required this.page});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: _kIllustrationSize,
            height: _kIllustrationSize,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(page.illustration, size: _kIconSize, color: page.color),
          ),
          const SizedBox(height: 40),

          // Title
          Text(
            page.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: theme.colorScheme.onSurface,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Subtitle
          Text(
            page.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Page indicator widget
class _MinimalPageIndicator extends StatelessWidget {
  final int currentPage;
  final int pageCount;
  final Color color;

  const _MinimalPageIndicator({
    required this.currentPage,
    required this.pageCount,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pageCount, (index) {
        final isActive = index == currentPage;
        return AnimatedContainer(
          duration: _kAnimationDuration,
          width: isActive ? 20 : 6,
          height: 6,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            color: isActive ? color : color.withOpacity(0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

// Data model for intro pages
class IntroPage {
  final String title;
  final String subtitle;
  final IconData illustration;
  final Color color;

  IntroPage({
    required this.title,
    required this.subtitle,
    required this.illustration,
    required this.color,
  });
}