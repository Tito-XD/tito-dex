import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titodex/features/companion/companion_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('load returns null choice when nothing stored', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = CompanionRepository();
    await repository.load();
    expect(repository.choice, isNull);
  });

  test('save persists and notifies; load restores', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = CompanionRepository();
    var notified = 0;
    repository.addListener(() => notified += 1);

    await repository.save(
      const CompanionChoice(pokemonId: 700, nameZh: '仙子伊布'),
    );
    expect(repository.choice?.pokemonId, 700);
    expect(notified, 1);

    final restored = CompanionRepository();
    await restored.load();
    expect(restored.choice?.pokemonId, 700);
    expect(restored.choice?.nameZh, '仙子伊布');
  });

  test('sizeScale defaults to 1.0, persists, and clamps to 1.0–1.5', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = CompanionRepository();
    await repository.load();
    expect(repository.sizeScale, 1.0);

    await repository.setSizeScale(1.25);
    expect(repository.sizeScale, 1.25);

    await repository.setSizeScale(9.0);
    expect(repository.sizeScale, CompanionRepository.maxSizeScale);
    await repository.setSizeScale(0.2);
    expect(repository.sizeScale, CompanionRepository.minSizeScale);

    await repository.setSizeScale(1.4);
    final restored = CompanionRepository();
    await restored.load();
    expect(restored.sizeScale, 1.4);
  });

  test('clear removes the stored choice', () async {
    SharedPreferences.setMockInitialValues({
      'companion.pokemonId': 25,
      'companion.nameZh': '皮卡丘',
    });
    final repository = CompanionRepository();
    await repository.load();
    expect(repository.choice?.pokemonId, 25);

    await repository.clear();
    expect(repository.choice, isNull);

    final reloaded = CompanionRepository();
    await reloaded.load();
    expect(reloaded.choice, isNull);
  });
}
