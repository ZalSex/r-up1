import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../services/heartbeat_service.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import 'chat_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  List<Map<String, dynamic>> _users = [];
  String _myId     = '';
  String _myName   = '';
  String _myAvatar = '';
  bool   _loading  = true;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _loadProfile().then((_) {
      if (mounted) _fetchUsers();
    });
    _refreshTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (mounted) _fetchUsers();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _myId     = prefs.getString('user_id') ?? '';
      _myName   = prefs.getString('username') ?? '';
      _myAvatar = prefs.getString('avatar') ?? '';
    });
    final res = await ApiService.getProfile();
    if (res['success'] == true && mounted) {
      setState(() {
        _myId     = res['user']['id']       ?? _myId;
        _myName   = res['user']['username'] ?? _myName;
        _myAvatar = res['user']['avatar']   ?? _myAvatar;
      });
    }
  }

  Future<void> _fetchUsers() async {
    HeartbeatService.instance.start();
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('auth_token');
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/chat/users'),
        headers: {'Authorization': 'Bearer $token'},
      );
      if (!mounted) return;
      final json = jsonDecode(res.body);
      if (json['success'] != true) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      final users = List<Map<String, dynamic>>.from(json['users']);
      // Sort: online dulu, lalu A-Z
      users.sort((a, b) {
        final aOnline = (a['isOnline'] == true) ? 0 : 1;
        final bOnline = (b['isOnline'] == true) ? 0 : 1;
        if (aOnline != bOnline) return aOnline.compareTo(bOnline);
        return (a['username'] as String? ?? '').toLowerCase()
            .compareTo((b['username'] as String? ?? '').toLowerCase());
      });
      setState(() {
        _users   = users;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _openGroupChat() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          room: 'global',
          dmTarget: null,
          myId: _myId,
          myName: _myName,
          myAvatar: _myAvatar,
        ),
      ),
    );
  }

  Widget _buildAvatar(String? avatar, String name, double size) {
    if (avatar != null && avatar.isNotEmpty) {
      try {
        return ClipOval(
          child: Image.memory(base64Decode(avatar), width: size, height: size, fit: BoxFit.cover),
        );
      } catch (_) {}
    }
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
      child: Center(
        child: Text(
          name.isNotEmpty ? name[0].toUpperCase() : '?',
          style: TextStyle(fontFamily: 'Orbitron', fontSize: size * 0.4,
              color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Color _roleColor(String role) {
    switch (role) {
      case 'owner':   return Colors.orange;
      case 'premium': return const Color(0xFF82B1FF);
      case 'vip':     return const Color(0xFFFFD54F);
      default:        return AppTheme.accentBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final onlineCount = _users.where((u) => u['isOnline'] == true).length;

    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: AppTheme.cardBg,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            tr('msg_screen_title'),
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16,
                fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 3),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded, color: AppTheme.accentBlue, size: 20),
              onPressed: () {
                setState(() => _loading = true);
                _fetchUsers();
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: AppTheme.primaryBlue.withOpacity(0.3)),
          ),
        ),
        body: _loading
            ? Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
            : RefreshIndicator(
                color: AppTheme.primaryBlue,
                backgroundColor: AppTheme.cardBg,
                onRefresh: _fetchUsers,
                child: CustomScrollView(
                  slivers: [
                    // ─── GRUP GLOBAL ───
                    SliverToBoxAdapter(child: _buildGroupTile(onlineCount)),
                    SliverToBoxAdapter(child: SizedBox(height: 8)),
                    // ─── HEADER ANGGOTA ───
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                        child: Row(children: [
                          Icon(Icons.people_rounded, size: 12,
                              color: AppTheme.accentBlue.withOpacity(0.7)),
                          SizedBox(width: 6),
                          Text(
                            '${_users.length} ANGGOTA · $onlineCount ONLINE',
                            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                                color: AppTheme.accentBlue.withOpacity(0.7), letterSpacing: 2),
                          ),
                        ]),
                      ),
                    ),
                    // ─── LIST ANGGOTA ───
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (ctx, i) => _buildMemberTile(_users[i]),
                        childCount: _users.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: SizedBox(height: 80)),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildGroupTile(int onlineCount) {
    return InkWell(
      onTap: _openGroupChat,
      splashColor: AppTheme.primaryBlue.withOpacity(0.1),
      highlightColor: AppTheme.primaryBlue.withOpacity(0.05),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2))),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                Container(
                  width: 54, height: 54,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppTheme.accentBlue.withOpacity(0.6), width: 2),
                    boxShadow: [BoxShadow(color: AppTheme.accentBlue.withOpacity(0.2), blurRadius: 8)],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icons/grup.jpg',
                      width: 54, height: 54, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.primaryGradient,
                        ),
                        child: const Icon(Icons.group_rounded, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppTheme.darkBg, width: 1.5),
                    ),
                    child: Text('$onlineCount',
                        style: const TextStyle(fontFamily: 'ShareTechMono',
                            fontSize: 8, color: Colors.white, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('PEGASUS-X ROOM',
                          style: TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                              fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withOpacity(0.25),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppTheme.accentBlue.withOpacity(0.4)),
                        ),
                        child: Text(tr('group_label'),
                            style: const TextStyle(fontFamily: 'ShareTechMono',
                                fontSize: 8, color: AppTheme.accentBlue, letterSpacing: 1)),
                      ),
                    ],
                  ),
                  SizedBox(height: 5),
                  Text('${_users.length} anggota · $onlineCount online',
                      style: const TextStyle(fontFamily: 'ShareTechMono',
                          fontSize: 11, color: AppTheme.textMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberTile(Map<String, dynamic> u) {
    final name     = u['username'] as String? ?? '?';
    final role     = u['role']     as String? ?? 'member';
    final avatar   = u['avatar']   as String?;
    final isOnline = u['isOnline'] == true;
    final isMe     = u['id'] == _myId;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.04))),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              _buildAvatar(avatar, name, 44),
              Positioned(
                right: 1, bottom: 1,
                child: Container(
                  width: 11, height: 11,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isOnline ? Colors.greenAccent : Colors.grey.shade700,
                    border: Border.all(color: AppTheme.darkBg, width: 2),
                    boxShadow: isOnline
                        ? [BoxShadow(color: Colors.greenAccent.withOpacity(0.5), blurRadius: 4)]
                        : [],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(width: 12),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    isMe ? '$name (Kamu)' : name,
                    style: TextStyle(
                      fontFamily: 'Orbitron', fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isMe ? AppTheme.textMuted : Colors.white,
                      letterSpacing: 0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _roleColor(role).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: _roleColor(role).withOpacity(0.4)),
                  ),
                  child: Text(role.toUpperCase(),
                      style: TextStyle(fontFamily: 'ShareTechMono',
                          fontSize: 8, color: _roleColor(role), letterSpacing: 1)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
