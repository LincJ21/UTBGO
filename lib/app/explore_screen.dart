import 'package:flutter/material.dart';

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({super.key});

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  int _selectedFilterIndex = 0;
  final List<String> _filters = ['Usuarios', 'Asignaturas', 'Hashtags'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF9F6), // Un tono hueso crudo muy claro como la imagen
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(),
                const SizedBox(height: 20),
                _buildFiltersBar(),
                const SizedBox(height: 24),
                _buildSuggestionsSection(),
                const SizedBox(height: 24),
                _buildTrendingSection(),
                const SizedBox(height: 48), // Espacio extra al final para scroll suave
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 1. TOP BAR (Search)
  Widget _buildTopBar() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(24),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.grey.shade600, size: 24),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Buscar en UTBGO',
                hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 15),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. FILTERS (Usuarios, Asignaturas, Hashtags)
  Widget _buildFiltersBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_filters.length, (index) {
          final isSelected = _selectedFilterIndex == index;
          return GestureDetector(
            onTap: () => setState(() => _selectedFilterIndex = index),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFF003399) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: isSelected ? null : Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                _filters[index],
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade700,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // 3. SUGERENCIAS PARA TI
  Widget _buildSuggestionsSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Sugerencias para ti',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            TextButton(
              onPressed: () {},
              style: TextButton.styleFrom(
                minimumSize: Size.zero,
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Ver todo', style: TextStyle(color: Color(0xFF003399), fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildUserSuggestionCard(
          name: 'Carlos David',
          verified: true,
          bio1: 'Ing. Sistemas • Profesor Redes',
          bio2: 'Te sigue',
          badgeText: 'PRO',
          badgeColor: const Color(0xFF003399),
        ),
        const SizedBox(height: 12),
        _buildUserSuggestionCard(
          name: 'Maria Gonzalez',
          verified: false,
          bio1: 'Comunicación Social • 5° Sem',
          bio2: 'Amigos en común: Ana P.',
          badgeText: 'EST',
          badgeColor: const Color(0xFF2E7D32), // Verde hoja
        ),
        const SizedBox(height: 12),
        _buildUserSuggestionCard(
          name: 'Jorge Ramirez',
          verified: false,
          bio1: 'Bienestar Universitario',
          bio2: '',
          badgeText: 'ADM',
          badgeColor: const Color(0xFF003399), // Azul oscuro
        ),
      ],
    );
  }

  Widget _buildUserSuggestionCard({
    required String name,
    required bool verified,
    required String bio1,
    required String bio2,
    required String badgeText,
    required Color badgeColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          // Avatar + Badge
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey.shade300,
                ),
                child: const Icon(Icons.person, color: Colors.grey), // Fallback
              ),
              Positioned(
                bottom: -4,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: badgeColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Text(
                      badgeText,
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              )
            ],
          ),
          const SizedBox(width: 16),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    if (verified) ...[
                      const SizedBox(width: 4),
                      const Icon(Icons.verified, color: Colors.blue, size: 16),
                    ]
                  ],
                ),
                const SizedBox(height: 2),
                Text(bio1, style: const TextStyle(color: Colors.grey, fontSize: 12)),
                if (bio2.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(bio2, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ]
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Follow Button
          SizedBox(
            height: 32,
            child: ElevatedButton(
              onPressed: () {},
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003399),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Seguir', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          )
        ],
      ),
    );
  }

  // 4. TENDENCIAS
  Widget _buildTrendingSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.trending_up, color: Color(0xFF003399), size: 22),
            const SizedBox(width: 8),
            const Text(
              'Tendencias en UTB',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
          ],
        ),
        const SizedBox(height: 16),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 2.2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          children: [
            _buildTrendingCard('#IngenieríaUTB', '2.4k Publicaciones', const Color(0xFF003399)),
            _buildTrendingCard('#SemanaCultural', '856 Publicaciones', const Color(0xFF8E24AA)), // Púrpura
            _buildTrendingCard('#Parciales', '12k Publicaciones', const Color(0xFF2E7D32)), // Verde
            _buildTrendingCard('#FutbolUTB', '320 Publicaciones', const Color(0xFFE65100)), // Naranja
          ],
        ),
      ],
    );
  }

  Widget _buildTrendingCard(String tag, String count, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(tag, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 4),
          Text(count, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

