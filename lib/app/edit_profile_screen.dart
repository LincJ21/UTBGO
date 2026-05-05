import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';

// ─────────────────────────────────────────────────────────────
//  PANTALLA DE EDITAR PERFIL
// ─────────────────────────────────────────────────────────────

/// Pantalla para editar la información del perfil del usuario.
///
/// Secciones:
///  • Foto de perfil (con selector de imagen).
///  • INFORMACIÓN BÁSICA: Nombre, Usuario.
///  • PERFIL ACADÉMICO: Biografía (con contador), Rol, Facultad.
///  • ENLACES: CvLAC/Google Scholar, Sitio Web Personal.
///
/// Recibe datos iniciales opcionales y devuelve los cambios al hacer "Guardar".
class EditProfileScreen extends StatefulWidget {
  /// Datos iniciales del perfil para pre-llenar los campos.
  final ProfileData? initialData;

  const EditProfileScreen({super.key, this.initialData});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

/// Modelo inmutable con los datos del perfil que esta pantalla edita.
class ProfileData {
  final String name;
  final String username;
  final String bio;
  final String role;
  final String faculty;
  final String? avatarUrl;
  final String? cvlacUrl;
  final String? websiteUrl;

  const ProfileData({
    this.name = '',
    this.username = '',
    this.bio = '',
    this.role = 'Estudiante',
    this.faculty = '',
    this.avatarUrl,
    this.cvlacUrl,
    this.websiteUrl,
  });
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // ── Controladores de formulario ──
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;
  late final TextEditingController _facultyController;

  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  // ── Estado ──
  File? _selectedImage;
  String _selectedRole = 'Estudiante';
  String _cvlacUrl = '';
  String _websiteUrl = '';
  bool _isSaving = false;
  bool _hasChanges = false;

  // Opciones de Rol en UTB
  static const _roles = [
    'Aspirante',
    'Estudiante',
    'Profesor',
    'Administrador',
  ];

  static const int _maxBioLength = 200;

  // ── Colores del diseño ──
  static const _utbDarkBlue = Color.fromRGBO(0, 26, 63, 1);
  static const _utbBaseBlue = Color.fromRGBO(1, 35, 80, 1);
  static const _utbLightBlue = Color.fromARGB(255, 4, 66, 114);
  static const _primaryBlue = Color(0xFF1565C0);
  static const _sectionHeader = Color(0xFF757575);
  static const _fieldBorder = Color(0xFFE0E0E0);
  static const _validGreen = Color(0xFF4CAF50);

