import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'video_model.dart';

/// [FlashcardWidget] es una tarjeta interactiva con diseño moderno y educativo.
///
/// Características:
/// - Efecto de volteo 3D (Flip).
/// - Fondo con gradiente animado sutil.
/// - Sombra y resplandor para profundidad.
/// - Adaptable a contenido con o sin imagen.
/// - Soporte para múltiples tarjetas (Sets).
class FlashcardWidget extends StatefulWidget {
  final VideoModel content;

  const FlashcardWidget({super.key, required this.content});

  @override
  State<FlashcardWidget> createState() => _FlashcardWidgetState();
}

class _FlashcardWidgetState extends State<FlashcardWidget> {
  // Controlador para el carrusel de flashcards (si hay más de una)
  final PageController _pageController = PageController(viewportFraction: 0.92);
  int _currentIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Obtenemos la lista de flashcards. Si es nula o vacía, mostramos un fallback.
    final flashcards = widget.content.flashcards;

    if (flashcards == null || flashcards.isEmpty) {
      return const Center(child: Text("No hay flashcards disponibles"));
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Área principal de las tarjetas (Carrusel)
        Expanded(
          child: PageView.builder(
            controller: _pageController,
            itemCount: flashcards.length,
            physics: const BouncingScrollPhysics(),
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: _SingleFlashcardItem(
                  data: flashcards[index],
                  index: index,
                  total: flashcards.length,
                ),
              );
            },
          ),
        ),
        
        const SizedBox(height: 20),
        
        // Indicador de progreso (Puntos o Texto)
        if (flashcards.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 12.0),
            child: Text(
              "${_currentIndex + 1} / ${flashcards.length}",
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
      ],
    );
  }
}

/// Widget interno que representa UNA sola tarjeta con su lógica de volteo
class _SingleFlashcardItem extends StatefulWidget {
  final Map<String, dynamic> data;
  final int index;
  final int total;

  const _SingleFlashcardItem({
    required this.data,
    required this.index,
    required this.total,
  });

  @override
  State<_SingleFlashcardItem> createState() => _SingleFlashcardItemState();
}

class _SingleFlashcardItemState extends State<_SingleFlashcardItem> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late Animation<double> _flipAnimation;
  
  // Animación de fondo
  late AnimationController _bgController;

  bool _isFront = true;

  @override
  void initState() {
    super.initState();
    _flipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _flipAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _flipController, curve: Curves.easeInOutBack),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15), // Rotación lenta y relajante
    )..repeat(); // Bucle continuo sin reversa
  }

  @override
  void dispose() {
    _flipController.dispose();
    _bgController.dispose();
    super.dispose();
  }

  void _toggleCard() {
    if (_isFront) {
      _flipController.forward();
    } else {
      _flipController.reverse();
    }
    setState(() {
      _isFront = !_isFront;
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggleCard,
      child: AnimatedBuilder(
        animation: Listenable.merge([_flipController, _bgController]),
        builder: (context, child) {
          final double angle = _flipAnimation.value * pi;
          final bool isFrontVisible = angle < pi / 2;
          
          // Calculamos la rotación del gradiente (0 a 2*pi)
          final double gradientAngle = _bgController.value * 2 * pi;
          
          // Factor de sombra dinámica: 1.0 cuando está plana, 0.0 cuando está a 90 grados
          final double shadowFactor = 1.0 - sin(angle).abs();

          final Matrix4 transform = Matrix4.identity()
            ..setEntry(3, 2, 0.002) // Aumentamos perspectiva
            ..rotateY(angle);

          return Transform(
            transform: transform,
            alignment: Alignment.center,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.15 * shadowFactor),
                    blurRadius: 24 * shadowFactor,
                    offset: Offset(0, 12 * shadowFactor),
                  ),
                  BoxShadow(
                    color: const Color(0xFFE0E5EC).withOpacity(0.6 * shadowFactor),
                    blurRadius: 16 * shadowFactor,
                    spreadRadius: -4,
                  ),
                ],
                gradient: LinearGradient(
                  begin: Alignment(cos(gradientAngle), sin(gradientAngle)),
                  end: Alignment(cos(gradientAngle + pi), sin(gradientAngle + pi)),
                  colors: const [
                    Color.fromARGB(255, 183, 197, 223), // Blanco azulado muy sutil
                    Color.fromARGB(255, 160, 247, 169), // Azul pastel claro
                    Color.fromARGB(255, 149, 172, 207), // Azul sereno suave
                  ],
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  isFrontVisible
                      ? _buildFrontSide()
                      : Transform(
                          alignment: Alignment.center,
                          transform: Matrix4.identity()..rotateY(pi),
                          child: _buildBackSide(),
                        ),
                  // Capa de brillo simulado (Glare)
                  IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(32),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Colors.white.withOpacity(0.0),
                            Colors.white.withOpacity(0.2 * sin(angle).abs()),
                            Colors.white.withOpacity(0.0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFrontSide() {
    final String text = widget.data['front'] ?? 'Sin pregunta';
    // Si hubiera imagen en el frente, la procesaríamos aquí.
    // Por ahora asumimos que el frente es principalmente texto/pregunta.
    
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          
          const SizedBox(height: 30),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: Colors.black87,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildBackSide() {
    final String text = widget.data['back'] ?? 'Sin respuesta';
    // Detectamos imagen en el reverso (que es lo común para explicaciones)
    final dynamic imageSource = widget.data['backImage']; 
    final bool hasImage = imageSource != null && imageSource.toString().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Detectamos si es formato horizontal (Landscape) para adaptar el layout
          final bool isLandscape = constraints.maxWidth > constraints.maxHeight;

          if (hasImage) {
            // --- CASO 1: CON IMAGEN ---
            // Si es horizontal, usamos Row para no aplastar la imagen
            if (isLandscape) {
              return Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: _buildImageContainer(imageSource),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    flex: 4,
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Text(
                          text,
                          textAlign: TextAlign.left,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.3,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            } else {
              // Si es vertical, mantenemos Column
              return Column(
                children: [
                  Expanded(
                    flex: 4,
                    child: _buildImageContainer(imageSource),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    flex: 2,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Text(
                          text,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                            height: 1.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }
          }

          // --- CASO 2: SOLO TEXTO ---
          return Center(
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Text(
                    text,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 20,
                      color: Colors.black87,
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            );
        },
      ),
    );
  }

  Widget _buildImageContainer(dynamic source) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: _buildImage(source),
    );
  }

  /// Helper para construir la imagen ya sea desde File (local) o Network (remoto)
  Widget _buildImage(dynamic source) {
    if (source is String) {
      if (source.startsWith('http')) {
        return Image.network(
          source,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
        );
      } else {
        // Asumimos que es un path local si no empieza con http
        return Image.file(
          File(source),
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.image_not_supported, color: Colors.grey)),
        );
      }
    } else if (source is File) {
       return Image.file(
          source,
          fit: BoxFit.cover,
       );
    }
    return const SizedBox();
  }
}