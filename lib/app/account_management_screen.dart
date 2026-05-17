import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';

// ─────────────────────────────────────────────────────────────
//  PANTALLA DE GESTIÓN DE CUENTA
// ─────────────────────────────────────────────────────────────

/// Pantalla que permite al usuario:
///  • Cambiar su contraseña (requiere contraseña actual).
///  • Desactivar su cuenta (soft delete con confirmación).
///
/// Sigue las directrices OWASP: verificación de identidad antes
/// de operaciones sensibles, validación en cliente y servidor,
/// y mensajes de error genéricos para no filtrar información.
class AccountManagementScreen extends StatefulWidget {
  final VoidCallback onAccountDeactivated;

  const AccountManagementScreen({
    super.key,
    required this.onAccountDeactivated,
  });

  @override
  State<AccountManagementScreen> createState() =>
      _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  // ── Colores del diseño ──
  static const _utbDarkBlue = Color.fromRGBO(0, 26, 63, 1);
  static const _utbBaseBlue = Color.fromRGBO(1, 35, 80, 1);
  static const _utbLightBlue = Color.fromARGB(255, 4, 66, 114);
  static const _sectionHeader = Color(0xFF1565C0);
  static const _iconBg = Color(0xFF1A3A6B);
  static const _cardBorder = Color(0xFFE8ECF0);
  static const _dangerRed = Color(0xFFE53935);

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
          'Gestión de cuenta',
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
          // ── SECCIÓN: SEGURIDAD ──
          _buildSectionHeader('SEGURIDAD'),
          const SizedBox(height: 8),
          _buildCard([
            _buildSettingsItem(
              icon: Icons.lock_outline,
              iconColor: _iconBg,
              title: 'Cambiar contraseña',
              subtitle: 'Actualiza tu contraseña de acceso',
              onTap: () => _showChangePasswordDialog(context),
            ),
          ]),

          const SizedBox(height: 24),

          // ── SECCIÓN: ZONA DE PELIGRO ──
          _buildSectionHeader('ZONA DE PELIGRO'),
          const SizedBox(height: 8),
          _buildCard([
            _buildSettingsItem(
              icon: Icons.warning_amber_rounded,
              iconColor: _dangerRed,
              title: 'Desactivar cuenta',
              subtitle: 'Tu cuenta será suspendida temporalmente',
              titleColor: _dangerRed,
              onTap: () => _showDeactivateDialog(context),
            ),
          ]),

          const SizedBox(height: 16),

          // Nota informativa
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              'Al desactivar tu cuenta, tu perfil y contenido dejarán de ser visibles. '
              'Puedes contactar a soporte para reactivarla en cualquier momento.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[500],
                height: 1.5,
              ),
            ),
          ),

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
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: title == 'ZONA DE PELIGRO' ? _dangerRed : _sectionHeader,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

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

  Widget _buildSettingsItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    Color? titleColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  // ── Diálogo: Cambiar Contraseña ──

  void _showChangePasswordDialog(BuildContext context) {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showCurrentPassword = false;
    bool showNewPassword = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _iconBg.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.lock_outline,
                    color: _iconBg, size: 20),
              ),
              const SizedBox(width: 12),
              const Text('Cambiar contraseña',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: currentPasswordController,
                    obscureText: !showCurrentPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña actual',
                      prefixIcon: const Icon(Icons.lock, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(showCurrentPassword
                            ? Icons.visibility_off
                            : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(
                            () => showCurrentPassword = !showCurrentPassword),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo requerido' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: newPasswordController,
                    obscureText: !showNewPassword,
                    decoration: InputDecoration(
                      labelText: 'Nueva contraseña',
                      prefixIcon: const Icon(Icons.lock_reset, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(showNewPassword
                            ? Icons.visibility_off
                            : Icons.visibility, size: 20),
                        onPressed: () => setDialogState(
                            () => showNewPassword = !showNewPassword),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Campo requerido';
                      if (v.length < 8) return 'Mínimo 8 caracteres';
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: confirmPasswordController,
                    obscureText: !showNewPassword,
                    decoration: InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                      prefixIcon: const Icon(Icons.check_circle_outline, size: 20),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    validator: (v) {
                      if (v != newPasswordController.text) {
                        return 'Las contraseñas no coinciden';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);

                      final apiClient = ApiClient();
                      final response = await apiClient.patch(
                        AppConfig.changePasswordEndpoint,
                        requiresAuth: true,
                        body: {
                          'current_password':
                              currentPasswordController.text,
                          'new_password': newPasswordController.text,
                        },
                      );

                      setDialogState(() => isLoading = false);

                      if (response.isSuccess && dialogContext.mounted) {
                        Navigator.pop(dialogContext);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                  '✅ Contraseña actualizada correctamente'),
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                              backgroundColor: Colors.green[700],
                            ),
                          );
                        }
                      }
                      // Si falla, el ApiClient ya muestra el error globalmente
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _utbBaseBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Guardar'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Diálogo: Desactivar Cuenta ──

  void _showDeactivateDialog(BuildContext context) {
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool isLoading = false;
    bool showPassword = false;

    showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _dangerRed.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.warning_amber_rounded,
                    color: _dangerRed, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text('Desactivar cuenta',
                    style:
                        TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _dangerRed.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border:
                          Border.all(color: _dangerRed.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      '⚠️ Esta acción suspenderá tu cuenta. '
                      'Tu perfil y contenido dejarán de ser visibles para otros usuarios.',
                      style: TextStyle(fontSize: 13, height: 1.5),
                    ),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Ingresa tu contraseña para confirmar:',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: passwordController,
                    obscureText: !showPassword,
                    decoration: InputDecoration(
                      labelText: 'Contraseña',
                      prefixIcon: const Icon(Icons.lock, size: 20),
                      suffixIcon: IconButton(
                        icon: Icon(
                            showPassword
                                ? Icons.visibility_off
                                : Icons.visibility,
                            size: 20),
                        onPressed: () => setDialogState(
                            () => showPassword = !showPassword),
                      ),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Campo requerido' : null,
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed:
                  isLoading ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: isLoading
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;

                      setDialogState(() => isLoading = true);

                      final apiClient = ApiClient();
                      final response = await apiClient.post(
                        AppConfig.deactivateAccountEndpoint,
                        requiresAuth: true,
                        body: {
                          'password': passwordController.text,
                        },
                      );

                      setDialogState(() => isLoading = false);

                      if (response.isSuccess && dialogContext.mounted) {
                        Navigator.pop(dialogContext);

                        // Limpiar tokens y hacer logout
                        const storage = FlutterSecureStorage();
                        await storage.deleteAll();

                        if (context.mounted) {
                          widget.onAccountDeactivated();
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: _dangerRed,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Desactivar'),
            ),
          ],
        ),
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
