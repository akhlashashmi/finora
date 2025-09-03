import 'dart:ui';
import 'package:finora/data/local/app_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class StatsHeader extends StatelessWidget {
  final ListPage listPage;
  final List<Check> checks;

  const StatsHeader({
    super.key,
    required this.listPage,
    required this.checks,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currencyFormat = NumberFormat.currency(symbol: '', decimalDigits: 2);
    final compactCurrencyFormat =
    NumberFormat.compactCurrency(symbol: '', decimalDigits: 2);

    // CALCULATIONS
    final totalItems = checks.length;
    final selectedCount = checks.where((c) => c.isSelected).length;
    final totalAmount = checks.fold<double>(0.0, (sum, c) => sum + c.number);
    final selectedAmount = checks
        .where((c) => c.isSelected)
        .fold<double>(0.0, (sum, c) => sum + c.number);

    final hasBudget = listPage.budget > 0;
    final remainingForTotal = listPage.budget - totalAmount;
    final remainingForSelected = listPage.budget - selectedAmount;

    final budgetUsedPercentage = hasBudget && listPage.budget > 0
        ? (totalAmount / listPage.budget).clamp(0.0, 1.0)
        : 0.0;

    final useCompactFormat =
        totalAmount > 999999 || (hasBudget && listPage.budget > 999999);
    final numberFormat =
    useCompactFormat ? compactCurrencyFormat : currencyFormat;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 7, sigmaY: 7),
        child: Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceVariant.withValues(alpha:0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: theme.colorScheme.outline.withValues(alpha:0.2)),
          ),
          child: _buildExpandedView(
            context,
            theme,
            numberFormat,
            selectedAmount,
            totalAmount,
            selectedCount,
            totalItems,
            hasBudget,
            remainingForSelected,
            remainingForTotal,
            budgetUsedPercentage,
          ),
        ),
      ),
    );
  }

  Widget _buildExpandedView(
      BuildContext context,
      ThemeData theme,
      NumberFormat numberFormat,
      double selectedAmount,
      double totalAmount,
      int selectedCount,
      int totalItems,
      bool hasBudget,
      double remainingForSelected,
      double remainingForTotal,
      double budgetUsedPercentage,
      ) {
    return Padding( // Use padding instead of margin
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Primary Statistics Row
          Padding(
            // Reduced vertical padding to prevent overflow
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: _StatTile(
                    icon: Icons.shopping_cart_checkout,
                    label: 'Selected',
                    value: numberFormat.format(selectedAmount),
                    theme: theme,
                    isCurrency: true,
                    valueColor: theme.colorScheme.secondary,
                  ),
                ),
                _VerticalDivider(theme: theme),
                Expanded(
                  child: _StatTile(
                    icon: Icons.attach_money_outlined,
                    label: 'Total',
                    value: numberFormat.format(totalAmount),
                    theme: theme,
                    isCurrency: true,
                    valueColor: theme.colorScheme.primary,
                  ),
                ),
                _VerticalDivider(theme: theme),
                Expanded(
                  child: _StatTile(
                    icon: Icons.check_circle_outline,
                    label: 'Items',
                    value: '$selectedCount/$totalItems',
                    theme: theme,
                    isCurrency: false,
                    progress: totalItems > 0 ? selectedCount / totalItems : 0.0,
                  ),
                ),
              ],
            ),
          ),

          // Budget Row
          if (hasBudget) ...[
            Container(
              height: 1,
              color: theme.colorScheme.outline.withValues(alpha:0.1),
              margin: const EdgeInsets.symmetric(horizontal: 4),
            ),
            Padding(
              // Reduced vertical padding to prevent overflow
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
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
                      icon: remainingForSelected < 0
                          ? Icons.warning_amber_rounded
                          : Icons.price_check_rounded,
                      label: remainingForSelected < 0
                          ? 'Over (Selected)'
                          : 'Left (Selected)',
                      value: numberFormat.format(remainingForSelected.abs()),
                      theme: theme,
                      isCurrency: true,
                      valueColor: remainingForSelected < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.secondary,
                    ),
                  ),
                  _VerticalDivider(theme: theme),
                  Expanded(
                    child: _StatTile(
                      icon: remainingForTotal < 0
                          ? Icons.warning_amber_rounded
                          : Icons.savings_outlined,
                      label:
                      remainingForTotal < 0 ? 'Over (Total)' : 'Left (Total)',
                      value: numberFormat.format(remainingForTotal.abs()),
                      theme: theme,
                      isCurrency: true,
                      valueColor: remainingForTotal < 0
                          ? theme.colorScheme.error
                          : theme.colorScheme.primary,
                    ),
                  ),
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
      color: theme.colorScheme.outline.withValues(alpha:0.2),
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
          color: valueColor ?? theme.colorScheme.onSurface.withValues(alpha:0.7),
        ),
        // Reduced vertical spacing
        const SizedBox(height: 2),
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
          // Reduced vertical spacing
          const SizedBox(height: 4),
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
            color: theme.colorScheme.onSurface.withValues(alpha:0.6),
          ),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}