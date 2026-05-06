import 'package:flutter/material.dart';
import 'services/comment_api_service.dart';
import 'package:timeago/timeago.dart' as timeago;

// ─────────────────────────────────────────────────────────────
//  MODELO DE DATOS
// ─────────────────────────────────────────────────────────────

/// Representa un comentario individual con soporte para respuestas anidadas.
class CommentModel {
  final String id;
  final String userName;
  final String content;
  final String timeAgo;
  int likesCount;
  final bool isAuthor;
  final List<CommentModel> replies;
  bool isLiked;

  CommentModel({
    required this.id,
    required this.userName,
    required this.content,
    required this.timeAgo,
    this.likesCount = 0,
    this.isAuthor = false,
    List<CommentModel>? replies,
    this.isLiked = false,
  }) : replies = replies ?? [];

  /// Factory manual para mapear la respuesta del backend
  factory CommentModel.fromMap(Map<String, dynamic> map, {bool isAuthor = false}) {
    DateTime createdAt = DateTime.parse(map['created_at']);
    return CommentModel(
      id: map['id']?.toString() ?? '',
      userName: map['username'] ?? 'Usuario',
      content: map['text'] ?? '',
      timeAgo: timeago.format(createdAt, locale: 'es'),
      likesCount: 0, // Por ahora no viene en la v2 inmediatamente
      isLiked: false,
      isAuthor: isAuthor, // Necesitarías comparar los IDs para saber si es autor
      replies: [], // TODO: implementar unidesidado después si el backend lo soporta
    );
  }
}

// ─────────────────────────────────────────────────────────────
//  FUNCIÓN PÚBLICA PARA ABRIR EL SHEET
// ─────────────────────────────────────────────────────────────

