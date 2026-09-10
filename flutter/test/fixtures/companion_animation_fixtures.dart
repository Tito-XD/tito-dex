import 'dart:convert';
import 'dart:typed_data';

import 'package:titodex/features/companion/companion_animation_catalog.dart';

Uint8List get twoFrameGif => base64Decode(
  'R0lGODlhAgACAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAAAgACAAAIBgABCAQQEAAh+QQBCgABACwAAAAAAgACAIEA/wAAAAAAAAAAAAAIBgABCAQQEAA7',
);

Uint8List get oneFrameGif => base64Decode(
  'R0lGODdhAgACAIEAAP8AAAAAAAAAAAAAACwAAAAAAgACAAAIBgABCAQQEAA7',
);

CompanionAnimationAsset animationFixture({
  String id = 'source-a:162:furret:normal',
  String url = 'https://example.test/a.gif',
  int speciesId = 162,
  String formKey = 'furret',
  bool isDefault = true,
  bool shiny = false,
  int? sizeBytes,
}) => CompanionAnimationAsset(
  id: id,
  speciesId: speciesId,
  formKey: formKey,
  isDefault: isDefault,
  source: 'test',
  shiny: shiny,
  url: url,
  width: 2,
  height: 2,
  sizeBytes: sizeBytes ?? twoFrameGif.length,
  labelZh: '测试来源',
  labelEn: 'Test source',
);
