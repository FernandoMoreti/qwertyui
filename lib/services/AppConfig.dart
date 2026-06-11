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
 
  static String get googlePlacesKey => const String.fromEnvironment('GOOGLE_PLACES_KEY', defaultValue: '');
  static String get geminiApiKey => const String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');
}
 