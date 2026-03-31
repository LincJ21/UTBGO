import 'package:flutter/material.dart';
import 'video_model.dart';
import 'video_player_widget.dart';
import 'widgets/feed_flashcard_widget.dart';
import 'widgets/feed_poll_widget.dart';

/// Pantalla autónoma para reproducir un único contenido (video, flashcard o encuesta).
/// Se usa principalmente al navegar desde los resultados de búsqueda o explorar.
class SingleVideoScreen extends StatelessWidget {
  final VideoModel video;

  const SingleVideoScreen({super.key, required this.video});

  Widget _buildContent() {
    if (video.contentType == 'flashcard') {
      return FeedFlashcardWidget(
        video: video,
        onVisibilityChanged: (_) {},
      );
    } else if (video.contentType == 'encuesta') {
      return FeedPollWidget(
        video: video,
        onVisibilityChanged: (_) {},
      );
    } else {
      return VideoPlayerWidget(
        video: video,
        onVisibilityChanged: (_) {},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para la reproducción
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white, shadows: [
          Shadow(
            color: Colors.black87,
            offset: Offset(1, 1),
            blurRadius: 3,
          )
        ]),
      ),
      body: _buildContent(),
    );
  }
}
