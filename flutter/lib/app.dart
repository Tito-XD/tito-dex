import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'features/companion/companion_art.dart';
import 'features/game/game_edition_controller.dart';
import 'features/journey/journey_io.dart';
import 'features/journey/journey_repository.dart';
import 'features/launcher/emulator_launcher.dart';
import 'features/launcher/emulator_launcher_repository.dart';
import 'features/parser/hgss_parser.dart';
import 'features/save/save_sync_service.dart';
import 'features/save/save_types.dart';
import 'features/trainer/trainer_avatar_service.dart';
import 'l10n/app_zh.dart';
import 'models/journey.dart';
import 'navigation/back_navigation.dart';
import 'navigation/tito_page_transition.dart';
import 'pages/dex/ability_encyclopedia_page.dart';
import 'pages/dex/move_encyclopedia_page.dart';
import 'pages/dex_page.dart';
import 'pages/pokemon_detail_page.dart';
import 'pages/home_page.dart';
import 'pages/journey_page.dart';
import 'pages/companion/quick_damage_page.dart';
import 'pages/companion/stat_calc_page.dart';
import 'pages/companion/type_matchup_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'pages/team_page.dart';
import 'theme/tito_colors.dart';
import 'theme/tito_theme.dart';
import 'theme/tito_typography.dart';
import 'widgets/continue_emulator_sheet.dart';
import 'widgets/device_shell.dart';
import 'widgets/handheld_input.dart';
import 'widgets/shell_companion_overlay.dart';
import 'widgets/game_edition_picker_sheet.dart';
import 'widgets/tito_page_container.dart';

class TitoDexApp extends StatefulWidget {
  const TitoDexApp({super.key});

  @override
  State<TitoDexApp> createState() => _TitoDexAppState();
}

class _TitoDexAppState extends State<TitoDexApp> {
  final _repository = JourneyRepository();
  final _parser = const HgssParser();
  final _saveSync = SaveSyncService();
  final _emulatorLauncher = EmulatorLauncher();
  final _journeyIo = const JourneyIo();
  late final GoRouter _router;
  CurrentJourney _journey = CurrentJourney.mock();
  SaveDirectoryConfig _saveConfig = const SaveDirectoryConfig();
  EmulatorAppChoice? _emulatorChoice;
  bool _ready = false;
  bool _avatarChangeArmed = false;

