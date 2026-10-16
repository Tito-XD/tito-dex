import 'dart:io';
import 'package:titodex_launcher/weather.dart';

Future<void> main() async {
  final service = WeatherService();
  final cities = await service.search('Shanghai');
  if (cities.isEmpty) throw StateError('No city results');
  final reading = await service.current(cities.first);
  stdout.writeln(
    'Open-Meteo geocoding and current weather returned valid results; ${cities.length} city candidates, WMO ${reading.code}.',
  );
}
