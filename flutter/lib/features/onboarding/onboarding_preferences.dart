import 'package:shared_preferences/shared_preferences.dart';

class OnboardingPreferences {
  static const completedKey = 'onboarding.completed.v1';

  /// Record the first-run decision before bootstrap can write a mock journey.
  /// Explicit false survives a killed process halfway through the introduction.
  Future<bool> shouldShow() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(completedKey);
    if (completed != null) return !completed;
    final existing =
        prefs.containsKey('titodex.current_journey') ||
        prefs.containsKey('titodex_offline_prompt_shown') ||
        prefs.containsKey('titodex.global_game_edition');
    await prefs.setBool(completedKey, existing);
    return !existing;
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(completedKey, true);
    // The final introduction page already explains the same offline choice.
    await prefs.setBool('titodex_offline_prompt_shown', true);
  }
}