  @override
  void initState() {
    super.initState();
    // v0.4.0 B1: Rebuild shell routes when global game edition changes.
    _router = GoRouter(
      refreshListenable: gameEditionController,
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return PopScope(
              canPop: TitoBackNavigation.canPopRoute(context, state.uri.path),
              onPopInvokedWithResult: (didPop, result) {
                if (didPop) {
                  return;
                }
                TitoBackNavigation.navigateBack(context, state.uri.path);
              },
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  HandheldInputShell(
                    location: state.uri.path,
                    child: DeviceShell(child: child),
                  ),
                  Positioned.fill(
                    child: ShellCompanionOverlay(
                      onHome: TitoBackNavigation.isHome(state.uri.path),
                      companionName: _journey.companion,
                      onTap: () => _onCompanionChanged(
                        cycleCompanion(_journey.companion),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => titoHomePage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: HomePage(
                    journey: _journey,
                    onContinue: _onContinue,
                    // v0.4.0 B2: Badge reflects global GameEdition, not 7-game cycle.
                    gameBadge: gameEditionController.edition.homeBadgeLabel,
                    onGameBadgeTap: _onGameBadgeTap,
                    onAvatarTap: _onTrainerAvatarTap,
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/team',
              pageBuilder: (context, state) => titoSlidePage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: TeamPage(journey: _journey),
                ),
              ),
            ),
            GoRoute(
              path: '/journey',
              pageBuilder: (context, state) => titoSlidePage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: JourneyPage(journey: _journey),
                ),
              ),
            ),
            GoRoute(
              path: '/dex',
              pageBuilder: (context, state) => titoSlidePage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: DexPage(journey: _journey),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'moves',
                  pageBuilder: (context, state) => titoSlidePage(
                    key: state.pageKey,
                    child: const TitoPageContainer(
                      child: MoveEncyclopediaPage(),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'abilities',
                  pageBuilder: (context, state) => titoSlidePage(
                    key: state.pageKey,
                    child: const TitoPageContainer(
                      child: AbilityEncyclopediaPage(),
                    ),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => titoSlidePage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: PokemonDetailPage(
                        pokemonId:
                            int.tryParse(state.pathParameters['id'] ?? '') ??
                                1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => titoSlidePage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: SearchPage(journey: _journey),
                ),
              ),
              routes: [
                GoRoute(
                  path: 'companion/type-matchup',
                  pageBuilder: (context, state) => titoSlidePage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: TypeMatchupPage(journey: _journey),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'companion/stat-calc',
                  pageBuilder: (context, state) => titoSlidePage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: StatCalcPage(journey: _journey),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'companion/quick-damage',
                  pageBuilder: (context, state) => titoSlidePage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: QuickDamagePage(journey: _journey),
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => titoSlidePage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: SettingsPage(
                    journey: _journey,
                    saveConfig: _saveConfig,
                    emulatorChoice: _emulatorChoice,
                    onImportFixture: _importBundledSave,
                    onResetMock: _resetMock,
                    onSaveJourney: _persist,
                    onPickSaveDirectory: _pickSaveDirectory,
                    onClearSaveDirectory: _clearSaveDirectory,
                    onToggleAutoLoad: _setAutoLoadOnStartup,
                    onSyncNow: () => _syncSaveDirectory(force: true),
                    onExportJourney: _exportJourney,
                    onImportJourney: _importJourneyJson,
                    onPickEmulator: _pickEmulatorFromSettings,
                    onClearEmulator: _clearEmulator,
                  ),
                ),
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
    if (journey.game == 'SoulSilver' && journey.companion == 'Riolu') {
      journey = journey.copyWith(companion: 'Cyndaquil');
      await _repository.save(journey);
    }
    final syncResult = await _saveSync.syncOnStartup(existing: journey);
    if (syncResult.updated) {
      journey = syncResult.journey;
      await _repository.save(journey);
    }
    final saveConfig = await _saveSync.loadConfig();
    final emulatorChoice = await _emulatorLauncher.loadChoice();
    // v0.4.0 B2: Restore global GameEdition from prefs (dex/detail/search share this).
    await gameEditionController.loadFromSettings();
    if (!mounted) {
      return;
    }
    setState(() {
      _journey = journey;
      _saveConfig = saveConfig;
      _emulatorChoice = emulatorChoice;
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

  Future<void> _exportJourney() async {
    await _journeyIo.copyExportToClipboard(_journey);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackJourneyExported)),
    );
  }

  Future<void> _importJourneyJson() async {
    final journey = await _journeyIo.pickAndImport();
    if (journey == null || !mounted) {
      return;
    }
    await _persist(journey);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackJourneyImported)),
    );
  }

  Future<void> _rememberEmulator(EmulatorAppChoice choice) async {
    await _emulatorLauncher.saveChoice(choice);
    if (!mounted) {
      return;
    }
    setState(() => _emulatorChoice = choice);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackEmulatorSaved)),
    );
  }

  Future<void> _clearEmulator() async {
    await _emulatorLauncher.clearChoice();
    if (!mounted) {
      return;
    }
    setState(() => _emulatorChoice = null);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackEmulatorCleared)),
    );
  }

  Future<void> _pickEmulatorFromSettings() async {
    final choice = await showEmulatorPickerSheet(context, _emulatorLauncher);
    if (choice != null) {
      await _rememberEmulator(choice);
    }
  }

  Future<void> _onCompanionChanged(String companion) async {
    await _persist(_journey.copyWith(companion: companion));
  }

  /// v0.4.0 B1: 23-item picker replaces cycleGameKey rotation.
  Future<void> _onGameBadgeTap() async {
    final picked = await showGameEditionPickerSheet(
      context,
      selected: gameEditionController.edition,
    );
    if (picked == null || !mounted) {
      return;
    }
    await gameEditionController.setEdition(picked);
    final journeyKey = picked.journeyGameKey;
    if (_journey.game != journeyKey) {
      await _persist(_journey.copyWith(game: journeyKey));
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppZh.snackGameSwitched(picked.labelZh))),
    );
  }

  Future<void> _onTrainerAvatarTap() async {
    if (_journey.trainerAvatarCustomized) {
      if (!_avatarChangeArmed) {
        setState(() => _avatarChangeArmed = true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.snackAvatarConfirmAgain)),
        );
        return;
      }
      setState(() => _avatarChangeArmed = false);
      await _pickAndSaveAvatar();
      return;
    }

    await _showAvatarPickerMenu();
  }

  Future<void> _showAvatarPickerMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded),
                title: const Text(AppZh.avatarPickGallery),
                onTap: () => Navigator.pop(context, 'gallery'),
              ),
            ],
          ),
        );
      },
    );

    if (choice == 'gallery' && mounted) {
      await _pickAndSaveAvatar();
    }
  }

  Future<void> _pickAndSaveAvatar() async {
    final path = await TrainerAvatarService.pickAndCropSquare();
    if (path == null || !mounted) {
      return;
    }
    await _persist(
      _journey.copyWith(
        trainerAvatarPath: path,
        trainerAvatarCustomized: true,
      ),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppZh.snackAvatarUpdated)),
    );
  }

  Future<void> _onContinue() async {
    final saved = _emulatorChoice;
    if (saved != null && _emulatorLauncher.isLaunchSupported) {
      try {
        await _emulatorLauncher.launch(saved);
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppZh.continueSheetLaunching(saved.appName))),
        );
        return;
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppZh.snackEmulatorLaunchFailed)),
        );
      }
    }

    if (!mounted) {
      return;
    }
    final choice = await showEmulatorPickerSheet(context, _emulatorLauncher);
    if (choice == null || !mounted) {
      return;
    }

    await _rememberEmulator(choice);
    if (_emulatorLauncher.isLaunchSupported) {
      try {
        await _emulatorLauncher.launch(choice);
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppZh.snackEmulatorLaunchFailed)),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return MaterialApp(
        theme: buildTitoTheme(),
        home: const TitoPageContainer(
          child: DeviceShell(
            child: Center(
              child: _BootstrapLoading(),
            ),
          ),
        ),
      );
    }

    return MaterialApp.router(
      title: AppZh.appTitle,
      theme: buildTitoTheme(),
      builder: (context, child) {
        return DefaultTextStyle(
          style: TitoTypography.style().copyWith(
            decoration: TextDecoration.none,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: _router,
    );
  }
}

class _BootstrapLoading extends StatelessWidget {
  const _BootstrapLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          AppZh.appTitle,
          style: TitoTypography.style(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: TitoColors.card,
          ),
        ),
        const SizedBox(height: 16),
        const CircularProgressIndicator(color: TitoColors.card),
      ],
    );
  }
}
