import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/list_details/widgets/editable_check_list_item.dart';
import 'package:finora/features/list_details/widgets/stats_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final listStatsProvider = StreamProvider.autoDispose
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

// Enum to manage the states of the stats card
enum StatsCardState { hidden, shown, pinned }

class _ListDetailsScreenState extends ConsumerState<ListDetailsScreen> {
  bool _isEditingTitle = false;
  StatsCardState _statsCardState = StatsCardState.hidden;
  late TextEditingController _titleController;
  late FocusNode _titleFocusNode;
  late ScrollController _scrollController;
  late FocusNode _newItemFocusNode;
  bool _initialScrollDone = false;
  final GlobalKey _statsHeaderKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _titleFocusNode = FocusNode();
    _scrollController = ScrollController();
    _newItemFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _titleFocusNode.dispose();
    _scrollController.dispose();
    _newItemFocusNode.dispose();
    super.dispose();
  }

  void _toggleStatsVisibility() {
    setState(() {
      switch (_statsCardState) {
        case StatsCardState.hidden:
          _statsCardState = StatsCardState.shown;
          break;
        case StatsCardState.shown:
          _statsCardState = StatsCardState.pinned;
          break;
        case StatsCardState.pinned:
          _statsCardState = StatsCardState.hidden;
          break;
      }
    });
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

  void _startEditingTitle(String currentTitle) {
    setState(() {
      _isEditingTitle = true;
      _titleController.text = currentTitle;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
      _titleController.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _titleController.text.length,
      );
    });
  }

  void _saveTitle(ListPage list) {
    if (_titleController.text.trim().isNotEmpty) {
      ref
          .read(expenseRepositoryProvider)
          .updateListPage(list.copyWith(name: _titleController.text.trim()));
    }
    setState(() {
      _isEditingTitle = false;
    });
  }

  void _cancelEdit() {
    setState(() {
      _isEditingTitle = false;
    });
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
          surfaceTintColor: theme.colorScheme.surfaceTint,
          backgroundColor: _statsCardState == StatsCardState.pinned
              ? theme.colorScheme.surface
              : theme.scaffoldBackgroundColor,
          pinned: true,
          title: _buildTitle(list, theme),
          centerTitle: true,
          actions: _isEditingTitle
              ? [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _cancelEdit,
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () => _saveTitle(list),
                  ),
                ]
              : [
                  IconButton(
                    icon: Icon(
                      _statsCardState == StatsCardState.hidden
                          ? Icons.analytics_outlined
                          : Icons.analytics,
                      color: _statsCardState != StatsCardState.hidden
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                    onPressed: _toggleStatsVisibility,
                  ),
                ],
        ),
        if (_statsCardState != StatsCardState.hidden)
          SliverPersistentHeader(
            pinned: _statsCardState == StatsCardState.pinned,
            floating: _statsCardState == StatsCardState.shown,
            delegate: _StatsHeaderDelegate(
              listPage: list,
              checksAsync: checksAsync,
              isVisible: _statsCardState != StatsCardState.hidden,
              theme: theme,
              isPinned: _statsCardState == StatsCardState.pinned,
            ),
          ),
        checksAsync.when(
          data: (checks) => SliverPadding(
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                final check = checks[index];
                return Padding(
                  padding: const EdgeInsets.only(
                    bottom: 10,
                    left: 10,
                    right: 10,
                  ),
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
            onAdded: () => _scrollToBottomAndFocusNewItem(forceScroll: true),
          ),
        ),
      ],
    );
  }

  Widget _buildTitle(ListPage list, ThemeData theme) {
    if (_isEditingTitle) {
      return Container(
        constraints: const BoxConstraints(maxWidth: 250),
        child: TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          style:
              theme.appBarTheme.titleTextStyle?.copyWith(
                color: theme.colorScheme.onSurface,
              ) ??
              theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
          decoration: InputDecoration(
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
            hintText: 'List name',
            hintStyle: TextStyle(
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          textAlign: TextAlign.center,
          onSubmitted: (_) => _saveTitle(list),
        ),
      );
    }

    return GestureDetector(
      onTap: () => _startEditingTitle(list.name),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 250),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                list.name,
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
                style:
                    theme.appBarTheme.titleTextStyle?.copyWith(
                      color: theme.colorScheme.onSurface,
                    ) ??
                    theme.textTheme.headlineSmall?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.edit_outlined,
              size: 16,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ],
        ),
      ),
    );
  }
}

