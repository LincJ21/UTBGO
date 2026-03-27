import 'config/app_config.dart';
import 'config/api_client.dart';

/// Modelo de notificación del backend.
class BackendNotification {
  final int id;
  final int userId;
  final String type;
  final String title;
  final String body;
  final String actorName;
  final int refId;
  final bool isRead;
  final DateTime createdAt;

  BackendNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    required this.actorName,
    required this.refId,
    required this.isRead,
    required this.createdAt,
  });

  factory BackendNotification.fromJson(Map<String, dynamic> json) {
    return BackendNotification(
      id: json['id'] ?? 0,
      userId: json['user_id'] ?? 0,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      actorName: json['actor_name'] ?? '',
      refId: json['ref_id'] ?? 0,
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.tryParse(json['created_at'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Servicio para conectar con los endpoints de notificaciones del backend.
class NotificationApiService {
  final ApiClient _api = ApiClient();
  final String _baseUrl = '${AppConfig.backendBaseUrl}/api/v1/notifications';

  /// Obtiene las notificaciones del usuario autenticado.
  Future<ApiResponse<List<BackendNotification>>> getNotifications({int page = 1, int pageSize = 20}) async {
    return _api.get<List<BackendNotification>>(
      '$_baseUrl?page=$page&page_size=$pageSize',
      requiresAuth: true,
      fromJson: (json) {
        final list = json['data'] as List? ?? [];
        return list.map((e) => BackendNotification.fromJson(e)).toList();
      },
    );
  }

  /// Obtiene el contador de notificaciones no leídas.
  Future<ApiResponse<int>> getUnreadCount() async {
    return _api.get<int>(
      '$_baseUrl/unread-count',
      requiresAuth: true,
      fromJson: (json) => json['data']?['unread_count'] ?? 0,
    );
  }

  /// Marca una notificación como leída.
  Future<ApiResponse<void>> markAsRead(int id) async {
    return _api.patch<void>(
      '$_baseUrl/$id/read',
      requiresAuth: true,
      body: {},
      fromJson: (_) {},
    );
  }

  /// Marca todas las notificaciones como leídas.
  Future<ApiResponse<void>> markAllAsRead() async {
    return _api.patch<void>(
      '$_baseUrl/read-all',
      requiresAuth: true,
      body: {},
      fromJson: (_) {},
    );
  }
}
