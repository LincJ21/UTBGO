import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'profile_model.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'upload_video_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';
import 'services/global_ui_service.dart';
import 'settings_screen.dart';
import 'edit_profile_screen.dart';
import 'admin_panel_screen.dart';
import 'connections_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import 'video_model.dart';
import 'single_video_screen.dart';

/// [ProfileScreen] muestra el perfil del usuario con tabs de Stats y Publicaciones.
class ProfileScreen extends StatefulWidget {
  final VoidCallback onLogout;

  const ProfileScreen({super.key, required this.onLogout});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late Future<ProfileModel> _profileFuture;
  final _storage = const FlutterSecureStorage();
  int _selectedPublicationTab = 0;

  final _apiClient = ApiClient();

  @override
  void initState() {
    super.initState();
    _profileFuture = _fetchProfile();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<ProfileModel> _fetchProfile() async {
    final response = await _apiClient.get<ProfileModel>(
      AppConfig.profileMeEndpoint,
      requiresAuth: true,
      fromJson: (json) => ProfileModel.fromJson(json),
    );

    if (response.isSuccess && response.data != null) {
      return response.data!;
    } else {
      final errorMsg = response.error?.message ?? 'Error desconocido';
      if (mounted) {
        GlobalUIService.showError('Perfil falló: $errorMsg');
      }
      debugPrint('Error fetching profile: $errorMsg. Loading local fallback.');
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
    request.files.add(await http.MultipartFile.fromPath('avatar', image.path));

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

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(
        urlString.startsWith('http') ? urlString : 'https://$urlString');
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        GlobalUIService.showError('No se pudo abrir el enlace.');
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
    final isCreator = profile.role == 'profesor' || profile.role == 'admin';

    final tabs = isCreator
        ? const [
            Tab(text: 'STATS'),
            Tab(text: 'PUBLICACIONES'),
            Tab(icon: Icon(Icons.repeat)),
            Tab(icon: Icon(Icons.bookmark_border)),
          ]
        : const [
            Tab(text: 'STATS'),
            Tab(icon: Icon(Icons.repeat)),
            Tab(icon: Icon(Icons.bookmark_border)),
          ];

    final tabViews = isCreator
        ? [
            _buildNestedStatsTab(profile),
            _buildNestedPublicationsTab(profile),
            _buildNestedRepostsTab(profile),
            _buildNestedBookmarksTab(profile),
          ]
        : [
            _buildNestedStatsTab(profile),
            _buildNestedRepostsTab(profile),
            _buildNestedBookmarksTab(profile),
          ];

    return DefaultTabController(
        length: tabs.length,
        child: Scaffold(
          backgroundColor: Colors.white,
          endDrawer: _buildRightDrawer(context, profile),
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
                                // Botón de atrás dinámico (si fue abierto desde otra pantalla, no desde pestañas base)
                                if (Navigator.canPop(context))
                                  Positioned(
                                    top: 40,
                                    left: 12,
                                    child: IconButton(
                                      icon: const Icon(Icons.arrow_back,
                                          color: Colors.white, size: 28),
                                      onPressed: () => Navigator.pop(context),
                                    ),
                                  ),
                                // Botón de menú y notificaciones
                                Positioned(
                                  top: 40,
                                  right: 12,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Builder(
                                        builder: (innerContext) => IconButton(
                                          icon: const Icon(Icons.menu,
                                              color: Colors.white, size: 28),
                                          onPressed: () {
                                            Scaffold.of(innerContext)
                                                .openEndDrawer();
                                          },
                                        ),
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
                            onPressed: () async {
                              final didSave =
                                  await Navigator.of(context).push<bool>(
                                MaterialPageRoute(
                                  builder: (_) => EditProfileScreen(
                                    initialData: ProfileData(
                                      name: profile
                                          .username, // mapping username -> name because ProfileModel groups them
                                      username: '',
                                      bio: profile.bio ?? '',
                                      faculty: profile.faculty ?? '',
                                      role: profile.role,
                                      cvlacUrl: profile.cvlacUrl,
                                      websiteUrl: profile.websiteUrl,
                                      avatarUrl: profile.avatarUrl.isNotEmpty
                                          ? profile.avatarUrl
                                          : null,
                                    ),
                                  ),
                                ),
                              );
                              if (didSave == true) {
                                setState(
                                    () => _profileFuture = _fetchProfile());
                              }
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(
                                  color: Color(0xFF003399), width: 1.5),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 24, vertical: 8),
                            ),
                            child: const Text('Editar perfil',
                                style: TextStyle(
                                    color: Color(0xFF003399),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      // Nombre y bio
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.5,
                                color: Color(0xFF1E293B),
                              ),
                            ),
                            if (profile.faculty != null &&
                                profile.faculty!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.school,
                                      size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      profile.faculty!,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF64748B),
                                          fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            Text(
                              (profile.bio != null && profile.bio!.isNotEmpty)
                                  ? profile.bio!
                                  : (profile.role == 'profesor'
                                      ? 'Profesor de la Universidad Tecnológica de Bolívar.'
                                      : profile.role == 'admin'
                                          ? 'Administrador del sistema UTBGO'
                                          : 'Estudiante de la UTB'),
                              style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF334155),
                                  height: 1.5),
                            ),
                            if ((profile.cvlacUrl != null &&
                                    profile.cvlacUrl!.isNotEmpty) ||
                                (profile.websiteUrl != null &&
                                    profile.websiteUrl!.isNotEmpty)) ...[
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  if (profile.cvlacUrl != null &&
                                      profile.cvlacUrl!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 10),
                                      child: Material(
                                        color: Colors.red.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(20),
                                        child: InkWell(
                                          onTap: () =>
                                              _launchURL(profile.cvlacUrl!),
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 12, vertical: 6),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.school,
                                                    size: 14,
                                                    color: Colors.red[400]),
                                                const SizedBox(width: 6),
                                                const Text('CvLAC',
                                                    style: TextStyle(
                                                        fontSize: 13,
                                                        color: Colors.red,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (profile.websiteUrl != null &&
                                      profile.websiteUrl!.isNotEmpty)
                                    Material(
                                      color: Colors.blue.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(20),
                                      child: InkWell(
                                        onTap: () =>
                                            _launchURL(profile.websiteUrl!),
                                        borderRadius: BorderRadius.circular(20),
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 6),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.language,
                                                  size: 14, color: Colors.blue),
                                              SizedBox(width: 6),
                                              Text('Website',
                                                  style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.blue,
                                                      fontWeight:
                                                          FontWeight.w600)),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
                // Tabs
                SliverOverlapAbsorber(
                  handle:
                      NestedScrollView.sliverOverlapAbsorberHandleFor(context),
                  sliver: SliverPersistentHeader(
                    pinned: true,
                    delegate: _TabBarDelegate(
                      TabBar(
                        isScrollable: isCreator,
                        tabAlignment:
                            isCreator ? TabAlignment.center : TabAlignment.fill,
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 24),
                        labelStyle: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.bold),
                        unselectedLabelStyle: const TextStyle(
                            fontSize: 12.5, fontWeight: FontWeight.w500),
                        labelColor: Colors.black,
                        unselectedLabelColor: Colors.grey,
                        indicatorColor: const Color(0xFF003399),
                        tabs: tabs,
                      ),
                    ),
                  ),
                ),
              ];
            },
            body: TabBarView(
              children: tabViews,
            ),
          ),
        ));
  }

  Widget _buildStatsTab(ProfileModel profile) {
    return _buildTabScrollView(
      storageKey: 'profile-stats',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _statCard(
                            Icons.video_library,
                            profile.totalVideos.toString(),
                            'Publicaciones',
                            Colors.blue)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _statCard(Icons.people,
                            profile.followers.toString(), 'Seguidores', Colors.deepPurple)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _statCard(Icons.favorite,
                            profile.totalLikes.toString(), 'Me gustas', Colors.pink)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _statCard(
                            Icons.visibility,
                            profile.totalViews.toString(),
                            'Visualizaciones',
                            Colors.orange)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
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
        // Grid de contenidos reales
        Expanded(
          child: FutureBuilder<ApiResponse<List<VideoModel>>>(
            future: _apiClient.get<List<VideoModel>>(
              AppConfig.profilePublicationsEndpoint,
              requiresAuth: true,
              fromJson: (json) {
                final List<dynamic> videoJson = (json as List<dynamic>?) ?? [];
                return videoJson
                    .map((v) => VideoModel.fromBackendJson(v))
                    .toList();
              },
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError ||
                  !snapshot.hasData ||
                  !snapshot.data!.isSuccess) {
                return const Center(
                  child: Text('Error al cargar publicaciones',
                      style: TextStyle(color: Colors.grey)),
                );
              }

              final allVideos = snapshot.data!.data ?? [];

              // Filtrar según el sub-tab seleccionado
              List<VideoModel> filteredVideos = [];
              if (_selectedPublicationTab == 0) {
                filteredVideos =
                    allVideos.where((v) => v.contentType == 'video').toList();
              } else if (_selectedPublicationTab == 1) {
                filteredVideos =
                    allVideos.where((v) => v.contentType == 'poll').toList();
              } else if (_selectedPublicationTab == 2) {
                filteredVideos = allVideos
                    .where((v) => v.contentType == 'flashcard')
                    .toList();
              }

              if (filteredVideos.isEmpty) {
                return Center(
                  child: Text(
                    _selectedPublicationTab == 0
                        ? 'No hay videos'
                        : _selectedPublicationTab == 1
                            ? 'No hay encuestas'
                            : 'No hay flashcards',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                );
              }

              return GridView.builder(
                padding: const EdgeInsets.all(2),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                itemCount: filteredVideos.length,
                itemBuilder: (context, index) {
                  final video = filteredVideos[index];

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => SingleVideoScreen(
                            video: video,
                            showFeedTopBar: false,
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Thumbnail oscuro o imagen
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              image: video.thumbnailUrl.isNotEmpty
                                  ? DecorationImage(
                                      image: NetworkImage(video.thumbnailUrl),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                          ),
                          // Overlay para que resalte el texto
                          Container(color: Colors.black.withOpacity(0.3)),

                          // Icono Central
                          Center(
                            child: Icon(
                              video.contentType == 'poll'
                                  ? Icons.poll_outlined
                                  : video.contentType == 'flashcard'
                                      ? Icons.style_outlined
                                      : Icons.play_circle_outline,
                              color: Colors.white.withOpacity(0.8),
                              size: 32,
                            ),
                          ),

                          // Views/Likes overlay
                          Positioned(
                            bottom: 6,
                            left: 6,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.favorite,
                                    color: Colors.white, size: 12),
                                const SizedBox(width: 4),
                                Text(
                                  '${video.likes}',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
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

  Widget _buildRepostsTab(ProfileModel profile) {
    return FutureBuilder<List<VideoModel>>(
      future: _apiClient.get<List<VideoModel>>(
        AppConfig.profileRepostsEndpoint,
        requiresAuth: true,
        fromJson: (json) {
          final list = json as List<dynamic>;
          return list.map((e) => VideoModel.fromBackendJson(e)).toList();
        },
      ).then((response) =>
          (response.isSuccess && response.data != null) ? response.data! : []),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.repeat, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aún no has reposteado nada',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final videos = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
            childAspectRatio: 0.7,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SingleVideoScreen(
                      video: video,
                      showFeedTopBar: false,
                    ),
                  ),
                );
              },
              child: Stack(
                fit: StackFit.expand,
                children: [
                  video.thumbnailUrl.isNotEmpty
                      ? Image.network(
                          video.thumbnailUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.error)),
                        )
                      : Container(
                          color: Colors.grey[800],
                          child: const Icon(Icons.video_library,
                              color: Colors.white54)),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Row(
                      children: [
                        const Icon(Icons.play_arrow_outlined,
                            color: Colors.white, size: 16),
                        const SizedBox(width: 2),
                        Text(
                          '${video.views}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBookmarksTab(ProfileModel profile) {
    return FutureBuilder<List<VideoModel>>(
      future: _apiClient.get<List<VideoModel>>(
        AppConfig.profileBookmarksEndpoint,
        requiresAuth: true,
        fromJson: (json) {
          final list = json as List<dynamic>;
          return list.map((e) => VideoModel.fromBackendJson(e)).toList();
        },
      ).then((response) =>
          (response.isSuccess && response.data != null) ? response.data! : []),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
                SizedBox(height: 16),
                Text(
                  'Aún no hay videos guardados',
                  style: TextStyle(color: Colors.grey, fontSize: 16),
                ),
              ],
            ),
          );
        }

        final videos = snapshot.data!;
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: videos.length,
          itemBuilder: (context, index) {
            final video = videos[index];
            final thumbUrl = video.thumbnailUrl.isNotEmpty
                ? video.thumbnailUrl
                : video.videoUrl;
            return GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => SingleVideoScreen(
                      video: video,
                      showFeedTopBar: false,
                    ),
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    thumbUrl.isNotEmpty
                        ? Image.network(
                            thumbUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.play_circle_filled,
                                        color: Colors.white, size: 40)),
                          )
                        : Container(
                            color: Colors.grey[800],
                            child: const Icon(Icons.play_circle_filled,
                                color: Colors.white, size: 40)),
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
                              Colors.black.withOpacity(0.7)
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 6,
                      left: 6,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.favorite,
                              color: Colors.white, size: 14),
                          const SizedBox(width: 2),
                          Text('${video.likes}',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildNestedStatsTab(ProfileModel profile) {
    return _buildTabScrollView(
      storageKey: 'profile-stats',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                        child: _statCard(
                            Icons.video_library,
                            profile.totalVideos.toString(),
                            'Publicaciones',
                            Colors.blue)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _statCard(Icons.people,
                            profile.followers.toString(), 'Seguidores', Colors.deepPurple)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _statCard(Icons.favorite,
                            profile.totalLikes.toString(), 'Me gustas', Colors.pink)),
                    const SizedBox(width: 16),
                    Expanded(
                        child: _statCard(
                            Icons.visibility,
                            profile.totalViews.toString(),
                            'Visualizaciones',
                            Colors.orange)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNestedPublicationsTab(ProfileModel profile) {
    return FutureBuilder<ApiResponse<List<VideoModel>>>(
      future: _apiClient.get<List<VideoModel>>(
        AppConfig.profilePublicationsEndpoint,
        requiresAuth: true,
        fromJson: (json) {
          final List<dynamic> videoJson = (json as List<dynamic>?) ?? [];
          return videoJson.map((v) => VideoModel.fromBackendJson(v)).toList();
        },
      ),
      builder: (context, snapshot) {
        final leadingSlivers = <Widget>[_buildPublicationFilterSliver()];

        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildTabScrollView(
            storageKey: 'profile-publications-loading',
            slivers: [
              ...leadingSlivers,
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }

        if (snapshot.hasError || !snapshot.hasData || !snapshot.data!.isSuccess) {
          return _buildTabScrollView(
            storageKey: 'profile-publications-error',
            slivers: [
              ...leadingSlivers,
              const SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    'Error al cargar publicaciones',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
              ),
            ],
          );
        }

        final allVideos = snapshot.data!.data ?? [];
        List<VideoModel> filteredVideos = [];
        if (_selectedPublicationTab == 0) {
          filteredVideos =
              allVideos.where((v) => v.contentType == 'video').toList();
        } else if (_selectedPublicationTab == 1) {
          filteredVideos =
              allVideos.where((v) => v.contentType == 'poll').toList();
        } else if (_selectedPublicationTab == 2) {
          filteredVideos =
              allVideos.where((v) => v.contentType == 'flashcard').toList();
        }

        if (filteredVideos.isEmpty) {
          return _buildTabScrollView(
            storageKey: 'profile-publications-empty-$_selectedPublicationTab',
            slivers: [
              ...leadingSlivers,
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Text(
                    _selectedPublicationTab == 0
                        ? 'No hay videos'
                        : _selectedPublicationTab == 1
                            ? 'No hay encuestas'
                            : 'No hay flashcards',
                    style: const TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ),
              ),
            ],
          );
        }

        return _buildTabScrollView(
          storageKey: 'profile-publications-$_selectedPublicationTab',
          slivers: [
            ...leadingSlivers,
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = filteredVideos[index];

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SingleVideoScreen(
                              video: video,
                              showFeedTopBar: false,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                image: video.thumbnailUrl.isNotEmpty
                                    ? DecorationImage(
                                        image: NetworkImage(video.thumbnailUrl),
                                        fit: BoxFit.cover,
                                      )
                                    : null,
                              ),
                            ),
                            Container(color: Colors.black.withOpacity(0.3)),
                            Center(
                              child: Icon(
                                video.contentType == 'poll'
                                    ? Icons.poll_outlined
                                    : video.contentType == 'flashcard'
                                        ? Icons.style_outlined
                                        : Icons.play_circle_outline,
                                color: Colors.white.withOpacity(0.8),
                                size: 32,
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              left: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.favorite,
                                      color: Colors.white, size: 12),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${video.likes}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: filteredVideos.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNestedRepostsTab(ProfileModel profile) {
    return FutureBuilder<List<VideoModel>>(
      future: _apiClient.get<List<VideoModel>>(
        AppConfig.profileRepostsEndpoint,
        requiresAuth: true,
        fromJson: (json) {
          final list = json as List<dynamic>;
          return list.map((e) => VideoModel.fromBackendJson(e)).toList();
        },
      ).then((response) =>
          (response.isSuccess && response.data != null) ? response.data! : []),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildTabScrollView(
            storageKey: 'profile-reposts-loading',
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildTabScrollView(
            storageKey: 'profile-reposts-empty',
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.repeat, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'AÃºn no has reposteado nada',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final videos = snapshot.data!;
        return _buildTabScrollView(
          storageKey: 'profile-reposts',
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                  childAspectRatio: 0.7,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = videos[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SingleVideoScreen(
                              video: video,
                              showFeedTopBar: false,
                            ),
                          ),
                        );
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          video.thumbnailUrl.isNotEmpty
                              ? Image.network(
                                  video.thumbnailUrl,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                          color: Colors.grey[800],
                                          child: const Icon(Icons.error)),
                                )
                              : Container(
                                  color: Colors.grey[800],
                                  child: const Icon(Icons.video_library,
                                      color: Colors.white54)),
                          Positioned(
                            bottom: 4,
                            left: 4,
                            child: Row(
                              children: [
                                const Icon(Icons.play_arrow_outlined,
                                    color: Colors.white, size: 16),
                                const SizedBox(width: 2),
                                Text(
                                  '${video.views}',
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                  childCount: videos.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildNestedBookmarksTab(ProfileModel profile) {
    return FutureBuilder<List<VideoModel>>(
      future: _apiClient.get<List<VideoModel>>(
        AppConfig.profileBookmarksEndpoint,
        requiresAuth: true,
        fromJson: (json) {
          final list = json as List<dynamic>;
          return list.map((e) => VideoModel.fromBackendJson(e)).toList();
        },
      ).then((response) =>
          (response.isSuccess && response.data != null) ? response.data! : []),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildTabScrollView(
            storageKey: 'profile-bookmarks-loading',
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(child: CircularProgressIndicator()),
              ),
            ],
          );
        }
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _buildTabScrollView(
            storageKey: 'profile-bookmarks-empty',
            slivers: const [
              SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.bookmark_border, size: 48, color: Colors.grey),
                      SizedBox(height: 16),
                      Text(
                        'AÃºn no hay videos guardados',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }

        final videos = snapshot.data!;
        return _buildTabScrollView(
          storageKey: 'profile-bookmarks',
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.all(2),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  childAspectRatio: 0.65,
                  crossAxisSpacing: 2,
                  mainAxisSpacing: 2,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final video = videos[index];
                    final thumbUrl = video.thumbnailUrl.isNotEmpty
                        ? video.thumbnailUrl
                        : video.videoUrl;
                    return GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SingleVideoScreen(
                              video: video,
                              showFeedTopBar: false,
                            ),
                          ),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            thumbUrl.isNotEmpty
                                ? Image.network(
                                    thumbUrl,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) =>
                                        Container(
                                            color: Colors.grey[800],
                                            child:
                                                const Icon(Icons.play_circle_filled,
                                                    color: Colors.white, size: 40)),
                                  )
                                : Container(
                                    color: Colors.grey[800],
                                    child: const Icon(Icons.play_circle_filled,
                                        color: Colors.white, size: 40)),
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
                                      Colors.black.withOpacity(0.7)
                                    ],
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                  ),
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 6,
                              left: 6,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.favorite,
                                      color: Colors.white, size: 14),
                                  const SizedBox(width: 2),
                                  Text('${video.likes}',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  childCount: videos.length,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTabScrollView({
    required String storageKey,
    required List<Widget> slivers,
  }) {
    return Builder(
      builder: (context) => CustomScrollView(
        key: PageStorageKey(storageKey),
        physics: const ClampingScrollPhysics(),
        slivers: [
          SliverOverlapInjector(
            handle: NestedScrollView.sliverOverlapAbsorberHandleFor(context),
          ),
          ...slivers,
        ],
      ),
    );
  }

  Widget _buildPublicationFilterSliver() {
    return SliverToBoxAdapter(
      child: Padding(
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
    );
  }

  Widget _buildRightDrawer(BuildContext context, ProfileModel profile) {
    return Drawer(
      child: Container(
        color: Colors.white,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFF001F60),
                    Color(0xFF003399),
                    Color(0xFF0044CC),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(
                children: [
                  Positioned(
                    bottom: 0,
                    left: 0,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: Colors.white24,
                          backgroundImage: profile.avatarUrl.isNotEmpty
                              ? NetworkImage(profile.avatarUrl)
                              : null,
                          child: profile.avatarUrl.isEmpty
                              ? Text(
                                  profile.username.isNotEmpty
                                      ? profile.username[0].toUpperCase()
                                      : 'U',
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white),
                                )
                              : null,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          profile.username,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          profile.role.isNotEmpty
                              ? '${profile.role[0].toUpperCase()}${profile.role.substring(1)}'
                              : '',
                          style: const TextStyle(
                              color: Colors.white70, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: -10,
                    right: -10,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  )
                ],
              ),
            ),
            if (profile.role == 'admin' || profile.role == 'moderador')
              ListTile(
                leading: const Icon(Icons.admin_panel_settings,
                    color: Color(0xFF0044CC), size: 28),
                title: const Text('Panel de Administración',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Gestionar contenido y usuarios'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => const AdminPanelScreen()));
                },
              ),
            if (profile.role == 'admin' || profile.role == 'moderador')
              const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined,
                  color: Colors.black87, size: 28),
              title: const Text('Configuración',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: const Text('Privacidad y notificaciones'),
              onTap: () {
                Navigator.pop(context);
                Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SettingsScreen(onLogout: widget.onLogout)));
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.people_outline,
                  color: Colors.black87, size: 28),
              title: const Text('Mis Conexiones',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
              subtitle: const Text('Seguidores y seguidos'),
              onTap: () {
                Navigator.pop(context);
                final parsedId = int.tryParse(profile.id) ?? 0;
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ConnectionsScreen(
                      userId: parsedId, username: profile.username),
                ));
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.logout, color: Colors.red, size: 24),
              ),
              title: const Text('Cerrar Sesión',
                  style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                      fontSize: 16)),
              onTap: () {
                Navigator.pop(context);
                widget.onLogout();
              },
            ),
          ],
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
      ..quadraticBezierTo(
          size.width * 0.5, size.height * -0.1, size.width, size.height * 0.3)
      ..quadraticBezierTo(size.width * 1.5, size.height * 0.7, size.width * 2,
          size.height * 0.2);
    canvas.drawPath(path1, strokePaint);

    // Curva secundaria
    final path2 = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(size.width * 0.3, size.height * 1.2, size.width * 0.8,
          size.height * 0.7)
      ..quadraticBezierTo(
          size.width * 1.3, size.height * 0.2, size.width, size.height * -0.2);
    canvas.drawPath(path2, strokePaint);

    // Arcos
    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(size.width * 0.8, size.height * 0.2), radius: 80),
        0,
        3.14,
        false,
        strokePaint);

    canvas.drawArc(
        Rect.fromCircle(
            center: Offset(size.width * 0.1, size.height * 0.1), radius: 120),
        0.5,
        2.5,
        false,
        strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
