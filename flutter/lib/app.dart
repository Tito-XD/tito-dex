import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'config/app_config.dart';
import 'features/companion/companion_repository.dart';
import 'features/game/game_catalog.dart';
import 'features/game/game_edition_repository.dart';
import 'features/game/journey_capability.dart';
import 'features/dex/dex_offline_service.dart';
import 'features/dex/dex_repository.dart';
import 'features/dex/dex_settings_repository.dart';
import 'features/dex/dex_update_service.dart';
import 'l10n/zh_catalog.dart';
import 'features/journey/journey_io.dart';
import 'features/journey/journey_repository.dart';
import 'features/launcher/emulator_launcher.dart';
import 'features/launcher/emulator_launcher_repository.dart';
import 'features/parser/pokemon_save_parser.dart';
import 'features/save/save_sync_service.dart';
import 'features/save/save_types.dart';
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
import 'pages/companion/blind_spot_page.dart';
import 'pages/companion/quick_damage_page.dart';
import 'pages/companion/stat_calc_page.dart';
import 'pages/companion/type_matchup_page.dart';
import 'pages/dex/dex_json_reference_page.dart';
import 'pages/dex/silhouette_quiz_page.dart';
import 'pages/search_page.dart';
import 'pages/settings_page.dart';
import 'pages/team_page.dart';
import 'theme/tito_theme.dart';
import 'theme/tito_typography.dart';
import 'widgets/continue_emulator_sheet.dart';
import 'widgets/device_shell.dart';
import 'widgets/handheld_input.dart';
import 'widgets/offline_data_prompt.dart';
import 'widgets/system_ui_coordinator.dart';
import 'widgets/tito_page_container.dart';

class TitoDexApp extends StatefulWidget {
  const TitoDexApp({super.key});

  @override
  State<TitoDexApp> createState() => _TitoDexAppState();
}

class _TitoDexAppState extends State<TitoDexApp> {
  final _repository = JourneyRepository();
  final _parser = const PokemonSaveParser();
  final _saveSync = SaveSyncService();
  final _emulatorLauncher = EmulatorLauncher();
  final _journeyIo = const JourneyIo();
  final _emulatorChoiceRefresh = ValueNotifier<EmulatorAppChoice?>(null);
  final _settingsRefresh = ValueNotifier<int>(0);
  late final GoRouter _router;
  CurrentJourney _journey = CurrentJourney.mock();
  SaveFileConfig _saveConfig = const SaveFileConfig();
  EmulatorAppChoice? _emulatorChoice;
  bool _bootstrapComplete = false;

