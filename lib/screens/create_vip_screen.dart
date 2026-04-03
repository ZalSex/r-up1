import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../services/api_service.dart';

class CreateVipScreen extends StatefulWidget {
  const CreateVipScreen({super.key});

  @override
  State<CreateVipScreen> createState() => _CreateVipScreenState();
}

class _CreateVipScreenState extends State<CreateVipScreen> {
  static const _gold   = Color(0xFFFFD700);
  static const _purple = Color(0xFF8B5CF6);

  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscurePass   = true;
  bool _loading       = false;
  String _msg         = '';
  bool _msgSuccess    = false;
  String _vipType     = 'update';

  List<Map<String, dynamic>> _vipUsers = [];
  bool _loadingUsers = false;

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
      final res = await ApiService.ownerGetAllUsers();
      if (res['success'] == true && mounted) {
        final all = List<Map<String, dynamic>>.from(res['users'] ?? []);
        setState(() => _vipUsers = all.where((u) => u['role'] == 'vip').toList());
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
    if (password.length < 6) {
      showWarning(context, 'Password minimal 6 karakter!');
      return;
    }
    setState(() { _loading = true; });
    try {
      final res = await ApiService.post('/api/owner/create-vip', {
        'username': username,
        'password': password,
        'vipType':  _vipType,
      });
      if (res['success'] == true) {
        _usernameCtrl.clear();
        _passwordCtrl.clear();
        _loadVipUsers();
        if (mounted) showSuccess(context, 'Akun VIP "$username" ($_vipType) berhasil dibuat!');
      } else {
        if (mounted) showError(context, res['message'] as String? ?? 'Gagal membuat akun VIP');
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    }
    if (mounted) setState(() => _loading = false);
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
              border: Border.all(color: _gold.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16))),
        title: Row(children: [
          Container(width: 3, height: 18,
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_gold, Color(0xFFFFA500)]),
              borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          const Text('CREATE VIP', style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 14,
            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: _gold.withOpacity(0.15),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: _gold.withOpacity(0.5))),
            child: const Text('OWNER ONLY', style: TextStyle(
              fontFamily: 'ShareTechMono', fontSize: 8, color: _gold, letterSpacing: 1))),
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
                colors: [_gold.withOpacity(0.15), _gold.withOpacity(0.05)],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _gold.withOpacity(0.3))),
            child: Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: _gold.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _gold.withOpacity(0.5)),
                  boxShadow: [BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 12)]),
                child: const Center(child: Icon(Icons.star_rounded, color: _gold, size: 28))),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('BUAT AKUN VIP', style: TextStyle(
                  fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold,
                  color: _gold, letterSpacing: 1.5)),
                const SizedBox(height: 4),
                Text('Akun VIP dapat mengakses semua fitur hacked dan tools premium',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                    color: Colors.white.withOpacity(0.6), height: 1.5)),
              ])),
            ]),
          ),

          // Form section
          _buildLabel('USERNAME'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF071525),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.3))),
            child: TextField(
              controller: _usernameCtrl,
              style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: Icon(Icons.person_outline_rounded, color: _gold.withOpacity(0.6), size: 20),
                hintText: 'Masukkan username VIP...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono')),
            ),
          ),
          const SizedBox(height: 16),

          _buildLabel('PASSWORD'),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF071525),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.3))),
            child: TextField(
              controller: _passwordCtrl,
              obscureText: _obscurePass,
              style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                prefixIcon: Icon(Icons.lock_outline_rounded, color: _gold.withOpacity(0.6), size: 20),
                hintText: 'Min 6 karakter...',
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono'),
                suffixIcon: GestureDetector(
                  onTap: () => setState(() => _obscurePass = !_obscurePass),
                  child: Icon(_obscurePass ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                    color: _gold.withOpacity(0.5), size: 20))),
            ),
          ),
          const SizedBox(height: 16),

          // VIP Type Toggle
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _gold.withOpacity(0.3)),
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
                      color: _vipType == 'update' ? _gold.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _vipType == 'update' ? _gold : Colors.white24),
                    ),
                    child: Column(children: [
                      Icon(Icons.update_rounded, color: _vipType == 'update' ? _gold : Colors.white30, size: 20),
                      const SizedBox(height: 4),
                      Text('Update', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                        color: _vipType == 'update' ? _gold : Colors.white30)),
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
                      color: _vipType == 'no_update' ? _purple.withOpacity(0.15) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _vipType == 'no_update' ? _purple : Colors.white24),
                    ),
                    child: Column(children: [
                      Icon(Icons.block_rounded, color: _vipType == 'no_update' ? _purple : Colors.white30, size: 20),
                      const SizedBox(height: 4),
                      Text('No Update', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                        color: _vipType == 'no_update' ? _purple : Colors.white30)),
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
                    ? LinearGradient(colors: [_gold.withOpacity(0.4), const Color(0xFFFFA500).withOpacity(0.4)])
                    : const LinearGradient(colors: [_gold, Color(0xFFFFA500)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _loading ? [] : [BoxShadow(color: _gold.withOpacity(0.3), blurRadius: 16)]),
                child: Center(child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                  : const Text('⭐  BUAT AKUN VIP', style: TextStyle(
                      fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
                      color: Colors.black, letterSpacing: 1.5))),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // Existing VIP users list
          Row(children: [
            Container(width: 3, height: 14,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_gold, Color(0xFFFFA500)]),
                borderRadius: BorderRadius.circular(2))),
            const SizedBox(width: 8),
            const Text('DAFTAR AKUN VIP', style: TextStyle(
              fontFamily: 'Orbitron', fontSize: 11, color: _gold, letterSpacing: 2)),
            const Spacer(),
            GestureDetector(
              onTap: _loadVipUsers,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  border: Border.all(color: _gold.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(6)),
                child: const Text('Refresh', style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 9, color: _gold, letterSpacing: 1)))),
          ]),
          const SizedBox(height: 12),

          _loadingUsers
            ? Center(child: CircularProgressIndicator(color: _gold.withOpacity(0.7), strokeWidth: 2))
            : _vipUsers.isEmpty
              ? Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _gold.withOpacity(0.15))),
                  child: Center(child: Text('Belum ada akun VIP',
                    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white.withOpacity(0.4)))))
              : Column(
                  children: _vipUsers.map((u) => Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _gold.withOpacity(0.2))),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _gold.withOpacity(0.3))),
                        child: const Center(child: Icon(Icons.star_rounded, color: _gold, size: 18))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(u['username'] as String? ?? '-',
                          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(u['createdAt'] != null
                          ? 'Dibuat: ${(u['createdAt'] as String).substring(0, 10)}'
                          : '',
                          style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white.withOpacity(0.4))),
                      ])),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _gold.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: _gold.withOpacity(0.4))),
                        child: const Text('VIP', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: _gold, letterSpacing: 1))),
                    ]),
                  )).toList(),
                ),

          const SizedBox(height: 60),
        ]),
      ),
    );
  }

  Widget _buildLabel(String t) => Text(t,
    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
      color: _gold.withOpacity(0.8), letterSpacing: 1.5));
}
