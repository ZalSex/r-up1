import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../../utils/app_localizations.dart';
import '../../services/api_service.dart';

class OwnerManagementScreen extends StatefulWidget {
  const OwnerManagementScreen({super.key});

  @override
  State<OwnerManagementScreen> createState() => _OwnerManagementScreenState();
}

class _OwnerManagementScreenState extends State<OwnerManagementScreen> {
  List<Map<String, dynamic>> _senders = [];
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final sendersRes = await ApiService.ownerGetAllSenders();
      final usersRes   = await ApiService.ownerGetAllUsers();
      if (mounted) {
        setState(() {
          final allSenders = List<Map<String, dynamic>>.from(sendersRes['senders'] ?? []);
          _senders = allSenders.where((s) {
            final type = (s['type'] ?? '').toString().toLowerCase();
            final status = (s['status'] ?? '').toString().toLowerCase();
            return type != 'spam_pairing' && status != 'spam_pairing';
          }).toList();
          _users   = List<Map<String, dynamic>>.from(usersRes['users'] ?? []);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSession(Map<String, dynamic> sender) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: Colors.red.withOpacity(0.4))),
        title: Text(tr('delete_session'),
            style: TextStyle(fontFamily: 'Orbitron', color: Colors.red, fontSize: 13, letterSpacing: 1)),
        content: Text('Hapus session ${sender['phone'] ?? sender['id']}? Sender akan disconnect.',
            style: const TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textSecondary, fontSize: 12)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: const Text('Batal', style: TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 11))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: Text(tr('delete_msg'), style: TextStyle(fontFamily: 'Orbitron', color: Colors.red, fontSize: 11))),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      final res = await ApiService.ownerDeleteSession(sender['id'] as String);
      if (mounted) {
        if (res['success'] == true) {
          showSuccess(context, 'Session berhasil dihapus');
          _loadData();
        } else {
          showError(context, res['message'] ?? 'Gagal');
        }
      }
    } catch (e) {
      showError(context, 'Error: $e');
    }
  }

  void _showTransferDialog(Map<String, dynamic> sender) {
    String? selectedUserId;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDState) => AlertDialog(
          backgroundColor: AppTheme.cardBg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.orange.withOpacity(0.5)),
          ),
          title: const Text(
            'Pindah Sender',
            style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 14, letterSpacing: 1),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Sender: ${sender['phone'] ?? sender['id']}',
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textSecondary),
              ),
              Text(
                'Pemilik Sekarang: ${sender['ownerUsername'] ?? '-'}',
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted),
              ),
              SizedBox(height: 16),
              const Text(
                'Pilih User Tujuan:',
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textSecondary),
              ),
              SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10),
                  color: AppTheme.darkBg,
                ),
                child: DropdownButton<String>(
                  value: selectedUserId,
                  isExpanded: true,
                  dropdownColor: AppTheme.cardBg,
                  hint: Text(tr('pick_user'), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted)),
                  underline: SizedBox(),
                  items: _users.map((u) {
                    return DropdownMenuItem<String>(
                      value: u['id'] as String,
                      child: Text(
                        '${u['username']} (${u['role']}) — ${u['senderCount']} Sender',
                        style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white),
                      ),
                    );
                  }).toList(),
                  onChanged: (val) => setDState(() => selectedUserId = val),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(tr('cancel'), style: const TextStyle(fontFamily: 'Orbitron', color: AppTheme.textMuted, fontSize: 11)),
            ),
            TextButton(
              onPressed: selectedUserId == null
                  ? null
                  : () async {
                      Navigator.pop(ctx);
                      await _transferSender(sender['id'], selectedUserId!);
                    },
              child: Text(tr('move_sender'), style: TextStyle(fontFamily: 'Orbitron', color: Colors.orange, fontSize: 11)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _transferSender(String senderId, String targetUserId) async {
    try {
      final res = await ApiService.ownerTransferSender(senderId, targetUserId);
      if (mounted) {
        if (res['success'] == true) {
          showSuccess(context, res['message'] ?? 'Berhasil memindah sender');
          _loadData();
        } else {
          showError(context, res['message'] ?? 'Gagal Memindah Sender');
        }
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Error: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        centerTitle: true,
        title: const Text(
          'MANAGEMENT SENDER',
          style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 15, fontWeight: FontWeight.bold,
            color: Colors.orange, letterSpacing: 2,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: AppTheme.textSecondary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 20),
            onPressed: _loadData,
          ),
          SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: Colors.orange.withOpacity(0.2)),
        ),
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: Colors.orange))
          : _senders.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SvgPicture.string(
                        '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>''',
                        width: 48, height: 48,
                        colorFilter: ColorFilter.mode(Colors.orange.withOpacity(0.3), BlendMode.srcIn),
                      ),
                      SizedBox(height: 16),
                      Text(tr('no_sender_registered'),
                          style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: Colors.orange,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _senders.length,
                    itemBuilder: (_, i) => _buildSenderCard(_senders[i]),
                  ),
                ),
    );
  }

  Widget _buildSenderCard(Map<String, dynamic> sender) {
    final isOnline = (sender['status'] ?? '') == 'online';
    final statusColor = isOnline ? Colors.green : Colors.red.shade400;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.cardBg, AppTheme.darkBg],
          begin: Alignment.topLeft, end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle, color: statusColor,
                boxShadow: [BoxShadow(color: statusColor.withOpacity(0.5), blurRadius: 6)],
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sender['phone'] ?? sender['id'] ?? '-',
                    style: const TextStyle(
                      fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      SvgPicture.string(AppSvgIcons.user, width: 11, height: 11,
                          colorFilter: const ColorFilter.mode(AppTheme.textMuted, BlendMode.srcIn)),
                      SizedBox(width: 4),
                      Text(
                        sender['ownerUsername'] ?? '-',
                        style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted),
                      ),
                      SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: statusColor.withOpacity(0.4)),
                        ),
                        child: Text(
                          (sender['status'] ?? 'offline').toUpperCase(),
                          style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: statusColor, letterSpacing: 1),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () => _showTransferDialog(sender),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.4)),
                    ),
                    child: Text(tr('take_sender'),
                        style: TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: Colors.orange, letterSpacing: 1)),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _deleteSession(sender),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.red.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withOpacity(0.4)),
                    ),
                    child: Text(tr('delete_msg'),
                        style: TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: Colors.red, letterSpacing: 1)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Body-only widget untuk digunakan dalam tab (tanpa Scaffold)
class OwnerManagementBody extends StatelessWidget {
  const OwnerManagementBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const OwnerManagementScreen();
  }
}
