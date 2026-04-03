import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../utils/theme.dart';
import '../../utils/notif_helper.dart';
import '../../utils/role_style.dart';
import '../../utils/app_localizations.dart';
import '../../services/api_service.dart';
import '../management_app_screen.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({super.key});

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> with TickerProviderStateMixin {
  String _username = '';
  String _role = 'member';
  String? _avatarBase64;
  bool _loading = true;
  late VideoPlayerController _bannerController;
  bool _bannerInitialized = false;

  int _onlineUsers = 0;
  int _onlineSenders = 0;
  int _balance = 0;
  Timer? _statsTimer;

  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  static const _overlayChannel = MethodChannel('com.pegasusx.revenge/overlay');
  bool _overlayEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _initBanner();
    _loadStats();
    _loadOverlayState();
    _statsTimer = Timer.periodic(const Duration(seconds: 30), (_) => _loadStats());

    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowCtrl);
  }

  Future<void> _loadOverlayState() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool('overlay_enabled') ?? false;
    final hasPermission = await _checkOverlayPermission();
    setState(() => _overlayEnabled = saved && hasPermission);
  }

  Future<bool> _checkOverlayPermission() async {
    try {
      final result = await _overlayChannel.invokeMethod<bool>('checkPermission');
      return result ?? false;
    } catch (_) { return false; }
  }

  Future<void> _toggleOverlay(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value) {
      final hasPermission = await _checkOverlayPermission();
      if (!hasPermission) {
        await _overlayChannel.invokeMethod('requestPermission');
        await Future.delayed(const Duration(seconds: 1));
        final granted = await _checkOverlayPermission();
        if (!granted) {
          _showSnack(tr('overlay_permission'));
          return;
        }
      }
      final ok = await _overlayChannel.invokeMethod<bool>('startOverlay') ?? false;
      if (ok) {
        setState(() => _overlayEnabled = true);
        await prefs.setBool('overlay_enabled', true);
        _showSnack(tr('overlay_active'), isSuccess: true);
      }
    } else {
      await _overlayChannel.invokeMethod('stopOverlay');
      setState(() => _overlayEnabled = false);
      await prefs.setBool('overlay_enabled', false);
      _showSnack(tr('overlay_disabled'), isSuccess: true);
    }
  }

  void _showSnack(String msg, {bool isSuccess = false}) {
    if (!mounted) return;
    if (isSuccess) {
      showSuccess(context, msg);
    } else {
      showWarning(context, msg);
    }
  }

  Future<void> _initBanner() async {
    try {
      _bannerController = VideoPlayerController.asset('assets/video/banner.mp4')
        ..initialize().then((_) {
          if (mounted) {
            setState(() => _bannerInitialized = true);
            _bannerController.setLooping(true);
            _bannerController.setVolume(0.0);
            _bannerController.play();
          }
        });
    } catch (_) {}
  }

  Future<void> _loadStats() async {
    try {
      final res = await ApiService.getStats();
      if (res['success'] == true && mounted) {
        setState(() {
          _onlineUsers = res['onlineUsers'] ?? 0;
          _onlineSenders = res['onlineSenders'] ?? 0;
        });
      }
    } catch (_) {}
    try {
      final res = await ApiService.get('/api/balance');
      if (res['success'] == true && mounted) {
        setState(() => _balance = res['balance'] ?? 0);
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    if (_bannerInitialized) _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? '';
        _role = prefs.getString('role') ?? 'member';
        _avatarBase64 = prefs.getString('avatar');
      });
      final res = await ApiService.getProfile();
      if (res['success'] == true) {
        final user = res['user'];
        setState(() {
          _username = user['username'] ?? _username;
          _role = user['role'] ?? _role;
          _avatarBase64 = user['avatar'];
        });
        await prefs.setString('username', _username);
        await prefs.setString('role', _role);
        await prefs.setString('user_id', user['id'] ?? '');
        if (_avatarBase64 != null) await prefs.setString('avatar', _avatarBase64!);
      }
    } catch (_) {}
    setState(() => _loading = false);
  }

  void _openTopUp() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _TopUpSheet(onSuccess: _loadStats),
    );
  }

  void _openHistory() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _TopUpHistorySheet(),
    );
  }

  String _formatRupiah(int amount) {
    return amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom + 80),
          child: Column(
            children: [
              _buildBanner(),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionTitle(tr('information_account')),
                    const SizedBox(height: 12),
                    _buildAccountCard(),
                    const SizedBox(height: 16),
                    _buildStatsRow(),
                    const SizedBox(height: 16),
                    _buildCryptoSection(),
                    if (_role == 'owner') ...[
                      const SizedBox(height: 16),
                      _buildManagementAppCard(),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF29B6F6), width: 2.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: AspectRatio(
            aspectRatio: 16 / 9,
            child: _bannerInitialized
                ? VideoPlayer(_bannerController)
                : Container(
                    color: AppTheme.cardBg,
                    child: Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2))),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Row(children: [
      Container(width: 3, height: 22,
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Text(title, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16,
          fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
    ]);
  }

  Widget _buildAccountCard() {
    final avatarWidget = _avatarBase64 != null
        ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover)
        : null;

    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.1), blurRadius: 15)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [AppTheme.primaryBlue.withOpacity(0.3), Colors.transparent]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Row(
              children: [
                RoleStyle.instagramPhoto(
                  assetPath: avatarWidget == null ? 'assets/icons/revenge.jpg' : null,
                  customImage: avatarWidget,
                  colors: RoleStyle.loginBorderColors,
                  rotateAnim: _rotateAnim,
                  glowAnim: _glowAnim,
                  size: 54, borderWidth: 3, innerPad: 2,
                  fallback: Container(
                    color: AppTheme.primaryBlue.withOpacity(0.3),
                    child: Center(child: SvgPicture.string(AppSvgIcons.user, width: 20, height: 20,
                        colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_loading ? '...' : _username,
                        style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16,
                            fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 5),
                      RoleStyle.roleBadge(_role),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(tr('overlay'), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, letterSpacing: 1,
                        color: _overlayEnabled ? Colors.greenAccent : AppTheme.textMuted)),
                    const SizedBox(height: 4),
                    GestureDetector(
                      onTap: () => _toggleOverlay(!_overlayEnabled),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 46, height: 26,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          color: _overlayEnabled ? Colors.greenAccent.withOpacity(0.85) : Colors.white.withOpacity(0.12),
                          border: Border.all(color: _overlayEnabled ? Colors.greenAccent : Colors.white24, width: 1.5),
                          boxShadow: _overlayEnabled ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.4), blurRadius: 8)] : [],
                        ),
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 250),
                          alignment: _overlayEnabled ? Alignment.centerRight : Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _overlayEnabled ? Colors.white : Colors.white38,
                                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 1))],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _buildInfoRow(tr('username'), _username, AppSvgIcons.user),
          _buildInfoRow(tr('password'), '••••••••', AppSvgIcons.lock),
          _buildInfoRow(tr('role'), _role.toUpperCase(), AppSvgIcons.shield),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, String iconSvg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.15)))),
      child: Row(
        children: [
          SvgPicture.string(iconSvg, width: 16, height: 16,
              colorFilter: const ColorFilter.mode(AppTheme.textMuted, BlendMode.srcIn)),
          const SizedBox(width: 12),
          Text('$label:', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(width: 8),
          Expanded(child: Text(_loading ? '...' : value,
              style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white),
              textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Row(children: [
      Expanded(child: _buildStatCard(
        label: tr('online_users'), value: _onlineUsers.toString(),
        color: Colors.green, icon: AppSvgIcons.user)),
      const SizedBox(width: 12),
      Expanded(child: _buildStatCard(
        label: tr('connections'), value: _onlineSenders.toString(),
        color: AppTheme.accentBlue, icon: AppSvgIcons.mobile)),
    ]);
  }

  Widget _buildStatCard({required String label, required String value, required Color color, required String icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.4), width: 1.5),
        gradient: LinearGradient(colors: [color.withOpacity(0.12), AppTheme.cardBg], begin: Alignment.topLeft, end: Alignment.bottomRight),
        boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SvgPicture.string(icon, width: 18, height: 18, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(fontFamily: 'Orbitron', fontSize: 26, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted, letterSpacing: 1)),
      ]),
    );
  }

  Widget _buildCryptoSection() {
    const Color saldoColor = Color(0xFF1E88E5);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 3, height: 22,
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        const Text('SALDO & TOPUP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 16,
            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
      ]),
      const SizedBox(height: 12),
      // ── SALDO CARD (full width, biru) ──
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: saldoColor.withOpacity(0.55), width: 1.5),
          gradient: LinearGradient(
            colors: [saldoColor.withOpacity(0.18), AppTheme.cardBg],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: saldoColor.withOpacity(0.2), blurRadius: 14)],
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: saldoColor.withOpacity(0.22),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: saldoColor.withOpacity(0.5)),
            ),
            child: Center(child: SvgPicture.string(
              '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><line x1="12" y1="1" x2="12" y2="23"/><path d="M17 5H9.5a3.5 3.5 0 0 0 0 7h5a3.5 3.5 0 0 1 0 7H6"/></svg>',
              width: 22, height: 22,
              colorFilter: const ColorFilter.mode(Color(0xFF1E88E5), BlendMode.srcIn),
            )),
          ),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Rp ${_formatRupiah(_balance)}',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 20,
                  fontWeight: FontWeight.bold, color: Color(0xFF1E88E5), letterSpacing: 1)),
            const SizedBox(height: 3),
            const Text('SALDO KAMU', style: TextStyle(fontFamily: 'ShareTechMono',
                fontSize: 10, color: AppTheme.textMuted, letterSpacing: 2)),
          ]),
        ]),
      ),
      const SizedBox(height: 12),
      // ── TOP UP & HISTORY (sejajar, di bawah saldo) ──
      Row(children: [
        Expanded(child: _buildCryptoCard(
          icon: const Icon(Icons.add_card_rounded, color: Color(0xFF10B981), size: 20),
          title: 'TOP UP',
          label: 'DEPOSIT',
          color: const Color(0xFF10B981),
          onTap: _openTopUp,
        )),
        const SizedBox(width: 12),
        Expanded(child: _buildCryptoCard(
          icon: const Icon(Icons.history_rounded, color: Color(0xFF8B5CF6), size: 20),
          title: 'HISTORY',
          label: 'TRANSAKSI',
          color: const Color(0xFF8B5CF6),
          onTap: _openHistory,
        )),
      ]),
    ]);
  }

  Widget _buildCryptoCard({
    required Widget icon,
    required String title,
    required String label,
    required Color color,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          gradient: LinearGradient(
            colors: [color.withOpacity(0.12), AppTheme.cardBg],
            begin: Alignment.topLeft, end: Alignment.bottomRight,
          ),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10)],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: color.withOpacity(0.4)),
            ),
            child: Center(child: icon),
          ),
          const SizedBox(height: 10),
          Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
              fontWeight: FontWeight.bold, color: color), maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
              color: AppTheme.textMuted, letterSpacing: 1)),
        ]),
      ),
    );
  }

  Widget _buildManagementAppCard() {
    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ManagementAppScreen())),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
          gradient: LinearGradient(colors: [Colors.orange.withOpacity(0.12), AppTheme.cardBg], begin: Alignment.centerLeft, end: Alignment.centerRight),
          boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.12), blurRadius: 12)],
        ),
        child: Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: Colors.orange.withOpacity(0.2), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange.withOpacity(0.4))),
            child: Center(child: SvgPicture.string(AppSvgIcons.keypad, width: 22, height: 22,
                colorFilter: const ColorFilter.mode(Colors.orange, BlendMode.srcIn)))),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(tr('management_app'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                fontWeight: FontWeight.bold, color: Colors.orange, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text('${tr("manage_sender")} & ${tr("manage_users")}',
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
          ])),
          const Icon(Icons.chevron_right, color: Colors.orange, size: 22),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TOP UP SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _TopUpSheet extends StatefulWidget {
  final VoidCallback onSuccess;
  const _TopUpSheet({required this.onSuccess});

  @override
  State<_TopUpSheet> createState() => _TopUpSheetState();
}

