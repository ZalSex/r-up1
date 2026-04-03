import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:ui';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../services/api_service.dart';
import '../services/heartbeat_service.dart';
import 'intro_screen.dart';
import 'maintenance_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with TickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _codeCtrl     = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _shimmerCtrl;
  late Animation<double> _shimmerAnim;

  late VideoPlayerController _bgController;
  bool _bgInitialized = false;

  static const _contacts = [
    {'label': 'WhatsApp', 'url': 'https://wa.me/6289524134626',          'icon': 'whatsapp'},
    {'label': 'Telegram', 'url': 'https://t.me/Zal7Sex',                 'icon': 'telegram'},
    {'label': 'TikTok',   'url': 'https://www.tiktok.com/@zal_infinity', 'icon': 'tiktok'},
  ];

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    _shimmerCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
    _shimmerAnim = Tween<double>(begin: -1.0, end: 2.0).animate(
        CurvedAnimation(parent: _shimmerCtrl, curve: Curves.easeInOut));

    _bgController = VideoPlayerController.asset('assets/video/background.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _bgInitialized = true);
          _bgController.setLooping(true);
          _bgController.setVolume(0);
          _bgController.play();
        }
      });
  }

  @override
  void dispose() {
    _glowCtrl.dispose();
    _rotateCtrl.dispose();
    _shimmerCtrl.dispose();
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _codeCtrl.dispose();
    _bgController.dispose();
    super.dispose();
  }


  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  Future<void> _login() async {
    if (_usernameCtrl.text.isEmpty || _passwordCtrl.text.isEmpty) {
      showWarning(context, 'Username Dan Password Harus Diisi');
      return;
    }
    if (_codeCtrl.text.trim().isEmpty) {
      showWarning(context, 'Kode Akses Harus Diisi');
      return;
    }
    setState(() => _loading = true);
    try {
      String? deviceId;
      try {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        deviceId = androidInfo.id;
      } catch (_) {}

      final res = await ApiService.login(
        _usernameCtrl.text.trim(),
        _passwordCtrl.text,
        deviceId: deviceId,
        code: _codeCtrl.text.trim(),
      );
      if (res['success'] == true) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('auth_token', res['token']);
        await prefs.setString('user_id', res['user']['id'] ?? '');
        await prefs.setString('username', res['user']['username']);
        await prefs.setString('role', res['user']['role']);
        HeartbeatService.instance.start();
        final userRole = res['user']['role'] as String? ?? 'member';
        // Cek app status untuk role member
        if (userRole == 'member') {
          try {
            final statusRes = await ApiService.get('/api/app-status');
            if (statusRes['success'] == true && statusRes['open'] == false) {
              if (mounted) {
                Navigator.pushReplacement(
                    context, MaterialPageRoute(builder: (_) => const MaintenanceScreen()));
              }
              return;
            }
          } catch (_) {}
        }
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const IntroScreen()));
        }
      } else {
        showError(context, res['message'] ?? 'Login Gagal');
      }
    } catch (e) {
      showError(context, 'Koneksi Gagal. Periksa Server.');
    }
    if (mounted) setState(() => _loading = false);
  }

  Color _contactColor(String icon) {
    switch (icon) {
      case 'telegram':  return const Color(0xFF29B6F6);
      case 'whatsapp':  return const Color(0xFF25D366);
      case 'tiktok':    return const Color(0xFFE0E0E0);
      case 'instagram': return const Color(0xFFE1306C);
      case 'youtube':   return const Color(0xFFFF0000);
      case 'github':    return const Color(0xFFE6EDF3);
      case 'website':   return const Color(0xFF8B5CF6);
      default:          return AppTheme.accentBlue;
    }
  }

  String _contactSvgIcon(String icon) {
    switch (icon) {
      case 'telegram':  return AppSvgIcons.telegram;
      case 'whatsapp':  return AppSvgIcons.whatsapp;
      case 'tiktok':    return AppSvgIcons.tiktok;
      case 'instagram': return AppSvgIcons.instagram;
      case 'youtube':   return AppSvgIcons.youtube;
      case 'github':    return AppSvgIcons.githubIcon;
      case 'website':   return AppSvgIcons.globe;
      default:          return AppSvgIcons.globe;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Video background ──
          if (_bgInitialized)
            SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _bgController.value.size.width,
                  height: _bgController.value.size.height,
                  child: VideoPlayer(_bgController),
                ),
              ),
            )
          else
            Container(color: Colors.black),

          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
            child: Container(color: Colors.transparent),
          ),
          Container(color: Colors.black.withOpacity(0.35)),

          SafeArea(
            child: Stack(
              children: [
                // ── Konten scroll utama ──
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    children: [
                      const SizedBox(height: 40),

                      // ── Logo rotating ──
                      AnimatedBuilder(
                        animation: _rotateAnim,
                        builder: (_, __) => Transform.rotate(
                          angle: _rotateAnim.value * 6.2832,
                          child: Container(
                            width: 120, height: 120,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: const SweepGradient(colors: [
                                Color(0xFF00E5FF), Color(0xFF1565C0),
                                Color(0xFF7C4DFF), Color(0xFF00E5FF),
                              ]),
                            ),
                            child: Transform.rotate(
                              angle: -_rotateAnim.value * 6.2832,
                              child: Padding(
                                padding: const EdgeInsets.all(3),
                                child: Container(
                                  decoration: const BoxDecoration(
                                      shape: BoxShape.circle, color: Colors.black),
                                  child: ClipOval(
                                    child: Image.asset('assets/icons/login.jpg',
                                        width: 114, height: 114, fit: BoxFit.cover),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ── PEGASUS-X REVENGE Title ──
                      _buildTitle(),

                      const SizedBox(height: 44),

                      // ── Login Card ──
                      _buildLoginCard(),

                      const SizedBox(height: 36),

                      // ── Contact Us ──
                      _buildContactUs(),

                      const SizedBox(height: 32),
                    ],
                  ),
                ),

              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        Text(
          'PEGASUS-X',
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontFamily: 'Deltha',
            fontSize: 34,
            fontWeight: FontWeight.w900,
            letterSpacing: 5,
            color: Colors.white,
          ),
        ),

        const SizedBox(height: 6),

        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                height: 1, width: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    const Color(0xFF00E5FF).withOpacity(_glowAnim.value),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 5, height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(_glowAnim.value),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF00E5FF).withOpacity(_glowAnim.value * 0.8),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 1, width: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    const Color(0xFF00E5FF).withOpacity(_glowAnim.value),
                    Colors.transparent,
                  ]),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        AnimatedBuilder(
          animation: _glowAnim,
          builder: (_, __) => ShaderMask(
            shaderCallback: (bounds) => LinearGradient(
              colors: [
                Color.lerp(const Color(0xFF7C4DFF), const Color(0xFF00E5FF), _glowAnim.value)!,
                const Color(0xFF00E5FF),
                Color.lerp(const Color(0xFF00E5FF), const Color(0xFF7C4DFF), _glowAnim.value)!,
              ],
            ).createShader(bounds),
            child: const Text(
              'R · E · V · E · N · G · E',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 6,
                color: Colors.white,
              ),
            ),
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildLoginCard() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00E5FF).withOpacity(0.15 + 0.3 * _glowAnim.value),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF).withOpacity(0.06 * _glowAnim.value),
              blurRadius: 24, spreadRadius: 2,
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: child,
      ),
      child: Column(
        children: [
          // Username
          TextFormField(
            controller: _usernameCtrl,
            style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono'),
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.string(AppSvgIcons.user,
                    width: 20, height: 20,
                    colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono'),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.string(AppSvgIcons.lock,
                    width: 20, height: 20,
                    colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: SvgPicture.string(
                  _obscure ? AppSvgIcons.eyeOff : AppSvgIcons.eye,
                  width: 20, height: 20,
                  colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
            onFieldSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 16),

          // CODE field
          TextFormField(
            controller: _codeCtrl,
            keyboardType: TextInputType.number,
            maxLength: 6,
            style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, letterSpacing: 4, fontSize: 18),
            decoration: InputDecoration(
              counterText: '',
              hintText: '_ _ _ _ _ _',
              hintStyle: TextStyle(color: Colors.white24, letterSpacing: 4, fontSize: 16),
              labelText: 'Kode Akses',
              labelStyle: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary, fontSize: 11, letterSpacing: 2),
              prefixIcon: const Icon(Icons.lock_outline_rounded, color: AppTheme.textSecondary, size: 20),
            ),
            onFieldSubmitted: (_) => _login(),
          ),
          const SizedBox(height: 28),

          // MASUK button
          GestureDetector(
            onTap: _loading ? null : _login,
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF1565C0)],
                ),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: _loading
                  ? const Center(
                      child: SizedBox(
                        width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.login_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'MASUK',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            letterSpacing: 4,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),

          GestureDetector(
            onTap: () => _launch('https://wa.me/6289524134626'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 13),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF25D366).withOpacity(0.4)),
                color: const Color(0xFF25D366).withOpacity(0.05),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.chat_rounded, color: Color(0xFF25D366), size: 16),
                  SizedBox(width: 8),
                  Text(
                    'MINTA KODE AKSES',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Color(0xFF25D366),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactUs() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.45),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.35)),
      ),
      child: Column(
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(width: 40, height: 1, color: AppTheme.primaryBlue.withOpacity(0.4)),
            const SizedBox(width: 10),
            const Text('CONTACT US',
                style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 11,
                    color: AppTheme.accentBlue, letterSpacing: 3)),
            const SizedBox(width: 10),
            Container(width: 40, height: 1, color: AppTheme.primaryBlue.withOpacity(0.4)),
          ]),
          const SizedBox(height: 18),
          Wrap(
            spacing: 16,
            runSpacing: 14,
            alignment: WrapAlignment.center,
            children: _contacts.map((c) {
              final color = _contactColor(c['icon']!);
              return GestureDetector(
                onTap: () => _launch(c['url']!),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 46, height: 46,
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.12),
                        shape: BoxShape.circle,
                        border: Border.all(color: color.withOpacity(0.45), width: 1.5),
                        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 8)],
                      ),
                      child: Center(
                        child: SvgPicture.string(
                          _contactSvgIcon(c['icon']!),
                          width: 22, height: 22,
                          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(c['label']!,
                        style: TextStyle(
                          fontFamily: 'ShareTechMono', fontSize: 9,
                          color: color.withOpacity(0.8), letterSpacing: 0.5,
                        )),
                  ],
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
