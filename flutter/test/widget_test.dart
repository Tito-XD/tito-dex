import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:titodex/app.dart';
import 'package:titodex/l10n/app_zh.dart';

void main() {
  testWidgets('TitoDex app boots to trainer-card bootstrap shell', (tester) async {
    await tester.pumpWidget(const TitoDexApp());
    await tester.pump();

    expect(find.text(AppZh.appTitle), findsWidgets);
    expect(find.text(AppZh.bootstrapLoading), findsOneWidget);
    expect(find.text(AppZh.trainerNameLine('Tito')), findsOneWidget);
  });
}
