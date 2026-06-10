import 'package:flutter/material.dart';
import 'services/AppConfig.dart';
import 'views/map_screen.dart';
 
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppConfig.load();
  runApp(const TourInteligenteApp());
}
 
class TourInteligenteApp extends StatelessWidget {
  const TourInteligenteApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tour Inteligente',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF4F46E5),
          brightness: Brightness.light,
        ),
        fontFamily: 'Roboto',
      ),
      home: const MapaScreen(),
    );
  }
}
 