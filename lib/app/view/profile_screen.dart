import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'create_post_sheet.dart';
import 'package:image_picker/image_picker.dart';
import 'api_constants.dart';
import 'package:video_player/video_player.dart';

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
    const String baseUrl = ApiConstants.apiUrl;
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
    const String uploadUrl = '${ApiConstants.apiUrl}/profile/avatar';
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
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Iconos oscuros para fondo claro
        statusBarBrightness: Brightness.light,    // Iconos oscuros (iOS)
      ),
      child: FutureBuilder<ProfileModel>(
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
      ),
    );
  }

  /// Construye la vista del perfil una vez que los datos han sido cargados.
  Widget _buildProfileView(BuildContext context, ProfileModel profile) {
    // Dimensiones para el diseño tipo X (Twitter)
    const double coverHeight = 160.0;
    const double avatarRadius = 45.0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: DefaultTabController(
        length: 2,
        child: NestedScrollView(
          headerSliverBuilder: (context, innerBoxIsScrolled) {
            return [
              SliverToBoxAdapter(
                child: Stack(
                  children: [
                    // Contenido del Header (Portada + Info)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Imagen de Portada
                        Container(
                          height: coverHeight,
                          width: double.infinity,
                          decoration: const BoxDecoration(
                            image: DecorationImage(
                              image: AssetImage('assets/images/Gemini_nueva.png'),
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        // Espacio y Contenido de Texto
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Espacio para el botón de editar (alineado con el avatar visualmente)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 12.0),
                                    child: OutlinedButton(
                                      onPressed: _uploadAvatar,
                                      style: OutlinedButton.styleFrom(
                                        shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20)),
                                        side: BorderSide(color: Colors.grey.shade300),
                                      ),
                                      child: const Text('Editar perfil',
                                          style: TextStyle(color: Colors.black)),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                profile.username,
                                style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.black),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Profesor tanto en pregrado como en posgrados en las áreas de Redes y Comunicación de Datos, Sistemas Operativos, Ingeniería de Software y Educación Apoyada en TIC. ',
                                style: TextStyle(fontSize: 15, height: 1.4, color: Colors.black87),
                              ),
                              const SizedBox(height: 20),
                            ],
                          ),
                        ),
                      ],
                    ),
                    // Avatar Superpuesto
                    Positioned(
                      top: coverHeight - avatarRadius,
                      left: 16.0,
                      child: GestureDetector(
                        onTap: _uploadAvatar,
                        child: Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 4.0),
                          ),
                          child: CircleAvatar(
                            radius: avatarRadius,
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: const AssetImage('assets/images/imagen1.jpg'),
                          ),
                        ),
                      ),
                    ),
                    // Menú Superior Derecho
                    Positioned(
                      top: 0,
                      right: 0,
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.black38,
                              shape: BoxShape.circle,
                            ),
                            child: PopupMenuButton<String>(
                              icon: const Icon(Icons.menu, color: Colors.white),
                              onSelected: (value) {
                                if (value == 'logout') {
                                  widget.onLogout();
                                } else if (value == 'create_post') {
                                  showCreatePostSheet(context);
                                }
                              },
                              itemBuilder: (BuildContext context) =>
                                  <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'settings',
                                  child: Row(children: [
                                    Icon(Icons.settings, color: Colors.black87),
                                    SizedBox(width: 10),
                                    Text('Ajustes')
                                  ]),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'create_post',
                                  child: Row(children: [
                                    Icon(Icons.add_circle_outline, color: Colors.black87),
                                    SizedBox(width: 10),
                                    Text('Crear publicación')
                                  ]),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'logout',
                                  child: Row(children: [
                                    Icon(Icons.logout, color: Colors.black87),
                                    SizedBox(width: 10),
                                    Text('Cerrar Sesión')
                                  ]),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Barra de Pestañas (Sticky)
              SliverOverlapAbsorber(
                handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                sliver: SliverPersistentHeader(
                  delegate: _SliverAppBarDelegate(
                    const TabBar(
                      indicatorColor: Color(0xFF003399),
                      indicatorSize: TabBarIndicatorSize.tab,
                      labelColor: Colors.black,
                      unselectedLabelColor: Colors.grey,
                      labelStyle: TextStyle(fontWeight: FontWeight.bold),
                      tabs: [
                        Tab(text: 'STATS'),
                        Tab(text: 'PUBLICACIONES'),
                      ],
                    ),
                  ),
                  pinned: true,
                ),
              ),
            ];
          },
          body: TabBarView(
            children: [
              _buildStatsTab(),
              _buildPostsTab(profile),
            ],
          ),
        ),
      ),
    );
  }

  // --- WIDGETS DE LAS PESTAÑAS ---

  Widget _buildStatsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
            children: [
              _buildStatCard('Publicaciones', '12', Icons.article, Colors.blue),
              _buildStatCard('Seguidores', '1.2k', Icons.people, Colors.purple),
              _buildStatCard('Accuracy', '85%', Icons.show_chart, Colors.green),
              _buildStatCard('Progreso', 'Lvl 5', Icons.star, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(height: 8),
          Text(value,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.black)),
          Text(title,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        ],
      ),
    );
  }

  Widget _buildPostsTab(ProfileModel profile) {
    return _ProfilePostsTab(profile: profile);
  }
}

