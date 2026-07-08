import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'theme/tito_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: TitoColors.card,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const TitoDexApp());
}
