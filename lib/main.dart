import 'package:finora/core/theme.dart';
import 'package:finora/firebase_options.dart';
import 'package:finora/routing/app_router.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // All the SharedPreferences and provider override logic is removed from here.
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the goRouterProvider.
    final router = ref.watch(goRouterProvider);

    // Use MaterialApp.router to link go_router to your app.
    return MaterialApp.router(
      routerConfig: router,
      title: 'Expense Tracker',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
    );
  }
}