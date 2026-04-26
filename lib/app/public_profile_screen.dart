import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/app_config.dart';
import 'video_model.dart';
import 'video_player_widget.dart';

class PublicProfileScreen extends StatefulWidget {
  final int authorId;

  const PublicProfileScreen({super.key, required this.authorId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _storage = const FlutterSecureStorage();
  Map<String, dynamic>? _profileData;
  List<VideoModel>? _publications;
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  
  bool _isFollowing = false;
  bool _isFollowingLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchProfileAndPublications();
  }

  Future<void> _fetchProfileAndPublications() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) throw Exception("No autenticado");

      // 1. Fetch Profile
      final profileUrl = Uri.parse(AppConfig.publicProfileEndpoint(widget.authorId));
      final profileResponse = await http.get(profileUrl, headers: {
        'Authorization': 'Bearer $token',
      });

      if (profileResponse.statusCode == 403) {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Este perfil es exclusivo para estudiantes y docentes."),
              backgroundColor: Colors.orange.shade800,
            ),
          );
        }
        return;
      }

      if (profileResponse.statusCode == 200) {
        _profileData = json.decode(profileResponse.body);
        _isFollowing = _profileData?['is_following'] ?? false;
      } else {
        throw Exception("No se pudo cargar el perfil");
      }

      // 2. Fetch Publications
      final pubsUrl = Uri.parse(AppConfig.publicProfilePublicationsEndpoint(widget.authorId));
      final pubsResponse = await http.get(pubsUrl, headers: {
        'Authorization': 'Bearer $token',
      });

      if (pubsResponse.statusCode == 200) {
        final List<dynamic> jsonList = json.decode(pubsResponse.body);
        _publications = jsonList.map((json) => VideoModel.fromBackendJson(json)).toList();
      } else {
        _publications = [];
      }
    } catch (e) {
      _hasError = true;
      _errorMessage = e.toString().replaceAll("Exception: ", "");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getRoleDisplayName(String role) {
    if (role == 'admin') return 'Administrador';
    if (role == 'profesor') return 'Profesor UTB';
    if (role == 'estudiante') return 'Estudiante';
    return 'Usuario';
  }

  Future<void> _toggleFollow() async {
    setState(() {
      _isFollowingLoading = true;
    });
    try {
      final token = await _storage.read(key: 'jwt_token');
      final url = Uri.parse(AppConfig.publicProfileFollowEndpoint(widget.authorId));
      
      http.Response response;
      if (_isFollowing) {
        response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
      } else {
        response = await http.post(url, headers: {'Authorization': 'Bearer $token'});
      }
      
      if (response.statusCode == 200) {
        setState(() {
          _isFollowing = !_isFollowing;
        });
      } else {
        final body = jsonDecode(response.body);
        throw Exception(body['error'] ?? "Error procesando solicitud");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: ${e.toString().replaceAll('Exception: ', '')}"), backgroundColor: Colors.redAccent)
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFollowingLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(
          _profileData?['username'] ?? 'Perfil',
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, shadows: [Shadow(color: Colors.black54, blurRadius: 4)]),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFF001F60), // Dark UTB Blue
              Color(0xFF0F172A), // Slate 900
              Color(0xFF000000), // Pure Black Deep Down
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            stops: [0.0, 0.3, 1.0],
          ),
        ),
        child: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _hasError
              ? _buildErrorView()
              : _buildProfileView(),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_outline, color: Colors.redAccent, size: 60),
          const SizedBox(height: 20),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF003399)),
            child: const Text('Regresar'),
          )
        ],
      ),
    );
  }

  Widget _buildProfileView() {
    final avatarUrl = _profileData?['avatar_url'] as String?;
    final role = _profileData?['role'] as String? ?? 'estudiante';

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: const Color(0xFF1E293B),
                  backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl.startsWith('http') ? avatarUrl : '${AppConfig.apiBaseUrl}/$avatarUrl')
                      : null,
                  child: avatarUrl == null || avatarUrl.isEmpty
                      ? const Icon(Icons.person, size: 50, color: Colors.grey)
                      : null,
                ),
                const SizedBox(height: 16),
                Text(
                  _profileData?['username'] ?? 'Usuario',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold),
                ),
                Text(
                  _getRoleDisplayName(role),
                  style: TextStyle(
                    color: role == 'profesor' || role == 'admin' ? Colors.blue[300] : Colors.grey[400],
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 16),
                _buildFollowButton(),
                const SizedBox(height: 20),
                if (_profileData?['bio'] != null && _profileData!['bio'].isNotEmpty)
                  Text(
                    _profileData!['bio'],
                    style: const TextStyle(color: Colors.white70, fontSize: 15),
                    textAlign: TextAlign.center,
                  ),
                const SizedBox(height: 20),
                if (_profileData?['website_url'] != null || _profileData?['cvlac_url'] != null)
                  _buildLinksRow(),
                const SizedBox(height: 20),
                const Divider(color: Colors.white24),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      'Publicaciones',
                      style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 2.0),
          sliver: _publications == null || _publications!.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(40.0),
                      child: Text(
                        'Este perfil no tiene publicaciones aún.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ),
                  ),
                )
              : SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 2.0,
                    mainAxisSpacing: 2.0,
                    childAspectRatio: 9 / 16,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (BuildContext context, int index) {
                      final video = _publications![index];
                      return GestureDetector(
                        onTap: () {
                          // Abre el reproductor individual
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => Scaffold(
                                backgroundColor: Colors.black,
                                appBar: AppBar(backgroundColor: Colors.black),
                                body: VideoPlayerWidget(
                                  video: video,
                                  onVisibilityChanged: (_) {},
                                ),
                              ),
                            ),
                          );
                        },
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Container(
                              color: const Color(0xFF1E293B),
                              child: video.thumbnailUrl.isNotEmpty
                                  ? Image.network(
                                      video.thumbnailUrl.startsWith('http') ? video.thumbnailUrl : '${AppConfig.apiBaseUrl}/${video.thumbnailUrl}',
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      video.contentType == 'encuesta' ? Icons.bar_chart :
                                      video.contentType == 'flashcard' ? Icons.style_outlined : Icons.play_arrow,
                                      size: 40,
                                      color: Colors.white30,
                                    ),
                            ),
                            Positioned(
                              bottom: 4,
                              left: 4,
                              child: Row(
                                children: [
                                  const Icon(Icons.play_arrow_outlined, color: Colors.white, size: 16),
                                  Text(
                                    video.views.toString(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: _publications!.length,
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildLinksRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (_profileData?['cvlac_url'] != null && _profileData!['cvlac_url'].isNotEmpty)
          _linkButton(Icons.description, "CVLAC", _profileData!['cvlac_url']),
        if (_profileData?['website_url'] != null && _profileData!['website_url'].isNotEmpty) ...[
          const SizedBox(width: 20),
          _linkButton(Icons.link, "Web", _profileData!['website_url']),
        ]
      ],
    );
  }

  Widget _linkButton(IconData icon, String label, String url) {
    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white10,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 16),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildFollowButton() {
    return SizedBox(
      width: 200,
      height: 45,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: _isFollowing ? Colors.grey[800] : const Color(0xFF0044CC), // UTB Blue
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
          elevation: _isFollowing ? 0 : 4,
        ),
        onPressed: _isFollowingLoading ? null : _toggleFollow,
        child: _isFollowingLoading 
          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(
              _isFollowing ? 'Siguiendo' : 'Seguir',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
      ),
    );
  }
}
