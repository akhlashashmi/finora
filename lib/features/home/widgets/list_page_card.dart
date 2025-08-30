import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/home/widgets/edit_list_bottom_sheet.dart';
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

    void editList() {
      HapticFeedback.lightImpact();
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (_) => EditListBottomSheet(listPage: listPage),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8), // Reduced from 12
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12), // Reduced from 16
        child: Slidable(
          key: ValueKey(listPage.id),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.35, // Reduced from 0.4
            dragDismissible: false,
            children: [
              SizedBox(width: 8),
              // Edit Action
              Expanded(
                flex: 1,
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.1),
                        theme.colorScheme.primary.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: editList,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36, // Reduced from 44
                            height: 36, // Reduced from 44
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(
                                10,
                              ), // Reduced from 12
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.primary.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 6, // Reduced from 8
                                  offset: const Offset(
                                    0,
                                    1,
                                  ), // Reduced from (0, 2)
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.edit_outlined,
                              color: theme.colorScheme.onPrimary,
                              size: 18, // Reduced from 20
                            ),
                          ),
                          const SizedBox(height: 4), // Reduced from 8
                          Text(
                            'Edit',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              fontSize: 10, // Added smaller font
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Delete Action
              Expanded(
                flex: 1,
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        theme.colorScheme.error.withOpacity(0.1),
                        theme.colorScheme.error.withOpacity(0.15),
                      ],
                    ),
                    borderRadius: const BorderRadius.only(
                      topRight: Radius.circular(12),
                      bottomRight: Radius.circular(12),
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: deleteList,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36, // Reduced from 44
                            height: 36, // Reduced from 44
                            decoration: BoxDecoration(
                              color: theme.colorScheme.error,
                              borderRadius: BorderRadius.circular(
                                10,
                              ), // Reduced from 12
                              boxShadow: [
                                BoxShadow(
                                  color: theme.colorScheme.error.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 6, // Reduced from 8
                                  offset: const Offset(
                                    0,
                                    1,
                                  ), // Reduced from (0, 2)
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.delete_outline,
                              color: theme.colorScheme.onError,
                              size: 18, // Reduced from 20
                            ),
                          ),
                          const SizedBox(height: 4), // Reduced from 8
                          Text(
                            'Delete',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.error,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.5,
                              fontSize: 10, // Added smaller font
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Reduced from 16
              side: BorderSide(
                color: theme.colorScheme.outline.withOpacity(0.2),
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
                padding: const EdgeInsets.all(12.0), // Reduced from 16
                child: Container(
                  height: 80, // Fixed height for all cards
                  child: stats.when(
                    data: (checks) {
                      final total = checks.fold<double>(
                        0,
                        (sum, item) => sum + item.number,
                      );
                      final checked = checks
                          .where((c) => c.isSelected)
                          .fold<double>(0, (sum, item) => sum + item.number);
                      final checkedCount = checks
                          .where((c) => c.isSelected)
                          .length;
                      final hasBudget = listPage.budget > 0;
                      final isOverBudget = hasBudget && total > listPage.budget;
                      final useCompactFormat =
                          total > 999999 ||
                          (hasBudget && listPage.budget > 999999);
                      final numberFormat = useCompactFormat
                          ? compactCurrencyFormat
                          : currencyFormat;

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Header row with name and key stats
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listPage.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '$checkedCount/${checks.length} selected',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              // Total value prominently displayed
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    numberFormat.format(total),
                                    style: theme.textTheme.titleMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w700,
                                          color: theme.colorScheme.primary,
                                        ),
                                  ),
                                  // Always reserve space for budget info to maintain consistent height
                                  SizedBox(
                                    height: 16,
                                    child: hasBudget
                                        ? Text(
                                            'of ${numberFormat.format(listPage.budget)}',
                                            style: theme.textTheme.bodySmall
                                                ?.copyWith(
                                                  color: theme
                                                      .colorScheme
                                                      .onSurfaceVariant,
                                                ),
                                          )
                                        : null,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          // Fixed height bottom section for status
                          SizedBox(
                            height: 18,
                            child: Row(
                              children: [
                                if (isOverBudget)
                                  _CompactChip(
                                    icon: Icons.warning_amber,
                                    label: 'Over Budget',
                                    color: theme.colorScheme.error,
                                  )
                                else if (checks.length > 10)
                                  _CompactChip(
                                    icon: Icons.list_alt,
                                    label: '${checks.length} items',
                                    color: theme.colorScheme.primary,
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                    loading: () => Container(
                      height: 80, // Same fixed height
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listPage.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Loading...',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme
                                                .colorScheme
                                                .onSurfaceVariant,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            ],
                          ),
                          // Fixed height bottom section
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                    error: (_, __) => Container(
                      height: 80, // Same fixed height
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      listPage.name,
                                      style: theme.textTheme.titleMedium
                                          ?.copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      'Error loading data',
                                      style: theme.textTheme.bodySmall
                                          ?.copyWith(
                                            color: theme.colorScheme.error,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                Icons.error_outline,
                                size: 16,
                                color: theme.colorScheme.error,
                              ),
                            ],
                          ),
                          // Fixed height bottom section for status
                          const SizedBox(height: 18),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _CompactChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
