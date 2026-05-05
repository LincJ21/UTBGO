import 'package:flutter/material.dart';
import 'main_navigation_page.dart';
import 'services/global_ui_service.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
