import 'package:flutter/material.dart';
import 'video_model.dart';

/// Muestra una lista de videos que coinciden con un término de búsqueda.
class SearchResultsScreen extends StatelessWidget {
  final List<VideoModel> searchResults;
  final String query;

  const SearchResultsScreen({
    super.key,
    required this.searchResults,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Resultados para "$query"'),
        backgroundColor: const Color(0xFF003399),
      ),
      body: searchResults.isEmpty
          ? const Center(
              child: Text(
                'No se encontraron videos.',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              itemCount: searchResults.length,
              itemBuilder: (context, index) {
                final video = searchResults[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: video.thumbnailUrl.isNotEmpty
                        ? Image.network(
                            video.thumbnailUrl,
                            width: 100,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                const Icon(Icons.video_camera_back, size: 40),
                          )
                        : const Icon(Icons.video_camera_back, size: 40),
                    title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      video.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.favorite, color: Colors.red, size: 18),
                        Text(video.likes.toString()),
                      ],
                    ),
                    onTap: () {
                      // TODO: Implementar navegación al reproductor de video
                      // Por ahora, solo mostramos un SnackBar.
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reproduciendo: ${video.title}')),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}
