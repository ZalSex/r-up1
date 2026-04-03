import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/app_localizations.dart';
import '../services/api_service.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _oldPassCtrl = TextEditingController();
  final _newPassCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureOld = true, _obscureNew = true, _obscureConfirm = true;
  bool _loading = false;

  Future<void> _changePassword() async {
    if (_oldPassCtrl.text.isEmpty || _newPassCtrl.text.isEmpty || _confirmCtrl.text.isEmpty) {
      _showSnack('Semua Field Harus Diisi');
      return;
    }
    if (_newPassCtrl.text != _confirmCtrl.text) {
      _showSnack('Password Baru Tidak Cocok');
      return;
    }
    if (_newPassCtrl.text.length < 6) {
      _showSnack('Password Minimal 6 Karakter');
      return;
    }

    setState(() => _loading = true);
    try {
      final res = await ApiService.changePassword(_oldPassCtrl.text, _newPassCtrl.text);
      if (res['success'] == true) {
        _showSnack('Password Berhasil Diubah', isSuccess: true);
        if (mounted) Navigator.pop(context);
      } else {
        _showSnack(res['message'] ?? 'Gagal', isError: true);
      }
    } catch (_) {
      _showSnack('Koneksi Gagal', isError: true);
    }
    setState(() => _loading = false);
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(title: Text(tr('change_password_title'))),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                SizedBox(height: 20),

                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    gradient: AppTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.4), blurRadius: 20)],
                  ),
                  child: Center(child: SvgPicture.string(AppSvgIcons.lock, width: 40, height: 40,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))),
                ),
                SizedBox(height: 16),
                Text(tr('account_security'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 16,
                    color: Colors.white, letterSpacing: 2)),
                SizedBox(height: 6),
                Text(tr('update_password_hint'),
                    style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted)),
                SizedBox(height: 36),

                Container(
                  decoration: BoxDecoration(
                    gradient: AppTheme.cardGradient,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      _buildField('Password Lama', _oldPassCtrl, _obscureOld,
                          () => setState(() => _obscureOld = !_obscureOld)),
                      SizedBox(height: 16),
                      _buildField('Password Baru', _newPassCtrl, _obscureNew,
                          () => setState(() => _obscureNew = !_obscureNew)),
                      SizedBox(height: 16),
                      _buildField('Konfirmasi Password', _confirmCtrl, _obscureConfirm,
                          () => setState(() => _obscureConfirm = !_obscureConfirm)),
                      SizedBox(height: 28),

                      SizedBox(
                        width: double.infinity,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.5),
                                blurRadius: 15, offset: const Offset(0, 4))],
                          ),
                          child: ElevatedButton(
                            onPressed: _loading ? null : _changePassword,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                            child: _loading
                                ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : Text(tr('save_changes'), style: TextStyle(fontFamily: 'Orbitron',
                                    fontWeight: FontWeight.bold, letterSpacing: 2, fontSize: 12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl, bool obscure, VoidCallback toggle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
            color: AppTheme.textMuted, letterSpacing: 2)),
        SizedBox(height: 6),
        TextFormField(
          controller: ctrl,
          obscureText: obscure,
          style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono'),
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.all(12),
              child: SvgPicture.string(AppSvgIcons.lock, width: 18, height: 18,
                  colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
            ),
            suffixIcon: IconButton(
              onPressed: toggle,
              icon: SvgPicture.string(obscure ? AppSvgIcons.eyeOff : AppSvgIcons.eye,
                  width: 18, height: 18,
                  colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
            ),
          ),
        ),
      ],
    );
  }
}