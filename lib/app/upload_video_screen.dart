import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'config/app_config.dart';

class UploadVideoScreen extends StatefulWidget {
  const UploadVideoScreen({super.key});

  @override
  State<UploadVideoScreen> createState() => _UploadVideoScreenState();
}

class _UploadVideoScreenState extends State<UploadVideoScreen> {
  final _storage = const FlutterSecureStorage();
  final _picker = ImagePicker();

  bool _isUploading = false;
  int _selectedContentType = 0; // 0=Video, 1=Imágenes, 2=Flashcards, 3=Encuesta

  final List<_ContentType> _contentTypes = [
    _ContentType(Icons.videocam, 'Video'),
    _ContentType(Icons.image, 'Imágenes'),
    _ContentType(Icons.style, 'Flashcards'),
    _ContentType(Icons.bar_chart, 'Encuesta'),
  ];

  // Controladores Generales
  XFile? _selectedFile; // Para Video o Imagen principal
  final _descriptionController = TextEditingController();

  // Controladores Encuesta
  final _pollQuestionController = TextEditingController();
  final List<TextEditingController> _pollOptionControllers = [
    TextEditingController(),
    TextEditingController(),
  ];

  // Controladores Flashcard
  final _flashcardFrontController = TextEditingController();
  final _flashcardBackController = TextEditingController();
  XFile? _flashcardFrontImage;
  XFile? _flashcardBackImage;

  @override
  void dispose() {
    _descriptionController.dispose();
    _pollQuestionController.dispose();
    for (var c in _pollOptionControllers) {
      c.dispose();
    }
    _flashcardFrontController.dispose();
    _flashcardBackController.dispose();
    super.dispose();
  }

  Future<void> _pickFile({bool isVideo = false, bool isFlashcardFront = false, bool isFlashcardBack = false}) async {
    try {
      XFile? pickedFile;
      if (isVideo) {
        pickedFile = await _picker.pickVideo(source: ImageSource.gallery);
      } else {
        pickedFile = await _picker.pickImage(source: ImageSource.gallery);
      }
      
      if (pickedFile == null || !mounted) return;

      setState(() {
        if (isFlashcardFront) {
          _flashcardFrontImage = pickedFile;
        } else if (isFlashcardBack) {
          _flashcardBackImage = pickedFile;
        } else {
          _selectedFile = pickedFile;
        }
      });
    } catch (e) {
      debugPrint("Error al seleccionar archivo: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error al seleccionar el archivo.')),
      );
    }
  }

  void _addPollOption() {
    setState(() {
      _pollOptionControllers.add(TextEditingController());
    });
  }

