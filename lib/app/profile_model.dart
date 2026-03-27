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

  ProfileModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.role,
    this.bio,
    this.faculty,
    this.cvlacUrl,
    this.websiteUrl,
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
    );
  }

  /// Indica si el usuario puede subir videos (profesor, moderador o admin).
  bool get canUploadVideos => role == 'profesor' || role == 'admin' || role == 'moderador';
}
