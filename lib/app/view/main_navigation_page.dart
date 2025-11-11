import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
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
  int _selectedIndex = 1;

  /// --- NUEVO --- Controla si la barra de navegación inferior es visible.
  bool _isBottomBarVisible = true;

  /// --- NUEVO --- Callback para que los widgets hijos puedan cambiar la visibilidad de la barra.
  void _setBottomBarVisibility(bool isVisible) {
    // Solo actualiza si el estado ha cambiado para evitar reconstrucciones innecesarias.
    if (_isBottomBarVisible != isVisible) {
      setState(() {
        _isBottomBarVisible = isVisible;
      });
    }
  }

  /// [_pages] es una lista estática que contiene los widgets de las tres
  /// pantallas principales de la aplicación. El orden en esta lista corresponde
  /// a los índices de la barra de navegación.
  // --- CAMBIO --- Hacemos la lista de páginas dinámica para pasar el callback.
  late final List<Widget> _pages;

  /// [_onItemTapped] es la función que se llama cuando el usuario toca un ícono
  /// en la barra de navegación. Actualiza el estado para cambiar de página.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  void initState() {
    super.initState();
    // --- CAMBIO --- Inicializamos la lista de páginas aquí para poder pasar el callback.
    _pages = <Widget>[
      // --- Pestaña 0: Información ---
      Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: const Text('Información Adicional'),
          backgroundColor: const Color(0xFF003399),
        ),
        body: const Center(child: Text('Página de Información Adicional')),
      ),
      // --- Pestaña 1: Videos (Logo) ---
      VideosScreen(onVisibilityChanged: _setBottomBarVisibility), // Pasamos la función
      // --- Pestaña 2: Perfil ---
      const ProfileScreen(),
    ];
    // --- DESACTIVADO TEMPORALMENTE PARA PRUEBAS ---
    // Se omite la verificación de autenticación y se asume que el usuario
    // ya ha iniciado sesión.
    _isAuthenticated = true;
    // _checkAuthStatus();
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

    return Scaffold(
      // El cuerpo del Scaffold muestra la página correspondiente al índice seleccionado.
      body: _pages[_selectedIndex],
      // La barra de navegación inferior.
      // --- CAMBIO --- Envolvemos la barra en un AnimatedContainer para ocultarla.
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _isBottomBarVisible ? 40.0 : 0.0, // Altura 0 para ocultar
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Ancho de cada "cajón" para los iconos
            final itemWidth = constraints.maxWidth / _pages.length;

            return Container(
              height: 40,
              color: const Color(0xFF003399), // Fondo azul oscuro
              child: SingleChildScrollView(
                // Evita overflow cuando la altura es 0
                child: Stack(
                  children: [
                    // --- 2. Indicador Deslizante Animado ---
                    AnimatedPositioned(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      // Posicionamos el indicador debajo del ítem seleccionado
                      left: _selectedIndex * itemWidth,
                      bottom: 0,
                      child: Container(
                        width: itemWidth,
                        height: 4,
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                        ),
                      ),
                    ),
                    // --- 1. Fila de Iconos ---
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(icon: Icons.description, index: 0),
                        _buildNavItem(asset: 'assets/images/01.png', index: 1),
                        _buildNavItem(icon: Icons.person_outline, index: 2),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// Construye cada ítem de la barra de navegación.
  ///
  /// Usa [AnimatedContainer] para animar el tamaño y color del icono
  /// cuando es seleccionado.
  Widget _buildNavItem({IconData? icon, String? asset, required int index}) {
    final isSelected = _selectedIndex == index;

    // El widget del icono, ya sea un IconData o una imagen de asset.
    Widget iconWidget;
    if (asset != null) {
      iconWidget = Image.asset(asset, height: isSelected ? 35 : 30, color: Colors.white);
    } else {
      iconWidget = Icon(icon, size: isSelected ? 35 : 30, color: Colors.white);
    }

    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque, // Asegura que toda el área sea tappable
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut,
            height: isSelected ? 40 : 35,
            child: iconWidget,
          ),
        ),
      ),
    );
  }
}
