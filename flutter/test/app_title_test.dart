import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/l10n/app_zh.dart';

void main() {
  test('displayTitleForTrainer defaults to TitoDex', () {
    expect(AppZh.displayTitleForTrainer(''), AppZh.appTitle);
    expect(AppZh.displayTitleForTrainer('Tito'), AppZh.appTitle);
    expect(AppZh.displayTitleForTrainer('Trainer'), AppZh.appTitle);
  });

  test('displayTitleForTrainer uses custom name', () {
    expect(AppZh.displayTitleForTrainer('小明'), '小明Dex');
    expect(AppZh.displayTitleForTrainer('Ash'), 'AshDex');
  });
}
