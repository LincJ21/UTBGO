import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'video_model.dart';

class VideoPlayerWidget extends StatefulWidget {
  /// El modelo de datos completo del video.
  final VideoModel video;

  const VideoPlayerWidget({super.key, required this.video});

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
  void _performSearch() {
    final query = _searchController.text;
    if (query.isEmpty) return;

    // Aquí llamarías a tu API: `GET /api/videos/search?q=$query`
    // y luego navegarías a una pantalla de resultados.
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Búsqueda'),
        content: Text('Buscando videos para: "$query"'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK')),
        ],
      ),
    );
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

  Widget _topNav() {
    // Este widget construye la barra de búsqueda superior.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white, size: 30),
              onPressed: () {
                /* Lógica para el menú */
              },
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: TextField(
                  controller: _searchController,
                  style: const TextStyle(color: Colors.black87),
                  decoration: InputDecoration(
                    hintText: 'Search videos',
                    hintStyle: const TextStyle(color: Colors.grey, fontSize: 16),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(left: 16.0, bottom: 8.0),
                    suffixIcon: Container(
                      width: 50,
                      decoration: const BoxDecoration(
                        color: Color(0xFF003399),
                        borderRadius: BorderRadius.only(
                          topRight: Radius.circular(20),
                          bottomRight: Radius.circular(20),
                        ),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: Colors.white, size: 24),
                        onPressed: _performSearch,
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _performSearch(),
                ),
              ),
            ),
          ],
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
            fit: StackFit.expand,
            children: [
              // El video en sí. El FittedBox asegura que el video cubra toda la pantalla.
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.cover,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              ),

              // Superpone la barra de navegación superior.
              Positioned(top: 0, left: 0, right: 0, child: _topNav()),
              Center(
                child: GestureDetector(
                  // Permite pausar/reanudar el video al tocar el centro de la pantalla.
                  onTap: () {
                    setState(() {
                      _controller.value.isPlaying ? _controller.pause() : _controller.play();
                    });
                  },
                  child: Container(
                    color: Colors.transparent,
                    // El botón de play que aparece y desaparece.
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
                      icon: widget.video.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
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
          )
        : const Center(child: CircularProgressIndicator());
  }
}
