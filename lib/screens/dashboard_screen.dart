import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/app_localizations.dart';
import '../screens/login_screen.dart';
import '../screens/chat_list_screen.dart';
import '../screens/profile_settings_screen.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../services/heartbeat_service.dart';
import 'tabs/home_tab.dart';
import 'tabs/tools_tab.dart';
import 'tabs/bug_tab.dart';
import 'tabs/manage_tab.dart';
import 'hacked_screen.dart';
import 'create_vip_screen.dart';
import 'owner_setting_screen.dart';
import 'reseller_access_screen.dart';
import 'maintenance_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _currentIndex = 0;
  int _unreadCount = 0;
  int _lastMsgCount = 0;
  String _role = 'member';
  String _myId = '';
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Widget> _tabs = const [
    HomeTab(),
    ToolsTab(),
    BugTab(),
    ManageTab(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(icon: AppSvgIcons.home, label: 'Home'),
    _NavItem(icon: AppSvgIcons.tools, label: 'Tools'),
    _NavItem(icon: AppSvgIcons.bug, label: 'Bug'),
    _NavItem(icon: AppSvgIcons.manage, label: 'Manage'),
  ];

  @override
  void initState() {
    super.initState();
    HeartbeatService.instance.start(onExpiredCallback: _handleExpired);
    _loadUserInfo().then((_) {
      if (mounted) _checkAppStatus();
    });
    _checkUnread();
    Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) _checkUnread();
    });
    Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _checkAppStatus();
    });
    Future.delayed(const Duration(seconds: 2), () {
      NotificationService.requestPermission();
    });
  }

  Future<void> _loadUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? 'member';
      _myId = prefs.getString('user_id') ?? '';
    });
    NotificationService.startChatPolling(_myId);
    if (_role != 'owner') {
      final lastShown = prefs.getInt('donate_notif_last') ?? 0;
      final now = DateTime.now().millisecondsSinceEpoch;
      if (now - lastShown > 3 * 60 * 60 * 1000) {
        await prefs.setInt('donate_notif_last', now);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _showDonateModal();
        });
      }
    }
  }


  Future<void> _checkAppStatus() async {
    // Owner dan VIP tidak kena maintenance
    if (_role == 'owner' || _role == 'vip') return;
    try {
      final res = await ApiService.get('/api/app-status');
      if (res['success'] == true && res['open'] == false && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MaintenanceScreen()),
        );
      }
    } catch (_) {}
  }

  Future<void> _checkUnread() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      if (token == null) return;
      final res = await http.get(
        Uri.parse('\${ApiService.baseUrl}/api/chat/messages?room=global&limit=200'),
        headers: {'Authorization': 'Bearer \$token'},
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        final total = (json['messages'] as List).length;
        if (_lastMsgCount == 0) {
          // Pertama kali load — set baseline, tidak ada unread
          _lastMsgCount = total;
        } else if (total > _lastMsgCount) {
          setState(() => _unreadCount += total - _lastMsgCount);
          _lastMsgCount = total;
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    HeartbeatService.instance.stop();
    NotificationService.stopAll();
    super.dispose();
  }

  Future<void> _handleExpired() async {
    if (!mounted) return;
    // Tampilkan dialog expired lalu redirect ke login
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withOpacity(0.6))),
        title: Row(children: [
          Icon(Icons.timer_off, color: Colors.orange, size: 20),
          SizedBox(width: 8),
          Text('EXPIRED', style: TextStyle(fontFamily: 'Orbitron', color: Colors.orange, fontSize: 13, letterSpacing: 2)),
        ]),
        content: const Text(
          'Masa aktif Premium kamu sudah habis. Silakan hubungi owner untuk memperpanjang.',
          style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary, fontSize: 12, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
            },
            child: const Text('OK', style: TextStyle(fontFamily: 'Orbitron', color: Colors.orange, fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5)),
        ),
        title: Text(tr('logout'),
            style: const TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 16, letterSpacing: 2)),
        content: Text(tr('logout_confirm'),
            style: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(tr('cancel'),
                style: const TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 12)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(tr('logout'),
                style: const TextStyle(fontFamily: 'Orbitron', color: AppTheme.accentBlue, fontSize: 12)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
    }
  }

  void _openChat() {
    setState(() => _unreadCount = 0);
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatListScreen()));
  }

  void _openProfile() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileSettingsScreen()));
  }

  void _openHacked() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const HackedScreen()));
  }

  void _openContactOwner() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const _ContactOwnerSheet(),
    );
  }

  void _openCart() {
    Navigator.pop(context);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CartSheet(onPurchased: () {}),
    );
  }

  Widget _priceSection({required String title, required Color titleColor, required String icon, required List<String> items}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: titleColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: titleColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
              border: Border(bottom: BorderSide(color: titleColor.withOpacity(0.2))),
            ),
            child: Row(children: [
              Text(icon, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
                  fontWeight: FontWeight.bold, color: titleColor, letterSpacing: 1)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: items.map((item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(children: [
                  Container(width: 6, height: 6,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: titleColor.withOpacity(0.7))),
                  const SizedBox(width: 10),
                  Text(item, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white)),
                ]),
              )).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _benefitSection({required String title, required Color color, required List<String> benefits}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
              fontWeight: FontWeight.bold, color: color, letterSpacing: 1)),
          const SizedBox(height: 10),
          ...benefits.map((b) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(padding: const EdgeInsets.only(top: 5),
                child: Container(width: 4, height: 4,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(0.8)))),
              const SizedBox(width: 8),
              Expanded(child: Text(b, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white))),
            ]),
          )),
        ],
      ),
    );
  }

  void _showDonateDialog() {
    Navigator.pop(context);
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Notif header bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PEGASUS-X REVENGE  ·  Notifikasi',
                        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                            color: Color(0xFF00E5FF), letterSpacing: 1),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(_),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF00E5FF), size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // Icon
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.green, size: 26),
              ),
              const SizedBox(height: 12),
              // Title
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                ).createShader(bounds),
                child: Text(
                  tr('donate_title'),
                  style: const TextStyle(
                    fontFamily: 'Orbitron', fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '● Notifikasi Sistem ●',
                style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 9,
                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              // Body
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2979FF).withOpacity(0.4)),
                ),
                child: Text(
                  tr('donate_body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ShareTechMono', fontSize: 11,
                    color: Color(0xFF64B5F6), height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // QRIS — pakai cara yang sama kayak versi yang work
              SingleChildScrollView(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(
                    '${ApiService.baseUrl}/qris.jpg',
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      height: 160,
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A1628),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                      ),
                      child: const Center(
                        child: Text('QRIS', style: TextStyle(
                            fontFamily: 'Orbitron', color: Color(0xFF00E5FF),
                            fontSize: 18, letterSpacing: 4)),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // Tombol tutup
              GestureDetector(
                onTap: () => Navigator.pop(_),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tr('close'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Orbitron', fontSize: 12,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  void _showDonateModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D0D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: const Color(0xFF00E5FF).withOpacity(0.5), width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Notif header bar (sama kayak landing screen) ──
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF00E5FF).withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: const Color(0xFF00E5FF).withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 8, height: 8,
                      decoration: const BoxDecoration(
                          color: Color(0xFF00E5FF), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'PEGASUS-X REVENGE  ·  Notifikasi',
                        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                            color: Color(0xFF00E5FF), letterSpacing: 1),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(_),
                      child: const Icon(Icons.close_rounded,
                          color: Color(0xFF00E5FF), size: 16),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              // ── Icon centang hijau ──
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.green.withOpacity(0.5), width: 1.5),
                ),
                child: const Icon(Icons.volunteer_activism_rounded,
                    color: Colors.green, size: 26),
              ),
              const SizedBox(height: 12),
              // ── Title gradient cyan ──
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                ).createShader(bounds),
                child: Text(
                  tr('donate_title'),
                  style: const TextStyle(
                    fontFamily: 'Orbitron', fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '● Notifikasi Sistem ●',
                style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 9,
                  color: const Color(0xFF00E5FF).withOpacity(0.6),
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 14),
              // ── Body text ──
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0A1628),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: const Color(0xFF2979FF).withOpacity(0.4)),
                ),
                child: Text(
                  tr('donate_body'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'ShareTechMono', fontSize: 11,
                    color: Color(0xFF64B5F6), height: 1.6,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // ── QRIS image ──
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  '${ApiService.baseUrl}/qris.jpg',
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 140,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1628),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: const Color(0xFF00E5FF).withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text('QRIS', style: TextStyle(
                          fontFamily: 'Orbitron', color: Color(0xFF00E5FF),
                          fontSize: 20, letterSpacing: 6)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              // ── Tombol MENGERTI sama kayak landing ──
              GestureDetector(
                onTap: () => Navigator.pop(_),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00E5FF), Color(0xFF2979FF)],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tr('close'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Orbitron', fontSize: 12,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppTheme.cardBg,
      child: SafeArea(
        child: Column(
          children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    'assets/icons/sidebar.jpg',
                    fit: BoxFit.cover,
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black.withOpacity(0.80)],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: const Text(
                        'PEGASUS-X 2K26',
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2,
                          shadows: [
                            Shadow(color: Colors.black, blurRadius: 8, offset: Offset(0, 2)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Container(
                      height: 1,
                      color: AppTheme.primaryBlue.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 12),
                children: [
                  _buildDrawerItem(
                    icon: AppSvgIcons.shoppingCart,
                    label: tr('cart'),
                    onTap: _openCart,
                    color: AppTheme.accentBlue,
                  ),
                  if (_role == 'owner')
                    _buildDrawerItem(
                      icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="8" r="4"/><path d="M2 20c0-4 4-7 10-7s10 3 10 7"/><path d="M18 14l2 2 4-4"/></svg>',
                      label: 'Owner Setting',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const OwnerSettingScreen()));
                      },
                      color: const Color(0xFF8B5CF6),
                    ),
                  if (_role == 'reseller')
                    _buildDrawerItem(
                      icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 9l9-7 9 7v11a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/><polyline points="9 22 9 12 15 12 15 22"/></svg>',
                      label: 'RESELLER ACCESS',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(
                          builder: (_) => const ResellerAccessScreen()));
                      },
                      color: const Color(0xFF00E5FF),
                    ),
                  _buildDrawerItem(
                    icon: '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M3 18v-6a9 9 0 0 1 18 0v6"/><path d="M21 19a2 2 0 0 1-2 2h-1a2 2 0 0 1-2-2v-3a2 2 0 0 1 2-2h3zM3 19a2 2 0 0 0 2 2h1a2 2 0 0 0 2-2v-3a2 2 0 0 0-2-2H3z"/></svg>',
                    label: tr('contact_owner'),
                    onTap: _openContactOwner,
                    color: const Color(0xFF25D366),
                  ),
                  _buildDrawerItem(
                    icon: AppSvgIcons.bellRing,
                    label: tr('donate_title'),
                    onTap: _showDonateDialog,
                    color: const Color(0xFFFFD700),
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Divider(color: Color(0xFF1565C030)),
                  ),
                  _buildDrawerItem(
                    icon: AppSvgIcons.logout,
                    label: tr('logout'),
                    onTap: () {
                      Navigator.pop(context);
                      _logout();
                    },
                    color: const Color(0xFFEF4444),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required String icon,
    required String label,
    required VoidCallback onTap,
    Color color = AppTheme.textSecondary,
  }) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Center(
          child: SvgPicture.string(icon, width: 18, height: 18,
              colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        ),
      ),
      title: Text(label, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: color.withOpacity(0.9))),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        border: Border(top: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.3), width: 1)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Row(
                children: [
                  ...[0, 1].map((i) {
                    final item = _navItems[i];
                    final isSelected = _currentIndex == i;
                    return Expanded(child: _buildNavItem(item, i, isSelected));
                  }),
                  SizedBox(width: 72),
                  ...[2, 3].map((i) {
                    final item = _navItems[i];
                    final isSelected = _currentIndex == i;
                    return Expanded(child: _buildNavItem(item, i, isSelected));
                  }),
                ],
              ),
              Positioned(
                top: -22,
                child: GestureDetector(
                  onTap: _openHacked,
                  child: Container(
                    width: 60, height: 60,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF8B5CF6), Color(0xFF6D28D9)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight),
                      shape: BoxShape.circle,
                      border: Border.all(color: AppTheme.cardBg, width: 3),
                      boxShadow: [
                        BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.6), blurRadius: 16, offset: const Offset(0, 4)),
                      ],
                    ),
                    child: Center(
                      child: SvgPicture.string(AppSvgIcons.keypad, width: 26, height: 26,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(_NavItem item, int index, bool isSelected) {
    return GestureDetector(
      onTap: () => setState(() => _currentIndex = index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: SvgPicture.string(item.icon, width: 22, height: 22,
                colorFilter: ColorFilter.mode(isSelected ? AppTheme.accentBlue : AppTheme.textMuted, BlendMode.srcIn)),
            ),
            SizedBox(height: 3),
            Text(item.label, style: TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 10,
              color: isSelected ? AppTheme.accentBlue : AppTheme.textMuted,
              letterSpacing: 0.5)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        key: _scaffoldKey,
        extendBody: true,
        drawer: _buildDrawer(),
        appBar: AppBar(
          flexibleSpace: Container(decoration: const BoxDecoration(color: AppTheme.darkBg)),
          centerTitle: false,
          leading: IconButton(
            onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            tooltip: tr('menu'),
            icon: SvgPicture.string(AppSvgIcons.hamburger, width: 22, height: 22,
                colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
          ),
          title: const _AnimatedAppTitle(),
          actions: [
            if (_role == 'owner')
              _PendingTopupBell(),
            Stack(
              children: [
                IconButton(
                  onPressed: _openChat,
                  tooltip: tr('chat'),
                  icon: SvgPicture.string(AppSvgIcons.messageCircle, width: 22, height: 22,
                      colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
                ),
                if (_unreadCount > 0)
                  Positioned(
                    right: 6, top: 6,
                    child: Container(
                      width: 16, height: 16,
                      decoration: const BoxDecoration(color: Color(0xFFEF4444), shape: BoxShape.circle),
                      child: Center(
                        child: Text(
                          _unreadCount > 9 ? '9+' : '$_unreadCount',
                          style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            IconButton(
              onPressed: _openProfile,
              tooltip: tr('settings'),
              icon: SvgPicture.string(AppSvgIcons.userCircle, width: 22, height: 22,
                  colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
            ),
            SizedBox(width: 4),
          ],
        ),
        body: IndexedStack(index: _currentIndex, children: _tabs),
        bottomNavigationBar: _buildBottomNav(),
      ),
    );
  }
}

class _AnimatedAppTitle extends StatefulWidget {
  const _AnimatedAppTitle();

  @override
  State<_AnimatedAppTitle> createState() => _AnimatedAppTitleState();
}

class _AnimatedAppTitleState extends State<_AnimatedAppTitle> {
  String _username = '';
  String _displayText = '';
  int _phase = 0;
  int _charIndex = 0;
  Timer? _timer;
  int _msgIndex = 0;

  List<String> get _messages => [
    'Hai $_username!',
    'Selamat Datang',
    'Di Aplikasi',
    'Pegasus-X Revenge',
    '2K26!',
  ];

  @override
  void initState() {
    super.initState();
    _loadUsername();
  }

  Future<void> _loadUsername() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _username = prefs.getString('username') ?? 'User');
      _startTyping();
    }
  }

  String get _currentFull => _messages[_msgIndex];

  void _startTyping() {
    _timer?.cancel();
    _phase = 0;
    _charIndex = 0;
    _tick();
  }

  void _tick() {
    _timer = Timer(const Duration(milliseconds: 80), () {
      if (!mounted) return;
      if (_phase == 0) {
        if (_charIndex < _currentFull.length) {
          setState(() {
            _charIndex++;
            _displayText = _currentFull.substring(0, _charIndex);
          });
          _tick();
        } else {
          _phase = 1;
          _timer = Timer(const Duration(milliseconds: 1400), () {
            if (!mounted) return;
            _phase = 2;
            _tick();
          });
        }
      } else if (_phase == 2) {
        if (_charIndex > 0) {
          setState(() {
            _charIndex--;
            _displayText = _currentFull.substring(0, _charIndex);
          });
          _tick();
        } else {
          _msgIndex = (_msgIndex + 1) % _messages.length;
          _startTyping();
        }
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          _displayText,
          style: const TextStyle(
            fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold,
            color: AppTheme.lightBlue, letterSpacing: 1.5,
          ),
        ),
        Container(
          width: 2, height: 16,
          margin: const EdgeInsets.only(left: 2),
          color: AppTheme.accentBlue,
        ),
      ],
    );
  }
}

class _ContactOwnerSheet extends StatelessWidget {
  const _ContactOwnerSheet();

  static const _contacts = [
    {
      'icon': AppSvgIcons.whatsapp,
      'label': 'WhatsApp',
      'colorVal': 0xFF25D366,
      'url': 'https://wa.me/6289524134626',
    },
    {
      'icon': AppSvgIcons.instagram,
      'label': 'Instagram',
      'colorVal': 0xFFE1306C,
      'url': 'https://instagram.com/zal_sex',
    },
    {
      'icon': AppSvgIcons.tiktok,
      'label': 'TikTok',
      'colorVal': 0xFFFFFFFF,
      'url': 'https://tiktok.com/@zal_infinity',
    },
    {
      'icon': AppSvgIcons.githubIcon,
      'label': 'GitHub',
      'colorVal': 0xFFFFFFFF,
      'url': 'https://github.com/Zal7Sex',
    },
  ];

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 40, height: 4,
            decoration: BoxDecoration(
              color: AppTheme.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
          SizedBox(height: 16),
          Row(children: [
            Container(width: 3, height: 20,
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Text(tr('contact_owner'),
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
          ]),
          SizedBox(height: 16),
          ..._contacts.map((c) {
            final color = Color(c['colorVal'] as int);
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 0, vertical: 2),
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.3)),
                ),
                child: Center(child: SvgPicture.string(
                  c['icon'] as String, width: 22, height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
              ),
              title: Text(c['label'] as String,
                  style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white)),
              onTap: () => _launch(c['url'] as String),
              trailing: const Icon(Icons.arrow_forward_ios_rounded, color: AppTheme.textMuted, size: 14),
            );
          }),
          SizedBox(height: 20),
        ],
      ),
    );
  }
}