/// Muestra el panel inferior de comentarios como un modal arrastrable.
void showCommentsBottomSheet(BuildContext context, {String? videoId, VoidCallback? onCommentAdded}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      builder: (context, scrollController) => _CommentsSheet(
        scrollController: scrollController,
        videoId: videoId,
        onCommentAdded: onCommentAdded,
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────
//  WIDGET PRINCIPAL
// ─────────────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final ScrollController scrollController;
  final String? videoId;
  final VoidCallback? onCommentAdded;

  const _CommentsSheet({
    required this.scrollController,
    this.videoId,
    this.onCommentAdded,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();
  final CommentApiService _commentService = CommentApiService();

  List<CommentModel> _comments = [];
  int _totalComments = 0;
  bool _isLoading = true;
  bool _isSending = false;
  String? _errorMessage;

  // ── Colores del diseño ──
  static const _authorBadgeBg = Color(0xFFE8EAF6);
  static const _authorBadgeText = Color(0xFF3949AB);
  static const _sendButtonColor = Color(0xFF1565C0);

  // ── Ciclo de vida ──

  @override
  void initState() {
    super.initState();
    _fetchComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // ── Carga de Datos ──
  Future<void> _fetchComments() async {
    if (widget.videoId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = "ID de video no proporcionado.";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final response = await _commentService.getComments(widget.videoId!);
    
    if (mounted) {
      if (response.isSuccess && response.data != null) {
        final List<dynamic> currentData = response.data!;
        setState(() {
          _comments = currentData.map((e) => CommentModel.fromMap(e)).toList();
          _totalComments = _comments.length;
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.error?.message ?? "Error al cargar los comentarios";
          _isLoading = false;
        });
      }
    }
  }

  // ── Acciones ──

  /// Alterna el "like" local de un comentario.
  void _toggleLike(CommentModel comment) {
    setState(() {
      comment.isLiked = !comment.isLiked;
      comment.likesCount += comment.isLiked ? 1 : -1;
    });
  }

  /// Opciones de moderación al mantener presionado
  void _showCommentOptions(CommentModel comment) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (comment.isAuthor)
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Eliminar comentario', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _deleteComment(comment);
                  },
                )
              else
                ListTile(
                  leading: const Icon(Icons.flag, color: Colors.orange),
                  title: const Text('Reportar comentario'),
                  onTap: () {
                    Navigator.pop(context);
                    _showReportDialog(comment);
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _deleteComment(CommentModel comment) async {
    // Confirmación simple
    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar comentario'),
        content: const Text('¿Estás seguro de que quieres eliminar tu comentario? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final response = await _commentService.deleteComment(comment.id);
    if (response.isSuccess) {
      setState(() {
        _comments.removeWhere((c) => c.id == comment.id);
        _totalComments = _comments.length;
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Comentario eliminado')));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.error?.message ?? 'Error al eliminar')));
    }
  }

  void _showReportDialog(CommentModel comment) {
    String selectedMotivo = 'Spam o contenido engañoso';
    final motivos = [
      'Spam o contenido engañoso',
      'Lenguaje ofensivo o acoso',
      'Desinformación',
      'Contenido inapropiado',
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reportar comentario'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: motivos.map((motivo) {
                  return RadioListTile<String>(
                    title: Text(motivo, style: const TextStyle(fontSize: 14)),
                    value: motivo,
                    groupValue: selectedMotivo,
                    contentPadding: EdgeInsets.zero,
                    onChanged: (value) {
                      setDialogState(() => selectedMotivo = value!);
                    },
                  );
                }).toList(),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar')),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final resp = await _commentService.reportComment(comment.id, selectedMotivo);
                    if (resp.isSuccess) {
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Reporte enviado al administrador')));
                    } else {
                      ScaffoldMessenger.of(this.context).showSnackBar(const SnackBar(content: Text('Error al reportar')));
                    }
                  },
                  child: const Text('Reportar', style: TextStyle(color: Colors.red)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Prepara el campo de texto para responder a un comentario específico.
  void _replyTo(CommentModel comment) {
    _inputFocusNode.requestFocus();
    _inputController.text = '@${comment.userName} ';
    _inputController.selection = TextSelection.fromPosition(
      TextPosition(offset: _inputController.text.length),
    );
  }

  /// Envía un nuevo comentario y limpia el campo de texto.
  Future<void> _sendComment() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    if (widget.videoId == null) {
      debugPrint('Error: Video ID es nulo al intentar comentar.');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No pudimos enviar tu comentario en este momento.')));
      return;
    }
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final response = await _commentService.createComment(widget.videoId!, text);

      if (mounted) {
        if (response.isSuccess) {
          _inputController.clear();
          _inputFocusNode.unfocus();
          // Recargar los comentarios para mostrar el nuevo
          await _fetchComments();
          
          // Actualizar contador en la UI principal
          widget.onCommentAdded?.call();
        } else {
          // Si el backend de Go rechaza explícitamente el comentario, mostramos el mensaje de error de la API
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response.error?.message ?? 'No pudimos enviar tu comentario en este momento.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Excepción al enviar comentario: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ocurrió un problema de red. Por favor, intenta nuevamente.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          Expanded(
            child: _isLoading 
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                    ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                    : _comments.isEmpty
                        ? const Center(child: Text('No hay comentarios aún. ¡Sé el primero!'))
                        : ListView.builder(
                            controller: widget.scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            itemCount: _comments.length,
                            itemBuilder: (_, i) =>
                                _buildCommentTile(_comments[i], isReply: false),
                          ),
          ),
          const Divider(height: 1, color: Color(0xFFEEEEEE)),
          _buildCommentInput(),
        ],
      ),
    );
  }

  // ── Componentes internos ──

  Widget _buildDragHandle() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      width: 40,
      height: 4,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          const Spacer(),
          Text(
            'Comentarios ($_totalComments)',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close, color: Colors.black54, size: 24),
          ),
        ],
      ),
    );
  }

  /// Construye recursivamente un comentario y sus respuestas.
  Widget _buildCommentTile(CommentModel comment, {required bool isReply}) {
    final double avatarRadius = isReply ? 16 : 20;

    return Padding(
      padding: EdgeInsets.only(left: isReply ? 48 : 0, top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onLongPress: () => _showCommentOptions(comment),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Colors.grey[300],
                  child: Icon(Icons.person,
                      size: avatarRadius + 2, color: Colors.grey[600]),
                ),
                const SizedBox(width: 12),
                // Contenido del comentario
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildUserNameRow(comment),
                      const SizedBox(height: 4),
                      Text(
                        comment.content,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black87,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildActionsRow(comment),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sub-respuestas
          ...comment.replies.map(
            (reply) => _buildCommentTile(reply, isReply: true),
          ),
        ],
      ),
    );
  }

  Widget _buildUserNameRow(CommentModel comment) {
    return Row(
      children: [
        Text(
          comment.userName,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            color: Colors.black87,
          ),
        ),
        if (comment.isAuthor) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _authorBadgeBg,
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Autor',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _authorBadgeText,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildActionsRow(CommentModel comment) {
    final greyStyle = TextStyle(fontSize: 12, color: Colors.grey[500]);

    return Row(
      children: [
        Text(comment.timeAgo, style: greyStyle),
        const SizedBox(width: 16),
        GestureDetector(
          onTap: () => _replyTo(comment),
          child: Text(
            'Responder',
            style: greyStyle.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        const Spacer(),
        GestureDetector(
          onTap: () => _toggleLike(comment),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                comment.isLiked ? Icons.favorite : Icons.favorite_border,
                size: 16,
                color: comment.isLiked ? Colors.red : Colors.grey[400],
              ),
              if (comment.likesCount > 0) ...[
                const SizedBox(width: 4),
                Text('${comment.likesCount}', style: greyStyle),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInput() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        color: Colors.white,
        child: Row(
          children: [
            // Avatar del usuario actual
            CircleAvatar(
              radius: 18,
              backgroundColor: Colors.grey[300],
              child: Icon(Icons.person, size: 20, color: Colors.grey[600]),
            ),
            const SizedBox(width: 10),
            // Campo de texto con íconos internos
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        focusNode: _inputFocusNode,
                        decoration: const InputDecoration(
                          hintText: 'Añadir un comentario...',
                          hintStyle:
                              TextStyle(color: Colors.grey, fontSize: 14),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 10),
                        ),
                        style: const TextStyle(fontSize: 14),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendComment(),
                      ),
                    ),
                    _iconButton(
                      Icons.alternate_email,
                      onTap: () {
                        _inputController.text += '@';
                        _inputController.selection =
                            TextSelection.fromPosition(
                          TextPosition(offset: _inputController.text.length),
                        );
                      },
                    ),
                    _iconButton(Icons.sentiment_satisfied_alt),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Botón de enviar
            GestureDetector(
              onTap: _isSending ? null : _sendComment,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isSending ? Colors.grey : _sendButtonColor,
                  shape: BoxShape.circle,
                ),
                child: _isSending 
                    ? const Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Icon(Icons.send, color: Colors.white, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _iconButton(IconData icon, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Icon(icon, size: 20, color: Colors.grey[500]),
      ),
    );
  }
}
