import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aad_oauth/aad_oauth.dart';
import 'package:aad_oauth/model/config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'config/app_config.dart';
import 'config/api_client.dart';
import 'onboarding_interests_screen.dart';
import 'services/global_ui_service.dart';

/// [LoginScreen] Rediseñada para flujos OIDC (Microsoft y Google) exclusivamente.
class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _storage = const FlutterSecureStorage();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleWebClientId,
  );

  AadOAuth? _microsoftSignIn;

  bool _isLoading = false;
  bool _showOnboarding = false;
  bool _manualLoginEnabled = false;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkManualLoginStatus();
    if (AppConfig.isMicrosoftEnabled) {
      _microsoftSignIn = AadOAuth(Config(
        tenant: AppConfig.azureTenantId,
        clientId: AppConfig.azureClientId,
        scope: "openid profile email offline_access",
        redirectUri: AppConfig.azureRedirectUri,
        navigatorKey: GlobalUIService.navigatorKey,
      ));
    }
  }

  /// Guarda los tokens JWT, verifica el perfil y decide si ir al Onboarding o al Feed principal.
  Future<void> _saveTokensAndNotify(Map<String, dynamic> responseBody) async {
    final String accessToken = responseBody['access_token'];
    await _storage.write(key: 'jwt_token', value: accessToken);

    if (responseBody.containsKey('refresh_token')) {
      await _storage.write(
          key: 'refresh_token', value: responseBody['refresh_token']);
    }

    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final apiClient = ApiClient();
      final profileResponse = await apiClient.get(
        '${AppConfig.backendBaseUrl}/api/v1/profile/me',
        requiresAuth: true,
      );

      if (!mounted) return;

      bool needsOnboarding = true;
      if (profileResponse.isSuccess && profileResponse.data != null) {
        final data = profileResponse.data as Map<String, dynamic>;

        final prefs = await SharedPreferences.getInstance();
        if (data['user'] != null && data['user']['role'] != null) {
          await prefs.setString('role', data['user']['role']);
        }

        final interests = data['interests'] as List<dynamic>?;
        if (interests != null && interests.isNotEmpty) {
          needsOnboarding = false;
        }
      }

      if (needsOnboarding) {
        setState(() {
          _isLoading = false;
          _showOnboarding = true;
        });
      } else {
        setState(() => _isLoading = false);
        widget.onLoginSuccess();
      }
    } catch (e) {
      debugPrint('Error verificando perfil: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showOnboarding = true;
        });
      }
    }
  }

  Future<void> _checkManualLoginStatus() async {
    try {
      final response = await http
          .get(Uri.parse(
              '${AppConfig.backendBaseUrl}/api/v1/config/login-status'))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        if (mounted) {
          setState(() {
            _manualLoginEnabled = body['manualLoginEnabled'] ?? false;
          });
        }
      }
    } catch (e) {
      debugPrint('Error verificando status de login manual: $e');
    }
  }

  Future<void> _manualLogin() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showError('Por favor ingrese correo y contraseña.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse('${AppConfig.backendBaseUrl}/api/v1/auth/login'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'email': email, 'password': password}),
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        await _saveTokensAndNotify(body);
      } else {
        final body = json.decode(response.body);
        _showError(body['error'] ?? 'Error al iniciar sesión');
      }
    } catch (e) {
      _showError('No se pudo conectar con el servidor.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Inicia el flujo de autenticación con Microsoft Entra ID (Acceso Institucional).
  Future<void> _loginWithMicrosoft() async {
    if (!AppConfig.isMicrosoftEnabled) {
      _showError('Acceso Institucional no configurado.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await _microsoftSignIn?.login();
      final String? idToken = await _microsoftSignIn?.getIdToken();

      if (idToken == null) {
        debugPrint('Login Microsoft cancelado o fallido.');
        return;
      }

      final response = await http
          .post(
            Uri.parse(AppConfig.oidcAuthUrl('microsoft')),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'token': idToken}),
          )
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        await _saveTokensAndNotify(body);
      } else {
        final body = json.decode(response.body);
        final msg = body['error']?['message'] ??
            'Error verificando cuenta institucional';
        _showError(msg);
      }
    } catch (error) {
      debugPrint('Error Microsoft Sign-In: $error');
      if (mounted) _showError('No se pudo conectar con Microsoft.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Inicia el flujo de autenticación con Google (Acceso Externo/Invitados).
  Future<void> _loginWithGoogle() async {
    setState(() => _isLoading = true);

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null)
        throw Exception("Error al obtener usuario de Firebase");

      final String? firebaseIdToken = await firebaseUser.getIdToken();
      if (firebaseIdToken == null) throw Exception("Error al obtener ID Token");

      final response = await http.post(
        Uri.parse(AppConfig.oidcAuthUrl('firebase')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': firebaseIdToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokensAndNotify(data);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Bienvenido, ${firebaseUser.displayName}!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        throw Exception('Error en el servidor: ${response.body}');
      }
    } catch (e) {
      if (mounted) {
        _showError('Error al iniciar con Google: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade700,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingInterestsScreen(onFinish: widget.onLoginSuccess);
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 28.0, vertical: 16.0),
                child: Column(
                  children: [
                    const Spacer(flex: 2),

                    // Logo
                    Image.asset('assets/images/logoUTB.png', height: 75),
                    const SizedBox(height: 24),

                    // Textos principales
                    const Text(
                      '¡Bienvenido a UTBGo!',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12.0),
                      child: Text(
                        'Tu plataforma de microlearning para el aprendizaje remoto y accesible.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: Colors.black54,
                          height: 1.3,
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    if (_isLoading)
                      const CircularProgressIndicator(color: Color(0xFF185DB2))
                    else ...[
                      if (_manualLoginEnabled) ...[
                        // Formulario de login manual
                        TextField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'Correo Electrónico',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.email),
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            labelText: 'Contraseña',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            prefixIcon: const Icon(Icons.lock),
                          ),
                          obscureText: true,
                        ),
                        const SizedBox(height: 16),
                        _buildPrimaryButton(
                          text: 'Iniciar Sesión',
                          icon: const Icon(Icons.login,
                              color: Color(0xFF185DB2), size: 26),
                          backgroundColor: const Color(0xFF185DB2),
                          textColor: Colors.white,
                          onPressed: _manualLogin,
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () {
                            _showError(
                                'Registro no disponible por el momento.');
                          },
                          child: const Text('¿No tienes cuenta? Regístrate'),
                        ),
                        const SizedBox(height: 4),
                        const Divider(),
                        const SizedBox(height: 16),
                      ],

                      // Botón Microsoft
                      _buildPrimaryButton(
                        text: 'Iniciar Sesión con Microsoft 365',
                        icon: _buildMicrosoftIcon(),
                        backgroundColor: const Color(0xFF185DB2),
                        textColor: Colors.white,
                        onPressed: _loginWithMicrosoft,
                      ),

                      const SizedBox(height: 12),

                      // Botón Invitados
                      _buildPrimaryButton(
                        text: 'Acceso Externo (Invitados)',
                        icon: const Icon(Icons.person_outline,
                            color: Colors.black87, size: 26),
                        backgroundColor: Colors.white,
                        textColor: Colors.black87,
                        borderColor: Colors.black87,
                        onPressed: _loginWithGoogle,
                      ),
                    ],

                    const Spacer(flex: 2),

                    // Footer Legal
                    const SizedBox(height: 12),
                    const Text(
                      'Al iniciar sesión, aceptas los Términos y Condiciones de uso de la plataforma UTB. Consulta nuestra Política de Privacidad.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 11, color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '¿Tienes problemas para acceder? Contacta ',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                        GestureDetector(
                          onTap: () {
                            // TODO: Abrir URL de soporte
                          },
                          child: const Text(
                            'soporte UTB',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF185DB2),
                              fontWeight: FontWeight.bold,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye un botón estilizado según las guías de diseño de la imagen.
  Widget _buildPrimaryButton({
    required String text,
    required Widget icon,
    required Color backgroundColor,
    required Color textColor,
    required VoidCallback onPressed,
    Color? borderColor,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: backgroundColor == Colors.white ? 0 : 3,
          shadowColor: Colors.black.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: borderColor != null
                ? BorderSide(color: borderColor, width: 1.2)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: backgroundColor == Colors.white
                    ? Colors.transparent
                    : Colors.white,
                borderRadius: BorderRadius.circular(8),
              ),
              child: icon,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Construye el ícono clásico de 4 colores de Microsoft.
  Widget _buildMicrosoftIcon() {
    return SizedBox(
      width: 22,
      height: 22,
      child: GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          Container(color: const Color(0xFFF25022)), // Rojo
          Container(color: const Color(0xFF7FBA00)), // Verde
          Container(color: const Color(0xFF00A4EF)), // Azul
          Container(color: const Color(0xFFFFB900)), // Amarillo
        ],
      ),
    );
  }
}
