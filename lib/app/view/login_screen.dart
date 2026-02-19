import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'api_constants.dart';


/// [LoginScreen] es la pantalla de bienvenida que permite a los usuarios iniciar sesión.
class LoginScreen extends StatefulWidget {
  /// La función que se llamará cuando el login sea exitoso.
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _storage = const FlutterSecureStorage();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    // El serverClientId es el ID de cliente de tipo "Aplicación web" que creaste en Google Cloud
    // para tu backend. Es necesario para que Google sepa que tu backend verificará el token.
    // --- CORRECCIÓN ---
    // Se debe usar el ID de cliente de tipo "Web" (client_type: 3 en google-services.json),
    // no el de Android (client_type: 1).
    serverClientId: '1032148217715-c2ab71la5ht5nttfjvlbtfhhrem7adek.apps.googleusercontent.com',
  );

  @override
  void initState() {
    super.initState();
  }

  /// Inicia el flujo de autenticación con Google.
  Future<void> _loginWithGoogle() async {
    try {
      // Forzamos el cierre de sesión previo para limpiar cualquier estado "colgado"
      // que pueda causar el error 7 (Network Error) si el logout anterior falló.
      await _googleSignIn.signOut();

      // 1. Iniciar el proceso de login nativo de Google.
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // El usuario canceló el proceso.
        debugPrint('Login cancelado por el usuario.');
        return;
      }

      // 2. Obtener el idToken de la autenticación.
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        throw Exception('No se pudo obtener el idToken de Google.');
      }

      // 3. Enviar el idToken a nuestro backend para verificación.
      final Uri verifyUrl = Uri.parse('${ApiConstants.baseUrl}/auth/google/verify-token');
      final response = await http.post(
        verifyUrl,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': idToken}),
      );

      if (response.statusCode == 200) {
        // 4. El backend nos devuelve nuestro propio token JWT.
        final responseBody = json.decode(response.body);
        final String jwtToken = responseBody['token'];
        debugPrint('Token JWT recibido del backend: $jwtToken');

        // 5. Guardar el token y notificar el éxito.
        await _storage.write(key: 'jwt_token', value: jwtToken);
        widget.onLoginSuccess();
      } else {
        throw Exception('Fallo al verificar el token con el backend: ${response.body}');
      }
    } catch (error) {
      debugPrint('Error durante el inicio de sesión con Google: $error');
      // Opcional: Mostrar un SnackBar o diálogo de error al usuario.
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al iniciar sesión. Inténtalo de nuevo.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color primaryColor = Color(0xFF003399);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Iconos oscuros para fondo blanco
        statusBarBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.white,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo de la aplicación
                  Image.asset('assets/images/01.png', height: 120, color: primaryColor),
                  const SizedBox(height: 24),
                  const Text(
                    'Bienvenido a UTBGo',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: primaryColor),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tu plataforma de contenido educativo.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                  const SizedBox(height: 64),
                  // Botón de inicio de sesión
                  ElevatedButton.icon(
                    onPressed: _loginWithGoogle,
                    icon: const Icon(Icons.login, color: Colors.white),
                    label: const Text('Iniciar Sesión con Google'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
