import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'config/api_client.dart';
import 'config/app_config.dart';
import 'public_profile_model.dart';
import 'single_video_screen.dart';
import 'video_model.dart';

class PublicProfileScreen extends StatefulWidget {
  final int authorId;

  const PublicProfileScreen({super.key, required this.authorId});

  @override
  State<PublicProfileScreen> createState() => _PublicProfileScreenState();
}

class _PublicProfileScreenState extends State<PublicProfileScreen> {
  final _apiClient = ApiClient();

  PublicProfileModel? _profile;
  List<VideoModel> _publications = [];
  bool _isLoading = true;
  bool _isFollowingLoading = false;
  String? _errorMessage;
  String? _publicationsError;
  int _selectedPublicationTab = 0;

  @override
  void initState() {
    super.initState();
    _fetchProfileAndPublications();
  }

  Future<void> _fetchProfileAndPublications() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _publicationsError = null;
    });

    final profileResponse = await _apiClient.get<PublicProfileModel>(
      AppConfig.publicProfileEndpoint(widget.authorId),
      requiresAuth: true,
      fromJson: (json) =>
          PublicProfileModel.fromJson(json as Map<String, dynamic>),
    );

    if (!profileResponse.isSuccess || profileResponse.data == null) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            profileResponse.error?.message ?? 'No se pudo cargar el perfil.';
      });
      return;
    }

    final publicationsResponse = await _apiClient.get<List<VideoModel>>(
      AppConfig.publicProfilePublicationsEndpoint(widget.authorId),
      requiresAuth: true,
      fromJson: (json) {
        final list = (json as List<dynamic>?) ?? [];
        return list
            .map((item) =>
                VideoModel.fromPublicBackendJson(item as Map<String, dynamic>))
            .toList();
      },
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _profile = profileResponse.data;
      _publications = publicationsResponse.data ?? [];
      _publicationsError = publicationsResponse.isSuccess
          ? null
          : publicationsResponse.error?.message ??
              'No se pudieron cargar las publicaciones.';
      _isLoading = false;
    });
  }

  Future<void> _toggleFollow() async {
    final profile = _profile;
    if (profile == null || _isFollowingLoading) {
      return;
    }

    setState(() {
      _isFollowingLoading = true;
    });

    final response = profile.isFollowing
        ? await _apiClient.delete<dynamic>(
            AppConfig.publicProfileFollowEndpoint(widget.authorId),
            requiresAuth: true,
          )
        : await _apiClient.post<dynamic>(
            AppConfig.publicProfileFollowEndpoint(widget.authorId),
            requiresAuth: true,
          );

    if (!mounted) {
      return;
    }

    if (response.isSuccess) {
      final delta = profile.isFollowing ? -1 : 1;
      final nextFollowers = profile.followers + delta;

      setState(() {
        _profile = profile.copyWith(
          isFollowing: !profile.isFollowing,
          followers: nextFollowers < 0 ? 0 : nextFollowers,
        );
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response.error?.message ??
                'No se pudo actualizar el seguimiento del perfil.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
    }

    setState(() {
      _isFollowingLoading = false;
    });
  }

  Future<void> _launchUrl(String urlValue) async {
    final url =
        Uri.parse(urlValue.startsWith('http') ? urlValue : 'https://$urlValue');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }

  Future<void> _openPublication(VideoModel video) async {
    final viewerStateResponse = await _apiClient.get<Map<String, dynamic>>(
      AppConfig.videoViewerStateUrl(video.id),
      requiresAuth: true,
      fromJson: (json) => json as Map<String, dynamic>,
    );

    if (viewerStateResponse.isSuccess && viewerStateResponse.data != null) {
      final viewerState = viewerStateResponse.data!;
      video.isLiked = viewerState['is_liked'] ?? false;
      video.isBookmarked = viewerState['is_bookmarked'] ?? false;
      video.isReposted = viewerState['is_reposted'] ?? false;
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewerStateResponse.error?.message ??
                'No se pudo sincronizar el estado del contenido.',
          ),
          backgroundColor: Colors.orange.shade800,
        ),
      );
    }

    if (!mounted) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SingleVideoScreen(video: video, showFeedTopBar: false),
      ),
    );
  }

  List<VideoModel> get _filteredPublications {
    switch (_selectedPublicationTab) {
      case 1:
        return _publications
            .where((video) =>
                video.contentType == 'encuesta' || video.contentType == 'poll')
            .toList();
      case 2:
        return _publications
            .where((video) => video.contentType == 'flashcard')
            .toList();
      default:
        return _publications
            .where((video) =>
                video.contentType == 'video' || video.contentType == 'imagen')
            .toList();
    }
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'moderador':
        return 'Moderador';
      case 'profesor':
        return 'Docente UTB';
      case 'aspirante':
        return 'Aspirante';
      default:
        return 'Estudiante';
    }
  }

  String _emptyPublicationMessage() {
    switch (_selectedPublicationTab) {
      case 1:
        return 'Este docente no tiene encuestas publicadas.';
      case 2:
        return 'Este docente no tiene flashcards publicadas.';
      default:
        return 'Este docente no tiene publicaciones en esta categoria.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? _buildErrorState()
              : _buildProfileView(),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_outline, size: 56, color: Colors.orange),
            const SizedBox(height: 16),
            Text(
              _errorMessage ?? 'No se pudo cargar el perfil.',
              style: const TextStyle(fontSize: 16, color: Color(0xFF334155)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _fetchProfileAndPublications,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003399),
                foregroundColor: Colors.white,
              ),
              child: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileView() {
    final profile = _profile!;
    const tabs = [
      Tab(text: 'STATS'),
      Tab(text: 'PUBLICACIONES'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        height: 170,
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Color(0xFF001F60),
                              Color(0xFF003399),
                              Color(0xFF0044CC),
                              Color(0xFF1E88E5),
                            ],
                            stops: [0.0, 0.4, 0.75, 1.0],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 20,
                        bottom: -40,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                          child: CircleAvatar(
                            radius: 46,
                            backgroundColor: const Color(0xFF90CAF9),
                            backgroundImage: profile.avatarUrl.isNotEmpty
                                ? NetworkImage(profile.avatarUrl)
                                : null,
                            child: profile.avatarUrl.isEmpty
                                ? const Icon(Icons.person,
                                    size: 50, color: Colors.white)
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 44, 20, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile.username,
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF1E293B),
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF003399)
                                      .withValues(alpha: 0.10),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  _roleLabel(profile.role),
                                  style: const TextStyle(
                                    color: Color(0xFF003399),
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                            if (profile.faculty != null &&
                                profile.faculty!.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.school,
                                      size: 16, color: Color(0xFF64748B)),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      profile.faculty!,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF64748B),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 14),
                            Text(
                              (profile.bio != null &&
                                      profile.bio!.trim().isNotEmpty)
                                  ? profile.bio!.trim()
                                  : 'Perfil publico del docente en UTBGO.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF334155),
                                height: 1.5,
                              ),
                            ),
                            if ((profile.cvlacUrl?.isNotEmpty ?? false) ||
                                (profile.websiteUrl?.isNotEmpty ?? false)) ...[
                              const SizedBox(height: 16),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  if (profile.cvlacUrl?.isNotEmpty ?? false)
                                    _buildLinkChip(
                                      icon: Icons.school,
                                      label: 'CvLAC',
                                      color: Colors.red,
                                      onTap: () =>
                                          _launchUrl(profile.cvlacUrl!),
                                    ),
                                  if (profile.websiteUrl?.isNotEmpty ?? false)
                                    _buildLinkChip(
                                      icon: Icons.language,
                                      label: 'Website',
                                      color: Colors.blue,
                                      onTap: () =>
                                          _launchUrl(profile.websiteUrl!),
                                    ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 16),
                          ],
                        ),
                      ),
                      Positioned(
                        top: 8,
                        right: 16,
                        child: _buildFollowButton(profile),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SliverOverlapAbsorber(
              handle:
                  NestedScrollView.sliverOverlapAbsorberHandleFor(context),
              sliver: SliverPersistentHeader(
                pinned: true,
                delegate: _PublicProfileTabBarDelegate(
                  const TabBar(
                    tabAlignment: TabAlignment.fill,
                    labelStyle:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold),
                    unselectedLabelStyle:
                        TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
                    labelColor: Colors.black,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: Color(0xFF003399),
                    tabs: tabs,
                  ),
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          children: [
            _buildNestedStatsTab(profile),
            _buildNestedPublicationsTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsTab(PublicProfileModel profile) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: _buildStatsGrid(profile),
    );
  }

  Widget _buildStatsGrid(PublicProfileModel profile) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.video_library,
                value: profile.totalVideos.toString(),
                label: 'Publicaciones',
                color: Colors.blue,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.people,
                value: profile.followers.toString(),
                label: 'Seguidores',
                color: Colors.deepPurple,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                icon: Icons.favorite,
                value: profile.totalLikes.toString(),
                label: 'Me gustas',
                color: Colors.pink,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                icon: Icons.visibility,
                value: profile.totalViews.toString(),
                label: 'Visualizaciones',
                color: Colors.orange,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFAFAFA),
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
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                    fontSize: 13, color: color, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFollowButton(PublicProfileModel profile) {
    return SizedBox(
      height: 40,
      child: ElevatedButton(
        onPressed: _isFollowingLoading ? null : _toggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor:
              profile.isFollowing ? Colors.white : const Color(0xFF003399),
          foregroundColor:
              profile.isFollowing ? const Color(0xFF003399) : Colors.white,
          elevation: profile.isFollowing ? 0 : 3,
          side: profile.isFollowing
              ? const BorderSide(color: Color(0xFF003399))
              : BorderSide.none,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        ),
        child: _isFollowingLoading
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: profile.isFollowing
                      ? const Color(0xFF003399)
                      : Colors.white,
                ),
              )
            : Text(
                profile.isFollowing ? 'Siguiendo' : 'Seguir',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
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
        color: Colors.transparent,
        child: Icon(
          icon,
          size: 26,
          color: selected ? Colors.black87 : Colors.grey.shade500,
        ),
      ),
    );
  }

  Widget _buildPublicationsTab() {
    final publications = _filteredPublications;

    return Column(
      children: [
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
        if (_publicationsError != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _publicationsError!,
                style: const TextStyle(color: Color(0xFF9A3412)),
              ),
            ),
          ),
        Expanded(
          child: publications.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                    child: Text(
                      _emptyPublicationMessage(),
                      style: const TextStyle(color: Colors.grey, fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 0.65,
                    crossAxisSpacing: 2,
                    mainAxisSpacing: 2,
                  ),
                  itemCount: publications.length,
                  itemBuilder: (context, index) {
                    final video = publications[index];

                    return GestureDetector(
                      onTap: () => _openPublication(video),
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
                            Container(
                                color: Colors.black.withValues(alpha: 0.30)),
                            Center(
                              child: Icon(
                                video.contentType == 'encuesta' ||
                                        video.contentType == 'poll'
                                    ? Icons.poll_outlined
                                    : video.contentType == 'flashcard'
                                        ? Icons.style_outlined
                                        : Icons.play_circle_outline,
                                color: Colors.white.withValues(alpha: 0.80),
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
                ),
        ),
      ],
    );
  }

  Widget _buildNestedStatsTab(PublicProfileModel profile) {
    return _buildTabScrollView(
      storageKey: 'public-profile-stats',
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverToBoxAdapter(
            child: _buildStatsGrid(profile),
          ),
        ),
      ],
    );
  }

  Widget _buildNestedPublicationsTab() {
    final publications = _filteredPublications;
    final slivers = <Widget>[
      _buildPublicationFilterSliver(),
    ];

    if (_publicationsError != null) {
      slivers.add(
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7ED),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                _publicationsError!,
                style: const TextStyle(color: Color(0xFF9A3412)),
              ),
            ),
          ),
        ),
      );
    }

    if (publications.isEmpty) {
      slivers.add(
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Text(
                _emptyPublicationMessage(),
                style: const TextStyle(color: Colors.grey, fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
      );

      return _buildTabScrollView(
        storageKey: 'public-profile-publications-empty-$_selectedPublicationTab',
        slivers: slivers,
      );
    }

    slivers.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(2, 0, 2, 4),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 0.65,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          delegate: SliverChildBuilderDelegate(
            (context, index) {
              final video = publications[index];

              return GestureDetector(
                onTap: () => _openPublication(video),
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
                      Container(color: Colors.black.withValues(alpha: 0.30)),
                      Center(
                        child: Icon(
                          video.contentType == 'encuesta' ||
                                  video.contentType == 'poll'
                              ? Icons.poll_outlined
                              : video.contentType == 'flashcard'
                                  ? Icons.style_outlined
                                  : Icons.play_circle_outline,
                          color: Colors.white.withValues(alpha: 0.80),
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
            childCount: publications.length,
          ),
        ),
      ),
    );

    return _buildTabScrollView(
      storageKey: 'public-profile-publications-$_selectedPublicationTab',
      slivers: slivers,
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
}

class _PublicProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;

  _PublicProfileTabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;

  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(
      BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _PublicProfileTabBarDelegate oldDelegate) =>
      false;
}
