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
 
  static String get googlePlacesKey => _config['GOOGLE_PLACES_KEY'] ?? '';
  static String get geminiApiKey => _config['GEMINI_API_KEY'] ?? '';
}
 