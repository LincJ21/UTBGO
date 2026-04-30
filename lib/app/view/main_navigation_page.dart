import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'profile_screen.dart';
import 'login_screen.dart';
import 'videos_screen.dart';
import '../services/polling_service.dart';

class MainNavigationPage extends StatefulWidget {
  const MainNavigationPage({super.key});

  @override
  State<MainNavigationPage> createState() => _MainNavigationPageState();
}

class _MainNavigationPageState extends State<MainNavigationPage> {
  bool? _isAuthenticated;
  int _selectedIndex = 1;

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _handleLogout() async {
    const storage = FlutterSecureStorage();
    await storage.delete(key: 'jwt_token');
    await GoogleSignIn().signOut();
    PollingService().stopPolling();
    setState(() {
      _isAuthenticated = false;
      _selectedIndex = 1;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  Future<void> _checkAuthStatus() async {
    const storage = FlutterSecureStorage();
    final token = await storage.read(key: 'jwt_token');
    setState(() {
      _isAuthenticated = token != null && token.isNotEmpty;
    });
    if (_isAuthenticated == true) {
      PollingService().startPolling();
    }
  }

  void _onLoginSuccess() {
    setState(() {
      _isAuthenticated = true;
    });
    PollingService().startPolling();
  }

  @override
  void dispose() {
    PollingService().stopPolling();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isAuthenticated == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_isAuthenticated!) {
      return LoginScreen(onLoginSuccess: _onLoginSuccess);
    }

    final List<Widget> pages = [
      Scaffold(
        backgroundColor: const Color(0x00DDDDDD),
        body: const Center(
          child: Text('Estadísticas', style: TextStyle(color: Colors.white)),
        ),
      ),
      VideosScreen(onLogout: _handleLogout),
      ProfileScreen(onLogout: _handleLogout),
    ];

    final int safeIndex = (_selectedIndex >= pages.length) ? 1 : _selectedIndex;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
        ),
        child: pages[safeIndex],
      ),
      bottomNavigationBar: Container(
        height: 41.0,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.fromRGBO(0, 26, 63, 1),
              Color.fromRGBO(1, 35, 80, 1),
              Color.fromARGB(255, 4, 66, 114),
            ],
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildCustomNavItem(0, icon: Icons.insert_chart_outlined),
            _buildCustomNavItem(1, asset: 'assets/images/01.png'),
            _buildCustomNavItem(2, icon: Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomNavItem(int index, {IconData? icon, String? asset}) {
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          child: asset != null
              ? Image.asset(
                  asset,
                  height: 30,
                  color: Colors.white,
                )
              : Icon(
                  icon,
                  color: Colors.white,
                  size: 30,
                ),
        ),
      ),
    );
  }
}
