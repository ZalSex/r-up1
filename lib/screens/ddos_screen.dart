import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/app_localizations.dart';
import '../services/api_service.dart';

class DdosScreen extends StatefulWidget {
  const DdosScreen({super.key});

  @override
  State<DdosScreen> createState() => _DdosScreenState();
}

class _DdosScreenState extends State<DdosScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  String _role = 'member';

  static const Color _red        = Color(0xFFEF4444);
  static const Color _redDark    = Color(0xFF991B1B);
  static const Color _purple     = Color(0xFF7C3AED);
  static const Color _purpleDark = Color(0xFF4C1D95);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRole();
  }

  Future<void> _loadRole() async {
    try {
      final res = await ApiService.getProfile();
      if (res['success'] == true && mounted) {
        setState(() => _role = res['user']['role'] ?? 'member');
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _canMulti => _role == 'premium' || _role == 'vip' || _role == 'owner';

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
              border: Border.all(color: _red.withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
          ),
        ),
        title: Row(children: [
          Container(width: 3, height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_red, _redDark]),
                borderRadius: BorderRadius.circular(2),
              )),
          SizedBox(width: 10),
          Text(tr('ddos_title'), style: TextStyle(fontFamily: 'Orbitron',
              fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
        ]),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: Column(children: [
            Container(height: 1, color: _red.withOpacity(0.3)),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _red.withOpacity(0.2)),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  gradient: const LinearGradient(colors: [_red, _redDark]),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [BoxShadow(color: _red.withOpacity(0.4), blurRadius: 8)],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                    fontWeight: FontWeight.bold, letterSpacing: 1),
                unselectedLabelStyle: const TextStyle(fontFamily: 'Orbitron', fontSize: 10),
                labelColor: Colors.white,
                unselectedLabelColor: AppTheme.textMuted,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(text: 'DDOS PANEL'),
                  Tab(text: 'PERBAIKAN'),
                ],
              ),
            ),
          ]),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _DdosPanelTab(red: _red, redDark: _redDark),
          _PerbaikanTab(),
        ],
      ),
    );
  }
}

class _DdosPanelTab extends StatefulWidget {
  final Color red, redDark;
  const _DdosPanelTab({required this.red, required this.redDark});
  @override State<_DdosPanelTab> createState() => _DdosPanelTabState();
}

class _DdosPanelTabState extends State<_DdosPanelTab> with SingleTickerProviderStateMixin {
  final _targetCtrl = TextEditingController();
  int _timeSeconds = 60;
  bool _attacking  = false;
  String? _attackId;
  late AnimationController _pulseCtrl;
  late Animation<double> _pulseAnim;

  Color get c => widget.red;
  Color get cd => widget.redDark;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _targetCtrl.dispose(); super.dispose(); }

  Future<void> _startAttack() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) { _snack('Masukkan URL / IP Panel Target'); return; }
    if (!target.startsWith('http://') && !target.startsWith('https://')) { _snack('Link harus diawali http:// atau https://'); return; }
    setState(() => _attacking = true);
    try {
      final res = await ApiService.ddosStart(target: target, time: _timeSeconds);
      if (res['success'] == true) { _attackId = res['attackId']; _snack('Attack Dimulai! Target: \$target', isSuccess: true); }
      else { setState(() => _attacking = false); _snack(res['message'] ?? 'Gagal', err: true); }
    } catch (_) { setState(() => _attacking = false); _snack('Koneksi Gagal', err: true); }
  }

  Future<void> _stopAttack() async {
    try {
      final res = await ApiService.ddosStop(attackId: _attackId);
      if (res['success'] == true) { setState(() { _attacking = false; _attackId = null; }); _snack('Attack Dihentikan', isSuccess: true); }
      else _snack(res['message'] ?? 'Gagal', err: true);
    } catch (_) { setState(() { _attacking = false; _attackId = null; }); _snack('Koneksi Gagal', err: true); }
  }

  void _snack(String msg, {bool err = false, bool isSuccess = false}) {
    if (!mounted) return;
    if (err) {
      showError(context, msg);
    } else if (isSuccess) {
      showSuccess(context, msg);
    } else {
      showWarning(context, msg);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_attacking)
        AnimatedBuilder(animation: _pulseAnim, builder: (_, __) => _attackingBanner(c, _pulseAnim, 'Attack Berjalan...')),
      _lbl('URL / IP Target Panel', c), SizedBox(height: 8),
      _inputField(_targetCtrl, !_attacking, c, 'https://panel.target.com'),
      SizedBox(height: 20),
      _durationCard(context, c, cd, _timeSeconds, 10, 300, 29, !_attacking, [30,60,120,180,300], (v) => setState(() => _timeSeconds = v)),
      SizedBox(height: 28),
      if (!_attacking) _actionBtn('START ATTACK', c, cd, _startAttack)
      else _stopBtn('Stop Attack', c, _stopAttack),
      SizedBox(height: 40),
    ]));
  }
}

