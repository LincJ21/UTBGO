import 'package:flutter/material.dart';
import 'video_model.dart';

/// Pantalla de búsqueda con TextField y resultados.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<VideoModel> _results = [];
  bool _isSearching = false;

  void _performSearch(String query) {
    if (query.isEmpty) return;
    
    setState(() {
      _isSearching = true;
    });

    // Simulación de búsqueda
    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        _results = VideoModel.localFeed
            .where((v) => v.title.toLowerCase().contains(query.toLowerCase()))
            .toList();
        _isSearching = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        leading: const BackButton(color: Colors.white),
        title: TextField(
          controller: _searchController,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Buscar en UTB Go...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.grey.shade600),
          ),
          onSubmitted: _performSearch,
        ),
      ),
      body: _isSearching
          ? const Center(child: CircularProgressIndicator(color: Colors.white))
          : _results.isEmpty
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Busca videos, flashcards o usuarios', style: TextStyle(color: Colors.grey)),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _results.length,
              itemBuilder: (context, index) {
                final video = _results[index];
                return Card(
                  color: Colors.grey.shade900,
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    leading: Icon(
                      video.contentType == 'flashcard' ? Icons.style : Icons.play_circle,
                      color: Colors.white,
                    ),
                    title: Text(video.title, style: const TextStyle(color: Colors.white)),
                    subtitle: Text(
                      video.description,
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
