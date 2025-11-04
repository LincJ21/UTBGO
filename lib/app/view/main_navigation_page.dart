import 'package:flutter/material.dart';
import 'profile_screen.dart';
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
  /// [_selectedIndex] controla qué pestaña está activa.
  /// Inicia en 1 para que la aplicación abra directamente en la vista de videos.
  int _selectedIndex = 1;

  /// [_pages] es una lista estática que contiene los widgets de las tres
  /// pantallas principales de la aplicación. El orden en esta lista corresponde
  /// a los índices de la barra de navegación.
  static final List<Widget> _pages = <Widget>[
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
    const VideosScreen(), // Tu reproductor de video
    // --- Pestaña 2: Perfil ---
    const ProfileScreen(), // La NUEVA página de perfil (ver al final)
  ];

  /// [_onItemTapped] es la función que se llama cuando el usuario toca un ícono
  /// en la barra de navegación. Actualiza el estado para cambiar de página.
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // El cuerpo del Scaffold muestra la página correspondiente al índice seleccionado.
      body: _pages[_selectedIndex],
      // La barra de navegación inferior.
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          // Ancho de cada "cajón" para los iconos
          final itemWidth = constraints.maxWidth / _pages.length;

          return Container(
            height: 40, // Aumentamos la altura para dar espacio a la animación
            color: const Color(0xFF003399), // Fondo azul oscuro
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
          );
        },
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
