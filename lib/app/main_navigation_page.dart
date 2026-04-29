import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'config/app_config.dart';
import 'config/api_client.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'videos_screen.dart';
import 'explore_screen.dart'; // <--- Importado el nuevo Explore Screen
import 'widgets/main_bottom_nav_bar.dart';

class MainNavigationPage extends StatefulWidget {
  final int initialSelectedIndex;

  const MainNavigationPage({
    super.key,
    this.initialSelectedIndex = 1,
  });

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  bool? _isAuthenticated;
  late int _selectedIndex;
  bool _isBottomBarVisible = true;

  void _setBottomBarVisibility(bool isVisible) {
    if (_isBottomBarVisible != isVisible) {
      setState(() => _isBottomBarVisible = isVisible);
    }
  }

  late final List<Widget> _pages;

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  void _handleLogout() {
    const storage = FlutterSecureStorage();
    Future.wait([
      storage.delete(key: 'jwt_token'),
      storage.delete(key: 'refresh_token'),
    ]).then((_) {
      setState(() {
        _isAuthenticated = false;
        _selectedIndex = 1;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    _selectedIndex =
        widget.initialSelectedIndex >= 0 && widget.initialSelectedIndex <= 2
            ? widget.initialSelectedIndex
            : 1;
    _pages = <Widget>[
      const ExploreScreen(), // <--- Nueva pantalla de Explorar!
      VideosScreen(onVisibilityChanged: _setBottomBarVisibility),
      ProfileScreen(onLogout: _handleLogout),
    ];
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');

    // Si ya estamos autenticados, actualicemos el rol silenciosamente
    if (token != null && token.isNotEmpty) {
      _cacheUserRoleSilently();
    }

    if (!mounted) return;
    setState(() {
      _isAuthenticated = token != null && token.isNotEmpty;
    });
  }

  Future<void> _cacheUserRoleSilently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getString('role') != null &&
          prefs.getString('role') != 'estudiante') return;

      final apiClient = ApiClient();
      final res = await apiClient.get(
          '${AppConfig.backendBaseUrl}/api/v1/profile/me',
          requiresAuth: true);
      if (res.isSuccess && res.data != null) {
        final data = res.data as Map<String, dynamic>;
        if (data['user'] != null && data['user']['role'] != null) {
          await prefs.setString('role', data['user']['role']);
        }
      }
    } catch (_) {}
  }

  void _onLoginSuccess() {
    setState(() => _isAuthenticated = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated!) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: _isBottomBarVisible ? 60.0 : 0.0,
        child: _isBottomBarVisible
            ? MainBottomNavBar(onTap: _onItemTapped)
            : const SizedBox.shrink(),
      ),
    );
  }
}
