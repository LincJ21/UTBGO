/// [ProfileModel] representa la estructura del perfil de usuario en la app Flutter.
class ProfileModel {
  final String id;
  final String username;
  final String avatarUrl;
  final String role;

  ProfileModel({
    required this.id,
    required this.username,
    required this.avatarUrl,
    required this.role,
  });

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: (json['id'] ?? '').toString(),
      username: json['username'] ?? 'Sin nombre',
      avatarUrl: json['avatar_url'] ?? json['avatarUrl'] ?? '',
      role: json['role'] ?? 'estudiante',
    );
  }

  /// Indica si el usuario puede subir videos (profesor, moderador o admin).
  bool get canUploadVideos => role != 'estudiante';
}