// Update the _StatsHeaderDelegate to include isPinned parameter
class _StatsHeaderDelegate extends SliverPersistentHeaderDelegate {
  final ListPage listPage;
  final AsyncValue<List<Check>> checksAsync;
  final bool isVisible;
  final ThemeData theme;
  final bool isPinned;

  _StatsHeaderDelegate({
    required this.listPage,
    required this.checksAsync,
    required this.isVisible,
    required this.theme,
    this.isPinned = false,
  });

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Material(
        elevation: 0.0,
        color: theme.colorScheme.surface,

        child: isVisible
            ? checksAsync.when(
          data: (checks) => Container(
            margin: EdgeInsets.symmetric(vertical: 10),
            child: StatsHeader(
              listPage: listPage,
              checks: checks,
              isPinned: isPinned,
            ),
          ),
          loading: () => const Center(child: LinearProgressIndicator(minHeight: 4)),
          error: (_, __) => const SizedBox.shrink(),
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  // Update height calculation
  double _calculateHeight(AsyncValue<List<Check>> checksAsyncValue) {
    if (!isVisible) return 0.0;

    if (isPinned) return 125.0; // Compact height for pinned state

    const double baseHeight = 125.0;
    const double extraRowHeight = 117.0;

    final checks = checksAsyncValue.asData?.value;
    if (checks == null) return baseHeight;

    final hasBudget = listPage.budget > 0;
    final selectedCount = checks.where((c) => c.isSelected).length;

    return baseHeight + (hasBudget || selectedCount > 0 ? extraRowHeight : 0);
  }

  @override
  double get maxExtent => _calculateHeight(checksAsync);

  @override
  double get minExtent => _calculateHeight(checksAsync);

  @override
  bool shouldRebuild(_StatsHeaderDelegate oldDelegate) =>
      isVisible != oldDelegate.isVisible ||
          listPage != oldDelegate.listPage ||
          checksAsync != oldDelegate.checksAsync ||
          theme != oldDelegate.theme ||
          isPinned != oldDelegate.isPinned;
}


/// A dedicated widget for the inline "add new item" text field.
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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(String value) {
    final text = value.trim();
    if (text.isEmpty) return;

    final regex = RegExp(r'^(.*?)\s+([\d.,]+)$');
    double number;
    String? title;

    if (regex.hasMatch(text)) {
      final match = regex.firstMatch(text)!;
      title = match.group(1)!.trim();
      final numberStr = match.group(2)!.replaceAll(',', '');
      number = double.tryParse(numberStr) ?? 0.0;
    } else {
      number = double.tryParse(text.replaceAll(',', '')) ?? 0.0;
      title = null;
    }

    if (number > 0) {
      ref
          .read(expenseRepositoryProvider)
          .addCheck(
            listId: widget.listId,
            number: number,
            title: title?.isNotEmpty == true ? title : null,
          );
      _controller.clear();
      widget.focusNode.requestFocus();
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
        style: TextStyle(color: theme.colorScheme.onSurface, fontSize: 16),
        decoration: InputDecoration(
          border: InputBorder.none,
          focusedBorder: InputBorder.none,
          disabledBorder: InputBorder.none,
          enabledBorder: InputBorder.none,
          errorBorder: InputBorder.none,
          focusedErrorBorder: InputBorder.none,
          prefixIcon: Icon(Icons.add, color: theme.colorScheme.primary),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 10,
          ),
          hintText: 'Add item (e.g., "Coffee 5.99")',
          hintStyle: TextStyle(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontSize: 15,
          ),
        ),
        onSubmitted: _submit,
      ),
    );
  }
}
