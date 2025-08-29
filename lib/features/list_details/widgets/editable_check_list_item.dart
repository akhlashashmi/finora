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
        widget.inactiveColor ?? theme.colorScheme.outline.withOpacity(0.5);
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
                          color: activeColor.withOpacity(0.3),
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

    return Slidable(
      key: ValueKey(widget.check.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.25,
        children: [
          SlidableAction(
            onPressed: (_) => _deleteItem(),
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
            icon: Icons.delete_outline,
            borderRadius: BorderRadius.circular(12),
          ),
        ],
      ),

      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          crossAxisAlignment:
              CrossAxisAlignment.start, // Top-aligns the checkbox
          children: [
            // Custom Circular Checkbox - Top aligned
            Padding(
              padding: const EdgeInsets.only(top: 2.0),
              child: CustomCircularCheck(
                isChecked: isSelected,
                onChanged: (value) {
                  final updatedCheck = widget.check.copyWith(isSelected: value);
                  ref.read(expenseRepositoryProvider).updateCheck(updatedCheck);
                },
                size: 24.0,
                strokeWidth: 2.5,
                activeColor: theme.colorScheme.primary,
                checkColor: theme.colorScheme.onPrimary,
                inactiveColor: theme.colorScheme.outline.withOpacity(0.5),
              ),
            ),
            const SizedBox(width: 12),
            // Column for Number and Title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Number TextField (Primary)
                  TextField(
                    controller: _numberController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: '0.00',
                    ),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      decoration: isSelected
                          ? TextDecoration.lineThrough
                          : null,
                      color: isSelected
                          ? theme.hintColor
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Title TextField (Secondary)
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Item name...',
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      decoration: isSelected
                          ? TextDecoration.lineThrough
                          : null,
                      color: isSelected
                          ? theme.hintColor
                          : theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
