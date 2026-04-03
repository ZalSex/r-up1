import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import 'dart:ui';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with TickerProviderStateMixin {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;
  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;

  late VideoPlayerController _bgController;
  bool _bgInitialized = false;

  @override
  void initState() {
    super.initState();

    _glowCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
        CurvedAnimation(parent: _glowCtrl, curve: Curves.easeInOut));

    _rotateCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat();
    _rotateAnim =
        Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    _bgController =
        VideoPlayerController.asset('assets/video/background.mp4')
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
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    _bgController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (username.isEmpty || password.isEmpty) {
      _showSnack('Username Dan Password Harus Diisi');
      return;
    }
    if (password.length < 3) {
      _showSnack('Password Minimal 3 Karakter');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.register(username, password);
      if (res['success'] == true) {
        _showSnack('Akun Berhasil Dibuat! Hubungi Admin Di WhatsApp Untuk Mendapatkan Kode Akses.', isSuccess: true);
        try {
          final uri = Uri.parse('https://wa.me/6289524134626');
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          }
        } catch (_) {}
        await Future.delayed(const Duration(milliseconds: 800));
        if (mounted) {
          Navigator.pushReplacement(
              context, MaterialPageRoute(builder: (_) => const LoginScreen()));
        }
      } else {
        _showSnack(res['message'] ?? 'Registrasi Gagal', isError: true);
      }
    } catch (e) {
      _showSnack('Koneksi Gagal. Periksa Server.', isError: true);
    }
    if (mounted) setState(() => _loading = false);
  }

  void _showSnack(String msg, {bool isError = false, bool isSuccess = false}) {
    if (!mounted) return;
    if (isError) {
      showError(context, msg);
    } else if (isSuccess) {
      showSuccess(context, msg);
    } else {
      showWarning(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Video background
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                children: [
                  const SizedBox(height: 40),

                  // Logo rotating
                  AnimatedBuilder(
                    animation: _rotateAnim,
                    builder: (_, __) => Transform.rotate(
                      angle: _rotateAnim.value * 6.2832,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: SweepGradient(colors: [
                            Color(0xFF00E5FF),
                            Color(0xFF1565C0),
                            Color(0xFF7C4DFF),
                            Color(0xFF00E5FF),
                          ]),
                        ),
                        child: Transform.rotate(
                          angle: -_rotateAnim.value * 6.2832,
                          child: Padding(
                            padding: const EdgeInsets.all(3),
                            child: Container(
                              decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black),
                              child: ClipOval(
                                child: Image.asset(
                                    'assets/icons/login.jpg',
                                    width: 114,
                                    height: 114,
                                    fit: BoxFit.cover),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Title
                  _buildTitle(),

                  const SizedBox(height: 44),

                  // Register Card
                  _buildRegisterCard(),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitle() {
    return Column(
      children: [
        const Text(
          'PEGASUS-X',
          textAlign: TextAlign.center,
          style: TextStyle(
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
                height: 1,
                width: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    Colors.transparent,
                    const Color(0xFF00E5FF).withOpacity(_glowAnim.value),
                  ]),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(_glowAnim.value),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 1,
                width: 70,
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
                Color.lerp(const Color(0xFF7C4DFF), const Color(0xFF00E5FF),
                    _glowAnim.value)!,
                const Color(0xFF00E5FF),
                Color.lerp(const Color(0xFF00E5FF), const Color(0xFF7C4DFF),
                    _glowAnim.value)!,
              ],
            ).createShader(bounds),
            child: const Text(
              'R · E · V · E · N · G · E',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Orbitron',
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 4,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildRegisterCard() {
    return AnimatedBuilder(
      animation: _glowAnim,
      builder: (_, child) => Container(
        decoration: BoxDecoration(
          color: AppTheme.cardBg.withOpacity(0.75),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: const Color(0xFF00E5FF)
                .withOpacity(0.15 + 0.3 * _glowAnim.value),
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00E5FF)
                  .withOpacity(0.06 * _glowAnim.value),
              blurRadius: 24,
              spreadRadius: 2,
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
            style: const TextStyle(
                color: Colors.white, fontFamily: 'ShareTechMono'),
            decoration: InputDecoration(
              labelText: 'Username',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.string(AppSvgIcons.user,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                        AppTheme.textSecondary, BlendMode.srcIn)),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Password
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            style: const TextStyle(
                color: Colors.white, fontFamily: 'ShareTechMono'),
            decoration: InputDecoration(
              labelText: 'Password (Min. 3 Karakter)',
              prefixIcon: Padding(
                padding: const EdgeInsets.all(12),
                child: SvgPicture.string(AppSvgIcons.lock,
                    width: 20,
                    height: 20,
                    colorFilter: const ColorFilter.mode(
                        AppTheme.textSecondary, BlendMode.srcIn)),
              ),
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscure = !_obscure),
                icon: SvgPicture.string(
                  _obscure ? AppSvgIcons.eyeOff : AppSvgIcons.eye,
                  width: 20,
                  height: 20,
                  colorFilter: const ColorFilter.mode(
                      AppTheme.textSecondary, BlendMode.srcIn),
                ),
              ),
            ),
            onFieldSubmitted: (_) => _register(),
          ),
          const SizedBox(height: 28),

          // BUAT AKUN button
          GestureDetector(
            onTap: _loading ? null : _register,
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
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_add_rounded,
                            color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'BUAT AKUN',
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

          const SizedBox(height: 16),

          // Tombol LOGIN di bawah BUAT AKUN
          GestureDetector(
            onTap: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: const Color(0xFF00E5FF).withOpacity(0.5),
                  width: 1.5,
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.login_rounded,
                      color: Color(0xFF00E5FF), size: 18),
                  SizedBox(width: 10),
                  Text(
                    'LOGIN',
                    style: TextStyle(
                      fontFamily: 'Orbitron',
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 4,
                      color: Color(0xFF00E5FF),
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
}
