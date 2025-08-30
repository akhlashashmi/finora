import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

// Custom Circular Check Widget
class CustomCircularCheck extends StatefulWidget {
  final bool isChecked;
  final ValueChanged<bool>? onChanged;
  final double size;
  final Color? activeColor;
  final Color? inactiveColor;
  final Color? checkColor;
  final Duration animationDuration;
  final double strokeWidth;

  const CustomCircularCheck({
    super.key,
    required this.isChecked,
    this.onChanged,
    this.size = 24.0,
    this.activeColor,
    this.inactiveColor,
    this.checkColor,
    this.animationDuration = const Duration(milliseconds: 200),
    this.strokeWidth = 2.0,
  });

  @override
  State<CustomCircularCheck> createState() => _CustomCircularCheckState();
}

class _CustomCircularCheckState extends State<CustomCircularCheck>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _checkAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: widget.animationDuration,
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.9).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut),
      ),
    );

    _checkAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.elasticOut),
      ),
    );

    if (widget.isChecked) {
      _animationController.value = 1.0;
    }
  }

  @override
  void didUpdateWidget(CustomCircularCheck oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isChecked != widget.isChecked) {
      if (widget.isChecked) {
        _animationController.forward();
      } else {
        _animationController.reverse();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = widget.activeColor ?? theme.colorScheme.primary;
    final inactiveColor =
        widget.inactiveColor ??
        theme.colorScheme.outline.withValues(alpha: 0.5);
    final checkColor = widget.checkColor ?? theme.colorScheme.onPrimary;

    return GestureDetector(
      onTap: widget.onChanged != null
          ? () => widget.onChanged!(!widget.isChecked)
          : null,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Container(
              width: widget.size,
              height: widget.size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.isChecked ? activeColor : Colors.transparent,
                border: Border.all(
                  color: widget.isChecked ? activeColor : inactiveColor,
                  width: widget.strokeWidth,
                ),
                boxShadow: widget.isChecked
                    ? [
                        BoxShadow(
                          color: activeColor.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: widget.isChecked
                  ? Center(
                      child: Transform.scale(
                        scale: _checkAnimation.value,
                        child: Icon(
                          Icons.check,
                          size: widget.size * 0.6,
                          color: checkColor,
                          weight: 600,
                        ),
                      ),
                    )
                  : null,
            ),
          );
        },
      ),
    );
  }
}

class EditableCheckListItem extends ConsumerStatefulWidget {
  final Check check;
  const EditableCheckListItem({super.key, required this.check});

  @override
  ConsumerState<EditableCheckListItem> createState() =>
      _EditableCheckListItemState();
}

class _EditableCheckListItemState extends ConsumerState<EditableCheckListItem> {
  late final TextEditingController _titleController;
  late final TextEditingController _numberController;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.check.title);
    final numberString = NumberFormat.decimalPattern().format(
      widget.check.number,
    );
    _numberController = TextEditingController(text: numberString);

    // Add listeners to save changes after a short delay
    _titleController.addListener(_onTextChanged);
    _numberController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), _saveChanges);
  }

  void _saveChanges() {
    final title = _titleController.text.trim();
    final number =
        double.tryParse(_numberController.text.trim().replaceAll(',', '')) ??
        widget.check.number;

    if (title != (widget.check.title ?? '') || number != widget.check.number) {
      final updatedCheck = widget.check.copyWith(
        title: Value(title.isEmpty ? null : title),
        number: number,
      );
      ref.read(expenseRepositoryProvider).updateCheck(updatedCheck);
    }
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _numberController.removeListener(_onTextChanged);
    _titleController.dispose();
    _numberController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _deleteItem() {
    HapticFeedback.mediumImpact();
    ref.read(expenseRepositoryProvider).deleteCheck(widget.check.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSelected = widget.check.isSelected;

    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Slidable(
          key: ValueKey(widget.check.id),
          endActionPane: ActionPane(
            motion: const BehindMotion(),
            extentRatio: 0.25,
            dragDismissible: false,
            children: [
              // Delete Action with Professional Styling
              Expanded(
                child: Container(
                  height: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(12),
                      bottomLeft: Radius.circular(12),
                    ),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        theme.colorScheme.error.withValues(alpha: 0.05),
                        theme.colorScheme.error.withValues(alpha: 0.1),
                      ],
                    ),
                  ),
                  child: InkWell(
                    onTap: _deleteItem,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: theme.colorScheme.error.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            color: theme.colorScheme.onError,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(color: theme.colorScheme.surface),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Custom Circular Checkbox - Top aligned with better spacing
                Padding(
                  padding: const EdgeInsets.only(top: 3.0, right: 2.0),
                  child: CustomCircularCheck(
                    isChecked: isSelected,
                    onChanged: (value) {
                      final updatedCheck = widget.check.copyWith(
                        isSelected: value,
                      );
                      ref
                          .read(expenseRepositoryProvider)
                          .updateCheck(updatedCheck);
                    },
                    size: 22.0,
                    strokeWidth: 2.0,
                    activeColor: theme.colorScheme.primary,
                    checkColor: theme.colorScheme.onPrimary,
                    inactiveColor: theme.colorScheme.outline.withValues(
                      alpha: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Column for Number and Title with improved layout
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Number TextField (Primary) with better styling
                      TextField(
                        controller: _numberController,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 2,
                          ),
                          hintText: '0.00',
                          hintStyle: TextStyle(
                            color: theme.hintColor.withValues(alpha: 0.5),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          decoration: isSelected
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: isSelected ? theme.hintColor : null,
                          decorationThickness: 2.0,
                          color: isSelected
                              ? theme.hintColor.withValues(alpha: 0.7)
                              : theme.colorScheme.onSurface,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      // Title TextField (Secondary) with improved styling
                      TextField(
                        controller: _titleController,
                        decoration: InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                          hintText: 'Item name...',
                          hintStyle: TextStyle(
                            color: theme.hintColor.withValues(alpha: 0.4),
                            fontSize: 14,
                          ),
                        ),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          decoration: isSelected
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: isSelected
                              ? theme.hintColor.withValues(alpha: 0.6)
                              : null,
                          decorationThickness: 1.5,
                          color: isSelected
                              ? theme.hintColor.withValues(alpha: 0.6)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.8,
                                ),
                          fontSize: 14,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
