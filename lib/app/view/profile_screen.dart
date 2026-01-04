import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'upload_video_screen.dart';
import 'package:image_picker/image_picker.dart';

/// [ProfileScreen] muestra la información del perfil del usuario.
///
/// Actualmente, carga los datos desde un backend local de Go. Si falla,
/// muestra datos de respaldo locales.
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  /// [_profileFuture] almacena el resultado de la llamada a la API del perfil.
  late Future<ProfileModel> _profileFuture;
  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  Future<ProfileModel> _fetchProfile() async {
    // URL para conectar al backend local desde el emulador de Android.
    const String baseUrl = 'http://10.0.2.2:8080/api';
    // --- CAMBIO PARA PRUEBAS ---
    // Leemos el token, pero no lanzamos un error si no existe, ya que el backend
    // está configurado para devolver el usuario con ID 1 de todas formas.
    final token = await _storage.read(key: 'jwt_token');

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/profile/me'),
        headers: {
          'Authorization': 'Bearer ${token ?? 'test-token'}'
        }, // Enviamos un token de relleno si no hay uno real.
      );
      if (response.statusCode == 200) {
        return ProfileModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Fallo al cargar el perfil: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e. Loading local fallback.');
      // Si hay un error (ej. el backend no está corriendo), devuelve datos locales.
      return ProfileModel(
        id: 'local-1',
        username: 'Nombre Estudiante (Local)',
        avatarUrl: '', // URL vacía para mostrar el ícono
      );
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    // 1. Permitir al usuario seleccionar una imagen
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);

    if (image == null) return; // El usuario canceló la selección

    // 2. Preparar la petición multipart
    const String uploadUrl = 'http://10.0.2.2:8080/api/profile/avatar';
    // --- CAMBIO PARA PRUEBAS ---
    // Leemos el token, pero no fallamos si es nulo. Usaremos un valor de relleno.
    final token = await _storage.read(key: 'jwt_token');

    var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
    // Enviamos un token de relleno si no hay uno real. El backend lo ignorará.
    request.headers['Authorization'] = 'Bearer ${token ?? 'test-token'}';
    request.files.add(await http.MultipartFile.fromPath('avatar', image.path));

    // 3. Enviar la petición
    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        debugPrint('Avatar subido con éxito!');
        // 4. Refrescar el perfil para mostrar la nueva imagen
        setState(() {
          _profileFuture = _fetchProfile();
        });
      } else {
        debugPrint('Error al subir el avatar: ${response.statusCode}');
        // Mostrar un SnackBar o diálogo de error al usuario
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Error al subir la imagen.')));
      }
    } catch (e) {
      debugPrint('Excepción al subir el avatar: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Usa un FutureBuilder para manejar el estado de la carga de datos del perfil
    // (cargando, error, datos recibidos).
    return FutureBuilder<ProfileModel>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          final profile = snapshot.data!;
          return _buildProfileView(context, profile);
        }
        return const Center(child: Text('No se pudo cargar el perfil.'));
      },
    );
  }

  /// Construye la vista del perfil una vez que los datos han sido cargados.
  Widget _buildProfileView(BuildContext context, ProfileModel profile) {
    // El color de fondo claro que se ve en la imagen de perfil
    final Color colorFondoPerfil = Colors.blue[100]!.withOpacity(0.7);
    // El color del ícono de perfil circular
    final Color colorIconoPerfil = Colors.blue[300]!;

    void _navigateToUploadVideo() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const UploadVideoScreen(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white, // Fondo blanco como en la imagen
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Icono de Menú superior izquierdo
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 2.5), // Borde negro
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: const Icon(Icons.menu, size: 30, color: Colors.black),
                  ),
                  // Botón de Cerrar Sesión
                  GestureDetector(
                    onTap: widget.onLogout,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 2.5),
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: const Icon(Icons.logout, size: 26, color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Avatar de Perfil Circular
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                // El avatar
                profile.avatarUrl.isNotEmpty
                    ? CircleAvatar(
                        radius: 70,
                        backgroundImage: NetworkImage(profile.avatarUrl),
                        backgroundColor: colorIconoPerfil,
                      )
                    : CircleAvatar(
                        radius: 70,
                        backgroundColor: colorIconoPerfil,
                        child: const Icon(Icons.person, size: 100, color: Colors.white),
                      ),
                // El botón para subir archivo
                GestureDetector(
                  onTap: _uploadAvatar,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Color(0xFF003399),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.edit, color: Colors.white, size: 24),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 30),

            // Contenedor azul inferior
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: colorFondoPerfil, // Azul claro
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(30),
                    topRight: Radius.circular(30),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(25.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        profile.username,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _navigateToUploadVideo,
                        icon: const Icon(Icons.video_call),
                        label: const Text('Subir Video'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF003399),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
