import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'videos_screen.dart';

/// [MainNavigationPage] es el widget principal de la aplicación.
///
/// Actúa como un "armazón" o "scaffold" que contiene la barra de navegación inferior
/// y gestiona cuál de las tres páginas principales (`Información`, `Videos`, `Perfil`)
/// se está mostrando actualmente.
class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  /// [_isAuthenticated] controla si el usuario ha iniciado sesión.
  /// Por defecto es `false` para mostrar primero la pantalla de login.
  bool? _isAuthenticated; // Nulable para representar el estado de carga

  /// [_selectedIndex] controla qué pestaña está activa.
  /// Inicia en 1 para que la aplicación abra directamente en la vista de videos.
  int _selectedIndex = 1; // Iniciamos en el Feed (índice 1)

  /// [_pages] es una lista estática que contiene los widgets de las tres
  /// pantallas principales de la aplicación. El orden en esta lista corresponde
  /// a los índices de la barra de navegación.
  // --- CAMBIO --- Hacemos la lista de páginas dinámica para pasar el callback.
  // late final List<Widget> _pages; // Eliminamos esta variable de estado

  /// [_onItemTapped] es la función que se llama cuando el usuario toca un ícono
  /// en la barra de navegación. Actualiza el estado para cambiar de página.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  /// Cierra la sesión del usuario, borra el token y vuelve a la pantalla de login.
  Future<void> _handleLogout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'jwt_token');
    await GoogleSignIn().signOut();
    setState(() {
      _isAuthenticated = false;
      _selectedIndex = 1; // Reiniciar a la pestaña por defecto
    });
  }

  @override
  void initState() {
    super.initState();
    // --- DESACTIVADO TEMPORALMENTE PARA PRUEBAS ---
    // Se omite la verificación de autenticación y se asume que el usuario
    // ya ha iniciado sesión.
    // _isAuthenticated = true;
    _checkAuthStatus();
  }

  /// Comprueba si hay un token JWT guardado para autenticar al usuario automáticamente.
  Future<void> _checkAuthStatus() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    setState(() {
      _isAuthenticated = token != null && token.isNotEmpty;
    });
  }

  /// Esta función se pasa a la pantalla de login para que pueda notificar
  /// cuando el login ha sido (simuladamente) exitoso.
  void _onLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Muestra un loader mientras se verifica el estado de autenticación
    if (_isAuthenticated == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // --- Lógica de Autenticación ---
    // Si el usuario no está autenticado, muestra la pantalla de login.
    // Si no, muestra la navegación principal.
    if (!_isAuthenticated!) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    // Definimos las páginas aquí para que se reconstruyan con cada Hot Reload
    final List<Widget> pages = [
      // --- Pestaña 0: Estadísticas (Placeholder) ---
      Scaffold(
        backgroundColor: const Color(0x00DDDDDD),
        body: const Center(
          child: Text('Estadísticas', style: TextStyle(color: Colors.white)),
        ),
      ),
      // --- Pestaña 1: Feed Principal (Videos) ---
      VideosScreen(
        onLogout: _handleLogout,
      ),
      // --- Pestaña 2: Perfil ---
      ProfileScreen(onLogout: _handleLogout),
    ];

    // --- CORRECCIÓN DE SEGURIDAD ---
    // Validamos que el índice no exceda el número de páginas.
    // Esto previene errores tras un Hot Reload si se redujo la cantidad de pestañas.
    final int safeIndex = (_selectedIndex >= pages.length) ? 1 : _selectedIndex;

    return Scaffold(
      // Envolvemos el body en un Container con el degradado
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white, // Fondo blanco solicitado
        ),
      // El cuerpo del Scaffold muestra la página correspondiente al índice seleccionado.
        child: pages[safeIndex],
      ),
      // La barra de navegación inferior.
      // --- CAMBIO --- Barra fija, siempre visible.
      bottomNavigationBar: Container(
        height: 41.0, // <--- CAMBIA ESTE VALOR para ajustar la altura
        decoration: BoxDecoration(
          gradient: const LinearGradient(
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
            _buildCustomNavItem(0, icon: Icons.insert_chart_outlined),
            _buildCustomNavItem(1, asset: 'assets/images/01.png'),
            _buildCustomNavItem(2, icon: Icons.person),
          ],
        ),
      ),
    );
  }

  /// Construye un ítem de navegación personalizado centrado verticalmente.
  Widget _buildCustomNavItem(int index, {IconData? icon, String? asset}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center, // Centra el ícono vertical y horizontalmente
          child: asset != null
              ? Image.asset(
                  asset,
                  height: 30,
                  color: Colors.white,
                )
              : Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
        ),
      ),
    );
  }
}
