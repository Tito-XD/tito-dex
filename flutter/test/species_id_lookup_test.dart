import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/features/companion/companion_art.dart';
import 'package:titodex/features/parser/hgss_format.dart';

void main() {
  test('speciesIdForName resolves English and Chinese party labels', () {
    expect(speciesIdForName('Quilava'), 156);
    expect(speciesIdForName('火岩鼠'), 156);
    expect(speciesIdForName('Togepi'), 175);
    expect(speciesIdForName('波克比'), 175);
    expect(speciesIdForName('Riolu'), 447);
  });

  test('knownSpeciesIdForLabel covers HGSS parser species table', () {
    expect(knownSpeciesIdForLabel('Flaaffy'), 180);
    expect(knownSpeciesIdForLabel('茸茸羊'), 180);
  });
}
