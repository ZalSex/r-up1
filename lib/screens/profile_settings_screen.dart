import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/role_style.dart';
import '../utils/app_localizations.dart';
import '../services/api_service.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen>
    with TickerProviderStateMixin {
  String _username = '';
  String _role = 'member';
  String? _avatarBase64;
  bool _loading = true;
  bool _saving = false;

  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();
  bool _showOld = false;
  bool _showNew = false;
  bool _showConfirm = false;

  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowCtrl);
    _loadProfile();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    _oldPassCtrl.dispose();
    _newPassCtrl.dispose();
    _confirmPassCtrl.dispose();
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
      if (res['success'] == true && mounted) {
        final user = res['user'];
        setState(() {
          _username = user['username'] ?? _username;
          _role = user['role'] ?? _role;
          _avatarBase64 = user['avatar'];
        });
        await prefs.setString('username', _username);
        await prefs.setString('role', _role);
        if (_avatarBase64 != null) await prefs.setString('avatar', _avatarBase64!);
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70, maxWidth: 400);
    if (picked == null) return;
    final bytes = await File(picked.path).readAsBytes();
    final b64 = base64Encode(bytes);
    setState(() => _saving = true);
    try {
      final res = await ApiService.updateAvatar(b64);
      if (res['success'] == true) {
        setState(() => _avatarBase64 = b64);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('avatar', b64);
        _snack(tr('avatar_updated'), isSuccess: true);
      } else {
        _snack(res['message'] ?? tr('error'), isError: true);
      }
    } catch (e) {
      _snack('\$e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _changePassword() async {
    final old = _oldPassCtrl.text.trim();
    final newP = _newPassCtrl.text.trim();
    final confirm = _confirmPassCtrl.text.trim();
    if (old.isEmpty || newP.isEmpty || confirm.isEmpty) {
      _snack(tr('error'), isError: true);
      return;
    }
    if (newP != confirm) {
      _snack(tr('password_mismatch'));
      return;
    }
    setState(() => _saving = true);
    try {
      final res = await ApiService.changePassword(old, newP);
      if (res['success'] == true) {
        _oldPassCtrl.clear();
        _newPassCtrl.clear();
        _confirmPassCtrl.clear();
        _snack(tr('password_changed'), isSuccess: true);
      } else {
        _snack(res['message'] ?? tr('password_wrong'), isError: true);
      }
    } catch (e) {
      _snack('\$e', isError: true);
    }
    if (mounted) setState(() => _saving = false);
  }

  void _snack(String msg, {bool isError = false, bool isSuccess = false}) {
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
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: const Color(0xFF050D1A),
        body: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
              child: _loading
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(60),
                        child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
                      ),
                    )
                  : Column(
                      children: [
                        _buildHeroSection(),
                        const SizedBox(height: 8),
                        _buildGroupLabel('AKUN'),
                        _buildSettingGroup([
                          _buildSettingTile(
                            icon: AppSvgIcons.user, iconColor: AppTheme.accentBlue,
                            title: tr('username'), subtitle: _username, onTap: null,
                          ),
                          _buildDivider(),
                          _buildSettingTile(
                            icon: AppSvgIcons.shield, iconColor: _roleColor(_role),
                            title: tr('role'), subtitle: _role.toUpperCase(),
                            trailing: _roleBadge(_role), onTap: null,
                          ),
                        ]),
                        const SizedBox(height: 8),
                        _buildGroupLabel('KEAMANAN'),
                        _buildSettingGroup([
                          _buildSettingTile(
                            icon: AppSvgIcons.lock, iconColor: Colors.orange,
                            title: tr('change_password'), subtitle: 'Ubah password akun kamu',
                            showChevron: true, onTap: _showPasswordBottomSheet,
                          ),
                        ]),
                        const SizedBox(height: 8),
                        _buildGroupLabel('PREFERENSI'),
                        _buildSettingGroup([
                          _buildSettingTile(
                            icon: AppSvgIcons.globe, iconColor: const Color(0xFF4CAF50),
                            title: tr('app_language'),
                            subtitle: AppLocalizations.instance.lang == 'id' ? '🇮🇩 Indonesia' : '🇬🇧 English',
                            showChevron: true, onTap: _showLanguageBottomSheet,
                          ),
                        ]),
                        const SizedBox(height: 8),
                        _buildGroupLabel('INFORMASI'),
                        _buildSettingGroup([
                          _buildSettingTile(
                            icon: AppSvgIcons.file, iconColor: AppTheme.accentBlue,
                            title: 'INFORMASI APLIKASI', subtitle: 'Fitur, peraturan & info lengkap',
                            showChevron: true, onTap: _showReadmeDialog,
                          ),
                          _buildDivider(),
                          _buildSettingTile(
                            icon: AppSvgIcons.verified, iconColor: Colors.green,
                            title: 'VERSI APLIKASI', subtitle: 'Revenge 2.1.0.1.9 — Stable',
                            trailing: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.green.withOpacity(0.4)),
                              ),
                              child: const Text('STABLE',
                                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.green, letterSpacing: 1)),
                            ),
                            onTap: null,
                          ),
                        ]),
                        const SizedBox(height: 100),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      backgroundColor: const Color(0xFF050D1A),
      elevation: 0, pinned: true,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
        ),
      ),
      title: Row(children: [
        Container(width: 3, height: 18,
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 10),
        Text(tr('profile_settings'),
          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
      ]),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: AppTheme.primaryBlue.withOpacity(0.15)),
      ),
    );
  }

  Widget _buildHeroSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [AppTheme.primaryBlue.withOpacity(0.12), Colors.transparent],
        ),
      ),
      child: Column(children: [
        GestureDetector(
          onTap: _pickPhoto,
          child: Stack(children: [
            _avatarBase64 != null
                ? RoleStyle.instagramPhoto(
                    customImage: Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover),
                    colors: RoleStyle.loginBorderColors,
                    rotateAnim: _rotateAnim, glowAnim: _glowAnim,
                    size: 96, borderWidth: 3, innerPad: 3,
                  )
                : RoleStyle.instagramPhoto(
                    assetPath: 'assets/icons/revenge.jpg',
                    colors: RoleStyle.loginBorderColors,
                    rotateAnim: _rotateAnim, glowAnim: _glowAnim,
                    size: 96, borderWidth: 3, innerPad: 3,
                  ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 30, height: 30,
                decoration: BoxDecoration(
                  gradient: AppTheme.primaryGradient,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF050D1A), width: 2),
                ),
                child: Center(
                  child: SvgPicture.string(AppSvgIcons.camera, width: 14, height: 14,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                ),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 14),
        Text(_username,
          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 18,
              fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _roleColor(_role).withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _roleColor(_role).withOpacity(0.5)),
          ),
          child: Text(_role.toUpperCase(),
            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                color: _roleColor(_role), letterSpacing: 2)),
        ),
        const SizedBox(height: 8),
        Text(_saving ? tr('loading') : tr('change_photo'),
          style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
              color: _saving ? AppTheme.textMuted : AppTheme.accentBlue.withOpacity(0.7), letterSpacing: 1)),
      ]),
    );
  }

  Widget _buildGroupLabel(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
      child: Text(label,
        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
            color: AppTheme.accentBlue.withOpacity(0.6), letterSpacing: 2)),
    );
  }

  Widget _buildSettingGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1F35),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildSettingTile({
    required String icon, required Color iconColor,
    required String title, required String subtitle,
    Widget? trailing, bool showChevron = false, VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(child: SvgPicture.string(icon, width: 18, height: 18,
                colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn))),
          ),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11,
                fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                color: AppTheme.textMuted.withOpacity(0.7))),
          ])),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted.withOpacity(0.4), size: 20),
          ],
        ]),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 68),
      child: Container(height: 1, color: AppTheme.primaryBlue.withOpacity(0.1)),
    );
  }

  // ── Password Bottom Sheet ─────────────────────────────────────────────────
  void _showPasswordBottomSheet() {
    _oldPassCtrl.clear(); _newPassCtrl.clear(); _confirmPassCtrl.clear();
    _showOld = false; _showNew = false; _showConfirm = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1F35),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4,
                  decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 20),
                Row(children: [
                  Container(width: 3, height: 18,
                    decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 10),
                  Text(tr('change_password'),
                    style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14,
                        fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                ]),
                const SizedBox(height: 20),
                _sheetPassField(setSheetState, tr('old_password'), _oldPassCtrl, _showOld,
                    () => setSheetState(() => _showOld = !_showOld), AppSvgIcons.lock),
                const SizedBox(height: 12),
                _sheetPassField(setSheetState, tr('new_password'), _newPassCtrl, _showNew,
                    () => setSheetState(() => _showNew = !_showNew), AppSvgIcons.lock),
                const SizedBox(height: 12),
                _sheetPassField(setSheetState, tr('confirm_password'), _confirmPassCtrl, _showConfirm,
                    () => setSheetState(() => _showConfirm = !_showConfirm), AppSvgIcons.shield),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _saving ? null : () async {
                    Navigator.pop(ctx);
                    await _changePassword();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: _saving
                        ? [Colors.grey.withOpacity(0.3), Colors.grey.withOpacity(0.3)]
                        : [AppTheme.primaryBlue, const Color(0xFF00E5FF)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(child: _saving
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(tr('save'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                          fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2))),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetPassField(StateSetter setSheetState, String label, TextEditingController ctrl,
      bool visible, VoidCallback toggle, String iconSvg) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
          color: AppTheme.textMuted.withOpacity(0.7), letterSpacing: 1)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(
          color: const Color(0xFF071525),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
        ),
        child: TextField(
          controller: ctrl,
          obscureText: !visible,
          style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            prefixIcon: Padding(padding: const EdgeInsets.all(12),
              child: SvgPicture.string(iconSvg, width: 16, height: 16,
                  colorFilter: const ColorFilter.mode(AppTheme.textMuted, BlendMode.srcIn))),
            suffixIcon: GestureDetector(
              onTap: toggle,
              child: Padding(padding: const EdgeInsets.all(12),
                child: SvgPicture.string(visible ? AppSvgIcons.eyeOff : AppSvgIcons.eye,
                    width: 16, height: 16,
                    colorFilter: const ColorFilter.mode(AppTheme.textMuted, BlendMode.srcIn))),
            ),
          ),
        ),
      ),
    ]);
  }

  // ── Language Bottom Sheet ─────────────────────────────────────────────────
  void _showLanguageBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0D1F35),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: ListenableBuilder(
          listenable: AppLocalizations.instance,
          builder: (ctx, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 3, height: 18,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text(tr('app_language'),
                  style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
              ]),
              const SizedBox(height: 16),
              _langOption(ctx, 'id', tr('indonesian'), '🇮🇩'),
              const SizedBox(height: 8),
              _langOption(ctx, 'en', tr('english'), '🇬🇧'),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _langOption(BuildContext ctx, String code, String label, String flag) {
    final isSelected = AppLocalizations.instance.lang == code;
    return GestureDetector(
      onTap: () { AppLocalizations.instance.setLang(code); Navigator.pop(ctx); },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryBlue.withOpacity(0.2) : const Color(0xFF071525),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.primaryBlue.withOpacity(0.6) : AppTheme.primaryBlue.withOpacity(0.15)),
        ),
        child: Row(children: [
          Text(flag, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 14),
          Text(label, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 13,
              color: isSelected ? Colors.white : AppTheme.textMuted)),
          const Spacer(),
          if (isSelected)
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(color: AppTheme.primaryBlue, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded, color: Colors.white, size: 13),
            ),
        ]),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Color _roleColor(String role) {
    switch (role) {
      case 'owner':   return Colors.orange;
      case 'vip':     return const Color(0xFFFFD54F);
      case 'premium': return const Color(0xFF82B1FF);
      default:        return AppTheme.textMuted;
    }
  }

  Widget _roleBadge(String role) {
    final color = _roleColor(role);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Text(role.toUpperCase(), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: color, letterSpacing: 1)),
    );
  }

  // ── Informasi Aplikasi Dialog ─────────────────────────────────────────────
  void _showReadmeDialog() {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1117),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5), width: 1.5),
          ),
          child: Column(children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2)))),
              child: Row(children: [
                Container(width: 3, height: 18,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                const Text('📋 INFORMASI APLIKASI',
                  style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30, height: 30,
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.red.withOpacity(0.4))),
                    child: const Icon(Icons.close_rounded, color: Colors.red, size: 16),
                  ),
                ),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(18),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _readmeSectionTitle('FITUR-FITUR', AppSvgIcons.zap, AppTheme.accentBlue),
                  const SizedBox(height: 10),
                  _readmeFeature('Bug WhatsApp', 'Kirim serangan bug ke target melalui WhatsApp'),
                  _readmeFeature('Hacked Command', 'Remote control device target (VIP/Owner)'),
                  _readmeFeature('WA Call Spam', 'Spam panggilan WhatsApp ke target'),
                  _readmeFeature('Spam NGL', 'Kirim pesan anonim massal ke NGL link'),
                  _readmeFeature('Spam Pairing', 'Spam pairing code WhatsApp'),
                  _readmeFeature('Remini AI', 'Enhance foto menggunakan AI'),
                  _readmeFeature('iPhone Quote', 'Generate screenshot quote ala iPhone'),
                  _readmeFeature('Downloader', 'Download konten dari berbagai platform'),
                  _readmeFeature('Grup Chat', 'Chat internal semua member Pegasus-X'),
                  _readmeFeature('DDOS Tool', 'Multi-layer network stress test (VIP/Owner)'),
                  _readmeFeature('Manage Sender', 'Kelola nomor WhatsApp sebagai sender'),
                  _readmeFeature('Manage Users', 'Manajemen user (Owner only)'),
                  const SizedBox(height: 20),
                  _readmeSectionTitle('PERATURAN', AppSvgIcons.file, Colors.orange),
                  const SizedBox(height: 10),
                  _readmeRule('1', 'Dilarang menyalahgunakan fitur untuk tujuan ilegal'),
                  _readmeRule('2', 'Dilarang menjual atau mendistribusikan ulang aplikasi ini'),
                  _readmeRule('3', 'Dilarang melakukan spam berlebihan yang merugikan server'),
                  _readmeRule('4', 'Dilarang share akun kepada orang lain'),
                  _readmeRule('5', 'Dilarang menggunakan akun untuk menyerang sesama member'),
                  _readmeRule('6', 'Dilarang melakukan eksploitasi bug/celah aplikasi'),
                  _readmeRule('7', 'Hormati sesama member dan owner'),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity, padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withOpacity(0.4))),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SvgPicture.string(AppSvgIcons.ban, width: 14, height: 14,
                            colorFilter: const ColorFilter.mode(Colors.red, BlendMode.srcIn)),
                        const SizedBox(width: 6),
                        const Text('PERINGATAN', style: TextStyle(fontFamily: 'Orbitron',
                            fontSize: 12, color: Colors.red, fontWeight: FontWeight.bold, letterSpacing: 2)),
                      ]),
                      const SizedBox(height: 8),
                      const Text('Jika Melanggar Aturan Di Atas,\nAkun Anda Akan Dihapus Dan\nDibanned Selamanya!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.red, height: 1.6)),
                    ]),
                  ),
                  const SizedBox(height: 20),
                  _readmeSectionTitle('ROLE & AKSES', AppSvgIcons.shield, AppTheme.accentBlue),
                  const SizedBox(height: 10),
                  _readmeRole('Member',  'Akses fitur dasar', Colors.grey),
                  _readmeRole('VIP',     'Akses semua fitur + Hacked Command', const Color(0xFFFFD54F)),
                  _readmeRole('Premium', 'Akses semua fitur + prioritas', const Color(0xFF82B1FF)),
                  _readmeRole('Owner',   'Full akses + manajemen sistem', Colors.orange),
                  const SizedBox(height: 20),
                ]),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _readmeSectionTitle(String title, String svgIcon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        SvgPicture.string(svgIcon, width: 13, height: 13,
            colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
        const SizedBox(width: 6),
        Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
            fontWeight: FontWeight.bold, color: color, letterSpacing: 1.5)),
      ]),
    );
  }

  Widget _readmeFeature(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.only(top: 4),
          child: Container(width: 5, height: 5,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentBlue))),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11,
              color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(desc, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
        ])),
      ]),
    );
  }

  Widget _readmeRule(String num, String rule) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.15), shape: BoxShape.circle,
            border: Border.all(color: Colors.orange.withOpacity(0.4))),
          child: Center(child: Text(num, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.orange))),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(rule, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, height: 1.4))),
      ]),
    );
  }

  Widget _readmeRole(String role, String desc, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.4))),
          child: Text(role, style: TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: color, letterSpacing: 1)),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(desc, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted))),
      ]),
    );
  }
}
