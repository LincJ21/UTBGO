import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _storage = const FlutterSecureStorage();
  final _picker = ImagePicker();

  XFile? _videoFile;
  bool _isUploading = false;

  Future<void> _pickVideo() async {
    try {
      final XFile? pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      setState(() {
        _videoFile = pickedFile;
      });
    } catch (e) {
      debugPrint("Error al seleccionar el video: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al seleccionar el video.')),
      );
    }
  }

  Future<void> _uploadVideo() async {
    if (_videoFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona un video primero.')),
      );
      return;
    }
    if (_titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, añade un título.')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
    });

    const String uploadUrl = 'http://10.0.2.2:8080/api/videos/upload';
    final token = await _storage.read(key: 'jwt_token');

    try {
      var request = http.MultipartRequest('POST', Uri.parse(uploadUrl));
      request.headers['Authorization'] = 'Bearer ${token ?? 'test-token'}';

      // Añadir campos de texto
      request.fields['title'] = _titleController.text;
      request.fields['description'] = _descriptionController.text;

      // Añadir archivo de video
      request.files.add(await http.MultipartFile.fromPath('video', _videoFile!.path));

      final response = await request.send();

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Video subido con éxito!')),
        );
        Navigator.of(context).pop(); // Volver a la pantalla de perfil
      } else {
        final respStr = await response.stream.bytesToString();
        throw Exception('Fallo al subir el video: ${response.statusCode} - $respStr');
      }
    } catch (e) {
      debugPrint("Error al subir el video: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir el video: $e')),
      );
    } finally {
      setState(() {
        _isUploading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Subir Nuevo Video'),
        backgroundColor: const Color(0xFF003399),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _titleController,
                decoration: const InputDecoration(labelText: 'Título del video'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Descripción'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.video_library),
                label: Text(_videoFile == null ? 'Seleccionar Video' : 'Video seleccionado'),
                onPressed: _pickVideo,
              ),
              if (_videoFile != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Archivo: ${File(_videoFile!.path).path.split('/').last}',
                      textAlign: TextAlign.center),
                ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: _isUploading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white))
                    : const Icon(Icons.upload_file),
                label: Text(_isUploading ? 'Subiendo...' : 'Subir Video'),
                onPressed: _isUploading ? null : _uploadVideo,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003399),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
