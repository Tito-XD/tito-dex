import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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
  static const _channel = MethodChannel('com.tito.titodex/app_launcher');

  Future<EmulatorAppChoice?> loadChoice() => _repository.load();

  Future<void> saveChoice(EmulatorAppChoice choice) => _repository.save(choice);

  Future<void> clearChoice() => _repository.clear();

  bool get isLaunchSupported => !kIsWeb && Platform.isAndroid;

  /// All launcher-visible Android apps. Recommended emulators are ranked in UI.
  Future<List<EmulatorAppChoice>> listCandidateApps() async {
    if (!Platform.isAndroid) {
      return knownEmulatorPackages.entries
          .map(
            (entry) =>
                EmulatorAppChoice(packageName: entry.key, appName: entry.value),
          )
          .toList();
    }

    final rawApps = await _channel.invokeListMethod<Object?>(
      'listLaunchableApps',
    );
    return (rawApps ?? const <Object?>[])
        .whereType<Map<Object?, Object?>>()
        .map((app) {
          return EmulatorAppChoice(
            packageName: app['packageName']! as String,
            activityName: app['activityName']! as String,
            appName: app['appName']! as String,
          );
        })
        .toList(growable: false);
  }

  Future<bool> launch(EmulatorAppChoice choice) async {
    if (!Platform.isAndroid) {
      return false;
    }

    return await _channel.invokeMethod<bool>('launchApp', {
          'packageName': choice.packageName,
          'activityName': choice.activityName,
        }) ??
        false;
  }
}

bool isRecommendedEmulator(EmulatorAppChoice choice) {
  if (knownEmulatorPackages.containsKey(choice.packageName)) {
    return true;
  }
  final haystack = '${choice.appName} ${choice.packageName}'.toLowerCase();
  return _emulatorKeywords.any(haystack.contains);
}
