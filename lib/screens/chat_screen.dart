import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';

class ChatScreen extends StatefulWidget {
  final String room;
  final Map<String, dynamic>? dmTarget; // null = grup
  final String myId;
  final String myName;
  final String myAvatar;

  const ChatScreen({
    super.key,
    required this.room,
    this.dmTarget,
    required this.myId,
    required this.myName,
    required this.myAvatar,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl    = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _picker     = ImagePicker();

  List<Map<String, dynamic>> _messages = [];
  bool _loading  = false;
  bool _sending  = false;
  Map<String, dynamic>? _replyTo;
  Timer? _pollTimer;

  bool get _isGroup => widget.dmTarget == null;

  @override
  void initState() {
    super.initState();
    _fetchMessages();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted) _fetchMessages(silent: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  Future<String?> _getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  Future<void> _fetchMessages({bool silent = false}) async {
    if (!silent && mounted) setState(() => _loading = true);
    try {
      final token = await _getToken();
      final res = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/chat/messages?room=${widget.room}&limit=80'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final json = jsonDecode(res.body);
      if (json['success'] == true && mounted) {
        final newMsgs = List<Map<String, dynamic>>.from(json['messages']);
        final changed = newMsgs.length != _messages.length;
        setState(() => _messages = newMsgs);
        if (changed) _scrollToBottom();
      }
    } catch (_) {}
    if (!silent && mounted) setState(() => _loading = false);
  }

  Future<void> _sendMessage({String? mediaBase64, String? mediaType}) async {
    final text = _msgCtrl.text.trim();
    if (text.isEmpty && mediaBase64 == null) return;
    setState(() => _sending = true);
    try {
      final token = await _getToken();
      final body = <String, dynamic>{
        'room': widget.room,
        if (text.isNotEmpty) 'text': text,
        if (_replyTo != null) 'replyTo': _replyTo!['id'],
        if (mediaBase64 != null) 'mediaBase64': mediaBase64,
        if (mediaType != null) 'mediaType': mediaType,
      };
      await http.post(
        Uri.parse('${ApiService.baseUrl}/api/chat/send'),
        headers: {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      _msgCtrl.clear();
      setState(() => _replyTo = null);
      await _fetchMessages(silent: true);
      _scrollToBottom();
    } catch (_) {}
    setState(() => _sending = false);
  }

  Future<void> _pickAndSendImage() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked == null) return;
    final bytes  = await File(picked.path).readAsBytes();
    final b64    = base64Encode(bytes);
    await _sendMessage(mediaBase64: b64, mediaType: 'image');
  }

  Future<void> _deleteMessage(String id) async {
    try {
      final token = await _getToken();
      await http.delete(
        Uri.parse('${ApiService.baseUrl}/api/chat/messages/$id'),
        headers: {'Authorization': 'Bearer $token'},
      );
      await _fetchMessages(silent: true);
    } catch (_) {}
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Map<String, dynamic>? _findReplyMsg(String? id) {
    if (id == null) return null;
    try { return _messages.firstWhere((m) => m['id'] == id); } catch (_) { return null; }
  }

  Widget _buildAvatar(String? avatar, String name, double size) {
    if (avatar != null && avatar.isNotEmpty) {
      try {
        return ClipOval(child: Image.memory(base64Decode(avatar), width: size, height: size, fit: BoxFit.cover));
      } catch (_) {}
    }
    return Container(
      width: size, height: size,
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
      child: Center(child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: TextStyle(fontFamily: 'Orbitron', fontSize: size * 0.4,
            color: Colors.white, fontWeight: FontWeight.bold),
      )),
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
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: AppTheme.cardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(children: [
          if (_isGroup)
            ClipOval(
              child: Image.asset('assets/icons/grup.jpg', width: 36, height: 36, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 36, height: 36,
                    decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppTheme.primaryGradient),
                    child: const Icon(Icons.group_rounded, color: Colors.white, size: 20),
                  )),
            )
          else
            _buildAvatar(widget.dmTarget!['avatar'] as String?, widget.dmTarget!['username'] as String? ?? 'U', 36),
          SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
              _isGroup ? 'PEGASUS-X ROOM' : (widget.dmTarget!['username'] as String? ?? ''),
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                  fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.8),
            ),
            Text(
              _isGroup ? 'Grup Chat' : 'Pesan Langsung',
              style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted),
            ),
          ]),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: AppTheme.primaryBlue.withOpacity(0.3)),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: _loading
                ? Center(child: CircularProgressIndicator(color: AppTheme.primaryBlue))
                : RefreshIndicator(
                    color: AppTheme.primaryBlue,
                    backgroundColor: AppTheme.cardBg,
                    onRefresh: _fetchMessages,
                    child: _messages.isEmpty
                        ? ListView(children: [_buildEmptyState()])
                        : ListView.builder(
                            controller: _scrollCtrl,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _messages.length,
                            itemBuilder: (ctx, i) => _buildBubble(_messages[i]),
                          ),
                  ),
          ),
        ),
        if (_replyTo != null) _buildReplyPreview(),
        _buildInputBar(),
      ]),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(height: 80),
        Icon(Icons.chat_bubble_outline_rounded, size: 60, color: AppTheme.primaryBlue.withOpacity(0.3)),
        SizedBox(height: 12),
        Text(tr('no_messages'), style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted, fontSize: 12)),
        Text(tr('send_first'), style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted, fontSize: 10)),
      ]),
    );
  }

  Widget _buildBubble(Map<String, dynamic> msg) {
    final isMe      = msg['senderId'] == widget.myId;
    final avatar    = msg['senderAvatar'] as String?;
    final name      = msg['senderName'] as String? ?? 'Unknown';
    final role      = msg['senderRole'] as String? ?? 'member';
    final text      = msg['text'] as String?;
    final media     = msg['mediaBase64'] as String?;
    final mediaType = msg['mediaType'] as String?;
    final replyMsg  = _findReplyMsg(msg['replyTo'] as String?);

    final time = () {
      try {
        final dt = DateTime.parse(msg['createdAt'] as String).toLocal();
        return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      } catch (_) { return ''; }
    }();

    return GestureDetector(
      onLongPress: () => _showMsgOptions(msg),
      onHorizontalDragEnd: (d) {
        if (d.primaryVelocity!.abs() > 200) setState(() => _replyTo = msg);
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!isMe) ...[
              _buildAvatar(avatar, name, 28),
              SizedBox(width: 6),
            ],
            Flexible(
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 4, bottom: 2),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text(name, style: TextStyle(fontFamily: 'Orbitron', fontSize: 9,
                            color: _roleColor(role), fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                        if (role == 'owner') ...[
                          SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(3),
                              border: Border.all(color: Colors.orange.withOpacity(0.5)),
                            ),
                            child: Text(tr('owner_label'), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 7, color: Colors.orange)),
                          ),
                        ],
                      ]),
                    ),
                  Container(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.72),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: isMe ? AppTheme.primaryGradient : null,
                      color: isMe ? null : AppTheme.cardBg,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(16),
                        topRight: const Radius.circular(16),
                        bottomLeft: Radius.circular(isMe ? 16 : 4),
                        bottomRight: Radius.circular(isMe ? 4 : 16),
                      ),
                      border: isMe ? null : Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 4)],
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      if (replyMsg != null) _buildReplyInBubble(replyMsg),
                      if (media != null && mediaType == 'image') ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(base64Decode(media), width: 200, fit: BoxFit.cover),
                        ),
                        if (text != null) SizedBox(height: 6),
                      ],
                      if (text != null)
                        Text(text, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12,
                            color: isMe ? Colors.white : Colors.white70, height: 1.4)),
                      SizedBox(height: 2),
                      Text(time, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                          color: isMe ? Colors.white54 : AppTheme.textMuted)),
                    ]),
                  ),
                ],
              ),
            ),
            if (isMe) SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildReplyInBubble(Map<String, dynamic> replied) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: const Border(left: BorderSide(color: AppTheme.accentBlue, width: 3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(replied['senderName'] ?? '', style: const TextStyle(fontFamily: 'Orbitron',
            fontSize: 9, color: AppTheme.accentBlue, fontWeight: FontWeight.bold)),
        SizedBox(height: 2),
        Text(
          replied['mediaBase64'] != null ? '📷 Foto' : (replied['text'] ?? ''),
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white54),
        ),
      ]),
    );
  }

  Widget _buildReplyPreview() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: AppTheme.cardBg,
      child: Row(children: [
        Container(width: 3, height: 36, color: AppTheme.accentBlue),
        SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Membalas ${_replyTo!['senderName']}',
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 9, color: AppTheme.accentBlue)),
          Text(
            _replyTo!['mediaBase64'] != null ? '📷 Foto' : (_replyTo!['text'] ?? ''),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted),
          ),
        ])),
        IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18),
          onPressed: () => setState(() => _replyTo = null),
        ),
      ]),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          border: Border(top: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.2))),
        ),
        child: Row(children: [
          GestureDetector(
            onTap: _pickAndSendImage,
            child: Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.image_rounded, color: AppTheme.textSecondary, size: 20),
            ),
          ),
          SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _msgCtrl,
              style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono', fontSize: 13),
              maxLines: 4, minLines: 1,
              decoration: InputDecoration(
                hintText: _isGroup ? 'Tulis Pesan...' : 'Pesan ke ${widget.dmTarget!['username']}...',
                hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 12),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.4)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: AppTheme.primaryBlue),
                ),
                filled: true,
                fillColor: AppTheme.darkBg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          SizedBox(width: 8),
          GestureDetector(
            onTap: _sending ? null : () => _sendMessage(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40, height: 40,
              decoration: BoxDecoration(
                gradient: _sending ? null : AppTheme.primaryGradient,
                color: _sending ? AppTheme.primaryBlue.withOpacity(0.3) : null,
                borderRadius: BorderRadius.circular(10),
                boxShadow: _sending ? [] : [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.4), blurRadius: 8)],
              ),
              child: _sending
                  ? Padding(padding: EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.send_rounded, color: Colors.white, size: 20),
            ),
          ),
        ]),
      ),
    );
  }

  void _showMsgOptions(Map<String, dynamic> msg) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardBg,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4, margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(color: AppTheme.textMuted, borderRadius: BorderRadius.circular(2))),
          ListTile(
            leading: const Icon(Icons.reply_rounded, color: AppTheme.accentBlue),
            title: Text(tr('reply_to'), style: TextStyle(fontFamily: 'ShareTechMono', color: Colors.white)),
            onTap: () { Navigator.pop(context); setState(() => _replyTo = msg); },
          ),
          if (msg['senderId'] == widget.myId)
            ListTile(
              leading: const Icon(Icons.delete_rounded, color: Colors.red),
              title: Text(tr('delete_msg'), style: TextStyle(fontFamily: 'ShareTechMono', color: Colors.white)),
              onTap: () { Navigator.pop(context); _deleteMessage(msg['id'] as String); },
            ),
        ]),
      ),
    );
  }
}
