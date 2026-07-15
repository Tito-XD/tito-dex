import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/save/save_scanner.dart';

void main() {
  const scanner = SaveScanner();

  test('findNewestSave picks the most recently modified 512 KB .sav', () async {
    final tempDir = await Directory.systemTemp.createTemp('titodex_sav_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    final older = File('${tempDir.path}/older.sav');
    final newer = File('${tempDir.path}/nested/newer.sav');
    await newer.parent.create(recursive: true);

    await older.writeAsBytes(List.filled(SaveScanner.retailSaveSize, 0));
    await newer.writeAsBytes(List.filled(SaveScanner.retailSaveSize, 1));

    final olderTime = DateTime.now().subtract(const Duration(hours: 2));
    final newerTime = DateTime.now().subtract(const Duration(minutes: 5));
    await older.setLastModified(olderTime);
    await newer.setLastModified(newerTime);

    final found = await scanner.findNewestSave(tempDir.path);
    expect(found, isNotNull);
    expect(found!.absolute.uri.toFilePath(), newer.absolute.uri.toFilePath());
  });

  test('findNewestSave ignores non-retail sizes and non-sav files', () async {
    final tempDir = await Directory.systemTemp.createTemp('titodex_sav_test');
    addTearDown(() => tempDir.deleteSync(recursive: true));

    await File('${tempDir.path}/notes.txt').writeAsString('hello');
    await File('${tempDir.path}/small.sav').writeAsBytes(List.filled(1024, 0));
    await File('${tempDir.path}/valid.sav')
        .writeAsBytes(List.filled(SaveScanner.retailSaveSize, 2));

    final found = await scanner.findNewestSave(tempDir.path);
    expect(found, isNotNull);
    expect(found!.path.endsWith('valid.sav'), isTrue);
  });

  test('findNewestSave returns null when directory is missing', () async {
    final found = await scanner.findNewestSave('/tmp/titodex_missing_dir_xyz');
    expect(found, isNull);
  });
}
