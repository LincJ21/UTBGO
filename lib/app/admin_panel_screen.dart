import 'package:flutter/material.dart';
import 'admin_api_service.dart';
import 'admin_models.dart';
import 'config/app_config.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart' as flutter_secure_storage;
class AdminPanelScreen extends StatefulWidget {
  const AdminPanelScreen({super.key});

  @override
  State<AdminPanelScreen> createState() => _AdminPanelScreenState();
}

class _AdminPanelScreenState extends State<AdminPanelScreen> {
  static const _utbDarkBlue = Color.fromRGBO(0, 26, 63, 1);
  static const _utbBaseBlue = Color.fromRGBO(1, 35, 80, 1);
  static const _utbLightBlue = Color.fromARGB(255, 4, 66, 114);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel de Administración', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: _utbBaseBlue,
          iconTheme: const IconThemeData(color: Colors.white),
          bottom: const TabBar(
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            indicatorColor: Colors.amber,
            labelPadding: EdgeInsets.symmetric(horizontal: 4.0),
            labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            unselectedLabelStyle: TextStyle(fontSize: 12),
            tabs: [
              Tab(icon: Icon(Icons.dashboard, size: 22), text: 'Dashboard'),
              Tab(icon: Icon(Icons.people, size: 22), text: 'Usuarios'),
              Tab(icon: Icon(Icons.video_library, size: 22), text: 'Videos'),
              Tab(icon: Icon(Icons.flag, size: 22), text: 'Denuncias'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _DashboardTab(),
            _UsersTab(),
            _VideosTab(),
            _ReportsTab(),
          ],
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------
// TAB 1: DASHBOARD
// ----------------------------------------------------------------------
class _DashboardTab extends StatefulWidget {
  const _DashboardTab();

  @override
  State<_DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends State<_DashboardTab> {
  final AdminApiService _apiService = AdminApiService();
  AdminStats? _stats;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final response = await _apiService.getDashboardStats();
    if (response.isSuccess && response.data != null) {
      if (mounted) setState(() => _stats = response.data);
    } else {
      if (mounted) setState(() => _error = response.error?.message ?? 'Error cargando dashboard');
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: const TextStyle(color: Colors.red)),
            ElevatedButton(onPressed: _loadStats, child: const Text('Reintentar')),
          ],
        ),
      );
    }
    if (_stats == null) return const Center(child: Text('No hay datos disponibles.'));

    return RefreshIndicator(
      onRefresh: _loadStats,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Sección de Inteligencia Artificial
          const Text('Motor Predictivo', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Card(
            color: Colors.indigo.shade50,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.psychology, size: 40, color: Colors.indigo),
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Reentrenamiento LightGBM', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text('Generar nueva versión de recomendaciones.', style: TextStyle(fontSize: 12, color: Colors.black54)),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                    onPressed: _triggerRetraining,
                    icon: const Icon(Icons.sync),
                    label: const Text("Entrenar"),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Sección Usuarios
          const Text('Usuarios', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _buildStatCard('Total', _stats!.totalUsers.toString(), Icons.people_outline, Colors.blue),
              _buildStatCard('Activos', _stats!.activeUsers.toString(), Icons.check_circle_outline, Colors.green),
              _buildStatCard('Baneados', _stats!.bannedUsers.toString(), Icons.block, Colors.red),
              _buildStatCard('Registros (7d)', _stats!.recentSignups.toString(), Icons.trending_up, Colors.orange),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Contenido', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.5,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            children: [
              _buildStatCard('Videos Totales', _stats!.totalVideos.toString(), Icons.video_library, Colors.purple),
              _buildStatCard('Publicados', _stats!.publishedVideos.toString(), Icons.visibility, Colors.indigo),
              _buildStatCard('Eliminados', _stats!.removedVideos.toString(), Icons.delete_outline, Colors.grey),
              _buildStatCard('Comentarios', _stats!.totalComments.toString(), Icons.comment, Colors.teal),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerRetraining() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Reentrenar Módulo IA"),
        content: const Text("Esta operación consumirá CPU en el servidor en segundo plano calculando nuevos pesos de Features para los usuarios. ¿Proceder?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Iniciar Entrenamiento")),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final storage = const flutter_secure_storage.FlutterSecureStorage();
      final token = await storage.read(key: 'jwt_token');
      final url = Uri.parse('${AppConfig.apiBaseUrl}/v1/admin/retrain');
      
      final response = await http.post(url, headers: {'Authorization': 'Bearer $token'});
      
      if (response.statusCode == 202) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Entrenamiento IA encolado correctamente"), backgroundColor: Colors.green));
      } else {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Motor rechazó ejecución: STATUS ${response.statusCode}"), backgroundColor: Colors.red));
      }
    } catch(e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    }
  }
}

// ----------------------------------------------------------------------
// TAB 2: USUARIOS
// ----------------------------------------------------------------------
class _UsersTab extends StatefulWidget {
  const _UsersTab();

