import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import './video_model.dart';
import './video_player_widget.dart';
import './flashcard_widget.dart';
import './poll_widget.dart';
import './api_constants.dart';
import 'image_post_widget.dart';

/// [FeedItem] rediseñado para ocupar toda la pantalla (Reels style)
class FeedItem extends StatefulWidget {
  final VideoModel video;
  final PageController? pageController;
  final int? index;
  final int currentIndex; // Nuevo parámetro para saber si es el video activo

  const FeedItem({
    super.key,
    required this.video,
    this.pageController,
    this.index,
    this.currentIndex = 0,
  });

  @override
  State<FeedItem> createState() => _FeedItemState();
}

class _FeedItemState extends State<FeedItem> {
  static const String _baseUrl = ApiConstants.baseUrl;
  bool _isBookmarked = false;
  late int _likes;
  late bool _isLiked;
  bool _isFollowing = false;
  bool _isExpanded = false; // Nuevo estado para controlar la expansión

  @override
  void initState() {
    super.initState();
    // Inicializamos el estado local con los datos del modelo
    _isBookmarked = widget.video.isBookmarked ?? false;
    _isLiked = widget.video.isLiked ?? false;
    _likes = widget.video.likes ?? 0;
  }

  Future<void> _toggleLike() async {
    setState(() {
      _isLiked = !_isLiked;
      _isLiked ? _likes++ : _likes--;
      widget.video.isLiked = _isLiked;
      widget.video.likes = _likes;
    });
    // Llamada API simulada
    try {
      await http
          .post(Uri.parse('$_baseUrl/api/videos/${widget.video.id}/like'));
    } catch (e) {
      debugPrint('Error giving like: $e');
    }
  }

  void _toggleBookmark() {
    setState(() {
      _isBookmarked = !_isBookmarked;
      widget.video.isBookmarked = _isBookmarked;
    });
  }

  void _showFullDescription() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isVideo = widget.video.contentType == 'video';
    final double screenHeight = MediaQuery.of(context).size.height;
    // Altura que ocupará la descripción al expandirse
    final double expandedHeight = screenHeight * 0.35;

    const Color textColor = Colors.white;
    const Color subTextColor = Colors.white70;
    const Color iconColor = Colors.white;
    const List<Shadow> iconShadows = [Shadow(color: Colors.black26, blurRadius: 4, offset: Offset(0, 1))];

