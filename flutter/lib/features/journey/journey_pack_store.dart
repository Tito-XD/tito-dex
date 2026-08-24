import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';

import 'journey_pack_models.dart';

class JourneyPackStoreSnapshot {
  const JourneyPackStoreSnapshot({
    this.installed = const {},
    this.corruptFamilies = const {},
  });

  final Map<String, InstalledJourneyPack> installed;
  final Set<String> corruptFamilies;
}

abstract interface class JourneyPackStore {
  Future<JourneyPackStoreSnapshot> load();
  Future<void> install(
    JourneyPackDescriptor descriptor,
    Uint8List bytes,
    JourneyPackDocument document,
  );
  Future<void> delete(String gameFamily);
}

class FileJourneyPackStore implements JourneyPackStore {
  FileJourneyPackStore({Future<Directory> Function()? rootProvider})
    : _rootProvider = rootProvider ?? _defaultRoot;

  final Future<Directory> Function() _rootProvider;

  static Future<Directory> _defaultRoot() async {
    final documents = await getApplicationDocumentsDirectory();
    return Directory('${documents.path}/journey_packs');
  }

  @override
  Future<JourneyPackStoreSnapshot> load() async {
    final root = await _rootProvider();
    final installedDirectory = Directory('${root.path}/installed');
    if (!await installedDirectory.exists()) {
      return const JourneyPackStoreSnapshot();
    }
    await _recoverInterruptedPointerWrites(installedDirectory);
    final installed = <String, InstalledJourneyPack>{};
    final corrupt = <String>{};
    await for (final entity in installedDirectory.list()) {
      if (entity is! File || !entity.path.endsWith('.json')) continue;
      final family = entity.uri.pathSegments.last.replaceAll('.json', '');
      if (!_safeSegment(family)) continue;
      try {
        final pointer = jsonDecode(await entity.readAsString());
        if (pointer is! Map) throw const FormatException('Invalid pointer');
        final json = Map<String, dynamic>.from(pointer);
        if (json['schemaVersion'] != 1 || json['descriptor'] is! Map) {
          throw const FormatException('Invalid pointer');
        }
        final descriptor = JourneyPackDescriptor.fromJson(
          Map<String, dynamic>.from(json['descriptor'] as Map),
        );
        if (descriptor.gameFamily != family) {
          throw const FormatException('Family mismatch');
        }
        final objectPath = json['objectPath'] as String? ?? '';
        if (!RegExp(
          r'^objects/[a-z0-9._-]+/[a-f0-9]{64}\.json$',
        ).hasMatch(objectPath)) {
          throw const FormatException('Invalid object path');
        }
        final object = File('${root.path}/$objectPath');
        final bytes = await object.readAsBytes();
        if (bytes.length != descriptor.sizeBytes ||
            sha256.convert(bytes).toString() != descriptor.sha256Hex) {
          throw const FormatException('Stored pack integrity failed');
        }
        final document = JourneyPackDocument.fromBytes(
          Uint8List.fromList(bytes),
          descriptor: descriptor,
        );
        installed[family] = InstalledJourneyPack(
          descriptor: descriptor,
          installedAt:
              DateTime.tryParse(json['installedAt'] as String? ?? '') ??
              DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
          objectPath: objectPath,
          document: document,
        );
      } on Object {
        corrupt.add(family);
      }
    }
    return JourneyPackStoreSnapshot(
      installed: Map.unmodifiable(installed),
      corruptFamilies: Set.unmodifiable(corrupt),
    );
  }

  @override
  Future<void> install(
    JourneyPackDescriptor descriptor,
    Uint8List bytes,
    JourneyPackDocument document,
  ) async {
    if (!_safeSegment(descriptor.id) ||
        !_safeSegment(descriptor.gameFamily) ||
        bytes.length != descriptor.sizeBytes ||
        sha256.convert(bytes).toString() != descriptor.sha256Hex ||
        document.id != descriptor.id ||
        document.gameFamily != descriptor.gameFamily ||
        document.version != descriptor.version) {
      throw const FormatException('Invalid verified Journey pack');
    }
    final root = await _rootProvider();
    final objectDirectory = Directory('${root.path}/objects/${descriptor.id}');
    final installedDirectory = Directory('${root.path}/installed');
    await objectDirectory.create(recursive: true);
    await installedDirectory.create(recursive: true);

    final objectRelative =
        'objects/${descriptor.id}/${descriptor.sha256Hex}.json';
    final object = File('${root.path}/$objectRelative');
    var objectIsValid = false;
    if (await object.exists()) {
      final existing = await object.readAsBytes();
      objectIsValid =
          existing.length == descriptor.sizeBytes &&
          sha256.convert(existing).toString() == descriptor.sha256Hex;
    }
    if (!objectIsValid) {
      final temporary = File('${object.path}.tmp');
      if (await temporary.exists()) await temporary.delete();
      await temporary.writeAsBytes(bytes, flush: true);
      if (await object.exists()) await object.delete();
      await temporary.rename(object.path);
    }

    final pointer = File(
      '${installedDirectory.path}/${descriptor.gameFamily}.json',
    );
    final pointerTemporary = File('${pointer.path}.tmp');
    final pointerBackup = File('${pointer.path}.bak');
    if (await pointerTemporary.exists()) await pointerTemporary.delete();
    await pointerTemporary.writeAsString(
      jsonEncode({
        'schemaVersion': 1,
        'installedAt': DateTime.now().toUtc().toIso8601String(),
        'objectPath': objectRelative,
        'descriptor': descriptor.toJson(),
      }),
      flush: true,
    );
    if (await pointerBackup.exists()) await pointerBackup.delete();
    if (await pointer.exists()) await pointer.rename(pointerBackup.path);
    try {
      await pointerTemporary.rename(pointer.path);
      if (await pointerBackup.exists()) await pointerBackup.delete();
    } on Object {
      if (await pointer.exists()) await pointer.delete();
      if (await pointerBackup.exists()) {
        await pointerBackup.rename(pointer.path);
      }
      rethrow;
    }
  }

  @override
  Future<void> delete(String gameFamily) async {
    if (!_safeSegment(gameFamily)) return;
    final root = await _rootProvider();
    final pointer = File('${root.path}/installed/$gameFamily.json');
    final pointerTemporary = File('${pointer.path}.tmp');
    final pointerBackup = File('${pointer.path}.bak');
    String? packId;
    try {
      final decoded = jsonDecode(await pointer.readAsString());
      if (decoded is Map && decoded['descriptor'] is Map) {
        packId = (decoded['descriptor'] as Map)['id'] as String?;
      }
    } on Object {
      // A corrupt pointer is still safe to remove.
    }
    if (await pointer.exists()) await pointer.delete();
    if (await pointerTemporary.exists()) await pointerTemporary.delete();
    if (await pointerBackup.exists()) await pointerBackup.delete();
    if (packId != null && _safeSegment(packId)) {
      final objects = Directory('${root.path}/objects/$packId');
      if (await objects.exists()) await objects.delete(recursive: true);
    }
  }
}

Future<void> _recoverInterruptedPointerWrites(Directory directory) async {
  await for (final entity in directory.list()) {
    if (entity is! File || !entity.path.endsWith('.json.bak')) continue;
    final pointer = File(entity.path.substring(0, entity.path.length - 4));
    if (await pointer.exists()) {
      await entity.delete();
    } else {
      await entity.rename(pointer.path);
    }
  }
}

bool _safeSegment(String value) =>
    RegExp(r'^[a-z0-9][a-z0-9._-]{0,99}$').hasMatch(value);
