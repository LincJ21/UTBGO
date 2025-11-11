import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'video_model.dart';
import 'search_results_screen.dart';

class VideoPlayerWidget extends StatefulWidget {
  /// El modelo de datos completo del video.
  final VideoModel video;

  /// --- NUEVO --- Callback para notificar cambios de visibilidad de los controles.
  final Function(bool isVisible) onVisibilityChanged;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    required this.onVisibilityChanged,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  // URL base de tu backend en Go.
  // Usa 'http://10.0.2.2:8080' para el emulador de Android.
  // Usa 'http://localhost:8080' para iOS o web.
  static const String _baseUrl = 'http://10.0.2.2:8080';

  /// [_controller] es el controlador principal para el reproductor de video.
  late VideoPlayerController _controller;

  /// [_searchController] para el campo de búsqueda.
  final TextEditingController _searchController = TextEditingController();

  /// Controla si la barra de búsqueda está visible.
  bool _isSearching = false;

  /// --- NUEVO --- Controla si los controles (botones, barra superior) están visibles.
  bool _showControls = true;

  /// Simula una llamada a la API para dar "like" o "unlike".
  Future<void> _toggleLike() async {
    // Lógica optimista: actualiza la UI inmediatamente.
    setState(() {
      widget.video.isLiked = !widget.video.isLiked;
      widget.video.isLiked ? widget.video.likes++ : widget.video.likes--;
    });

    // Llama a tu backend en Go.
    // En un caso real, manejarías el error si la llamada falla.
    await http.post(Uri.parse('$_baseUrl/api/videos/${widget.video.id}/like'));
  }

  /// Simula una llamada a la API para guardar o desguardar.
  Future<void> _toggleBookmark() async {
    setState(() {
      widget.video.isBookmarked = !widget.video.isBookmarked;
    });
    await http.post(Uri.parse('$_baseUrl/api/videos/${widget.video.id}/bookmark'));
  }