  @override
  void initState() {
    super.initState();
    ZhCatalog.instance.ensureLoaded();
    AppConfig.instance.ensureLoaded();
    _router = GoRouter(
      refreshListenable: Listenable.merge([
        gameEditionRepository,
        _BootstrapGate.instance,
        _emulatorChoiceRefresh,
        _settingsRefresh,
      ]),
      redirect: (context, state) {
        if (!_bootstrapComplete && state.uri.path != '/') {
          return '/';
        }
        return null;
      },
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
              child: HandheldInputShell(
                location: state.uri.path,
                child: DeviceShell(child: child),
              ),
            );
          },
          routes: [
            GoRoute(
              path: '/',
              pageBuilder: (context, state) => titoHomePage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: ListenableBuilder(
                    listenable: Listenable.merge([
                      gameEditionRepository,
                      _settingsRefresh,
                    ]),
                    builder: (context, _) {
                      return HomePage(
                        journey: _journey,
                        onJourneyOpen: () => context.push('/journey'),
                        gameBadge: homeGameBadgeLabel(
                          gameEditionRepository.edition,
                        ),
                        onGameBadgeTap: _onGameBadgeTap,
                        bootstrapping: !_bootstrapComplete,
                      );
                    },
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/team',
              pageBuilder: (context, state) => titoSideSlidePage(
                key: state.pageKey,
                direction: TitoSideSlideDirection.fromLeft,
                child: TitoPageContainer(
                  child: TeamPage(journey: _journey, onSaveJourney: _persist),
                ),
              ),
            ),
            GoRoute(
              path: '/journey',
              pageBuilder: (context, state) => titoMaterialPage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: JourneyPage(
                    journey: _journey,
                    onLaunchEmulator: () => _onContinue(context),
                  ),
                ),
              ),
            ),
            GoRoute(
              path: '/dex',
              pageBuilder: (context, state) => titoDexPage(
                key: state.pageKey,
                heroTag: TitoHomeActionHero.forRoute('/dex', state.extra),
                child: const TitoPageContainer(child: SizedBox.expand()),
                content: DexPage(
                  journey: _journey,
                  onManualDexMarkChanged: _persist,
                ),
              ),
              routes: [
                GoRoute(
                  path: 'moves',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: const TitoPageContainer(
                      child: MoveEncyclopediaPage(),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'abilities',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: const TitoPageContainer(
                      child: AbilityEncyclopediaPage(),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'quiz',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: const TitoPageContainer(child: SilhouetteQuizPage()),
                  ),
                ),
                GoRoute(
                  path: ':id',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: PokemonDetailPage(
                        pokemonId:
                            int.tryParse(state.pathParameters['id'] ?? '') ?? 1,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            GoRoute(
              path: '/search',
              pageBuilder: (context, state) => titoSideSlidePage(
                key: state.pageKey,
                direction: TitoSideSlideDirection.fromRight,
                child: TitoPageContainer(child: SearchPage(journey: _journey)),
              ),
              routes: [
                GoRoute(
                  path: 'companion/type-matchup',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: TypeMatchupPage(journey: _journey),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'companion/stat-calc',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: StatCalcPage(journey: _journey),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'companion/blind-spot',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: BlindSpotPage(journey: _journey),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'companion/quick-damage',
                  pageBuilder: (context, state) => titoMaterialPage(
                    key: state.pageKey,
                    child: TitoPageContainer(
                      child: QuickDamagePage(journey: _journey),
                    ),
                  ),
                ),
                GoRoute(
                  path: 'reference/json',
                  pageBuilder: (context, state) {
                    final extra = state.extra;
                    final map = extra is Map<String, String> ? extra : const {};
                    return titoMaterialPage(
                      key: state.pageKey,
                      child: TitoPageContainer(
                        child: DexJsonReferencePage(
                          title: map['title'] ?? AppZh.searchHubDataTitle,
                          cdnFilename: map['cdnFilename'] ?? 'natures.json',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            GoRoute(
              path: '/settings',
              pageBuilder: (context, state) => titoMaterialPage(
                key: state.pageKey,
                child: TitoPageContainer(
                  child: SettingsPage(
                    journey: _journey,
                    saveConfig: _saveConfig,
                    emulatorChoice: _emulatorChoice,
                    onImportFixture: _importBundledSave,
                    onResetMock: _resetMock,
                    onSaveJourney: _persist,
                    onPickSaveFile: () => _pickSaveFile(context),
                    onClearSaveFile: () => _clearSaveFile(context),
                    onToggleAutoLoad: _setAutoLoadOnStartup,
                    onSyncNow: () => _syncSaveFile(context, force: true),
                    onExportJourney: _exportJourney,
                    onImportJourney: _importJourneyJson,
                    onPickEmulator: () => _pickEmulatorFromSettings(context),
                    onClearEmulator: () => _clearEmulator(context),
                    onChangeGameEdition: _onGameBadgeTap,
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
    await gameEditionRepository.load();
    await companionRepository.load();
    var journey = await _repository.load();
    journey = await _migrateLegacyBundledTrainerName(journey);
    if (!mounted) {
      return;
    }
    setState(() => _journey = journey);

    if (journey.game == 'SoulSilver' && journey.companion == 'Riolu') {
      journey = journey.copyWith(companion: 'Cyndaquil');
      await _repository.save(journey);
      if (mounted) {
        setState(() => _journey = journey);
      }
    }
    if (gameEditionRepository.edition.isSaveLinked) {
      try {
        final syncResult = await _saveSync.syncOnStartup(existing: journey);
        if (syncResult.updated) {
          journey = syncResult.journey;
          await _repository.save(journey);
          if (mounted) {
            setState(() => _journey = journey);
          }
        }
      } catch (error, stackTrace) {
        debugPrint('Save startup sync skipped: $error');
        debugPrint('$stackTrace');
      }
    }
    final saveConfig = await _saveSync.loadConfig();
    final emulatorChoice = await _emulatorLauncher.loadChoice();
    if (!mounted) {
      return;
    }
    setState(() {
      _journey = journey;
      _saveConfig = saveConfig;
      _emulatorChoice = emulatorChoice;
      _bootstrapComplete = true;
    });
    _emulatorChoiceRefresh.value = emulatorChoice;
    _settingsRefresh.value += 1;
    _BootstrapGate.instance.markReady();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prepareDexAfterHomeIsReady();
    });
  }

  Future<CurrentJourney> _migrateLegacyBundledTrainerName(
    CurrentJourney journey,
  ) async {
    final legacyHash = journey.saveDexHash;
    if (legacyHash == null || legacyHash.startsWith('v2:')) {
      return journey;
    }
    final bytes = await rootBundle.load('assets/fixtures/PKMSS.sav');
    final summary = _parser.parseSummary(bytes.buffer.asUint8List());
    if (!summary.saveHash.endsWith(legacyHash) ||
        journey.trainerNameCustomized) {
      return journey;
    }
    final migrated = journey.copyWith(
      trainerName: summary.trainerName,
      saveTrainerName: summary.trainerName,
    );
    await _repository.save(migrated);
    return migrated;
  }

  /// Data preparation intentionally happens outside the home bootstrap UI.
  /// A legacy bundle may need one catalog migration; it must never make the
  /// home progress animation loop or block the rest of the app from opening.
  Future<void> _prepareDexAfterHomeIsReady() async {
    try {
      await for (final _ in dexOfflineService.seedFromApkAssetIfNeeded()) {}
      if (await dexOfflineService.isReady()) {
        if (!await dexOfflineService.hasCatalog()) {
          await dexOfflineService.ensureCatalog();
          dexRepository.clearMemoryCache();
        }
      }
      // Lite uses the CDN rather than an APK bundle. Warm both variants in
      // the background so opening Dex does not begin the first list fetch.
      await dexRepository.warmUp();
    } catch (error, stackTrace) {
      debugPrint('Dex background preparation failed: $error');
      debugPrint('$stackTrace');
    } finally {
      if (mounted) {
        await _checkOfflineDataPrompts();
      }
    }
  }

  Future<void> _checkOfflineDataPrompts() async {
    if (!mounted) {
      return;
    }

    final offlineReady = await dexOfflineService.isReady();
    if (!offlineReady) {
      if (mounted) {
        await showOfflineDataPrompt(context);
      }
      return;
    }

    try {
      final updateInfo = await dexUpdateService.checkForUpdates();
      if (!mounted || !updateInfo.hasUpdate) {
        return;
      }
      await showUpdateAvailableDialog(context);
    } catch (_) {
      // Network unavailable — skip silently.
    }
  }

  Future<void> _persist(CurrentJourney journey) async {
    setState(() => _journey = journey);
    _settingsRefresh.value += 1;
    await _repository.save(journey);
  }

  Future<void> _pickSaveFile(BuildContext feedbackContext) async {
    final document = await _saveSync.pickSaveDocument();
    if (document == null) {
      return;
    }
    final result = await _saveSync.selectSaveDocument(
      document: document,
      existing: _journey,
    );
    final config = await _saveSync.loadConfig();
    if (!mounted || !feedbackContext.mounted) {
      return;
    }
    if (result.updated) {
      setState(() => _saveConfig = config);
      await _persist(result.journey);
      if (!feedbackContext.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        feedbackContext,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackSaveFileSet)));
      return;
    }
    ScaffoldMessenger.of(
      feedbackContext,
    ).showSnackBar(SnackBar(content: Text(_syncMessage(result) ?? '')));
  }

  Future<void> _clearSaveFile(BuildContext feedbackContext) async {
    final config = await _saveSync.clearFile();
    if (!mounted || !feedbackContext.mounted) {
      return;
    }
    setState(() => _saveConfig = config);
    _settingsRefresh.value += 1;
    ScaffoldMessenger.of(
      feedbackContext,
    ).showSnackBar(const SnackBar(content: Text(AppZh.snackSaveFileCleared)));
  }

  Future<void> _setAutoLoadOnStartup(bool enabled) async {
    final config = await _saveSync.setAutoLoadOnStartup(enabled);
    if (!mounted) {
      return;
    }
    setState(() => _saveConfig = config);
    _settingsRefresh.value += 1;
  }

  Future<void> _syncSaveFile(
    BuildContext feedbackContext, {
    bool force = false,
  }) async {
    final result = await _saveSync.syncSelected(
      existing: _journey,
      force: force,
    );
    final config = await _saveSync.loadConfig();
    if (!mounted || !feedbackContext.mounted) {
      return;
    }

    if (result.updated) {
      await _persist(result.journey);
    } else {
      setState(() => _saveConfig = config);
      _settingsRefresh.value += 1;
    }

    final message = _syncMessage(result);
    if (message != null && mounted && feedbackContext.mounted) {
      ScaffoldMessenger.of(
        feedbackContext,
      ).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  String? _syncMessage(SaveSyncResult result) {
    switch (result.message) {
      case 'loaded':
        return AppZh.snackSaveSyncLoaded(result.fileName ?? '');
      case 'unchanged':
        return AppZh.snackSaveSyncUnchanged;
      case 'no_file':
        return AppZh.snackSaveSyncNoFile;
      case 'unsupported_save':
        return AppZh.snackSaveSyncUnsupported;
      case 'selected_file_unavailable':
        return AppZh.snackSaveFileUnavailable;
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
              ? AppZh.snackSaveLoaded(summary.trainerName, summary.party.length)
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppZh.snackMockRestored)));
  }

  Future<void> _exportJourney() async {
    await _journeyIo.copyExportToClipboard(_journey);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppZh.snackJourneyExported)));
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
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text(AppZh.snackJourneyImported)));
  }

  Future<void> _rememberEmulator(
    EmulatorAppChoice choice,
    BuildContext feedbackContext,
  ) async {
    await _emulatorLauncher.saveChoice(choice);
    if (!mounted) {
      return;
    }
    setState(() => _emulatorChoice = choice);
    _emulatorChoiceRefresh.value = choice;
    if (feedbackContext.mounted) {
      ScaffoldMessenger.of(
        feedbackContext,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackEmulatorSaved)));
    }
  }

  Future<void> _clearEmulator(BuildContext feedbackContext) async {
    await _emulatorLauncher.clearChoice();
    if (!mounted) {
      return;
    }
    setState(() => _emulatorChoice = null);
    _emulatorChoiceRefresh.value = null;
    if (feedbackContext.mounted) {
      ScaffoldMessenger.of(
        feedbackContext,
      ).showSnackBar(const SnackBar(content: Text(AppZh.snackEmulatorCleared)));
    }
  }

  Future<void> _pickEmulatorFromSettings(BuildContext pickerContext) async {
    final choice = await showEmulatorPickerSheet(
      pickerContext,
      _emulatorLauncher,
    );
    if (choice != null && pickerContext.mounted) {
      await _rememberEmulator(choice, pickerContext);
    }
  }

  Future<void> _onGameBadgeTap(BuildContext context) async {
    final picked = await showGameEditionGridPicker(
      context,
      selected: gameEditionRepository.edition,
    );
    if (picked == null || !mounted) {
      return;
    }
    await gameEditionRepository.save(picked);
    await dexSettingsRepository.saveDefaultGameEdition(picked);
    final journeyKey = picked.journeyGameKey ?? _journey.game;
    if (picked.journeyGameKey != null && _journey.game != journeyKey) {
      await _persist(_journey.copyWith(game: journeyKey));
    }
    if (!mounted || !context.mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppZh.snackGameSwitched(picked.labelZh))),
    );
  }

  Future<void> _onContinue(BuildContext pickerContext) async {
    final saved = _emulatorChoice;
    if (saved != null && _emulatorLauncher.isLaunchSupported) {
      try {
        final started = await _emulatorLauncher.launch(saved);
        if (!started) {
          throw StateError('Saved launcher activity is unavailable');
        }
        if (!mounted || !pickerContext.mounted) {
          return;
        }
        ScaffoldMessenger.of(pickerContext).showSnackBar(
          SnackBar(content: Text(AppZh.continueSheetLaunching(saved.appName))),
        );
        return;
      } catch (_) {
        await _emulatorLauncher.clearChoice();
        if (!mounted || !pickerContext.mounted) {
          return;
        }
        setState(() => _emulatorChoice = null);
        _emulatorChoiceRefresh.value = null;
        ScaffoldMessenger.of(pickerContext).showSnackBar(
          const SnackBar(content: Text(AppZh.snackEmulatorLaunchFailed)),
        );
      }
    }

    if (!mounted || !pickerContext.mounted) {
      return;
    }
    final choice = await showEmulatorPickerSheet(
      pickerContext,
      _emulatorLauncher,
    );
    if (choice == null || !mounted || !pickerContext.mounted) {
      return;
    }

    await _rememberEmulator(choice, pickerContext);
    if (_emulatorLauncher.isLaunchSupported) {
      try {
        final started = await _emulatorLauncher.launch(choice);
        if (!started) {
          throw StateError('Selected launcher activity is unavailable');
        }
      } catch (_) {
        if (mounted && pickerContext.mounted) {
          await _emulatorLauncher.clearChoice();
          if (!mounted || !pickerContext.mounted) {
            return;
          }
          setState(() => _emulatorChoice = null);
          _emulatorChoiceRefresh.value = null;
          ScaffoldMessenger.of(pickerContext).showSnackBar(
            const SnackBar(content: Text(AppZh.snackEmulatorLaunchFailed)),
          );
        }
      }
    }
  }

  @override
  void dispose() {
    _router.dispose();
    _emulatorChoiceRefresh.dispose();
    _settingsRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: AppZh.displayTitleForTrainer(_journey.trainerName),
      theme: buildTitoTheme(),
      builder: (context, child) {
        return SystemUiCoordinator(
          child: DefaultTextStyle(
            style: TitoTypography.style().copyWith(
              decoration: TextDecoration.none,
            ),
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
      routerConfig: _router,
    );
  }
}

/// Notifies [GoRouter] when bootstrap completes so redirects unlock.
final class _BootstrapGate extends ChangeNotifier {
  _BootstrapGate._();
  static final instance = _BootstrapGate._();

  void markReady() => notifyListeners();
}
