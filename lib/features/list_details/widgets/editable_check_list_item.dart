import 'dart:async';
import 'package:drift/drift.dart' show Value;
import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:intl/intl.dart';

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
        widget.inactiveColor ?? theme.colorScheme.outline.withValues(alpha:0.5);
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
                    color: activeColor.withValues(alpha:0.3),
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
  late final FocusNode _titleFocusNode;
  late final FocusNode _numberFocusNode;

  Timer? _debounce;
  bool _isEditing = false;

  static const double _maxNumberLimit = 999999999999.0;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.check.title);
    final numberString =
    NumberFormat.decimalPattern().format(widget.check.number);
    _numberController = TextEditingController(text: numberString);
    _titleFocusNode = FocusNode();
    _numberFocusNode = FocusNode();

    _titleController.addListener(_onTextChanged);
    _numberController.addListener(_onTextChanged);
    _titleFocusNode.addListener(_handleFocusChange);
    _numberFocusNode.addListener(_handleFocusChange);
  }

  @override
  void dispose() {
    _titleController.removeListener(_onTextChanged);
    _numberController.removeListener(_onTextChanged);
    _titleFocusNode.removeListener(_handleFocusChange);
    _numberFocusNode.removeListener(_handleFocusChange);
    _titleController.dispose();
    _numberController.dispose();
    _titleFocusNode.dispose();
    _numberFocusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onTextChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 750), _saveChanges);
  }

  void _handleFocusChange() {
    if (!_titleFocusNode.hasFocus && !_numberFocusNode.hasFocus && _isEditing) {
      _saveChanges();
      if (mounted) {
        setState(() {
          _isEditing = false;
        });
      }
    }
  }

  void _saveChanges() {
    final title = _titleController.text.trim();
    final number =
        double.tryParse(_numberController.text.trim().replaceAll(',', '')) ??
            widget.check.number;

    if (number.abs() > _maxNumberLimit) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Number cannot exceed 999 billion.'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
      final originalNumberString =
      NumberFormat.decimalPattern().format(widget.check.number);
      _numberController.text = originalNumberString;
      return;
    }

    if (title != (widget.check.title ?? '') || number != widget.check.number) {
      final updatedCheck = widget.check.copyWith(
        title: Value(title.isEmpty ? null : title),
        number: number,
      );
      ref.read(expenseRepositoryProvider).updateCheck(updatedCheck);
    }
  }

  void _deleteItem(BuildContext context) {
    HapticFeedback.mediumImpact();
    ref.read(expenseRepositoryProvider).deleteCheck(widget.check.id);
    Slidable.of(context)?.close();
  }

  void _enterEditMode(BuildContext context) {
    // Close the slidable first
    Slidable.of(context)?.close();

    // Then, enter edit mode
    if (mounted) {
      setState(() {
        _isEditing = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _titleFocusNode.requestFocus();
      });
    }
  }

  void _toggleCheckbox() {
    final updatedCheck = widget.check.copyWith(
      isSelected: !widget.check.isSelected,
    );
    ref.read(expenseRepositoryProvider).updateCheck(updatedCheck);
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
            extentRatio: 0.3,
            children: [
              SlidableActionItem(
                onPressed: (actionContext) => _enterEditMode(actionContext),
                backgroundColor: theme.colorScheme.secondary,
                foregroundColor: theme.colorScheme.onSecondaryContainer,
                icon: Icons.edit_rounded,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
              const SizedBox(width: 1),
              SlidableActionItem(
                onPressed: (actionContext) => _deleteItem(actionContext),
                backgroundColor: theme.colorScheme.error,
                foregroundColor: theme.colorScheme.onErrorContainer,
                icon: Icons.delete_outline,
                borderRadius: const BorderRadius.only(
                  topRight: Radius.circular(12),
                  bottomRight: Radius.circular(12),
                ),
              ),
            ],
          ),
          child: InkWell(
            onTap: _isEditing ? null : _toggleCheckbox,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              color: theme.colorScheme.surface,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 2.0),
                    child: CustomCircularCheck(
                      isChecked: isSelected,
                      onChanged: (_) => _toggleCheckbox(),
                      size: 22.0,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _isEditing
                        ? _buildEditView(theme, isSelected)
                        : _buildReadView(theme, isSelected),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadView(ThemeData theme, bool isSelected) {
    final numberFormat = widget.check.number.abs() > 999999
        ? NumberFormat.compactCurrency(symbol: '', decimalDigits: 2)
        : NumberFormat.currency(symbol: '', decimalDigits: 2);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          numberFormat.format(widget.check.number),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            decoration: isSelected ? TextDecoration.lineThrough : null,
            decorationColor: isSelected ? theme.hintColor : null,
            decorationThickness: 2.0,
            color: isSelected
                ? theme.hintColor.withValues(alpha:0.7)
                : theme.colorScheme.onSurface,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        if (widget.check.title != null && widget.check.title!.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            widget.check.title!,
            style: theme.textTheme.bodyMedium?.copyWith(
              decoration: isSelected ? TextDecoration.lineThrough : null,
              decorationColor:
              isSelected ? theme.hintColor.withValues(alpha:0.6) : null,
              decorationThickness: 1.5,
              color: isSelected
                  ? theme.hintColor.withValues(alpha:0.6)
                  : theme.colorScheme.onSurface.withValues(alpha:0.8),
              fontSize: 14,
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildEditView(ThemeData theme, bool isSelected) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _numberController,
          focusNode: _numberFocusNode,
          keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 2),
            hintText: '0.00',
            hintStyle: TextStyle(
              color: theme.hintColor.withValues(alpha:0.5),
              fontWeight: FontWeight.w500,
            ),
          ),
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: 'Item name...',
            hintStyle: TextStyle(
              color: theme.hintColor.withValues(alpha:0.4),
              fontSize: 14,
            ),
          ),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha:0.8),
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class SlidableActionItem extends StatelessWidget {
  final void Function(BuildContext) onPressed;
  final Color backgroundColor;
  final Color foregroundColor;
  final IconData icon;
  final BorderRadiusGeometry borderRadius;

  const SlidableActionItem({
    super.key,
    required this.onPressed,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.icon,
    required this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: 1,
      child: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              backgroundColor.withValues(alpha:0.1),
              backgroundColor.withValues(alpha:0.15),
            ],
          ),
          borderRadius: borderRadius,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            // UPDATED: Pass the correct context from this widget's build method
            onTap: () => onPressed(context),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  color: foregroundColor,
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}