import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'video_model.dart';

/// Muestra el modal de creación de publicación.
Future<VideoModel?> showCreatePostSheet(BuildContext context) {
  return showModalBottomSheet<VideoModel>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => const CreatePostSheet(),
  );
}

class CreatePostSheet extends StatefulWidget {
  const CreatePostSheet({super.key});

  @override
  State<CreatePostSheet> createState() => _CreatePostSheetState();
}

enum PostType { video, image, flashcard, poll }

class _CreatePostSheetState extends State<CreatePostSheet> {
  PostType _selectedType = PostType.video;
  final TextEditingController _descriptionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();

  XFile? _selectedVideo;
  XFile? _selectedImage;

  // Estado para Flashcards
  final List<Map<String, dynamic>> _flashcards = [
    {
      'front': '', 
      'back': '',
      'frontImage': null, // XFile?
      'backImage': null,  // XFile?
    }
  ];

  // Estado para Encuestas
  final List<TextEditingController> _pollControllers = [];

  @override
  void initState() {
    super.initState();
    // Inicializar encuesta con 2 opciones por defecto
    _pollControllers.add(TextEditingController());
    _pollControllers.add(TextEditingController());
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    for (var controller in _pollControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.gallery);
    if (video != null) {
      setState(() {
        _selectedVideo = video;
      });
    }
  }

