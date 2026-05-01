import 'package:flutter/material.dart';
import '../video_model.dart';
import '../config/app_config.dart';
import '../config/api_client.dart';
import '../comments_bottom_sheet.dart';
import 'package:share_plus/share_plus.dart';

class FeedFlashcardWidget extends StatefulWidget {
  final VideoModel video;
  final Function(bool)? onVisibilityChanged;

  const FeedFlashcardWidget({
    super.key,
    required this.video,
    this.onVisibilityChanged,
  });

  @override
  State<FeedFlashcardWidget> createState() => _FeedFlashcardWidgetState();
}

class _FeedFlashcardWidgetState extends State<FeedFlashcardWidget> {
  final _apiClient = ApiClient();
  bool _isLoading = true;
  bool _isFlipped = false;
  String _frontText = '';
  String _backText = '';

  @override
  void initState() {
    super.initState();
    _fetchFlashcardDetails();
  }

  Future<void> _fetchFlashcardDetails() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.flashcardsEndpoint}/${widget.video.id}',
        requiresAuth: false,
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null && mounted) {
        setState(() {
          _frontText = response.data!['front_text'] ?? '';
          _backText = response.data!['back_text'] ?? '';
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading flashcard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _toggleLike() async {
    setState(() {
      widget.video.isLiked = !widget.video.isLiked;
      widget.video.likes += widget.video.isLiked ? 1 : -1;
    });

    final response = await _apiClient.post(
      AppConfig.videoLikeUrl(widget.video.id),
      requiresAuth: true,
    );

    if (!response.isSuccess && mounted) {
      setState(() {
        widget.video.isLiked = !widget.video.isLiked;
        widget.video.likes += widget.video.isLiked ? 1 : -1;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.error?.message ?? 'Error al dar like')),
      );
    }
  }

  void _toggleBookmark() async {
    setState(() {
      widget.video.isBookmarked = !widget.video.isBookmarked;
    });

    final response = await _apiClient.post(
      AppConfig.videoBookmarkUrl(widget.video.id),
      requiresAuth: true,
    );

    if (!response.isSuccess && mounted) {
      setState(() {
        widget.video.isBookmarked = !widget.video.isBookmarked;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(response.error?.message ?? 'Error al guardar')),
      );
    }
  }

  void _shareContent() {
    final String shareText =
        'Mira esta flashcard en UTBGO: ${widget.video.title}\n${widget.video.description}\nhttps://utbgo.app/content/${widget.video.id}';
    Share.share(shareText);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Color(0xFF0F172A), // Slate 900
            Color(0xFF001F60), // UTB Dark Blue
            Color(0xFF0F172A),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Flashcard Central
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : GestureDetector(
                    onTap: () => setState(() => _isFlipped = !_isFlipped),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 400),
                      transitionBuilder: (Widget child, Animation<double> animation) {
                        return FadeTransition(opacity: animation, child: child);
                      },
                      child: Container(
                        key: ValueKey<bool>(_isFlipped),
                        width: MediaQuery.of(context).size.width * 0.85,
                        height: MediaQuery.of(context).size.height * 0.5,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: _isFlipped ? Colors.green[800] : Colors.blueGrey[800],
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 5))
                          ],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _isFlipped ? _backText : _frontText,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
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
                  icon: widget.video.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: widget.video.isLiked ? const Color(0xFF4CAF50) : Colors.white,
                  text: widget.video.likes.toString(),
                  onTap: _toggleLike,
                ),
                const SizedBox(height: 16),
                _actionButton(
                  icon: Icons.comment,
                  color: Colors.white,
                  text: widget.video.comments.toString(),
                  onTap: () {
                    showCommentsBottomSheet(context, videoId: widget.video.id);
                  },
                ),
                const SizedBox(height: 16),
                _actionButton(
                  icon: widget.video.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  color: Colors.white,
                  text: '',
                  onTap: _toggleBookmark,
                ),
                const SizedBox(height: 16),
                _actionButton(
                  icon: Icons.share,
                  color: Colors.white,
                  text: '',
                  onTap: _shareContent,
                ),
              ],
            ),
          ),

          // Info del contenido abajo
          Positioned(
            left: 12,
            right: 80,
            bottom: 50,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Flashcard', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.title,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.video.description,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionButton({required IconData icon, required Color color, required String text, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: color, size: 36),
          if (text.isNotEmpty) const SizedBox(height: 4),
          if (text.isNotEmpty)
            Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
