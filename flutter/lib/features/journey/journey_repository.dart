import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../models/journey.dart';

const _journeyKey = 'titodex.current_journey';

class JourneyRepository {
  Future<CurrentJourney> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_journeyKey);
    if (raw == null) {
      return CurrentJourney.mock();
    }
    return CurrentJourney.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> save(CurrentJourney journey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_journeyKey, jsonEncode(journey.toJson()));
  }

  Future<void> resetToMock() async {
    await save(CurrentJourney.mock());
  }
}
