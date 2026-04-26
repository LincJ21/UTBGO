/// [ProfileModel] representa la estructura del perfil de usuario en la app Flutter.
class ProfileModel {
  final String id;
  final String username;
  final String avatarUrl;
  final String role;
  final String? bio;
  final String? faculty;
  final String? cvlacUrl;
  final String? websiteUrl;
  final int followers;
  final int totalLikes;
  final int totalViews;
  final int totalVideos;

  ProfileModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.role,
    this.bio,
    this.faculty,
    this.cvlacUrl,
    this.websiteUrl,
    this.followers = 0,
    this.totalLikes = 0,
    this.totalViews = 0,
    this.totalVideos = 0,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: (json['id'] ?? '').toString(),
      username: json['username'] ?? 'Sin nombre',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'] ?? '',
      role: json['role'] ?? 'estudiante',
      bio: json['bio'],
      faculty: json['faculty'],
      cvlacUrl: json['cvlac_url'],
      websiteUrl: json['website_url'],
      followers: json['followers'] ?? 0,
      totalLikes: json['total_likes'] ?? 0,
      totalViews: json['total_views'] ?? 0,
      totalVideos: json['total_videos'] ?? 0,
    );
  }

  /// Indica si el usuario puede subir videos (profesor, moderador o admin).
  bool get canUploadVideos => role == 'profesor' || role == 'admin' || role == 'moderador';
}
