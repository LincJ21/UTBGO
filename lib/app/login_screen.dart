import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'config/app_config.dart';
import 'config/api_client.dart'; // Importación añadida para consultar el perfil
import 'onboarding_interests_screen.dart';

/// [LoginScreen] permite iniciar sesión con email/password o con Google.
class LoginScreen extends StatefulWidget {
  /// La función que se llamará cuando el login sea exitoso.
  final VoidCallback onLoginSuccess;

  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _storage = const FlutterSecureStorage();
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _lastNameController = TextEditingController();

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: AppConfig.googleWebClientId,
  );

  bool _isLoading = false;
  bool _isRegisterMode = false;
  bool _obscurePassword = true;
  bool _showOnboarding = false; // Nuevo estado para controlar la transición

  static const String _studentDomain = 'utb.edu.co';
  static const String _professorDomain = 'doc.utb.edu.co';
  static const String _googleAspirantDomain = 'gmail.com';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  /// Guarda los tokens JWT, verifica el perfil y decide si de ir al Onboarding o al Feed principal.
  Future<void> _saveTokensAndNotify(Map<String, dynamic> responseBody) async {
    final String accessToken = responseBody['access_token'];
    debugPrint('Token JWT recibido (longitud: ${accessToken.length})');
    await _storage.write(key: 'jwt_token', value: accessToken);

    // Guardar refresh token si viene
    if (responseBody.containsKey('refresh_token')) {
      await _storage.write(
          key: 'refresh_token', value: responseBody['refresh_token']);
    }

    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      // Verificar si el usuario ya escogió sus intereses (Cold Start)
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
          needsOnboarding = false; // Ya tiene intereses, omitir Onboarding
        }
      }

      if (needsOnboarding) {
        setState(() {
          _isLoading = false;
          _showOnboarding = true;
        });
      } else {
        setState(() => _isLoading = false);
        widget.onLoginSuccess(); // Lo manda directo al Feed (Home)
      }
    } catch (e) {
      debugPrint('Error verificando perfil: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _showOnboarding = true; // Ante la duda, pedir intereses
        });
      }
    }
  }

  /// Login con email y contraseña.
  Future<void> _loginWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.loginUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': _emailController.text.trim().toLowerCase(),
              'password': _passwordController.text,
            }),
          )
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));

      if (response.statusCode == 200) {
        final body = json.decode(response.body);
        await _saveTokensAndNotify(body);
      } else {
        final body = json.decode(response.body);
        final msg = body['error']?['message'] ?? 'Credenciales inválidas';
        _showError(msg);
      }
    } catch (e) {
      debugPrint('Error login email: $e');
      _showError('Error de conexión. Verifica tu red e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Registro con email, contraseña, nombre y apellido.
  Future<void> _registerWithEmail() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      final response = await http
          .post(
            Uri.parse(AppConfig.registerUrl),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'email': _emailController.text.trim().toLowerCase(),
              'password': _passwordController.text,
              'name': _nameController.text.trim(),
              'last_name': _lastNameController.text.trim(),
            }),
          )
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));

      if (response.statusCode == 201) {
        final body = json.decode(response.body);
        await _saveTokensAndNotify(body);
      } else {
        final body = json.decode(response.body);
        final msg = body['error']?['message'] ?? 'Error al registrar';
        _showError(msg);
      }
    } catch (e) {
      debugPrint('Error registro: $e');
      _showError('Error de conexión. Verifica tu red e inténtalo de nuevo.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Inicia el flujo de autenticación con Google.
  Future<void> _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // 1. Iniciar flujo nativo de Google
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final selectedEmail = googleUser.email.trim().toLowerCase();
      if (!_hasExactDomain(selectedEmail, _googleAspirantDomain)) {
        await _googleSignIn.signOut();
        _showError(
          'El acceso con Google solo está permitido para aspirantes con correo @$_googleAspirantDomain.',
        );
        return;
      }

      // 2. Obtener autenticación de Google
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      // 3. Autenticar en Firebase con las credenciales de Google
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      final User? firebaseUser = userCredential.user;

      if (firebaseUser == null) {
        throw Exception("Error al obtener usuario de Firebase");
      }

      // 4. Obtener el ID Token de Firebase para nuestro Backend
      final String? firebaseIdToken = await firebaseUser.getIdToken();

      if (firebaseIdToken == null) {
        throw Exception("Error al obtener ID Token de Firebase");
      }

      // 5. Enviar ID Token al Identity Broker (Backend Go)
      final response = await http.post(
        Uri.parse(AppConfig.oidcAuthUrl('firebase')),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'token': firebaseIdToken}),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        await _saveTokensAndNotify(data); // Usa el método seguro que extrae ambos tokens

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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al iniciar con Google: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

  void _toggleMode() {
    setState(() {
      _isRegisterMode = !_isRegisterMode;
      _formKey.currentState?.reset();
    });
  }

  bool _hasExactDomain(String email, String domain) {
    final normalized = email.trim().toLowerCase();
    return normalized.endsWith('@$domain');
  }

  String? _validateEmail(String? value) {
    final email = value?.trim().toLowerCase() ?? '';
    if (email.isEmpty) {
      return 'Ingresa tu correo';
    }
    if (!email.contains('@')) {
      return 'Correo no válido';
    }

    if (_isRegisterMode &&
        !_hasExactDomain(email, _studentDomain) &&
        !_hasExactDomain(email, _professorDomain)) {
      return 'Regístrate solo con @$_studentDomain o @$_professorDomain';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (_showOnboarding) {
      return OnboardingInterestsScreen(onFinish: widget.onLoginSuccess);
    }

    const Color primaryColor = Color(0xFF003399);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo
                  Image.asset('assets/images/01.png',
                      height: 100, color: primaryColor),
                  const SizedBox(height: 16),
                  Text(
                    _isRegisterMode ? 'Crear Cuenta' : 'Bienvenido a UTBGo',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: primaryColor),
                  ),
                  const SizedBox(height: 30),
                  Text(
                    _isRegisterMode
                        ? 'Registro para estudiantes y profesores'
                        : 'Ingresa con tu cuenta institucional o con Google si eres aspirante.',
                    textAlign: TextAlign.center,
                    style:
                        const TextStyle(fontSize: 14, color: Colors.black54),
                  ),
                  const SizedBox(height: 20),

                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    
                  ),
                  const SizedBox(height: 20),

                  // Campos de nombre (solo en modo registro)
                  if (_isRegisterMode) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: _inputDecoration('Nombre', Icons.person),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa tu nombre'
                          : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _lastNameController,
                      decoration:
                          _inputDecoration('Apellido', Icons.person_outline),
                      textCapitalization: TextCapitalization.words,
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Ingresa tu apellido'
                          : null,
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Email
                  TextFormField(
                    controller: _emailController,
                    decoration: _inputDecoration('Correo electrónico',
                        Icons.email_outlined),
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 12),

                  // Password
                  TextFormField(
                    controller: _passwordController,
                    decoration: _inputDecoration(
                            'Contraseña', Icons.lock_outline)
                        .copyWith(
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off
                              : Icons.visibility,
                          color: Colors.grey,
                        ),
                        onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword),
                      ),
                    ),
                    obscureText: _obscurePassword,
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Ingresa tu contraseña';
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Botón principal
                  ElevatedButton(
                    onPressed: _isLoading
                        ? null
                        : (_isRegisterMode
                            ? _registerWithEmail
                            : _loginWithEmail),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            height: 22,
                            width: 22,
                            child: CircularProgressIndicator(
                                color: Colors.white, strokeWidth: 2.5))
                        : Text(_isRegisterMode
                            ? 'Crear Cuenta'
                            : 'Iniciar Sesión'),
                  ),
                  const SizedBox(height: 12),

                  // Cambiar entre login / registro
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    child: Text(
                      _isRegisterMode
                          ? '¿Ya tienes cuenta? Inicia sesión'
                          : '¿No tienes cuenta? Regístrate',
                      style: const TextStyle(color: primaryColor),
                    ),
                  ),

                  // Divider
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('o', style: TextStyle(color: Colors.grey)),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Botón Google
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Ingresa con Google'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                      side: BorderSide(color: Colors.grey.shade300),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.normal),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: const Color(0xFF003399)),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF003399), width: 2),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }
}
