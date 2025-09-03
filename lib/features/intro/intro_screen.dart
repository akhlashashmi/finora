import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/features/intro/intro_provider.dart';

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

  late final List<IntroPage> _pages = _buildPages(context);

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  List<IntroPage> _buildPages(BuildContext context) {
    final theme = Theme.of(context);
    return [
      // Page 1: Focus on the core "Smart Input" feature
      IntroPage(
        title: 'Smarter Lists Start Here',
        // Subtitle now specifies the purpose and types of lists.
        subtitle:
            'From daily expenses and shopping lists to budgets and wishlists, mindmap your goals and capture them effortlessly.',
        highlights: ['Coffee 15.99', '15% tip on 45', 'Groceries: 25+15'],
        color: theme.colorScheme.primary,
        illustration: Icons.auto_fix_high,
      ),
      // Page 2: Focus on List & Item Management
      IntroPage(
        title: 'Organize with Precision',
        subtitle:
            'Manage your lists and items with powerful, intuitive controls designed for speed and simplicity.',
        highlights: [
          'Tap to select',
          'Swipe to edit/delete',
          'Pin important lists',
        ],
        color: theme.colorScheme.secondary,
        illustration: Icons.edit_note_rounded,
      ),
      // Page 3: Focus on Statistics and Budgeting
      IntroPage(
        title: 'Gain Financial Clarity',
        subtitle:
            'Turn your lists into insights. Track spending, visualize budgets, and make informed decisions with detailed stats.',
        highlights: [
          'Interactive budget tracking',
          'Detailed stats overlay',
          'Cycle through key metrics',
        ],
        color: theme.colorScheme.tertiary,
        illustration: Icons.analytics_outlined,
      ),
      // Page 4: Focus on Security and Data Backup
      IntroPage(
        title: 'Your Data, Safe & Sound',
        subtitle:
            'Keep your information secure with app-wide PIN protection and never lose your data with local & cloud backups.',
        highlights: [
          'Protect lists with PIN',
          'Cloud & Local Backups',
          'Restore anytime',
        ],
        color: theme.colorScheme.primary,
        illustration: Icons.security_rounded,
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
      await ref.read(introCompletedNotifierProvider.notifier).completeIntro();
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
            _IntroHeader(
              showSkip: !isLastPage,
              onSkip: _onSkipPressed,
              accentColor: currentPage.color,
            ),
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
        _kHorizontalPadding,
        16,
        _kHorizontalPadding,
        0,
      ),
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
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
              const SizedBox(width: 48),
          ],
        ),
      ),
    );
  }
}

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
          _MinimalPageIndicator(
            currentPage: currentPage,
            pageCount: totalPages,
            color: accentColor,
          ),
          const SizedBox(height: 32),
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
          Container(
            width: _kIllustrationSize,
            height: _kIllustrationSize,
            decoration: BoxDecoration(
              color: page.color.withValues(alpha:0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(page.illustration, size: _kIconSize, color: page.color),
          ),
          const SizedBox(height: 48),
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
          Text(
            page.subtitle,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (page.highlights.isNotEmpty)
            IntrinsicWidth(
              child: Column(
                children: page.highlights.map((highlight) {
                  final bool isExample =
                      highlight.contains('Coffee') ||
                      highlight.contains('%') ||
                      highlight.contains(':');

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                          color: page.color.withValues(alpha:0.8),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          highlight,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                            fontFamily: isExample ? 'monospace' : null,
                            fontWeight: isExample ? FontWeight.w500 : null,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

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
            color: isActive ? color : color.withValues(alpha:0.25),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}

class IntroPage {
  final String title;
  final String subtitle;
  final List<String> highlights;
  final IconData illustration;
  final Color color;

  IntroPage({
    required this.title,
    required this.subtitle,
    required this.highlights,
    required this.illustration,
    required this.color,
  });
}
