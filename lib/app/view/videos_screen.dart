import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'video_model.dart';
import 'search_results_screen.dart'; // Asegúrate de tener este import si usas la búsqueda
import 'notifications_screen.dart';
import 'api_constants.dart';
import 'feed_item.dart'; // Importamos el nuevo widget separado

/// [VideosScreen] es la pantalla principal que muestra los videos en un formato de scroll vertical,
/// similar a TikTok.
///
/// Se encarga de:s
/// - Cargar la lista inicial de videos desde la API de Pexels.
/// - Implementar el "scroll infinito" para cargar más videos cuando el usuario llega al final.
class VideosScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const VideosScreen({
    super.key,
    required this.onLogout,
  });

  @override
  State<VideosScreen> createState() => _VideosScreenState();
}

class _VideosScreenState extends State<VideosScreen> with SingleTickerProviderStateMixin {
  // --- Variables de Estado para el Scroll Infinito ---

  /// [_videos] almacena la lista de videos que se están mostrando.
  final List<VideoModel> _videos = [];

  /// [_pageController] nos permite escuchar los eventos de scroll del PageView.
  final PageController _pageController = PageController(); 

  /// [_isLoading] controla si se está mostrando el indicador de carga inicial.
  bool _isLoading = true;

  /// [_isMoreLoading] controla si se muestra el indicador de carga al final de la lista.
  bool _isMoreLoading = false;

  /// [_currentPage] lleva la cuenta de qué página de resultados pedir a la API.
  int _currentPage = 1;

  /// [_hasMore] indica si hay más videos por cargar desde la API.
  bool _hasMore = true;

  /// Estado para el icono de notificaciones
  bool _isNotificationsActive = false;

  /// Índice actual para controlar colores de la UI
  int _currentIndex = 0;

  late AnimationController _bellController;

