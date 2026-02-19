/// [VideoModel] representa la estructura de un video dentro de la app Flutter.
class VideoModel {
  final String id;
  final String title;
  final String videoUrl;
  final String thumbnailUrl;
  final String description;
  final String contentType; // Nuevo campo para distinguir entre 'video' y 'flashcard'
  final List<Map<String, dynamic>>? flashcards; // Datos de las flashcards
  final List<Map<String, dynamic>>? pollOptions; // Datos de la encuesta
  // Convertimos a 'var' para poder modificarlos
  var likes;
  var comments;
  var isLiked;
  var isBookmarked;
  var hasVotedOnPoll; // Estado local para saber si ya votó

  VideoModel({
    required this.id,
    required this.title,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.description,
    this.contentType = 'video', // Valor por defecto
    this.flashcards,
    this.pollOptions,
    // Valores iniciales
    required this.likes,
    required this.comments,
    this.isLiked = false,
    this.isBookmarked = false,
    this.hasVotedOnPoll = false,
  });

  /// Simulación de base de datos local para publicaciones nuevas
  static List<VideoModel> localFeed = [];

  /// Constructor para crear un [VideoModel] desde un JSON (usado por el backend de Go).
  factory VideoModel.fromJson(Map<String, dynamic> json) {
    return VideoModel(
      id: json['id'] ?? '',
      title: json['title'] ?? 'Sin Título',
      videoUrl: json['videoUrl'] ?? '',
      thumbnailUrl: json['thumbnail_url'] ?? '',
      description: json['description'] ?? '',
      contentType: json['content_type'] ?? 'video',
      flashcards: json['flashcards'] != null ? List<Map<String, dynamic>>.from(json['flashcards']) : null,
      pollOptions: json['poll_options'] != null ? List<Map<String, dynamic>>.from(json['poll_options']) : null,
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
      isLiked: json['isLiked'] ?? false, // El backend nos diría esto
      isBookmarked: json['isBookmarked'] ?? false, // Y esto también
      hasVotedOnPoll: json['hasVotedOnPoll'] ?? false,
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
      contentType: json['content_type'] ?? 'video',
      flashcards: json['flashcards'] != null ? List<Map<String, dynamic>>.from(json['flashcards']) : null,
      pollOptions: json['poll_options'] != null ? List<Map<String, dynamic>>.from(json['poll_options']) : null,
      // En un caso real, estos valores vendrían de nuestra API de Go.
      // Por ahora, los simulamos si no vienen.
      likes: json['likes'] ?? 0,
      comments: json['comments'] ?? 0,
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

    return VideoModel(
      id: (json['id'] ?? 0).toString(),
      title: 'Video por ${json['user']?['name'] ?? 'Desconocido'}',
      videoUrl: url,
      thumbnailUrl: json['image'] ?? '', // Pexels usa 'image' para la miniatura
      description: 'Video por ${json['user']?['name'] ?? 'Desconocido'}',
      contentType: 'video', // Pexels solo devuelve videos
      // En un caso real, estos valores vendrían de nuestra API de Go.
      likes: (json['id'] % 5000) + 100,
      comments: (json['id'] % 800) + 50,
      isLiked: false, // Por defecto, no le ha gustado
      isBookmarked: false, // Por defecto, no está guardado
    );
  }
}
