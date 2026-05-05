import 'package:flutter/material.dart';
import 'notification_api_service.dart';

// ─────────────────────────────────────────────────────────────
//  MODELO DE DATOS (adaptado al backend real)
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
class NotificationItemModel {
  final int id;
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

  /// Convierte un BackendNotification en un NotificationItemModel para la UI.
  factory NotificationItemModel.fromBackend(BackendNotification n) {
    return NotificationItemModel(
      id: n.id,
      userName: n.actorName,
      body: n.body,
      time: _formatTime(n.createdAt),
      type: _mapType(n.type),
      isRead: n.isRead,
      actionLabel: n.type == 'follow' ? 'Seguir también' : null,
    );
  }

  static NotificationType _mapType(String type) {
    switch (type) {
      case 'like':
        return NotificationType.like;
      case 'comment':
        return NotificationType.comment;
      case 'follow':
        return NotificationType.follow;
      case 'announcement':
        return NotificationType.announcement;
      case 'material':
        return NotificationType.material;
      case 'grade':
        return NotificationType.grade;
      case 'event':
        return NotificationType.event;
      default:
        return NotificationType.announcement;
    }
  }

  static String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);

    if (diff.inMinutes < 1) return 'Justo ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} minutos';
    if (diff.inHours < 24) return 'Hace ${diff.inHours} horas';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return '${dt.day}/${dt.month}/${dt.year}';
  }
}

/// Agrupa notificaciones bajo una sección temporal.
class NotificationSection {
  final String title;
  final List<NotificationItemModel> items;

  const NotificationSection({required this.title, required this.items});
}

// ─────────────────────────────────────────────────────────────
//  PANTALLA PRINCIPAL
// ─────────────────────────────────────────────────────────────

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationApiService _apiService = NotificationApiService();
  List<NotificationSection> _sections = [];
  bool _isLoading = true;
  String? _error;

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
    _loadNotifications();
  }

  /// Carga las notificaciones reales del backend.
  Future<void> _loadNotifications() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.getNotifications(pageSize: 50);

    if (!mounted) return;

    if (response.isSuccess && response.data != null) {
      final items = response.data!
          .map((n) => NotificationItemModel.fromBackend(n))
          .toList();
      setState(() {
        _sections = _groupBySections(items);
        _isLoading = false;
      });
    } else {
      setState(() {
        _error = response.error?.message ?? 'Error cargando notificaciones';
        _isLoading = false;
      });
    }
  }

  /// Agrupa las notificaciones por secciones temporales (HOY, AYER, ESTA SEMANA, ANTERIORES).
  List<NotificationSection> _groupBySections(List<NotificationItemModel> items) {
    if (items.isEmpty) return [];

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final weekAgo = today.subtract(const Duration(days: 7));

    final todayItems = <NotificationItemModel>[];
    final yesterdayItems = <NotificationItemModel>[];
    final weekItems = <NotificationItemModel>[];
    final olderItems = <NotificationItemModel>[];

    for (final item in items) {
      // Parseamos la fecha real desde el backend notification
      // Ya convertimos a string de tiempo relativo, así que usamos la original
      final createdAt = _getCreatedAt(item);

      if (createdAt.isAfter(today)) {
        todayItems.add(item);
      } else if (createdAt.isAfter(yesterday)) {
        yesterdayItems.add(item);
      } else if (createdAt.isAfter(weekAgo)) {
        weekItems.add(item);
      } else {
        olderItems.add(item);
      }
    }

    final sections = <NotificationSection>[];
    if (todayItems.isNotEmpty) {
      sections.add(NotificationSection(title: 'HOY', items: todayItems));
    }
    if (yesterdayItems.isNotEmpty) {
      sections.add(NotificationSection(title: 'AYER', items: yesterdayItems));
    }
    if (weekItems.isNotEmpty) {
      sections.add(NotificationSection(title: 'ESTA SEMANA', items: weekItems));
    }
    if (olderItems.isNotEmpty) {
      sections.add(NotificationSection(title: 'ANTERIORES', items: olderItems));
    }

    return sections;
  }

  /// Obtiene el DateTime real de la notificación para agrupar.
  DateTime _getCreatedAt(NotificationItemModel item) {
    // Parseamos la hora formateada para determinar la sección
    final timeLower = item.time.toLowerCase();
    final now = DateTime.now();

    if (timeLower.contains('justo ahora') || timeLower.contains('minutos') || timeLower.contains('horas')) {
      return now; // Es de hoy
    }
    if (timeLower.contains('ayer')) {
      return now.subtract(const Duration(days: 1));
    }
    if (timeLower.contains('días')) {
      final match = RegExp(r'(\d+)').firstMatch(timeLower);
      if (match != null) {
        return now.subtract(Duration(days: int.parse(match.group(1)!)));
      }
    }
    // Fallback: intentar parsear como fecha
    return now.subtract(const Duration(days: 30));
  }

  // ── Acciones ──

  /// Marca todas las notificaciones como leídas (local + backend).
  void _markAllAsRead() async {
    setState(() {
      for (final section in _sections) {
        for (final item in section.items) {
          item.isRead = true;
        }
      }
    });
    await _apiService.markAllAsRead();
  }

  /// Marca una notificación individual como leída al tocarla.
  void _onNotificationTap(NotificationItemModel notification) async {
    if (!notification.isRead) {
      setState(() => notification.isRead = true);
      await _apiService.markAsRead(notification.id);
    }
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
      body: _buildBody(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotifications,
              child: const Text('Reintentar'),
            ),
          ],
        ),
      );
    }

    if (_sections.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.notifications_none, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No tienes notificaciones',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
            const SizedBox(height: 8),
            Text(
              'Cuando alguien interactúe con tu contenido,\naparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadNotifications,
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 16),
        itemCount: _sections.length,
        itemBuilder: (_, i) => _buildSection(_sections[i], isFirst: i == 0),
      ),
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
              leading: const Icon(Icons.refresh),
              title: const Text('Actualizar'),
              onTap: () {
                Navigator.pop(context);
                _loadNotifications();
              },
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
            _buildAvatarWithBadge(notification.type),
            const SizedBox(width: 14),
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
                  if (notification.actionLabel != null) ...[
                    const SizedBox(height: 8),
                    _buildActionButton(notification.actionLabel!),
                  ],
                ],
              ),
            ),
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

    return Text(
      notification.body,
      style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.35),
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
          CircleAvatar(
            radius: 24,
            backgroundColor: Colors.grey[200],
            child: Icon(
              _avatarIcon(type),
              color: Colors.grey[600],
              size: 26,
            ),
          ),
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
      onPressed: () {},
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
          }),
          _buildNavItemAsset('assets/images/01.png', onTap: () {
            Navigator.pop(context);
          }),
          _buildNavItem(Icons.person, onTap: () {
            Navigator.pop(context);
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
