import 'package:flutter/material.dart';
import 'dart:async';
import 'package:app_links/app_links.dart';
import 'main_navigation_page.dart';
import 'services/global_ui_service.dart';
import 'deep_link_handler_screen.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late AppLinks _appLinks;
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    try {
      final initialUri = await _appLinks.getInitialAppLink();
      if (initialUri != null) {
        _handleDeepLink(initialUri);
      }
    } catch (e) {
      debugPrint("Error reading initial deep link: $e");
    }

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleDeepLink(uri);
    }, onError: (err) {
      debugPrint("Error listening to deep links: $err");
    });
  }

  void _handleDeepLink(Uri uri) {
    debugPrint('Received Deep Link: $uri');
    final pathSegments = uri.pathSegments;
    
    // Rutas esperadas: /video/123 o /content/123
    if (pathSegments.length >= 2 && (pathSegments[0] == 'video' || pathSegments[0] == 'content')) {
      final contentId = pathSegments[1];
      
      Future.delayed(const Duration(milliseconds: 500), () {
        final context = GlobalUIService.navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => DeepLinkHandlerScreen(contentId: contentId),
            ),
          );
        }
      });
    }
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'UTBGo',
      debugShowCheckedModeBanner: false,
      navigatorKey: GlobalUIService.navigatorKey,
      scaffoldMessengerKey: GlobalUIService.scaffoldMessengerKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF003399),
          primary: const Color(0xFF003399),
        ),
        useMaterial3: true,
      ),
      home: const MainNavigationPage(),
    );
  }
}
