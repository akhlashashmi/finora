import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            elevation: 0,
            scrolledUnderElevation: 0.5,
            surfaceTintColor: theme.colorScheme.surfaceTint.withValues(alpha:0.1),
            backgroundColor: theme.colorScheme.surface.withValues(alpha:0.95),
            pinned: true,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Back',
            ),
            title: Text(
              'Quick Guide',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            centerTitle: false,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Smart Input Section
                  _buildSection(
                    context,
                    icon: Icons.edit_outlined,
                    title: 'Smart Input',
                    children: [
                      _buildTip('Coffee 15.99', 'Title then amount'),
                      _buildTip('15.99 Coffee', 'Amount then title'),
                      _buildTip('20*3 Tea for us', 'Math expression then title'),
                      _buildTip('Groceries: 25+15', 'Title then math expression'),
                      _buildTip('15% tip on 45', 'Natural language for tips/tax'),
                      _buildTip('ABC/123 button', 'Switch between keyboards'),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Statistics Section
                  _buildSection(
                    context,
                    icon: Icons.analytics_outlined,
                    title: 'Statistics',
                    children: [
                      _buildTip('Tap header', 'Cycle through stats'),
                      _buildTip('Long press header', 'Show detailed overlay'),
                      _buildTip('Drag down on overlay', 'Dismiss the overlay'),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Item Management Section
                  _buildSection(
                    context,
                    icon: Icons.checklist_outlined,
                    title: 'Item Management',
                    children: [
                      _buildTip('Tap item', 'Select/deselect item'),
                      _buildTip('Swipe left', 'Reveal Edit or Delete options'),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Pro Tips Card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha:0.3),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha:0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lightbulb_outline,
                              color: theme.colorScheme.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pro Tips',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildProTip('Try "20% of 150" for quick calculations'),
                        _buildProTip('Use "8.5% tax on 200" for shopping'),
                        _buildProTip('Long press stats for budget insights'),
                        _buildProTip('Numbers auto-format (e.g., 1.2M for millions)'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Quick Examples
                  Text(
                    'Quick Examples',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceVariant.withValues(alpha:0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildExample('Lunch 12.50'),
                        _buildExample('15.99 Coffee'),
                        _buildExample('20 * 3 Tea for us'),
                        _buildExample('Tea for us: 20 * 3'),
                        _buildExample('Groceries: 25 + 15'),
                        _buildExample('15% tip on 80'),
                        _buildExample('0% of 100'),
                        _buildExample('Just a title (no number)'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      BuildContext context, {
        required IconData icon,
        required String title,
        required List<Widget> children,
      }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: theme.colorScheme.primary,
              size: 22,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...children,
      ],
    );
  }

  Widget _buildTip(String example, String description) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha:0.6),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha:0.8),
                    ),
                    children: [
                      TextSpan(
                        text: example,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          backgroundColor: theme.colorScheme.surfaceVariant.withValues(alpha:0.5),
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      TextSpan(text: ' → $description'),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProTip(String tip) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 4,
                height: 4,
                margin: const EdgeInsets.only(top: 8),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha:0.7),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tip,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha:0.8),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExample(String example) {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Text(
            example,
            style: theme.textTheme.bodySmall?.copyWith(
              fontFamily: 'monospace',
              color: theme.colorScheme.onSurface.withValues(alpha:0.7),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
    );
  }
}