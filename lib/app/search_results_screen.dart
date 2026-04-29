import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'video_model.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';
import 'main_navigation_page.dart';
import 'single_video_screen.dart';
import 'widgets/main_bottom_nav_bar.dart';

/// Pantalla que busca y muestra videos que coinciden con un término de búsqueda.
/// Maneja su propio estado de carga, error y "sin resultados", incluyendo pull-to-refresh.
class SearchResultsScreen extends StatefulWidget {
  final String query;
  final String categoryFilter;

  const SearchResultsScreen({
    super.key,
    this.query = '',
    this.categoryFilter = '',
  });

  @override
  State<SearchResultsScreen> createState() => _SearchResultsScreenState();
}

class _SearchResultsScreenState extends State<SearchResultsScreen> {
  final _apiClient = ApiClient();
  List<VideoModel> _searchResults = [];
  bool _isLoading = true;
  String? _error;

  // Filtros
  String _dateFilter = '';
  String _authorFilter = '';

  @override
  void initState() {
    super.initState();
    _performSearch();
  }

  /// Realiza la búsqueda llamando al API real con autenticación JWT y filtros.
  Future<void> _performSearch() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    // Si hay query, la incluimos; si viene vacía (filtro por categoría), usamos '*' como comodín
    final searchQuery = widget.query.isNotEmpty ? widget.query : '*';
    final queryParams = <String, String>{'q': searchQuery};
    if (_dateFilter.isNotEmpty) queryParams['date'] = _dateFilter;
    if (_authorFilter.isNotEmpty) queryParams['author'] = _authorFilter;
    if (widget.categoryFilter.isNotEmpty)
      queryParams['category'] = widget.categoryFilter;

    final Uri uri = Uri.parse(AppConfig.videosSearchEndpoint)
        .replace(queryParameters: queryParams);

    final response = await _apiClient.get<List<VideoModel>>(
      uri.toString(),
      requiresAuth: true,
      fromJson: (json) {
        final List<dynamic> videoJson =
            (json['videos'] as List<dynamic>?) ?? [];
        return videoJson.map((v) => VideoModel.fromBackendJson(v)).toList();
      },
    );

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      setState(() {
        _searchResults = response.data!;
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error?.message ?? 'Error al buscar';
        _isLoading = false;
      });
    }
  }

  void _showFiltersBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                top: 24,
                left: 20,
                right: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filtros de búsqueda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  const Text('Fecha de publicación',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    children: [
                      _buildDateChip('Cualquiera', '', setModalState),
                      _buildDateChip('Hoy', 'today', setModalState),
                      _buildDateChip('Esta semana', 'week', setModalState),
                      _buildDateChip('Este mes', 'month', setModalState),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('Autor',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: TextEditingController(text: _authorFilter),
                    decoration: InputDecoration(
                      hintText: 'Ej. Juan Pérez',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                    onChanged: (val) => _authorFilter = val,
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _performSearch();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF003399),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Aplicar filtros',
                          style: TextStyle(color: Colors.white, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildDateChip(String label, String value, StateSetter setModalState) {
    final isSelected = _dateFilter == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: const Color(0xFF003399).withValues(alpha: 0.2),
      labelStyle: TextStyle(
        color: isSelected ? const Color(0xFF003399) : Colors.black87,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (selected) {
        if (selected) {
          setModalState(() => _dateFilter = value);
          setState(() => _dateFilter = value);
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          widget.categoryFilter.isNotEmpty
              ? widget.categoryFilter
              : 'Resultados para "${widget.query}"',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
        ),
        backgroundColor: const Color(0xFF003399),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: _showFiltersBottomSheet,
            tooltip: 'Filtros',
          ),
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: MainBottomNavBar(
        onTap: _goToMainTab,
      ),
    );
  }

  void _goToMainTab(int index) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => MainNavigationPage(initialSelectedIndex: index),
      ),
      (route) => false,
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return _buildShimmerLoading();
    }

    if (_error != null) {
      return _buildErrorState();
    }

    if (_searchResults.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _performSearch,
      color: const Color(0xFF003399),
      child: GridView.builder(
        padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: _searchResults.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          childAspectRatio: 0.72,
          crossAxisSpacing: 2,
          mainAxisSpacing: 2,
        ),
        itemBuilder: (context, index) {
          final video = _searchResults[index];
          return _buildResultTile(video);
        },
      ),
    );
  }

  Widget _buildResultTile(VideoModel video) {
    final previewUrl = _resolvePreviewUrl(video);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) =>
                SingleVideoScreen(video: video, showFeedTopBar: false),
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
                image: previewUrl != null && previewUrl.isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(previewUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: previewUrl == null || previewUrl.isEmpty
                  ? _buildFallbackThumbnail()
                  : null,
            ),
            Container(color: Colors.black.withValues(alpha: 0.28)),
            Center(
              child: Icon(
                video.contentType == 'encuesta' || video.contentType == 'poll'
                    ? Icons.poll_outlined
                    : video.contentType == 'flashcard'
                        ? Icons.style_outlined
                        : Icons.play_circle_outline,
                color: Colors.white.withValues(alpha: 0.82),
                size: 32,
              ),
            ),
            Positioned(
              bottom: 6,
              left: 6,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite, color: Colors.white, size: 12),
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
  }

  String? _resolvePreviewUrl(VideoModel video) {
    if (video.thumbnailUrl.isNotEmpty) {
      return video.thumbnailUrl;
    }
    if (video.contentType == 'imagen' && video.videoUrl.isNotEmpty) {
      return video.videoUrl;
    }
    return null;
  }

  Widget _buildFallbackThumbnail() {
    return Container(
      color: Colors.grey.shade200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.image_not_supported,
                color: Colors.grey.shade400, size: 32),
            const SizedBox(height: 4),
            Text(
              'Sin portada',
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(
            'No encontramos videos para "${widget.query}"',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Intenta buscar con otras palabras clave\no verifica la ortografía.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _goToMainTab(0),
            icon: const Icon(Icons.arrow_back),
            label: const Text('Volver a Explorar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003399),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.redAccent),
          const SizedBox(height: 16),
          Text(
            'Oops, algo salió mal',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error ?? 'Error desconocido',
            style: const TextStyle(fontSize: 14, color: Colors.redAccent),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: _performSearch,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003399),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(2, 8, 2, 12),
      itemCount: 6, // Mostrar 6 placeholders
      physics: const AlwaysScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 0.72,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: Colors.grey[300]!,
          highlightColor: Colors.grey[100]!,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: Container(color: Colors.white),
                ),
                Positioned(
                  left: 8,
                  bottom: 8,
                  child: Container(
                    width: 36,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