  @override
  State<_UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<_UsersTab> {
  final AdminApiService _apiService = AdminApiService();
  final TextEditingController _searchController = TextEditingController();
  
  final List<AdminUser> _users = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _users.clear();
      });
    }

    setState(() => _isLoading = true);

    final response = await _apiService.getUsers(
      page: _currentPage,
      search: _searchController.text,
    );

    if (response.isSuccess && response.data != null) {
      if (mounted) {
        setState(() {
          _users.addAll(response.data!.data);
          _currentPage++;
          if (response.data!.page >= response.data!.totalPages) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
      _showError(response.error?.message ?? 'Error loading users');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _changeStatus(AdminUser user, String newStatus) async {
    final res = await _apiService.updateUserStatus(user.id, newStatus);
    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado actualizado')));
      _loadUsers(refresh: true);
    } else {
      _showError(res.error?.message ?? 'Error updating status');
    }
  }

  Future<void> _changeRole(AdminUser user, String newRole) async {
    final res = await _apiService.updateUserRole(user.id, newRole);
    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rol actualizado')));
      _loadUsers(refresh: true);
    } else {
      _showError(res.error?.message ?? 'Error updating role');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Buscar email o nombre...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                  ),
                  onSubmitted: (_) => _loadUsers(refresh: true),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  // TODO: Agregar filtros por status y role en el futuro
                },
              )
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadUsers(refresh: true),
            child: ListView.builder(
              itemCount: _users.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _users.length) {
                  if (!_isLoading) _loadUsers();
                  return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                }
                final user = _users[index];
                return _buildUserCard(user);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUserCard(AdminUser user) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: CircleAvatar(
          backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
          child: user.avatarUrl == null ? Text(user.name[0].toUpperCase()) : null,
        ),
        title: Text('${user.name} ${user.lastName}', style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(user.email),
        trailing: _buildStatusBadge(user.statusCode),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cambiar Estado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    DropdownButton<String>(
                      value: user.statusCode,
                      items: _buildStatusItems(user.statusCode),
                      onChanged: (val) {
                        if (val != null && val != user.statusCode) _changeStatus(user, val);
                      },
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Cambiar Rol', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                    DropdownButton<String>(
                      value: user.roleCode,
                      items: _buildRoleItems(user.roleCode),
                      onChanged: (val) {
                        if (val != null && val != user.roleCode) _changeRole(user, val);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye items de estado, asegurándose que el valor actual siempre esté presente.
  List<DropdownMenuItem<String>> _buildStatusItems(String currentValue) {
    final knownStatuses = {'activo': 'Activo', 'suspendido': 'Suspendido', 'baneado': 'Baneado'};
    if (!knownStatuses.containsKey(currentValue)) {
      knownStatuses[currentValue] = currentValue[0].toUpperCase() + currentValue.substring(1);
    }
    return knownStatuses.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();
  }

  /// Construye items de rol, asegurándose que el valor actual siempre esté presente.
  List<DropdownMenuItem<String>> _buildRoleItems(String currentValue) {
    final knownRoles = {'estudiante': 'Estudiante', 'profesor': 'Profesor', 'aspirante': 'Aspirante', 'moderador': 'Moderador', 'admin': 'Admin'};
    if (!knownRoles.containsKey(currentValue)) {
      knownRoles[currentValue] = currentValue[0].toUpperCase() + currentValue.substring(1);
    }
    return knownRoles.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'activo':
        color = Colors.green;
        break;
      case 'suspendido':
        color = Colors.orange;
        break;
      case 'baneado':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ----------------------------------------------------------------------
// TAB 3: VIDEOS
// ----------------------------------------------------------------------
class _VideosTab extends StatefulWidget {
  const _VideosTab();

  @override
  State<_VideosTab> createState() => _VideosTabState();
}

class _VideosTabState extends State<_VideosTab> {
  final AdminApiService _apiService = AdminApiService();
  final TextEditingController _searchController = TextEditingController();
  
  final List<AdminVideo> _videos = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadVideos();
  }

  Future<void> _loadVideos({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _videos.clear();
      });
    }

    setState(() => _isLoading = true);

    final response = await _apiService.getVideos(
      page: _currentPage,
      search: _searchController.text,
    );

    if (response.isSuccess && response.data != null) {
      if (mounted) {
        setState(() {
          _videos.addAll(response.data!.data);
          _currentPage++;
          if (response.data!.page >= response.data!.totalPages) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
      _showError(response.error?.message ?? 'Error loading videos');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _changeStatus(AdminVideo video, String newStatus) async {
    final res = await _apiService.updateVideoStatus(video.id, newStatus);
    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado de video actualizado')));
      _loadVideos(refresh: true);
    } else {
      _showError(res.error?.message ?? 'Error updating video status');
    }
  }

  Future<void> _deleteVideo(AdminVideo video) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Confirmar Eliminación'),
        content: const Text('¿Estás seguro de eliminar PERMANENTEMENTE este video?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Eliminar', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      final res = await _apiService.deleteVideo(video.id);
      if (!mounted) return;
      if (res.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Video eliminado permanentemente')));
        _loadVideos(refresh: true);
      } else {
        _showError(res.error?.message ?? 'Error deleting video');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar título de video...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
            ),
            onSubmitted: (_) => _loadVideos(refresh: true),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadVideos(refresh: true),
            child: ListView.builder(
              itemCount: _videos.length + (_hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _videos.length) {
                  if (!_isLoading) _loadVideos();
                  return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                }
                final video = _videos[index];
                return _buildVideoCard(video);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVideoCard(AdminVideo video) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: ExpansionTile(
        leading: video.thumbnailUrl != null
            ? Image.network(video.thumbnailUrl!, width: 50, height: 50, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.video_file, size: 40))
            : const Icon(Icons.video_file, size: 40),
        title: Text(video.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('ID: ${video.id} • ${video.authorName}'),
        trailing: _buildStatusBadge(video.statusCode),
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('Descripción: ${video.description}'),
                const SizedBox(height: 8),
                Text('Likes: ${video.likesCount} • Comentarios: ${video.commentsCount}', style: const TextStyle(color: Colors.grey)),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    DropdownButton<String>(
                      value: video.statusCode,
                      items: _buildVideoStatusItems(video.statusCode),
                      onChanged: (val) {
                        if (val != null && val != video.statusCode) _changeStatus(video, val);
                      },
                    ),
                    ElevatedButton.icon(
                      onPressed: () => _deleteVideo(video),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Eliminar (Hard)'),
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Construye items de estado de video, asegurándose que el valor actual siempre esté presente.
  List<DropdownMenuItem<String>> _buildVideoStatusItems(String currentValue) {
    final knownStatuses = {'publicado': 'Publicado', 'oculto': 'Oculto', 'eliminado': 'Eliminado'};
    if (!knownStatuses.containsKey(currentValue)) {
      knownStatuses[currentValue] = currentValue[0].toUpperCase() + currentValue.substring(1);
    }
    return knownStatuses.entries
        .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
        .toList();
  }

  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case 'publicado':
        color = Colors.green;
        break;
      case 'oculto':
        color = Colors.orange;
        break;
      case 'eliminado':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
      child: Text(status.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}

// ----------------------------------------------------------------------
// TAB 4: DENUNCIAS (REPORTES)
// ----------------------------------------------------------------------
class _ReportsTab extends StatefulWidget {
  const _ReportsTab();

  @override
  State<_ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<_ReportsTab> {
  final AdminApiService _apiService = AdminApiService();
  
  final List<AdminReport> _reports = [];
  bool _isLoading = false;
  int _currentPage = 1;
  bool _hasMore = true;

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports({bool refresh = false}) async {
    if (_isLoading) return;
    if (refresh) {
      setState(() {
        _currentPage = 1;
        _hasMore = true;
        _reports.clear();
      });
    }

    setState(() => _isLoading = true);

    final response = await _apiService.getReports(page: _currentPage);

    if (response.isSuccess && response.data != null) {
      if (mounted) {
        setState(() {
          _reports.addAll(response.data!.data);
          _currentPage++;
          if (response.data!.page >= response.data!.totalPages) {
            _hasMore = false;
          }
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
      _showError(response.error?.message ?? 'Error cargando denuncias');
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  Future<void> _resolveReport(AdminReport report, String action) async {
    // action puede ser 'ignore' o 'delete'
    final res = await _apiService.resolveReport(report.reportId, action);
    if (!mounted) return;
    if (res.isSuccess) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Reporte gestionado')));
      _loadReports(refresh: true);
    } else {
      _showError(res.error?.message ?? 'Error al procesar el reporte');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text(
            'Denuncias Pendientes de Revisión',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadReports(refresh: true),
            child: _reports.isEmpty && !_isLoading
                ? const Center(child: Text('¡Excelente! No hay denuncias pendientes.'))
                : ListView.builder(
                    itemCount: _reports.length + (_hasMore ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _reports.length) {
                        if (!_isLoading) _loadReports();
                        return const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator()));
                      }
                      final report = _reports[index];
                      return _buildReportCard(report);
                    },
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportCard(AdminReport report) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.red.shade100)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 22),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Motivo: ${report.motivo}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red, fontSize: 16),
                  ),
                ),
                Text(
                  '${report.fechaCreacion.day}/${report.fechaCreacion.month}/${report.fechaCreacion.year}',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.shade50.withValues(alpha: 0.5), 
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.shade100, width: 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: Colors.black54),
                      const SizedBox(width: 4),
                      Text('Comentario de ${report.authorName}:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black87)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('"${report.commentText}"', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 15, color: Colors.black87)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.flag_outlined, size: 14, color: Colors.grey),
                const SizedBox(width: 4),
                Text('Denunciado por: ${report.reporterName}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8.0,
              runSpacing: 8.0,
              children: [
                TextButton.icon(
                  onPressed: () => _resolveReport(report, 'ignore'),
                  icon: const Icon(Icons.close, color: Colors.grey, size: 18),
                  label: const Text('Ignorar', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton.icon(
                  onPressed: () => _resolveReport(report, 'delete'),
                  icon: const Icon(Icons.delete_outline, size: 18),
                  label: const Text('Eliminar', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.shade600, 
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
