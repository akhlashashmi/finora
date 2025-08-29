import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/routing/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final listStatsProvider = StreamProvider.autoDispose
    .family<List<Check>, String>((ref, listId) {
      final repo = ref.watch(expenseRepositoryProvider);
      return repo.watchChecksForList(listId);
    });

class ListPageCard extends ConsumerWidget {
  final ListPage listPage;
  const ListPageCard({super.key, required this.listPage});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(listStatsProvider(listPage.id));
    final currencyFormat = NumberFormat.currency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final compactCurrencyFormat = NumberFormat.compactCurrency(
      symbol: '\$',
      decimalDigits: 2,
    );
    final theme = Theme.of(context);

    void deleteList() {
      HapticFeedback.mediumImpact();
      ref.read(expenseRepositoryProvider).deleteListPage(listPage.id);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('${listPage.name} deleted')));
    }

    return Slidable(
      key: ValueKey(listPage.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => deleteList(),
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            icon: Icons.delete_outline,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(12),
              bottomRight: Radius.circular(12),
            ),
          ),
        ],
      ),
      child: Card(
        clipBehavior: Clip.antiAlias,
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1.0,
          ),
        ),
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            context.pushNamed(
              AppRoute.listDetails.name,
              pathParameters: {'listId': listPage.id},
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top Section (Name and Status)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      listPage.name,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    stats.when(
                      data: (checks) {
                        final total = checks.fold<double>(
                          0,
                          (sum, item) => sum + item.number,
                        );
                        final hasBudget = listPage.budget > 0;
                        final isOverBudget =
                            hasBudget && total > listPage.budget;

                        return Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            _InfoChip(
                              icon: Icons.list_alt,
                              label: '${checks.length} items',
                              color: theme.colorScheme.primary,
                            ),
                            if (hasBudget)
                              _InfoChip(
                                icon: isOverBudget
                                    ? Icons.warning_amber
                                    : Icons.account_balance_wallet,
                                label: isOverBudget
                                    ? 'Over Budget'
                                    : 'On Budget',
                                color: isOverBudget
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.tertiary,
                              ),
                          ],
                        );
                      },
                      loading: () => const _InfoChip(
                        icon: Icons.hourglass_empty,
                        label: 'Loading...',
                        color: Colors.grey,
                      ),
                      error: (_, __) => const _InfoChip(
                        icon: Icons.error_outline,
                        label: 'Error',
                        color: Colors.red,
                      ),
                    ),
                  ],
                ),

                // Middle Section (Progress and Stats)
                stats.when(
                  data: (checks) {
                    final total = checks.fold<double>(
                      0,
                      (sum, item) => sum + item.number,
                    );
                    final checked = checks
                        .where((c) => c.isSelected)
                        .fold<double>(0, (sum, item) => sum + item.number);
                    final hasBudget = listPage.budget > 0;
                    final useCompactFormat =
                        total > 999999 ||
                        (hasBudget && listPage.budget > 999999);
                    final numberFormat = useCompactFormat
                        ? compactCurrencyFormat
                        : currencyFormat;

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 12),
                        if (hasBudget)
                          _BudgetProgressBar(
                            total: total,
                            budget: listPage.budget,
                            theme: theme,
                          )
                        else
                          _SelectionProgressBar(
                            total: total,
                            checked: checked,
                            theme: theme,
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Total Value',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            Text(
                              numberFormat.format(total),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                  loading: () => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  error: (_, __) => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: Icon(Icons.error_outline, size: 20)),
                  ),
                ),

                // Bottom Section (Actions and Metadata)
                stats.when(
                  data: (checks) {
                    final checkedCount = checks
                        .where((c) => c.isSelected)
                        .length;
                    final hasBudget = listPage.budget > 0;

                    return Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$checkedCount/${checks.length} selected',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (hasBudget)
                          Text(
                            'Budget: ${currencyFormat.format(listPage.budget)}',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                      ],
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _InfoChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label, style: TextStyle(fontSize: 12, color: color)),
      avatar: Icon(icon, size: 16, color: color),
      backgroundColor: color.withValues(alpha: 0.1),
      side: BorderSide.none,
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
      labelPadding: const EdgeInsets.only(right: 4),
    );
  }
}

class _BudgetProgressBar extends StatelessWidget {
  final double total;
  final double budget;
  final ThemeData theme;

  const _BudgetProgressBar({
    required this.total,
    required this.budget,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final progress = (total / budget).clamp(0.0, 1.0);
    final isOverBudget = total > budget;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Budget Usage',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: isOverBudget
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              color: isOverBudget
                  ? theme.colorScheme.error
                  : theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectionProgressBar extends StatelessWidget {
  final double total;
  final double checked;
  final ThemeData theme;

  const _SelectionProgressBar({
    required this.total,
    required this.checked,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final progress = total > 0 ? (checked / total) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Selection Progress',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              '${(progress * 100).toStringAsFixed(0)}%',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        SizedBox(
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: theme.colorScheme.surfaceContainerHighest
                  .withValues(alpha: 0.3),
              color: theme.colorScheme.primary,
            ),
          ),
        ),
      ],
    );
  }
}
