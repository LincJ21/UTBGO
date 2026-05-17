import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'videos_screen.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'video_model.dart';
import 'single_video_screen.dart';
import 'explore_screen.dart'; // <--- Importado el nuevo Explore Screen

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  bool? _isAuthenticated;
  int _selectedIndex = 1;
  bool _isBottomBarVisible = true;
  
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  void _setBottomBarVisibility(bool isVisible) {
    if (_isBottomBarVisible != isVisible) {
      setState(() => _isBottomBarVisible = isVisible);
    }
  }

  late final List<Widget> _pages;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _handleLogout() {
    const storage = FlutterSecureStorage();
    storage.delete(key: 'jwt_token').then((_) {
      setState(() {
        _isAuthenticated = false;
        _selectedIndex = 1;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      const ExploreScreen(), // <--- Nueva pantalla de Explorar!
      VideosScreen(onVisibilityChanged: _setBottomBarVisibility),
      ProfileScreen(onLogout: _handleLogout),
    ];
    _checkAuthStatus();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Manejar el enlace inicial (si la app estaba cerrada)
    try {
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Error obteniendo initial link: $e");
    }

    // Escuchar enlaces mientras la app está abierta (en background o activa)
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("Error escuchando deep links: $err");
    });
  }

  void _handleDeepLink(Uri uri) async {
    // Ejemplo de URI: https://utbgo-api.../video/123
    if (uri.pathSegments.length >= 2 && uri.pathSegments[0] == 'video') {
      final videoId = uri.pathSegments[1];
      
      // Esperar a que la autenticación termine si está en progreso
      if (_isAuthenticated == null) {
        await Future.doWhile(() async {
          await Future.delayed(const Duration(milliseconds: 100));
          return _isAuthenticated == null;
        });
      }

      // Mostrar indicador de carga visualmente usando el context actual si es posible
      if (!mounted) return;
      
      // Mostrar diálogo de carga temporal
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      try {
        final apiClient = ApiClient();
        final response = await apiClient.get(
          AppConfig.videoDetailsUrl(videoId),
          requiresAuth: _isAuthenticated == true, // Enviar token si está autenticado
        );

        // Cerrar el diálogo de carga
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }

        if (response.isSuccess && response.data != null) {
          final video = VideoModel.fromJson(response.data as Map<String, dynamic>);
          
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => SingleVideoScreen(video: video),
              ),
            );
          }
        } else {
          // Mostrar error si el video no existe o hubo un problema
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No se pudo cargar el video compartido.')),
            );
          }
        }
      } catch (e) {
        // Cerrar el diálogo de carga en caso de excepción
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthStatus() async {
    try {
      const storage = FlutterSecureStorage();
      // Ponemos un timeout de 3 segundos a la lectura del token. 
      // Si el Keystore de Android está lento, no bloquearemos la app.
      final token = await storage.read(key: 'jwt_token').timeout(
        const Duration(seconds: 3),
        onTimeout: () => null, 
      );
      
      if (token != null && token.isNotEmpty) {
        _cacheUserRoleSilently();
      }
      
      if (!mounted) return;
      setState(() {
        _isAuthenticated = token != null && token.isNotEmpty;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isAuthenticated = false;
      });
    }
  }

  /// Consulta al backend el rol actual del usuario y lo guarda localmente.
  /// Se ejecuta cada vez que la app arranca para garantizar que cambios
  /// de rol hechos por un administrador se reflejen sin re-login.
  Future<void> _cacheUserRoleSilently() async {
    try {
      final apiClient = ApiClient();
      final res = await apiClient.get('${AppConfig.backendBaseUrl}/api/v1/profile/me', requiresAuth: true);
      if (res.isSuccess && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        // La respuesta de /profile/me devuelve el User directamente (no anidado)
        final role = data['role'] as String?;
        if (role != null && role.isNotEmpty) {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('role', role);
        }
      }
    } catch (_) {}
  }

  void _onLoginSuccess() {
    setState(() => _isAuthenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated!) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _isBottomBarVisible ? 60.0 : 0.0,
        child: _isBottomBarVisible ? _buildBottomBar() : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.fromRGBO(0, 26, 63, 1), // Azul profundo
            Color.fromRGBO(1, 35, 80, 1), // Azul UTB base
            Color.fromARGB(255, 4, 66, 114), // Azul claro frío
          ],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(icon: Icons.insert_chart_outlined, index: 0),
          _buildNavItemAsset('assets/images/01.png', index: 1),
          _buildNavItem(icon: Icons.person, index: 2),
        ],
      ),
    );
  }

  Widget _buildNavItem({required IconData icon, required int index}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildNavItemAsset(String asset, {required int index}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Image.asset(asset, height: 30, color: Colors.white),
        ),
      ),
    );
  }
}
