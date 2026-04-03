import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/app_localizations.dart';
import '../services/api_service.dart';

class WaCallScreen extends StatefulWidget {
  const WaCallScreen({super.key});
  @override
  State<WaCallScreen> createState() => _WaCallScreenState();
}

class _WaCallScreenState extends State<WaCallScreen> {
  String? _selectedSenderId;
  String? _selectedSenderPhone;
  List<Map<String, dynamic>> _senders = [];
  bool _loadingSenders = false;

  final _targetCtrl = TextEditingController();
  final _countCtrl  = TextEditingController(text: '1');
  double _delay = 2.0;
  int _callType = 0;

  bool   _running  = false;
  String? _jobId;
  Timer? _pollTimer;
  int    _progress = 0;
  int    _total    = 0;
  bool   _done     = false;
  String _error    = '';

  static const _blue  = AppTheme.primaryBlue;
  static const _red   = Color(0xFFEF4444);
  static const _green = Color(0xFF10B981);

  @override
  void initState() {
    super.initState();
    _loadSenders();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _targetCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSenders() async {
    if (_loadingSenders) return;
    setState(() => _loadingSenders = true);
    try {
      final res = await ApiService.getSenders();
      if (res['success'] == true && mounted) {
        setState(() => _senders = List<Map<String, dynamic>>.from(res['senders'] ?? [])
            .where((s) => s['status'] == 'online' || s['status'] == 'connected').toList());
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSenders = false);
  }

  Future<void> _start() async {
    if (_selectedSenderId == null) { _snack(tr('pick_sender')); return; }
    if (_targetCtrl.text.isEmpty) { _snack('Masukkan Nomor Target'); return; }
    final count = int.tryParse(_countCtrl.text) ?? 1;
    if (count < 1 || count > 999) { _snack('Jumlah 1–999'); return; }

    setState(() { _running = true; _done = false; _progress = 0; _total = count; _error = ''; });

    try {
      final res = await ApiService.post('/api/wacall/start', {
        'senderId': _selectedSenderId,
        'target':   _targetCtrl.text.trim(),
        'type':     _callType == 0 ? 'voice' : 'video',
        'jumlah':   count,
        'delay':    _delay,
      });
      if (res['success'] == true) {
        _jobId = res['jobId'] as String?;
        _snack('WhatsApp Call Dimulai', isSuccess: true);
        _startPoll();
      } else {
        setState(() => _running = false);
        _snack(res['message'] ?? 'Gagal', isError: true);
      }
    } catch (_) {
      setState(() => _running = false);
      _snack('Koneksi Gagal', isError: true);
    }
  }

  void _startPoll() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      if (_jobId == null || !mounted) return;
      try {
        final prefs = await SharedPreferences.getInstance();
        final token = prefs.getString('auth_token') ?? '';
        final r = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/wacall/status/$_jobId'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));
        final json = jsonDecode(r.body);
        if (!mounted) return;
        setState(() {
          _progress = json['progress'] ?? _progress;
          _total    = json['total']    ?? _total;
          _done     = json['done']     ?? false;
          _error    = json['error']    ?? '';
        });
        if (_done) {
          _pollTimer?.cancel();
          setState(() => _running = false);
          _snack(_error.isNotEmpty ? 'Error: $_error' : 'Selesai $_progress/$_total Call');
        }
      } catch (_) {}
    });
  }

  Future<void> _stop() async {
    if (_jobId == null) return;
    try {
      await ApiService.post('/api/wacall/stop', {'jobId': _jobId});
      _pollTimer?.cancel();
      setState(() { _running = false; _done = true; });
      _snack('Call Dihentikan', isSuccess: true);
    } catch (_) { _snack('Gagal Menghentikan', isError: true); }
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
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          backgroundColor: AppTheme.darkBg,
          elevation: 0, pinned: true,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: _blue.withOpacity(0.4)),
                borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16)),
          ),
          title: Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Text(tr('wa_call_title'), style: TextStyle(fontFamily: 'Orbitron',
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          ]),
          actions: [
            GestureDetector(
              onTap: _loadSenders,
              child: Container(margin: const EdgeInsets.only(right: 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(border: Border.all(color: _blue.withOpacity(0.4)), borderRadius: BorderRadius.circular(8)),
                child: _loadingSenders
                  ? SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 1.5, color: _blue))
                  : const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 16)),
            ),
          ],
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _blue.withOpacity(0.25))),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _label('Tipe Call'),
              SizedBox(height: 10),
              Row(children: [
                _callTypeBtn(0, Icons.mic_rounded, 'VOICE CALL', const Color(0xFF10B981)),
                SizedBox(width: 12),
                _callTypeBtn(1, Icons.videocam_rounded, 'VIDEO CALL', const Color(0xFF3B82F6)),
              ]),

              SizedBox(height: 20),

              _label(tr('pick_sender')),
              SizedBox(height: 8),
              GestureDetector(
                onTap: _showSenderPicker,
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _selectedSenderId != null ? _blue : _blue.withOpacity(0.4))),
                  child: Row(children: [
                    Container(width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _selectedSenderId != null ? _green.withOpacity(0.15) : _blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: _selectedSenderId != null ? _green.withOpacity(0.4) : _blue.withOpacity(0.3))),
                      child: Center(child: SvgPicture.string(AppSvgIcons.phone, width: 18, height: 18,
                        colorFilter: ColorFilter.mode(_selectedSenderId != null ? _green : AppTheme.textMuted, BlendMode.srcIn)))),
                    SizedBox(width: 12),
                    Expanded(child: Text(
                      _selectedSenderId != null ? '+${_selectedSenderPhone ?? _selectedSenderId}' : 'Pilih Nomor Sender...',
                      style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 13,
                        color: _selectedSenderId != null ? Colors.white : AppTheme.textMuted))),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted),
                  ]),
                ),
              ),

              SizedBox(height: 16),

              _label('Nomor Target'),
              SizedBox(height: 8),
              TextFormField(
                controller: _targetCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono'),
                decoration: InputDecoration(
                  hintText: '628xxxxxxxxxx',
                  hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 13),
                  prefixIcon: Padding(padding: const EdgeInsets.all(12),
                    child: SvgPicture.string(AppSvgIcons.mobile, width: 18, height: 18,
                      colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn))),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _blue.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _blue, width: 1.5)),
                  filled: true, fillColor: AppTheme.cardBg, contentPadding: const EdgeInsets.all(14),
                ),
              ),

              SizedBox(height: 16),

              _buildCountDelayCard(),

              SizedBox(height: 20),

              if (_jobId != null) _buildProgress(),

              SizedBox(height: 16),

              Row(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _running ? null : _start,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: _running ? null : LinearGradient(
                          colors: _callType == 0 ? [const Color(0xFF10B981), const Color(0xFF059669)]
                              : [const Color(0xFF3B82F6), const Color(0xFF1D4ED8)]),
                        color: _running ? _blue.withOpacity(0.2) : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _running ? [] : [BoxShadow(
                          color: (_callType == 0 ? const Color(0xFF10B981) : _blue).withOpacity(0.4),
                          blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _running
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : Icon(_callType == 0 ? Icons.mic_rounded : Icons.videocam_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 10),
                        Text(_running ? 'Calling...' : _callType == 0 ? 'MULAI VOICE CALL' : 'MULAI VIDEO CALL',
                          style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11,
                            fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                      ]),
                    ),
                  ),
                ),
                if (_running) ...[
                  SizedBox(width: 12),
                  GestureDetector(
                    onTap: _stop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(color: _red.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _red.withOpacity(0.5))),
                      child: const Icon(Icons.stop_rounded, color: _red, size: 22)),
                  ),
                ],
              ]),

              SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _callTypeBtn(int idx, IconData icon, String label, Color color) => Expanded(
    child: GestureDetector(
      onTap: () => setState(() => _callType = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          gradient: _callType == idx ? LinearGradient(colors: [color.withOpacity(0.3), color.withOpacity(0.1)]) : null,
          color: _callType == idx ? null : AppTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _callType == idx ? color : _blue.withOpacity(0.3), width: _callType == idx ? 1.5 : 1),
          boxShadow: _callType == idx ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Column(children: [
          Icon(icon, color: _callType == idx ? color : AppTheme.textMuted, size: 26),
          SizedBox(height: 6),
          Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, fontWeight: FontWeight.bold,
            color: _callType == idx ? color : AppTheme.textMuted, letterSpacing: 0.5)),
        ]),
      ),
    ),
  );

  Widget _buildCountDelayCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _blue.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _label('Jumlah Call'),
        Row(children: [
          _cBtn(Icons.remove, () { final v = int.tryParse(_countCtrl.text) ?? 1; if (v > 1) setState(() => _countCtrl.text = (v-1).toString()); }),
          SizedBox(width: 8),
          SizedBox(width: 56, child: TextFormField(controller: _countCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
            decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _blue.withOpacity(0.4))),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _blue)),
              filled: true, fillColor: _blue.withOpacity(0.08)))),
          SizedBox(width: 8),
          _cBtn(Icons.add, () { final v = int.tryParse(_countCtrl.text) ?? 1; if (v < 999) setState(() => _countCtrl.text = (v+1).toString()); }, isAdd: true),
        ]),
      ]),
      SizedBox(height: 20),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        _label('Delay Antar Call'),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(6)),
          child: Text('${_delay.toStringAsFixed(1)}s', style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
      ]),
      SizedBox(height: 8),
      SliderTheme(data: SliderTheme.of(context).copyWith(
          activeTrackColor: _blue, inactiveTrackColor: _blue.withOpacity(0.2),
          thumbColor: Colors.white, trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
        child: Slider(value: _delay, min: 0.5, max: 30, divisions: 59, onChanged: (v) => setState(() => _delay = v))),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('0.5s', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
        Text('30s',  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
      ]),
    ]),
  );

  Widget _buildProgress() {
    final color = _done ? (_error.isNotEmpty ? _red : _green) : _blue;
    final label = _done ? (_error.isNotEmpty ? 'Error' : 'Selesai') : 'Memanggil...';
    return Container(margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withOpacity(0.08), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: color, letterSpacing: 2, fontWeight: FontWeight.bold)),
          Text('$_progress / $_total', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: color, fontWeight: FontWeight.bold)),
        ]),
        SizedBox(height: 8),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: _total > 0 ? _progress / _total : 0,
            backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation<Color>(color), minHeight: 6)),
        if (_error.isNotEmpty) ...[
          SizedBox(height: 8),
          Text('⚠ $_error', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.redAccent)),
        ],
      ]),
    );
  }

  void _showSenderPicker() {
    showModalBottomSheet(
      context: context, backgroundColor: Colors.transparent, isScrollControlled: true,
      builder: (_) => Container(
        decoration: BoxDecoration(color: AppTheme.cardBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border.all(color: _blue.withOpacity(0.4))),
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: AppTheme.textMuted.withOpacity(0.4), borderRadius: BorderRadius.circular(2)))),
          SizedBox(height: 16),
          Text(tr('pick_sender'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, letterSpacing: 2)),
          SizedBox(height: 16),
          if (_senders.isEmpty)
            Padding(padding: EdgeInsets.all(20),
              child: Text(tr('no_sender_online'), style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted))),
          ..._senders.map((s) => GestureDetector(
            onTap: () {
              setState(() { _selectedSenderId = s['id'] as String; _selectedSenderPhone = s['phone'] ?? s['id']; });
              Navigator.pop(context);
            },
            child: Container(margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _selectedSenderId == s['id'] ? _blue : _blue.withOpacity(0.2))),
              child: Row(children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: _green)),
                SizedBox(width: 10),
                Text('+${s['phone'] ?? s['id']}', style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.white)),
              ])),
          )),
          SizedBox(height: 10),
        ]),
      ),
    );
  }

  Widget _label(String t) => Text(t, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _blue, letterSpacing: 2));
  Widget _cBtn(IconData icon, VoidCallback onTap, {bool isAdd = false}) => GestureDetector(onTap: onTap,
    child: Container(width: 28, height: 28,
      decoration: BoxDecoration(gradient: isAdd ? AppTheme.primaryGradient : null,
        border: isAdd ? null : Border.all(color: _blue.withOpacity(0.5)), borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, color: Colors.white, size: 14)));
}