class _MultiLayerTab extends StatefulWidget {
  final Color purple, purpleDark;
  const _MultiLayerTab({required this.purple, required this.purpleDark});
  @override State<_MultiLayerTab> createState() => _MultiLayerTabState();
}

class _MultiLayerTabState extends State<_MultiLayerTab> with SingleTickerProviderStateMixin {
  final _targetCtrl    = TextEditingController();
  int  _timeSeconds    = 60;
  int  _cooldownMinutes = 20;
  bool _attacking      = false;
  String? _attackId;
  String? _selectedMethod;
  bool _onCooldown     = false;
  int  _remainingMs    = 0;
  Timer? _cdTimer;

  late AnimationController _pulseCtrl;
  late Animation<double>   _pulseAnim;

  Color get c  => widget.purple;
  Color get cd => widget.purpleDark;

  static const List<Map<String, String>> _methods = [
    {'id': 'one',   'label': 'Pidoras Killer'},
    {'id': 'two',   'label': 'Dns Amplify'},
    {'id': 'four',  'label': 'Bypass Destroyer'},
    {'id': 'five',  'label': 'Tcp Strom'},
    {'id': 'six',   'label': 'Http Masscare'},
  ];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.5, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _loadStatus();
  }

  @override
  void dispose() { _pulseCtrl.dispose(); _targetCtrl.dispose(); _cdTimer?.cancel(); super.dispose(); }

  Future<void> _loadStatus() async {
    try {
      final res = await ApiService.ddosMultiStatus();
      if (!mounted) return;
      if (res['success'] == true) {
        final cd = res['cooldown'];
        if (cd['active'] == true) {
          setState(() { _onCooldown = true; _remainingMs = cd['remainingMs']; });
          _startCdTick();
        }
        if (res['isRunning'] == true) {
          final attacks = res['attacks'] as List? ?? [];
          if (attacks.isNotEmpty) setState(() { _attacking = true; _attackId = attacks[0]['attackId']; });
        }
      }
    } catch (_) {}
  }

  void _startCdTick() {
    _cdTimer?.cancel();
    _cdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _remainingMs = (_remainingMs - 1000).clamp(0, 999999999));
      if (_remainingMs <= 0) { _cdTimer?.cancel(); setState(() { _onCooldown = false; _remainingMs = 0; }); }
    });
  }

  Future<void> _startAttack() async {
    final target = _targetCtrl.text.trim();
    if (target.isEmpty) { _snack('Masukkan URL / IP Target'); return; }
    if (!target.startsWith('http://') && !target.startsWith('https://')) { _snack('Link harus diawali http:// atau https://'); return; }
    if (_selectedMethod == null) { _snack('Pilih Metode Terlebih Dahulu'); return; }
    setState(() => _attacking = true);
    try {
      final res = await ApiService.ddosMultiStart(
        target: target, time: _timeSeconds, method: _selectedMethod!, cooldownMinutes: _cooldownMinutes);
      if (res['success'] == true) {
        _attackId = res['attackId']; _snack('Multi Layer Dimulai! Target: \$target', isSuccess: true);
      } else if (res['cooldown'] == true) {
        setState(() { _attacking = false; _onCooldown = true; _remainingMs = res['remainingMs'] ?? 0; });
        _startCdTick(); _snack('Sedang Cooldown!', err: true);
      } else {
        setState(() => _attacking = false); _snack(res['message'] ?? 'Gagal', err: true);
      }
    } catch (_) { setState(() => _attacking = false); _snack('Koneksi Gagal', err: true); }
  }

  Future<void> _stopAttack() async {
    if (_attackId == null) { setState(() { _attacking = false; }); return; }
    try {
      final res = await ApiService.ddosMultiStop(attackId: _attackId!);
      setState(() { _attacking = false; _attackId = null; });
      if (res['success'] == true) { _snack('Attack Dihentikan, Cooldown Dimulai', isSuccess: true); } else { _snack(res['message'] ?? 'Gagal', err: true); }
      if (res['success'] == true) {
        await Future.delayed(const Duration(milliseconds: 500));
        final status = await ApiService.ddosMultiCooldown();
        if (status['cooldown'] == true && mounted) {
          setState(() { _onCooldown = true; _remainingMs = status['remainingMs'] ?? (_cooldownMinutes * 60 * 1000); });
          _startCdTick();
        }
      }
    } catch (_) { setState(() { _attacking = false; _attackId = null; }); _snack('Koneksi Gagal', err: true); }
  }

  void _snack(String msg, {bool err = false, bool isSuccess = false}) {
    if (!mounted) return;
    if (err) {
      showError(context, msg);
    } else if (isSuccess) {
      showSuccess(context, msg);
    } else {
      showWarning(context, msg);
    }
  }

  String _fmt() {
    final t = _remainingMs ~/ 1000;
    return '${(t ~/ 60).toString().padLeft(2,'0')}:${(t % 60).toString().padLeft(2,'0')}';
  }

  @override
  Widget build(BuildContext context) {
    final disabled = _attacking || _onCooldown;
    return SingleChildScrollView(padding: const EdgeInsets.all(20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      if (_onCooldown) Container(
        width: double.infinity, padding: const EdgeInsets.all(16), margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withOpacity(0.5), width: 1.5),
            boxShadow: [BoxShadow(color: Colors.orange.withOpacity(0.15), blurRadius: 12)]),
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.timer_outlined, color: Colors.orange, size: 20),
            SizedBox(width: 8),
            Text(tr('cooldown_active'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
          ]),
          SizedBox(height: 10),
          Text(_fmt(), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 36,
              color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 4)),
          SizedBox(height: 6),
          Text(tr('cooldown_warning'),
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.orange, height: 1.5)),
        ]),
      ),

      if (_attacking && !_onCooldown)
        AnimatedBuilder(animation: _pulseAnim, builder: (_, __) => _attackingBanner(c, _pulseAnim, 'Multi Layer Sedang Berjalan...')),

      _lbl('URL / IP Target', c), SizedBox(height: 8),
      _inputField(_targetCtrl, !disabled, c, 'https://link.target.com'),
      SizedBox(height: 20),

      _lbl('Pilih Metode', c), SizedBox(height: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _selectedMethod != null ? c : c.withOpacity(0.4))),
        child: DropdownButton<String>(
          value: _selectedMethod, isExpanded: true, dropdownColor: AppTheme.cardBg, underline: SizedBox(),
          hint: Text(tr('pick_layer'), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted)),
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: c),
          items: _methods.map((m) => DropdownMenuItem<String>(
            value: m['id'],
            child: Text(m['label']!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white)),
          )).toList(),
          onChanged: disabled ? null : (v) => setState(() => _selectedMethod = v),
        ),
      ),
      SizedBox(height: 20),

      _durationCard(context, c, cd, _timeSeconds, 10, 600, 59, !disabled, [30,60,120,300,600], (v) => setState(() => _timeSeconds = v)),
      SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.orange.withOpacity(0.3))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(tr('cooldown_duration'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                color: Colors.orange.withOpacity(0.8), letterSpacing: 2)),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.4))),
              child: Text('$_cooldownMinutes menit', style: const TextStyle(fontFamily: 'Orbitron',
                  fontSize: 12, color: Colors.orange, fontWeight: FontWeight.bold)),
            ),
          ]),
          SizedBox(height: 12),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.orange, inactiveTrackColor: Colors.orange.withOpacity(0.15),
              thumbColor: Colors.white, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
              overlayColor: Colors.orange.withOpacity(0.2), trackHeight: 3,
            ),
            child: Slider(value: _cooldownMinutes.toDouble(), min: 5, max: 60, divisions: 11,
              onChanged: disabled ? null : (v) => setState(() => _cooldownMinutes = v.toInt())),
          ),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('5 mnt', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
            Text('60 mnt', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
          ]),
          SizedBox(height: 10),
          Row(children: [5,10,20,30,60].map((m) {
            final isActive = _cooldownMinutes == m;
            return Expanded(child: GestureDetector(
              onTap: disabled ? null : () => setState(() => _cooldownMinutes = m),
              child: Container(margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  color: isActive ? Colors.orange.withOpacity(0.8) : Colors.orange.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(color: isActive ? Colors.orange : Colors.orange.withOpacity(0.25)),
                ),
                child: Text('${m}m', textAlign: TextAlign.center,
                    style: TextStyle(fontFamily: 'Orbitron', fontSize: 9,
                        color: isActive ? Colors.white : Colors.orange.withOpacity(0.6), fontWeight: FontWeight.bold)),
              ),
            ));
          }).toList()),
        ]),
      ),
      SizedBox(height: 28),

      if (!_attacking && !_onCooldown) _actionBtn('START ATTACK', c, cd, _startAttack)
      else if (_attacking) _stopBtn('Stop Multi Layer', c, _stopAttack)
      else Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(color: Colors.orange.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.withOpacity(0.4))),
        child: Column(children: [
          const Icon(Icons.timer_outlined, color: Colors.orange, size: 22),
          SizedBox(height: 6),
          Text('Cooldown: ${_fmt()}', style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12,
              color: Colors.orange, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ]),
      ),
      SizedBox(height: 40),
    ]));
  }
}

