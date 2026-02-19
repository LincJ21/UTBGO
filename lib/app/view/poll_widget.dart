import 'package:flutter/material.dart';
import 'video_model.dart';

class PollWidget extends StatefulWidget {
  final VideoModel video;

  const PollWidget({super.key, required this.video});

  @override
  State<PollWidget> createState() => _PollWidgetState();
}

class _PollWidgetState extends State<PollWidget> {
  late List<Map<String, dynamic>> _options;
  bool _hasVoted = false;

  @override
  void initState() {
    super.initState();
    _options = widget.video.pollOptions ?? [];
    _hasVoted = widget.video.hasVotedOnPoll;
  }

  void _vote(int index) {
    if (_hasVoted) return;

    setState(() {
      // Incrementar voto localmente
      int currentVotes = _options[index]['votes'] ?? 0;
      _options[index]['votes'] = currentVotes + 1;
      
      _hasVoted = true;
      widget.video.hasVotedOnPoll = true; // Persistir en el modelo en memoria
    });
  }

  int _getTotalVotes() {
    int total = 0;
    for (var option in _options) {
      total += (option['votes'] as int? ?? 0);
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    final totalVotes = _getTotalVotes();

    return Column(
      mainAxisSize: MainAxisSize.min, // Se ajusta al contenido
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
            // Pregunta de la encuesta
            Text(
              widget.video.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.black87, // Texto oscuro
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            
            // Lista de opciones
            ...List.generate(_options.length, (index) {
              final option = _options[index];
              final votes = option['votes'] as int? ?? 0;
              final percent = totalVotes == 0 ? 0.0 : (votes / totalVotes);

              return Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: GestureDetector(
                  onTap: () => _vote(index),
                  child: Stack(
                    children: [
                      // Fondo de la barra (Contenedor base)
                      Container(
                        height: 50,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100, // Gris muy suave
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _hasVoted ? Colors.transparent : Colors.grey.shade300,
                            width: 1,
                          ),
                        ),
                      ),
                      
                      // Barra de progreso animada (Solo visible si ya votó)
                      if (_hasVoted)
                        AnimatedFractionallySizedBox(
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutCubic,
                          widthFactor: percent,
                          child: Container(
                            height: 50,
                            decoration: BoxDecoration(
                              color: const Color(0xFF003399).withOpacity(0.1), // Azul UTB muy suave
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFF003399).withOpacity(0.3)),
                            ),
                          ),
                        ),

                      // Texto de la opción y porcentaje
                      Container(
                        height: 50,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              option['text'] ?? '',
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_hasVoted)
                              Text(
                                '${(percent * 100).toStringAsFixed(0)}%',
                                style: const TextStyle(
                                  color: Color(0xFF003399),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            
            if (_hasVoted)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  '$totalVotes votos totales',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                ),
              ),
      ],
    );
  }
}