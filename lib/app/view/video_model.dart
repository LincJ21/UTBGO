import 'dart:convert';

/// [VideoModel] representa la estructura de un video dentro de la app Flutter.
class VideoModel {
  final String id;
  final String videoUrl;
  final String description;
  // Convertimos a 'var' para poder modificarlos
  var likes;
  var comments;
  var isLiked;
  var isBookmarked;

  VideoModel({
    required this.id,
    required this.videoUrl,
    required this.description,
    // Valores iniciales
    required this.likes,
    required this.comments,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  /// Constructor para crear un [VideoModel] desde un JSON (usado por el backend de Go).
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] ?? '',
      videoUrl: json['videoUrl'] ?? '',
      description: json['description'] ?? '',
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      isLiked: json['isLiked'] ?? false, // El backend nos diría esto
      isBookmarked: json['isBookmarked'] ?? false, // Y esto también
    );
  }

  /// Constructor para crear un [VideoModel] desde el JSON específico de la API de Pexels.
  factory VideoModel.fromPexelsJson(Map<String, dynamic> json) {
    final List<dynamic> videoFiles = json['video_files'] ?? [];
    String url = '';
    // Buscamos un video de calidad decente pero no excesiva
    final sdVideo = videoFiles.firstWhere((file) => file['quality'] == 'sd', orElse: () => null);
    if (sdVideo != null) {
      url = sdVideo['link'] ?? '';
    } else if (videoFiles.isNotEmpty) {
      url = videoFiles.first['link'] ?? ''; // Fallback al primer video disponible
    }

    return VideoModel(
      id: (json['id'] ?? 0).toString(),
      videoUrl: url,
      description: 'Video por ${json['user']?['name'] ?? 'Desconocido'}',
      // En un caso real, estos valores vendrían de nuestra API de Go.
      likes: (json['id'] % 5000) + 100,
      comments: (json['id'] % 800) + 50,
      isLiked: false, // Por defecto, no le ha gustado
      isBookmarked: false, // Por defecto, no está guardado
    );
  }
}
