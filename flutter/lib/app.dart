import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'features/journey/journey_repository.dart';
import 'features/parser/hgss_parser.dart';
import 'features/save/save_sync_service.dart';
import 'features/save/save_types.dart';
import 'l10n/app_zh.dart';
import 'models/journey.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';
import 'theme/tito_theme.dart';
import 'widgets/device_shell.dart';
import 'widgets/tito_bottom_nav.dart';

class TitoDexApp extends StatefulWidget {
  const TitoDexApp({super.key});

  @override
  State<TitoDexApp> createState() => _TitoDexAppState();
}

class _TitoDexAppState extends State<TitoDexApp> {
  final _repository = JourneyRepository();
  final _parser = const HgssParser();
  final _saveSync = SaveSyncService();
  late final GoRouter _router;
  CurrentJourney _journey = CurrentJourney.mock();
  SaveDirectoryConfig _saveConfig = const SaveDirectoryConfig();
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return DeviceShell(
              child: Column(
                children: [
                  Expanded(child: child),
                  TitoBottomNav(location: state.uri.path),
                ],
              ),
            );
          },
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => HomePage(
                journey: _journey,
                onContinue: _showContinueSheet,
              ),
            ),
            GoRoute(
              path: '/team',
              builder: (context, state) =>
                  PlaceholderPage(title: AppZh.navTeam),
            ),
            GoRoute(
              path: '/journey',
              builder: (context, state) =>
                  PlaceholderPage(title: AppZh.navJourney),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => SettingsPage(
                journey: _journey,
                saveConfig: _saveConfig,
                onImportFixture: _importBundledSave,
                onResetMock: _resetMock,
                onSaveJourney: _persist,
                onPickSaveDirectory: _pickSaveDirectory,
                onClearSaveDirectory: _clearSaveDirectory,
                onToggleAutoLoad: _setAutoLoadOnStartup,
                onSyncNow: () => _syncSaveDirectory(force: true),
              ),
            ),
          ],
        ),
      ],
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    var journey = await _repository.load();
    final syncResult = await _saveSync.syncOnStartup(existing: journey);
    if (syncResult.updated) {
      journey = syncResult.journey;
      await _repository.save(journey);
    }
    final saveConfig = await _saveSync.loadConfig();
    if (!mounted) {
      return;
    }
    setState(() {
      _journey = journey;
      _saveConfig = saveConfig;
      _ready = true;
    });
  }

  Future<void> _persist(CurrentJourney journey) async {
    setState(() => _journey = journey);
    await _repository.save(journey);
  }

  Future<void> _pickSaveDirectory() async {
    final path = await FilePicker.platform.getDirectoryPath();
    if (path == null) {
      return;
    }

    final config = await _saveSync.updateDirectory(path);
    if (!mounted) {
      return;
    }
    setState(() => _saveConfig = config);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackSaveDirectorySet)),
    );
    await _syncSaveDirectory(force: true);
  }

  Future<void> _clearSaveDirectory() async {
    final config = await _saveSync.updateDirectory(null);
    if (!mounted) {
      return;
    }
    setState(() => _saveConfig = config);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackSaveDirectoryCleared)),
    );
  }

  Future<void> _setAutoLoadOnStartup(bool enabled) async {
    final config = await _saveSync.setAutoLoadOnStartup(enabled);
    if (!mounted) {
      return;
    }
    setState(() => _saveConfig = config);
  }

  Future<void> _syncSaveDirectory({bool force = false}) async {
    final result = await _saveSync.syncLatest(existing: _journey, force: force);
    final config = await _saveSync.loadConfig();
    if (!mounted) {
      return;
    }

    if (result.updated) {
      await _persist(result.journey);
    } else {
      setState(() => _saveConfig = config);
    }

    final message = _syncMessage(result);
    if (message != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  String? _syncMessage(SaveSyncResult result) {
    switch (result.message) {
      case 'loaded':
        return AppZh.snackSaveSyncLoaded(result.fileName ?? '');
      case 'unchanged':
        return AppZh.snackSaveSyncUnchanged;
      case 'no_directory':
        return AppZh.snackSaveSyncNoDirectory;
      case 'no_save_found':
        return AppZh.snackSaveSyncNoSave;
      case 'unsupported_save':
        return AppZh.snackSaveSyncUnsupported;
      default:
        return null;
    }
  }

  Future<void> _importBundledSave() async {
    final bytes = await rootBundle.load('assets/fixtures/PKMSS.sav');
    final summary = _parser.parseSummary(bytes.buffer.asUint8List());
    await _persist(_parser.toJourney(summary, existing: _journey));
    if (!mounted) {
      return;
    }
    final warnings = summary.warnings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          warnings.isEmpty
              ? AppZh.snackSaveLoaded(
                  summary.trainerName,
                  summary.party.length,
                )
              : AppZh.snackSaveLoadedWarnings(warnings.length),
        ),
      ),
    );
  }

  Future<void> _resetMock() async {
    await _persist(CurrentJourney.mock());
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackMockRestored)),
    );
  }

  Future<void> _showContinueSheet() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                AppZh.continueSheetTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(AppZh.continueSheetBody),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(AppZh.continueSheetOk),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        theme: buildTitoTheme(),
        home: const DeviceShell(
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    return MaterialApp.router(
      title: AppZh.appTitle,
      theme: buildTitoTheme(),
      routerConfig: _router,
    );
  }
}
