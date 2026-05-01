import 'package:flutter/material.dart';
import 'privacy_policy_screen.dart';
import 'terms_of_service_screen.dart';

// ─────────────────────────────────────────────────────────────
//  PANTALLA DE CONFIGURACIÓN
// ─────────────────────────────────────────────────────────────

/// Pantalla de configuración de la aplicación.
///
/// Secciones:
///  • CUENTA: Notificaciones, Gestión de cuenta, Modo Oscuro.
///  • LEGAL Y PRIVACIDAD: Privacidad, Términos y condiciones, Política de datos.
///  • Cerrar Sesión.
///
/// Requiere un [onLogout] callback para manejar el cierre de sesión.
class SettingsScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const SettingsScreen({super.key, required this.onLogout});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isDarkMode = false;

  // ── Colores del diseño ──
  static const _utbDarkBlue = Color.fromRGBO(0, 26, 63, 1);
  static const _utbBaseBlue = Color.fromRGBO(1, 35, 80, 1);
  static const _utbLightBlue = Color.fromARGB(255, 4, 66, 114);
  static const _sectionHeader = Color(0xFF1565C0);
  static const _logoutRed = Color(0xFFE53935);
  static const _iconBg = Color(0xFF1A3A6B);
  static const _cardBorder = Color(0xFFE8ECF0);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.chevron_left, color: Colors.black87, size: 30),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Configuración',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // ── SECCIÓN: CUENTA ──
          _buildSectionHeader('CUENTA'),
          const SizedBox(height: 8),
          _buildCard([
            _buildSettingsItem(
              icon: Icons.notifications,
              iconColor: _iconBg,
              title: 'Notificaciones',
              subtitle: 'Push, Email, SMS',
              onTap: () => _navigateToNotificationSettings(context),
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.group,
              iconColor: _iconBg,
              title: 'Gestión de cuenta',
              subtitle: 'Contraseña, Desactivación',
              onTap: () => _navigateToAccountManagement(context),
            ),
            _buildDivider(),
            _buildToggleItem(
              icon: Icons.dark_mode,
              iconColor: const Color(0xFF0D1B3E),
              title: 'Modo Oscuro',
              subtitle: 'Cambiar tema de la aplicación',
              value: _isDarkMode,
              onChanged: (value) {
                setState(() => _isDarkMode = value);
                // TODO: Implementar cambio global de tema.
              },
            ),
          ]),

          const SizedBox(height: 24),

          // ── SECCIÓN: LEGAL Y PRIVACIDAD ──
          _buildSectionHeader('LEGAL Y PRIVACIDAD'),
          const SizedBox(height: 8),
          _buildCard([
            _buildSettingsItem(
              icon: Icons.lock,
              iconColor: const Color(0xFF546E7A),
              title: 'Privacidad',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.description,
              iconColor: const Color(0xFF546E7A),
              title: 'Términos y condiciones',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TermsOfServiceScreen()),
              ),
            ),
            _buildDivider(),
            _buildSettingsItem(
              icon: Icons.policy,
              iconColor: const Color(0xFF546E7A),
              title: 'Política de datos',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PrivacyPolicyScreen()),
              ),
            ),
          ]),

          const SizedBox(height: 24),

          // ── CERRAR SESIÓN ──
          _buildCard([
            _buildSettingsItem(
              icon: Icons.logout,
              iconColor: _logoutRed,
              title: 'Cerrar Sesión',
              titleColor: _logoutRed,
              showChevron: false,
              onTap: () => _confirmLogout(context),
            ),
          ]),

          const SizedBox(height: 32),
        ],
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ── Componentes de UI ──

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: _sectionHeader,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  /// Envuelve una lista de widgets en una tarjeta con bordes redondeados.
  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _cardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return const Divider(height: 1, indent: 64, color: Color(0xFFEEEEEE));
  }

  /// Ítem estándar de configuración con ícono, título, subtítulo y chevron.
  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    bool showChevron = true,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Ícono con fondo circular
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            // Título + subtítulo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor ?? Colors.black87,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),
                  ],
                ],
              ),
            ),
            if (showChevron)
              Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  /// Ítem con switch toggle para Modo Oscuro.
  Widget _buildToggleItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: _sectionHeader,
          ),
        ],
      ),
    );
  }

  // ── Navegación / Acciones ──

  void _navigateToNotificationSettings(BuildContext context) {
    _showComingSoon(context, 'Configuración de notificaciones');
  }

  void _navigateToAccountManagement(BuildContext context) {
    _showComingSoon(context, 'Gestión de cuenta');
  }

  void _showComingSoon(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — próximamente'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  /// Muestra un diálogo de confirmación antes de cerrar sesión.
  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cerrar sesión'),
        content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cierra el diálogo
              Navigator.pop(context); // Vuelve a la pantalla anterior
              widget.onLogout();
            },
            style: TextButton.styleFrom(foregroundColor: _logoutRed),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
  }

  // ── Barra de navegación inferior ──

  Widget _buildBottomNavBar() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_utbDarkBlue, _utbBaseBlue, _utbLightBlue],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.insert_chart_outlined, onTap: () {
            Navigator.pop(context);
          }),
          _buildNavItemAsset('assets/images/01.png', onTap: () {
            Navigator.pop(context);
          }),
          _buildNavItem(Icons.person, onTap: () {
            Navigator.pop(context);
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildNavItemAsset(String asset, {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Image.asset(asset, height: 30, color: Colors.white),
        ),
      ),
    );
  }
}