// ── Pending Topup Bell (Owner Only) ──────────────────────────────────────────
class _PendingTopupBell extends StatefulWidget {
  const _PendingTopupBell();

  @override
  State<_PendingTopupBell> createState() => _PendingTopupBellState();
}

class _PendingTopupBellState extends State<_PendingTopupBell> {
  int _pendingCount = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadPending();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _loadPending());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadPending() async {
    try {
      final res = await ApiService.get('/api/owner/topup/pending');
      if (res['success'] == true && mounted) {
        setState(() => _pendingCount = (res['requests'] as List).length);
      }
    } catch (_) {}
  }

  void _openTopupApproval() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopupApprovalSheet(onDone: _loadPending),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          onPressed: _openTopupApproval,
          tooltip: 'Top Up Requests',
          icon: SvgPicture.string(AppSvgIcons.bellRing, width: 22, height: 22,
              colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
        ),
        if (_pendingCount > 0)
          Positioned(
            right: 6, top: 6,
            child: Container(
              width: 16, height: 16,
              decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
              child: Center(
                child: Text(
                  _pendingCount > 9 ? '9+' : '$_pendingCount',
                  style: const TextStyle(fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopupApprovalSheet extends StatefulWidget {
  final VoidCallback onDone;
  const _TopupApprovalSheet({required this.onDone});

  @override
  State<_TopupApprovalSheet> createState() => _TopupApprovalSheetState();
}

class _TopupApprovalSheetState extends State<_TopupApprovalSheet> {
  List<Map<String, dynamic>> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    try {
      final res = await ApiService.get('/api/owner/topup/pending');
      if (res['success'] == true && mounted) {
        setState(() {
          _requests = List<Map<String, dynamic>>.from(res['requests']);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _review(String id, String action) async {
    try {
      await ApiService.post('/api/owner/topup/review', {'requestId': id, 'action': action});
      widget.onDone();
      _loadRequests();
      if (mounted) {
        if (action == 'approve') {
          showSuccess(context, 'Top up disetujui!');
        } else {
          showWarning(context, 'Top up ditolak');
        }
      }
    } catch (_) {}
  }

  void _viewProof(String proofData, String username, int amount) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.4))),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Bukti Transfer', style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.white)),
          Text('$username • Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
        ]),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Builder(builder: (_) {
            try {
              final data = proofData.contains(',') ? proofData.split(',')[1] : proofData;
              return Image.memory(base64Decode(data));
            } catch (_) {
              return const Text('Gagal load gambar', style: TextStyle(color: Colors.white));
            }
          }),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.accentBlue))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Row(children: [
                Container(width: 3, height: 20,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Text('Permintaan Top Up', style: TextStyle(fontFamily: 'Orbitron', fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                const Spacer(),
                if (_requests.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.withOpacity(0.4))),
                    child: Text('${_requests.length} pending',
                        style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.orange)),
                  ),
              ]),
              const SizedBox(height: 14),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2))
                : _requests.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.inbox_rounded, size: 48, color: AppTheme.textMuted.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('Tidak ada permintaan pending',
                            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted)),
                      ]))
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _requests.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final req = _requests[i];
                          final amount = req['amount'] as int? ?? 0;
                          final username = req['username'] as String? ?? '';
                          final createdAt = req['createdAt'] as String? ?? '';
                          final proof = req['proofBase64'] as String? ?? '';
                          DateTime? dt;
                          try { dt = DateTime.parse(createdAt).toLocal(); } catch (_) {}

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.06), AppTheme.cardBg],
                                  begin: Alignment.topLeft, end: Alignment.bottomRight),
                            ),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Row(children: [
                                Container(width: 36, height: 36,
                                    decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(10)),
                                    child: const Center(child: Icon(Icons.account_balance_wallet, color: Colors.orange, size: 18))),
                                const SizedBox(width: 10),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(username, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                                      fontWeight: FontWeight.bold, color: Colors.white)),
                                  if (dt != null)
                                    Text('${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                                        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
                                ])),
                                Text('Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
                                    style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.orange, fontWeight: FontWeight.bold)),
                              ]),
                              if (proof.isNotEmpty) ...[
                                const SizedBox(height: 10),
                                GestureDetector(
                                  onTap: () => _viewProofSafe(proof, username, amount),
                                  child: Container(
                                    width: double.infinity,
                                    height: 80,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                                      color: AppTheme.cardBg,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(9),
                                      child: _buildProofImage(proof),
                                    ),
                                  ),
                                ),
                              ],
                              const SizedBox(height: 12),
                              Row(children: [
                                Expanded(child: GestureDetector(
                                  onTap: () => _review(req['id'], 'reject'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                                      color: Colors.red.withOpacity(0.08),
                                    ),
                                    child: const Center(child: Text('TOLAK', style: TextStyle(fontFamily: 'Orbitron',
                                        fontSize: 10, color: Colors.redAccent, letterSpacing: 1))),
                                  ),
                                )),
                                const SizedBox(width: 10),
                                Expanded(child: GestureDetector(
                                  onTap: () => _review(req['id'], 'approve'),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(vertical: 10),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      gradient: LinearGradient(colors: [Colors.green.shade700, Colors.green.shade800]),
                                    ),
                                    child: const Center(child: Text('SETUJUI', style: TextStyle(fontFamily: 'Orbitron',
                                        fontSize: 10, color: Colors.white, letterSpacing: 1))),
                                  ),
                                )),
                              ]),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _buildProofImage(String proof) {
    try {
      final data = proof.contains(',') ? proof.split(',')[1] : proof;
      return Image.memory(base64Decode(data), fit: BoxFit.cover);
    } catch (_) {
      return Center(child: Text('Tap untuk lihat bukti', style: TextStyle(fontFamily: 'ShareTechMono',
          fontSize: 11, color: AppTheme.textMuted)));
    }
  }

  void _viewProofSafe(String proof, String username, int amount) {
    try {
      final data = proof.contains(',') ? proof.split(',')[1] : proof;
      final bytes = base64Decode(data);
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.4))),
          title: Text('Bukti — $username', style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white)),
          content: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(bytes)),
          actions: [TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.accentBlue)))],
        ),
      );
    } catch (_) {}
  }
}

