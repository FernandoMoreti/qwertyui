// lib/services/LocaleService.dart

import 'package:geolocator/geolocator.dart';

class GeolocalizacaoService {
  static Future<Position> pegarPosicaoAtual() async {
    bool servicoAtivo = await Geolocator.isLocationServiceEnabled();
    if (!servicoAtivo) {
      throw 'O GPS do seu aparelho está desativado. Ative-o nas configurações.';
    }

    LocationPermission permissao = await Geolocator.checkPermission();
    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
      if (permissao == LocationPermission.denied) {
        throw 'Permissão de GPS negada pelo usuário.';
      }
    }

    if (permissao == LocationPermission.deniedForever) {
      throw 'A permissão de GPS está negada permanentemente nas configurações do dispositivo.';
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
      timeLimit: const Duration(seconds: 15),
    );
  }

  static double calcularDistancia(
    double lat1, double lng1,
    double lat2, double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }
}