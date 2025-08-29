import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:finora/features/intro/intro_provider.dart';

class IntroScreen extends ConsumerStatefulWidget {
  const IntroScreen({super.key});

  @override
  ConsumerState<IntroScreen> createState() => _IntroScreenState();
}

class _IntroScreenState extends ConsumerState<IntroScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  late List<IntroPage> _pages;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final theme = Theme.of(context);
    _pages = [
      IntroPage(
        title: 'Welcome to Finora',
        subtitle:
        'Your personal expense tracker designed for simplicity and power',
        color: theme.colorScheme.primary,
        illustration: Icons.account_balance_wallet_outlined,
      ),
      IntroPage(
        title: 'Track Everything',
        subtitle:
        'Easily add expenses with quick input and smart categorization',
        color: theme.colorScheme.primary,
        illustration: Icons.show_chart_outlined,
      ),
      IntroPage(
        title: 'Mind Map Your Wishlist',
        subtitle:
        'Have a budget and want to mind map with your wishlist? Let\'s continue.',
        color: theme.colorScheme.primary,
        illustration: Icons.map_outlined,
      ),
      IntroPage(
        title: 'Backup & Restore', // Changed title for clarity
        subtitle: 'Secure your data with local and cloud backup options', // **MODIFIED LINE**
        color: theme.colorScheme.primary,
        illustration: Icons.cloud_done_outlined,
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_pages.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentPage = _pages[_currentPage];
    final isLastPage = _currentPage == _pages.length - 1;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Container(
        // decoration: BoxDecoration(
        //   gradient: LinearGradient(
        //     begin: Alignment.topCenter,
        //     end: Alignment.bottomCenter,
        //     stops: const [0.0, 0.3, 1.0],
        //     colors: [
        //       currentPage.color.withOpacity(0.03),
        //       theme.scaffoldBackgroundColor.withOpacity(0.5),
        //       theme.scaffoldBackgroundColor,
        //     ],
        //   ),
        // ),
        child: SafeArea(
          child: Column(
            children: [
              // Fixed header with consistent spacing
              _buildHeader(isLastPage, currentPage.color),

              // Main content
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: _pages.length,
                  onPageChanged: (index) {
                    setState(() => _currentPage = index);
                  },
                  itemBuilder: (context, index) {
                    return _IntroPageContent(page: _pages[index]);
                  },
                ),
              ),

              // Bottom section with rounded button
              _buildBottomSection(currentPage, isLastPage, theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isLastPage, Color accentColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: SizedBox(
        height: 48, // Fixed height to prevent layout shifts
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

            // Skip button or empty container to maintain layout
            isLastPage
                ? const SizedBox(width: 48) // Empty space to balance layout
                : TextButton(
              onPressed: () => _pageController.jumpToPage(_pages.length - 1),
              child: Text(
                'Skip',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomSection(IntroPage currentPage, bool isLastPage, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Page indicator
          _MinimalPageIndicator(
            currentPage: _currentPage,
            pageCount: _pages.length,
            color: currentPage.color,
          ),

          const SizedBox(height: 32),

          // Completely rounded action button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () async {
                if (!isLastPage) {
                  _pageController.nextPage(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  );
                } else {
                  await ref
                      .read(introCompletedNotifierProvider.notifier)
                      .completeIntro();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: currentPage.color,
                foregroundColor: Theme.of(context).colorScheme.surface,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24), // Completely rounded
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
          // Minimal icon container
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: page.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(
              page.illustration,
              size: 36,
              color: page.color,
            ),
          ),

          const SizedBox(height: 40),

          // Clean title
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

          // Simple subtitle
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
          duration: const Duration(milliseconds: 200),
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