/// Clase auxiliar para hacer que el TabBar se quede fijo (sticky) al hacer scroll.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar _tabBar;

  _SliverAppBarDelegate(this._tabBar);

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white, // Fondo blanco para que no sea transparente al pegar
      child: _tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}

/// Widget interno para manejar el estado y diseño de la pestaña de publicaciones
class _ProfilePostsTab extends StatefulWidget {
  final ProfileModel profile;
  const _ProfilePostsTab({required this.profile});

  @override
  State<_ProfilePostsTab> createState() => _ProfilePostsTabState();
}

class _ProfilePostsTabState extends State<_ProfilePostsTab> {
  // 0: Reels, 1: Imágenes, 2: Flashcards
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _categories = [
    {'label': 'Reels', 'icon': Icons.videocam_outlined},
    {'label': 'Imágenes', 'icon': Icons.grid_on},
    {'label': 'Flashcards', 'icon': Icons.style_outlined},
  ];

  @override
  Widget build(BuildContext context) {
    // Usamos CustomScrollView para que funcione bien dentro del NestedScrollView principal
    return CustomScrollView(
      key: const PageStorageKey<String>('posts_tab'),
      slivers: [
        SliverOverlapInjector(
          handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
        ),
        // Selector de Categorías
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Colors.black12, width: 0.5)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(_categories.length, (index) {
                final isSelected = _selectedIndex == index;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _selectedIndex = index),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        border: isSelected
                            ? const Border(bottom: BorderSide(color: Colors.black87, width: 2))
                            : null,
                      ),
                      child: Icon(
                        _categories[index]['icon'],
                        color: isSelected ? Colors.black87 : Colors.grey.shade400,
                        size: 26,
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        // Grid de Publicaciones
        SliverPadding(
          padding: const EdgeInsets.all(1.0),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 columnas como solicitado
              crossAxisSpacing: 1.5,
              mainAxisSpacing: 1.5,
              childAspectRatio: 0.65, // Relación de aspecto vertical (tipo Reels)
            ),
            delegate: SliverChildBuilderDelegate(
              (BuildContext context, int index) {
                return _buildGridItem(index);
              },
              childCount: 6, // 2 filas de 3 columnas = 6 items
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridItem(int index) {
    if (_selectedIndex == 0) {
      // Reels: Mostrar el video de assets
      return Stack(
        fit: StackFit.expand,
        children: [
          const _GridVideoItem(assetPath: 'assets/videos/v1.mp4'),
          Positioned(
            bottom: 6,
            left: 6,
            child: Row(
              children: [
                const Icon(Icons.play_arrow, color: Colors.white, size: 14),
                Text(
                  "${(index + 1) * 150} views",
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      );
    }

    Color baseColor;
    IconData typeIcon;
    String overlayText = "";

    switch (_selectedIndex) {
      case 1: // Imágenes
        baseColor = Colors.grey.shade300;
        typeIcon = Icons.image;
        break;
      case 2: // Flashcards
        baseColor = const Color(0xFF003399).withOpacity(0.8);
        typeIcon = Icons.style;
        overlayText = "Set #${index + 1}";
        break;
      default:
        baseColor = Colors.grey;
        typeIcon = Icons.error;
    }

    return Container(
      decoration: BoxDecoration(
        color: baseColor,
        image: _selectedIndex == 1
            ? const DecorationImage(
                image: AssetImage('assets/images/image.png'), // Placeholder para imágenes
                fit: BoxFit.cover,
              )
            : null,
      ),
      child: Stack(
        children: [
          if (_selectedIndex != 1)
            Center(
              child: Icon(typeIcon, color: Colors.white.withOpacity(0.5), size: 32),
            ),
          if (overlayText.isNotEmpty)
            Positioned(
              bottom: 6,
              left: 6,
              child: Row(
                children: [
                  Text(
                    overlayText,
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GridVideoItem extends StatefulWidget {
  final String assetPath;
  const _GridVideoItem({required this.assetPath});

  @override
  State<_GridVideoItem> createState() => _GridVideoItemState();
}

class _GridVideoItemState extends State<_GridVideoItem> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.asset(widget.assetPath)
      ..initialize().then((_) {
        if (mounted) {
          setState(() {
            _isInitialized = true;
          });
        }
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Container(
        color: Colors.grey.shade900,
        child: const Center(child: Icon(Icons.video_library, color: Colors.white54)),
      );
    }
    return ClipRect(
      child: Container(
        color: Colors.black,
        child: FittedBox(
          fit: BoxFit.cover,
          child: SizedBox(
            width: _controller.value.size.width,
            height: _controller.value.size.height,
            child: VideoPlayer(_controller),
          ),
        ),
      ),
    );
  }
}