  @override
  void initState() {
    super.initState();
    // 1. Carga los videos iniciales cuando el widget se crea.
    _fetchVideos();

    // Inicializar controlador de animación para la campana
    _bellController = AnimationController(
      duration: const Duration(milliseconds: 600), // Duración para 2 movimientos
      vsync: this,
    );

    // SIMULACIÓN: Notificación entrante a los 3 segundos
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() => _isNotificationsActive = true); // Aparece el punto
        _bellController.forward(from: 0).then((_) {
          if (mounted) _bellController.reset();
        }); // Se mueve
        try {
          SystemSound.play(SystemSoundType.click); // Suena
        } catch (e) {
          debugPrint('Error playing sound: $e');
        }
      }
    });
  }

  @override
  void dispose() {
    // Es importante "desechar" el controlador para liberar recursos.
    _pageController.dispose();
    _bellController.dispose();
    super.dispose();
  }

  /// Genera un video de muestra para pruebas de UI.
  VideoModel _getMockVideo(int index) {
    return VideoModel(
      id: 'mock-video-$index-${DateTime.now().millisecondsSinceEpoch}',
      title: 'Video de Muestra #$index',
      videoUrl: 'assets/videos/v1.mp4',
      thumbnailUrl: '', // Sin miniatura de red, el player mostrará el video o loader
      description: 'Video vertical de prueba para validar el diseño del feed. Este texto es intencionalmente largo para verificar que el corte de líneas funciona correctamente y aparece el botón de ver más al final.',
      likes: 150,
      comments: 20,
      contentType: 'video',
      isLiked: true,
    );
  }

  /// Carga videos desde la API de Pexels.
  /// Esta función se usa tanto para la carga inicial como para cargar más videos.
  Future<void> _fetchVideos() async {
    if (_isLoading && _currentPage == 1) _videos.clear(); // Limpieza preventiva
    // URL de tu backend local (para emulador Android usa 10.0.2.2)
    final Uri uri = Uri.parse('${ApiConstants.apiUrl}/videos/feed?page=$_currentPage');

    try {
      // Intentamos conectar con el backend real
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> videoJson = data['videos'] ?? [];

        // Mapeamos la respuesta JSON a objetos VideoModel
        final List<VideoModel> newVideos = videoJson.map((json) {
          return VideoModel(
            id: json['id'].toString(),
            title: json['title'] ?? '',
            videoUrl: json['video_url'] ?? '',
            thumbnailUrl: json['thumbnail_url'] ?? '',
            description: json['description'] ?? '',
            likes: json['likes'] ?? 0,
            comments: json['comments'] ?? 0,
            contentType: json['content_type'] ?? 'video',
            isLiked: json['is_liked'] ?? false,
            // Asegúrate de que tu modelo acepte isBookmarked, si no, omítelo
            isBookmarked: json['is_bookmarked'] ?? false,
          );
        }).toList();

        if (mounted) {
          setState(() {
            // Si es la primera página, cargamos primero las publicaciones locales (Simulación)
            if (_currentPage == 1) {
              _videos.clear();
              _videos.addAll(VideoModel.localFeed);
            }

            // Si hay videos reales, los agregamos a la lista.
            if (newVideos.isNotEmpty) {
              _videos.addAll(newVideos);
            } else {
              // Si no hay videos reales (o se acabaron), rellenamos con Mocks
              // para cumplir el requerimiento de scroll infinito con el video actual.
              final mockVideos = List.generate(5, (index) => _getMockVideo(_videos.length + index));
              _videos.addAll(mockVideos);
            }
            _currentPage++;
            _isLoading = false;
            _isMoreLoading = false;
          });
        }
      } else {
        throw Exception('Error del servidor: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error cargando videos del backend: $e. Usando Mocks locales.');
      // --- FALLBACK: Si falla la conexión, usamos los videos locales de prueba ---
      await Future.delayed(const Duration(seconds: 1)); // Simular delay
      final mockVideos = List.generate(5, (index) => _getMockVideo(_videos.length + index));
      if (mounted) {
        setState(() {
          // También en caso de error/fallback mostramos los locales
          if (_currentPage == 1) {
            _videos.clear();
            _videos.addAll(VideoModel.localFeed);
          }
          _videos.addAll(mockVideos);
          // Solo agregamos mocks si la lista está vacía para evitar duplicados infinitos en error
          if (_videos.isEmpty) {
             _videos.addAll(List.generate(5, (index) => _getMockVideo(index)));
          }
          _currentPage++;
          _isLoading = false;
          _isMoreLoading = false;
        });
      }
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

  /// Recarga el feed desde cero (Pull-to-Refresh) para ver nuevas publicaciones.
  Future<void> _refreshFeed() async {
    // URL de tu backend local
    // Pedimos siempre la página 1 al refrescar para obtener lo más nuevo
    final Uri uri = Uri.parse('${ApiConstants.apiUrl}/videos/feed?page=1');

    try {
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> videoJson = data['videos'] ?? [];

        final List<VideoModel> newVideos = videoJson.map((json) {
          return VideoModel(
            id: json['id'].toString(),
            title: json['title'] ?? '',
            videoUrl: json['video_url'] ?? '',
            thumbnailUrl: json['thumbnail_url'] ?? '',
            description: json['description'] ?? '',
            likes: json['likes'] ?? 0,
            comments: json['comments'] ?? 0,
            contentType: json['content_type'] ?? 'video',
            isLiked: json['is_liked'] ?? false,
            isBookmarked: json['is_bookmarked'] ?? false,
          );
        }).toList();

        if (mounted) {
          setState(() {
            _videos.clear(); // Limpiamos la lista actual para poner lo nuevo
            // Re-agregamos las publicaciones locales al refrescar
            _videos.addAll(VideoModel.localFeed);

            if (newVideos.isNotEmpty) {
              _videos.addAll(newVideos);
            } else {
              // Si no hay videos reales, usamos mocks
              final mockVideos = List.generate(5, (index) => _getMockVideo(index));
              _videos.addAll(mockVideos);
            }
            // Reiniciamos la paginación para que el scroll infinito siga desde la página 2
            _currentPage = 2;
            _hasMore = true;
            _isLoading = false;
            _isMoreLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error refrescando feed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Configuración de la barra de estado para fondos oscuros
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent, // Fondo transparente
        statusBarIconBrightness: Brightness.light, // Iconos blancos (Android)
        statusBarBrightness: Brightness.dark,      // Iconos blancos (iOS)
      ),
      child: Scaffold(
        backgroundColor: Colors.black, // Fondo negro para experiencia inmersiva
        body: Stack(
          children: [
            // 1. Contenido del Feed (Scroll Vertical PageView)
            Positioned.fill(
              child: _buildFeed(),
            ),

            // 2. Barra Superior Fija (Top Bar) - Superpuesta
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: _buildTopBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeed() {
    // --- Lógica de construcción de la UI basada en el estado ---

    // 1. Si está en la carga inicial, muestra un indicador de progreso centrado.
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Si la carga terminó y no hay videos, muestra un mensaje.
    if (_videos.isEmpty) {
      return const Center(child: Text('No hay videos para mostrar.'));
    }

    // 3. PageView vertical para efecto Reels 100%
    return RefreshIndicator(
      onRefresh: _refreshFeed,
      color: const Color.fromRGBO(0, 26, 63, 1), // Azul UTB
      child: PageView.builder(
        controller: _pageController,
        scrollDirection: Axis.vertical,
        // AlwaysScrollableScrollPhysics asegura que puedas deslizar hacia abajo incluso si hay pocos videos
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _videos.length + (_hasMore ? 1 : 0),
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
          // Cargar más si nos acercamos al final
          if (index >= _videos.length - 2 && !_isMoreLoading) {
            _loadMoreVideos();
          }
        },
        itemBuilder: (context, index) {
          if (index == _videos.length) {
            return const Center(child: CircularProgressIndicator());
          }
          return FeedItem(
            video: _videos[index],
            pageController: _pageController,
            index: index,
            currentIndex: _currentIndex, // Pasamos el índice actual
          );
        },
      ),
    );
  }

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 7.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Icono de Búsqueda (Izquierda)
            GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchScreen())),
              child: const Icon(Icons.search, color: Colors.white, size: 30),
            ),

            // Icono de Notificaciones (Ahora a la Derecha)
            Stack(
              children: [
                GestureDetector(
                  onTap: () {
                     // Al leer (tocar), quitamos el punto verde
                     setState(() => _isNotificationsActive = false);
                     Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationsScreen()));
                  },
                  child: AnimatedBuilder(
                    animation: _bellController,
                    builder: (context, child) {
                      // Animación de sacudida (rotación)
                      double angle = 0;
                      if (_bellController.isAnimating) {
                        angle = math.sin(_bellController.value * math.pi * 4) * 0.2;
                      }
                      return Transform.rotate(
                        angle: angle,
                        // Icono blanco puro con el borde negro simulado por sombras
                        child: const Icon(Icons.notifications_none_outlined, color: Colors.white, size: 30),
                      );
                    },
                  ),
                ),
                if (_isNotificationsActive)
                  Positioned(
                    top: 5,
                    right: 5,
                    child: Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(color: Color.fromARGB(255, 65, 206, 43), shape: BoxShape.circle),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