  Future<void> _uploadContent() async {
    // Validaciones dependiendo del tipo
    if (_selectedContentType == 0 || _selectedContentType == 1) {
      if (_selectedFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Por favor, selecciona un archivo primero.')),
        );
        return;
      }
    } else if (_selectedContentType == 3) {
      if (_pollQuestionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ingresa la pregunta de la encuesta.')),
        );
        return;
      }
    } else if (_selectedContentType == 2) {
       if (_flashcardFrontController.text.trim().isEmpty || _flashcardBackController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Llena tanto el frente como el reverso de la flashcard.')),
        );
        return;
       }
    }

    setState(() => _isUploading = true);

    final token = await _storage.read(key: 'jwt_token');
    if (token == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sesión expirada.')),
        );
      }
      setState(() => _isUploading = false);
      return;
    }

    // Aquí iría la lógica de subida real con http.MultipartRequest
    // Simulamos un retraso por ahora para todas las opciones para no romper la app
    // Ya que los endpoints seguramente deben ser ajustados en el backend para admitir
    // diferentes tipos de datos.

    try {
      if (_selectedContentType == 0) { // Video (Lógica original)
        final file = File(_selectedFile!.path);
        final fileSize = await file.length();
        final maxSize = AppConfig.maxVideoSizeMB * 1024 * 1024;

        if (fileSize > maxSize) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Archivo muy grande. Máximo: ${AppConfig.maxVideoSizeMB}MB')),
          );
          setState(() => _isUploading = false);
          return;
        }

        var request = http.MultipartRequest('POST', Uri.parse(AppConfig.videosUploadEndpoint));
        request.headers['Authorization'] = 'Bearer $token';

        request.fields['title'] = _contentTypes[_selectedContentType].label;
        request.fields['description'] = _descriptionController.text;
        request.files.add(await http.MultipartFile.fromPath('video', _selectedFile!.path));

        final response = await request.send();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Publicación subida con éxito!')),
          );
          Navigator.of(context).pop();
        } else {
          final respStr = await response.stream.bytesToString();
          throw Exception('Fallo: ${response.statusCode} - $respStr');
        }
      } else if (_selectedContentType == 2) {
        // ── Flashcard: POST JSON al backend ──
        final body = jsonEncode({
          'title': _descriptionController.text.isNotEmpty
              ? _descriptionController.text
              : 'Flashcard',
          'description': _descriptionController.text,
          'front_text': _flashcardFrontController.text.trim(),
          'back_text': _flashcardBackController.text.trim(),
        });

        final response = await http.post(
          Uri.parse(AppConfig.flashcardsEndpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Flashcard creada con éxito!')),
          );
          Navigator.of(context).pop();
        } else {
          throw Exception('Error ${response.statusCode}: ${response.body}');
        }
      } else if (_selectedContentType == 3) {
        // ── Encuesta: POST JSON al backend ──
        final options = _pollOptionControllers
            .map((c) => c.text.trim())
            .where((t) => t.isNotEmpty)
            .toList();

        if (options.length < 2) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Se necesitan al menos 2 opciones.')),
          );
          setState(() => _isUploading = false);
          return;
        }

        final body = jsonEncode({
          'title': _pollQuestionController.text.trim(),
          'description': _descriptionController.text,
          'question': _pollQuestionController.text.trim(),
          'options': options,
        });

        final response = await http.post(
          Uri.parse(AppConfig.pollsEndpoint),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: body,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Encuesta creada con éxito!')),
          );
          Navigator.of(context).pop();
        } else {
          throw Exception('Error ${response.statusCode}: ${response.body}');
        }
      } else if (_selectedContentType == 1) {
        // ── Imagen: sube como contenido multimedia ──
        final file = File(_selectedFile!.path);
        final fileSize = await file.length();
        final maxSize = AppConfig.maxVideoSizeMB * 1024 * 1024;

        if (fileSize > maxSize) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Imagen muy grande. Máximo: ${AppConfig.maxVideoSizeMB}MB')),
          );
          setState(() => _isUploading = false);
          return;
        }

        var request = http.MultipartRequest('POST', Uri.parse(AppConfig.videosUploadEndpoint));
        request.headers['Authorization'] = 'Bearer $token';
        request.fields['title'] = _descriptionController.text.isNotEmpty ? 'Imagen: ${_descriptionController.text}' : 'Imagen';
        request.fields['description'] = _descriptionController.text;
        request.fields['content_type'] = 'imagen';
        request.files.add(await http.MultipartFile.fromPath('video', _selectedFile!.path));

        final response = await request.send();

        if (response.statusCode >= 200 && response.statusCode < 300) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('¡Imagen subida con éxito!')),
          );
          Navigator.of(context).pop();
        } else {
          final respStr = await response.stream.bytesToString();
          throw Exception('Fallo: ${response.statusCode} - $respStr');
        }
      }

    } catch (e) {
      debugPrint("Error al subir: $e");
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir: $e')),
      );
    } finally {
      if(mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black, size: 28),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Crear publicación',
          style: TextStyle(color: Colors.black, fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Selectores
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: List.generate(_contentTypes.length, (index) {
                  final ct = _contentTypes[index];
                  final selected = _selectedContentType == index;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedContentType = index;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: selected ? Colors.white : Colors.transparent,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: selected ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ] : [],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(ct.icon, size: 18, color: selected ? const Color(0xFF003399) : Colors.grey.shade500),
                            if (selected) const SizedBox(width: 6),
                            if (selected)
                              Flexible(
                                child: Text(
                                  ct.label,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Color(0xFF003399),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: _buildFormContent(),
            ),
          ),

          // Botón Publicar
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _isUploading ? null : _uploadContent,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003399),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: _isUploading
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                    : const Text('Publicar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContent() {
    switch (_selectedContentType) {
      case 0: // Video
      case 1: // Imagen
        return _buildMediaForm(isVideo: _selectedContentType == 0);
      case 2: // Flashcards
        return _buildFlashcardForm();
      case 3: // Encuesta
        return _buildPollForm();
      default:
        return const SizedBox();
    }
  }

  // FORMULARIO DE VIDEO / IMAGEN
  Widget _buildMediaForm({required bool isVideo}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: () => _pickFile(isVideo: isVideo),
          child: Container(
            height: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFFAFAFA),
              border: Border.all(color: Colors.grey.shade300, width: 1.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _selectedFile != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(isVideo ? Icons.video_file : Icons.image, size: 48, color: const Color(0xFF003399)),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            File(_selectedFile!.path).path.split(Platform.pathSeparator).last,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  )
                : Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(isVideo ? Icons.cloud_upload : Icons.add_photo_alternate, size: 48, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      Text(
                        'Seleccionar ${isVideo ? 'video' : 'imagen'}',
                        style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Descripción', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _descriptionController,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: '¿Qué quieres compartir hoy?',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: false,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
      ],
    );
  }

  // FORMULARIO DE ENCUESTA
  Widget _buildPollForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('Pregunta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        TextField(
          controller: _pollQuestionController,
          decoration: InputDecoration(
            hintText: 'Ej: ¿Cuál es tu lenguaje favorito?',
            hintStyle: TextStyle(color: Colors.grey.shade400),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            contentPadding: const EdgeInsets.all(16),
          ),
        ),
        const SizedBox(height: 24),
        const Text('Opciones de respuesta', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        ...List.generate(_pollOptionControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextField(
              controller: _pollOptionControllers[index],
              decoration: InputDecoration(
                hintText: 'Opción ${index + 1}',
                hintStyle: TextStyle(color: Colors.grey.shade400),
                filled: true,
                fillColor: const Color(0xFFFAFAFA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade200),
                ),
                contentPadding: const EdgeInsets.all(16),
              ),
            ),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addPollOption,
            icon: const Icon(Icons.add, size: 20, color: Color(0xFF003399)),
            label: const Text('Agregar opción', style: TextStyle(color: Color(0xFF003399), fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }

  // FORMULARIO DE FLASHCARDS
  Widget _buildFlashcardForm() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Flashcard #1', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(height: 16),
          
          const Text('Frente (Pregunta)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _flashcardFrontController,
            decoration: InputDecoration(
              hintText: 'Escribe el concepto...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _imageSelectorRow('Agregar imagen al frente', true),
          
          const SizedBox(height: 24),
          
          const Text('Reverso (Respuesta)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _flashcardBackController,
            maxLines: 2,
            decoration: InputDecoration(
              hintText: 'Escribe la definición...',
              hintStyle: TextStyle(color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade200),
              ),
            ),
          ),
          const SizedBox(height: 8),
          _imageSelectorRow('Agregar imagen al reverso', false),
          
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () {}, // Por ahora no hace nada mas que lucir bonito
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Agregar Flashcard'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF003399),
              side: const BorderSide(color: Color(0xFF003399)),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          )
        ],
      ),
    );
  }

  Widget _imageSelectorRow(String label, bool isFront) {
    bool hasImg = isFront ? _flashcardFrontImage != null : _flashcardBackImage != null;
    return GestureDetector(
      onTap: () => _pickFile(isFlashcardFront: isFront, isFlashcardBack: !isFront),
      child: Row(
        children: [
          Icon(hasImg ? Icons.image : Icons.image_outlined, size: 18, color: hasImg ? Colors.green : Colors.grey.shade600),
          const SizedBox(width: 8),
          Text(
            hasImg ? 'Imagen seleccionada' : label,
            style: TextStyle(fontSize: 13, color: hasImg ? Colors.green : Colors.grey.shade600, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _ContentType {
  final IconData icon;
  final String label;
  const _ContentType(this.icon, this.label);
}
