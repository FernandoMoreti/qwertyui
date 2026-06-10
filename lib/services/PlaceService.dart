// lib/services/PlaceService.dart

import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'AppConfig.dart';

class GooglePlacesService {
  static String get _apiKey => AppConfig.googlePlacesKey;

  // Mapa de categorias do app → query para o Google Places
  static const Map<String, String> _categoriaParaQuery = {
    'Gastronomia': 'restaurantes e lanchonetes',
    'Cultura': 'museus e centros culturais',
    'Lazer': 'parques e entretenimento',
    'Natureza': 'parques naturais e áreas verdes',
    'Pontos Turísticos': 'pontos turísticos',
    // legado
    'Almoço': 'restaurantes almoço',
    'Jantar': 'restaurantes jantar',
    'Passeio': 'pontos turísticos passeio',
  };

  static Future<List<Map<String, dynamic>>> buscarLugaresProximos(
    double lat,
    double lng,
    String categoria,
  ) async {
    final query = _categoriaParaQuery[categoria] ?? categoria;
    final url = Uri.parse('https://places.googleapis.com/v1/places:searchText');

    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'X-Goog-Api-Key': _apiKey,
          'X-Goog-FieldMask':
              'places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.photos,places.userRatingCount',
        },
        body: jsonEncode({
          'textQuery': query,
          'locationBias': {
            'circle': {
              'center': {
                'latitude': lat,
                'longitude': lng,
              },
              'radius': 5000.0,
            },
          },
          'maxResultCount': 10,
        }),
      );

      if (response.statusCode == 200) {
        final dados = jsonDecode(response.body);
        final List lugares = dados['places'] ?? [];

        return lugares.map<Map<String, dynamic>>((lugar) {
          final double lugarLat = (lugar['location']?['latitude'] ?? lat).toDouble();
          final double lugarLng = (lugar['location']?['longitude'] ?? lng).toDouble();
          final double distancia = _calcularDistancia(lat, lng, lugarLat, lugarLng);

          String? photoRef;
          final fotos = lugar['photos'] as List?;
          if (fotos != null && fotos.isNotEmpty) {
            photoRef = fotos[0]['name'];
          }

          return {
            'placeId': lugar['id'] ?? '',
            'nome': lugar['displayName']?['text'] ?? '',
            'endereco': lugar['formattedAddress'] ?? '',
            'latitude': lugarLat,
            'longitude': lugarLng,
            'rating': (lugar['rating'] ?? 0.0).toDouble(),
            'distanciaMetros': distancia,
            'photoReference': photoRef,
          };
        }).toList()
          ..sort((a, b) => (a['distanciaMetros'] as double).compareTo(b['distanciaMetros'] as double));
      } else {
        throw 'Erro na API Google Places: ${response.statusCode} - ${response.body}';
      }
    } catch (e) {
      throw 'Falha ao conectar no Google Places: $e';
    }
  }

  static String fotoUrl(String photoReference) {
    return 'https://places.googleapis.com/v1/$photoReference/media'
        '?maxHeightPx=400&maxWidthPx=400&key=$_apiKey';
  }

  static double _calcularDistancia(double lat1, double lng1, double lat2, double lng2) {
    const R = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  static double _rad(double deg) => deg * pi / 180;
}