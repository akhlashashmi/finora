import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/home/widgets/list_form_bottom_sheet.dart';
import 'package:finora/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:finora/features/home/widgets/list_page_card.dart';
import 'package:finora/features/home/widgets/password_screen.dart';
import 'package:finora/routing/app_router.dart';

final listPagesStreamProvider = StreamProvider.autoDispose<List<ListPage>>((
    ref,
    ) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchAllLists();
});

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with TickerProviderStateMixin {
  final List<ListPage> _selectedLists = [];
  bool _isReorderMode = false;
  bool _hasInitiallyLoaded =
  false; // Track initial load to prevent re-animations

  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  late Animation<Offset> _fabSlideAnimation;

  @override
  void initState() {
    super.initState();
    _initAnimations();
  }

  void _initAnimations() {
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fabScaleAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _fabAnimationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _fabSlideAnimation =
        Tween<Offset>(begin: Offset.zero, end: const Offset(0, 2)).animate(
          CurvedAnimation(
            parent: _fabAnimationController,
            curve: Curves.easeOutCubic,
          ),
        );
  }

  @override
  void dispose() {
    _fabAnimationController.dispose();
    super.dispose();
  }

  void _handleSelectList(ListPage list) {
    setState(() {
      HapticFeedback.mediumImpact();
      final isCurrentlySelected = _selectedLists.any(
            (selected) => selected.id == list.id,
      );

      if (isCurrentlySelected) {
        _selectedLists.removeWhere((selected) => selected.id == list.id);
        if (_selectedLists.isEmpty) {
          _exitSelectionMode();
        }
      } else {
        if (_selectedLists.isEmpty) {
          _enterSelectionMode();
        }
        _selectedLists.add(list);
      }
    });
  }

  void _enterSelectionMode() {
    _fabAnimationController.forward();
  }

  void _exitSelectionMode() {
    _fabAnimationController.reverse();
  }

  void _clearSelection() {
    HapticFeedback.lightImpact();
    setState(() {
      _selectedLists.clear();
    });
    _exitSelectionMode();
  }

  void _toggleReorderMode() {
    setState(() {
      _isReorderMode = !_isReorderMode;
      if (_isReorderMode && _selectedLists.isNotEmpty) {
        _clearSelection();
      }
    });
  }

  void _onEdit() {
    if (_selectedLists.length != 1) return;
    final listToEdit = _selectedLists.first;
    _clearSelection();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: ListFormBottomSheet(listPage: listToEdit),
      ),
    );
  }

  void _onTogglePin() {
    if (_selectedLists.length != 1) return;
    ref.read(expenseRepositoryProvider).togglePinList(_selectedLists.first.id);
    _clearSelection();
  }

  void _onToggleProtection() async {
    if (_selectedLists.length != 1) return;

    final list = _selectedLists.first;
    final isCurrentlyProtected = list.isProtected;
    final repo = ref.read(expenseRepositoryProvider);
    final passwordService = ref.read(passwordServiceProvider);
    final messenger = ScaffoldMessenger.of(context);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isCurrentlyProtected ? 'Unprotect List?' : 'Protect List?',
        ),
        content: Text(
          'Do you want to ${isCurrentlyProtected ? 'remove' : 'add'} protection for "${list.name}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isCurrentlyProtected ? 'Unprotect' : 'Protect'),
          ),
        ],
      ),
    );

    if (confirm != true) {
      _clearSelection();
      return;
    }

    if (isCurrentlyProtected) {
      // Unprotect: requires verification
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PinEntryScreen(
            mode: PinEntryMode.verify,
            title: 'Enter PIN to Unprotect',
            subtitle: 'Verify to remove protection from "${list.name}"',
            onVerified: () {
              repo.updateListPage(list.copyWith(isProtected: false));
              messenger.showSnackBar(
                SnackBar(content: Text('"${list.name}" is now unprotected.')),
              );
            },
          ),
        ),
      );
    } else {
      // Protect
      final isPasswordSet = await passwordService.isPasswordSet();
      if (isPasswordSet) {
        repo.updateListPage(list.copyWith(isProtected: true));
        messenger.showSnackBar(
          SnackBar(content: Text('"${list.name}" is now protected.')),
        );
      } else {
        // No password set, must create one first
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => PinEntryScreen(
              mode: PinEntryMode.create,
              title: 'Create App PIN',
              subtitle: 'This PIN will be used for all protected lists.',
              onPinCreated: (pin) {
                repo.updateListPage(list.copyWith(isProtected: true));
                messenger.showSnackBar(
                  SnackBar(
                    content: Text(
                      'App PIN created. "${list.name}" is now protected.',
                    ),
                  ),
                );
              },
            ),
          ),
        );
      }
    }
    _clearSelection();
  }

  void _onDelete() {
    if (_selectedLists.isEmpty) return;
    final listsToDelete = List<ListPage>.from(_selectedLists);
    _clearSelection();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Delete ${listsToDelete.length} List${listsToDelete.length > 1 ? 's' : ''}?',
        ),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          FilledButton(
            onPressed: () {
              final idsToDelete = listsToDelete.map((l) => l.id).toList();
              ref
                  .read(expenseRepositoryProvider)
                  .deleteMultipleListPages(idsToDelete);
              Navigator.of(context).pop();

              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    '${listsToDelete.length} list${listsToDelete.length > 1 ? 's' : ''} deleted',
                  ),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              );
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _navigateToList(ListPage list) {
    final isProtected = list.isProtected;
    if (isProtected) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PinEntryScreen(
            title: 'Enter PIN',
            subtitle: 'to access "${list.name}"',
            onVerified: () => context.pushNamed(
              AppRoute.listDetails.name,
              pathParameters: {'listId': list.id},
            ),
            mode: PinEntryMode.verify,
          ),
        ),
      );
    } else {
      context.pushNamed(
        AppRoute.listDetails.name,
        pathParameters: {'listId': list.id},
      );
    }
  }

  Widget _buildAnimatedAppBar(ThemeData theme, bool isInSelectionMode) {
    final defaultTitle = Text(
      'finora lists',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );

    final defaultActions = [
      if (!isInSelectionMode && !_isReorderMode)
        IconButton(
          icon: const Icon(Icons.swap_vert_rounded), // ICON-CHANGED
          iconSize: 24,
          onPressed: _toggleReorderMode,
          tooltip: 'Reorder Lists',
          style: IconButton.styleFrom(
            foregroundColor: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      IconButton(
        icon: const Icon(Icons.tune_rounded), // ICON-CHANGED
        iconSize: 24,
        onPressed: () => context.pushNamed(AppRoute.settings.name),
        tooltip: 'Settings & Backup',
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 8),
    ];

    final actionTitle = Text(
      '${_selectedLists.length} selected',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );

    final actionLeading = IconButton(
      icon: const Icon(Icons.close_rounded), // ICON-CHANGED
      iconSize: 26,
      onPressed: _clearSelection,
      tooltip: 'Clear Selection',
    );

    final reorderTitle = Text(
      'Reorder lists',
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w600,
        color: theme.colorScheme.onSurface,
      ),
    );

    final reorderActions = [
      IconButton(
        icon: const Icon(Icons.check_rounded), // ICON-CHANGED
        iconSize: 24,
        onPressed: _toggleReorderMode,
        tooltip: 'Done Reordering',
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      const SizedBox(width: 8),
    ];

    return SliverAppBar(
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: theme.colorScheme.surfaceTint.withValues(alpha:0.1),
      backgroundColor: theme.colorScheme.surface.withValues(alpha:0.95),
      pinned: true,
      leading: _isReorderMode
          ? IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded), // ICON-CHANGED
        onPressed: _toggleReorderMode,
        tooltip: 'Back',
      )
          : isInSelectionMode
          ? actionLeading
          : null,
      title: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        transitionBuilder: (child, animation) {
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.5),
                end: Offset.zero,
              ).animate(animation),
              child: child,
            ),
          );
        },
        child: _isReorderMode
            ? reorderTitle
            : isInSelectionMode
            ? actionTitle
            : defaultTitle,
      ),
      centerTitle: false,
      actions: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 350),
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: _isReorderMode
              ? Row(mainAxisSize: MainAxisSize.min, children: reorderActions)
              : isInSelectionMode
              ? _buildContextualActions(theme)
              : Row(mainAxisSize: MainAxisSize.min, children: defaultActions),
        ),
      ],
    );
  }

  Widget _buildContextualActions(ThemeData theme) {
    if (_selectedLists.length > 1) {
      return IconButton(
        key: const ValueKey('delete-multiple'),
        icon: const Icon(Icons.delete_outline_rounded), // ICON-CHANGED
        iconSize: 26,
        onPressed: _onDelete,
        tooltip: 'Delete Selected',
        style: IconButton.styleFrom(
          foregroundColor: theme.colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (_selectedLists.length == 1) {
      final isPinned = _selectedLists.first.isPinned;
      final isProtected = _selectedLists.first.isProtected;
      return Row(
        key: const ValueKey('single-selection-actions'),
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isProtected ? Icons.shield_rounded : Icons.shield_outlined, // ICON-CHANGED
            ),
            iconSize: 24,
            onPressed: _onToggleProtection,
            tooltip: isProtected ? 'Unprotect' : 'Protect',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.drive_file_rename_outline_rounded), // ICON-CHANGED
            iconSize: 24,
            onPressed: _onEdit,
            tooltip: 'Edit',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            icon: Icon(isPinned ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded), // ICON-CHANGED
            iconSize: 24,
            onPressed: _onTogglePin,
            tooltip: isPinned ? 'Unpin' : 'Pin',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded), // ICON-CHANGED
            iconSize: 24,
            onPressed: _onDelete,
            tooltip: 'Delete',
            style: IconButton.styleFrom(
              foregroundColor: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }
    return const SizedBox.shrink(key: ValueKey('no-actions'));
  }

  @override
  Widget build(BuildContext context) {
    final listsAsyncValue = ref.watch(listPagesStreamProvider);
    final theme = Theme.of(context);
    final isInSelectionMode = _selectedLists.isNotEmpty;

    return PopScope(
      canPop: !isInSelectionMode && !_isReorderMode,
      onPopInvoked: (didPop) {
        if (didPop) return;
        if (_isReorderMode) {
          _toggleReorderMode();
        } else if (isInSelectionMode) {
          _clearSelection();
        }
      },
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildAnimatedAppBar(theme, isInSelectionMode),
            listsAsyncValue.when(
              data: (lists) {
                // Mark as initially loaded only on first successful load
                if (!_hasInitiallyLoaded) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() {
                        _hasInitiallyLoaded = true;
                      });
                    }
                  });
                }

                if (lists.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainer
                                  .withValues(alpha:0.3),
                              borderRadius: BorderRadius.circular(32),
                            ),
                            child: Icon(
                              Icons.space_dashboard_outlined, // ICON-CHANGED
                              size: 64,
                              color: theme.colorScheme.onSurfaceVariant
                                  .withValues(alpha:0.6),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'No Lists yet',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Create your first list to get started',
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ).animate().fadeIn(duration: 500.ms),
                  );
                }

                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 100),
                  sliver: SliverReorderableList(
                    itemCount: lists.length,
                    onReorderStart: (_) => HapticFeedback.mediumImpact(),
                    onReorder: _isReorderMode
                        ? (oldIndex, newIndex) {
                      setState(() {
                        if (oldIndex < newIndex) {
                          newIndex -= 1;
                        }
                        final item = lists.removeAt(oldIndex);
                        lists.insert(newIndex, item);
                      });
                      final orderedIds = lists.map((l) => l.id).toList();
                      ref
                          .read(expenseRepositoryProvider)
                          .reorderLists(orderedIds);
                    }
                        : (_, _) {},
                    itemBuilder: (context, index) {
                      final list = lists[index];
                      final shouldAnimate =
                          !_hasInitiallyLoaded && !_isReorderMode;

                      Widget cardWidget = Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ListPageCard(
                          listPage: list,
                          index: index,
                          isSelected: _selectedLists.any(
                                (l) => l.id == list.id,
                          ),
                          isReorderMode: _isReorderMode,
                          onTap: () {
                            if (_isReorderMode) return;
                            if (isInSelectionMode) {
                              _handleSelectList(list);
                            } else {
                              _navigateToList(list);
                            }
                          },
                          onLongPress: () {
                            if (_isReorderMode) return;
                            _handleSelectList(list);
                          },
                        ),
                      );

                      // Only animate on initial load, not during reorder mode or after initial load
                      if (shouldAnimate) {
                        cardWidget = cardWidget
                            .animate(delay: (100 * (index / lists.length)).ms)
                            .fadeIn(
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        )
                            .slideY(
                          begin: 0.3,
                          duration: 400.ms,
                          curve: Curves.easeOutCubic,
                        );
                      }

                      return KeyedSubtree(
                        key: ValueKey(list.id),
                        child: cardWidget,
                      );
                    },
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('Error: $err')),
              ),
            ),
          ],
        ),
        floatingActionButton: _isReorderMode
            ? null
            : SlideTransition(
          position: _fabSlideAnimation,
          child: ScaleTransition(
            scale: _fabScaleAnimation,
            child: FloatingActionButton.extended(
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => Container(
                    decoration: BoxDecoration(
                      color: theme.scaffoldBackgroundColor,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(28),
                      ),
                    ),
                    child: const ListFormBottomSheet(),
                  ),
                );
              },
              label: const Text('New List'),
              icon: const Icon(Icons.add_rounded),
              backgroundColor: theme.colorScheme.primaryContainer,
              foregroundColor: theme.colorScheme.onPrimaryContainer,
              elevation: 3,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      ),
    );
  }
}