import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/theme/tito_typography.dart';

void main() {
  test('TitoTypography always sets Nunito font family', () {
    final style = TitoTypography.style(
      fontSize: 14,
      fontWeight: FontWeight.w700,
    );

    expect(style.fontFamily, TitoTypography.fontFamily);
    expect(style.fontFamily, 'Nunito');
  });
}
