import 'package:shared_preferences/shared_preferences.dart';

class EmulatorAppChoice {
  const EmulatorAppChoice({
    required this.packageName,
    required this.appName,
    this.activityName,
  });

  final String packageName;
  final String appName;
  final String? activityName;
}

class EmulatorLauncherRepository {
  static const _packageKey = 'titodex.emulator.package';
  static const _nameKey = 'titodex.emulator.name';
  static const _activityKey = 'titodex.emulator.activity';

  Future<EmulatorAppChoice?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final packageName = prefs.getString(_packageKey);
    final appName = prefs.getString(_nameKey);
    if (packageName == null || appName == null) {
      return null;
    }
    return EmulatorAppChoice(
      packageName: packageName,
      appName: appName,
      activityName: prefs.getString(_activityKey),
    );
  }

  Future<void> save(EmulatorAppChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_packageKey, choice.packageName);
    await prefs.setString(_nameKey, choice.appName);
    if (choice.activityName == null) {
      await prefs.remove(_activityKey);
    } else {
      await prefs.setString(_activityKey, choice.activityName!);
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_packageKey);
    await prefs.remove(_nameKey);
    await prefs.remove(_activityKey);
  }
}