class _LockedTab extends StatelessWidget {
  final String role;
  const _LockedTab({required this.role});
  @override
  Widget build(BuildContext context) {
    return Center(child: Padding(padding: const EdgeInsets.all(32), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle,
          color: Colors.amber.withOpacity(0.1), border: Border.all(color: Colors.amber.withOpacity(0.4), width: 2)),
        child: const Icon(Icons.lock_outline, color: Colors.amber, size: 36)),
      SizedBox(height: 20),
      Text(tr('access_limited'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 16,
          color: Colors.amber, letterSpacing: 3, fontWeight: FontWeight.bold)),
      SizedBox(height: 12),
      Text('Multi Layer Hanya Bisa Diakses Oleh:\nPremium • VIP • Owner\n\nRole kamu: ${role.toUpperCase()}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted, height: 1.6)),
    ])));
  }
}

Widget _attackingBanner(Color color, Animation<double> anim, String label) {
  return AnimatedBuilder(animation: anim, builder: (_, __) => Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12),
    margin: const EdgeInsets.only(bottom: 20),
    decoration: BoxDecoration(
      color: color.withOpacity(0.08 + anim.value * 0.06), borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.3 + anim.value * 0.3)),
      boxShadow: [BoxShadow(color: color.withOpacity(anim.value * 0.2), blurRadius: 16, spreadRadius: 2)],
    ),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle,
          color: color.withOpacity(anim.value), boxShadow: [BoxShadow(color: color, blurRadius: 6)])),
      SizedBox(width: 10),
      Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
          color: color, letterSpacing: 1.5, fontWeight: FontWeight.bold)),
    ]),
  ));
}

