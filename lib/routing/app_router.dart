import 'package:finora/features/home/home_screen.dart';
import 'package:finora/features/intro/intro_provider.dart'; // Import the new provider
import 'package:finora/features/intro/intro_screen.dart';
import 'package:finora/features/list_details/list_details_screen.dart';
import 'package:finora/features/settings/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'app_router.g.dart';

enum AppRoute { home, listDetails, settings, intro }

final _rootNavigatorKey = GlobalKey<NavigatorState>();

@Riverpod(keepAlive: true)
GoRouter goRouter(Ref ref) {
  // Watch the new provider to react to state changes.
  final introState = ref.watch(introCompletedNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    // Start at a temporary splash route while we check the intro state.
    initialLocation: '/splash',
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      ),
      GoRoute(
        path: '/intro',
        name: AppRoute.intro.name,
        builder: (context, state) => const IntroScreen(),
      ),
      GoRoute(
        path: '/',
        name: AppRoute.home.name,
        builder: (context, state) => const HomeScreen(),
        routes: [
          GoRoute(
            path: 'list/:listId',
            name: AppRoute.listDetails.name,
            builder: (context, state) {
              final listId = state.pathParameters['listId']!;
              return ListDetailsScreen(listId: listId);
            },
          ),
          GoRoute(
            path: 'settings',
            name: AppRoute.settings.name,
            builder: (context, state) => const SettingsScreen(),
          ),
        ],
      ),
    ],
    // The redirect logic handles where the user should go.
    redirect: (context, state) {
      // While the provider is loading, stay on the splash screen.
      if (introState.isLoading || introState.hasError) {
        return '/splash';
      }

      final isIntroCompleted = introState.requireValue;
      final isGoingToIntro = state.matchedLocation == '/intro';

      // If intro is NOT complete, redirect to the intro screen.
      if (!isIntroCompleted) {
        return '/intro';
      }

      // If intro IS complete and the user is on the intro/splash screen,
      // redirect them to the home screen.
      if (isIntroCompleted && (isGoingToIntro || state.matchedLocation == '/splash')) {
        return '/';
      }

      // Otherwise, no redirect is needed.
      return null;
    },
  );
}