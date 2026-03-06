import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'upload_video_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'config/app_config.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'notifications_screen.dart';

/// [ProfileScreen] muestra el perfil del usuario con tabs de Stats y Publicaciones.
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen>
    with SingleTickerProviderStateMixin {
  late Future<ProfileModel> _profileFuture;
  final _storage = const FlutterSecureStorage();
  late TabController _tabController;
  int _selectedPublicationTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _profileFuture = _fetchProfile();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<ProfileModel> _fetchProfile() async {
    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      throw Exception('No hay token de autenticación');
    }

    try {
      final response = await http
          .get(
            Uri.parse(AppConfig.profileMeEndpoint),
            headers: {'Authorization': 'Bearer $token'},
          )
          .timeout(Duration(seconds: AppConfig.httpTimeoutSeconds));
      if (response.statusCode == 200) {
        return ProfileModel.fromJson(json.decode(response.body));
      } else {
        throw Exception('Fallo al cargar el perfil: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Error fetching profile: $e. Loading local fallback.');
      return ProfileModel(
        id: 'local-1',
        username: 'Carlos David',
        avatarUrl: '',
        role: 'profesor',
      );
    }
  }

  Future<void> _uploadAvatar() async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión expirada.')),
        );
      }
      return;
    }

    var request = http.MultipartRequest(
        'POST', Uri.parse(AppConfig.profileAvatarEndpoint));
    request.headers['Authorization'] = 'Bearer $token';
    request.files
        .add(await http.MultipartFile.fromPath('avatar', image.path));

    try {
      final response = await request.send();
      if (response.statusCode == 200) {
        setState(() => _profileFuture = _fetchProfile());
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la imagen.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al subir la imagen.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ProfileModel>(
      future: _profileFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (snapshot.hasData) {
          return _buildProfileView(context, snapshot.data!);
        }
        return const Center(child: Text('No se pudo cargar el perfil.'));
      },
    );
  }

  Widget _buildProfileView(BuildContext context, ProfileModel profile) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: profile.canUploadVideos
          ? FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (context) => const UploadVideoScreen()),
              ),
              backgroundColor: const Color(0xFF003399),
              foregroundColor: Colors.white,
              elevation: 4,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 32),
            )
          : null,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            // Banner + Avatar + Info
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Banner con degradado
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 160,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF001F60),
                              Color(0xFF003399),
                              Color(0xFF0044CC),
                              Color(0xFF1E88E5),
                            ],
                            stops: [0.0, 0.4, 0.7, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                        child: Stack(
                          children: [
                            // Decoración geométrica sutil
                            Positioned(
                              right: 20,
                              top: 30,
                              child: CustomPaint(
                                size: const Size(120, 120),
                                painter: _GeometricPainter(),
                              ),
                            ),
                            // Botón de menú y notificaciones
                            Positioned(
                              top: 40,
                              right: 12,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.notifications_none, color: Colors.white, size: 28),
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                                      );
                                    },
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.menu,
                                        color: Colors.white, size: 28),
                                    onSelected: (value) {
                                      if (value == 'settings') {
                                        Navigator.of(context).push(
                                          MaterialPageRoute(
                                            builder: (_) => SettingsScreen(onLogout: widget.onLogout),
                                          ),
                                        );
                                      } else if (value == 'logout') {
                                        widget.onLogout();
                                      }
                                    },
                                    itemBuilder: (context) => [
                                      const PopupMenuItem(
                                        value: 'settings',
                                        child: Row(
                                          children: [
                                            Icon(Icons.settings, color: Colors.black54),
                                            SizedBox(width: 8),
                                            Text('Configuración'),
                                          ],
                                        ),
                                      ),
                                      const PopupMenuItem(
                                        value: 'logout',
                                        child: Row(
                                          children: [
                                            Icon(Icons.logout, color: Colors.red),
                                            SizedBox(width: 8),
                                            Text('Cerrar Sesión'),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Avatar sobre el banner
                      Positioned(
                        bottom: -40,
                        left: 20,
                        child: GestureDetector(
                          onTap: _uploadAvatar,
                          child: Container(
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                            ),
                            padding: const EdgeInsets.all(4),
                            child: profile.avatarUrl.isNotEmpty
                                ? CircleAvatar(
                                    radius: 45,
                                    backgroundImage:
                                        NetworkImage(profile.avatarUrl),
                                  )
                                : const CircleAvatar(
                                    radius: 45,
                                    backgroundColor: Color(0xFF90CAF9),
                                    child: Icon(Icons.person,
                                        size: 50, color: Colors.white),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Botón editar perfil
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 16, top: 4),
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF003399), width: 1.5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20)),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 8),
                        ),
                        child: const Text('Editar perfil',
                            style: TextStyle(
                                color: Color(0xFF003399), fontSize: 14, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  // Nombre y bio
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile.username,
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          profile.role == 'profesor'
                              ? 'Profesor en pregrado como en posgrados en las áreas de Redes y Comunicación de Datos, Sistemas Operativos, Ingeniería de Software y Educación Apoyada en TIC.'
                              : profile.role == 'admin'
                                  ? 'Administrador del sistema UTBGO'
                                  : profile.role == 'aspirante'
                                      ? 'Aspirante'
                                      : 'Estudiante de la UTB',
                          style: const TextStyle(
                              fontSize: 13, color: Colors.black87, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // Tabs
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: Colors.black,
                  unselectedLabelColor: Colors.grey,
                  indicatorColor: const Color(0xFF003399),
                  tabs: const [
                    Tab(text: 'STATS'),
                    Tab(text: 'PUBLICACIONES'),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            // Tab STATS
            _buildStatsTab(profile),
            // Tab PUBLICACIONES
            _buildPublicationsTab(profile),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(ProfileModel profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                  child: _statCard(
                      Icons.article, '12', 'Publicaciones', Colors.blue)),
              const SizedBox(width: 16),
              Expanded(
                  child: _statCard(Icons.people, '1.2k', 'Seguidores',
                      Colors.deepPurple)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                  child: _statCard(
                      Icons.trending_up, '85%', 'Accuracy', Colors.green)),
              const SizedBox(width: 16),
              Expanded(
                  child:
                      _statCard(Icons.star, 'Lvl 5', 'Progreso', Colors.orange)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPublicationsTab(ProfileModel profile) {
    return Column(
      children: [
        // Sub-tabs de tipo contenido
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _contentTypeIcon(index: 0, icon: Icons.videocam),
              _contentTypeIcon(index: 1, icon: Icons.grid_on),
              _contentTypeIcon(index: 2, icon: Icons.style),
            ],
          ),
        ),
        // Grid de videos
        Expanded(
          child: _selectedPublicationTab == 0
              ? GridView.builder(
                  padding: const EdgeInsets.all(2),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: 6,
                  itemBuilder: (context, index) {
                    final views = [150, 300, 450, 120, 280, 500];
                    final colors = [
                      const Color(0xFF455A64),
                      const Color(0xFF37474F),
                      const Color(0xFF546E7A),
                      const Color(0xFF263238),
                      const Color(0xFF4DB6AC),
                      const Color(0xFF78909C),
                    ];
                    return ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail con gradiente
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  colors[index % colors.length],
                                  colors[index % colors.length]
                                      .withValues(alpha: 0.6),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.play_circle_filled,
                                    size: 44,
                                    color: Colors.white.withValues(alpha: 0.7)),
                                const SizedBox(height: 6),
                                Text('Video ${index + 1}',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.8),
                                        fontSize: 11)),
                              ],
                            ),
                          ),
                          // Gradiente oscuro abajo
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: 32,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.transparent,
                                    Colors.black.withValues(alpha: 0.7),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                          // Views overlay
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.play_arrow,
                                    color: Colors.white, size: 14),
                                const SizedBox(width: 2),
                                Text(
                                  '${views[index % views.length]} Views',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                )
              : Center(
                  child: Text(
                    _selectedPublicationTab == 1
                        ? 'No hay imágenes'
                        : 'No hay flashcards',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _statCard(IconData icon, String value, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA), // Muy sutil, casi blanco
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(value,
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ],
      ),
    );
  }

  Widget _contentTypeIcon({required int index, required IconData icon}) {
    final selected = _selectedPublicationTab == index;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedPublicationTab = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        color: Colors.transparent, // Expand hitting area
        child: Icon(
          icon,
          size: 26,
          color: selected ? Colors.black87 : Colors.grey.shade500,
        ),
      ),
    );
  }
}

/// Delegate para el TabBar sticky.
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(context, shrinkOffset, overlapsContent) {
    return Container(color: Colors.white, child: tabBar);
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}

/// Pinta formas geométricas decorativas en el banner.
class _GeometricPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Dibujamos arcos suaves simulando una red abstracta
    final strokePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Curva principal
    final path1 = Path()
      ..moveTo(0, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.5, size.height * -0.1, size.width, size.height * 0.3)
      ..quadraticBezierTo(size.width * 1.5, size.height * 0.7, size.width * 2, size.height * 0.2);
    canvas.drawPath(path1, strokePaint);

    // Curva secundaria
    final path2 = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 1.2, size.width * 0.8, size.height * 0.7)
      ..quadraticBezierTo(size.width * 1.3, size.height * 0.2, size.width, size.height * -0.2);
    canvas.drawPath(path2, strokePaint);

    // Arcos
    canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.8, size.height * 0.2), radius: 80),
        0, 3.14, false, strokePaint);

    canvas.drawArc(
        Rect.fromCircle(center: Offset(size.width * 0.1, size.height * 0.1), radius: 120),
        0.5, 2.5, false, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
