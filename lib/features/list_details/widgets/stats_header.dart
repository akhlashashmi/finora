import 'package:finora/data/local/app_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatsHeader extends StatelessWidget {
  final ListPage listPage;
  final List<Check> checks;
  final bool isPinned;

  const StatsHeader({
    super.key,
    required this.listPage,
    required this.checks,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '\$', decimalDigits: 2);
    final compactCurrencyFormat =
    NumberFormat.compactCurrency(symbol: '\$', decimalDigits: 2);

    // Calculate statistics
    final totalItems = checks.length;
    final selectedCount = checks.where((c) => c.isSelected).length;
    final totalAmount = checks.fold<double>(0.0, (sum, c) => sum + c.number);
    final selectedAmount = checks
        .where((c) => c.isSelected)
        .fold<double>(0.0, (sum, c) => sum + c.number);

    final hasBudget = listPage.budget > 0;
    final remaining = listPage.budget - totalAmount;
    final budgetUsedPercentage = hasBudget && listPage.budget > 0
        ? (totalAmount / listPage.budget).clamp(0.0, 1.0)
        : 0.0;

    // Determine if we need to use compact formatting
    final useCompactFormat = isPinned ||
        totalAmount > 999999 ||
        (hasBudget && listPage.budget > 999999);
    final numberFormat = useCompactFormat ? compactCurrencyFormat : currencyFormat;

    // New stats: average item value
    final averageAmount = totalItems > 0 ? totalAmount / totalItems : 0;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16), // Vertical margin removed
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceVariant.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.outline.withOpacity(0.1)),
      ),
      child: Column(
        // === FIX APPLIED HERE ===
        // mainAxisSize: MainAxisSize.min, // REMOVED this line
        mainAxisAlignment: MainAxisAlignment.center, // ADDED this line
        // ========================
        children: [
          // Primary Statistics Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                if (!isPinned) ...[
                  _StatTile(
                    icon: Icons.check_circle_outline,
                    label: 'Completed',
                    value: '$selectedCount/$totalItems',
                    theme: theme,
                    isCurrency: false,
                    progress: totalItems > 0 ? selectedCount / totalItems : 0.0,
                  ),
                  _VerticalDivider(theme: theme),
                ],
                _StatTile(
                  icon: Icons.attach_money_outlined,
                  label: 'Total',
                  value: numberFormat.format(totalAmount),
                  theme: theme,
                  isCurrency: true,
                  valueColor: theme.colorScheme.primary,
                ),
                if (!isPinned) ...[
                  _VerticalDivider(theme: theme),
                  _StatTile(
                    icon: Icons.trending_up_outlined,
                    label: 'Average',
                    value: numberFormat.format(averageAmount),
                    theme: theme,
                    isCurrency: true,
                    valueColor: theme.colorScheme.tertiary,
                  ),
                ],
              ],
            ),
          ),

          // Budget & Selected Amount Row (if budget exists or items are selected)
          if ((hasBudget || selectedCount > 0) && !isPinned) ...[
            Container(
              height: 1,
              color: theme.colorScheme.outline.withOpacity(0.1),
              margin: const EdgeInsets.symmetric(horizontal: 20),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  if (hasBudget) ...[
                    Expanded(
                      child: _StatTile(
                        icon: Icons.account_balance_wallet_outlined,
                        label: 'Budget',
                        value: numberFormat.format(listPage.budget),
                        theme: theme,
                        isCurrency: true,
                        progress: budgetUsedPercentage,
                        progressColor: budgetUsedPercentage > 1.0
                            ? theme.colorScheme.error
                            : budgetUsedPercentage > 0.8
                            ? Colors.orange
                            : theme.colorScheme.primary,
                      ),
                    ),
                    _VerticalDivider(theme: theme),
                    Expanded(
                      child: _StatTile(
                        icon: remaining < 0
                            ? Icons.warning_outlined
                            : Icons.savings_outlined,
                        label: remaining < 0 ? 'Over Budget' : 'Remaining',
                        value: numberFormat.format(remaining.abs()),
                        theme: theme,
                        isCurrency: true,
                        valueColor: remaining < 0
                            ? theme.colorScheme.error
                            : theme.colorScheme.primary,
                      ),
                    ),
                  ],
                  if (selectedCount > 0) ...[
                    if (hasBudget) _VerticalDivider(theme: theme),
                    Expanded(
                      child: _StatTile(
                        icon: Icons.shopping_cart_outlined,
                        label: 'Selected',
                        value: numberFormat.format(selectedAmount),
                        theme: theme,
                        isCurrency: true,
                        valueColor: theme.colorScheme.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _VerticalDivider extends StatelessWidget {
  final ThemeData theme;

  const _VerticalDivider({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 40,
      color: theme.colorScheme.outline.withOpacity(0.2),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final ThemeData theme;
  final Color? valueColor;
  final double? progress;
  final Color? progressColor;
  final bool isCurrency;

  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.theme,
    required this.isCurrency,
    this.valueColor,
    this.progress,
    this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 20,
          color: valueColor ?? theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(height: 4),
        if (progress != null) ...[
          Container(
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceVariant,
              borderRadius: BorderRadius.circular(1.5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress!.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  color: progressColor ?? theme.colorScheme.primary,
                  borderRadius: BorderRadius.circular(1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: valueColor ?? theme.colorScheme.onSurface,
          ),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}