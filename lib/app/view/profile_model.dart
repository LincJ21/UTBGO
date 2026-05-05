/// [ProfileModel] representa la estructura del perfil de usuario en la app Flutter.
class ProfileModel {
  final String id;
  final String username;
  final String avatarUrl;
  final String role;

  ProfileModel({required this.id, required this.username, required this.avatarUrl, required this.role});

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    // Constructor para crear un [ProfileModel] desde un JSON.
    return ProfileModel(
      id: json['id']?.toString() ?? '',
      username: json['username']?.toString() ?? 'Sin nombre',
      avatarUrl: json['avatarUrl']?.toString() ?? '',
      role: json['role']?.toString() ?? 'estudiante',
    );
  }
}