  Future<void> _pickImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _selectedImage = image;
      });
    }
  }

  Future<void> _pickImageForFlashcard(int index, bool isFront) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isFront) {
          _flashcards[index]['frontImage'] = image;
        } else {
          _flashcards[index]['backImage'] = image;
        }
      });
    }
  }

  void _publishPost() {
    VideoModel? newPost;

    if (_selectedType == PostType.video) {
      if (_selectedVideo == null) return; // Validación simple
      newPost = VideoModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Nuevo Video',
        videoUrl: _selectedVideo!.path,
        thumbnailUrl: '',
        description: _descriptionController.text,
        contentType: 'video',
        likes: 0,
        comments: 0,
      );
    } else if (_selectedType == PostType.image) {
      if (_selectedImage == null) return; // Validación simple
      newPost = VideoModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Nueva Imagen',
        videoUrl: _selectedImage!.path, // Usamos videoUrl para la ruta de la imagen
        thumbnailUrl: '',
        description: _descriptionController.text,
        contentType: 'image',
        likes: 0,
        comments: 0,
      );
    } else if (_selectedType == PostType.flashcard) {
      // Validar que haya al menos una flashcard completa (opcional)
      
      // Convertir XFile a String (path) para que el modelo lo pueda usar
      final processedFlashcards = _flashcards.map((card) {
        return {
          'front': card['front'],
          'back': card['back'],
          'frontImage': card['frontImage'] is XFile ? (card['frontImage'] as XFile).path : null,
          'backImage': card['backImage'] is XFile ? (card['backImage'] as XFile).path : null,
        };
      }).toList();

      // Crear el modelo de Flashcard
      newPost = VideoModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Set de Flashcards',
        videoUrl: '',
        thumbnailUrl: '',
        description: 'Flashcards educativas',
        contentType: 'flashcard',
        flashcards: processedFlashcards,
        likes: 0,
        comments: 0,
      );
    } else if (_selectedType == PostType.poll) {
      // Crear el modelo de Encuesta
      final pollOptions = _pollControllers
          .where((c) => c.text.isNotEmpty)
          .map((c) => {'text': c.text, 'votes': 0})
          .toList();

      newPost = VideoModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: _descriptionController.text.isNotEmpty ? _descriptionController.text : 'Encuesta',
        videoUrl: '',
        thumbnailUrl: '',
        description: 'Encuesta de la comunidad',
        contentType: 'poll',
        pollOptions: pollOptions,
        likes: 0,
        comments: 0,
      );
    }

    if (newPost != null) {
      VideoModel.localFeed.insert(0, newPost);
      Navigator.pop(context, newPost); // Devolvemos el post creado
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('¡Publicación creada con éxito!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usamos DraggableScrollableSheet para que se sienta nativo y expandible
    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.8,
      maxChildSize: 1.0,
      expand: false,
      builder: (context, scrollController) {
        return Scaffold(
          backgroundColor: Colors.white,
          appBar: _buildAppBar(),
          body: Column(
            children: [
              _buildTypeSelector(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: _buildContent(),
                ),
              ),
              _buildBottomBar(),
            ],
          ),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.close, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text(
        'Crear publicación',
        style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
      ),
      centerTitle: true,
    );
  }

  Widget _buildTypeSelector() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(25),
      ),
      child: Row(
        children: [
          _buildTypeTab('Video', PostType.video, Icons.videocam),
          _buildTypeTab('Imágenes', PostType.image, Icons.image),
          _buildTypeTab('Flashcards', PostType.flashcard, Icons.style),
          _buildTypeTab('Encuesta', PostType.poll, Icons.poll),
        ],
      ),
    );
  }

  Widget _buildTypeTab(String text, PostType type, IconData icon) {
    final isSelected = _selectedType == type;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedType = type),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2))
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18,
                  color: isSelected ? const Color(0xFF003399) : Colors.grey),
              if (isSelected) ...[
                const SizedBox(width: 6),
                Text(
                  text,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF003399),
                    fontSize: 13,
                  ),
                ),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    switch (_selectedType) {
      case PostType.video:
        return _buildVideoForm();
      case PostType.image:
        return _buildImageForm();
      case PostType.flashcard:
        return _buildFlashcardForm();
      case PostType.poll:
        return _buildPollForm();
    }
  }

  // --- FORMULARIO DE VIDEO ---
  Widget _buildVideoForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(
          aspectRatio: 16 / 9,
          child: GestureDetector(
            onTap: _pickVideo,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
              ),
              child: _selectedVideo != null
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.check_circle, size: 48, color: Color(0xFF003399)),
                        const SizedBox(height: 8),
                        Text('Video seleccionado', style: TextStyle(color: Colors.grey.shade800, fontWeight: FontWeight.bold)),
                        Text(_selectedVideo!.name, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), overflow: TextOverflow.ellipsis),
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.cloud_upload_outlined,
                            size: 48, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        Text(
                          'Seleccionar video de la galería',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      ],
                    ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        _buildTextField('Descripción', 'Escribe algo sobre este video...',
            controller: _descriptionController, maxLines: 3),
      ],
    );
  }

  // --- FORMULARIO DE IMÁGENES ---
  Widget _buildImageForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Descripción', '¿Qué quieres compartir hoy?',
            controller: _descriptionController, maxLines: 3),
        const SizedBox(height: 24),
        GestureDetector(
          onTap: _pickImage,
          child: Container(
            width: double.infinity,
            height: 200,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: _selectedImage != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_selectedImage!.path),
                      fit: BoxFit.cover,
                    ),
                  )
                : const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.add_photo_alternate_outlined, size: 48, color: Colors.grey),
                      SizedBox(height: 8),
                      Text("Seleccionar imagen", style: TextStyle(color: Colors.grey)),
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  // --- FORMULARIO DE FLASHCARDS ---
  Widget _buildFlashcardForm() {
    return Column(
      children: [
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _flashcards.length,
          separatorBuilder: (c, i) => const SizedBox(height: 16),
          itemBuilder: (context, index) {
            return _buildFlashcardItem(index);
          },
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () {
            setState(() {
              _flashcards.add({
                'front': '', 
                'back': '',
                'frontImage': null,
                'backImage': null,
              });
            });
          },
          icon: const Icon(Icons.add),
          label: const Text('Agregar Flashcard'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF003399),
            side: const BorderSide(color: Color(0xFF003399)),
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          ),
        ),
      ],
    );
  }

  // --- FORMULARIO DE ENCUESTA ---
  Widget _buildPollForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField('Pregunta', 'Ej: ¿Cuál es tu lenguaje favorito?',
            controller: _descriptionController, maxLines: 2),
        const SizedBox(height: 24),
        const Text('Opciones de respuesta',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _pollControllers.length,
          separatorBuilder: (c, i) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return Row(
              children: [
                Expanded(
                  child: _buildTextField('', 'Opción ${index + 1}',
                      controller: _pollControllers[index], filled: true),
                ),
                if (_pollControllers.length > 2)
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline, color: Colors.red),
                    onPressed: () => setState(() => _pollControllers.removeAt(index)),
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        if (_pollControllers.length < 5)
          TextButton.icon(
            onPressed: () {
              setState(() {
                _pollControllers.add(TextEditingController());
              });
            },
            icon: const Icon(Icons.add, color: Color(0xFF003399)),
            label: const Text('Agregar opción', style: TextStyle(color: Color(0xFF003399))),
          ),
      ],
    );
  }

  Widget _buildFlashcardItem(int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Flashcard #${index + 1}',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey)),
              if (_flashcards.length > 1)
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.red, size: 20),
                  onPressed: () {
                    setState(() {
                      _flashcards.removeAt(index);
                    });
                  },
                )
            ],
          ),
          const SizedBox(height: 8),
          _buildTextField('Frente (Pregunta)', 'Escribe el concepto...',
              filled: true,
              onChanged: (val) => _flashcards[index]['front'] = val),
          const SizedBox(height: 8),
          _buildImagePickerButton(index, true),
          const SizedBox(height: 12),
          _buildTextField('Reverso (Respuesta)', 'Escribe la definición...',
              filled: true,
              onChanged: (val) => _flashcards[index]['back'] = val),
          const SizedBox(height: 8),
          _buildImagePickerButton(index, false),
        ],
      ),
    );
  }

  Widget _buildImagePickerButton(int index, bool isFront) {
    final XFile? image = isFront 
        ? _flashcards[index]['frontImage'] 
        : _flashcards[index]['backImage'];

    if (image != null) {
      return Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.file(
              File(image.path),
              height: 100,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  if (isFront) {
                    _flashcards[index]['frontImage'] = null;
                  } else {
                    _flashcards[index]['backImage'] = null;
                  }
                });
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                child: const Icon(Icons.close, color: Colors.white, size: 16),
              ),
            ),
          ),
        ],
      );
    }

    return TextButton.icon(
      onPressed: () => _pickImageForFlashcard(index, isFront),
      icon: const Icon(Icons.image, size: 18),
      label: Text(isFront ? 'Agregar imagen al frente' : 'Agregar imagen al reverso'),
      style: TextButton.styleFrom(foregroundColor: Colors.grey.shade600),
    );
  }

  Widget _buildTextField(String label, String hint,
      {TextEditingController? controller, int maxLines = 1, bool filled = false, Function(String)? onChanged}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          onChanged: onChanged,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: Colors.grey.shade400),
            filled: filled,
            fillColor: filled ? Colors.grey.shade50 : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.shade300),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF003399), width: 2),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: _publishPost,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF003399),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              elevation: 0,
            ),
            child: const Text('Publicar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          ),
        ),
      ),
    );
  }
}