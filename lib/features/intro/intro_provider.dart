import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'intro_provider.g.dart';

@Riverpod(keepAlive: true)
class IntroCompletedNotifier extends _$IntroCompletedNotifier {
  // The build method will be async and return the initial state from SharedPreferences.
  // Riverpod will automatically handle the loading/error/data states for us.
  @override
  Future<bool> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('intro_completed') ?? false;
  }

  // This method is called when the user taps "Get Started".
  Future<void> completeIntro() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('intro_completed', true);
    // We update the state to true, which will trigger UI/router changes.
    state = const AsyncValue.data(true);
  }
}