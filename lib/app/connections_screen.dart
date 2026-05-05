import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'config/app_config.dart';
import 'public_profile_screen.dart';

class ConnectionsScreen extends StatefulWidget {
  final int userId;
  final String username;
  final int initialTabIndex; // 0 para seguidores, 1 para seguidos

  const ConnectionsScreen({
    super.key,
    required this.userId,
    required this.username,
    this.initialTabIndex = 0,
  });

  @override
  State<ConnectionsScreen> createState() => _ConnectionsScreenState();
}

class _ConnectionsScreenState extends State<ConnectionsScreen> {
  final _storage = const FlutterSecureStorage();
  bool _isLoading = true;
  String? _errorMessage;

  List<dynamic> _followers = [];
  List<dynamic> _following = [];

  @override
  void initState() {
    super.initState();
    _fetchConnections();
  }

  Future<void> _fetchConnections() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) throw Exception("No autenticado");

      final url = Uri.parse('${AppConfig.backendBaseUrl}/api/v1/profile/public/${widget.userId}/connections');
      final response = await http.get(url, headers: {'Authorization': 'Bearer $token'});

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _followers = data['followers'] ?? [];
          _following = data['following'] ?? [];
          _isLoading = false;
        });
      } else {
        throw Exception("Error al cargar conexiones");
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFollow(int targetUserId, bool currentStatus, String listType, int index) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      final url = Uri.parse(AppConfig.publicProfileFollowEndpoint(targetUserId));
      
      http.Response response;
      if (currentStatus) {
        response = await http.delete(url, headers: {'Authorization': 'Bearer $token'});
      } else {
        response = await http.post(url, headers: {'Authorization': 'Bearer $token'});
      }

      if (response.statusCode == 200) {
        setState(() {
          if (listType == 'followers') {
            _followers[index]['is_following'] = !currentStatus;
          } else {
            _following[index]['is_following'] = !currentStatus;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error procesando solicitud")));
      }
    }
  }

  Widget _buildUserList(List<dynamic> users, String listType) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              listType == 'followers' ? 'Aún no tienes seguidores' : 'Aún no sigues a nadie',
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (context, index) {
        final user = users[index];
        final isFollowing = user['is_following'] ?? false;
        final isMe = user['user_id'] == widget.userId; // Simplificación, en realidad habría que comparar con el logged in userID

        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: CircleAvatar(
            backgroundColor: Colors.grey[200],
            backgroundImage: user['avatar_url'] != null && user['avatar_url'].toString().isNotEmpty
                ? NetworkImage(user['avatar_url'])
                : null,
            child: user['avatar_url'] == null || user['avatar_url'].toString().isEmpty
                ? Text(user['username'] != null && user['username'].toString().isNotEmpty ? user['username'][0].toString().toUpperCase() : 'U')
                : null,
          ),
          title: Text(
            user['username'] ?? 'Usuario',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            user['role'].toString().toUpperCase(),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          trailing: isMe ? null : ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: isFollowing ? Colors.grey[300] : const Color(0xFF003399),
              foregroundColor: isFollowing ? Colors.black87 : Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () => _toggleFollow(user['user_id'], isFollowing, listType, index),
            child: Text(isFollowing ? 'Siguiendo' : 'Seguir'),
          ),
          onTap: () {
            Navigator.push(context, MaterialPageRoute(
              builder: (context) => PublicProfileScreen(authorId: user['user_id']),
            ));
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTabIndex,
      child: Scaffold(
        appBar: AppBar(
          title: Text(widget.username, style: const TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          bottom: const TabBar(
            labelColor: Colors.black,
            indicatorColor: Color(0xFF003399),
            tabs: [
              Tab(text: "Seguidores"),
              Tab(text: "Seguidos"),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _errorMessage != null
                ? Center(child: Text(_errorMessage!))
                : TabBarView(
                    children: [
                      _buildUserList(_followers, 'followers'),
                      _buildUserList(_following, 'following'),
                    ],
                  ),
      ),
    );
  }
}