  /// Muestra un diálogo simple para los comentarios.
  void _showComments() {
    // En una app real, esto abriría una nueva pantalla o un panel inferior
    // que cargaría los comentarios desde `GET /api/videos/{id}/comments`.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Comentarios'),
        content: Text('Mostrando comentarios para el video ${widget.video.id}.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  /// Lógica para compartir (requiere el paquete `share_plus`).
  void _shareVideo() {
    // import 'package:share_plus/share_plus.dart';
    // Share.share('¡Mira este video increíble! ${widget.video.videoUrl}');
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Función de compartir no implementada')));
  }

  /// Ejecuta la búsqueda.
  Future<void> _performSearch() async {
    final query = _searchController.text;
    if (query.isEmpty) return;

    // Oculta el teclado
    FocusScope.of(context).unfocus();

    final Uri uri = Uri.parse('$_baseUrl/api/videos/search?q=$query');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> videoJson = data['videos'];
        final searchResults = videoJson.map((json) => VideoModel.fromBackendJson(json)).toList();

        // Navega a la pantalla de resultados
        // Es importante usar `mounted` para asegurarse de que el widget todavía está en el árbol.
        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SearchResultsScreen(
              searchResults: searchResults,
              query: query,
            ),
          ),
        );
      } else {
        throw Exception('Fallo al buscar videos: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error en la búsqueda: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al realizar la búsqueda.')),
        );
      }
    }
    setState(() {
      _isSearching = false;
    });
  }

  @override
  void initState() {
    super.initState();
    // Decide qué tipo de controlador usar basado en si el video es de red o local.
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));

    _controller.initialize().then((_) {
      // Una vez inicializado, actualiza la UI, inicia la reproducción y lo pone en bucle.
      setState(() {});
      _controller.play();
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    // Libera los recursos del controlador cuando el widget es destruido.
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Construye la barra de navegación superior con la lógica de búsqueda.
  Widget _topNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: _isSearching
              // --- VISTA DE BÚSQUEDA ACTIVA ---
              ? Row(
                  key: const ValueKey('search_bar'),
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white, size: 30),
                      onPressed: () => setState(() => _isSearching = false),
                    ),
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: TextField(
                          controller: _searchController,
                          autofocus: true,
                          style: const TextStyle(color: Colors.black87),
                          decoration: const InputDecoration(
                            hintText: 'Buscar videos...',
                            hintStyle: TextStyle(color: Colors.grey, fontSize: 16),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.only(left: 16.0, bottom: 8.0),
                          ),
                          onSubmitted: (_) => _performSearch(),
                        ),
                      ),
                    ),
                    IconButton(
                        icon: const Icon(Icons.search, color: Colors.white, size: 24),
                        onPressed: _performSearch,
                        style: IconButton.styleFrom(
                          backgroundColor: const Color(0xFF003399),
                          padding: const EdgeInsets.all(8),
                        )
                        // --- CAMBIO ---
                        // Le damos un fondo azul al botón de búsqueda para que destaque.
                        // Container(
                        //   decoration: const BoxDecoration(color: Color(0xFF003399), shape: BoxShape.circle),
                        //   child: IconButton(icon: const Icon(Icons.search, color: Colors.white, size: 30), onPressed: _performSearch),
                        // ),
                        ),
                  ],
                )
              // --- VISTA PREDETERMINADA (BOTONES) ---
              : Row(
                  key: const ValueKey('default_nav'),
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.menu, color: Colors.white, size: 30),
                      onPressed: () {
                        /* Lógica para el menú */
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.search, color: Colors.white, size: 30),
                      onPressed: () => setState(() => _isSearching = true),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  /// Construye un botón de acción con su icono y texto (contador).
  Widget _buildActionButton({
    required IconData icon,
    required String text,
    required VoidCallback onPressed,
    Color? iconColor,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          icon: Icon(icon, size: 35, color: iconColor ?? Colors.white),
          onPressed: onPressed,
        ),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
        const SizedBox(height: 15),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Si el controlador no se ha inicializado, muestra un loader.
    return _controller.value.isInitialized
        ? Stack(
            alignment: Alignment.center,
            children: [
              // El video en sí. El FittedBox asegura que el video cubra toda la pantalla.
              GestureDetector(
                // --- CAMBIO PRINCIPAL ---
                // Este GestureDetector ahora cubre toda la pantalla y controla la visibilidad.
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                    // --- CAMBIO CLAVE --- Llamamos al callback para notificar al padre.
                    widget.onVisibilityChanged(_showControls);
                  });
                },
                child: SizedBox.expand(
                  child: FittedBox(
                    fit: BoxFit.cover,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
              ),

              // --- NUEVO --- Contenedor para los controles que aparecen y desaparecen.
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                // Ignora los toques cuando los controles están ocultos.
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      // Superpone la barra de navegación superior.
                      Positioned(top: 0, left: 0, right: 0, child: _topNav()),

                      // Botón de Pausa/Reproducir en el centro.
                      Center(
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _controller.value.isPlaying
                                  ? _controller.pause()
                                  : _controller.play();
                            });
                          },
                          child: AnimatedOpacity(
                            opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                            duration: const Duration(milliseconds: 250),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.green[400]?.withOpacity(0.9),
                              ),
                              child: const Icon(Icons.play_arrow, size: 80, color: Colors.white),
                            ),
                          ),
                        ),
                      ),

                      // Superpone la columna de botones de acción a la derecha.
                      Positioned(
                        right: 15,
                        bottom: 80,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildActionButton(
                              icon: widget.video.isLiked ? Icons.favorite : Icons.favorite_border,
                              iconColor: widget.video.isLiked ? Colors.red : Colors.white,
                              text: widget.video.likes.toString(),
                              onPressed: _toggleLike,
                            ),
                            _buildActionButton(
                              icon: Icons.chat_bubble_outline,
                              text: widget.video.comments.toString(),
                              onPressed: _showComments,
                            ),
                            _buildActionButton(
                              icon: widget.video.isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              text: 'Guardar',
                              onPressed: _toggleBookmark,
                            ),
                            _buildActionButton(
                              icon: Icons.share,
                              text: 'Compartir',
                              onPressed: _shareVideo,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          )
        : const Center(child: CircularProgressIndicator());
  }
}
