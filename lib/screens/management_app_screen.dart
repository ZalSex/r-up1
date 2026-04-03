import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/app_localizations.dart';
import '../screens/owner_management_screen.dart';
import '../screens/manage_users_screen.dart';
import '../services/api_service.dart';

class ManagementAppScreen extends StatefulWidget {
  const ManagementAppScreen({super.key});

  @override
  State<ManagementAppScreen> createState() => _ManagementAppScreenState();
}

class _ManagementAppScreenState extends State<ManagementAppScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBg,
          elevation: 0,
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
            SizedBox(width: 10),
            Text(tr('management_app'),
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          ]),
          bottom: TabBar(
            controller: _tabCtrl,
            indicatorColor: AppTheme.accentBlue,
            indicatorWeight: 2,
            labelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, letterSpacing: 1),
            unselectedLabelColor: AppTheme.textMuted,
            labelColor: AppTheme.accentBlue,
            tabs: [
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.string(AppSvgIcons.mobile, width: 14, height: 14,
                      colorFilter: const ColorFilter.mode(AppTheme.accentBlue, BlendMode.srcIn)),
                  SizedBox(width: 6),
                  Text(tr('manage_sender')),
                ]),
              ),
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.string(AppSvgIcons.manage, width: 14, height: 14,
                      colorFilter: const ColorFilter.mode(AppTheme.accentBlue, BlendMode.srcIn)),
                  SizedBox(width: 6),
                  Text(tr('manage_users')),
                ]),
              ),
              Tab(
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Icon(Icons.block_rounded, size: 14, color: AppTheme.accentBlue),
                  SizedBox(width: 6),
                  Text('BANNED'),
                ]),
              ),
            ],
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: const [
            OwnerManagementBody(),
            ManageUsersBody(),
            BannedPhonesBody(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNED PHONES BODY
// ─────────────────────────────────────────────────────────────────────────────
class BannedPhonesBody extends StatefulWidget {
  const BannedPhonesBody({super.key});

  @override
  State<BannedPhonesBody> createState() => _BannedPhonesBodyState();
}

class _BannedPhonesBodyState extends State<BannedPhonesBody> {
  List<String> _bannedPhones = [];
  bool _loading = true;
  final TextEditingController _phoneCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBanned();
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBanned() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.ownerGetBannedPhones();
      if (mounted) {
        setState(() {
          _bannedPhones = List<String>.from(res['phones'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _banPhone(String phone) async {
    final normalised = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (normalised.isEmpty) return;
    try {
      final res = await ApiService.ownerBanPhone(normalised);
      if (mounted) {
        if (res['success'] == true) {
          showSuccess(context, res['message'] ?? 'Berhasil di-ban');
          _phoneCtrl.clear();
          _loadBanned();
        } else {
          showError(context, res['message'] ?? 'Gagal');
        }
      }
    } catch (e) {
      showError(context, 'Error: $e');
    }
  }

  Future<void> _unbanPhone(String phone) async {
    try {
      final res = await ApiService.ownerUnbanPhone(phone);
      if (mounted) {
        if (res['success'] == true) {
          showSuccess(context, res['message'] ?? 'Berhasil di-unban');
          _loadBanned();
        } else {
          showError(context, res['message'] ?? 'Gagal');
        }
      }
    } catch (e) {
      showError(context, 'Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // ── Input ban nomer baru ──
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Row(children: [
          Expanded(
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: AppTheme.darkBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.4)),
              ),
              child: TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white),
                decoration: const InputDecoration(
                  hintText: '628xxxxxxxxxx',
                  hintStyle: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _banPhone(_phoneCtrl.text.trim()),
            child: Container(
              height: 44,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.withOpacity(0.5)),
              ),
              child: const Center(
                child: Text('BAN', style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 11, color: Colors.red, letterSpacing: 1)),
              ),
            ),
          ),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Row(children: [
          const Icon(Icons.block_rounded, color: Colors.red, size: 13),
          const SizedBox(width: 6),
          Text('${_bannedPhones.length} Nomor Dibanned',
              style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted)),
          const Spacer(),
          GestureDetector(
            onTap: _loadBanned,
            child: const Icon(Icons.refresh, color: AppTheme.textMuted, size: 18),
          ),
        ]),
      ),
      const Divider(color: AppTheme.cardBg, height: 1),
      // ── List banned phones ──
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Colors.red))
            : _bannedPhones.isEmpty
                ? Center(
                    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      Icon(Icons.check_circle_outline_rounded, color: Colors.green.withOpacity(0.4), size: 48),
                      const SizedBox(height: 12),
                      const Text('Tidak Ada Nomor Yang Dibanned',
                          style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted, fontSize: 12)),
                    ]),
                  )
                : RefreshIndicator(
                    onRefresh: _loadBanned,
                    color: Colors.red,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _bannedPhones.length,
                      itemBuilder: (_, i) {
                        final phone = _bannedPhones[i];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.red.withOpacity(0.3)),
                            gradient: LinearGradient(
                              colors: [Colors.red.withOpacity(0.08), AppTheme.cardBg],
                              begin: Alignment.centerLeft, end: Alignment.centerRight,
                            ),
                          ),
                          child: Row(children: [
                            Container(
                              width: 36, height: 36,
                              decoration: BoxDecoration(
                                color: Colors.red.withOpacity(0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.red.withOpacity(0.4)),
                              ),
                              child: const Center(child: Icon(Icons.block_rounded, color: Colors.red, size: 18)),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text('+$phone',
                                  style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                                      color: Colors.white, letterSpacing: 1)),
                            ),
                            GestureDetector(
                              onTap: () => _unbanPhone(phone),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.green.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.green.withOpacity(0.4)),
                                ),
                                child: const Text('UNBAN', style: TextStyle(
                                    fontFamily: 'Orbitron', fontSize: 9, color: Colors.green, letterSpacing: 1)),
                              ),
                            ),
                          ]),
                        );
                      },
                    ),
                  ),
      ),
    ]);
  }
}

