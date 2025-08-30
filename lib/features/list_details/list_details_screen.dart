import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/list_details/widgets/editable_check_list_item.dart';
import 'package:finora/features/list_details/widgets/stats_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:math_expressions/math_expressions.dart' hide Stack;

// Enum for cycling through stats in the AppBar
enum StatsDisplayMode {
  amount,
  count,
  budget,
  remainingSelected,
  remainingTotal,
}

// --- Providers ---
final listPageStreamProvider = StreamProvider.autoDispose
    .family<ListPage?, String>((ref, listId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchListById(listId);
});

final checksStreamProvider = StreamProvider.autoDispose
    .family<List<Check>, String>((ref, listId) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchChecksForList(listId);
});

class ListDetailsScreen extends ConsumerStatefulWidget {
  final String listId;
  const ListDetailsScreen({super.key, required this.listId});

  @override
  ConsumerState<ListDetailsScreen> createState() => _ListDetailsScreenState();
}

class _ListDetailsScreenState extends ConsumerState<ListDetailsScreen>
    with TickerProviderStateMixin {
  bool _showStats = false;
  late ScrollController _scrollController;
  late FocusNode _newItemFocusNode;
  bool _initialScrollDone = false;
  final GlobalKey _statsButtonKey = GlobalKey();
  OverlayEntry? _statsOverlay;
  late AnimationController _overlayAnimationController;
  StatsDisplayMode _statsDisplayMode = StatsDisplayMode.amount;

  bool _showFloatingButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _newItemFocusNode = FocusNode();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _newItemFocusNode.dispose();
    if (_statsOverlay != null) {
      _overlayAnimationController.dispose();
      _statsOverlay?.remove();
    }
    super.dispose();
  }

  void _scrollListener() {
    final shouldShow = _scrollController.offset > kToolbarHeight;
    if (shouldShow != _showFloatingButton) {
      setState(() {
        _showFloatingButton = shouldShow;
      });
    }
  }

  void _handleStatsToggle(ListPage list, List<Check> checks) {
    if (_showStats) {
      _hideStatsOverlay();
    } else {
      _showStatsOverlay(list, checks);
    }
  }

  void _hideStatsOverlay() {
    if (!_showStats) return;
    _overlayAnimationController.reverse().then((_) {
      _statsOverlay?.remove();
      _statsOverlay = null;
      if (mounted) {
        _overlayAnimationController.dispose();
        setState(() {
          _showStats = false;
        });
      }
    });
  }

  void _showStatsOverlay(ListPage list, List<Check> checks) {
    if (_showStats) return;

    final renderBox =
    _statsButtonKey.currentContext?.findRenderObject() as RenderBox?;
    final buttonPosition =
        renderBox?.localToGlobal(Offset.zero) ??
            Offset(MediaQuery.of(context).size.width - 60, kToolbarHeight);
    final buttonSize = renderBox?.size ?? const Size(40, 40);

    final hasBudget = list.budget > 0;
    final finalHeight = hasBudget ? 180.0 : 90.0;

    _overlayAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      reverseDuration: const Duration(milliseconds: 300),
    );

    _statsOverlay = OverlayEntry(
      builder: (context) => _buildStatsOverlay(
        context,
        list,
        checks,
        buttonPosition,
        buttonSize,
        finalHeight,
      ),
    );
    Overlay.of(context).insert(_statsOverlay!);
    _overlayAnimationController.forward();
    setState(() {
      _showStats = true;
    });
  }

  Widget _buildStatsOverlay(
      BuildContext context,
      ListPage list,
      List<Check> checks,
      Offset buttonPosition,
      Size buttonSize,
      double finalHeight,
      ) {
    return AnimatedBuilder(
      animation: _overlayAnimationController,
      builder: (context, child) {
        final value = Curves.easeInOut.transform(
          _overlayAnimationController.value,
        );
        final currentLeft = buttonPosition.dx + (0 - buttonPosition.dx) * value;
        final currentTop =
            buttonPosition.dy + (kToolbarHeight - buttonPosition.dy) * value;
        final currentWidth =
            buttonSize.width +
                (MediaQuery.of(context).size.width - buttonSize.width) * value;
        final currentHeight =
            buttonSize.height + (finalHeight - buttonSize.height) * value;

        return Positioned(
          left: currentLeft,
          top: currentTop / 1.5,
          child: GestureDetector(
            onTap: _hideStatsOverlay,
            onVerticalDragUpdate: (details) {
              double delta = details.primaryDelta! / finalHeight;
              _overlayAnimationController.value -= delta;
            },
            onVerticalDragEnd: (details) {
              if (_overlayAnimationController.value < 0.5 ||
                  details.primaryVelocity! > 500) {
                _hideStatsOverlay();
              } else {
                _overlayAnimationController.forward(
                  from: _overlayAnimationController.value,
                );
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              width: currentWidth,
              height: currentHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.25 * value),
                    blurRadius: 20 * value,
                    offset: Offset(0, 4 * value),
                  ),
                ],
              ),
              child: Opacity(
                opacity: value,
                child: FittedBox(
                  fit: BoxFit.fill,
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width,
                    height: finalHeight,
                    child: StatsHeader(listPage: list, checks: checks),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _scrollToBottomAndFocusNewItem({bool forceScroll = false}) {
    if (!_initialScrollDone || forceScroll) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
          _newItemFocusNode.requestFocus();
          if (!forceScroll) _initialScrollDone = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(listPageStreamProvider(widget.listId));
    final checksAsync = ref.watch(checksStreamProvider(widget.listId));
    final theme = Theme.of(context);

    if (checksAsync.value != null && !_initialScrollDone) {
      _scrollToBottomAndFocusNewItem();
    }

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: listAsync.when(
          data: (list) {
            if (list == null)
              return const Center(child: Text('List not found'));
            return _buildContent(list, checksAsync, theme);
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (err, stack) =>
              Center(child: Text('Error loading list: $err')),
        ),
      ),
    );
  }

  Widget _buildContent(
      ListPage list,
      AsyncValue<List<Check>> checksAsync,
      ThemeData theme,
      ) {
    return Stack(
      children: [
        CustomScrollView(
          controller: _scrollController,
          slivers: [
            SliverAppBar(
              elevation: 0,
              scrolledUnderElevation: 1,
              surfaceTintColor: theme.colorScheme.surfaceTint,
              backgroundColor: theme.scaffoldBackgroundColor,
              pinned: false,
              floating: true,
              snap: true,
              title: _buildStatsButton(theme, checksAsync, list),
              centerTitle: true,
              actions: const [],
            ),
            checksAsync.when(
              data: (checks) => SliverPadding(
                padding: const EdgeInsets.fromLTRB(10, 10, 0, 0),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate((context, index) {
                    final check = checks[index];
                    return Padding(
                      padding: const EdgeInsets.only(left: 10, right: 10),
                      child: EditableCheckListItem(
                        key: ValueKey(check.id),
                        check: check,
                      ),
                    );
                  }, childCount: checks.length),
                ),
              ),
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Error loading items: $err')),
              ),
            ),
            SliverToBoxAdapter(
              child: NewItemInput(
                listId: widget.listId,
                focusNode: _newItemFocusNode,
                onAdded: () =>
                    _scrollToBottomAndFocusNewItem(forceScroll: true),
              ),
            ),
          ],
        ),
        _buildFloatingStatsButton(list, checksAsync, theme),
      ],
    );
  }

  Widget _buildFloatingStatsButton(
      ListPage list,
      AsyncValue<List<Check>> checksAsync,
      ThemeData theme,
      ) {
    return AnimatedOpacity(
      opacity: _showFloatingButton ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 200),
      child: IgnorePointer(
        ignoring: !_showFloatingButton,
        child: checksAsync.when(
          data: (checks) {
            return Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.only(top: kToolbarHeight, right: 16),
                child: FloatingActionButton.small(
                  heroTag: 'fab_stats_toggle',
                  onPressed: () => _handleStatsToggle(list, checks),
                  elevation: 2,
                  child: Icon(
                    _showStats ? Icons.close : Icons.insights,
                    size: 22,
                  ),
                ),
              ),
            );
          },
          loading: () => const SizedBox.shrink(),
          error: (_, __) => const SizedBox.shrink(),
        ),
      ),
    );
  }

  void _cycleStatsDisplay(bool hasBudget) {
    final availableModes = [
      StatsDisplayMode.amount,
      StatsDisplayMode.count,
    ];
    if (hasBudget) {
      availableModes.addAll([
        StatsDisplayMode.budget,
        StatsDisplayMode.remainingSelected,
        StatsDisplayMode.remainingTotal,
      ]);
    }

    // If current mode is not available (e.g., budget was removed), reset to amount
    if (!availableModes.contains(_statsDisplayMode)) {
      setState(() {
        _statsDisplayMode = StatsDisplayMode.amount;
      });
      return;
    }

    setState(() {
      final currentIndex = availableModes.indexOf(_statsDisplayMode);
      final nextIndex = (currentIndex + 1) % availableModes.length;
      _statsDisplayMode = availableModes[nextIndex];
    });
  }

  String _getDisplayTextForStatsMode({
    required StatsDisplayMode mode,
    required List<Check> checks,
    required ListPage list,
    required NumberFormat numberFormat,
  }) {
    // Calculations
    final selectedAmount = checks
        .where((c) => c.isSelected)
        .fold<double>(0.0, (sum, c) => sum + c.number);
    final totalAmount = checks.fold<double>(0.0, (sum, c) => sum + c.number);
    final selectedCount = checks.where((c) => c.isSelected).length;
    final totalCount = checks.length;
    final remainingForTotal = list.budget - totalAmount;
    final remainingForSelected = list.budget - selectedAmount;

    switch (mode) {
      case StatsDisplayMode.amount:
        return '${numberFormat.format(selectedAmount)} / ${numberFormat.format(totalAmount)}';
      case StatsDisplayMode.count:
        return 'Items: $selectedCount / $totalCount';
      case StatsDisplayMode.budget:
        return 'Budget: ${numberFormat.format(list.budget)}';
      case StatsDisplayMode.remainingSelected:
        final prefix = remainingForSelected < 0 ? 'Over:' : 'Left:';
        return '$prefix ${numberFormat.format(remainingForSelected.abs())} (Sel)';
      case StatsDisplayMode.remainingTotal:
        final prefix = remainingForTotal < 0 ? 'Over:' : 'Left:';
        return '$prefix ${numberFormat.format(remainingForTotal.abs())} (Total)';
    }
  }

  Widget _buildStatsButton(
      ThemeData theme,
      AsyncValue<List<Check>> checksAsync,
      ListPage list,
      ) {
    return checksAsync.when(
      data: (checks) {
        final totalAmount = checks.fold<double>(0.0, (sum, c) => sum + c.number);
        final hasBudget = list.budget > 0;
        final useCompactFormat = totalAmount > 999999 || (hasBudget && list.budget > 999999);

        final numberFormat = useCompactFormat
            ? NumberFormat.compact()
            : NumberFormat('#,##0.##');

        final displayText = _getDisplayTextForStatsMode(
          mode: _statsDisplayMode,
          checks: checks,
          list: list,
          numberFormat: numberFormat,
        );

        return TextButton(
          key: _statsButtonKey,
          onPressed: () => _cycleStatsDisplay(hasBudget),
          onLongPress: () => _handleStatsToggle(list, checks),
          child: Text(
            displayText,
            style: theme.textTheme.titleMedium?.copyWith(
              color: _showStats
                  ? theme.colorScheme.primary
                  : theme.colorScheme.onSurface.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (err, stack) => const SizedBox.shrink(),
    );
  }
}

class NewItemInput extends ConsumerStatefulWidget {
  final String listId;
  final VoidCallback onAdded;
  final FocusNode focusNode;

  const NewItemInput({
    super.key,
    required this.listId,
    required this.onAdded,
    required this.focusNode,
  });

  @override
  ConsumerState<NewItemInput> createState() => _NewItemInputState();
}

class _NewItemInputState extends ConsumerState<NewItemInput> {
  final _controller = TextEditingController();
  bool _isNumericKeyboard = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Tries to evaluate a string as a math expression first, then falls back
  /// to parsing it as a simple number (which supports percentages, etc.).
  double? _evaluateOrParseNumber(String numberStr) {
    // Try full math evaluation first. This handles "12+3", "5*4", "12.5" etc.
    final mathResult = _evaluateMathExpression(numberStr);
    if (mathResult != null) {
      return mathResult;
    }

    // Fallback for formats not supported by the math parser, like percentages.
    final simpleParseResult = _parseNumber(numberStr);
    return simpleParseResult;
  }

  /// Parses input for patterns like "Title Number" or "Number Title".
  /// This is called only after the primary math expression check fails in _submit.
  ParsedInput _parseInput(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return ParsedInput();

    // Pattern 1: Expression/Number at the end (e.g., "Coffee 12+3")
    final endNumberMatch =
    RegExp(r'^(.*?)\s+([\d\.,\+\-\*\/\(\)%\/]+)$').firstMatch(trimmed);
    if (endNumberMatch != null) {
      final title = endNumberMatch.group(1)?.trim();
      final numberPart = endNumberMatch.group(2)!;
      final number = _evaluateOrParseNumber(numberPart); // Use new helper
      if (number != null) {
        return ParsedInput(
          number: number,
          title: title?.isNotEmpty == true ? title : null,
        );
      }
    }

    // Pattern 2: Expression/Number at the beginning (e.g., "12+3 Coffee")
    final startNumberMatch =
    RegExp(r'^([\d\.,\+\-\*\/\(\)%\/]+)\s+(.*?)$').firstMatch(trimmed);
    if (startNumberMatch != null) {
      final numberPart = startNumberMatch.group(1)!;
      final title = startNumberMatch.group(2)?.trim();
      final number = _evaluateOrParseNumber(numberPart); // Use new helper
      if (number != null) {
        return ParsedInput(
          number: number,
          title: title?.isNotEmpty == true ? title : null,
        );
      }
    }

    // Pattern 3: The whole string is just a simple number or percentage
    final onlyNumber = _evaluateOrParseNumber(trimmed);
    if (onlyNumber != null) {
      return ParsedInput(number: onlyNumber);
    }

    // Pattern 4: The whole string is just text
    return ParsedInput(title: trimmed);
  }

  /// Evaluates mathematical expressions using proper BODMAS rules.
  double? _evaluateMathExpression(String expression) {
    try {
      // Prepare the expression for the parser.
      String preparedExpression =
      expression.replaceAll(',', '').replaceAll(' ', '');
      if (preparedExpression.isEmpty) return null;

      Parser p = Parser();
      Expression exp = p.parse(preparedExpression);
      ContextModel cm = ContextModel();
      final result = exp.evaluate(EvaluationType.REAL, cm);

      // Ensure the result is a finite number.
      if (result is double && result.isFinite) {
        return result;
      }
      return null;
    } catch (e) {
      // If parsing or evaluation fails, it's not a valid math expression.
      return null;
    }
  }

  /// Robustly parses a string into a double, handling percentages and fractions.
  double? _parseNumber(String numberStr) {
    try {
      // Handle percentage values (e.g., "50%")
      if (numberStr.endsWith('%')) {
        final value = double.tryParse(
          numberStr.substring(0, numberStr.length - 1),
        );
        return value != null ? value / 100 : null;
      }

      // Handle fractions (e.g., "3/4")
      if (numberStr.contains('/')) {
        final parts = numberStr.split('/');
        if (parts.length == 2) {
          final numerator = double.tryParse(parts[0]);
          final denominator = double.tryParse(parts[1]);
          if (numerator != null && denominator != null && denominator != 0) {
            return numerator / denominator;
          }
        }
      }

      return double.tryParse(numberStr);
    } catch (e) {
      return null;
    }
  }

  void _submit(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    // Priority 1: Check if the entire input is a solvable math expression.
    final mathResult = _evaluateMathExpression(trimmed);
    final containsOperator = RegExp(r'[\+\-\*\/]').hasMatch(trimmed);

    // Treat as a "calculation" if it evaluates and contains an operator.
    // This distinguishes "5*4" from a simple entry like "20".
    if (mathResult != null && containsOperator) {
      // Use the expression as the title and the result as the number.
      ref.read(expenseRepositoryProvider).addCheck(
        listId: widget.listId,
        number: mathResult,
        title: trimmed,
      );
      _controller.clear();
      widget.onAdded();
      return; // Stop processing.
    }

    // Priority 2: If not a pure calculation, parse for mixed patterns.
    final parsed = _parseInput(trimmed);
    if (parsed.isValid) {
      ref.read(expenseRepositoryProvider).addCheck(
        listId: widget.listId,
        number: parsed.number ?? 0.0,
        title: parsed.title,
      );
      _controller.clear();
      widget.onAdded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
      child: TextField(
        controller: _controller,
        focusNode: widget.focusNode,
        keyboardType: _isNumericKeyboard
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textInputAction: TextInputAction.done,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 12, right: 8),
            child: Icon(Icons.add, color: theme.colorScheme.primary, size: 24),
          ),
          suffixIcon: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              icon: Icon(
                _isNumericKeyboard ? Icons.abc : Icons.dialpad,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
                size: 22,
              ),
              onPressed: () {
                setState(() {
                  _isNumericKeyboard = !_isNumericKeyboard;
                });
                widget.focusNode.unfocus();
                Future.delayed(
                  const Duration(milliseconds: 50),
                      () => widget.focusNode.requestFocus(),
                );
              },
              tooltip: _isNumericKeyboard
                  ? 'Switch to text keyboard'
                  : 'Switch to number pad',
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          hintText: 'Enter item (e.g., "Coffee 5.99" or "12*5+2")',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            fontSize: 14,
          ),
        ),
        onSubmitted: _submit,
      ),
    );
  }
}

/// Data class to hold parsed input results.
class ParsedInput {
  final double? number;
  final String? title;

  ParsedInput({this.number, this.title});

  /// An input is valid if it has a number or a title.
  bool get isValid => number != null || title != null;
}