class _TopUpSheetState extends State<_TopUpSheet> {
  int _step = 0;
  String? _selectedMethod;
  final _nominalCtrl = TextEditingController();
  String? _proofBase64;
  XFile? _proofFile;
  bool _uploadingProof = false;
  bool _loading = false;

  static const _danaNumber = '+62 895-2413-4626';
  static const _gopayNumber = '+62 895-2413-4626';
  static const _ownerName = 'Pr* Har*****';

  @override
  void dispose() {
    _nominalCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickProof() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 80);
    if (file == null) return;
    setState(() { _uploadingProof = true; _proofFile = file; });
    try {
      final bytes = await file.readAsBytes();
      final ext = file.name.split('.').last.toLowerCase();
      final mime = ext == 'png' ? 'image/png' : 'image/jpeg';
      setState(() => _proofBase64 = 'data:$mime;base64,${base64Encode(bytes)}');
    } catch (_) {
      setState(() { _proofFile = null; _proofBase64 = null; });
    }
    if (mounted) setState(() => _uploadingProof = false);
  }

  void _copyNumber(String number) {
    Clipboard.setData(ClipboardData(text: number.replaceAll(RegExp(r'[\s\-]'), '')));
    showSuccess(context, 'Nomor disalin!');
  }

  Future<void> _submitTopup() async {
    final nominalStr = _nominalCtrl.text.replaceAll(RegExp(r'[^0-9]'), '');
    final nominal = int.tryParse(nominalStr) ?? 0;
    if (nominal < 10000) {
      showWarning(context, 'Minimal top up Rp 10.000');
      return;
    }
    // Jika tidak ada bukti, kirim dengan placeholder
    final proof = _proofBase64 ?? 'no_proof';
    setState(() => _loading = true);
    try {
      final res = await ApiService.post('/api/topup/request', {
        'amount': nominal,
        'proofBase64': proof,
      });
      if (res['success'] == true && mounted) {
        Navigator.pop(context);
        widget.onSuccess();
        showSuccess(context, 'Top up dikirim! Menunggu konfirmasi owner.');
      } else {
        showError(context, res['message'] ?? 'Gagal kirim');
      }
    } catch (_) {
      showError(context, 'Koneksi error');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
        ),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(children: [
              Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 14),
              Row(children: [
                if (_step > 0) ...[
                  GestureDetector(
                    onTap: () => setState(() => _step = 0),
                    child: const Icon(Icons.arrow_back_ios_new_rounded, color: AppTheme.accentBlue, size: 18),
                  ),
                  const SizedBox(width: 8),
                ],
                Container(width: 3, height: 20,
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text(_step == 0 ? 'Metode Pembayaran' : 'Detail Top Up',
                    style: const TextStyle(fontFamily: 'Orbitron', fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              ]),
              const SizedBox(height: 14),
            ]),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: ctrl,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
              child: _step == 0 ? _buildMethodStep() : _buildFormStep(),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildMethodStep() {
    return Column(children: [
      _buildQrisCard(),
      const SizedBox(height: 12),
      _buildEwalletCard('Dana', Icons.account_balance_wallet_rounded, const Color(0xFF3B82F6), _danaNumber),
      const SizedBox(height: 12),
      _buildEwalletCard('GoPay', Icons.payment_rounded, const Color(0xFF10B981), _gopayNumber),
    ]);
  }

  Widget _buildQrisCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4)),
        color: const Color(0xFF06B6D4).withOpacity(0.05),
      ),
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
              child: const Center(child: Icon(Icons.qr_code_rounded, color: Color(0xFF06B6D4), size: 22))),
            const SizedBox(width: 12),
            const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('QRIS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF06B6D4))),
              Text('Scan QR untuk transfer', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
            ])),
            GestureDetector(
              onTap: _showQrisDialog,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.download_rounded, color: Color(0xFF06B6D4), size: 18))),
          ]),
        ),
        GestureDetector(
          onTap: _showQrisDialog,
          child: Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            height: 160,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3)),
              color: AppTheme.cardBg,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: Image.network(
                '${ApiService.baseUrl}/qris.jpg',
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.qr_code_2_rounded, size: 56, color: Color(0xFF06B6D4)),
                  const SizedBox(height: 8),
                  const Text('QRIS Payment', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
                ])),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: GestureDetector(
            onTap: () { _selectedMethod = 'QRIS'; setState(() => _step = 1); },
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0891B2)]),
              ),
              child: const Center(child: Text('SUDAH TRANSFER', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1))),
            ),
          ),
        ),
      ]),
    );
  }

  void _showQrisDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: const Color(0xFF06B6D4).withOpacity(0.4))),
        title: const Text('QRIS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Color(0xFF06B6D4))),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            '${ApiService.baseUrl}/qris.jpg',
              errorBuilder: (_, __, ___) => const SizedBox(height: 200,
                  child: Center(child: Icon(Icons.qr_code_2_rounded, size: 80, color: Color(0xFF06B6D4))))),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Tutup', style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.accentBlue))),
        ],
      ),
    );
  }

  Widget _buildEwalletCard(String name, IconData icon, Color color, String number) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.4)),
        color: color.withOpacity(0.05),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42,
            decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
            child: Center(child: Icon(icon, color: color, size: 22))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: color)),
            Text('a/n $_ownerName', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
          ])),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: AppTheme.cardBg,
              border: Border.all(color: color.withOpacity(0.3))),
          child: Row(children: [
            Expanded(child: Text(number, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 14, color: color, fontWeight: FontWeight.bold))),
            GestureDetector(
              onTap: () => _copyNumber(number),
              child: Icon(Icons.copy_rounded, color: color.withOpacity(0.7), size: 18)),
          ]),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () { _selectedMethod = name; setState(() => _step = 1); },
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
            ),
            child: const Center(child: Text('SUDAH TRANSFER', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1))),
          ),
        ),
      ]),
    );
  }

  Widget _buildFormStep() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_selectedMethod != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              color: const Color(0xFF10B981).withOpacity(0.1), border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3))),
          child: Text('Metode: $_selectedMethod', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Color(0xFF10B981))),
        ),
      const SizedBox(height: 16),
      const Text('Nominal Transfer', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 1)),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)), color: AppTheme.cardBg),
        child: TextField(
          controller: _nominalCtrl,
          keyboardType: TextInputType.number,
          style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white),
          decoration: InputDecoration(
            prefixText: 'Rp ',
            prefixStyle: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted),
            hintText: '10000',
            hintStyle: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted.withOpacity(0.5)),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          ),
        ),
      ),
      const SizedBox(height: 20),
      const Text('Bukti Transfer', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 1)),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: _uploadingProof ? null : _pickProof,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _proofBase64 != null
                  ? Colors.green.withOpacity(0.6)
                  : AppTheme.primaryBlue.withOpacity(0.4),
              width: 1.5),
            color: AppTheme.cardBg,
          ),
          child: _uploadingProof
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                    SizedBox(height: 8),
                    Text('Memuat gambar...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.orange)),
                  ]),
                )
              : _proofFile != null
                  ? Stack(children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(11),
                        child: Image.file(
                          File(_proofFile!.path),
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                        ),
                      ),
                      Positioned(top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Terpilih', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                          ]),
                        )),
                      Positioned(bottom: 8, right: 8,
                        child: GestureDetector(
                          onTap: _pickProof,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                            child: const Row(mainAxisSize: MainAxisSize.min, children: [
                              Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                              SizedBox(width: 4),
                              Text('Ganti', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                            ]),
                          ))),
                    ])
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.upload_rounded, color: AppTheme.primaryBlue.withOpacity(0.7), size: 32),
                        const SizedBox(height: 6),
                        const Text('Tap untuk upload bukti transfer', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
                        const SizedBox(height: 2),
                        Text('JPG / PNG dari galeri', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted.withOpacity(0.5))),
                      ]),
                    ),
        ),
      ),
      const SizedBox(height: 28),
      GestureDetector(
        onTap: _loading ? null : _submitTopup,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
          ),
          child: Center(child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Text('KIRIM TOP UP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white,
                  letterSpacing: 1.5, fontWeight: FontWeight.bold))),
        ),
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HISTORY SHEET
// ─────────────────────────────────────────────────────────────────────────────
class _TopUpHistorySheet extends StatefulWidget {
  const _TopUpHistorySheet();

