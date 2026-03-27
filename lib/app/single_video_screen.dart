import 'package:flutter/material.dart';
import 'video_model.dart';
import 'video_player_widget.dart';

/// Pantalla autónoma para reproducir un único video.
/// Se usa principalmente al navegar desde los resultados de búsqueda.
class SingleVideoScreen extends StatelessWidget {
  final VideoModel video;

  const SingleVideoScreen({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black, // Fondo negro para la reproducción de video
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
      body: VideoPlayerWidget(
        video: video,
        // Al estar en una pantalla suelta, no nos importa alterar el bottom bar padre
        onVisibilityChanged: (isVisible) {}, 
      ),
    );
  }
}
