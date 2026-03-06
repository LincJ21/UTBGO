/// Configuración centralizada de la aplicación.
/// Cambiar entre desarrollo y producción modificando [_environment].
library;

enum Environment { development, production }

/// Configuración activa de la aplicación.
/// Cambiar a [Environment.production] antes de compilar para producción.
const Environment _environment = Environment.development;

/// Clase de configuración que centraliza todas las URLs y constantes.
/// Esto permite cambiar fácilmente entre entornos sin modificar código.
class AppConfig {
  AppConfig._();

  /// Entorno actual de la aplicación.
  static Environment get environment => _environment;

  /// Indica si estamos en modo desarrollo.
  static bool get isDevelopment => _environment == Environment.development;

  /// Indica si estamos en modo producción.
  static bool get isProduction => _environment == Environment.production;

  // --- URLs del Backend ---

  /// URL base del backend según el entorno.
  /// - Desarrollo: 10.0.2.2 para emulador Android, localhost para iOS/web.
  /// - Producción: URL del servidor desplegado.
  static String get backendBaseUrl {
    switch (_environment) {
      case Environment.development:
        // Para emulador Android: 10.0.2.2
        // Para iOS Simulator o web: localhost
        // Para dispositivo físico: IP local de tu máquina
        return 'http://10.0.2.2:8080';
      case Environment.production:
        // TODO: Reemplazar con tu URL de producción real
        return 'https://api.utbgo.com';
    }
  }

  /// URL de la API (incluye /api).
  static String get apiBaseUrl => '$backendBaseUrl/api';

  /// URL para autenticación con Google.
  static String get googleAuthUrl => '$backendBaseUrl/auth/google/verify-token';

  // --- Endpoints de Autenticación v1 ---

  /// URL para login con email/password.
  static String get loginUrl => '$backendBaseUrl/api/v1/auth/login';

  /// URL para registro con email/password.
  static String get registerUrl => '$backendBaseUrl/api/v1/auth/register';

  /// URL para renovar tokens.
  static String get refreshTokenUrl => '$backendBaseUrl/api/v1/auth/refresh';

  // --- Endpoints OIDC (Identity Broker) ---

  /// URL base para autenticación OIDC.
  static String get oidcBaseUrl => '$backendBaseUrl/api/v1/auth/oidc';

  /// URL para autenticación OIDC con un proveedor específico.
  static String oidcAuthUrl(String provider) => '$oidcBaseUrl/$provider';

  /// URL para listar proveedores OIDC disponibles.
  static String get oidcProvidersUrl => '$oidcBaseUrl/providers';

  // --- Endpoints de la API ---

  static String get videosEndpoint => '$apiBaseUrl/videos';
  static String get videosFeedEndpoint => '$videosEndpoint/feed';
  static String get videosSearchEndpoint => '$videosEndpoint/search';
  static String get videosUploadEndpoint => '$videosEndpoint/upload';

  static String get profileEndpoint => '$apiBaseUrl/profile';
  static String get profileMeEndpoint => '$profileEndpoint/me';
  static String get profileAvatarEndpoint => '$profileEndpoint/avatar';

  /// Genera URL para like de un video.
  static String videoLikeUrl(String videoId) => '$videosEndpoint/$videoId/like';

  /// Genera URL para bookmark de un video.
  static String videoBookmarkUrl(String videoId) =>
      '$videosEndpoint/$videoId/bookmark';

  /// Genera URL para comentarios de un video.
  static String videoCommentsUrl(String videoId) =>
      '$videosEndpoint/$videoId/comments';

  // --- Configuración de la App ---

  /// Nombre de la aplicación.
  static const String appName = 'UTBGO';

  /// Versión de la aplicación.
  static const String appVersion = '1.0.0';

  /// Tiempo de espera máximo para requests HTTP (en segundos).
  static const int httpTimeoutSeconds = 30;

  /// Tamaño máximo de video para subir (en MB).
  static const int maxVideoSizeMB = 100;

  /// Tamaño máximo de imagen para subir (en MB).
  static const int maxImageSizeMB = 10;

  /// Extensiones de video permitidas.
  static const List<String> allowedVideoExtensions = ['mp4', 'mov', 'avi'];

  /// Extensiones de imagen permitidas.
  static const List<String> allowedImageExtensions = ['jpg', 'jpeg', 'png', 'webp'];

  // --- Google OAuth ---

  /// ID de cliente de Google (tipo Web) para autenticación.
  /// Se carga desde --dart-define para no exponer credenciales en el código.
  /// Compilar con: flutter build apk --dart-define=GOOGLE_CLIENT_ID=tu_id
  /// Fallback al valor de desarrollo si no se proporciona.
  static const String googleWebClientId = String.fromEnvironment(
    'GOOGLE_CLIENT_ID',
    defaultValue: '687042966882-4m86nj8c9tfkmp0f6sl3qtk0m38cmefp.apps.googleusercontent.com',
  );

  // --- Microsoft Entra ID (Azure AD) ---

  /// ID de cliente de Microsoft Entra ID.
  /// Compilar con: flutter build apk --dart-define=AZURE_CLIENT_ID=tu_id
  static const String azureClientId = String.fromEnvironment(
    'AZURE_CLIENT_ID',
    defaultValue: '',
  );

  /// Tenant ID de Azure AD.
  /// Compilar con: flutter build apk --dart-define=AZURE_TENANT_ID=tu_id
  static const String azureTenantId = String.fromEnvironment(
    'AZURE_TENANT_ID',
    defaultValue: 'common', // 'common' permite cualquier organización
  );

  /// Redirect URI para el flujo de Microsoft OAuth.
  /// Compilar con: flutter build apk --dart-define=AZURE_REDIRECT_URI=tu_uri
  static const String azureRedirectUri = String.fromEnvironment(
    'AZURE_REDIRECT_URI',
    defaultValue: 'msauth://com.example.flutter_practica/callback',
  );

  /// Indica si Microsoft Entra ID está configurado.
  static bool get isMicrosoftEnabled => azureClientId.isNotEmpty;
}