Widget _lbl(String text, Color color) => Text(text, style: TextStyle(fontFamily: 'Orbitron',
    fontSize: 10, color: color.withOpacity(0.8), letterSpacing: 2));

Widget _inputField(TextEditingController ctrl, bool enabled, Color color, String hint) {
  return TextFormField(
    controller: ctrl, enabled: enabled,
    keyboardType: TextInputType.url,
    style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono', fontSize: 13),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 12),
      prefixIcon: Padding(padding: const EdgeInsets.all(12),
          child: SvgPicture.string(AppSvgIcons.globe, width: 18, height: 18,
              colorFilter: ColorFilter.mode(enabled ? color : color.withOpacity(0.3), BlendMode.srcIn))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.5))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 1.5)),
      disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.2))),
      filled: true, fillColor: AppTheme.cardBg,
    ),
  );
}

Widget _durationCard(BuildContext context, Color color, Color darkColor, int value,
    double min, double max, int divisions, bool enabled, List<int> presets, ValueChanged<int> onChanged) {
  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(tr('attack_duration'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
            color: color.withOpacity(0.8), letterSpacing: 2)),
        Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(gradient: LinearGradient(colors: [color, darkColor]),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 8)]),
          child: Text('${value}s', style: const TextStyle(fontFamily: 'Orbitron', fontSize: 15,
              color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)),
        ),
      ]),
      SizedBox(height: 14),
      SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor: color, inactiveTrackColor: color.withOpacity(0.15),
          thumbColor: Colors.white, thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 9),
          overlayColor: color.withOpacity(0.2), trackHeight: 3,
        ),
        child: Slider(value: value.toDouble().clamp(min, max), min: min, max: max, divisions: divisions,
          onChanged: enabled ? (v) => onChanged(v.toInt()) : null),
      ),
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('${min.toInt()}s', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
        Text('${max.toInt()}s', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
      ]),
      SizedBox(height: 12),
      Row(children: presets.map((sec) {
        final isActive = value == sec;
        return Expanded(child: GestureDetector(
          onTap: enabled ? () => onChanged(sec) : null,
          child: Container(margin: const EdgeInsets.symmetric(horizontal: 3), padding: const EdgeInsets.symmetric(vertical: 7),
            decoration: BoxDecoration(
              gradient: isActive ? LinearGradient(colors: [color, darkColor]) : null,
              color: isActive ? null : color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(color: isActive ? color : color.withOpacity(0.25)),
            ),
            child: Text('${sec}s', textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 9,
                    color: isActive ? Colors.white : color.withOpacity(0.6), fontWeight: FontWeight.bold)),
          ),
        ));
      }).toList()),
    ]),
  );
}

