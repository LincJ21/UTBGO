import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  MODELO DE DATOS
// ─────────────────────────────────────────────────────────────

/// Representa un comentario individual con soporte para respuestas anidadas.
///
/// El campo [isAuthor] permite distinguir visualmente al creador del video
/// con una etiqueta "Autor".  [replies] almacena las respuestas al comentario.
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
}

// ─────────────────────────────────────────────────────────────
//  FUNCIÓN PÚBLICA PARA ABRIR EL SHEET
// ─────────────────────────────────────────────────────────────

/// Muestra el panel inferior de comentarios como un modal arrastrable.
///
/// Se invoca desde cualquier pantalla con:
/// ```dart
/// showCommentsBottomSheet(context, videoId: video.id);
/// ```
void showCommentsBottomSheet(BuildContext context, {String? videoId}) {
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

  const _CommentsSheet({
    required this.scrollController,
    this.videoId,
  });

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _inputController = TextEditingController();
  final FocusNode _inputFocusNode = FocusNode();

  late List<CommentModel> _comments;
  int _totalComments = 152;

  // ── Colores del diseño ──
  static const _authorBadgeBg = Color(0xFFE8EAF6);
  static const _authorBadgeText = Color(0xFF3949AB);
  static const _sendButtonColor = Color(0xFF1565C0);

  // ── Ciclo de vida ──

  @override
  void initState() {
    super.initState();
    _comments = _buildMockComments();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _inputFocusNode.dispose();
    super.dispose();
  }

  // ── Datos de ejemplo (coinciden con la imagen) ──

  List<CommentModel> _buildMockComments() {
    return [
      CommentModel(
        id: '1',
        userName: 'Profesor 1',
        content:
            '¡Hola a todos! Espero que disfruten este recorrido por el laboratorio de creatividad. 🎓\n💡',
        timeAgo: 'Hace 2h',
        likesCount: 24,
        isAuthor: true,
      ),
      CommentModel(
        id: '2',
        userName: 'Mariana López',
        content:
            'Me encanta la iniciativa del laboratorio "El Patio". ¿Cuándo son las inscripciones para el taller de LEGO? 😄',
        timeAgo: 'Hace 45m',
        likesCount: 8,
        isLiked: true,
        replies: [
          CommentModel(
            id: '2-1',
            userName: 'Carlos David',
            content:
                'Hola Mariana, empiezan la próxima semana. Pásate por la oficina de bienestar.',
            timeAgo: 'Hace 10m',
            likesCount: 2,
          ),
        ],
      ),
      CommentModel(
        id: '3',
        userName: 'Juan Pérez',
        content: 'Excelente video profe! 🔥🔥🔥',
        timeAgo: 'Hace 5m',
      ),
      CommentModel(
        id: '4',
        userName: 'Luisa F.',
        content: 'Necesito info sobre las prácticas 👋',
        timeAgo: 'Hace 1m',
      ),
    ];
  }

  // ── Acciones ──

  /// Alterna el "like" local de un comentario.
  void _toggleLike(CommentModel comment) {
    setState(() {
      comment.isLiked = !comment.isLiked;
      comment.likesCount += comment.isLiked ? 1 : -1;
    });
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
  void _sendComment() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _comments.add(CommentModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        userName: 'Tú',
        content: text,
        timeAgo: 'Ahora',
      ));
      _totalComments++;
    });

    _inputController.clear();
    _inputFocusNode.unfocus();
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
            child: ListView.builder(
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
          Row(
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
              onTap: _sendComment,
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: _sendButtonColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.send, color: Colors.white, size: 18),
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
