import 'dart:io';

import 'package:android_intent_plus/android_intent.dart';
import 'package:flutter/foundation.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

import 'emulator_launcher_repository.dart';

/// Known Nintendo / emulator packages on Android (launcher-visible).
const knownEmulatorPackages = <String, String>{
  'com.dsemu.drastic': 'DraStic',
  'me.magnum.melonds': 'melonDS',
  'com.explusalpha.NeoEmu': 'Neo.emu',
  'com.explusalpha.GbaEmu': 'GBA.emu',
  'com.explusalpha.MdEmu': 'MD.emu',
  'com.explusalpha.Snes9xPlus': 'Snes9x EX+',
  'com.retroarch': 'RetroArch',
  'org.dolphinemu.dolphinemu': 'Dolphin',
  'com.citra.citra_emu': 'Citra',
  'com.ndsemulator': 'NDS Emulator',
  'com.fastemulator.gbafree': 'My Boy!',
  'com.fastemulator.gba': 'My Boy! GBA',
};

const _emulatorKeywords = [
  'emu',
  'emulator',
  'retro',
  'drastic',
  'melonds',
  'melon',
  'nds',
  'gba',
  'citra',
  'dolphin',
  'retroarch',
];

class EmulatorLauncher {
  EmulatorLauncher({EmulatorLauncherRepository? repository})
      : _repository = repository ?? EmulatorLauncherRepository();

  final EmulatorLauncherRepository _repository;

  Future<EmulatorAppChoice?> loadChoice() => _repository.load();

  Future<void> saveChoice(EmulatorAppChoice choice) =>
      _repository.save(choice);

  Future<void> clearChoice() => _repository.clear();

  bool get isLaunchSupported => !kIsWeb && Platform.isAndroid;

  /// Installed known emulators plus keyword-matched launcher apps.
  Future<List<EmulatorAppChoice>> listCandidateApps() async {
    if (!Platform.isAndroid) {
      return knownEmulatorPackages.entries
          .map(
            (entry) => EmulatorAppChoice(
              packageName: entry.key,
              appName: entry.value,
            ),
          )
          .toList();
    }

    final installed = await InstalledApps.getInstalledApps(true, false);

    final byPackage = <String, AppInfo>{
      for (final app in installed) app.packageName: app,
    };

    final results = <String, EmulatorAppChoice>{};

    for (final entry in knownEmulatorPackages.entries) {
      final app = byPackage[entry.key];
      if (app != null) {
        results[entry.key] = EmulatorAppChoice(
          packageName: app.packageName,
          appName: app.name,
        );
      }
    }

    for (final app in installed) {
      final haystack = '${app.name} ${app.packageName}'.toLowerCase();
      if (_emulatorKeywords.any(haystack.contains)) {
        results[app.packageName] = EmulatorAppChoice(
          packageName: app.packageName,
          appName: app.name,
        );
      }
    }

    final list = results.values.toList()
      ..sort((a, b) => a.appName.compareTo(b.appName));
    return list;
  }

  Future<bool> launch(EmulatorAppChoice choice) async {
    if (!Platform.isAndroid) {
      return false;
    }

    final intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      package: choice.packageName,
      flags: <int>[
        0x10000000, // FLAG_ACTIVITY_NEW_TASK
      ],
    );
    await intent.launch();
    return true;
  }
}
