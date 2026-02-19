import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'video_model.dart';

class VideoPlayerWidget extends StatefulWidget {
  /// El modelo de datos completo del video.
  final VideoModel video;
  final VoidCallback? onExpand;
  final bool isFullScreen;
  final BoxFit fit;

  const VideoPlayerWidget({
    super.key,
    required this.video,
    this.onExpand,
    this.isFullScreen = false,
    this.fit = BoxFit.cover,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  /// [_controller] es el controlador principal para el reproductor de video.
  late VideoPlayerController _controller;

  @override
  void initState() {
    super.initState();
    // Decide qué tipo de controlador usar basado en si el video es de red o local.
    if (widget.video.videoUrl.startsWith('http')) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.video.videoUrl));
    } else if (widget.video.videoUrl.startsWith('assets/')) {
      _controller = VideoPlayerController.asset(widget.video.videoUrl);
    } else {
      _controller = VideoPlayerController.file(File(widget.video.videoUrl));
    }

    // --- OPTIMIZACIÓN DE RENDIMIENTO ---
    // Retrasamos la inicialización del video (300ms) para que la UI (descripción, perfil)
    // se renderice inmediatamente y evitar bloqueos (jank) al hacer scroll rápido.
    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      _controller.initialize().then((_) {
        if (!mounted) return;
        setState(() {});
        _controller.play();
        _controller.setLooping(true);
      });
    });
  }

  @override
  void dispose() {
    // Libera los recursos del controlador cuando el widget es destruido.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Si el controlador no se ha inicializado, muestra un loader.
    if (_controller.value.isInitialized) {
      return GestureDetector(
            onTap: () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause() : _controller.play();
              });
            },
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: FittedBox(
                    fit: widget.fit,
                    child: SizedBox(
                      width: _controller.value.size.width,
                      height: _controller.value.size.height,
                      child: VideoPlayer(_controller),
                    ),
                  ),
                ),
                // Icono de Play animado al pausar
                if (!_controller.value.isPlaying)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withOpacity(0.5),
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 60, color: Colors.white),
                  ),

                // Botón de Expandir (Solo si no es pantalla completa)
                if (!widget.isFullScreen && widget.onExpand != null)
                  Positioned(
                    bottom: 12,
                    right: 12,
                    child: GestureDetector(
                      onTap: widget.onExpand,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.fullscreen, color: Colors.white, size: 24),
                      ),
                    ),
                  ),
              ],
            ),
          );
    } else {
      // --- ESTADO DE CARGA (Thumbnail) ---
      // Mostramos la miniatura inmediatamente. Esto hace que la descripción y el resto
      // de la UI aparezcan al instante, dando sensación de velocidad.
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.video.thumbnailUrl.isNotEmpty)
            Image.network(
             widget.video.thumbnailUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(color: Colors.black),
            ),
          const Center(child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
        ],
      );
    }
  }
}
