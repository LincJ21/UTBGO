/// [VideoModel] representa la estructura de un video dentro de la app Flutter.
class VideoModel {
  final String id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String description;
  final String authorName;
  final String contentType;
  final DateTime createdAt;
  int likes;
  int comments;
  int views;
  bool isLiked;
  bool isBookmarked;

  VideoModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.description,
    this.authorName = 'Profesor UTB',
    this.contentType = 'video',
    required this.createdAt,
    // Valores iniciales
    required this.likes,
    required this.comments,
    this.views = 0,
    this.isLiked = false,
    this.isBookmarked = false,
  });

  /// Convierte la instancia a un mapa JSON para almacenamiento local o caché.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'videoUrl': videoUrl,
      'thumbnail_url': thumbnailUrl,
      'description': description,
      'author_name': authorName,
      'content_type': contentType,
      'created_at': createdAt.toIso8601String(),
      'likes': likes,
      'comments': comments,
      'views': views,
      'isLiked': isLiked,
      'isBookmarked': isBookmarked,
    };
  }

  /// Constructor para crear un [VideoModel] desde un JSON (usado por el backend de Go).
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? 'Sin Título',
      videoUrl: json['video_url'] ?? json['videoUrl'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      description: json['description'] ?? '',
      authorName: json['author_name'] ?? 'Profesor UTB',
      contentType: json['content_type'] ?? 'video',
      createdAt: json['created_at'] != null 
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      views: json['views'] ?? 0,
      isLiked: json['isLiked'] ?? false,
      isBookmarked: json['isBookmarked'] ?? false,
    );
  }

  /// Constructor para crear un [VideoModel] desde el JSON que envía nuestro backend de Go.
  factory VideoModel.fromBackendJson(Map<String, dynamic> json) {
    return VideoModel(
      id: (json['id'] ?? 0).toString(),
      title: json['title'] ?? 'Sin Título',
      videoUrl: json['video_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      description: json['description'] ?? 'Sin descripción',
      authorName: json['author_name'] ?? 'Profesor UTB',
      contentType: json['content_type'] ?? 'video',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']) ?? DateTime.now()
          : DateTime.now(),
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      views: json['views'] ?? 0,
      isLiked: json['is_liked'] ?? false,
      isBookmarked: json['is_bookmarked'] ?? false,
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

    final author = json['user']?['name'] ?? 'Desconocido';

    return VideoModel(
      id: (json['id'] ?? 0).toString(),
      title: 'Video por $author',
      videoUrl: url,
      thumbnailUrl: json['image'] ?? '',
      description: 'Video por $author',
      authorName: author,
      createdAt: DateTime.now(),
      likes: (json['id'] % 5000) + 100,
      comments: (json['id'] % 800) + 50,
      isLiked: false,
      isBookmarked: false,
    );
  }
}
 