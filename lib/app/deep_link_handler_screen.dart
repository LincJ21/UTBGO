import 'package:flutter/material.dart';
import 'config/api_client.dart';
import 'config/app_config.dart';
import 'video_model.dart';
import 'single_video_screen.dart';

class DeepLinkHandlerScreen extends StatefulWidget {
  final String contentId;

  const DeepLinkHandlerScreen({super.key, required this.contentId});

  @override
  State<DeepLinkHandlerScreen> createState() => _DeepLinkHandlerScreenState();
}

class _DeepLinkHandlerScreenState extends State<DeepLinkHandlerScreen> {
  final _apiClient = ApiClient();
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _loadContent();
  }

  Future<void> _loadContent() async {
    try {
      final response = await _apiClient.get<Map<String, dynamic>>(
        '${AppConfig.videosEndpoint}/${widget.contentId}',
        requiresAuth: false,
      );

      if (response.isSuccess && response.data != null && mounted) {
        final video = VideoModel.fromJson(response.data!);
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => SingleVideoScreen(video: video),
          ),
        );
      } else {
        if (mounted) setState(() => _hasError = true);
      }
    } catch (e) {
      if (mounted) setState(() => _hasError = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Center(
        child: _hasError
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Contenido no encontrado',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Volver'),
                  )
                ],
              )
            : const CircularProgressIndicator(color: Colors.white),
      ),
    );
  }
}
