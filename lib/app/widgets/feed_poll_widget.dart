import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../video_model.dart';
import '../config/app_config.dart';
import '../config/api_client.dart';
import '../comments_bottom_sheet.dart';

class FeedPollWidget extends StatefulWidget {
  final VideoModel video;
  final Function(bool)? onVisibilityChanged;

  const FeedPollWidget({
    super.key,
    required this.video,
    this.onVisibilityChanged,
  });

  @override
  State<FeedPollWidget> createState() => _FeedPollWidgetState();
}

class _FeedPollWidgetState extends State<FeedPollWidget> {
  final _apiClient = ApiClient();
  bool _isLoading = true;
  String _question = '';
  List<dynamic> _options = [];
  bool _hasVoted = false;
  int _totalVotes = 0;

  @override
  void initState() {
    super.initState();
    _fetchPollDetails();
  }

  Future<void> _fetchPollDetails() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.pollsEndpoint}/${widget.video.id}',
        requiresAuth: true, // Para obtener el estado has_voted del usuario actual
        fromJson: (json) => json,
      );

      if (response.isSuccess && response.data != null && mounted) {
        setState(() {
          _question = response.data!['question'] ?? '';
          _options = response.data!['options'] ?? [];
          _hasVoted = response.data!['has_voted'] ?? false;
          _totalVotes = response.data!['total_votes'] ?? 0;
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint('Error loading poll: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _vote(int optionId) async {
    if (_hasVoted) return;

    final response = await _apiClient.post(
      AppConfig.pollVoteUrl(widget.video.id),
      requiresAuth: true,
      body: {'option_id': optionId},
    );

    if (response.isSuccess && mounted) {
      // Recargar detalles localmente o volver a pedir
      _fetchPollDetails();
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response.error?.message ?? 'Error al votar')),
        );
      }
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
        'Participa en esta encuesta de UTBGO: ${widget.video.title}\n${widget.video.description}\nhttps://utbgo.app/content/${widget.video.id}';
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
          // Layout Central Encuesta
          Center(
            child: _isLoading
                ? const CircularProgressIndicator(color: Colors.white)
                : Container(
                    width: MediaQuery.of(context).size.width * 0.88,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF0F172A).withValues(alpha: 0.95), // Slate 900
                          const Color(0xFF1E293B).withValues(alpha: 0.95), // Slate 800
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.tealAccent.withValues(alpha: 0.05),
                          blurRadius: 30,
                          spreadRadius: -5,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _question,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            shadows: [
                              Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 2))
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                        ..._options.map((opt) => _buildOptionRow(opt)),
                        if (_hasVoted) ...[
                          const SizedBox(height: 20),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '$_totalVotes votos totales',
                              style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ),
                        ]
                      ],
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
                    color: Colors.orangeAccent.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Encuesta', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
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

  Widget _buildOptionRow(dynamic opt) {
    int votes = opt['votes'] ?? 0;
    double percentage = _totalVotes > 0 ? votes / _totalVotes : 0;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: () {
          if (!_hasVoted) _vote(opt['id']);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          height: 56,
          decoration: BoxDecoration(
            color: _hasVoted ? Colors.white.withValues(alpha: 0.03) : Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hasVoted ? Colors.white.withValues(alpha: 0.05) : Colors.white.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              if (_hasVoted)
                AnimatedFractionallySizedBox(
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.fastOutSlowIn,
                  widthFactor: percentage,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF38BDF8), Color(0xFF3B82F6)], // Light Blue to Blue
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          opt['text'],
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: _hasVoted ? FontWeight.w600 : FontWeight.w500,
                            fontSize: 15,
                            shadows: const [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (_hasVoted)
                        Container(
                          padding: const EdgeInsets.only(left: 12),
                          child: Text(
                            '${(percentage * 100).toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              shadows: [Shadow(color: Colors.black45, blurRadius: 2, offset: Offset(0, 1))],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
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
