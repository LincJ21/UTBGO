import 'package:flutter/material.dart';
import 'video_model.dart';
import 'video_player_widget.dart';
import 'widgets/feed_flashcard_widget.dart';
import 'widgets/feed_poll_widget.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';
import 'services/offline_feed_service.dart';
import 'services/global_ui_service.dart';

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
  final _apiClient = ApiClient();

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

  /// Carga videos desde el backend con autenticación JWT.
  Future<void> _fetchVideos() async {
    // Intentamos cargar primero desde el Motor de Recomendaciones de IA
    // Si la lista de IA nos devuelve vacío o falla, usamos el Feed general como Fallback seguro.
    final recommendUrl = '${AppConfig.recommendPersonalizedEndpoint}?n=10';
    
    // NOTA: Como la API de recomendaciones no tiene endpoint con "page",
    // en la primera página pedimos IA. Para las siguientes páginas (scroll infinito), 
    // pasamos directamente al Feed General para no pedir lo mismo.
    
    ApiResponse<List<VideoModel>> response;
    bool usingFallback = _currentPage > 1;

    if (!usingFallback) {
      // Pedimos a la IA
      response = await _apiClient.get<List<VideoModel>>(
        recommendUrl,
        requiresAuth: true,
        fromJson: (json) {
          // El JSON de recomendaciones en Go devuelve una lista cruda
          final List<dynamic> videoJson = (json as List<dynamic>?) ?? [];
          return videoJson.map((v) => VideoModel.fromBackendJson(v)).toList();
        },
      );

      // Verificamos si la IA nos falló o está vacía
      if (!response.isSuccess || response.data == null || response.data!.isEmpty) {
        usingFallback = true;
      }
    } else {
      // Si ya falló o es página > 1, creamos un "mock" de error para forzar el fallback local
      response = ApiResponse<List<VideoModel>>.error(ApiError(ApiErrorType.serverError, 'Fallback forced'));
    }

    // ACTIVAMOS EL FALLBACK SEGURO (El Feed General)
    if (usingFallback) {
      if (_currentPage == 1) {
        debugPrint('⚠️ [API] IA no disponible o sin gustos suficientes. Activando Fallback al Feed General/Reciente.');
      }
      final fallbackUrl = '${AppConfig.videosFeedEndpoint}?page=$_currentPage';
      response = await _apiClient.get<List<VideoModel>>(
        fallbackUrl,
        requiresAuth: true,
        fromJson: (json) {
          final List<dynamic> videoJson = (json['videos'] as List<dynamic>?) ?? [];
          return videoJson.map((v) => VideoModel.fromBackendJson(v)).toList();
        },
      );
    }

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final newVideos = response.data!;
      setState(() {
        if (newVideos.isEmpty) {
          _hasMore = false;
        } else {
          _videos.addAll(newVideos);
          _currentPage++;
        }
        _isLoading = false;
        _isMoreLoading = false;
      });

      // Guardamos todo el feed actual en caché silenciosamente
      OfflineFeedService.saveFeed(_videos);
    } else {
      debugPrint('Error fetching videos: ${response.error?.message}');

      // Si falla y es la primera carga, intentamos usar la caché offline
      if (_videos.isEmpty) {
        final cachedVideos = await OfflineFeedService.getCachedFeed();
        if (cachedVideos.isNotEmpty && mounted) {
          setState(() {
            _videos.clear();
            _videos.addAll(cachedVideos);
            _hasMore = false;
            _isLoading = false;
            _isMoreLoading = false;
          });
          GlobalUIService.showInfo('Modo Offline: Mostrando contenido guardado.');
          return;
        }
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _isMoreLoading = false;
      });
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

        // Si no, obtiene el video y determina qué widget usar según el tipo de contenido.
        final video = _videos[index];

        if (video.contentType == 'flashcard') {
          return FeedFlashcardWidget(
            key: Key('fc_${video.id}'),
            video: video,
            onVisibilityChanged: widget.onVisibilityChanged,
          );
        } else if (video.contentType == 'encuesta') {
          return FeedPollWidget(
            key: Key('poll_${video.id}'),
            video: video,
            onVisibilityChanged: widget.onVisibilityChanged,
          );
        } else {
          // Por defecto ('video' o 'imagen') usamos el VideoPlayerWidget 
          return VideoPlayerWidget(
            key: Key('vid_${video.id}'),
            video: video,
            onVisibilityChanged: widget.onVisibilityChanged,
          );
        }
      },
    );
  }
}