  @override
  void initState() {
    super.initState();
    final data = widget.initialData ?? const ProfileData();
    _nameController = TextEditingController(text: data.name);
    _usernameController = TextEditingController(text: data.username);
    _bioController = TextEditingController(text: data.bio);
    _facultyController = TextEditingController(text: data.faculty);
    
    // Mapeo seguro del rol del backend a las opciones del UI (exactamente 4 permitidas)
    final initialRole = data.role.toLowerCase();
    if (initialRole.contains('profesor') || initialRole.contains('docente')) {
      _selectedRole = 'Profesor';
    } else if (initialRole.contains('admin') || initialRole.contains('moderador') || initialRole.contains('administrativo')) {
      _selectedRole = 'Administrador';
    } else if (initialRole.contains('aspirante')) {
      _selectedRole = 'Aspirante';
    } else {
      _selectedRole = 'Estudiante'; // Fallback seguro
    }

    _cvlacUrl = data.cvlacUrl ?? '';
    _websiteUrl = data.websiteUrl ?? '';

    // Detectar cambios en cualquier campo
    for (final c in [
      _nameController,
      _usernameController,
      _bioController,
      _facultyController,
    ]) {
      c.addListener(_onFieldChanged);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    _facultyController.dispose();
    super.dispose();
  }

  void _onFieldChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  // ── Selección de imagen ──

  /// Muestra opciones para tomar foto o elegir de galería.
  Future<void> _pickImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: _primaryBlue),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: _primaryBlue),
              title: const Text('Elegir de galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _selectedImage = File(pickedFile.path);
        _hasChanges = true;
      });
    }
  }

  // ── Guardar cambios ──

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final api = ApiClient();
      
      final body = {
        'name': _nameController.text.trim(),
        'bio': _bioController.text.trim(),
        'faculty': _facultyController.text.trim(),
        'cvlac_url': _cvlacUrl.trim(),
        'website_url': _websiteUrl.trim(),
      };

      final response = await api.patch(
        AppConfig.profileMeEndpoint,
        body: body,
        requiresAuth: true,
      );

      if (!response.isSuccess) {
        throw Exception(response.error?.message ?? 'Error al actualizar perfil');
      }

      if (_selectedImage != null) {
        final avatarResponse = await api.uploadFile(
          AppConfig.profileAvatarEndpoint,
          file: _selectedImage!,
          fieldName: 'avatar',
        );
        if (!avatarResponse.isSuccess) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Perfil guardado pero falló el avatar: ${avatarResponse.error?.message}')),
           );
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Perfil actualizado correctamente'),
          backgroundColor: _validGreen,
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );

      Navigator.pop(context, true); // Devuelve true para indicar cambios
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al guardar: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => _confirmDiscard(context),
        ),
        title: const Text(
          'Editar perfil',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          children: [
            // ── AVATAR ──
            _buildAvatarSection(),

            const SizedBox(height: 24),

            // ── INFORMACIÓN BÁSICA ──
            _buildSectionHeader('INFORMACIÓN BÁSICA'),
            const SizedBox(height: 12),
            _buildLabeledField(
              label: 'Nombre',
              child: _buildNameField(),
            ),
            const SizedBox(height: 16),
            _buildLabeledField(
              label: 'Usuario',
              child: _buildUsernameField(),
            ),
            // URL preview
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 4),
              child: Text(
                'www.utb-social.edu.co/@${_usernameController.text}',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
            ),

            const SizedBox(height: 24),

            // ── PERFIL ACADÉMICO ──
            _buildSectionHeader('PERFIL ACADÉMICO'),
            const SizedBox(height: 12),
            _buildLabeledField(
              label: 'Biografía',
              trailing:
                  '${_bioController.text.length}/$_maxBioLength',
              child: _buildBioField(),
            ),
            const SizedBox(height: 16),
            _buildLabeledField(
              label: 'Rol en UTB (Solo Lectura)',
              child: TextFormField(
                initialValue: _selectedRole,
                enabled: false,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  fillColor: Colors.grey[100],
                  filled: true,
                ),
                style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500),
              ),
            ),
            const SizedBox(height: 16),
            _buildLabeledField(
              label: 'Facultad / Departamento',
              child: _buildFacultyField(),
            ),

            const SizedBox(height: 24),

            // ── ENLACES ──
            _buildSectionHeader('ENLACES'),
            const SizedBox(height: 12),
            _buildLinkItem(
              icon: Icons.school,
              iconColor: const Color(0xFFE57373),
              title: 'CvLAC / Google Scholar',
              subtitle: widget.initialData?.cvlacUrl != null
                  ? 'Agregado'
                  : null,
              onTap: () => _showLinkEditor(context, 'CvLAC / Google Scholar'),
            ),
            _buildLinkItem(
              icon: Icons.link,
              iconColor: const Color(0xFF90CAF9),
              title: 'Sitio Web Personal',
              subtitle: widget.initialData?.websiteUrl != null
                  ? 'Agregado'
                  : null,
              onTap: () => _showLinkEditor(context, 'Sitio Web Personal'),
            ),

            const SizedBox(height: 28),

            // ── BOTÓN GUARDAR ──
            _buildSaveButton(),

            const SizedBox(height: 20),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  // ─────────────────────────────────────────────────────────────
  //  COMPONENTES DE UI
  // ─────────────────────────────────────────────────────────────

  // ── Avatar ──

  Widget _buildAvatarSection() {
    return Column(
      children: [
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Fondo circular degradado
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Colors.blue.shade100,
                      Colors.blue.shade50,
                    ],
                  ),
                ),
                child: _selectedImage != null
                    ? ClipOval(
                        child: Image.file(
                          _selectedImage!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      )
                    : Icon(Icons.person, size: 54, color: Colors.grey[400]),
              ),
              // Badge de cámara
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: _primaryBlue,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2.5),
                  ),
                  child:
                      const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _pickImage,
          child: const Text(
            'Cambiar foto de perfil',
            style: TextStyle(
              fontSize: 14,
              color: _primaryBlue,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  // ── Headers de sección ──

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: _sectionHeader,
        letterSpacing: 0.5,
      ),
    );
  }

  /// Campo con label encima, y texto trailing opcional (ej. contador).
  Widget _buildLabeledField({
    required String label,
    required Widget child,
    String? trailing,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.grey[700],
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(fontSize: 12, color: Colors.grey[400]),
              ),
          ],
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }

  // ── Campos de formulario ──

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
        suffixIcon: _nameController.text.isNotEmpty
            ? const Icon(Icons.check_circle, color: _validGreen, size: 22)
            : null,
      ),
      style: const TextStyle(fontSize: 15),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El nombre es obligatorio';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildUsernameField() {
    return TextFormField(
      controller: _usernameController,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        prefixText: '@ ',
        prefixStyle: TextStyle(
          fontSize: 15,
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 15),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'El usuario es obligatorio';
        }
        if (value.contains(' ')) {
          return 'El usuario no puede contener espacios';
        }
        return null;
      },
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _buildBioField() {
    return TextFormField(
      controller: _bioController,
      maxLines: 4,
      maxLength: _maxBioLength,
      buildCounter: (_, {required currentLength, required isFocused, maxLength}) =>
          null, // Usamos nuestro propio contador en el label
      decoration: InputDecoration(
        contentPadding: const EdgeInsets.all(14),
        hintText: 'Cuéntanos sobre ti...',
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 14, height: 1.4),
      onChanged: (_) => setState(() {}),
    );
  }
  // Rol dropdown eliminado por seguridad
  Widget _buildFacultyField() {
    return TextFormField(
      controller: _facultyController,
      decoration: InputDecoration(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintText: 'Ej: Facultad de Ingeniería',
        hintStyle: TextStyle(color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _fieldBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primaryBlue, width: 1.5),
        ),
      ),
      style: const TextStyle(fontSize: 15),
    );
  }

  // ── Ítems de enlaces ──

  Widget _buildLinkItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ),
            if (subtitle != null) ...[
              Text(
                subtitle,
                style: TextStyle(fontSize: 13, color: Colors.grey[500]),
              ),
              const SizedBox(width: 4),
            ],
            Icon(Icons.chevron_right, color: Colors.grey[400], size: 24),
          ],
        ),
      ),
    );
  }

  // ── Botón de guardar ──

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: _isSaving ? null : _saveProfile,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.save, size: 20),
        label: Text(
          _isSaving ? 'Guardando...' : 'Guardar cambios',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: _primaryBlue,
          foregroundColor: Colors.white,
          disabledBackgroundColor: Colors.grey[400],
          elevation: 0,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }

  // ── Diálogos ──

  /// Confirma descarte de cambios si hay modificaciones sin guardar.
  void _confirmDiscard(BuildContext context) {
    if (!_hasChanges) {
      Navigator.pop(context);
      return;
    }

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Descartar cambios'),
        content: const Text(
          '¿Estás seguro? Los cambios sin guardar se perderán.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Seguir editando'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Cierra diálogo
              Navigator.pop(context); // Cierra pantalla
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
  }

  /// Editor de enlaces (CvLAC, Web Personal).
  void _showLinkEditor(BuildContext context, String linkType) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(linkType),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: 'https://',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          keyboardType: TextInputType.url,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final newLink = controller.text.trim();
              setState(() {
                if (linkType.contains('CvLAC')) {
                  _cvlacUrl = newLink;
                } else {
                  _websiteUrl = newLink;
                }
                _hasChanges = true;
              });
              Navigator.pop(context);
              ScaffoldMessenger.of(this.context).showSnackBar(
                SnackBar(
                  content: Text('$linkType actualizado'),
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              );
            },
            child: const Text('Guardar'),
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