  @override
  State<_TopUpHistorySheet> createState() => _TopUpHistorySheetState();
}

class _TopUpHistorySheetState extends State<_TopUpHistorySheet> {
  List<dynamic> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final res = await ApiService.get('/api/topup/history');
      if (res['success'] == true && mounted) {
        setState(() { _history = res['history'] ?? []; _loading = false; });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _statusColor(String s) {
    if (s == 'approved') return const Color(0xFF10B981);
    if (s == 'rejected') return Colors.redAccent;
    return Colors.orange;
  }

  String _statusLabel(String s) {
    if (s == 'approved') return 'DISETUJUI';
    if (s == 'rejected') return 'DITOLAK';
    return 'PENDING';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: AppTheme.darkBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: const Color(0xFF8B5CF6).withOpacity(0.3)),
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
                const Text('History Top Up', style: TextStyle(fontFamily: 'Orbitron', fontSize: 15,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              ]),
              const SizedBox(height: 14),
            ]),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2))
                : _history.isEmpty
                    ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Icon(Icons.receipt_long_rounded, size: 48, color: AppTheme.textMuted.withOpacity(0.4)),
                        const SizedBox(height: 12),
                        Text('Belum ada riwayat top up',
                            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted)),
                      ]))
                    : ListView.separated(
                        controller: ctrl,
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _history.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final item = _history[i] as Map<String, dynamic>;
                          final amount = item['amount'] as int? ?? 0;
                          final status = item['status'] as String? ?? 'pending';
                          final createdAt = item['createdAt'] as String? ?? '';
                          DateTime? dt;
                          try { dt = DateTime.parse(createdAt).toLocal(); } catch (_) {}
                          final sc = _statusColor(status);

                          return Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: sc.withOpacity(0.3)),
                              color: sc.withOpacity(0.04),
                            ),
                            child: Row(children: [
                              Container(width: 40, height: 40,
                                decoration: BoxDecoration(color: sc.withOpacity(0.15), borderRadius: BorderRadius.circular(10)),
                                child: Center(child: Icon(
                                  status == 'approved' ? Icons.check_circle_outline :
                                  status == 'rejected' ? Icons.cancel_outlined : Icons.hourglass_empty_rounded,
                                  color: sc, size: 20))),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text('Rp ${amount.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.')}',
                                    style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white)),
                                if (dt != null)
                                  Text('${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}',
                                      style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
                              ])),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
                                    color: sc.withOpacity(0.15), border: Border.all(color: sc.withOpacity(0.4))),
                                child: Text(_statusLabel(status),
                                    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: sc, letterSpacing: 1)),
                              ),
                            ]),
                          );
                        },
                      ),
          ),
        ]),
      ),
    );
  }
}
