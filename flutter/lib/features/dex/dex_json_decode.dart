import 'dart:convert';

import 'package:flutter/foundation.dart';

/// Large reference files must not occupy the frame thread during navigation.
/// Keep tiny local records inline to avoid isolate startup overhead.
Future<dynamic> decodeDexJson(String source) async {
  if (source.length < 32 * 1024) return jsonDecode(source);
  return compute(_decode, source, debugLabel: 'dex-json');
}

dynamic _decode(String source) => jsonDecode(source);
