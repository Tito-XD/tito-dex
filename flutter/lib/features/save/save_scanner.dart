import 'dart:io';

/// Finds the newest HGSS retail `.sav` (512 KB) under [directoryPath].
class SaveScanner {
  const SaveScanner();

  static const retailSaveSize = 524288;

  Future<File?> findNewestSave(String directoryPath) async {
    final root = Directory(directoryPath);
    if (!await root.exists()) {
      return null;
    }

    final candidates = <File>[];
    await for (final entity in root.list(recursive: true, followLinks: false)) {
      if (entity is! File) {
        continue;
      }
      final name = entity.path.toLowerCase();
      if (!name.endsWith('.sav')) {
        continue;
      }
      try {
        final length = await entity.length();
        if (length == retailSaveSize) {
          candidates.add(entity);
        }
      } on FileSystemException {
        continue;
      }
    }

    if (candidates.isEmpty) {
      return null;
    }

    candidates.sort((a, b) {
      final aModified = a.statSync().modified;
      final bModified = b.statSync().modified;
      return bModified.compareTo(aModified);
    });
    return candidates.first;
  }
}
