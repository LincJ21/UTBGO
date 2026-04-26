import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'video_model.dart';
import 'search_results_screen.dart';
import 'comments_bottom_sheet.dart';
import 'description_bottom_sheet.dart';
import 'notifications_screen.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'public_profile_screen.dart';
import 'profile_screen.dart';
import 'services/global_ui_service.dart';

class VideoPlayerWidget extends StatefulWidget {
  final VideoModel video;
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
  VideoPlayerController? _controller;
  late bool _isImage;
  final _apiClient = ApiClient();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showControls = true;
  bool _viewTracked = false; // Evita reportar la misma vista múltiples veces por rebuild

  /// Reporta al backend que el usuario reprodujo este video (fire-and-forget).
  /// Usa http.post directo en vez de ApiClient para evitar que errores de
  /// tracking muestren SnackBars al usuario. El tracking es invisible.
  Future<void> _trackView() async {
    if (_viewTracked) return;
    _viewTracked = true;

    try {
      final token = await const FlutterSecureStorage().read(key: 'jwt_token');
      if (token == null) return;

      http.post(
        Uri.parse(AppConfig.videoViewUrl(widget.video.id)),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ); // No await: fire-and-forget
    } catch (_) {
      // Silenciar errores de tracking — nunca interrumpir la experiencia del usuario
    }
  }

  Future<void> _toggleLike() async {
    final wasLiked = widget.video.isLiked;
    final prevLikes = widget.video.likes;

    setState(() {
      widget.video.isLiked = !widget.video.isLiked;
      widget.video.isLiked ? widget.video.likes++ : widget.video.likes--;
    });

    final response = await _apiClient.post(
      AppConfig.videoLikeUrl(widget.video.id),
      requiresAuth: true,
    );

    if (!response.isSuccess && mounted) {
      setState(() {
        widget.video.isLiked = wasLiked;
        widget.video.likes = prevLikes;
      });
    }
  }

  Future<void> _toggleBookmark() async {
    final wasBookmarked = widget.video.isBookmarked;
    setState(() => widget.video.isBookmarked = !widget.video.isBookmarked);

    final response = await _apiClient.post(
      AppConfig.videoBookmarkUrl(widget.video.id),
      requiresAuth: true,
    );

    if (!response.isSuccess && mounted) {
      setState(() => widget.video.isBookmarked = wasBookmarked);
    }
  }

  Future<void> _toggleRepost() async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString('role') ?? '';
    
