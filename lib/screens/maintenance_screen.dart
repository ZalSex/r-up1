import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';
import '../services/api_service.dart';
import 'login_screen.dart';
import 'intro_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MaintenanceScreen extends StatefulWidget {
  const MaintenanceScreen({super.key});

  @override
  State<MaintenanceScreen> createState() => _MaintenanceScreenState();
}

class _MaintenanceScreenState extends State<MaintenanceScreen>
    with TickerProviderStateMixin {
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;
  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  Timer? _checkTimer;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    // Cek status setiap 10 detik
    _checkTimer = Timer.periodic(const Duration(seconds: 10), (_) => _checkStatus());
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _rotateCtrl.dispose();
    _checkTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkStatus() async {
    try {
      final res = await ApiService.get('/api/app-status');
      if (res['success'] == true && res['open'] == true && mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const IntroScreen()));
      }
    } catch (_) {}
  }

  void _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
          context, MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Animated icon
                  AnimatedBuilder(
                    animation: _rotateAnim,
                    builder: (_, __) => Transform.rotate(
                      angle: _rotateAnim.value * 0.3,
                      child: AnimatedBuilder(
                        animation: _pulseAnim,
                        builder: (_, __) => Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.orange.withOpacity(_pulseAnim.value),
                              width: 2,
                            ),
                            gradient: RadialGradient(colors: [
                              Colors.orange.withOpacity(0.2 * _pulseAnim.value),
                              Colors.transparent,
                            ]),
                          ),
                          child: Center(
                            child: Icon(Icons.construction_rounded,
                                size: 56, color: Colors.orange.withOpacity(_pulseAnim.value)),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  // Title
                  const Text(
                    'MAINTENANCE',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                      letterSpacing: 4,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 60,
                    height: 2,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.orange, Colors.transparent]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                      color: Colors.orange.withOpacity(0.05),
                    ),
                    child: Column(
                      children: [
                        const Text(
                          'Sistem Sedang Dalam Perbaikan',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 13,
                            color: Colors.white,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'App sedang ditutup sementara oleh admin.\nSilakan coba beberapa saat lagi.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'ShareTechMono',
                            fontSize: 12,
                            color: AppTheme.textMuted,
                            height: 1.6,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Auto check indicator
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: Colors.orange.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Mengecek status otomatis...',
                        style: TextStyle(
                          fontFamily: 'ShareTechMono',
                          fontSize: 11,
                          color: AppTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Logout button
                  GestureDetector(
                    onTap: _logout,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.4)),
                        color: Colors.red.withOpacity(0.08),
                      ),
                      child: const Text(
                        'KELUAR',
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 11,
                          color: Colors.redAccent,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
