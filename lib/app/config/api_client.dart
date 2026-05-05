import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';
import '../services/global_ui_service.dart';

/// Cliente HTTP centralizado que maneja autenticación, errores y timeouts.
/// Usar esta clase en lugar de http.get/post directamente.
class ApiClient {
  static final ApiClient _instance = ApiClient._internal();
  factory ApiClient() => _instance;
  ApiClient._internal();

  final _storage = const FlutterSecureStorage();
  final _client = http.Client();

  /// Headers por defecto para todas las requests.
  Future<Map<String, String>> _getHeaders({bool requiresAuth = false}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    if (requiresAuth) {
      final token = await _storage.read(key: 'jwt_token');
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  bool _isRefreshing = false;
  Future<bool>? _refreshTokenFuture;

  /// Orquesta la renovación del token, evitando que múltiples peticiones lancen un refresh en paralelo.
  Future<bool> _refreshToken() async {
    if (_isRefreshing && _refreshTokenFuture != null) {
      return await _refreshTokenFuture!;
    }

    _isRefreshing = true;
    _refreshTokenFuture = _performRefreshToken();
    final result = await _refreshTokenFuture!;
    _isRefreshing = false;
    _refreshTokenFuture = null;
    return result;
  }

  /// Llama al backend (Paso 6) para intercambiar el refresh token por uno nuevo.
  Future<bool> _performRefreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      final response = await http.post(
        Uri.parse(AppConfig.refreshTokenUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      ).timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final newAccessToken = body['access_token'];
        final newRefreshToken = body['refresh_token'];

        await _storage.write(key: 'jwt_token', value: newAccessToken);
        if (newRefreshToken != null) {
          await _storage.write(key: 'refresh_token', value: newRefreshToken);
        }
        debugPrint('Token JWT renovado exitosamente');
        return true;
      } else {
        debugPrint('Refresh fallback falló. Status: ${response.statusCode}, Body: ${response.body}');
      }
    } catch (e) {
      debugPrint('Error al renovar token (Excepción): $e');
    }

    // Si el refresh token falló (ej. expirado o revocado en DB), forzamos logout global.
    await GlobalUIService.forceLogout();
    return false;
  }

  /// Wrapper para ejecutar peticiones HTTP transparentemente manejando el ciclo de Refresh Token.
  Future<ApiResponse<T>> _executeWithRetry<T>(
    Future<http.Response> Function() requestAction, {
    required bool requiresAuth,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      var response = await requestAction();

      // Si da 401 y requería Auth, intentamos refrescar el token
      if (response.statusCode == 401 && requiresAuth) {
        final refreshed = await _refreshToken();
        if (refreshed) {
          // Token renovado, reintentamos la petición original
          // (requestAction creará el Future desde cero, pidiendo los headers frescos)
          response = await requestAction();
        }
      }

      // Procesa la respuesta (si reintentó con éxito, procesará el 200 OK)
      return _handleResponse(response, fromJson);
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// Realiza una request GET.
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    bool requiresAuth = false,
    T Function(dynamic json)? fromJson,
  }) async {
    return _executeWithRetry(
      () async {
        final headers = await _getHeaders(requiresAuth: requiresAuth);
        return await _client
            .get(Uri.parse(endpoint), headers: headers)
            .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));
      },
      requiresAuth: requiresAuth,
      fromJson: fromJson,
    );
  }

  /// Realiza una request POST con body JSON.
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    T Function(dynamic json)? fromJson,
  }) async {
    return _executeWithRetry(
      () async {
        final headers = await _getHeaders(requiresAuth: requiresAuth);
        return await _client
            .post(
              Uri.parse(endpoint),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));
      },
      requiresAuth: requiresAuth,
      fromJson: fromJson,
    );
  }

  /// Realiza una request PATCH con body JSON.
  Future<ApiResponse<T>> patch<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    T Function(dynamic json)? fromJson,
  }) async {
    return _executeWithRetry(
      () async {
        final headers = await _getHeaders(requiresAuth: requiresAuth);
        return await _client
            .patch(
              Uri.parse(endpoint),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));
      },
      requiresAuth: requiresAuth,
      fromJson: fromJson,
    );
  }

  /// Realiza una request DELETE.
  Future<ApiResponse<T>> delete<T>(
    String endpoint, {
    bool requiresAuth = false,
    T Function(dynamic json)? fromJson,
  }) async {
    return _executeWithRetry(
      () async {
        final headers = await _getHeaders(requiresAuth: requiresAuth);
        return await _client
            .delete(Uri.parse(endpoint), headers: headers)
            .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));
      },
      requiresAuth: requiresAuth,
      fromJson: fromJson,
    );
  }

  /// Sube un archivo usando multipart/form-data.
  Future<ApiResponse<T>> uploadFile<T>(
    String endpoint, {
    required File file,
    required String fieldName,
    Map<String, String>? fields,
    bool requiresAuth = true,
    T Function(dynamic json)? fromJson,
  }) async {
    // La validación de archivo se hace fuera del logica de reintento para no repetirla innecesariamente
    final validation = await _validateFile(file, fieldName);
    if (!validation.isValid) {
      return ApiResponse.error(validation.error!);
    }

    return _executeWithRetry(
      () async {
        final request = http.MultipartRequest('POST', Uri.parse(endpoint));

        if (requiresAuth) {
          final token = await _storage.read(key: 'jwt_token');
          if (token != null) {
            request.headers['Authorization'] = 'Bearer $token';
          }
        }

        if (fields != null) {
          request.fields.addAll(fields);
        }

        request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

        final streamedResponse = await request.send()
            .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds * 2));
        return await http.Response.fromStream(streamedResponse);
      },
      requiresAuth: requiresAuth,
      fromJson: fromJson,
    );
  }

  /// Valida un archivo antes de subirlo.
  Future<FileValidation> _validateFile(File file, String fieldName) async {
    final fileSize = await file.length();
    final fileName = file.path.split('/').last.toLowerCase();
    final extension = fileName.split('.').last;

    // Determinar límites según el tipo de campo
    final isVideo = fieldName == 'video';
    final maxSizeBytes = isVideo
        ? AppConfig.maxVideoSizeMB * 1024 * 1024
        : AppConfig.maxImageSizeMB * 1024 * 1024;
    final allowedExtensions = isVideo
        ? AppConfig.allowedVideoExtensions
        : AppConfig.allowedImageExtensions;

    if (fileSize > maxSizeBytes) {
      final maxMB = isVideo ? AppConfig.maxVideoSizeMB : AppConfig.maxImageSizeMB;
      return FileValidation.invalid(
        'El archivo es demasiado grande. Máximo: ${maxMB}MB',
      );
    }

    if (!allowedExtensions.contains(extension)) {
      return FileValidation.invalid(
        'Formato no permitido. Formatos válidos: ${allowedExtensions.join(", ")}',
      );
    }

    return FileValidation.valid();
  }

  /// Procesa la respuesta HTTP y la convierte a ApiResponse.
  ApiResponse<T> _handleResponse<T>(
    http.Response response,
    T Function(dynamic json)? fromJson,
  ) {
    final statusCode = response.statusCode;

    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) {
        return ApiResponse.success(null);
      }

      final json = jsonDecode(response.body);
      final data = fromJson != null ? fromJson(json) : json as T?;
      return ApiResponse.success(data);
    }

    // Manejar errores HTTP
    String errorMessage;
    try {
      final json = jsonDecode(response.body);
      errorMessage = json['error'] ?? 'Error desconocido';
    } catch (_) {
      errorMessage = 'Error del servidor (código: $statusCode)';
    }

    ApiError apiError;
    switch (statusCode) {
      case 400:
        apiError = ApiError.badRequest(errorMessage);
        break;
      case 401:
        apiError = ApiError.unauthorized('Sesión expirada. Por favor, inicia sesión de nuevo.');
        // TODO: Mover al log in (Paso 6)
        break;
      case 403:
        apiError = ApiError.forbidden(errorMessage);
        break;
      case 404:
        apiError = ApiError.notFound(errorMessage);
        break;
      case 429:
        apiError = ApiError.tooManyRequests(errorMessage);
        break;
      case 500:
      case 502:
      case 503:
        apiError = ApiError.serverError('El servidor está temporalmente fuera de servicio.');
        break;
      default:
        apiError = ApiError.unknown(errorMessage);
    }

    // Mostrar el error globalmente
    GlobalUIService.showError(apiError.message);
    return ApiResponse.error(apiError);
  }

  /// Convierte excepciones en errores amigables y los muestra.
  ApiError _handleError(dynamic error) {
    debugPrint('ApiClient error: $error');

    ApiError apiError;
    if (error is SocketException) {
      apiError = ApiError.network('Sin conexión a internet. Verifica tu red.');
    } else if (error is http.ClientException) {
      apiError = ApiError.network('Error de conexión con el servidor.');
    } else if (error.toString().contains('TimeoutException')) {
      apiError = ApiError.timeout('La petición tardó demasiado. Intenta de nuevo.');
    } else {
      apiError = ApiError.unknown('Error inesperado de red.');
    }

    // Mostrar el error globalmente
    GlobalUIService.showError(apiError.message);
    return apiError;
  }
}

