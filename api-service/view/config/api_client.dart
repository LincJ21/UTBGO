import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'app_config.dart';

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

  /// Realiza una request GET.
  Future<ApiResponse<T>> get<T>(
    String endpoint, {
    bool requiresAuth = false,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client
          .get(Uri.parse(endpoint), headers: headers)
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));

      return _handleResponse(response, fromJson);
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
  }

  /// Realiza una request POST con body JSON.
  Future<ApiResponse<T>> post<T>(
    String endpoint, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
    T Function(dynamic json)? fromJson,
  }) async {
    try {
      final headers = await _getHeaders(requiresAuth: requiresAuth);
      final response = await _client
          .post(
            Uri.parse(endpoint),
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));

      return _handleResponse(response, fromJson);
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
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
    try {
      // Validar archivo antes de subir
      final validation = await _validateFile(file, fieldName);
      if (!validation.isValid) {
        return ApiResponse.error(validation.error!);
      }

      final request = http.MultipartRequest('POST', Uri.parse(endpoint));

      // Agregar headers de autenticación
      if (requiresAuth) {
        final token = await _storage.read(key: 'jwt_token');
        if (token != null) {
          request.headers['Authorization'] = 'Bearer $token';
        }
      }

      // Agregar campos adicionales
      if (fields != null) {
        request.fields.addAll(fields);
      }

      // Agregar archivo
      request.files.add(await http.MultipartFile.fromPath(fieldName, file.path));

      final streamedResponse = await request.send()
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds * 2)); // Más tiempo para uploads
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response, fromJson);
    } catch (e) {
      return ApiResponse.error(_handleError(e));
    }
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

    switch (statusCode) {
      case 400:
        return ApiResponse.error(ApiError.badRequest(errorMessage));
      case 401:
        return ApiResponse.error(ApiError.unauthorized(errorMessage));
      case 403:
        return ApiResponse.error(ApiError.forbidden(errorMessage));
      case 404:
        return ApiResponse.error(ApiError.notFound(errorMessage));
      case 429:
        return ApiResponse.error(ApiError.tooManyRequests(errorMessage));
      case 500:
      case 502:
      case 503:
        return ApiResponse.error(ApiError.serverError(errorMessage));
      default:
        return ApiResponse.error(ApiError.unknown(errorMessage));
    }
  }

  /// Convierte excepciones en errores amigables.
  ApiError _handleError(dynamic error) {
    debugPrint('ApiClient error: $error');

    if (error is SocketException) {
      return ApiError.network('Sin conexión a internet');
    }
    if (error is http.ClientException) {
      return ApiError.network('Error de conexión con el servidor');
    }
    if (error.toString().contains('TimeoutException')) {
      return ApiError.timeout('La conexión tardó demasiado. Intenta de nuevo.');
    }

    return ApiError.unknown('Error inesperado: ${error.toString()}');
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