    // Construimos la sección inferior (Información)
    Widget bottomInfo = Container(
      width: double.infinity,
      decoration: _isExpanded
          ? const BoxDecoration(
              color: Color(0xFF212121),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, -2))],
            )
          : (isVideo
              ? const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black54],
                    stops: [0.0, 1.0],
                  ),
                )
              : null),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: _isExpanded ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (_isExpanded) ...[
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white38,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Descripción", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: _showFullDescription,
                ),
              ],
            ),
            const Divider(color: Colors.white24, height: 20),
          ],
          Row(
            children: [
              const CircleAvatar(
                radius: 16,
                backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'), // Placeholder
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        "Profesor 1 ",
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () {
                          setState(() {
                            _isFollowing = !_isFollowing;
                          });
                        },
                        child: _isFollowing
                            ? Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: const Color.fromARGB(255, 11, 54, 146), width: 1.5),
                                  color: Colors.white,
                                ),
                                child: const Icon(Icons.check, size: 16, color: Color.fromARGB(255, 11, 54, 146)),
                              )
                            : Container(
                                height: 24,
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color.fromRGBO(0, 26, 63, 1),
                                      Color.fromARGB(255, 92, 153, 200),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(1.7),
                                  padding: const EdgeInsets.symmetric(horizontal: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  alignment: Alignment.center,
                                  child: ShaderMask(
                                    shaderCallback: (bounds) => const LinearGradient(
                                      colors: [
                                        Color.fromRGBO(0, 26, 63, 1),
                                        Color.fromARGB(255, 35, 95, 142),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ).createShader(bounds),
                                    child: const Text(
                                      "Seguir",
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                  const Text(
                    "hace 2 horas",
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isExpanded)
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.video.title,
                      style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text("${widget.video.likes} Me gusta", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 16),
                        Text("${widget.video.comments} visualizaciones", style: const TextStyle(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 16),
                        const Text("2024", style: TextStyle(color: Colors.white70, fontSize: 12)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.video.description,
                      style: const TextStyle(color: textColor, fontSize: 15, height: 1.4),
                    ),
                    const SizedBox(height: 20),
                    Wrap(
                      spacing: 8,
                      children: ["#educación", "#utb", "#aprender", "#viral"].map((t) => Text(t, style: const TextStyle(color: Colors.blue))).toList(),
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            )
          else
            SizedBox(
              width: MediaQuery.of(context).size.width * 0.65,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  const descriptionStyle = TextStyle(color: textColor, fontSize: 15);
                  final span = TextSpan(text: widget.video.description, style: descriptionStyle);
                  final tp = TextPainter(
                    text: span,
                    maxLines: 2,
                    textAlign: TextAlign.start,
                    textDirection: TextDirection.ltr,
                    textScaler: MediaQuery.of(context).textScaler,
                  );
                  tp.layout(maxWidth: constraints.maxWidth);

                  if (tp.didExceedMaxLines) {
                    return Stack(
                      children: [
                        Text(
                          widget.video.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: descriptionStyle,
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: GestureDetector(
                            onTap: _showFullDescription,
                            child: Container(
                              color: Colors.transparent,
                              padding: const EdgeInsets.only(left: 4),
                              child: const Text(
                                "...más",
                                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14, shadows: iconShadows),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Text(widget.video.description, style: descriptionStyle);
                  }
                },
              ),
            ),
          const SizedBox(height: 4),
        ],
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          top: 0,
          left: 0,
          right: 0,
          bottom: _isExpanded ? expandedHeight : 0,
          child: Container(
            color: Colors.black,
            child: _buildContent(),
          ),
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          left: 0,
          right: 0,
          bottom: 0,
          height: _isExpanded ? expandedHeight : null,
          child: bottomInfo,
        ),
        AnimatedPositioned(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          right: 10,
          bottom: _isExpanded ? expandedHeight + 20 : 20,
          child: AnimatedOpacity(
            opacity: _isExpanded ? 0.0 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(
              ignoring: _isExpanded,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildInteractionButton(
                    icon: _isLiked ? Icons.favorite : Icons.favorite_border,
                    label: '$_likes',
                    color: _isLiked ? const Color.fromARGB(255, 65, 206, 43) : iconColor,
                    shadows: iconShadows,
                    onTap: _toggleLike,
                  ),
                  const SizedBox(height: 20),
                  _buildInteractionButton(
                    icon: Icons.mode_comment_outlined,
                    label: '${widget.video.comments}',
                    color: iconColor,
                    shadows: iconShadows,
                    onTap: () {},
                  ),
                  const SizedBox(height: 20),
                  _buildInteractionButton(
                    icon: Icons.share,
                    color: iconColor,
                    shadows: iconShadows,
                    onTap: () {},
                  ),
                  const SizedBox(height: 20),
                  _buildInteractionButton(
                    icon: _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                    color: _isBookmarked ? const Color(0xFF30CB38) : iconColor,
                    shadows: iconShadows,
                    onTap: _toggleBookmark,
                  ),
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    String? label,
    required VoidCallback onTap,
    required Color color,
    required List<Shadow> shadows,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
       children: [
          Icon(
            icon,
            size: 35, 
            color: color,
            shadows: shadows,
          ),
          const SizedBox(height: 4),
          if (label != null && label.isNotEmpty)
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
                shadows: shadows,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (widget.video.contentType == 'video') {
      // Solo reproducimos si es el índice actual para ahorrar memoria
      final bool isPlaying = widget.index == widget.currentIndex;

      if (isPlaying) {
        return VideoPlayerWidget(
          key: Key(widget.video.id),
          video: widget.video,
          isFullScreen: true,
          fit: _isExpanded ? BoxFit.contain : BoxFit.cover,
        );
      } else {
        return ImagePostWidget(url: widget.video.thumbnailUrl);
      }
    } else if (widget.video.contentType == 'flashcard') {
      return Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final double width = constraints.maxWidth * 1.8;
            final double height = width / 1.6;
            return SizedBox(
              width: width,
              height: height,
              child: _buildSpecificContent(),
            );
          },
        ),
      );
    } else if (widget.video.contentType == 'image') {
      return Align(
        alignment: Alignment.topCenter,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return Padding(
              padding: const EdgeInsets.only(top: 85.0),
              child: SizedBox(
                width: constraints.maxWidth * 1.0,
                height: constraints.maxHeight * 0.8,
                child: Container(
                  color: Colors.black,
                  child: _buildSpecificContent(),
                ),
              ),
            );
          },
        ),
      );
    } else {
      return Center(
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.black,
            ),
            clipBehavior: Clip.antiAlias,
            child: _buildSpecificContent(),
          ),
        ),
      );
    }
  }

  Widget _buildSpecificContent() {
    switch (widget.video.contentType) {
      case 'flashcard':
        return FlashcardWidget(
          content: widget.video,
        );
      case 'poll':
        return Container(
          color: Colors.white,
          child: PollWidget(video: widget.video),
        );
      case 'image':
        return ImagePostWidget(url: widget.video.videoUrl);
      case 'video':
      default:
        return const SizedBox();
    }
  }
}