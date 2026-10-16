import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'models.dart';

class WeatherReading {
  const WeatherReading(this.temperature, this.code, this.receivedAt);
  final double temperature;
  final int code;
  final DateTime receivedAt;
  String get description => weatherDescription(code);
}

String weatherDescription(int code) => switch (code) {
  0 => '晴',
  1 || 2 => '晴间多云',
  3 => '阴',
  45 || 48 => '雾',
  51 || 53 || 55 || 56 || 57 => '毛毛雨',
  61 || 63 || 65 || 66 || 67 => '雨',
  71 || 73 || 75 || 77 => '雪',
  80 || 81 || 82 => '阵雨',
  85 || 86 => '阵雪',
  95 || 96 || 99 => '雷雨',
  _ => '天气未知',
};

class WeatherService {
  Future<Map<String, dynamic>> _get(Uri uri) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    try {
      return await (() async {
        final request = await client.getUrl(uri);
        final response = await request.close();
        if (response.statusCode != 200) throw const HttpException('天气服务暂时不可用');
        final bytes = <int>[];
        await for (final chunk in response) {
          bytes.addAll(chunk);
          if (bytes.length > 256 * 1024) throw const FormatException('天气响应过大');
        }
        return jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      })().timeout(const Duration(seconds: 15));
    } finally {
      client.close(force: true);
    }
  }

  Future<List<WeatherCity>> search(String query) async {
    final json = await _get(
      Uri.https('geocoding-api.open-meteo.com', '/v1/search', {
        'name': query.trim(),
        'count': '8',
        'language': 'zh',
        'format': 'json',
      }),
    );
    return (json['results'] as List? ?? [])
        .map(
          (row) => WeatherCity(
            [
              row['name'],
              row['admin1'],
              row['country'],
            ].whereType<String>().toSet().join(' · '),
            (row['latitude'] as num).toDouble(),
            (row['longitude'] as num).toDouble(),
          ),
        )
        .toList();
  }

  Future<WeatherReading> current(WeatherCity city) async {
    final json = await _get(
      Uri.https('api.open-meteo.com', '/v1/forecast', {
        'latitude': city.latitude.toString(),
        'longitude': city.longitude.toString(),
        'current': 'temperature_2m,weather_code',
        'temperature_unit': 'celsius',
        'timezone': 'auto',
      }),
    );
    final current = json['current'] as Map;
    final temperature = (current['temperature_2m'] as num).toDouble();
    if (!temperature.isFinite) throw const FormatException('温度不可用');
    return WeatherReading(
      temperature,
      (current['weather_code'] as num).toInt(),
      DateTime.now(),
    );
  }
}
