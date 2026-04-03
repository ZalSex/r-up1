import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../services/api_service.dart';

class OwnerSettingScreen extends StatefulWidget {
  const OwnerSettingScreen({super.key});

  @override
  State<OwnerSettingScreen> createState() => _OwnerSettingScreenState();
}

class _OwnerSettingScreenState extends State<OwnerSettingScreen>
    with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF8B5CF6);
  static const _purpleDark = Color(0xFF7C3AED);

  late TabController _tabCtrl;

  // Reseller tab
  final _rsUsernameCtrl = TextEditingController();
  final _rsPasswordCtrl = TextEditingController();
  bool _rsObscure     = true;
  bool _rsLoading     = false;
  List<Map<String, dynamic>> _resellerUsers = [];
  bool _rsListLoading = false;

  // VIP tab
  final _vipUsernameCtrl = TextEditingController();
  final _vipPasswordCtrl = TextEditingController();
  bool _vipObscure     = true;
  bool _vipLoading     = false;
  List<Map<String, dynamic>> _vipUsers = [];
  bool _vipListLoading = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadResellerUsers();
    _loadVipUsers();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _rsUsernameCtrl.dispose();
    _rsPasswordCtrl.dispose();
    _vipUsernameCtrl.dispose();
    _vipPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadResellerUsers() async {
    setState(() => _rsListLoading = true);
    try {
      final res = await ApiService.ownerGetAllUsers();
      if (res['success'] == true && mounted) {
        final all = List<Map<String, dynamic>>.from(res['users'] ?? []);
        setState(() => _resellerUsers = all.where((u) => u['role'] == 'reseller').toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _rsListLoading = false);
  }

  Future<void> _loadVipUsers() async {
    setState(() => _vipListLoading = true);
    try {
      final res = await ApiService.ownerGetAllUsers();
      if (res['success'] == true && mounted) {
        final all = List<Map<String, dynamic>>.from(res['users'] ?? []);
        setState(() => _vipUsers = all.where((u) => u['role'] == 'vip').toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _vipListLoading = false);
  }

  Future<void> _createReseller() async {
    final username = _rsUsernameCtrl.text.trim();
    final password = _rsPasswordCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _showCenterNotif(message: 'Username dan password wajib diisi!', success: false);
      return;
    }
    if (password.length < 3) {
      _showCenterNotif(message: 'Password minimal 3 karakter!', success: false);
      return;
    }
    setState(() => _rsLoading = true);
    try {
      final res = await ApiService.ownerCreateReseller(username: username, password: password);
      if (res['success'] == true) {
        _showCenterNotif(
          message: 'Akun Reseller "$username" Berhasil Dibuat!',
          success: true,
          username: username,
          password: password,
        );
        _rsUsernameCtrl.clear();
        _rsPasswordCtrl.clear();
        _loadResellerUsers();
      } else {
        _showCenterNotif(message: res['message'] ?? 'Gagal Membuat Reseller', success: false);
      }
    } catch (e) {
      _showCenterNotif(message: 'Error: $e', success: false);
    }
    if (mounted) setState(() => _rsLoading = false);
  }

  Future<void> _createVip() async {
    final username = _vipUsernameCtrl.text.trim();
    final password = _vipPasswordCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      _showCenterNotif(message: 'Username dan password wajib diisi!', success: false);
      return;
    }
    if (password.length < 3) {
      _showCenterNotif(message: 'Password minimal 3 karakter!', success: false);
      return;
    }
    setState(() => _vipLoading = true);
    try {
      final res = await ApiService.post('/api/owner/create-vip', {
        'username': username,
        'password': password,
      });
      if (res['success'] == true) {
        _showCenterNotif(
          message: 'Akun VIP "$username" Berhasil Dibuat!',
          success: true,
          username: username,
          password: password,
        );
        _vipUsernameCtrl.clear();
        _vipPasswordCtrl.clear();
        _loadVipUsers();
      } else {
        _showCenterNotif(message: res['message'] ?? 'Gagal Membuat VIP', success: false);
      }
    } catch (e) {
      _showCenterNotif(message: 'Error: $e', success: false);
    }
    if (mounted) setState(() => _vipLoading = false);
  }

  Future<void> _deleteUser(String userId, String username, String role) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        title: Text('Hapus ${role == 'reseller' ? 'Reseller' : 'VIP'}',
            style: const TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13)),
        content: Text('Hapus akun "$username"?',
            style: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal',
                style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 11)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus',
                style: TextStyle(fontFamily: 'Orbitron', color: Colors.red, fontSize: 11)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      try {
        final res = await ApiService.ownerDeleteUser(userId);
        if (res['success'] == true) {
          _showCenterNotif(message: 'Akun "$username" berhasil dihapus', success: true);
          if (role == 'reseller') _loadResellerUsers();
          else _loadVipUsers();
        } else {
          _showCenterNotif(message: res['message'] ?? 'Gagal hapus', success: false);
        }
      } catch (_) {
        _showCenterNotif(message: 'Koneksi gagal', success: false);
      }
    }
  }

  void _showCenterNotif({
    required String message,
    required bool success,
    String? username,
    String? password,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _CenterNotifDialog(
        message: message,
        success: success,
        username: username,
        password: password,
        accentColor: _purple,
      ),
    );
  }

  void _showDetailDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _DetailDialog(user: user, accentColor: _purple),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: _purple.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Row(children: [
          Container(width: 3, height: 18,
            decoration: BoxDecoration(
              color: _purple,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text('OWNER SETTING', style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 13,
            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _purple.withOpacity(0.5)),
            ),
            child: const Text('OWNER ONLY', style: TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 8, color: _purple, letterSpacing: 1,
            )),
          ),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: _purple.withOpacity(0.2))),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: _purple,
              unselectedLabelColor: Colors.white38,
              indicatorColor: _purple,
              indicatorWeight: 2,
              labelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, letterSpacing: 1.5),
              tabs: const [
                Tab(text: 'RESELLER'),
                Tab(text: 'VIP'),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildResellerTab(),
          _buildVipTab(),
        ],
      ),
    );
  }

  Widget _buildResellerTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeaderCard(
          icon: Icons.store_rounded,
          title: 'BUAT AKUN RESELLER',
          subtitle: '',
          color: _purple,
        ),
        const SizedBox(height: 20),
        _buildLabel('USERNAME'),
        const SizedBox(height: 8),
        _buildTextField(controller: _rsUsernameCtrl, hint: 'Username reseller...', icon: Icons.person_outline_rounded, color: _purple),
        const SizedBox(height: 16),
        _buildLabel('PASSWORD'),
        const SizedBox(height: 8),
        _buildPasswordField(controller: _rsPasswordCtrl, obscure: _rsObscure, onToggle: () => setState(() => _rsObscure = !_rsObscure), color: _purple),
        const SizedBox(height: 20),
        _buildCreateButton(label: 'BUAT AKUN', loading: _rsLoading, onTap: _createReseller, color: _purple),
        const SizedBox(height: 32),
        _buildListHeader(title: 'DAFTAR RESELLER', color: _purple, onRefresh: _loadResellerUsers),
        const SizedBox(height: 12),
        _rsListLoading
          ? Center(child: CircularProgressIndicator(color: _purple.withOpacity(0.7), strokeWidth: 2))
          : _resellerUsers.isEmpty
            ? _buildEmpty(text: 'Belum ada reseller', color: _purple)
            : Column(children: _resellerUsers.map((u) => _buildUserCard(u, color: _purple, role: 'reseller')).toList()),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildVipTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildHeaderCard(
          icon: Icons.star_rounded,
          title: 'BUAT AKUN VIP',
          subtitle: '',
          color: _purple,
        ),
        const SizedBox(height: 20),
        _buildLabel('USERNAME'),
        const SizedBox(height: 8),
        _buildTextField(controller: _vipUsernameCtrl, hint: 'Username VIP...', icon: Icons.person_outline_rounded, color: _purple),
        const SizedBox(height: 16),
        _buildLabel('PASSWORD'),
        const SizedBox(height: 8),
        _buildPasswordField(controller: _vipPasswordCtrl, obscure: _vipObscure, onToggle: () => setState(() => _vipObscure = !_vipObscure), color: _purple),
        const SizedBox(height: 20),
        _buildCreateButton(label: 'BUAT AKUN', loading: _vipLoading, onTap: _createVip, color: _purple),
        const SizedBox(height: 32),
        _buildListHeader(title: 'SEMUA AKUN VIP', color: _purple, onRefresh: _loadVipUsers),
        const SizedBox(height: 12),
        _vipListLoading
          ? Center(child: CircularProgressIndicator(color: _purple.withOpacity(0.7), strokeWidth: 2))
          : _vipUsers.isEmpty
            ? _buildEmpty(text: 'Belum ada akun VIP', color: _purple)
            : Column(children: _vipUsers.map((u) => _buildUserCard(u, color: _purple, role: 'vip')).toList()),
        const SizedBox(height: 80),
      ]),
    );
  }

  Widget _buildHeaderCard({required IconData icon, required String title, required String subtitle, required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5)),
            boxShadow: [BoxShadow(color: color.withOpacity(0.10), blurRadius: 6)],
          ),
          child: Center(child: Icon(icon, color: color, size: 26)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
            color: color, letterSpacing: 1.5,
          )),
          const SizedBox(height: 4),
          Text(subtitle, style: TextStyle(
            fontFamily: 'ShareTechMono', fontSize: 10,
            color: Colors.white.withOpacity(0.6), height: 1.5,
          )),
        ])),
      ]),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: color.withOpacity(0.6), size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono'),
        ),
      ),
    );
  }

  Widget _buildPasswordField({required TextEditingController controller, required bool obscure, required VoidCallback onToggle, required Color color}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: color.withOpacity(0.6), size: 20),
          hintText: 'Min 3 karakter...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono'),
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: color.withOpacity(0.5), size: 20),
          ),
        ),
      ),
    );
  }

  Widget _buildCreateButton({required String label, required bool loading, required VoidCallback onTap, required Color color}) {
    return SizedBox(
      width: double.infinity,
      child: GestureDetector(
        onTap: loading ? null : onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: loading ? color.withOpacity(0.3) : color,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
            : Text(label, style: const TextStyle(
                fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
                color: Colors.black, letterSpacing: 1.5,
              )),
          ),
        ),
      ),
    );
  }

  Widget _buildListHeader({required String title, required Color color, required VoidCallback onRefresh}) {
    return Row(children: [
      Container(width: 3, height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: color, letterSpacing: 2)),
      const Spacer(),
      GestureDetector(
        onTap: onRefresh,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text('Refresh', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: color, letterSpacing: 1)),
        ),
      ),
    ]);
  }

  Widget _buildEmpty({required String text, required Color color}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Center(child: Text(text,
        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white.withOpacity(0.4)),
      )),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> u, {required Color color, required String role}) {
    final icon = role == 'reseller' ? Icons.store_rounded : Icons.star_rounded;
    final label = role == 'reseller' ? 'RESELLER' : 'VIP';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Center(child: Icon(icon, color: color, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u['username'] as String? ?? '-',
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(
            u['createdAt'] != null ? 'Dibuat: ${(u['createdAt'] as String).substring(0, 10)}' : 'Dibuat: -',
            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white.withOpacity(0.4)),
          ),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.35)),
          ),
          child: Text(label, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: color, letterSpacing: 1)),
        ),
        const SizedBox(width: 6),
        // Detail button
        GestureDetector(
          onTap: () => _showDetailDialog(u),
          child: Container(
            padding: const EdgeInsets.all(7),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withOpacity(0.3)),
            ),
            child: Icon(Icons.info_outline_rounded, color: color, size: 16),
          ),
        ),
        // Delete button
        GestureDetector(
          onTap: () => _deleteUser(u['id'] as String? ?? u['_id'] as String? ?? '', u['username'] as String? ?? '', role),
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withOpacity(0.3)),
            ),
            child: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 16),
          ),
        ),
      ]),
    );
  }

  Widget _buildLabel(String t) => Text(t,
    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
      color: _purple.withOpacity(0.8), letterSpacing: 1.5,
    ));
}

