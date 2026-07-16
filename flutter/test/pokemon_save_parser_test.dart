import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:titodex/features/parser/pokemon_save_parser.dart';
import 'package:titodex/models/journey.dart';

void main() {
  const parser = PokemonSaveParser();

  test('does not accept an arbitrary 512 KB file as HGSS', () {
    expect(parser.canParse(Uint8List(0x80000)), isFalse);
  });

  test('reads Gen V UTF-16 trainer data and embedded save date', () {
    final bytes = Uint8List(0x24000);
    const player = 0x19400;
    _putUtf16(bytes, player + 4, 'Tito');
    _put16(bytes, player + 0x14, 12345);
    bytes[player + 0x1F] = 23;
    _put16(bytes, player + 0x24, 123);
    bytes[player + 0x26] = 45;
    bytes[player + 0x27] = 6;
    final packedDate = (26) | (7 << 7) | (15 << 11) | (18 << 16) | (42 << 21);
    _put32(bytes, player + 0x28, packedDate);

    expect(parser.canParse(bytes), isTrue);
    final summary = parser.parseSummary(bytes);
    expect(summary.game, 'Black2');
    expect(summary.trainerName, 'Tito');
    expect(summary.tid, 12345);
    expect(summary.playTime, '123:45:06');
    expect(summary.savedAt?.toLocal(), DateTime(2026, 7, 15, 18, 42));
  });

  test('reads Gen VI full-width name and embedded save date', () {
    final bytes = Uint8List(0x65600);
    const status = 0x14000;
    const playTime = 0x01800;
    _put16(bytes, status, 54321);
    bytes[status + 4] = 24;
    _putUtf16(bytes, status + 0x48, 'Ｔｉｔｏ');
    _put16(bytes, playTime, 50);
    bytes[playTime + 2] = 3;
    bytes[playTime + 3] = 4;
    final packedDate = 2026 | (7 << 12) | (16 << 16) | (10 << 21) | (5 << 26);
    _put32(bytes, playTime + 4, packedDate);
    _put32(bytes, bytes.length - 0x1F0, 0x42454546);

    final summary = parser.parseSummary(bytes);
    expect(summary.game, 'X');
    expect(summary.trainerName, 'Tito');
    expect(summary.playTime, '50:03:04');
    expect(summary.savedAt?.toLocal(), DateTime(2026, 7, 16, 10, 5));
  });

  test('reads a Generation I western trainer name', () {
    final bytes = Uint8List(0x8000);
    bytes[0x2F2C] = 0;
    bytes[0x2F2D] = 0xFF;
    bytes.setRange(0x2598, 0x259D, const [0x93, 0xA8, 0xB3, 0xAE, 0x50]);
    bytes[0x2602] = 0x07;
    bytes[0x2605] = 0x12;
    bytes[0x2606] = 0x34;
    bytes[0x2CED] = 9;
    bytes[0x2CEF] = 8;
    bytes[0x2CF0] = 7;

    final summary = parser.parseSummary(bytes);
    expect(summary.trainerName, 'Tito');
    expect(summary.tid, 0x1234);
    expect(summary.badges, 3);
    expect(summary.playTime, '9:08:07');
    final journey = parser.toJourney(
      summary,
      existing: CurrentJourney.mock().copyWith(game: 'RedBlueYellow'),
    );
    expect(journey.timeline.first.text, contains('红/绿/蓝'));
    expect(journey.timeline.first.text, isNot(contains('魂银存档')));
  });
}

void _putUtf16(Uint8List bytes, int offset, String value) {
  for (var index = 0; index < value.length; index++) {
    _put16(bytes, offset + index * 2, value.codeUnitAt(index));
  }
  _put16(bytes, offset + value.length * 2, 0xFFFF);
}

void _put16(Uint8List bytes, int offset, int value) {
  bytes[offset] = value & 0xFF;
  bytes[offset + 1] = (value >> 8) & 0xFF;
}

void _put32(Uint8List bytes, int offset, int value) {
  _put16(bytes, offset, value);
  _put16(bytes, offset + 2, value >> 16);
}