    if (role == 'aspirante') {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Los aspirantes no pueden repostear contenido. ¡Inscríbete para disfrutar de todas las funciones!'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    final wasReposted = widget.video.isReposted;
    setState(() => widget.video.isReposted = !widget.video.isReposted);

    final response = await _apiClient.post(
      AppConfig.videoRepostUrl(widget.video.id),
      requiresAuth: true,
    );

    if (!response.isSuccess && mounted) {
      setState(() => widget.video.isReposted = wasReposted);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al procesar repost')),
      );
    }
  }

  void _shareVideo() {
    final title = widget.video.title.isNotEmpty ? widget.video.title : 'este video';
    final shareText = '¡Mira $title en UTBGO! \n\nhttps://utbgo.app/video/${widget.video.id}';
    Share.share(shareText);
  }

  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;
    
    FocusScope.of(context).unfocus();
    setState(() => _isSearching = false);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(query: query),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _isImage = widget.video.contentType == 'imagen';
    if (!_isImage) {
      _controller =
          VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
      _controller!.initialize().then((_) {
        setState(() {});
        _controller!.play();
        _controller!.setLooping(true);
        _trackView(); // Registrar reproducción al iniciar el video
      });
    } else {
      _trackView(); // También registrar para imágenes (el usuario la vio)
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return (_isImage || (_controller?.value.isInitialized ?? false))
        ? Stack(
            alignment: Alignment.center,
            children: [
              // Reproductor o Imagen a pantalla completa
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
                    widget.onVisibilityChanged(_showControls);
                  });
                },
                child: SizedBox.expand(
                  child: _isImage
                      ? Image.network(widget.video.videoUrl, fit: BoxFit.contain)
                      : FittedBox(
                          fit: BoxFit.cover,
                          child: SizedBox(
                            width: _controller!.value.size.width,
                            height: _controller!.value.size.height,
                            child: VideoPlayer(_controller!),
                          ),
                        ),
                ),
              ),

              // Overlay de controles
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 250),
                child: IgnorePointer(
                  ignoring: !_showControls,
                  child: Stack(
                    children: [
                      // Barra superior: Home + Buscar en UTBGO
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: _buildTopBar(),
                      ),

                      // Play/Pause central
                      if (!_isImage)
                        Center(
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _controller!.value.isPlaying
                                  ? _controller!.pause()
                                  : _controller!.play();
                            }),
                            child: AnimatedOpacity(
                              opacity: _controller!.value.isPlaying ? 0.0 : 1.0,
                              duration: const Duration(milliseconds: 250),
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.green[400]?.withValues(alpha: 0.9),
                                ),
                                child: const Icon(Icons.play_arrow,
                                    size: 64, color: Colors.white),
                              ),
                            ),
                          ),
                        ),

                      // Botones de acción a la derecha
                      Positioned(
                        right: 12,
                        bottom: 100,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _actionButton(
                              icon: widget.video.isLiked
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              color: widget.video.isLiked
                                  ? const Color(0xFF4CAF50)
                                  : Colors.white,
                              text: widget.video.likes.toString(),
                              onTap: _toggleLike,
                            ),
                            const SizedBox(height: 16),
                            _actionButton(
                              icon: Icons.comment,
                              color: Colors.white,
                              text: widget.video.comments.toString(),
                              onTap: () {
                                showCommentsBottomSheet(
                                  context, 
                                  videoId: widget.video.id,
                                  onCommentAdded: () {
                                    setState(() {
                                      widget.video.comments++;
                                    });
                                  },
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _actionButton(
                              icon: widget.video.isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: Colors.white,
                              text: '',
                              onTap: _toggleBookmark,
                            ),
                            const SizedBox(height: 16),
                            _actionButton(
                              icon: Icons.repeat,
                              color: widget.video.isReposted ? Colors.green : Colors.white,
                              text: '',
                              onTap: _toggleRepost,
                            ),
                            const SizedBox(height: 16),
                            _actionButton(
                              icon: Icons.share,
                              color: Colors.white,
                              text: '',
                              onTap: _shareVideo,
                            ),
                          ],
                        ),
                      ),

                      // Gradiente oscuro para asegurar que el texto sea siempre legible
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        height: 250,
                        child: IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.bottomCenter,
                                end: Alignment.topCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.8),
                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),

                      // Info del profesor abajo
                      Positioned(
                        left: 12,
                        right: 80,
                        bottom: 20,
                        child: GestureDetector(
                          onTap: () => showDescriptionBottomSheet(context, widget.video),
                          child: _buildAuthorInfo(),
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

  Widget _buildTopBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: _isSearching
            ? Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 26),
                    onPressed: () => setState(() => _isSearching = false),
                  ),
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.3), // Fondo más oscuro para contraste
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2), // Borde sutil transparente
                          width: 1,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: Colors.white,
                        decoration: InputDecoration(
                          hintText: 'Buscar en UTBGO...',
                          hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (_) => _performSearch(),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.search, color: Colors.white),
                    onPressed: _performSearch,
                  ),
                ],
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  GestureDetector(
                    onTap: () => setState(() => _isSearching = true),
                    child: const Icon(Icons.search, color: Colors.white, size: 28),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const NotificationsScreen(),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                        Positioned(
                          right: 2,
                          top: 2,
                          child: Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Colors.green, // Simulando el punto verde de la imagen
                              shape: BoxShape.circle,
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

  Widget _buildAuthorInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Avatar del profesor
            const CircleAvatar(
              radius: 18,
              backgroundColor: Color(0xFF90CAF9),
              child: Icon(Icons.person, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 10),
            // Nombre
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () async {
                  if (widget.video.authorId == 0) return;
                  
                  final prefs = await SharedPreferences.getInstance();
                  String userRole = prefs.getString('role') ?? 'estudiante';
                  
                  int myId = -1;
                  final token = await const FlutterSecureStorage().read(key: 'jwt_token');
                  if (token != null) {
                    final parts = token.split('.');
                    if (parts.length == 3) {
                      try {
                        String normalized = base64Url.normalize(parts[1]);
                        String payloadStr = utf8.decode(base64Url.decode(normalized));
                        Map<String, dynamic> payload = jsonDecode(payloadStr);
                        if (payload.containsKey('user_id')) {
                          myId = (payload['user_id'] as num).toInt();
                        }
                        if (payload.containsKey('role')) {
                          userRole = payload['role'].toString();
                        }
                      } catch (_) {}
                    }
                  }
                  
                  // Evita que los aspirantes interactúen con la red social por políticas
                  if (userRole == 'aspirante') return;

                  if (context.mounted) {
                    if (myId != null && myId == widget.video.authorId) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Scaffold(body: ProfileScreen(onLogout: GlobalUIService.forceLogout)),
                        ),
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PublicProfileScreen(authorId: widget.video.authorId),
                        ),
                      );
                    }
                  }
                },
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                      Text(
                        widget.video.authorName.isNotEmpty ? widget.video.authorName : 'Usuario',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF003399),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text('Seguir',
                            style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (widget.video.title.isNotEmpty && widget.video.title != 'Video' && widget.video.title != 'Imagen' && widget.video.title != 'Encuesta' && widget.video.title != 'Flashcard')
                    Text(
                      widget.video.title,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (widget.video.description.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      widget.video.description,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
        ),
      ],
    );
  }

  Widget _actionButton({
    required IconData icon,
    required Color color,
    required String text,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 32),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(text,
                style: const TextStyle(color: Colors.white, fontSize: 12)),
          ],
        ],
      ),
    );
  }
}
