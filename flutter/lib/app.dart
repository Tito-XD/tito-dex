import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import 'features/journey/journey_repository.dart';
import 'features/parser/hgss_parser.dart';
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
  late final GoRouter _router;
  CurrentJourney _journey = CurrentJourney.mock();
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
                  const PlaceholderPage(title: 'Team'),
            ),
            GoRoute(
              path: '/journey',
              builder: (context, state) =>
                  const PlaceholderPage(title: 'Journey'),
            ),
            GoRoute(
              path: '/settings',
              builder: (context, state) => SettingsPage(
                journey: _journey,
                onImportFixture: _importBundledSave,
                onResetMock: _resetMock,
              ),
            ),
          ],
        ),
      ],
    );
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final journey = await _repository.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _journey = journey;
      _ready = true;
    });
  }

  Future<void> _persist(CurrentJourney journey) async {
    setState(() => _journey = journey);
    await _repository.save(journey);
  }

  Future<void> _importBundledSave() async {
    final bytes = await rootBundle.load('assets/fixtures/PKMSS.sav');
    final summary = _parser.parseSummary(bytes.buffer.asUint8List());
    await _persist(_parser.toJourney(summary));
    if (!mounted) {
      return;
    }
    final warnings = summary.warnings;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          warnings.isEmpty
              ? 'Loaded ${summary.trainerName} — ${summary.party.length} party members'
              : 'Loaded save with ${warnings.length} parser warning(s)',
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
      const SnackBar(content: Text('Restored mock journey')),
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
                'Continue Journey',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Emulator app picker arrives in Phase B. For now, Continue confirms your current journey context.',
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Got it'),
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
      title: 'TitoDex',
      theme: buildTitoTheme(),
      routerConfig: _router,
    );
  }
}
