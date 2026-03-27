import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'video_model.dart';

void showDescriptionBottomSheet(BuildContext context, VideoModel video) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: const Color(0xFF1E1E1E), // Color oscuro como en el mockup
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) {
      return DescriptionBottomSheet(video: video);
    },
  );
}

class DescriptionBottomSheet extends StatelessWidget {
  final VideoModel video;

  const DescriptionBottomSheet({super.key, required this.video});

  @override
  Widget build(BuildContext context) {
    // Configurar idioma español para timeago si es necesario
    timeago.setLocaleMessages('es', timeago.EsMessages());
    final timeAgoText = timeago.format(video.createdAt, locale: 'es');

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.75, // Ocupa hasta el 75%
      ),
      padding: const EdgeInsets.only(top: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Título central y botón cerrar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Descripción',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Colors.grey, height: 1, thickness: 0.3),
          const SizedBox(height: 16),

          // Scrollable Content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Author Row (Mockups info)
                  Row(
                    children: [
                      // Avatar
                      const CircleAvatar(
                        radius: 20,
                        backgroundColor: Color(0xFF90CAF9),
                        child: Icon(Icons.person, color: Colors.white, size: 24),
                      ),
                      const SizedBox(width: 12),
                      // Nombre y tiempo
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  video.authorName.isNotEmpty ? video.authorName : 'Usuario',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Botón Seguir (Blanco con texto azul)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: const Text('Seguir',
                                      style: TextStyle(
                                          color: Color(0xFF003399),
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              timeAgoText,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Título del Video
                  Text(
                    video.title.isNotEmpty ? video.title : 'Sin título',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Estadísticas (Me gusta, visualizaciones, año)
                  Row(
                    children: [
                      Text(
                        '${video.likes} Me gusta',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${video.views} visualizaciones', // Hardcode por ahora a "0 visualizaciones" si backend no lo envía
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${video.createdAt.year}',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Descripción Completa
                  Text(
                    video.description.isNotEmpty
                        ? video.description
                        : 'No hay descripción disponible para este contenido.',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      height: 1.4, // Line height
                    ),
                  ),
                  const SizedBox(height: 32), // Espaciador final
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
