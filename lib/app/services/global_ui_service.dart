import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../main_navigation_page.dart';
/// Servicio global para manejar la navegación y mostrar UI en cualquier parte de la app
/// sin necesitar el BuildContext de un widget específico.
class GlobalUIService {
  // Clave global para Scaffolds (útil para mostrar SnackBars en toda la app)
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  // Clave global para el Navigator (útil para pop-ups o redirecciones de Autenticación)
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  /// Muestra un mensaje de error estilo SnackBar en la parte superior.
  static void showError(String message) {
    if (scaffoldMessengerKey.currentState == null) return;

    scaffoldMessengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 4),
        ),
      );
  }

  /// Muestra un mensaje de información genérico.
  static void showInfo(String message) {
    if (scaffoldMessengerKey.currentState == null) return;

    scaffoldMessengerKey.currentState!
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white)),
          backgroundColor: const Color(0xFF003399), // UTB Blue
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: const EdgeInsets.all(16),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  /// Cierra la sesión globalmente, borrando los tokens y redirigiendo al inicio.
  static Future<void> forceLogout() async {
    // Evitamos importar cosas aquí si da ciclicidad, pero idealmente necesitamos 
    // borrar el token. Usamos dependencias dinámicas o directas si no hay ciclos.
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'jwt_token');
    await storage.delete(key: 'refresh_token');

    final context = navigatorKey.currentContext;
    if (context != null) {
      // Limpia todo el stack y vuelve al MainNavigationPage (que detectará la falta de token y mostrará Login)
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const MainNavigationPage()),
        (route) => false,
      );
    }
  }
}

