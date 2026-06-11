// lib/views/map_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:tour_inteligente/model/places.dart';
import '../services/LocaleService.dart';
import '../services/PlaceService.dart';
import '../services/GeminiService.dart';
import '../services/AppConfig.dart';
import 'chat_screen.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});

  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  static const primaryColor = Color(0xFF4F46E5);
  static const bgColor = Color(0xFFF8FAFC);

  final Completer<GoogleMapController> _mapController = Completer();
  LatLng? _userLocation;
  Set<Marker> _markers = {};

  List<PontoTuristico> _lugares = [];
  PontoTuristico? _localSelecionado;
  bool _estaCarregando = false;
  String _statusMsg = '';

  final ScrollController _scrollController = ScrollController();
  String _categoriaSelecionada = 'Gastronomia';
  final List<String> _categorias = [
    'Gastronomia',
    'Cultura',
    'Lazer',
    'Natureza',
    'Pontos Turísticos',
  ];

  @override
  void initState() {
    super.initState();
    _inicializar();
  }

  Future<void> _inicializar() async {
    await AppConfig.load();
    await _buscarLocalizacao();
  }

  Future<void> _buscarLocalizacao() async {
    setState(() {
      _estaCarregando = true;
      _statusMsg = 'Obtendo sua localização... 📡';
    });
    try {
      final pos = await GeolocalizacaoService.pegarPosicaoAtual();
      setState(() => _userLocation = LatLng(pos.latitude, pos.longitude));
      await _buscarLugares();
    } catch (e) {
      setState(() => _estaCarregando = false);
      _mostrarErro('$e');
    }
  }

  Future<void> _buscarLugares() async {
    if (_userLocation == null) return;
    setState(() {
      _estaCarregando = true;
      _lugares = [];
      _localSelecionado = null;
      _statusMsg = 'Buscando lugares de $_categoriaSelecionada... 🗺️';
    });

    try {
      final lugaresGoogle = await GooglePlacesService.buscarLugaresProximos(
        _userLocation!.latitude,
        _userLocation!.longitude,
        _categoriaSelecionada,
      );

      if (lugaresGoogle.isEmpty) {
        throw 'Nenhum local encontrado para "$_categoriaSelecionada" nas proximidades.';
      }

      final int max = lugaresGoogle.length < 5 ? lugaresGoogle.length : 5;
      final List<PontoTuristico> temp = [];

      for (int i = 0; i < max; i++) {
        final lugar = lugaresGoogle[i];
        if (!mounted) return;
        setState(() =>
            _statusMsg = 'IA analisando "${lugar['nome']}" (${i + 1}/$max) 🧠');

        final dadosIA = await GeminiService.enriquecerLugar(
          lugar['nome']!,
          lugar['endereco']!,
          _categoriaSelecionada,
        );
        temp.add(PontoTuristico.mesclar(lugar, dadosIA));

        if (i < max - 1) {
          await Future.delayed(const Duration(milliseconds: 1000));
        }
      }

      if (!mounted) return;
      setState(() {
        _lugares = temp;
        _estaCarregando = false;
      });
      await _atualizarMarcadores();
      await _centralizarMapa();
    } catch (e) {
      if (!mounted) return;
      setState(() => _estaCarregando = false);
      _mostrarErro('$e');
    }
  }

  Future<void> _atualizarMarcadores() async {
    final Set<Marker> markers = {};

    if (_userLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('user'),
        position: _userLocation!,
        icon:
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        infoWindow: const InfoWindow(title: 'Você está aqui'),
        zIndex: 2,
      ));
    }

    for (int i = 0; i < _lugares.length; i++) {
      final lugar = _lugares[i];
      final isSelected = _localSelecionado?.placeId == lugar.placeId;
      markers.add(Marker(
        markerId:
            MarkerId(lugar.placeId.isEmpty ? 'lugar_$i' : lugar.placeId),
        position: LatLng(lugar.latitude, lugar.longitude),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          isSelected
              ? BitmapDescriptor.hueOrange
              : BitmapDescriptor.hueGreen,
        ),
        infoWindow: InfoWindow(
          title: lugar.nome,
          snippet:
              '⭐ ${lugar.rating.toStringAsFixed(1)} • ${lugar.distanciaFormatada}',
        ),
        zIndex: isSelected ? 3 : 1,
        onTap: () => _selecionarLugar(lugar),
      ));
    }

    setState(() => _markers = markers);
  }

  Future<void> _centralizarMapa() async {
    if (!_mapController.isCompleted || _userLocation == null) return;
    final ctrl = await _mapController.future;
    await ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(_userLocation!, 14));
  }

  void _selecionarLugar(PontoTuristico lugar) {
    setState(() => _localSelecionado = lugar);
    _atualizarMarcadores();
    _moverCamera(lugar);
  }

  Future<void> _moverCamera(PontoTuristico lugar) async {
    if (!_mapController.isCompleted) return;
    final ctrl = await _mapController.future;
    await ctrl.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lugar.latitude, lugar.longitude), 15));
  }

  void _abrirChat(PontoTuristico lugar) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatAssistenteScreen(
          local: lugar,
          userLat: _userLocation!.latitude,
          userLng: _userLocation!.longitude,
          categoriaEscolhida: _categoriaSelecionada,
        ),
      ),
    );
  }

  Future<void> _abrirRota(PontoTuristico lugar) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&origin=${_userLocation!.latitude},${_userLocation!.longitude}'
      '&destination=${lugar.latitude},${lugar.longitude}'
      '&travelmode=driving',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) _mostrarErro('Não foi possível abrir o Google Maps.');
    }
  }

  // ── Lista de locais como modal ──────────────────────────────────────────────
  void _abrirListaModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ListaLugaresModal(
        lugares: _lugares,
        categoria: _categoriaSelecionada,
        localSelecionado: _localSelecionado,
        onSelect: (lugar) {
          Navigator.pop(context);
          _selecionarLugar(lugar);
        },
      ),
    );
  }

  void _mostrarErro(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: Colors.redAccent,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Mapa
          if (_userLocation != null)
            GoogleMap(
              initialCameraPosition:
                  CameraPosition(target: _userLocation!, zoom: 14),
              onMapCreated: (ctrl) => _mapController.complete(ctrl),
              markers: _markers,
              myLocationEnabled: true,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              onTap: (_) {
                if (_localSelecionado != null) {
                  setState(() => _localSelecionado = null);
                  _atualizarMarcadores();
                }
              },
            ),

          if (_userLocation == null && !_estaCarregando)
            Container(
              color: const Color(0xFFE2E8F0),
              child: const Center(
                  child: Text('Aguardando localização...',
                      style: TextStyle(color: Color(0xFF64748B)))),
            ),

          // Conteúdo sobre o mapa
          SafeArea(
            child: Column(
              children: [
                _buildTopBar(),
                const Spacer(),
              ],
            ),
          ),

          // Loading overlay
          if (_estaCarregando) _buildLoadingOverlay(),

          // Card inferior ou botão de lista
          if (!_estaCarregando && _lugares.isNotEmpty)
            _localSelecionado != null
                ? _buildCardSelecionado()
                : _buildBotaoLista(),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 12,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.location_on_rounded,
                      color: primaryColor, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Sua localização atual',
                          style: TextStyle(
                              fontSize: 11, color: Color(0xFF94A3B8))),
                      Text(
                        _userLocation != null
                            ? '${_userLocation!.latitude.toStringAsFixed(4)}, ${_userLocation!.longitude.toStringAsFixed(4)}'
                            : 'Obtendo localização...',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E293B)),
                      ),
                    ],
                  ),
                ),
                if (_lugares.isNotEmpty)
                  _iconBtn(Icons.list_rounded, _abrirListaModal),
                const SizedBox(width: 6),
                _iconBtn(Icons.refresh_rounded, _buscarLocalizacao),
              ],
            ),
          ),
          // Filtros
          SizedBox(
            height: 56,
            child: ListView.separated(
              controller: _scrollController, // <-- Vincula o controlador aqui
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              itemCount: _categorias.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final cat = _categorias[index];
                final isSel = cat == _categoriaSelecionada;
                return GestureDetector(
                  onTap: () {
                    if (!isSel) {
                      setState(() => _categoriaSelecionada = cat);
                      _buscarLugares();

                      // ─── LÓGICA DO DESLIZE (SCROLL) ──────────────────────────────────
                      // Largura estimada de cada tag + o separador (SizedBox de 8)
                      const double tamanhoAproximadoItem = 100.0; 
                      
                      // Calcula para onde a lista deve correr para tentar centralizar o item clicado
                      final double larguraTela = MediaQuery.of(context).size.width;
                      final double destinoScroll = (index * tamanhoAproximadoItem) - (larguraTela / 2) + (tamanhoAproximadoItem / 2);

                      // Executa a animação de deslize suave
                      _scrollController.animateTo(
                        destinoScroll.clamp(0.0, _scrollController.position.maxScrollExtent),
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                      // ─────────────────────────────────────────────────────────────────
                    }
                  },
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isSel ? primaryColor : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            cat,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white : const Color(0xFF475569),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: primaryColor, size: 20),
      ),
    );
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.black.withOpacity(0.35),
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: primaryColor),
                const SizedBox(height: 20),
                Text(
                  _statusMsg,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF475569),
                      height: 1.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBotaoLista() {
    return Positioned(
      bottom: 16,
      left: 16,
      right: 16,
      child: GestureDetector(
        onTap: _abrirListaModal,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 12,
                  offset: const Offset(0, -4))
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10)),
                child:
                    const Icon(Icons.place_rounded, color: primaryColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_lugares.length} locais de $_categoriaSelecionada',
                      style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E293B)),
                    ),
                    const Text('Toque para ver a lista completa',
                        style: TextStyle(
                            fontSize: 12, color: Color(0xFF94A3B8))),
                  ],
                ),
              ),
              const Icon(Icons.keyboard_arrow_up_rounded,
                  color: primaryColor),
            ],
          ),
        ),
      ),
    );
  }

  // Card do local selecionado
  Widget _buildCardSelecionado() {
    final local = _localSelecionado!;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 20,
                offset: Offset(0, -4))
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 10),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                  color: const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                  16,
                  16,
                  16,
                  MediaQuery.of(context).padding.bottom + 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(local.nome,
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF1E293B))),
                            const SizedBox(height: 4),
                            Row(children: [
                              Icon(Icons.star_rounded,
                                  color: Colors.amber.shade500,
                                  size: 16),
                              const SizedBox(width: 3),
                              Text(local.rating.toStringAsFixed(1),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                              const SizedBox(width: 12),
                              const Icon(Icons.directions_walk_rounded,
                                  size: 16, color: Color(0xFF64748B)),
                              const SizedBox(width: 3),
                              Text(local.distanciaFormatada,
                                  style: const TextStyle(
                                      color: Color(0xFF64748B),
                                      fontSize: 13)),
                            ]),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() => _localSelecionado = null);
                          _atualizarMarcadores();
                        },
                        icon: const Icon(Icons.close_rounded,
                            color: Color(0xFF94A3B8)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(local.descricao,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF475569),
                          height: 1.5)),
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.location_on_rounded,
                        size: 14, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Expanded(
                        child: Text(local.endereco,
                            style: const TextStyle(
                                fontSize: 12, color: Color(0xFF94A3B8)),
                            overflow: TextOverflow.ellipsis)),
                  ]),
                  const SizedBox(height: 16),
                  // Linha 1: Como Chegar + Perguntar à IA
                  Row(children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _abrirRota(local),
                        icon: const Icon(Icons.directions_rounded, size: 18),
                        label: const Text('Como Chegar'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF10B981),
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _abrirChat(local),
                        icon: const Icon(Icons.smart_toy_rounded,
                            size: 18),
                        label: const Text('Perguntar à IA'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding:
                              const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  // Linha 2: Ver Todos
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => _abrirListaModal(),
                      icon: const Icon(Icons.list_rounded, size: 18),
                      label: const Text('Ver Todos os Locais'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryColor,
                        side: const BorderSide(color: primaryColor),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _emojiCategoria(String cat) {
    switch (cat) {
      case 'Gastronomia': return '🍽️';
      case 'Cultura': return '🏛️';
      case 'Lazer': return '🎭';
      case 'Natureza': return '🌿';
      case 'Pontos Turísticos': return '🗺️';
      default: return '📍';
    }
  }
}

// ── Modal de lista ─────────────────────────────────────────────────────────────
class _ListaLugaresModal extends StatelessWidget {
  final List<PontoTuristico> lugares;
  final String categoria;
  final PontoTuristico? localSelecionado;
  final ValueChanged<PontoTuristico> onSelect;

  const _ListaLugaresModal({
    required this.lugares,
    required this.categoria,
    required this.localSelecionado,
    required this.onSelect,
  });

  static const primaryColor = Color(0xFF4F46E5);

  String _emoji(String cat) {
    switch (cat) {
      case 'Gastronomia': return '';
      case 'Cultura': return '';
      case 'Lazer': return '';
      case 'Natureza': return '';
      case 'Pontos Turísticos': return '';
      default: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 10),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: const Color(0xFFCBD5E1),
                borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 4),
            child: Row(
              children: [
                Text(
                  '${_emoji(categoria)} $categoria',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E293B)),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20)),
                  child: Text('${lugares.length} locais',
                      style: const TextStyle(
                          fontSize: 12,
                          color: primaryColor,
                          fontWeight: FontWeight.bold)),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded,
                      color: Color(0xFF94A3B8)),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              itemCount: lugares.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final lugar = lugares[index];
                final isSel = localSelecionado?.placeId == lugar.placeId;
                return GestureDetector(
                  onTap: () => onSelect(lugar),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color:
                              isSel ? primaryColor : Colors.transparent,
                          width: 2),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black
                                .withOpacity(isSel ? 0.08 : 0.03),
                            blurRadius: 12,
                            offset: const Offset(0, 4))
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                              color: primaryColor.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.location_on_rounded,
                              color: primaryColor, size: 24),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(lugar.nome,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF1E293B),
                                      fontSize: 15)),
                              const SizedBox(height: 4),
                              Row(children: [
                                Icon(Icons.star_rounded,
                                    color: Colors.amber.shade500,
                                    size: 14),
                                const SizedBox(width: 2),
                                Text(lugar.rating.toStringAsFixed(1),
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                                const SizedBox(width: 10),
                                const Icon(Icons.near_me_rounded,
                                    size: 13,
                                    color: Color(0xFF64748B)),
                                const SizedBox(width: 2),
                                Text(lugar.distanciaFormatada,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                                const SizedBox(width: 10),
                                const Icon(Icons.schedule_rounded,
                                    size: 13,
                                    color: Color(0xFF64748B)),
                                const SizedBox(width: 2),
                                Text('${lugar.tempoMinutos}min',
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF64748B))),
                              ]),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: Color(0xFFCBD5E1)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