Widget _actionBtn(String label, Color color, Color darkColor, VoidCallback onTap) {
  return GestureDetector(onTap: onTap, child: Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(gradient: LinearGradient(colors: [color, darkColor]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 4))]),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      SvgPicture.string(AppSvgIcons.zap, width: 20, height: 20,
          colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
      SizedBox(width: 10),
      Text(label, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
          fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
    ]),
  ));
}

Widget _stopBtn(String label, Color color, VoidCallback onTap) {
  return GestureDetector(onTap: onTap, child: Container(
    width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 18),
    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.7), width: 1.5),
        boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 16, offset: const Offset(0, 4))]),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(width: 18, height: 18, decoration: BoxDecoration(borderRadius: BorderRadius.circular(4), color: color)),
      SizedBox(width: 10),
      Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 13,
          fontWeight: FontWeight.bold, color: color, letterSpacing: 2)),
    ]),
  ));
}

// ─── PERBAIKAN Tab ────────────────────────────────────────────────────────────
class _PerbaikanTab extends StatelessWidget {
  const _PerbaikanTab();

  static const _blue  = Color(0xFF3B82F6);
  static const _green = Color(0xFF22C55E);
  static const _amber = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final items = [
      _PerbaikanItem(
        icon: Icons.construction_rounded,
        color: _amber,
        title: 'DDOS MULTI LAYER',
        status: 'DALAM PERBAIKAN',
        desc: 'Fitur DDOS Multi Layer sedang dalam maintenance. Sedang dilakukan peningkatan stabilitas dan performa sistem.',
        eta: 'Segera hadir',
      ),
      _PerbaikanItem(
        icon: Icons.security_update_rounded,
        color: _blue,
        title: 'SISTEM KEAMANAN',
        status: 'DIPERBARUI',
        desc: 'Peningkatan lapisan keamanan sistem sedang dilakukan untuk memastikan pengalaman yang lebih aman.',
        eta: 'Sedang berjalan',
      ),
      _PerbaikanItem(
        icon: Icons.speed_rounded,
        color: _green,
        title: 'OPTIMASI PERFORMA',
        status: 'PROGRESS',
        desc: 'Optimasi engine untuk kecepatan dan stabilitas yang lebih baik pada semua fitur premium.',
        eta: '80% selesai',
      ),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [_amber.withOpacity(0.15), _amber.withOpacity(0.05)],
              begin: Alignment.topLeft, end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _amber.withOpacity(0.4)),
          ),
          child: Row(children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: _amber.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _amber.withOpacity(0.5)),
                boxShadow: [BoxShadow(color: _amber.withOpacity(0.3), blurRadius: 14)],
              ),
              child: const Center(child: Icon(Icons.engineering_rounded, color: _amber, size: 26)),
            ),
            const SizedBox(width: 16),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('MAINTENANCE', style: TextStyle(
                fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold,
                color: _amber, letterSpacing: 2,
              )),
              const SizedBox(height: 4),
              Text(
                'Beberapa fitur sedang dalam proses perbaikan dan peningkatan',
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                  color: Colors.white.withOpacity(0.6), height: 1.5),
              ),
            ])),
          ]),
        ),

        // Items
        ...items.map((item) => Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: item.color.withOpacity(0.25)),
          ),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: item.color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: item.color.withOpacity(0.4)),
              ),
              child: Center(child: Icon(item.icon, color: item.color, size: 22)),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text(item.title, style: const TextStyle(
                  fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1,
                ))),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: item.color.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: item.color.withOpacity(0.4)),
                  ),
                  child: Text(item.status, style: TextStyle(
                    fontFamily: 'ShareTechMono', fontSize: 8, color: item.color, letterSpacing: 0.5,
                  )),
                ),
              ]),
              const SizedBox(height: 8),
              Text(item.desc, style: TextStyle(
                fontFamily: 'ShareTechMono', fontSize: 10,
                color: Colors.white.withOpacity(0.55), height: 1.5,
              )),
              const SizedBox(height: 8),
              Row(children: [
                Icon(Icons.access_time_rounded, color: item.color.withOpacity(0.6), size: 12),
                const SizedBox(width: 4),
                Text('ETA: ${item.eta}', style: TextStyle(
                  fontFamily: 'ShareTechMono', fontSize: 9, color: item.color.withOpacity(0.8), letterSpacing: 0.5,
                )),
              ]),
            ])),
          ]),
        )),

        const SizedBox(height: 40),
      ]),
    );
  }
}

class _PerbaikanItem {
  final IconData icon;
  final Color color;
  final String title;
  final String status;
  final String desc;
  final String eta;

  const _PerbaikanItem({
    required this.icon,
    required this.color,
    required this.title,
    required this.status,
    required this.desc,
    required this.eta,
  });
}
