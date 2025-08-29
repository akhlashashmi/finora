import 'package:finora/data/local/app_database.dart';
import 'package:finora/data/repository/expense_repository.dart';
import 'package:finora/features/home/widgets/add_list_bottom_sheet.dart'; // Updated import
import 'package:finora/features/home/widgets/list_page_card.dart';
import 'package:finora/features/intro/intro_screen.dart';
import 'package:finora/routing/app_router.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

final listPagesStreamProvider = StreamProvider.autoDispose<List<ListPage>>((
  ref,
) {
  final repo = ref.watch(expenseRepositoryProvider);
  return repo.watchAllLists();
});

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listsAsyncValue = ref.watch(listPagesStreamProvider);
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('finora', style: TextStyle(fontSize: 24)),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.pushNamed(AppRoute.settings.name),
          ),
          if (kDebugMode)
            IconButton(
              icon: const Icon(Icons.restart_alt),
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('intro_completed', false);
                // Restart app or navigate to intro
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const IntroScreen()),
                );
              },
              tooltip: 'Reset Intro',
            ),
        ],
      ),
      body: listsAsyncValue.when(
        data: (lists) {
          if (lists.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.folder_copy_outlined,
                    size: 64,
                    color: theme.colorScheme.onSurface.withOpacity(0.3),
                  ),
                  const SizedBox(height: 16),
                  Text('No sections yet', style: theme.textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(
                    'Tap the + button to add your first one!',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            itemCount: lists.length,
            itemBuilder: (context, index) {
              final list = lists[index];
              return ListPageCard(listPage: list);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // --- UPDATED ACTION ---
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // Important for keyboard handling
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (context) => const AddListBottomSheet(),
          );
        },
        label: const Text('New Section'),
        icon: const Icon(Icons.add),
      ),
    );
  }
}
