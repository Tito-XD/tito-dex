import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';

import '../../models/journey.dart';
import '../parser/hgss_parser.dart';

class JourneyIo {
  const JourneyIo();

  String exportJson(CurrentJourney journey) {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(journey.toJson());
  }

  CurrentJourney importJson(String source) => decodeJourneyJson(source);

  Future<void> copyExportToClipboard(CurrentJourney journey) async {
    await Clipboard.setData(ClipboardData(text: exportJson(journey)));
  }

  Future<CurrentJourney?> pickAndImport() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return null;
    }

    final file = result.files.first;
    final bytes = file.bytes;
    if (bytes == null) {
      return null;
    }

    final text = utf8.decode(bytes);
    return importJson(text);
  }
}
