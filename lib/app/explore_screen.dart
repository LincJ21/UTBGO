import 'package:flutter/material.dart';
import 'config/api_client.dart';
import 'config/app_config.dart';
import 'video_model.dart';
import 'search_results_screen.dart';
import 'single_video_screen.dart';

/// [ExploreScreen] muestra contenido de descubrimiento: videos populares,
/// búsqueda y tendencias, conectados al backend real.
class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _apiClient = ApiClient();

  late Future<List<VideoModel>> _popularVideosFuture;
  late Future<List<Map<String, dynamic>>> _trendsFuture;

  // Categorías oficiales UTB (basadas en Escuelas y Direcciones)
  final List<Map<String, dynamic>> _categories = [
    {'label': 'Todos', 'icon': Icons.explore, 'filter': ''},
    {'label': 'Ingeniería', 'icon': Icons.engineering, 'filter': 'Ingeniería'},
    {'label': 'Negocios', 'icon': Icons.business_center, 'filter': 'Negocios'},
    {'label': 'Sociedad', 'icon': Icons.gavel, 'filter': 'Sociedad'},
    {'label': 'Arquitectura', 'icon': Icons.palette, 'filter': 'Arquitectura'},
    {'label': 'Ciencias Básicas', 'icon': Icons.science, 'filter': 'Ciencias Básicas'},
    {'label': 'Vida UTB', 'icon': Icons.celebration, 'filter': 'Vida UTB'},
  ];
  int _selectedCategoryIndex = 0;

  // Paleta de colores para los tags generados dinámicamente
  final List<Color> _tagColors = const [
    Color(0xFF003399), // Azul UTB
    Color(0xFF8E24AA), // Púrpura
    Color(0xFF2E7D32), // Verde
    Color(0xFFE65100), // Naranja
    Color(0xFF00838F), // Cian oscuro
    Color(0xFFC62828), // Rojo
  ];

  @override
  void initState() {
    super.initState();
    _popularVideosFuture = _fetchPopularVideos();
    _trendsFuture = _fetchTrends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Obtiene contenido popular del backend.
  Future<List<VideoModel>> _fetchPopularVideos() async {
    final response = await _apiClient.get(
      '${AppConfig.recommendPopularEndpoint}?n=6',
    );

    if (response.isSuccess && response.data is List) {
      return (response.data as List)
          .map((json) => VideoModel.fromBackendJson(json))
          .toList();
    }
    return [];
  }

  /// Obtiene videos filtrados por categoría desde el endpoint de búsqueda
  Future<List<VideoModel>> _fetchVideosByCategory(String category) async {
    final uri = Uri.parse(AppConfig.videosSearchEndpoint).replace(
      queryParameters: {
        'q': '*',
        'category': category,
      },
    );

    final response = await _apiClient.get<List<VideoModel>>(
      uri.toString(),
      requiresAuth: true,
      fromJson: (json) {
        final List<dynamic> videoJson = (json['videos'] as List<dynamic>?) ?? [];
        return videoJson.map((v) => VideoModel.fromBackendJson(v)).toList();
      },
    );

    if (response.isSuccess && response.data != null) {
      return response.data!;
    }
    return [];
  }

  /// Obtiene tendencias reales del backend
  Future<List<Map<String, dynamic>>> _fetchTrends() async {
    final response = await _apiClient.get(
      '${AppConfig.apiBaseUrl}/v1/trends',
    );

    if (response.isSuccess && response.data != null) {
      final data = response.data as Map<String, dynamic>;
      if (data['trends'] != null && data['trends'] is List) {
         final list = data['trends'] as List;
         return list.map<Map<String, dynamic>>((e) => {
           'tag': e['tag']?.toString() ?? '',
           'count': (e['count'] is int) ? e['count'] : int.tryParse(e['count']?.toString() ?? '0') ?? 0,
         }).toList();
      }
    }
    return [];
  }

  /// Navega a la pantalla de búsqueda.
  void _performSearch() {
    final query = _searchController.text.trim();
    if (query.isEmpty) return;

    FocusScope.of(context).unfocus();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SearchResultsScreen(query: query),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            setState(() => _popularVideosFuture = _fetchPopularVideos());
          },
          color: const Color(0xFF003399),
          child: CustomScrollView(
            slivers: [
              // ── Header con búsqueda ──
              SliverToBoxAdapter(child: _buildHeader()),

              // ── Categorías ──
              SliverToBoxAdapter(child: _buildCategoriesBar()),

              // ── Novedades (Recientes) ──
              SliverToBoxAdapter(child: _buildRecentVideosSection()),

              // ── Tendencias (Hashtags) ──
              SliverToBoxAdapter(child: _buildTrendingSection()),

              // ── Videos Populares ──
              SliverToBoxAdapter(child: _buildPopularVideosSection()),

              // Espacio inferior
              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
    );
  }

  // ────────────────────────────────────────────
  //  COMPONENTES DE UI
  // ────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Título
          const Text(
            'Explorar',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Descubre contenido académico en UTBGO',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 16),

          // Barra de búsqueda
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 14),
                Icon(Icons.search, color: Colors.grey[400], size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Buscar videos, temas, profesores...',
                      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      isDense: true,
                    ),
                    style: const TextStyle(fontSize: 14),
                    onSubmitted: (_) => _performSearch(),
                  ),
                ),
                GestureDetector(
                  onTap: _performSearch,
                  child: Container(
                    margin: const EdgeInsets.all(6),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF003399),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesBar() {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: SizedBox(
        height: 42,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: _categories.length,
          itemBuilder: (context, index) {
            final isSelected = _selectedCategoryIndex == index;
            final cat = _categories[index];
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedCategoryIndex = index;
                  if (index == 0) {
                    _popularVideosFuture = _fetchPopularVideos();
                  } else {
                    final filter = cat['filter'] as String;
                    _popularVideosFuture = _fetchVideosByCategory(filter);
                  }
                });
              },
              child: Container(
                margin: const EdgeInsets.only(right: 10),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF003399) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: isSelected
                      ? null
                      : Border.all(color: const Color(0xFFE2E8F0)),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: const Color(0xFF003399).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  children: [
                    Icon(
                      cat['icon'] as IconData,
                      size: 16,
                      color: isSelected ? Colors.white : Colors.grey[600],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat['label'] as String,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.grey[700],
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildRecentVideosSection() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Text(
              'Novedades',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Color(0xFF1E293B),
                letterSpacing: -0.5,
              ),
            ),
          ),
          SizedBox(
            height: 150,
            child: FutureBuilder<ApiResponse<List<VideoModel>>>(
              // Llama dinámicamente al feed crudo que siempre trae lo más nuevo
              future: _apiClient.get<List<VideoModel>>(
                '${AppConfig.videosFeedEndpoint}?page=1',
                requiresAuth: true,
                fromJson: (json) {
                  final List<dynamic> videoJson =
                      (json['videos'] as List<dynamic>?) ?? [];
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
                  return const Center(child: Text('No hay novedades', style: TextStyle(color: Colors.grey)));
                }

                // Tomamos un máximo de 10 como límite prudente para scroll horizontal
                final videos = snapshot.data!.data?.take(10).toList() ?? [];

                if (videos.isEmpty) {
                  return const Center(child: Text('No hay novedades disponibles', style: TextStyle(color: Colors.grey)));
                }

                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: videos.length,
                  itemBuilder: (context, index) {
                    final video = videos[index];
                    // Hacemos que la tarjeta ocupe el 65% del ancho de la pantalla actual
                    // Así garantizamos que se vea bien en iPhone Mini, Pro Max, iPads o Androids.
                    final screenWidth = MediaQuery.of(context).size.width;
                    
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SingleVideoScreen(video: video),
                          ),
                        );
                      },
                      child: Container(
                        width: screenWidth * 0.65,
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B), // Fondo oscuro de respaldo si no hay miniatura
                          borderRadius: BorderRadius.circular(16),
                          image: video.thumbnailUrl.isNotEmpty
                              ? DecorationImage(
                                  image: NetworkImage(video.thumbnailUrl),
                                  fit: BoxFit.cover,
                                  colorFilter: ColorFilter.mode(
                                    Colors.black.withOpacity(0.3),
                                    BlendMode.darken,
                                  ),
                                )
                              : null,
                        ),
                        child: Stack(
                          children: [
                            // Badge NUEVO / TIPO DE CONTENIDO
                            Positioned(
                              top: 12,
                              left: 12,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF003399),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  video.contentType == 'poll'
                                      ? 'ENCUESTA'
                                      : video.contentType == 'flashcard'
                                          ? 'FLASHCARD'
                                          : 'NUEVO',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Botón central dinámico desenfocado
                            Center(
                              child: Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  video.contentType == 'poll'
                                      ? Icons.poll_outlined
                                      : video.contentType == 'flashcard'
                                          ? Icons.style_outlined
                                          : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                            // Info inferior
                            Positioned(
                              bottom: 12,
                              left: 12,
                              right: 12,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.favorite,
                                          color: Colors.white, size: 14),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${video.likes}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    video.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      shadows: [
                                        Shadow(
                                          color: Colors.black54,
                                          offset: Offset(0, 1),
                                          blurRadius: 2,
                                        )
                                      ],
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
      ),
    );
  }

  Widget _buildTrendingSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFF003399).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.trending_up, color: Color(0xFF003399), size: 18),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tendencias en UTB',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _trendsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF003399))),
                );
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox(
                  height: 60,
                  child: Center(child: Text('No hay tendencias disponibles hoy.', style: TextStyle(color: Colors.grey))),
                );
              }

              final tags = snapshot.data!;
              return Wrap(
                spacing: 8,
                runSpacing: 10,
                children: List.generate(tags.length, (index) {
                  final tag = tags[index];
                  // Asignar un color de la paleta cíclicamente para mantener la estética
                  final color = _tagColors[index % _tagColors.length];
                  
                  return Material(
                    color: color.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(24), // Más redondeado, estilo "píldora"
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SearchResultsScreen(query: tag['tag'] as String),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: color.withOpacity(0.2)),
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              tag['tag'] as String,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${tag['count']}',
                                style: TextStyle(
                                  color: color,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPopularVideosSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.local_fire_department, color: Colors.amber, size: 18),
              ),
              const SizedBox(width: 10),
              Text(
                _selectedCategoryIndex == 0 
                  ? 'Contenido Popular' 
                  : 'Contenido de ${_categories[_selectedCategoryIndex]['label']}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FutureBuilder<List<VideoModel>>(
            future: _popularVideosFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF003399)),
                  ),
                );
              }

              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                return _buildEmptyState();
              }

              final videos = snapshot.data!;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.75,
                ),
                itemCount: videos.length,
                itemBuilder: (context, index) => _buildVideoCard(videos[index]),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildVideoCard(VideoModel video) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => SingleVideoScreen(video: video),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Thumbnail
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    video.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            video.thumbnailUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: const Color(0xFF003399).withOpacity(0.1),
                              child: const Icon(Icons.play_circle_fill,
                                  size: 48, color: Color(0xFF003399)),
                            ),
                          )
                        : Container(
                            color: const Color(0xFF003399).withOpacity(0.1),
                            child: const Icon(Icons.play_circle_fill,
                                size: 48, color: Color(0xFF003399)),
                          ),
                    // Play overlay
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 24),
                      ),
                    ),
                    // Like count badge
                    Positioned(
                      bottom: 6,
                      right: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite, color: Colors.white, size: 12),
                            const SizedBox(width: 4),
                            Text(
                              _formatCount(video.likes),
                              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Info
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    video.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1E293B),
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    video.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.explore_off, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              'No hay videos populares aún',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Sé el primero en subir contenido',
              style: TextStyle(fontSize: 13, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  /// Formatea números grandes (1200 → 1.2k).
  String _formatCount(int count) {
    if (count >= 1000000) return '${(count / 1000000).toStringAsFixed(1)}M';
    if (count >= 1000) return '${(count / 1000).toStringAsFixed(1)}k';
    return count.toString();
  }
}
