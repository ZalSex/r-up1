import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

/// Global heartbeat service — jalan terus selama app aktif.
/// Juga mengecek expired premium setiap heartbeat.
class HeartbeatService with WidgetsBindingObserver {
  HeartbeatService._();
  static final HeartbeatService instance = HeartbeatService._();

  Timer? _timer;
  bool _running = false;

  // Callback yang dipanggil saat expired/session invalid
  Function()? onExpired;

  void start({Function()? onExpiredCallback}) {
    if (onExpiredCallback != null) onExpired = onExpiredCallback;
    if (_running) return;
    _running = true;
    WidgetsBinding.instance.addObserver(this);
    _sendAndSchedule();
  }

  void stop() {
    _running = false;
    _timer?.cancel();
    _timer = null;
    WidgetsBinding.instance.removeObserver(this);
    ApiService.sendLogoutStatus();
  }

  void _sendAndSchedule() {
    _checkProfile();
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 30), () {
      if (_running) _sendAndSchedule();
    });
  }

  Future<void> _checkProfile() async {
    try {
      await ApiService.sendHeartbeat();
      final res = await ApiService.getProfile();
      if (res['success'] == false) {
        final msg = (res['message'] ?? '').toString().toLowerCase();
        if (msg.contains('expired') || msg.contains('invalid token') ||
            res['expired'] == true || res['statusCode'] == 401) {
          _handleExpired();
        }
      }
    } catch (_) {}
  }

  Future<void> _handleExpired() async {
    if (!_running) return;
    stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    onExpired?.call();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        if (_running) _sendAndSchedule();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        _timer?.cancel();
        break;
      default:
        break;
    }
  }
}
