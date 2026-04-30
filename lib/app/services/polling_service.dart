import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'notification_service.dart';
import '../view/api_constants.dart';
import 'package:flutter/foundation.dart';

class PollingService {
  static final PollingService _instance = PollingService._internal();

  factory PollingService() {
    return _instance;
  }

  PollingService._internal();

  Timer? _timer;
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final NotificationService _notificationService = NotificationService();

  void startPolling() {
    if (_timer != null && _timer!.isActive) return;

    // Poll every 10 seconds for new notifications
    _timer = Timer.periodic(const Duration(seconds: 10), (timer) {
      _checkNotifications();
    });
  }

  void stopPolling() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkNotifications() async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http.get(
        Uri.parse('${ApiConstants.apiUrl}/notifications/poll'),
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final List<dynamic> notifications = json.decode(response.body)['notifications'] ?? [];
        for (var notif in notifications) {
          _notificationService.showNotification(
            id: notif['id'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: notif['title'] ?? 'Nueva notificación',
            body: notif['message'] ?? '',
            payload: notif['link']?.toString(),
          );
        }
      }
    } catch (e) {
      debugPrint('Error polling notifications: $e');
    }
  }
}
