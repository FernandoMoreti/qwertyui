// lib/services/AppConfig.dart
 
import 'dart:convert';
import 'package:flutter/services.dart';
 
class AppConfig {
  static Map<String, dynamic> _config = {};
  static bool _loaded = false;
 
  static Future<void> load() async {
    if (_loaded) return;
    final jsonStr = await rootBundle.loadString('config.json');
    _config = jsonDecode(jsonStr);
    _loaded = true;
  }
 
  static String get googlePlacesKey => 'AIzaSyDWs2Uvi2MSBfCBA_uVJqYWJAjyqWtgDyk';
  static String get geminiApiKey => 'AQ.Ab8RN6L6q2QdDHsRrUhO-W5sOywhbuFOf_SDRtte6T8UM2KKPA';
}
 