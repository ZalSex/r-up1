import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/app_localizations.dart';
import '../utils/role_style.dart';
import '../services/api_service.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  List<Map<String, dynamic>> _users    = [];
  List<Map<String, dynamic>> _filtered = [];
  List<String> _bannedUsernames        = [];
  bool _loading      = true;
  bool _loadingBan   = false;
  final _searchCtrl  = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadUsers();
    _loadBanned();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadUsers() async {
    setState(() => _loading = true);
    try {
      final res = await ApiService.ownerGetAllUsers();
      if (res['success'] == true && mounted) {
        final users = List<Map<String, dynamic>>.from(res['users'] ?? []);
        setState(() {
          _users    = users;
          _filtered = users;
          _loading  = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadBanned() async {
    try {
      final res = await ApiService.ownerGetBanned();
      if (res['success'] == true && mounted) {
        setState(() {
          _bannedUsernames = List<String>.from(res['banned']?['usernames'] ?? []);
        });
      }
    } catch (_) {}
  }

  void _filter() {
    final q = _searchCtrl.text.toLowerCase().trim();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              return (u['username'] ?? '').toLowerCase().contains(q) ||
                  (u['telegramId'] ?? '').toString().contains(q);
            }).toList();
    });
  }

  Future<void> _banUser(Map<String, dynamic> user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.red.withOpacity(0.5)),
        ),
        title: Text(tr('ban_delete_user'),
            style: TextStyle(fontFamily: 'Orbitron', color: Colors.red, fontSize: 13, letterSpacing: 1)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Username: ${user['username']}',
                style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 12)),
            SizedBox(height: 8),
            const Text(
              'Akun akan DIHAPUS PERMANEN dan username/telegramId akan di-blacklist. User tidak bisa buat akun lagi.',
              style: TextStyle(fontFamily: 'ShareTechMono', color: Colors.redAccent, fontSize: 11, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 11))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(tr('ban_delete_btn'), style: TextStyle(fontFamily: 'Orbitron', color: Colors.red, fontSize: 11))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await ApiService.ownerBanUser(user['id'] as String);
      if (res['success'] == true) {
        _snack('User ${user["username"]} berhasil dibanned & dihapus', isSuccess: true);
        _loadUsers();
        _loadBanned();
      } else {
        _snack(res['message'] ?? 'Gagal ban user', isError: true);
      }
    } catch (e) {
      _snack('$e', isError: true);
    }
  }

  Future<void> _unbanUsername(String username) async {
    try {
      final res = await ApiService.ownerUnban(username: username);
      if (res['success'] == true) {
        _snack('$username berhasil diunban', isSuccess: true);
        _loadBanned();
      } else {
        _snack(res['message'] ?? 'Gagal unban', isError: true);
      }
    } catch (e) {
      _snack('$e', isError: true);
    }
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
            Text(tr('manage_users_title'),
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold,
                    color: Colors.white, letterSpacing: 2)),
          ]),
          actions: [
            IconButton(
              onPressed: () { _loadUsers(); _loadBanned(); },
              icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(49),
            child: Column(
              children: [
                Container(height: 1, color: AppTheme.primaryBlue.withOpacity(0.25)),
                TabBar(
                  controller: _tabCtrl,
                  indicatorColor: AppTheme.primaryBlue,
                  labelColor: Colors.white,
                  unselectedLabelColor: AppTheme.textMuted,
                  labelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, letterSpacing: 1),
                  tabs: [
                    Tab(text: 'AKTIF'),
                    Tab(text: 'BANNED (${_bannedUsernames.length})'),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _buildActiveTab(),
            _buildBannedTab(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.cardBg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
            ),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Cari username...',
                hintStyle: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted, fontSize: 12),
                prefixIcon: const Icon(Icons.search, color: AppTheme.textMuted, size: 18),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ),
        Expanded(
          child: _loading
              ? Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2))
              : _filtered.isEmpty
                  ? Center(child: Text(tr('no_user'),
                      style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted, fontSize: 12)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _filtered.length,
                      itemBuilder: (_, i) => _buildUserCard(_filtered[i]),
                    ),
        ),
      ],
    );
  }

  Widget _buildBannedTab() {
    return _loadingBan
        ? Center(child: CircularProgressIndicator(color: Colors.red, strokeWidth: 2))
        : _bannedUsernames.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.green.withOpacity(0.4), size: 48),
                    SizedBox(height: 12),
                    Text(tr('no_banned'),
                        style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted, fontSize: 12)),
                  ],
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _bannedUsernames.length,
                itemBuilder: (_, i) => _buildBannedCard(_bannedUsernames[i]),
              );
  }

  Widget _buildBannedCard(String username) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.block, color: Colors.red, size: 18),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(username,
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 0.5)),
          ),
          GestureDetector(
            onTap: () => _unbanUsername(username),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.green.withOpacity(0.4)),
              ),
              child: Text(tr('unban_user'),
                  style: TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: Colors.green, letterSpacing: 1)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user) {
    final role       = user['role'] ?? 'member';
    final expiredAt  = user['expiredAt'] as String?;
    final isExpired  = expiredAt != null && DateTime.tryParse(expiredAt)?.isBefore(DateTime.now()) == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: AppTheme.primaryBlue.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
            ),
            child: Center(child: Icon(Icons.person, color: AppTheme.textSecondary, size: 20)),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(user['username'] ?? '-',
                  style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, letterSpacing: 1)),
              SizedBox(height: 4),
              Row(children: [
                RoleStyle.roleBadge(role),
                if (expiredAt != null) ...[
                  SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: isExpired ? Colors.red.withOpacity(0.2) : Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: isExpired ? Colors.red.withOpacity(0.4) : Colors.orange.withOpacity(0.4)),
                    ),
                    child: Text(
                      isExpired ? 'EXPIRED' : 'EXP: ${_formatExp(expiredAt)}',
                      style: TextStyle(
                        fontFamily: 'ShareTechMono', fontSize: 8,
                        color: isExpired ? Colors.red : Colors.orange, letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
              ]),
              if ((user['senderCount'] ?? 0) > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text('${user['senderCount']} sender',
                      style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
                ),
            ]),
          ),
          if (role != 'owner')
            GestureDetector(
              onTap: () => _banUser(user),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.4)),
                ),
                child: Text(tr('ban_user'),
                    style: TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: Colors.red, letterSpacing: 1)),
              ),
            ),
        ],
      ),
    );
  }

  String _formatExp(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return '${dt.day}/${dt.month}/${dt.year}';
    } catch (_) {
      return iso;
    }
  }
}

class ManageUsersBody extends StatelessWidget {
  const ManageUsersBody({super.key});

  @override
  Widget build(BuildContext context) => const ManageUsersScreen();
}
