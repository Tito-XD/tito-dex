import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/dex/dex_archive_install.dart';

List<int> tar(List<ArchiveFile> files) {
  final archive = Archive();
  for (final file in files) {
    archive.add(file);
  }
  return TarEncoder().encode(archive);
}

void main() {
  late Directory parent;
  late Directory root;
  setUp(() async {
    parent = await Directory.systemTemp.createTemp('dex_security_');
    root = await Directory('${parent.path}/dex_offline').create();
    await File('${root.path}/old.json').writeAsString('previous');
    await File('${parent.path}/escape').writeAsString('sibling');
  });
  tearDown(() => parent.delete(recursive: true));

  for (final name in [
    '../escape',
    '/escape',
    'sprites/../../escape',
    r'sprites\escape',
    'sprites/./escape',
    'sprites//escape',
    'C:/escape',
    'unexpected/file.json',
  ]) {
    test('rejects $name before touching active cache', () async {
      var prepared = false;
      await expectLater(
        installDexTar(
          tar([
            ArchiveFile.string('summaries.json', '[]'),
            ArchiveFile.string(name, 'attack'),
          ]),
          root,
          prepare: (_) async {
            prepared = true;
          },
        ),
        throwsFormatException,
      );
      expect(prepared, isFalse);
      expect(await File('${root.path}/old.json').readAsString(), 'previous');
      expect(await File('${parent.path}/escape').readAsString(), 'sibling');
      expect(await File('${root.path}/summaries.json').exists(), isFalse);
    });
  }

  test('rejects duplicate destinations from raw TAR entries', () async {
    final first = tar([ArchiveFile.string('moves.json', '{}')]);
    final second = tar([ArchiveFile.string('moves.json', 'attack')]);
    // Strip TAR end markers, preserving both headers instead of Archive.add
    // merging duplicate names.
    final bytes = [...first.take(1024), ...second];
    await expectLater(
      installDexTar(bytes, root, prepare: (_) async {}),
      throwsFormatException,
    );
    expect(await File('${root.path}/old.json').readAsString(), 'previous');
  });

  test('rejects links and special entry types', () async {
    for (final type in ['1', '2', '3', '4', '5', '6', '7']) {
      final bytes = tar([ArchiveFile.string('sprites/1.png', 'x')]);
      bytes[156] = type.codeUnitAt(0);
      await expectLater(
        installDexTar(bytes, root, prepare: (_) async {}),
        throwsFormatException,
      );
    }
    expect(await File('${root.path}/old.json').readAsString(), 'previous');
  });

  test('failed preparation leaves previous cache intact', () async {
    await expectLater(
      installDexTar(
        tar([ArchiveFile.string('summaries.json', '[]')]),
        root,
        prepare: (staging) async {
          expect(
            await File('${staging.path}/summaries.json').readAsString(),
            '[]',
          );
          throw const FormatException('invalid catalog');
        },
      ),
      throwsFormatException,
    );
    expect(await File('${root.path}/old.json').readAsString(), 'previous');
    expect((await parent.list().toList()).length, 2);
  });

  test('valid nested files activate only after preparation', () async {
    await installDexTar(
      tar([
        ArchiveFile.string('summaries.json', '[]'),
        ArchiveFile.string('sprites/forms/25.png', 'image'),
      ]),
      root,
      prepare: (staging) async {
        expect(await File('${root.path}/old.json').exists(), isTrue);
        await File('${staging.path}/manifest.json').writeAsString('{}');
      },
    );
    expect(await File('${root.path}/old.json').exists(), isFalse);
    expect(
      await File('${root.path}/sprites/forms/25.png').readAsString(),
      'image',
    );
    expect(await File('${root.path}/manifest.json').readAsString(), '{}');
  });

  test('active symlink cannot redirect installation', () async {
    await root.delete(recursive: true);
    await Link(root.path).create(parent.path);
    await expectLater(
      installDexTar(
        tar([ArchiveFile.string('summaries.json', '[]')]),
        root,
        prepare: (_) async {},
      ),
      throwsFormatException,
    );
    expect(await File('${parent.path}/escape').readAsString(), 'sibling');
  });
}
