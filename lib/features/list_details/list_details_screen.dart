import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/list_details/help_screen.dart';
import 'package:finora/features/list_details/widgets/editable_check_list_item.dart';
import 'package:finora/features/list_details/widgets/new_item_input.dart';
import 'package:finora/features/list_details/widgets/stats_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Key for storing the display mode preference
const _statsDisplayModePrefKey = 'statsDisplayMode';

// Enum for cycling through stats in the AppBar
enum StatsDisplayMode {
  amount,
  count,
  budget,
  remainingSelected,
  remainingTotal,
}

// Providers
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

class _ListDetailsScreenState extends ConsumerState<ListDetailsScreen> with TickerProviderStateMixin {
  bool _showStats = false;
  late ScrollController _scrollController;
  late FocusNode _newItemFocusNode;
  bool _initialScrollDone = false;
  final GlobalKey _statsButtonKey = GlobalKey();
  OverlayEntry? _statsOverlay;
  late AnimationController _overlayAnimationController;
  StatsDisplayMode _statsDisplayMode = StatsDisplayMode.amount;

  @override
  void initState() {
    super.initState();
    _loadStatsDisplayModePreference();
    _scrollController = ScrollController();
    _newItemFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _newItemFocusNode.dispose();

    if (_statsOverlay != null) {
      _overlayAnimationController.dispose();
      _statsOverlay?.remove();
    }

    super.dispose();
  }

  /// Loads the saved StatsDisplayMode from shared preferences.
  Future<void> _loadStatsDisplayModePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final modeIndex = prefs.getInt(_statsDisplayModePrefKey) ?? 0;

    if (mounted &&
        modeIndex >= 0 &&
        modeIndex < StatsDisplayMode.values.length) {
      setState(() {
        _statsDisplayMode = StatsDisplayMode.values[modeIndex];
      });
    }
  }

  /// Saves the selected StatsDisplayMode to shared preferences.
  Future<void> _saveStatsDisplayModePreference(StatsDisplayMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_statsDisplayModePrefKey, mode.index);
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
                    color: Colors.black.withValues(alpha:0.25 * value),
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

  void _showUnifiedHelpScreen() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (context) => const HelpScreen()));
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
            if (list == null) {
              return const Center(child: Text('List not found'));
            }
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
    return CustomScrollView(
      controller: _scrollController,
      slivers: [
        SliverAppBar(
          elevation: 0,
          scrolledUnderElevation: 1,
          surfaceTintColor: theme.colorScheme.surfaceTint.withValues(alpha:0.1),
          backgroundColor: theme.scaffoldBackgroundColor.withAlpha(245),
          pinned: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Back',
          ),
          title: Text(
            list.name,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          centerTitle: false,
          actions: [
            _buildStatsButton(theme, checksAsync, list),
            IconButton(
              icon: const Icon(Icons.help_outline_rounded),
              tooltip: 'User Guide',
              onPressed: _showUnifiedHelpScreen,
            ),
            const SizedBox(width: 8),
          ],
        ),
        checksAsync.when(
          data: (checks) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final check = checks[index];
                return EditableCheckListItem(
                  key: ValueKey(check.id),
                  check: check,
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
            onAdded: () => _scrollToBottomAndFocusNewItem(forceScroll: true),
            onShowInfoScreen: _showUnifiedHelpScreen,
          ),
        ),
      ],
    );
  }

  void _cycleStatsDisplay(bool hasBudget) {
    final availableModes = [StatsDisplayMode.amount, StatsDisplayMode.count];

    if (hasBudget) {
      availableModes.addAll([
        StatsDisplayMode.budget,
        StatsDisplayMode.remainingSelected,
        StatsDisplayMode.remainingTotal,
      ]);
    }

    if (!availableModes.contains(_statsDisplayMode)) {
      setState(() {
        _statsDisplayMode = StatsDisplayMode.amount;
      });
      _saveStatsDisplayModePreference(StatsDisplayMode.amount);
      return;
    }

    final currentIndex = availableModes.indexOf(_statsDisplayMode);
    final nextIndex = (currentIndex + 1) % availableModes.length;
    final newMode = availableModes[nextIndex];

    setState(() {
      _statsDisplayMode = newMode;
    });
    _saveStatsDisplayModePreference(newMode);
  }

  String _getDisplayTextForStatsMode({
    required StatsDisplayMode mode,
    required List<Check> checks,
    required ListPage list,
    required NumberFormat numberFormat,
  }) {
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
        final totalAmount = checks.fold<double>(
          0.0,
              (sum, c) => sum + c.number,
        );
        final hasBudget = list.budget > 0;
        final useCompactFormat =
            totalAmount.abs() > 999999 || (hasBudget && list.budget > 999999);
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
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            backgroundColor: theme.colorScheme.surfaceContainerHigh,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            child: Text(
              displayText,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: _showStats
                    ? theme.colorScheme.primary
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // Added to prevent overflow
            ),
          ),
        );
      },
      loading: () => const SizedBox(width: 48),
      error: (err, stack) => const Icon(Icons.error_outline),
    );
  }
}