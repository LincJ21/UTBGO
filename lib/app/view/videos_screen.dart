import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'video_model.dart';
import 'video_player_widget.dart';

/// [VideosScreen] es la pantalla principal que muestra los videos en un formato de scroll vertical,
/// similar a TikTok.
///
/// Se encarga de:
/// - Cargar la lista inicial de videos desde la API de Pexels.
/// - Implementar el "scroll infinito" para cargar más videos cuando el usuario llega al final.
class VideosScreen extends StatefulWidget {
  /// --- NUEVO --- Callback para notificar al padre sobre cambios de visibilidad.
  final Function(bool isVisible) onVisibilityChanged;

  const VideosScreen({super.key, required this.onVisibilityChanged});

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> {
  // --- Variables de Estado para el Scroll Infinito ---

  /// [_videos] almacena la lista de videos que se están mostrando.
  final List<VideoModel> _videos = [];

  /// [_pageController] nos permite escuchar los eventos de scroll del PageView.
  final _pageController = PageController();

  /// [_isLoading] controla si se está mostrando el indicador de carga inicial.
  bool _isLoading = true;

  /// [_isMoreLoading] controla si se muestra el indicador de carga al final de la lista.
  bool _isMoreLoading = false;

  /// [_currentPage] lleva la cuenta de qué página de resultados pedir a la API.
  int _currentPage = 1;

  /// [_hasMore] indica si hay más videos por cargar desde la API.
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    // 1. Carga los videos iniciales cuando el widget se crea.
    _fetchVideos();

    // 2. Añade un "listener" al controlador del PageView.
    _pageController.addListener(() {
      // Si el usuario ha deslizado casi hasta el final de la lista y no estamos ya cargando más...
      if (_pageController.position.pixels >= _pageController.position.maxScrollExtent - 200 &&
          !_isMoreLoading) {
        // ...entonces, carga la siguiente página de videos.
        _loadMoreVideos();
      }
    });
  }

  @override
  void dispose() {
    // Es importante "desechar" el controlador para liberar recursos.
    _pageController.dispose();
    super.dispose();
  }

  /// Carga videos desde la API de Pexels.
  /// Esta función se usa tanto para la carga inicial como para cargar más videos.
  Future<void> _fetchVideos() async {
    // Si no hay más videos por cargar, no hace nada.
    // --- CORRECCIÓN: Apuntar al backend local en lugar de Pexels ---
    // La API de Pexels se usaba para obtener videos, pero los likes/bookmarks
    // apuntaban a nuestro backend. Esto es inconsistente.
    // Ahora apuntamos a una nueva ruta en nuestro backend: /api/videos/feed
    // NOTA: Debes implementar esta ruta en tu backend de Go.
    const String baseUrl = 'http://10.0.2.2:8080/api';
    final Uri uri = Uri.parse('$baseUrl/videos/feed?page=$_currentPage');

    try {
      // En una app real, enviarías el token JWT aquí si el feed es privado.
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> videoJson =
            data['videos']; // Asumimos que el backend devuelve { "videos": [...] }
        // Usamos un constructor `fromBackendJson` que debes crear en tu VideoModel.
        final newVideos = videoJson.map((json) => VideoModel.fromBackendJson(json)).toList();

        // Actualiza el estado del widget dentro de setState para que la UI se redibuje.
        setState(() {
          // Si la API no devuelve videos, asumimos que no hay más.
          if (newVideos.isEmpty) {
            _hasMore = false;
          } else {
            // Añade los nuevos videos a la lista existente y avanza el contador de página.
            _videos.addAll(newVideos);
            _currentPage++;
          }
          _isLoading = false;
          _isMoreLoading = false;
        });
      } else {
        // Si la API da un error, detenemos los indicadores de carga.
        setState(() {
          _isLoading = false;
          _isMoreLoading = false;
        });
        throw Exception('Fallo al cargar videos del backend: ${response.statusCode}');
      }
    } catch (e) {
      // Si ocurre cualquier otro error (ej. sin conexión a internet), lo muestra en la consola.
      debugPrint('Error fetching videos: $e.');
      setState(() => _isLoading = false);
    }
  }

  /// Función auxiliar para iniciar la carga de más videos.
  void _loadMoreVideos() {
    if (_hasMore && !_isMoreLoading) {
      setState(() {
        _isMoreLoading = true;
      });
      _fetchVideos();
    }
  }

  @override
  Widget build(BuildContext context) {
    // --- Lógica de construcción de la UI basada en el estado ---

    // 1. Si está en la carga inicial, muestra un indicador de progreso centrado.
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Si la carga terminó y no hay videos, muestra un mensaje.
    if (_videos.isEmpty) {
      return const Center(child: Text('No hay videos para mostrar.'));
    }

    // 3. Si hay videos, construye el PageView.
    return PageView.builder(
      controller: _pageController,
      scrollDirection: Axis.vertical,
      // El número de items es la cantidad de videos + 1 si hay más por cargar (para el loader).
      itemCount: _videos.length + (_hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Si el índice corresponde al último item (el loader)...
        if (index == _videos.length) {
          // ...muestra el indicador de carga al final.
          return const Center(child: CircularProgressIndicator());
        }

        // Si no, obtiene el video y crea el widget reproductor.
        final video = _videos[index];
        return VideoPlayerWidget(
          key: Key(video.id), // La key ayuda a Flutter a identificar cada video de forma única.
          video: video,
          onVisibilityChanged: widget.onVisibilityChanged, // Pasamos el callback
        );
      },
    );
  }
}
