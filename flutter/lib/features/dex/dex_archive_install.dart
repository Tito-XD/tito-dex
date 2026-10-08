import 'dart:io';

import 'package:archive/archive.dart';

/// Validate every effective TAR member before touching the installed cache.
/// Decoder.files preserves duplicate entries and their original entry types.
Future<void> installDexTar(
  List<int> bytes,
  Directory root, {
  required Future<void> Function(Directory) prepare,
}) async {
  final decoder = TarDecoder();
  decoder.decodeBytes(bytes);
  final names = <String>{};
  const directories = {
    'details',
    'sprites',
    'artwork',
    'type_icons',
    'game_icons',
    'item-sprites',
    'l10n',
    'maps',
    'config',
  };
  var total = 0;
  for (final entry in decoder.files) {
    final name = entry.filename;
    final parts = name.split('/');
    final regular = entry.typeFlag == '0' || entry.typeFlag.isEmpty;
    if (!regular ||
        (entry.nameOfLinkedFile?.isNotEmpty ?? false) ||
        name.contains('\\') ||
        name.contains(':') ||
        name.contains(RegExp(r'[\x00-\x1f\x7f]')) ||
        parts.any((part) => part.isEmpty || part == '.' || part == '..') ||
        !names.add(name) ||
        (parts.length > 1
            ? !directories.contains(parts.first)
            : !(name.endsWith('.json') || name.endsWith('_ATTRIBUTION.txt')))) {
      throw FormatException('Unsafe Dex TAR member: $name');
    }
    total += entry.fileSize;
    if (entry.fileSize > 64 * 1024 * 1024 ||
        total > 1024 * 1024 * 1024 ||
        names.length > 100000) {
      throw const FormatException('Dex TAR exceeds extraction limits');
    }
  }
  if (names.isEmpty) throw const FormatException('Empty Dex TAR');
  // Reject file/directory collisions before making any writes.
  for (final name in names) {
    final parts = name.split('/');
    for (var i = 1; i < parts.length; i++) {
      if (names.contains(parts.take(i).join('/'))) {
        throw FormatException('Conflicting Dex TAR member: $name');
      }
    }
  }

  await root.parent.create(recursive: true);
  final parent = Directory(await root.parent.resolveSymbolicLinks());
  final active = Directory(
    '${parent.path}/${root.uri.pathSegments.where((s) => s.isNotEmpty).last}',
  );
  if (await FileSystemEntity.type(active.path, followLinks: false) ==
      FileSystemEntityType.link) {
    throw const FormatException('Dex cache root is a link');
  }
  final staging = await parent.createTemp('.dex-staging-');
  final backupContainer = await parent.createTemp('.dex-backup-');
  final backup = Directory('${backupContainer.path}/cache');
  var backedUp = false;
  try {
    final canonical = await staging.resolveSymbolicLinks();
    for (final entry in decoder.files) {
      final file = File('$canonical/${entry.filename}');
      await file.parent.create(recursive: true);
      final resolvedParent = await file.parent.resolveSymbolicLinks();
      if (resolvedParent != canonical &&
          !resolvedParent.startsWith('$canonical/')) {
        throw const FormatException('Dex TAR destination escapes staging');
      }
      await file.writeAsBytes(entry.rawContent!.toUint8List());
    }
    await prepare(staging);
    if (await active.exists()) {
      await active.rename(backup.path);
      backedUp = true;
    }
    try {
      await staging.rename(active.path);
    } catch (_) {
      if (backedUp) await backup.rename(active.path);
      rethrow;
    }
  } finally {
    if (await staging.exists()) await staging.delete(recursive: true);
    // Keep a backup if restoring it failed.
    if (!await backup.exists() || await active.exists()) {
      await backupContainer.delete(recursive: true);
    }
  }
}
