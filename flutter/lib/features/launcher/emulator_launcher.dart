import 'dart:io';

import 'package:flutter/foundation.dart';
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
  'com.retroarch.aarch64': 'RetroArch',
  'org.dolphinemu.dolphinemu': 'Dolphin',
  'com.citra.citra_emu': 'Citra',
  'com.citra.citra_emu.canary': 'Citra Canary',
  'com.ndsemulator': 'NDS Emulator',
  'com.fastemulator.gbafree': 'My Boy!',
  'com.fastemulator.gba': 'My Boy! GBA',
  'com.duckstation.psx': 'DuckStation',
  'org.easyrpg.player': 'EasyRPG',
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
  'duckstation',
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

    final results = <String, EmulatorAppChoice>{};

    for (final entry in knownEmulatorPackages.entries) {
      if (!await _canLaunch(entry.key)) {
        continue;
      }
      final app = await InstalledApps.getAppInfo(entry.key, null);
      results[entry.key] = EmulatorAppChoice(
        packageName: entry.key,
        appName: app?.name ?? entry.value,
      );
    }

    try {
      final installed = await InstalledApps.getInstalledApps(false, false);
      for (final app in installed) {
        final haystack = '${app.name} ${app.packageName}'.toLowerCase();
        if (!_emulatorKeywords.any(haystack.contains)) {
          continue;
        }
        if (!await _canLaunch(app.packageName)) {
          continue;
        }
        results[app.packageName] = EmulatorAppChoice(
          packageName: app.packageName,
          appName: app.name,
        );
      }
    } catch (error, stackTrace) {
      debugPrint('EmulatorLauncher: installed app scan failed: $error');
      debugPrint('$stackTrace');
    }

    final list = results.values.toList()
      ..sort((a, b) => a.appName.compareTo(b.appName));
    return list;
  }

  Future<bool> launch(EmulatorAppChoice choice) async {
    if (!Platform.isAndroid) {
      return false;
    }

    final started = await InstalledApps.startApp(choice.packageName);
    return started == true;
  }

  Future<bool> _canLaunch(String packageName) async {
    final installed = await InstalledApps.isAppInstalled(packageName);
    return installed == true;
  }
}
