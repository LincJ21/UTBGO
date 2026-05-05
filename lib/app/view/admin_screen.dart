import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_constants.dart';

class AdminScreen extends StatefulWidget {
  const AdminScreen({Key? key}) : super(key: key);

  @override
  _AdminScreenState createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _storage = const FlutterSecureStorage();

  Map<String, dynamic> _stats = {};
  List<dynamic> _users = [];
  List<dynamic> _contents = [];

  bool _isLoadingStats = true;
  bool _isLoadingUsers = true;
  bool _isLoadingContents = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchStats();
    _fetchUsers();
    _fetchContents();
  }

  Future<String?> _getToken() async {
    return await _storage.read(key: 'jwt_token');
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.apiUrl}/admin/stats'),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (response.statusCode == 200) {
        setState(() => _stats = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching admin stats: $e');
    } finally {
      setState(() => _isLoadingStats = false);
    }
  }

  Future<void> _fetchUsers() async {
    setState(() => _isLoadingUsers = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.apiUrl}/admin/users'),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (response.statusCode == 200) {
        setState(() => _users = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching admin users: $e');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  Future<void> _fetchContents() async {
    setState(() => _isLoadingContents = true);
    try {
      final token = await _getToken();
      final response = await http.get(
        Uri.parse('${ApiConstants.apiUrl}/admin/contents'),
        headers: {'Authorization': 'Bearer ${token ?? ''}'},
      );
      if (response.statusCode == 200) {
        setState(() => _contents = json.decode(response.body));
      }
    } catch (e) {
      debugPrint('Error fetching admin contents: $e');
    } finally {
      setState(() => _isLoadingContents = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Panel de Administración'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Estadísticas', icon: Icon(Icons.dashboard)),
            Tab(text: 'Usuarios', icon: Icon(Icons.people)),
            Tab(text: 'Contenido', icon: Icon(Icons.article)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildStatsTab(),
          _buildUsersTab(),
          _buildContentsTab(),
        ],
      ),
    );
  }

  Widget _buildStatsTab() {
    if (_isLoadingStats) {
      return const Center(child: CircularProgressIndicator());
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Vista General',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  title: 'Total Usuarios',
                  value: _stats['total_users']?.toString() ?? '0',
                  icon: Icons.people,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _StatCard(
                  title: 'Total Contenido',
                  value: _stats['total_contents']?.toString() ?? '0',
                  icon: Icons.article,
                  color: Colors.green,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildUsersTab() {
    if (_isLoadingUsers) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_users.isEmpty) {
      return const Center(child: Text('No hay usuarios.'));
    }

    return ListView.builder(
      itemCount: _users.length,
      itemBuilder: (context, index) {
        final user = _users[index];
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.person)),
          title: Text(user['email'] ?? 'Sin email'),
          subtitle: Text(user['fullname']?.isEmpty == true ? 'Sin nombre' : user['fullname']),
          trailing: Text(user['date']?.substring(0, 10) ?? ''),
        );
      },
    );
  }

  Widget _buildContentsTab() {
    if (_isLoadingContents) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_contents.isEmpty) {
      return const Center(child: Text('No hay contenido.'));
    }

    return ListView.builder(
      itemCount: _contents.length,
      itemBuilder: (context, index) {
        final content = _contents[index];
        return ListTile(
          leading: const Icon(Icons.video_library),
          title: Text(content['title'] ?? 'Sin título'),
          subtitle: Text('Tipo: ${content['type'] ?? 'Desconocido'}'),
          trailing: Text(content['date']?.substring(0, 10) ?? ''),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(fontSize: 16, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