// ─── Center Notification Dialog ───────────────────────────────────────────────
class _CenterNotifDialog extends StatelessWidget {
  final String message;
  final bool success;
  final String? username;
  final String? password;
  final Color accentColor;

  const _CenterNotifDialog({
    required this.message,
    required this.success,
    this.username,
    this.password,
    required this.accentColor,
  });

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showSuccess(context, 'Disalin!');
  }

  @override
  Widget build(BuildContext context) {
    final color = success ? accentColor : Colors.red;
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5)),
            ),
            child: Icon(success ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              color: color, size: 28),
          ),
          const SizedBox(height: 16),
          Text(success ? 'BERHASIL' : 'GAGAL',
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold,
              color: color, letterSpacing: 2)),
          const SizedBox(height: 8),
          Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white70, height: 1.5)),
          if (success && username != null && password != null) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: color.withOpacity(0.07),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.25)),
              ),
              child: Column(children: [
                _DataRow(label: 'Username', value: username!, color: color, onCopy: () => _copy(context, username!)),
                const SizedBox(height: 8),
                _DataRow(label: 'Password', value: password!, color: color, onCopy: () => _copy(context, password!)),
                const Divider(color: Colors.white12, height: 20),
                GestureDetector(
                  onTap: () => _copy(context, 'Username: $username\nPassword: $password'),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: color.withOpacity(0.4)),
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.copy_rounded, color: color, size: 14),
                      const SizedBox(width: 6),
                      Text('Salin Semua', style: TextStyle(
                        fontFamily: 'ShareTechMono', fontSize: 10, color: color, letterSpacing: 1)),
                    ]),
                  ),
                ),
              ]),
            ),
          ],
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 10),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text('OK', style: TextStyle(
                fontFamily: 'Orbitron', fontSize: 12, color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DataRow extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback onCopy;

  const _DataRow({required this.label, required this.value, required this.color, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('$label: ', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: color.withOpacity(0.7))),
      Expanded(child: Text(value, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
      GestureDetector(
        onTap: onCopy,
        child: Icon(Icons.copy_rounded, color: color.withOpacity(0.6), size: 15),
      ),
    ]);
  }
}

// ─── Detail Dialog ────────────────────────────────────────────────────────────
class _DetailDialog extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color accentColor;

  const _DetailDialog({required this.user, required this.accentColor});

  void _copy(BuildContext context, String text) {
    Clipboard.setData(ClipboardData(text: text));
    showSuccess(context, 'Disalin!');
  }

  @override
  Widget build(BuildContext context) {
    final color = accentColor;
    final username = user['username'] as String? ?? '-';
    final password = user['password'] as String? ?? '••••••';
    final createdAt = user['createdAt'] as String? ?? '-';
    final role = user['role'] as String? ?? 'vip';
    final displayDate = createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF0A1929),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.5), width: 1.5),
          boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 10)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(2),
              )),
            const SizedBox(width: 10),
            Text('DETAIL AKUN', style: TextStyle(
              fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
              color: color, letterSpacing: 1.5)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, color: Colors.white38, size: 20),
            ),
          ]),
          const SizedBox(height: 20),
          _DetailItem(label: 'USERNAME', value: username, color: color, onCopy: () => _copy(context, username)),
          const SizedBox(height: 10),
          _DetailItem(label: 'PASSWORD', value: password, color: color, onCopy: () => _copy(context, password)),
          const SizedBox(height: 10),
          _DetailItem(label: 'DIBUAT', value: displayDate, color: color),
          const SizedBox(height: 10),
          _DetailItem(label: 'ROLE', value: role.toUpperCase(), color: color),
          const Divider(color: Colors.white12, height: 24),
          GestureDetector(
            onTap: () => _copy(context, 'Username: $username\nPassword: $password\nRole: $role\nDibuat: $displayDate'),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.35)),
              ),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.copy_all_rounded, color: color, size: 16),
                const SizedBox(width: 8),
                Text('SALIN SEMUA DATA', style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 10, color: color, letterSpacing: 1)),
              ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class _DetailItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final VoidCallback? onCopy;

  const _DetailItem({required this.label, required this.value, required this.color, this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Row(children: [
        SizedBox(
          width: 76,
          child: Text(label, style: TextStyle(
            fontFamily: 'ShareTechMono', fontSize: 9, color: color.withOpacity(0.7), letterSpacing: 1)),
        ),
        Expanded(child: Text(value, style: const TextStyle(
          fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Icon(Icons.copy_rounded, color: color.withOpacity(0.5), size: 15),
          ),
      ]),
    );
  }
}
