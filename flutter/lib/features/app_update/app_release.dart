/// Only public stable releases of the host App are eligible for self-update.
class AppVersion implements Comparable<AppVersion> {
  const AppVersion(this.major, this.minor, this.patch, this.preview);

  final int major;
  final int minor;
  final int patch;
  final String? preview;

  static AppVersion? parse(String value) {
    final match = RegExp(
      r'^v?(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z.-]+))?(?:\+\d+)?$',
    ).firstMatch(value.replaceFirst('-offline', ''));
    if (match == null) return null;
    return AppVersion(
      int.parse(match[1]!),
      int.parse(match[2]!),
      int.parse(match[3]!),
      match[4],
    );
  }

  @override
  int compareTo(AppVersion other) {
    for (final pair in [
      (major, other.major),
      (minor, other.minor),
      (patch, other.patch),
    ]) {
      final result = pair.$1.compareTo(pair.$2);
      if (result != 0) return result;
    }
    if (preview == other.preview) return 0;
    if (preview == null) return 1;
    if (other.preview == null) return -1;
    final a = preview!.split('.');
    final b = other.preview!.split('.');
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] == b[i]) continue;
      final x = int.tryParse(a[i]);
      final y = int.tryParse(b[i]);
      if (x != null && y != null) return x.compareTo(y);
      if (x != null) return -1;
      if (y != null) return 1;
      return a[i].compareTo(b[i]);
    }
    return a.length.compareTo(b.length);
  }
}

class InstalledApp {
  const InstalledApp({
    required this.version,
    required this.buildNumber,
    required this.packageName,
    required this.arm64,
  });
  final String version;
  final int buildNumber;
  final String packageName;
  final bool arm64;
  bool get offline => version.contains('-offline');
  bool get canUpdate => packageName == 'com.tito.titodex' && arm64;
}

class AppRelease {
  const AppRelease({
    required this.version,
    required this.title,
    required this.notes,
    required this.page,
    required this.download,
    required this.sha256,
    required this.bytes,
    required this.assetName,
  });
  final String version;
  final String title;
  final String notes;
  final Uri page;
  final Uri download;
  final String sha256;
  final int bytes;
  final String assetName;

  static AppRelease? newerThan(
    Map<String, dynamic> json,
    InstalledApp installed,
  ) {
    if (json['draft'] is! bool ||
        json['prerelease'] is! bool ||
        json['tag_name'] is! String) {
      throw const FormatException('release_metadata_invalid');
    }
    if (!installed.canUpdate ||
        json['draft'] != false ||
        json['prerelease'] != false) {
      return null;
    }
    final tag = json['tag_name'];
    if (tag is! String || !RegExp(r'^v\d+\.\d+\.\d+$').hasMatch(tag)) {
      return null;
    }
    final version = tag.substring(1);
    final candidate = AppVersion.parse(version)!;
    final current = AppVersion.parse(installed.version);
    if (current == null || candidate.compareTo(current) <= 0) return null;
    final variant = installed.offline ? 'offline' : 'lite';
    final name = 'TitoDex-$version-$variant-rg-arm64.apk';
    final assets = json['assets'];
    if (assets is! List) throw const FormatException('release_assets_missing');
    final matches = assets
        .whereType<Map<String, dynamic>>()
        .where((a) => a['name'] == name)
        .toList();
    if (matches.length != 1) {
      throw const FormatException('release_asset_missing');
    }
    final asset = matches.single;
    final digest = asset['digest'];
    final size = asset['size'];
    final expectedUrl =
        'https://github.com/Tito-XD/tito-dex/releases/download/$tag/$name';
    if (asset['state'] != 'uploaded' ||
        asset['browser_download_url'] != expectedUrl ||
        digest is! String ||
        !RegExp(r'^sha256:[a-fA-F0-9]{64}$').hasMatch(digest) ||
        size is! int ||
        size < 15000000 ||
        size > 150000000) {
      throw const FormatException('release_asset_invalid');
    }
    return AppRelease(
      version: version,
      title: json['name'] as String? ?? tag,
      notes: json['body'] as String? ?? '',
      page: Uri.parse('https://github.com/Tito-XD/tito-dex/releases/tag/$tag'),
      download: Uri.parse(expectedUrl),
      sha256: digest.substring(7).toLowerCase(),
      bytes: size,
      assetName: name,
    );
  }
}
