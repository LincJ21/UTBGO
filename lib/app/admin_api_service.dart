import 'config/app_config.dart';
import 'config/api_client.dart';
import 'admin_models.dart';

class AdminApiService {
  final ApiClient _api = ApiClient();
  final String _baseUrl = '${AppConfig.backendBaseUrl}/api/v1/admin';

  Future<ApiResponse<AdminStats>> getDashboardStats() async {
    return _api.get<AdminStats>(
      '$_baseUrl/dashboard',
      requiresAuth: true,
      fromJson: (json) => AdminStats.fromJson(json['data']),
    );
  }

  Future<ApiResponse<PaginatedResponse<AdminUser>>> getUsers({
    int page = 1,
    String? search,
    String? role,
    String? status,
  }) async {
    final Map<String, String> queryParams = {'page': page.toString()};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (role != null && role.isNotEmpty) queryParams['role'] = role;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse('$_baseUrl/users').replace(queryParameters: queryParams);

    return _api.get<PaginatedResponse<AdminUser>>(
      uri.toString(),
      requiresAuth: true,
      fromJson: (json) => PaginatedResponse.fromJson(json, (j) => AdminUser.fromJson(j)),
    );
  }

  Future<ApiResponse<void>> updateUserStatus(int id, String status) async {
    return _api.patch<void>(
      '$_baseUrl/users/$id/status',
      requiresAuth: true,
      body: {'status': status},
      fromJson: (_) {},
    );
  }

  Future<ApiResponse<void>> updateUserRole(int id, String role) async {
    return _api.patch<void>(
      '$_baseUrl/users/$id/role',
      requiresAuth: true,
      body: {'role': role},
      fromJson: (_) {},
    );
  }

  Future<ApiResponse<PaginatedResponse<AdminVideo>>> getVideos({
    int page = 1,
    String? search,
    String? status,
  }) async {
    final Map<String, String> queryParams = {'page': page.toString()};
    if (search != null && search.isNotEmpty) queryParams['search'] = search;
    if (status != null && status.isNotEmpty) queryParams['status'] = status;

    final uri = Uri.parse('$_baseUrl/videos').replace(queryParameters: queryParams);

    return _api.get<PaginatedResponse<AdminVideo>>(
      uri.toString(),
      requiresAuth: true,
      fromJson: (json) => PaginatedResponse.fromJson(json, (j) => AdminVideo.fromJson(j)),
    );
  }

  Future<ApiResponse<void>> updateVideoStatus(int id, String status) async {
    return _api.patch<void>(
      '$_baseUrl/videos/$id/status',
      requiresAuth: true,
      body: {'status': status},
      fromJson: (_) {},
    );
  }

  Future<ApiResponse<void>> deleteVideo(int id) async {
    return _api.delete<void>(
      '$_baseUrl/videos/$id',
      requiresAuth: true,
      fromJson: (_) {},
    );
  }
}
