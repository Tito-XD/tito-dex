import 'package:shared_preferences/shared_preferences.dart';

class EmulatorAppChoice {
  const EmulatorAppChoice({
    required this.packageName,
    required this.appName,
  });

  final String packageName;
  final String appName;
}

class EmulatorLauncherRepository {
  static const _packageKey = 'titodex.emulator.package';
  static const _nameKey = 'titodex.emulator.name';

  Future<EmulatorAppChoice?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final packageName = prefs.getString(_packageKey);
    final appName = prefs.getString(_nameKey);
    if (packageName == null || appName == null) {
      return null;
    }
    return EmulatorAppChoice(packageName: packageName, appName: appName);
  }

  Future<void> save(EmulatorAppChoice choice) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_packageKey, choice.packageName);
    await prefs.setString(_nameKey, choice.appName);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_packageKey);
    await prefs.remove(_nameKey);
  }
}
