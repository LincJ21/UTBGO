import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'video_model.dart';
import 'search_results_screen.dart';
import 'comments_bottom_sheet.dart';
import 'notifications_screen.dart';
import 'config/app_config.dart';

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
  late VideoPlayerController _controller;
  final _storage = const FlutterSecureStorage();
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showControls = true;

  Future<void> _toggleLike() async {
    final wasLiked = widget.video.isLiked;
    final prevLikes = widget.video.likes;

    setState(() {
      widget.video.isLiked = !widget.video.isLiked;
      widget.video.isLiked ? widget.video.likes++ : widget.video.likes--;
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      await http.post(
        Uri.parse(AppConfig.videoLikeUrl(widget.video.id)),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          widget.video.isLiked = wasLiked;
          widget.video.likes = prevLikes;
        });
      }
    }
  }

  Future<void> _toggleBookmark() async {
    final wasBookmarked = widget.video.isBookmarked;
    setState(() => widget.video.isBookmarked = !widget.video.isBookmarked);

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;
      await http.post(
        Uri.parse(AppConfig.videoBookmarkUrl(widget.video.id)),
        headers: {'Authorization': 'Bearer $token'},
      );
    } catch (e) {
      if (mounted) setState(() => widget.video.isBookmarked = wasBookmarked);
    }
  }

  void _shareVideo() {
    ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Función de compartir no implementada')));
  }

  Future<void> _performSearch() async {
    final query = _searchController.text;
    if (query.isEmpty) return;
    FocusScope.of(context).unfocus();

    final Uri uri = Uri.parse(AppConfig.videosSearchEndpoint)
        .replace(queryParameters: {'q': query});

    try {
      final response = await http
          .get(uri)
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = json.decode(response.body);
        final List<dynamic> videoJson = (data['videos'] as List<dynamic>?) ?? [];
        final searchResults =
            videoJson.map((json) => VideoModel.fromBackendJson(json)).toList();

        if (!mounted) return;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SearchResultsScreen(
                searchResults: searchResults, query: query),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al realizar la búsqueda.')));
      }
    }
    setState(() => _isSearching = false);
  }

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    _controller.initialize().then((_) {
      setState(() {});
      _controller.play();
      _controller.setLooping(true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? Stack(
            alignment: Alignment.center,
            children: [
              // Video a pantalla completa
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showControls = !_showControls;
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
                      Center(
                        child: GestureDetector(
                          onTap: () => setState(() {
                            _controller.value.isPlaying
                                ? _controller.pause()
                                : _controller.play();
                          }),
                          child: AnimatedOpacity(
                            opacity: _controller.value.isPlaying ? 0.0 : 1.0,
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
                              text: '152', // Valor de ejemplo
                              onTap: () {
                                showCommentsBottomSheet(context, videoId: widget.video.id);
                              },
                            ),
                            const SizedBox(height: 16),
                            _actionButton(
                              icon: widget.video.isBookmarked
                                  ? Icons.bookmark
                                  : Icons.bookmark_border,
                              color: Colors.white,
                              text: '20',
                              onTap: _toggleBookmark,
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

                      // Info del profesor abajo
                      Positioned(
                        left: 12,
                        right: 80,
                        bottom: 50,
                        child: _buildAuthorInfo(),
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
            Text(
              widget.video.title.isNotEmpty ? widget.video.title : 'Profesor',
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15),
            ),
            const SizedBox(width: 10),
            // Botón Seguir
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFF003399),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Text('Seguir',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // Descripción del video
        if (widget.video.description.isNotEmpty)
          Text(
            widget.video.description,
            style: const TextStyle(color: Colors.white70, fontSize: 13),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
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
