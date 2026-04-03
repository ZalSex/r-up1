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

class SpamNglScreen extends StatefulWidget {
  const SpamNglScreen({super.key});
  @override
  State<SpamNglScreen> createState() => _SpamNglScreenState();
}

class _SpamNglScreenState extends State<SpamNglScreen> {
  final _urlCtrl   = TextEditingController();
  final _pesanCtrl = TextEditingController();
  final _countCtrl = TextEditingController(text: '10');
  double _delay = 2.0;

  bool   _running  = false;
  String? _jobId;
  Timer? _pollTimer;
  int    _progress = 0;
  int    _total    = 0;
  bool   _done     = false;
  String _error    = '';

  static const _pink   = Color(0xFFEC4899);
  static const _pinkDk = Color(0xFFBE185D);
  static const _red    = Color(0xFFEF4444);
  static const _green  = Color(0xFF10B981);

  @override
  void dispose() {
    _pollTimer?.cancel();
    _urlCtrl.dispose();
    _pesanCtrl.dispose();
    _countCtrl.dispose();
    super.dispose();
  }

  Future<void> _start() async {
    final url   = _urlCtrl.text.trim();
    final pesan = _pesanCtrl.text.trim();
    if (url.isEmpty)   { _snack('Masukkan URL NGL'); return; }
    if (pesan.isEmpty) { _snack('Masukkan Pesan'); return; }
    if (!url.contains('ngl.link')) { _snack('URL Harus Dari ngl.link'); return; }

    final count = int.tryParse(_countCtrl.text) ?? 10;
    if (count < 1 || count > 999) { _snack('Jumlah 1–999'); return; }

    setState(() { _running = true; _done = false; _progress = 0; _total = count; _error = ''; });

    try {
      final res = await ApiService.post('/api/spamngl/start', {
        'url': url, 'pesan': pesan, 'jumlah': count, 'delay': _delay,
      });
      if (res['success'] == true) {
        _jobId = res['jobId'] as String?;
        _snack('Spam NGL Dimulai', isSuccess: true);
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
          Uri.parse('${ApiService.baseUrl}/api/spamngl/status/$_jobId'),
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
          _snack(_error.isNotEmpty ? 'Error: $_error' : 'Selesai $_progress/$_total Pesan Terkirim');
        }
      } catch (_) {}
    });
  }

  Future<void> _stop() async {
    if (_jobId == null) return;
    try {
      await ApiService.post('/api/spamngl/stop', {'jobId': _jobId});
      _pollTimer?.cancel();
      setState(() { _running = false; _done = true; });
      _snack('Spam NGL Dihentikan', isSuccess: true);
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
          backgroundColor: AppTheme.darkBg, elevation: 0, pinned: true,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: _pink.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16)),
          ),
          title: Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(gradient: const LinearGradient(colors: [_pink, _pinkDk]), borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Text(tr('spam_ngl_title'), style: TextStyle(fontFamily: 'Orbitron',
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _pink.withOpacity(0.25))),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _label('URL NGL Target'),
              SizedBox(height: 8),
              TextFormField(
                controller: _urlCtrl,
                keyboardType: TextInputType.url,
                style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono', fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'https://ngl.link/username',
                  hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 12),
                  prefixIcon: Padding(padding: EdgeInsets.all(14),
                    child: Icon(Icons.link_rounded, color: AppTheme.textSecondary, size: 18)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _pink.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pink, width: 1.5)),
                  filled: true, fillColor: AppTheme.cardBg, contentPadding: const EdgeInsets.all(14),
                ),
              ),

              SizedBox(height: 16),

              _label('Pesan Yang Dikirim'),
              SizedBox(height: 8),
              TextFormField(
                controller: _pesanCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono', fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Tulis pesan anonim di sini...',
                  hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 12),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: _pink.withOpacity(0.4))),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _pink, width: 1.5)),
                  filled: true, fillColor: AppTheme.cardBg, contentPadding: const EdgeInsets.all(14),
                ),
              ),

              SizedBox(height: 20),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(gradient: AppTheme.cardGradient, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _pink.withOpacity(0.3))),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _label('Jumlah Pesan'),
                    Row(children: [
                      _cBtn(Icons.remove, () { final v = int.tryParse(_countCtrl.text) ?? 10; if (v > 1) setState(() => _countCtrl.text = (v-1).toString()); }),
                      SizedBox(width: 8),
                      SizedBox(width: 56, child: TextFormField(controller: _countCtrl, keyboardType: TextInputType.number, textAlign: TextAlign.center,
                        style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                        decoration: InputDecoration(isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 6),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide(color: _pink.withOpacity(0.4))),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: const BorderSide(color: _pink)),
                          filled: true, fillColor: _pink.withOpacity(0.08)))),
                      SizedBox(width: 8),
                      _cBtn(Icons.add, () { final v = int.tryParse(_countCtrl.text) ?? 10; if (v < 999) setState(() => _countCtrl.text = (v+1).toString()); }, isAdd: true),
                    ]),
                  ]),
                  SizedBox(height: 20),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    _label('Delay Antar Pesan'),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [_pink, _pinkDk]),
                        borderRadius: BorderRadius.circular(6)),
                      child: Text('${_delay.toStringAsFixed(1)}s',
                        style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold))),
                  ]),
                  SizedBox(height: 8),
                  SliderTheme(
                    data: SliderTheme.of(context).copyWith(
                      activeTrackColor: _pink, inactiveTrackColor: _pink.withOpacity(0.2),
                      thumbColor: Colors.white, trackHeight: 3, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8)),
                    child: Slider(value: _delay, min: 0.5, max: 30, divisions: 59, onChanged: (v) => setState(() => _delay = v))),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text('0.5s', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
                    Text('30s',  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
                  ]),
                ]),
              ),

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
                        gradient: _running ? null : const LinearGradient(colors: [_pink, _pinkDk]),
                        color: _running ? _pink.withOpacity(0.2) : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _running ? [] : [BoxShadow(color: _pink.withOpacity(0.4), blurRadius: 14, offset: const Offset(0,4))],
                      ),
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _running
                          ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.send_rounded, color: Colors.white, size: 18),
                        SizedBox(width: 10),
                        Text(_running ? 'Running...' : 'MULAI SPAM NGL',
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

  Widget _buildProgress() {
    final color = _done ? (_error.isNotEmpty ? _red : _green) : _pink;
    final label = _done ? (_error.isNotEmpty ? 'Error' : 'Selesai') : 'Mengirim...';
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

  Widget _label(String t) => Text(t, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _pink, letterSpacing: 2));
  Widget _cBtn(IconData icon, VoidCallback onTap, {bool isAdd = false}) => GestureDetector(onTap: onTap,
    child: Container(width: 28, height: 28,
      decoration: BoxDecoration(
        gradient: isAdd ? const LinearGradient(colors: [_pink, _pinkDk]) : null,
        border: isAdd ? null : Border.all(color: _pink.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(6)),
      child: Icon(icon, color: Colors.white, size: 14)));
}