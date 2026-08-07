import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:titodex/features/dex/dex_models.dart';
import 'package:titodex/pages/media_resource_page.dart';
import 'package:titodex/widgets/pokemon_artwork_viewer.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const pikachu = PokemonSummary(
    id: 25,
    nameEn: 'pikachu',
    nameZh: '皮卡丘',
    types: ['electric'],
    localSpritePath: 'sprites/25.png',
  );

  testWidgets('artwork viewer back toggle on this device', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showPokemonArtworkViewer(
                context,
                summary: pikachu,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot('viewer_front');
    await tester.tap(find.text('背面'));
    await tester.pump(const Duration(milliseconds: 400));
    await binding.takeScreenshot('viewer_back');
  });

  testWidgets('media resource page on this device', (tester) async {
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (_, __) => const MediaResourcePage(),
            ),
          ],
        ),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await binding.takeScreenshot('media_resource');
  });
}
