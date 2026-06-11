// lib/views/chat_screen.dart

import 'package:flutter/material.dart';
import '../services/GeminiService.dart';

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

class ChatAssistenteScreen extends StatefulWidget {
  final PontoTuristico local;
  final double userLat;
  final double userLng;
  final String categoriaEscolhida;

  const ChatAssistenteScreen({
    super.key,
    required this.local,
    required this.userLat,
    required this.userLng,
    required this.categoriaEscolhida,
  });

  @override
  State<ChatAssistenteScreen> createState() => _ChatAssistenteScreenState();
}

class _ChatAssistenteScreenState extends State<ChatAssistenteScreen>
    with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const primaryColor = Color(0xFF4F46E5);
  static const bgColor = Color(0xFFF8FAFC);

  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  // Animação dos dots — usando AnimationController estável
  late AnimationController _dotController;

  final List<String> _perguntasSugeridas = [
    'Vale a pena visitar?',
    'Quais atrações próximas?',
    'Qual o melhor horário?',
    'Tem estacionamento?',
    'É acessível para cadeirantes?',
  ];

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
    _enviarMensagemInicial();
  }

  @override
  void dispose() {
    _dotController.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _enviarMensagemInicial() {
    final mensagemContexto =
        'Olá! 👋 Sou seu assistente de exploração local.\n\n'
        '📍 Localização: [${widget.userLat.toStringAsFixed(4)}, ${widget.userLng.toStringAsFixed(4)}]\n'
        '🏷️ Categoria: ${widget.categoriaEscolhida}\n'
        '📌 Local: ${widget.local.nome}\n'
        '📏 Distância: ${widget.local.distanciaFormatada}\n'
        '⭐ Avaliação: ${widget.local.rating.toStringAsFixed(1)}/5.0\n\n'
        'Como posso ajudar você sobre este local?';

    setState(() {
      _messages.add({'role': 'model', 'text': mensagemContexto});
    });
  }

  Future<void> _enviarPergunta(String pergunta) async {
    if (pergunta.trim().isEmpty) return;
    _controller.clear();

    setState(() {
      _messages.add({'role': 'user', 'text': pergunta});
      _isTyping = true;
    });
    _scrollToBottom();

    final historico = _messages
        .map((m) => {'role': m['role'] as String, 'text': m['text'] as String})
        .toList();

    final resposta = await GeminiService.perguntarSobreLugar(
      userLat: widget.userLat,
      userLng: widget.userLng,
      categoriaEscolhida: widget.categoriaEscolhida,
      nomeLugar: widget.local.nome,
      distancia: widget.local.distanciaFormatada,
      rating: widget.local.rating,
      pergunta: pergunta,
      historicoChat: historico,
    );

    if (!mounted) return;
    setState(() {
      _isTyping = false;
      _messages.add({'role': 'model', 'text': resposta});
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.smart_toy_rounded,
                  color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.local.nome,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.white),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const Text('Assistente IA • Online',
                      style: TextStyle(fontSize: 11, color: Colors.white70)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildLocalHeader(),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _buildTypingIndicator();
                }
                final msg = _messages[index];
                return _buildMessageBubble(
                  text: msg['text'] as String,
                  isUser: msg['role'] == 'user',
                );
              },
            ),
          ),
          if (_messages.length <= 1) _buildSugestoes(),
          _buildInput(),
        ],
      ),
    );
  }

  Widget _buildLocalHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: primaryColor.withOpacity(0.08),
      child: Row(
        children: [
          const Icon(Icons.location_on_rounded, color: primaryColor, size: 16),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              widget.local.endereco,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.amber.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.star_rounded,
                    color: Colors.amber.shade600, size: 13),
                const SizedBox(width: 2),
                Text(
                  widget.local.rating.toStringAsFixed(1),
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade800),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              widget.local.distanciaFormatada,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: primaryColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(
      {required String text, required bool isUser}) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        decoration: BoxDecoration(
          color: isUser ? primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _buildTextWithBold(
          text,
          baseStyle: TextStyle(
            fontSize: 14,
            color: isUser ? Colors.white : const Color(0xFF1E293B),
            height: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildTextWithBold(String text, {required TextStyle baseStyle}) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int lastEnd = 0;
    for (final match in regex.allMatches(text)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(
            text: text.substring(lastEnd, match.start), style: baseStyle));
      }
      spans.add(TextSpan(
        text: match.group(1),
        style: baseStyle.copyWith(fontWeight: FontWeight.bold),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < text.length) {
      spans.add(
          TextSpan(text: text.substring(lastEnd), style: baseStyle));
    }
    return RichText(text: TextSpan(children: spans));
  }

  // Dots animados com AnimationController — estável no Flutter Web
  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomRight: Radius.circular(18),
            bottomLeft: Radius.circular(4),
          ),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AnimatedDot(controller: _dotController, delay: 0.0),
            const SizedBox(width: 5),
            _AnimatedDot(controller: _dotController, delay: 0.2),
            const SizedBox(width: 5),
            _AnimatedDot(controller: _dotController, delay: 0.4),
          ],
        ),
      ),
    );
  }

  Widget _buildSugestoes() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Perguntas sugeridas:',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _perguntasSugeridas.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () =>
                      _enviarPergunta(_perguntasSugeridas[index]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      border: Border.all(
                          color: primaryColor.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(20),
                      color: primaryColor.withOpacity(0.06),
                    ),
                    child: Text(
                      _perguntasSugeridas[index],
                      style: const TextStyle(
                          fontSize: 13,
                          color: primaryColor,
                          fontWeight: FontWeight.w600),
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

  Widget _buildInput() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 8,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -4))
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              enabled: !_isTyping,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                hintText:
                    'Pergunte sobre ${widget.local.nome}...',
                hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8), fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF1F5F9),
                contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: _enviarPergunta,
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: _isTyping ? Colors.grey.shade300 : primaryColor,
            borderRadius: BorderRadius.circular(24),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: _isTyping
                  ? null
                  : () => _enviarPergunta(_controller.text),
              child: SizedBox(
                width: 46,
                height: 46,
                child: _isTyping
                    ? const Padding(
                        padding: EdgeInsets.all(13),
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.send_rounded,
                        color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widget de dot animado estável (sem TweenAnimationBuilder rebuilding) ──────
class _AnimatedDot extends StatelessWidget {
  final AnimationController controller;
  final double delay;

  const _AnimatedDot({required this.controller, required this.delay});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        // valor cíclico entre 0.3 e 1.0 com offset de fase
        double t = (controller.value + delay) % 1.0;
        // sobe de 0.3→1.0 na primeira metade, desce 1.0→0.3 na segunda
        double opacity = t < 0.5
            ? 0.3 + (t / 0.5) * 0.7
            : 1.0 - ((t - 0.5) / 0.5) * 0.7;
        return Opacity(
          opacity: opacity,
          child: Container(
            width: 8,
            height: 8,
            decoration: const BoxDecoration(
              color: Color(0xFF4F46E5),
              shape: BoxShape.circle,
            ),
          ),
        );
      },
    );
  }
}