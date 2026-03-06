import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────
//  MODELO DE DATOS
// ─────────────────────────────────────────────────────────────

/// Tipos de notificación soportados por la aplicación.
enum NotificationType {
  announcement,
  material,
  like,
  comment,
  grade,
  event,
  follow,
}

/// Representa una notificación individual en la lista.
///
/// [type] determina el ícono de badge que se muestra sobre el avatar.
/// [isRead] controla el punto azul indicador de lectura.
/// [actionLabel] permite mostrar un botón de acción (ej. "Seguir también").
class NotificationItemModel {
  final String id;
  final String userName;
  final String body;
  final String time;
  final NotificationType type;
  bool isRead;
  final String? actionLabel;

  NotificationItemModel({
    required this.id,
    required this.userName,
    required this.body,
    required this.time,
    required this.type,
    this.isRead = false,
    this.actionLabel,
  });
}

/// Agrupa notificaciones bajo una sección temporal (HOY, AYER, etc.).
class NotificationSection {
  final String title;
  final List<NotificationItemModel> items;

  const NotificationSection({required this.title, required this.items});
}

// ─────────────────────────────────────────────────────────────
//  PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────

/// Pantalla de notificaciones agrupadas por sección temporal.
///
/// Incluye acciones de "marcar todo como leído", seguir usuarios,
/// y la barra de navegación inferior con el degradado azul UTB.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late List<NotificationSection> _sections;

  // ── Colores del diseño ──
  static const _utbDarkBlue = Color.fromRGBO(0, 26, 63, 1);
  static const _utbBaseBlue = Color.fromRGBO(1, 35, 80, 1);
  static const _utbLightBlue = Color.fromARGB(255, 4, 66, 114);
  static const _unreadDotColor = Color(0xFF1976D2);
  static const _followButtonColor = Color(0xFF1565C0);
  static const _sectionHeaderColor = Color(0xFF757575);

  @override
  void initState() {
    super.initState();
    _sections = _buildMockSections();
  }

  // ── Datos de ejemplo (coinciden con la imagen) ──

  List<NotificationSection> _buildMockSections() {
    return [
      NotificationSection(
        title: 'HOY',
        items: [
          NotificationItemModel(
            id: '1',
            userName: 'Secretaría Académica',
            body: ' ha publicado un nuevo anuncio oficial.',
            time: 'Hace 15 minutos',
            type: NotificationType.announcement,
          ),
          NotificationItemModel(
            id: '2',
            userName: '',
            body:
                'Nuevo material disponible en Cálculo Diferencial: "Derivadas Parciales".',
            time: 'Hace 1 hora',
            type: NotificationType.material,
          ),
          NotificationItemModel(
            id: '3',
            userName: 'María González',
            body: ' le gustó tu comentario en el foro de estudiantes.',
            time: 'Hace 2 horas',
            type: NotificationType.like,
          ),
        ],
      ),
      NotificationSection(
        title: 'AYER',
        items: [
          NotificationItemModel(
            id: '4',
            userName: 'Carlos Rodriguez',
            body:
                ' comentó en tu publicación: "Excelente iniciativa para el grupo de estudio..."',
            time: 'Ayer a las 14:30',
            type: NotificationType.comment,
            isRead: true,
          ),
          NotificationItemModel(
            id: '5',
            userName: '',
            body:
                'Tu nota del parcial de Programación II ha sido actualizada.',
            time: 'Ayer a las 09:15',
            type: NotificationType.grade,
            isRead: true,
          ),
          NotificationItemModel(
            id: '6',
            userName: '',
            body:
                'Recordatorio: La Feria de Emprendimiento UTB comienza mañana en el campus principal.',
            time: 'Ayer a las 08:00',
            type: NotificationType.event,
            isRead: true,
          ),
        ],
      ),
      NotificationSection(
        title: 'ESTA SEMANA',
        items: [
          NotificationItemModel(
            id: '7',
            userName: 'Ana P.',
            body: ' comenzó a seguirte.',
            time: 'Lunes',
            type: NotificationType.follow,
            isRead: true,
            actionLabel: 'Seguir también',
          ),
        ],
      ),
    ];
  }

  // ── Acciones ──

  /// Marca todas las notificaciones como leídas.
  void _markAllAsRead() {
    setState(() {
      for (final section in _sections) {
        for (final item in section.items) {
          item.isRead = true;
        }
      }
    });
  }

  /// Marca una notificación individual como leída al tocarla.
  void _onNotificationTap(NotificationItemModel notification) {
    if (!notification.isRead) {
      setState(() => notification.isRead = true);
    }
    // TODO: Navegar al contenido relacionado según el tipo.
  }

  // ── Build ──

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Notificaciones',
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black87),
            onPressed: () => _showOptionsMenu(context),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _sections.length,
        itemBuilder: (_, i) => _buildSection(_sections[i], isFirst: i == 0),
      ),
      // Barra de navegación inferior idéntica a MainNavigationPage
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  /// Muestra un menú de opciones contextual.
  void _showOptionsMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.done_all),
              title: const Text('Marcar todo como leído'),
              onTap: () {
                _markAllAsRead();
                Navigator.pop(context);
              },
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Configuración de notificaciones'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  // ── Componentes de sección ──

  Widget _buildSection(NotificationSection section, {required bool isFirst}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header de la sección
        Padding(
          padding: EdgeInsets.fromLTRB(16, isFirst ? 8 : 24, 16, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                section.title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _sectionHeaderColor,
                  letterSpacing: 0.5,
                ),
              ),
              // Solo la primera sección muestra "Marcar todo como leído"
              if (isFirst)
                GestureDetector(
                  onTap: _markAllAsRead,
                  child: const Text(
                    'Marcar todo como leído',
                    style: TextStyle(
                      fontSize: 13,
                      color: _followButtonColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Lista de notificaciones
        ...section.items.map(_buildNotificationTile),
      ],
    );
  }

  // ── Tile individual ──

  Widget _buildNotificationTile(NotificationItemModel notification) {
    return InkWell(
      onTap: () => _onNotificationTap(notification),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar con badge de tipo
            _buildAvatarWithBadge(notification.type),
            const SizedBox(width: 14),
            // Contenido
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildNotificationText(notification),
                  const SizedBox(height: 4),
                  Text(
                    notification.time,
                    style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                  ),
                  // Botón de acción (ej. "Seguir también")
                  if (notification.actionLabel != null) ...[
                    const SizedBox(height: 8),
                    _buildActionButton(notification.actionLabel!),
                  ],
                ],
              ),
            ),
            // Punto azul de no leído
            if (!notification.isRead) ...[
              const SizedBox(width: 8),
              Container(
                margin: const EdgeInsets.only(top: 6),
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: _unreadDotColor,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Construye el texto de la notificación con partes en negrita.
  Widget _buildNotificationText(NotificationItemModel notification) {
    // Si tiene usuario, lo mostramos en negrita antes del cuerpo.
    if (notification.userName.isNotEmpty) {
      return RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 14,
            color: Colors.black87,
            height: 1.35,
          ),
          children: [
            TextSpan(
              text: notification.userName,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(text: notification.body),
          ],
        ),
      );
    }

    // Notificaciones sin usuario: buscamos texto entre ** para poner en negrita.
    return _buildRichBody(notification.body);
  }

  /// Parsea texto con palabras clave en negrita.
  /// Las palabras clave se detectan si están en la lista predefinida.
  Widget _buildRichBody(String body) {
    // Palabras que deben ir en negrita (coinciden con la imagen)
    const boldKeywords = [
      'Cálculo Diferencial',
      'Programación II',
      'Feria de Emprendimiento UTB',
    ];

    List<TextSpan> spans = [];
    String remaining = body;

    while (remaining.isNotEmpty) {
      int earliestIndex = remaining.length;
      String? foundKeyword;

      for (final keyword in boldKeywords) {
        final idx = remaining.indexOf(keyword);
        if (idx != -1 && idx < earliestIndex) {
          earliestIndex = idx;
          foundKeyword = keyword;
        }
      }

      if (foundKeyword != null) {
        // Texto antes del keyword
        if (earliestIndex > 0) {
          spans.add(TextSpan(text: remaining.substring(0, earliestIndex)));
        }
        // Keyword en negrita
        spans.add(TextSpan(
          text: foundKeyword,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ));
        remaining = remaining.substring(earliestIndex + foundKeyword.length);
      } else {
        spans.add(TextSpan(text: remaining));
        remaining = '';
      }
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 14,
          color: Colors.black87,
          height: 1.35,
        ),
        children: spans,
      ),
    );
  }

  // ── Avatar con badge ──

  Widget _buildAvatarWithBadge(NotificationType type) {
    final config = _badgeConfig(type);

    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        children: [
          // Avatar principal
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            child: Icon(
              _avatarIcon(type),
              color: Colors.grey[600],
              size: 26,
            ),
          ),
          // Badge de tipo en la esquina inferior derecha
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: config.color,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(config.icon, size: 12, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  /// Ícono principal del avatar según el tipo de notificación.
  IconData _avatarIcon(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return Icons.account_balance;
      case NotificationType.material:
        return Icons.menu_book;
      case NotificationType.like:
        return Icons.person;
      case NotificationType.comment:
        return Icons.person;
      case NotificationType.grade:
        return Icons.school;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.follow:
        return Icons.person;
    }
  }

  /// Configuración visual del badge (color + ícono) según el tipo.
  _BadgeConfig _badgeConfig(NotificationType type) {
    switch (type) {
      case NotificationType.announcement:
        return _BadgeConfig(Colors.green.shade600, Icons.campaign);
      case NotificationType.material:
        return _BadgeConfig(_followButtonColor, Icons.menu_book);
      case NotificationType.like:
        return _BadgeConfig(Colors.red.shade400, Icons.favorite);
      case NotificationType.comment:
        return _BadgeConfig(_followButtonColor, Icons.chat_bubble);
      case NotificationType.grade:
        return _BadgeConfig(Colors.green.shade600, Icons.check_circle);
      case NotificationType.event:
        return _BadgeConfig(_followButtonColor, Icons.calendar_today);
      case NotificationType.follow:
        return _BadgeConfig(_followButtonColor, Icons.person_add);
    }
  }

  // ── Botón de acción ──

  Widget _buildActionButton(String label) {
    return ElevatedButton(
      onPressed: () {
        // TODO: Implementar lógica de seguir al usuario.
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: _followButtonColor,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
      child: Text(label),
    );
  }

  // ── Barra de navegación inferior ──

  Widget _buildBottomNavBar() {
    return Container(
      height: 60,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_utbDarkBlue, _utbBaseBlue, _utbLightBlue],
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.insert_chart_outlined, onTap: () {
            Navigator.pop(context);
            // TODO: Navegar a la pestaña de estadísticas (índice 0).
          }),
          _buildNavItemAsset('assets/images/01.png', onTap: () {
            Navigator.pop(context);
            // TODO: Navegar al feed de videos (índice 1).
          }),
          _buildNavItem(Icons.person, onTap: () {
            Navigator.pop(context);
            // TODO: Navegar al perfil (índice 2).
          }),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Icon(icon, color: Colors.white, size: 30),
        ),
      ),
    );
  }

  Widget _buildNavItemAsset(String asset, {required VoidCallback onTap}) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: Image.asset(asset, height: 30, color: Colors.white),
        ),
      ),
    );
  }
}

// ── Clase auxiliar privada ──

class _BadgeConfig {
  final Color color;
  final IconData icon;
  const _BadgeConfig(this.color, this.icon);
}
