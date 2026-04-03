import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../services/api_service.dart';

class ResellerAccessScreen extends StatefulWidget {
  const ResellerAccessScreen({super.key});

  @override
  State<ResellerAccessScreen> createState() => _ResellerAccessScreenState();
}

class _ResellerAccessScreenState extends State<ResellerAccessScreen> {
  static const _cyan   = Color(0xFF00E5FF);
  static const _teal   = Color(0xFF00BCD4);
  static const _darkBg = Color(0xFF050D15);

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass   = true;
  bool _loading       = false;
  String _vipType     = 'update';

  List<Map<String, dynamic>> _vipUsers = [];
  bool _loadingUsers = false;

  // Detail dialog state
  Map<String, dynamic>? _detailUser;

  @override
  void initState() {
    super.initState();
    _loadVipUsers();
  }

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadVipUsers() async {
    setState(() => _loadingUsers = true);
    try {
      final res = await ApiService.resellerGetVipUsers();
      if (res['success'] == true && mounted) {
        final all = List<Map<String, dynamic>>.from(res['users'] ?? []);
        setState(() => _vipUsers = all);
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingUsers = false);
  }

  Future<void> _createVip() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text.trim();
    if (username.isEmpty || password.isEmpty) {
      showWarning(context, 'Username dan password wajib diisi!');
      return;
    }
    if (password.length < 3) {
      showWarning(context, 'Password minimal 3 karakter!');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await ApiService.resellerCreateVip(
        username: username,
        password: password,
        vipType:  _vipType,
      );
      if (res['success'] == true) {
        final code = res['user']?['code'] ?? '-';
        _usernameCtrl.clear();
        _passwordCtrl.clear();
        _loadVipUsers();
        if (mounted) showSuccess(context, 'Akun VIP "$username" ($_vipType) Berhasil Dibuat!\n\nUsername: $username\nPassword: $password\nKode Akses: $code');
      } else {
        if (mounted) showError(context, res['message'] as String? ?? 'Gagal Membuat Akun VIP');
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _deleteVip(String userId, String username) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        title: const Text('Hapus Akun VIP',
            style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13)),
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
        final res = await ApiService.resellerDeleteVip(userId);
        if (res['success'] == true) {
          if (mounted) showSuccess(context, 'Akun "$username" berhasil dihapus');
          _loadVipUsers();
        } else {
          if (mounted) showError(context, res['message'] ?? 'Gagal hapus');
        }
      } catch (_) {
        if (mounted) showError(context, 'Koneksi gagal');
      }
    }
  }

  void _showDetailDialog(Map<String, dynamic> user) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.7),
      builder: (_) => _DetailDialog(user: user, accentColor: _cyan),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkBg,
      appBar: AppBar(
        backgroundColor: _darkBg,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: _cyan.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Row(children: [
          Container(
            width: 3, height: 18,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [_cyan, _teal]),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          const Text('RESELLER ACCESS', style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 13,
            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2,
          )),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _cyan.withOpacity(0.5)),
            ),
            child: Text('RESELLER ONLY', style: TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 8, color: _cyan, letterSpacing: 1,
            )),
          ),
        ]),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_cyan.withOpacity(0.12), _cyan.withOpacity(0.04)],
                begin: Alignment.topLeft, end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cyan.withOpacity(0.3)),
            ),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _cyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cyan.withOpacity(0.5)),
                  boxShadow: [BoxShadow(color: _cyan.withOpacity(0.25), blurRadius: 14)],
                ),
                child: Center(child: Icon(Icons.storefront_rounded, color: _cyan, size: 26)),
              ),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('BUAT AKUN VIP', style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold,
                  color: _cyan, letterSpacing: 1.5,
                )),
                const SizedBox(height: 4),
                Text(
                  '',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                    color: Colors.white.withOpacity(0.6), height: 1.5),
                ),
              ])),
            ]),
          ),

          // Form
          _buildLabel('USERNAME'),
          const SizedBox(height: 8),
          _buildTextField(controller: _usernameCtrl, hint: 'Masukkan username VIP...', icon: Icons.person_outline_rounded),
          const SizedBox(height: 16),
          _buildLabel('PASSWORD'),
          const SizedBox(height: 8),
          _buildPasswordField(),
          const SizedBox(height: 16),

          // VIP Type Toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0A1929),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _cyan.withOpacity(0.3)),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('TIPE VIP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                color: Colors.white70, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _vipType = 'update'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _vipType == 'update' ? _cyan.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _vipType == 'update' ? _cyan : Colors.white24),
                    ),
                    child: Column(children: [
                      Icon(Icons.update_rounded, color: _vipType == 'update' ? _cyan : Colors.white30, size: 20),
                      const SizedBox(height: 4),
                      Text('Update', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                        color: _vipType == 'update' ? _cyan : Colors.white30)),
                    ]),
                  ),
                )),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => setState(() => _vipType = 'no_update'),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _vipType == 'no_update' ? _teal.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _vipType == 'no_update' ? _teal : Colors.white24),
                    ),
                    child: Column(children: [
                      Icon(Icons.block_rounded, color: _vipType == 'no_update' ? _teal : Colors.white30, size: 20),
                      const SizedBox(height: 4),
                      Text('No Update', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                        color: _vipType == 'no_update' ? _teal : Colors.white30)),
                    ]),
                  ),
                )),
              ]),
            ]),
          ),
          const SizedBox(height: 20),

          // Create button
          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: _loading ? null : _createVip,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  gradient: _loading
                    ? LinearGradient(colors: [_cyan.withOpacity(0.4), _teal.withOpacity(0.4)])
                    : LinearGradient(colors: [_cyan, _teal]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _loading ? [] : [BoxShadow(color: _cyan.withOpacity(0.3), blurRadius: 16)],
                ),
                child: Center(
                  child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                    : const Text('BUAT AKUN', style: TextStyle(
                        fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
                        color: Colors.black, letterSpacing: 1.5,
                      )),
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // VIP users list
          Row(children: [
            Container(width: 3, height: 14,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [_cyan, _teal]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text('DAFTAR AKUN VIP', style: TextStyle(
              fontFamily: 'Orbitron', fontSize: 11, color: _cyan, letterSpacing: 2,
            )),
            const Spacer(),
            GestureDetector(
              onTap: _loadVipUsers,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: _cyan.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('Refresh', style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 9, color: _cyan, letterSpacing: 1,
                )),
              ),
            ),
          ]),
          const SizedBox(height: 12),

          _loadingUsers
            ? Center(child: CircularProgressIndicator(color: _cyan.withOpacity(0.7), strokeWidth: 2))
            : _vipUsers.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _cyan.withOpacity(0.15)),
                  ),
                  child: Center(child: Text('Belum ada akun VIP',
                    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11,
                      color: Colors.white.withOpacity(0.4),
                    )),
                  ),
                )
              : Column(
                  children: _vipUsers.map((u) => _buildVipCard(u)).toList(),
                ),

          const SizedBox(height: 80),
        ]),
      ),
    );
  }

  Widget _buildVipCard(Map<String, dynamic> u) {
    const _cyan = Color(0xFF00E5FF);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: _cyan.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _cyan.withOpacity(0.3)),
          ),
          child: Center(child: Icon(Icons.star_rounded, color: _cyan, size: 18)),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(u['username'] as String? ?? '-',
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            u['createdAt'] != null
              ? 'Dibuat: ${(u['createdAt'] as String).substring(0, 10)}'
              : 'Dibuat: -',
            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white.withOpacity(0.4)),
          ),
        ])),
        // Detail button
        GestureDetector(
          onTap: () => _showDetailDialog(u),
          child: Container(
            padding: const EdgeInsets.all(7),
            margin: const EdgeInsets.only(right: 6),
            decoration: BoxDecoration(
              color: _cyan.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _cyan.withOpacity(0.3)),
            ),
            child: Icon(Icons.info_outline_rounded, color: _cyan, size: 16),
          ),
        ),
        // Delete button
        GestureDetector(
          onTap: () => _deleteVip(u['id'] as String? ?? u['_id'] as String? ?? '', u['username'] as String? ?? ''),
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

  Widget _buildTextField({required TextEditingController controller, required String hint, required IconData icon}) {
    const _cyan = Color(0xFF00E5FF);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withOpacity(0.3)),
      ),
      child: TextField(
        controller: controller,
        style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(icon, color: _cyan.withOpacity(0.6), size: 20),
          hintText: hint,
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono'),
        ),
      ),
    );
  }

  Widget _buildPasswordField() {
    const _cyan = Color(0xFF00E5FF);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF071525),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _cyan.withOpacity(0.3)),
      ),
      child: TextField(
        controller: _passwordCtrl,
        obscureText: _obscurePass,
        style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          prefixIcon: Icon(Icons.lock_outline_rounded, color: _cyan.withOpacity(0.6), size: 20),
          hintText: 'Min 3 karakter...',
          hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono'),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscurePass = !_obscurePass),
            child: Icon(
              _obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
              color: _cyan.withOpacity(0.5), size: 20,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLabel(String t) => Text(t,
    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
      color: const Color(0xFF00E5FF).withOpacity(0.8), letterSpacing: 1.5,
    ));
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
    final code = user['code'] as String? ?? '-';
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
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 30)],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [color, color.withOpacity(0.5)]),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text('DETAIL AKUN', style: TextStyle(
              fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
              color: color, letterSpacing: 1.5,
            )),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Icon(Icons.close_rounded, color: Colors.white38, size: 20),
            ),
          ]),
          const SizedBox(height: 20),
          _DetailItem(label: 'USERNAME', value: username, color: color, onCopy: () => _copy(context, username)),
          const SizedBox(height: 10),
          _DetailItem(label: 'PASSWORD', value: password, color: color, onCopy: () => _copy(context, password)),
          const SizedBox(height: 10),
          _DetailItem(label: 'KODE AKSES', value: code, color: color, onCopy: () => _copy(context, code)),
          const SizedBox(height: 10),
          _DetailItem(label: 'DIBUAT', value: displayDate, color: color),
          const SizedBox(height: 10),
          _DetailItem(label: 'ROLE', value: role.toUpperCase(), color: color),
          const Divider(color: Colors.white12, height: 24),
          // Copy all button
          GestureDetector(
            onTap: () => _copy(context, 'Username: $username\nPassword: $password\nKode Akses: $code\nRole: $role\nDibuat: $displayDate'),
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
                  fontFamily: 'Orbitron', fontSize: 10, color: color, letterSpacing: 1,
                )),
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
            fontFamily: 'ShareTechMono', fontSize: 9, color: color.withOpacity(0.7), letterSpacing: 1,
          )),
        ),
        Expanded(child: Text(value, style: const TextStyle(
          fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold,
        ))),
        if (onCopy != null)
          GestureDetector(
            onTap: onCopy,
            child: Icon(Icons.copy_rounded, color: color.withOpacity(0.5), size: 15),
          ),
      ]),
    );
  }
}
