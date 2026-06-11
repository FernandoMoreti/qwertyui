// lib/model/places.dart

class PontoTuristico {
  final String nome;
  final String endereco;
  final String categoria;
  final int tempoMinutos;
  final String descricao;
  final double latitude;
  final double longitude;
  final double rating;
  final double distanciaMetros;
  final String? photoReference;
  final String placeId;

  PontoTuristico({
    required this.nome,
    required this.endereco,
    required this.categoria,
    required this.tempoMinutos,
    required this.descricao,
    required this.latitude,
    required this.longitude,
    this.rating = 0.0,
    this.distanciaMetros = 0.0,
    this.photoReference,
    this.placeId = '',
  });

  String get distanciaFormatada {
    if (distanciaMetros < 1000) {
      return '${distanciaMetros.toStringAsFixed(0)}m';
    } else {
      return '${(distanciaMetros / 1000).toStringAsFixed(1)}km';
    }
  }

  factory PontoTuristico.mesclar(
    Map<String, dynamic> dadosGoogle,
    Map<String, dynamic> dadosGemini,
  ) {
    return PontoTuristico(
      nome: dadosGoogle['nome'] ?? 'Lugar sem nome',
      endereco: dadosGemini['endereco'] ?? dadosGoogle['endereco'] ?? 'Endereço não informado',
      categoria: dadosGemini['categoria'] ?? 'Passeio',
      tempoMinutos: dadosGemini['tempoMinutos'] ?? 60,
      descricao: dadosGemini['descricao'] ?? 'Sem descrição disponível.',
      latitude: (dadosGoogle['latitude'] ?? 0.0).toDouble(),
      longitude: (dadosGoogle['longitude'] ?? 0.0).toDouble(),
      rating: (dadosGoogle['rating'] ?? 0.0).toDouble(),
      distanciaMetros: (dadosGoogle['distanciaMetros'] ?? 0.0).toDouble(),
      photoReference: dadosGoogle['photoReference'],
      placeId: dadosGoogle['placeId'] ?? '',
    );
  }
}