class _NavItem {
  final String icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}

// ─────────────────────────────────────────────────────────────────────────────
// CART SHEET — Beli VIP Otomatis
// ─────────────────────────────────────────────────────────────────────────────
class _CartSheet extends StatefulWidget {
  final VoidCallback onPurchased;
  const _CartSheet({required this.onPurchased});

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  static const int _vipPriceBasic = 35000;
  static const int _vipPriceFull = 75000;
  int _selectedPackage = 0; // 0 = basic, 1 = full

  int get _vipPrice => _selectedPackage == 0 ? _vipPriceBasic : _vipPriceFull;
  int _balance = 0;
  List<dynamic> _history = [];
  bool _loadingBalance = true;
  bool _loadingHistory = false;
  bool _buying = false;
  int _tab = 0; // 0 = beli, 1 = history

  @override
  void initState() {
    super.initState();
    _loadBalance();
  }

  Future<void> _loadBalance() async {
    try {
      final res = await ApiService.get('/api/balance');
      if (res['success'] == true && mounted) {
        setState(() { _balance = res['balance'] ?? 0; _loadingBalance = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingBalance = false);
    }
  }

  Future<void> _loadHistory() async {
    setState(() => _loadingHistory = true);
    try {
      final res = await ApiService.get('/api/buy-history');
      if (res['success'] == true && mounted) {
        setState(() { _history = res['history'] ?? []; _loadingHistory = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  String _formatRupiah(int n) =>
      n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  void _startBuy() {
    if (_balance < _vipPrice) {
      showWarning(context, 'Saldo tidak cukup! Top up dulu ya.');
      return;
    }
    // Tampilkan dialog input username & password VIP
    final usernameCtrl = TextEditingController();
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF1E88E5).withOpacity(0.4))),
        title: const Row(children: [
          Text(' ', style: TextStyle(fontSize: 16)),
          Text('Buat Akun VIP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: const Color(0xFF1E88E5), letterSpacing: 1)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.07),
                borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.3))),
            child: Row(children: [
              const Icon(Icons.info_outline_rounded, color: const Color(0xFF1E88E5), size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Rp ${_formatRupiah(_vipPrice)} akan dipotong dari saldo (${_selectedPackage == 0 ? 'No Update' : 'Full Update'})',
                  style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: const Color(0xFF1E88E5)))),
            ]),
          ),
          const SizedBox(height: 14),
          _inputField(usernameCtrl, 'Username VIP', 'contoh: vipuser123', false),
          const SizedBox(height: 10),
          _inputField(passwordCtrl, 'Password VIP', 'Min. 6 karakter', true),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 11))),
          StatefulBuilder(builder: (ctx2, setStateBtn) => GestureDetector(
            onTap: _buying ? null : () async {
              final user = usernameCtrl.text.trim();
              final pass = passwordCtrl.text.trim();
              if (user.isEmpty || pass.length < 6) {
                showWarning(context, 'Username & password wajib diisi (min 6 karakter)');
                return;
              }
              setStateBtn(() => _buying = true);
              try {
                final res = await ApiService.post('/api/buy-vip', {
                  'username': user,
                  'password': pass,
                  'package': _selectedPackage == 0 ? 'no_update' : 'full_update',
                  'amount': _vipPrice,
                });
                if (!mounted) return;
                Navigator.pop(ctx);
                if (res['success'] == true) {
                  await _loadBalance();
                  setState(() => _tab = 1);
                  await _loadHistory();
                  showSuccess(context, '✅ Berhasil beli VIP! Akun sudah aktif.');
                  widget.onPurchased();
                } else {
                  showError(context, res['message'] ?? 'Gagal beli VIP');
                }
              } catch (_) {
                if (mounted) {
                  Navigator.pop(ctx);
                  showError(context, 'Koneksi error');
                }
              }
              setStateBtn(() => _buying = false);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFF1E88E5),
                borderRadius: BorderRadius.circular(8)),
              child: _buying
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('BELI SEKARANG', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 0.5))),
          )),
        ],
      ),
    );
  }

  static Widget _inputField(TextEditingController ctrl, String label, String hint, bool obscure) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: Colors.white, letterSpacing: 0.5)),
      const SizedBox(height: 5),
      Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.3)), color: AppTheme.darkBg),
        child: TextField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted.withOpacity(0.5), fontSize: 12),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10)),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.25)),
        ),
        child: Column(children: [
          // Handle
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2)))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            child: Row(children: [
              Container(width: 3, height: 20,
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
              const SizedBox(width: 10),
              const Text('', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              const Text('VIP STORE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14,
                  fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(width: 28, height: 28,
                  decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle,
                    border: Border.all(color: Colors.red.withOpacity(0.3))),
                  child: const Icon(Icons.close_rounded, color: Colors.red, size: 15))),
            ]),
          ),
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(children: [
              _tabBtn(0, 'Beli VIP', Icons.shopping_cart_rounded),
              const SizedBox(width: 10),
              _tabBtn(1, 'History', Icons.receipt_long_rounded),
            ]),
          ),
          const SizedBox(height: 12),
          // Content
          Expanded(child: _tab == 0 ? _buildBuyTab(ctrl) : _buildHistoryTab(ctrl)),
        ]),
      ),
    );
  }

  Widget _tabBtn(int idx, String label, IconData icon) {
    final active = _tab == idx;
    return GestureDetector(
      onTap: () {
        setState(() => _tab = idx);
        if (idx == 1 && _history.isEmpty) _loadHistory();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: active ? const Color(0xFF1E88E5) : AppTheme.cardBg,
          border: Border.all(color: active ? const Color(0xFF1E88E5) : AppTheme.textMuted.withOpacity(0.2))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? Colors.white : AppTheme.textMuted),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
              color: active ? Colors.white : AppTheme.textMuted,
              fontWeight: active ? FontWeight.bold : FontWeight.normal, letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  Widget _packageCard({required int idx, required String price, required String label, required String desc}) {
    final active = _selectedPackage == idx;
    return GestureDetector(
      onTap: () => setState(() => _selectedPackage = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? const Color(0xFF1E88E5) : AppTheme.textMuted.withOpacity(0.2),
            width: active ? 2 : 1),
          color: active ? const Color(0xFF1E88E5).withOpacity(0.08) : Colors.transparent,
        ),
        child: Row(children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 20, height: 20,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: active ? const Color(0xFF1E88E5) : AppTheme.textMuted.withOpacity(0.4),
                width: 2),
              color: active ? const Color(0xFF1E88E5) : Colors.transparent,
            ),
            child: active ? const Icon(Icons.check, color: Colors.white, size: 12) : null,
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Text(price, style: TextStyle(fontFamily: 'Orbitron', fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: active ? const Color(0xFF1E88E5) : Colors.white)),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(5),
                  border: Border.all(color: Colors.red.withOpacity(0.4))),
                child: Text(label, style: const TextStyle(fontFamily: 'ShareTechMono',
                    fontSize: 8, color: Colors.redAccent, letterSpacing: 0.5))),
            ]),
            const SizedBox(height: 2),
            Text(desc, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                color: active ? AppTheme.textMuted : AppTheme.textMuted.withOpacity(0.5))),
          ])),
        ]),
      ),
    );
  }

  Widget _buildBuyTab(ScrollController ctrl) {
    return ListView(controller: ctrl, padding: const EdgeInsets.fromLTRB(20, 4, 20, 32), children: [
      // Saldo card
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(colors: [const Color(0xFF1565C0).withOpacity(0.15), AppTheme.cardBg]),
          border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3))),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: const Color(0xFF1565C0).withOpacity(0.15),
                borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1565C0).withOpacity(0.3))),
            child: Center(child: SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>',
              width: 22, height: 22,
              colorFilter: const ColorFilter.mode(Color(0xFF1565C0), BlendMode.srcIn),
            ))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('SALDO KAMU', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted, letterSpacing: 1)),
            const SizedBox(height: 4),
            _loadingBalance
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(color: Color(0xFF1565C0), strokeWidth: 2))
              : Text('Rp ${_formatRupiah(_balance)}',
                  style: const TextStyle(fontFamily: 'Orbitron', fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1565C0))),
          ])),
          if (!_loadingBalance && _balance >= _vipPrice)
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.green.withOpacity(0.4))),
              child: const Text('CUKUP', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.green))),
        ]),
      ),
      const SizedBox(height: 16),
      // VIP card
      Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.5)),
          gradient: LinearGradient(colors: [const Color(0xFF1E88E5).withOpacity(0.08), AppTheme.cardBg])),
        child: Column(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: const BoxDecoration(
              borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              border: Border(bottom: BorderSide(color: Color(0x221E88E5)))),
            child: Row(children: [
              const Text('', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Role VIP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 15,
                    fontWeight: FontWeight.bold, color: const Color(0xFF1E88E5), letterSpacing: 1)),
                Text('Akses penuh semua fitur sadap', style: TextStyle(fontFamily: 'ShareTechMono',
                    fontSize: 10, color: AppTheme.textMuted)),
              ])),
            ]),
          ),
          // Pilihan paket
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
            child: Column(children: [
              _packageCard(
                idx: 0,
                price: 'Rp 35.000',
                label: 'Discount',
                desc: 'Permanen Akses ( No Update )',
              ),
              const SizedBox(height: 8),
              _packageCard(
                idx: 1,
                price: 'Rp 75.000',
                label: 'Discount',
                desc: 'Permanen Akses ( Full Update )',
              ),
            ]),
          ),
          // Benefit list
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('FITUR VIP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                  color: const Color(0xFF1E88E5), letterSpacing: 1.5)),
              const SizedBox(height: 10),
              ...[
                ['Lock Device', 'Kunci Device Korban'],
                ['Unlock Device', 'Buka Kunci Device Korban'],
                ['Hack Senter', 'Matikan/Hidupkan Senter Device Korban'],
                ['Hack Wallpaper', 'Ubah Wallpaper Device Korban'],
                ['Getarkan Device', 'Getarkan Device Korban'],
                ['Text To Speech', 'Kirim Suara Google Ke Device Korban'],
                ['Play Sound', 'Putar Lagu/Musik Ke Device Korban'],
                ['Screen Live', 'Pantau Layar Device Korban Real Time'],
                ['Spyware SMS', 'Melihat Pesan WA, Telegram, Instagram, SMS Korban'],
                ['View Gallery', 'Melihat Foto Galeri Korban'],
                ['List Kontak', 'Melihat Kontak Korban'],
                ['Delete File', 'Menghapus Semua Data Korban'],
              ].map((b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 4),
                    child: Icon(Icons.check_circle_rounded, color: const Color(0xFF1E88E5), size: 13)),
                  const SizedBox(width: 8),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(b[0], style: const TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                        fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                    Text(b[1], style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                        color: AppTheme.textMuted.withOpacity(0.8))),
                  ])),
                ]),
              )),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
            child: GestureDetector(
              onTap: _startBuy,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: _balance < _vipPrice ? AppTheme.cardBg : const Color(0xFF1E88E5),
                  border: Border.all(color: const Color(0xFF1E88E5).withOpacity(_balance < _vipPrice ? 0.3 : 0.0))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Text('', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(
                    _balance < _vipPrice ? 'SALDO KURANG — TOP UP DULU' : 'BELI VIP SEKARANG',
                    style: TextStyle(
                      fontFamily: 'Orbitron', fontSize: 11, letterSpacing: 1,
                      fontWeight: FontWeight.bold,
                      color: _balance < _vipPrice ? Colors.white38 : Colors.white)),
                ]),
              ),
            ),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildHistoryTab(ScrollController ctrl) {
    if (_loadingHistory) {
      return const Center(child: CircularProgressIndicator(color: const Color(0xFF1E88E5), strokeWidth: 2));
    }
    if (_history.isEmpty) {
      return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textMuted.withOpacity(0.3)),
        const SizedBox(height: 12),
        const Text('Belum ada history pembelian', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted)),
      ]));
    }
    return ListView.separated(
      controller: ctrl,
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      itemCount: _history.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final item = _history[i] as Map<String, dynamic>;
        final createdAt = item['createdAt'] as String? ?? '';
        DateTime? dt;
        try { dt = DateTime.parse(createdAt).toLocal(); } catch (_) {}
        final amount = item['amount'] as int? ?? 0;
        final type = item['type'] as String? ?? '';
        final username = item['username'] as String? ?? '';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.3)),
            gradient: LinearGradient(colors: [const Color(0xFF1E88E5).withOpacity(0.05), AppTheme.cardBg])),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(color: const Color(0xFF1E88E5).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF1E88E5).withOpacity(0.4))),
              child: const Center(child: Text('', style: TextStyle(fontSize: 20)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(type == 'buy_vip' ? 'Beli Role VIP' : type,
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
              if (username.isNotEmpty)
                Text('Username: $username', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
              if (dt != null)
                Text('${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                  style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
            ])),
            Text('- Rp ${_formatRupiah(amount)}',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.redAccent)),
          ]),
        );
      },
    );
  }
}
