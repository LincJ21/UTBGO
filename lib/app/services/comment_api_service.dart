import '../config/api_client.dart';
import '../config/app_config.dart';

class CommentApiService {
  static final ApiClient _apiClient = ApiClient();

  /// Obtiene los comentarios de un video
  Future<ApiResponse<List<dynamic>>> getComments(String videoId, {int page = 1, int limit = 50}) async {
    return await _apiClient.get(
      '${AppConfig.apiBaseUrl}/v1/videos/$videoId/comments?page=$page&limit=$limit',
      requiresAuth: true,
    );
  }

  /// Crea un nuevo comentario en un video
  Future<ApiResponse<dynamic>> createComment(String videoId, String content) async {
    return await _apiClient.post(
      '${AppConfig.apiBaseUrl}/v1/videos/$videoId/comments',
      body: {
        'text': content,
      },
      requiresAuth: true,
    );
  }

  /// Elimina un comentario propio
  Future<ApiResponse<dynamic>> deleteComment(String commentId) async {
    return await _apiClient.delete(
      '${AppConfig.apiBaseUrl}/v1/comments/$commentId',
      requiresAuth: true,
    );
  }

  /// Reporta el comentario de otra persona
  Future<ApiResponse<dynamic>> reportComment(String commentId, String motivo) async {
    return await _apiClient.post(
      '${AppConfig.apiBaseUrl}/v1/comments/$commentId/report',
      body: {
        'motivo': motivo,
      },
      requiresAuth: true,
    );
  }
}
