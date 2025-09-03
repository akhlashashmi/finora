import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final listStatsProvider = StreamProvider.autoDispose
    .family<List<Check>, String>((ref, listId) {
      final repo = ref.watch(expenseRepositoryProvider);
      return repo.watchChecksForList(listId);
    });

class ListPageCard extends ConsumerStatefulWidget {
  final ListPage listPage;
  final bool isDragging;
  final bool isSelected;
  final bool isReorderMode;
  final int index;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const ListPageCard({
    super.key,
    required this.listPage,
    required this.index,
    this.isDragging = false,
    this.isSelected = false,
    this.isReorderMode = false,
    this.onTap,
    this.onLongPress,
  });

  @override
  ConsumerState<ListPageCard> createState() => _ListPageCardState();
}

class _ListPageCardState extends ConsumerState<ListPageCard> {
  @override
  Widget build(BuildContext context) {
    final stats = ref.watch(listStatsProvider(widget.listPage.id));
    final theme = Theme.of(context);

    final color = widget.isSelected
        ? theme.colorScheme.primaryContainer.withValues(alpha:0.4)
        : theme
              .colorScheme
              .surfaceContainerHigh;

    final elevation = widget.isSelected ? 4.0 : 1.0;
    final scale = widget.isSelected ? 1.03 : 1.0;

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withValues(alpha:0.05),
              blurRadius: 10,
              offset: Offset(0, elevation),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: widget.onTap,
            onLongPress: widget.onLongPress,
            borderRadius: BorderRadius.circular(16),
            splashColor: theme.colorScheme.primary.withValues(alpha:0.1),
            highlightColor: theme.colorScheme.primary.withValues(alpha:0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 350),
                      transitionBuilder: (child, animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: stats.when(
                        data: (checks) => _buildCardContent(
                          context,
                          theme,
                          checks,
                          key: const ValueKey('data'),
                        ),
                        loading: () => _buildLoadingContent(
                          context,
                          theme,
                          key: const ValueKey('loading'),
                        ),
                        error: (_, __) => _buildErrorContent(
                          context,
                          theme,
                          key: const ValueKey('error'),
                        ),
                      ),
                    ),
                  ),
                  if (widget.isReorderMode)
                    ReorderableDragStartListener(
                      index: widget.index,
                      child: Container(
                        margin: const EdgeInsets.only(left: 12),
                        padding: const EdgeInsets.all(8),
                        child: Icon(
                          Icons.drag_handle_rounded,
                          color: theme.colorScheme.onSurfaceVariant,
                          size: 24,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    ThemeData theme,
    List<Check> checks, {
    Key? key,
  }) {
    return _buildHeader(context, theme, checks, key: key);
  }

  Widget _buildHeader(
    BuildContext context,
    ThemeData theme,
    List<Check> checks, {
    Key? key,
  }) {
    final checkedCount = checks.where((c) => c.isSelected).length;

    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // A prominent leading icon, similar to settings screen.
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha:0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.article_outlined,
                color: theme.colorScheme.primary,
                size: 22,
              ),
            ),
            if (widget.listPage.isPinned)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: theme.colorScheme.surfaceContainerLow,
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.push_pin_rounded,
                    size: 12,
                    color: theme.colorScheme.onPrimaryContainer,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.listPage.name,
                style: TextStyle(
                  fontSize: 17, // Modified
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              // Item info is now a subtitle here, not in a separate footer.
              _buildItemsInfo(context, theme, checks, checkedCount),
            ],
          ),
        ),
        if (!widget.isReorderMode) ...[
          const SizedBox(width: 12),
          _buildStatusChip(context, theme, checks),
        ],
      ],
    );
  }

  Widget _buildStatusChip(
    BuildContext context,
    ThemeData theme,
    List<Check> checks,
  ) {
    final isProtected = widget.listPage.isProtected;
    final checkedCount = checks.where((c) => c.isSelected).length;
    final total = checks.fold<double>(0, (sum, item) => sum + item.number);
    final hasBudget = widget.listPage.budget > 0;
    final isOverBudget = hasBudget && total > widget.listPage.budget;

    Color? backgroundColor;
    Color? textColor;
    IconData? iconData;
    String? label;

    if (isProtected) {
      backgroundColor = theme.colorScheme.secondaryContainer;
      textColor = theme.colorScheme.onSecondaryContainer;
      iconData = Icons.security_rounded;
    } else if (isOverBudget) {
      backgroundColor = theme.colorScheme.errorContainer;
      textColor = theme.colorScheme.onErrorContainer;
      iconData = Icons.warning_amber_rounded;
    } else if (checkedCount == checks.length && checks.isNotEmpty) {
      backgroundColor = theme.colorScheme.tertiaryContainer;
      textColor = theme.colorScheme.onTertiaryContainer;
      iconData = Icons.check_circle_outline;
    }

    if (iconData == null) {
      return const SizedBox.shrink();
    }

    // This is now an icon-only chip for a cleaner look. A tooltip can be added.
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Icon(iconData, size: 16, color: textColor),
    );
  }

  // This widget now builds the subtitle-style text.
  Widget _buildItemsInfo(
    BuildContext context,
    ThemeData theme,
    List<Check> checks,
    int checkedCount,
  ) {
    return RichText(
      text: TextSpan(
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.onSurfaceVariant,
          fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
        ),
        children: [
          TextSpan(
            text: checks.length > 1
                ? '${checks.length} items'
                : '${checks.length} item',
          ),
          if (checkedCount > 0) ...[
            const TextSpan(text: '  •  '),
            TextSpan(
              text: '$checkedCount checked',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Updated loading content to match new layout.
  Widget _buildLoadingContent(
    BuildContext context,
    ThemeData theme, {
    Key? key,
  }) {
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha:0.05),
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.listPage.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Container(
                width: 120,
                height: 14,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha:0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Updated error content to match new layout.
  Widget _buildErrorContent(BuildContext context, ThemeData theme, {Key? key}) {
    return Row(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: theme.colorScheme.error.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.error_outline_rounded,
            color: theme.colorScheme.error,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.listPage.name,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                'Failed to load data',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
