import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/app.dart';

void main() {
  testWidgets('TitoDex app boots to loading shell', (tester) async {
    await tester.pumpWidget(const TitoDexApp());
    expect(find.text('TitoDex'), findsOneWidget);
  });
}