/// Resultado de una llamada a la API.
class ApiResponse<T> {
  final T? data;
  final ApiError? error;
  final bool isSuccess;

  ApiResponse.success(this.data)
      : error = null,
        isSuccess = true;

  ApiResponse.error(this.error)
      : data = null,
        isSuccess = false;

  /// Ejecuta callback si fue exitoso.
  void onSuccess(void Function(T? data) callback) {
    if (isSuccess) callback(data);
  }

  /// Ejecuta callback si hubo error.
  void onError(void Function(ApiError error) callback) {
    if (!isSuccess && error != null) callback(error!);
  }
}

/// Tipos de errores de la API.
enum ApiErrorType {
  network,
  timeout,
  badRequest,
  unauthorized,
  forbidden,
  notFound,
  tooManyRequests,
  serverError,
  unknown,
}

/// Error estructurado de la API.
class ApiError {
  final ApiErrorType type;
  final String message;

  ApiError(this.type, this.message);

  factory ApiError.network(String message) =>
      ApiError(ApiErrorType.network, message);
  factory ApiError.timeout(String message) =>
      ApiError(ApiErrorType.timeout, message);
  factory ApiError.badRequest(String message) =>
      ApiError(ApiErrorType.badRequest, message);
  factory ApiError.unauthorized(String message) =>
      ApiError(ApiErrorType.unauthorized, message);
  factory ApiError.forbidden(String message) =>
      ApiError(ApiErrorType.forbidden, message);
  factory ApiError.notFound(String message) =>
      ApiError(ApiErrorType.notFound, message);
  factory ApiError.tooManyRequests(String message) =>
      ApiError(ApiErrorType.tooManyRequests, message);
  factory ApiError.serverError(String message) =>
      ApiError(ApiErrorType.serverError, message);
  factory ApiError.unknown(String message) =>
      ApiError(ApiErrorType.unknown, message);

  @override
  String toString() => message;
}

/// Resultado de validación de archivo.
class FileValidation {
  final bool isValid;
  final ApiError? error;

  FileValidation.valid()
      : isValid = true,
        error = null;

  FileValidation.invalid(String message)
      : isValid = false,
        error = ApiError.badRequest(message);
}
