import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';

class NotificationService {
  static final FlutterLocalNotificationsPlugin _notif = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static Timer? _chatTimer;
  static Timer? _donateTimer;
  static int _lastMsgCount = 0;

  static Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);
    await _notif.initialize(settings);
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    final plugin = _notif.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    final granted = await plugin?.requestNotificationsPermission();
    return granted ?? false;
  }

  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const android = AndroidNotificationDetails(
      'pegasus_x_channel',
      'Pegasus-X Notifications',
      channelDescription: 'Notifikasi Pegasus-X Revenge',
      importance: Importance.high,
      priority: Priority.high,
    );
    const details = NotificationDetails(android: android);
    await _notif.show(id, title, body, details);
  }

  /// Start polling for chat notifications (every 10 seconds)
  static void startChatPolling(String myId) {
    _chatTimer?.cancel();
    _chatTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token');
        if (token == null) return;
        final res = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/chat/messages?room=global&limit=20'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 8));
        final json = jsonDecode(res.body);
        if (json['success'] == true) {
          final messages = List<Map<String, dynamic>>.from(json['messages'] ?? []);
          if (messages.isEmpty) return;
          // Only notify if there are new messages not sent by me
          final newMessages = messages
              .where((m) => m['senderId'] != myId)
              .toList();
          if (newMessages.length > _lastMsgCount && _lastMsgCount > 0) {
            final latest = newMessages.last;
            final sender = latest['senderName'] ?? 'User';
            final text = latest['text'] ?? 'Pesan baru';
            await showNotification(
              id: 1001,
              title: sender,
              body: text,
            );
          }
          _lastMsgCount = newMessages.length;
        }
      } catch (_) {}
    });
  }

  /// Donasi notification every 3 hours for non-owner users
  static void startDonateNotification(String role, String qrisUrl) {
    if (role == 'owner') return;
    _donateTimer?.cancel();
    // Show first one after 5 minutes, then every 3 hours
    _donateTimer = Timer.periodic(const Duration(hours: 3), (_) {
      showNotification(
        id: 2001,
        title: 'Donasi Seikhlasnya',
        body: 'Hei! Bantu pengembangan Pegasus-X Revenge dengan donasi seikhlasnya. Buka app untuk lihat QRIS.',
      );
    });
  }

  static void stopAll() {
    _chatTimer?.cancel();
    _donateTimer?.cancel();
    _lastMsgCount = 0;
  }
}
