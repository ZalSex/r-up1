import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:video_player/video_player.dart';
import '../../utils/theme.dart';
import '../../utils/notif_helper.dart';
import '../../utils/app_localizations.dart';
import '../../utils/role_style.dart';
import '../../services/api_service.dart';
import '../login_screen.dart';

class BugTab extends StatefulWidget {
  const BugTab({super.key});

  @override
  State<BugTab> createState() => _BugTabState();
}

class _BugTabState extends State<BugTab> with WidgetsBindingObserver, TickerProviderStateMixin {
  late TabController _tabController;

  String? _selectedSenderId;
  String? _selectedSenderPhone;
  List<String> _selectedSenderIds = [];
  bool _selectAll = false;
  List<Map<String, dynamic>> _senders = [];
  bool _loadingSenders = false;
  String _username = '';
  String _role = 'member';
  String? _avatarBase64;

  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  final _targetCtrl = TextEditingController();
  final _countCtrl  = TextEditingController(text: '20');
  bool _executing   = false;
  int? _selectedMethod;
  double _delaySeconds = 1.0;

  String? _currentJobId;
  Timer? _pollTimer;
  String _jobStatus = '';
  int _jobProgress = 0;
  int _jobTotal = 0;
  String _jobError = '';

  static const List<Map<String, dynamic>> _methods = [
    {'id': 'invisible',    'title': 'Invisible Delay', 'icon': AppSvgIcons.eye,   'color': Color(0xFF8B5CF6)},
    {'id': 'stickerpack',  'title': 'Sticker Blank',   'icon': AppSvgIcons.smile, 'color': Color(0xFFF59E0B)},
    {'id': 'trash',        'title': 'Button Invis',    'icon': AppSvgIcons.trash, 'color': Color(0xFFEC4899)},
    {'id': 'bulldozer',    'title': 'Contact Delay',   'icon': AppSvgIcons.drain, 'color': Color(0xFF06B6D4)},
    {'id': 'iosinvisible', 'title': 'Invisible iOS',   'icon': AppSvgIcons.zap,   'color': Color(0xFF10B981)},
    {'id': 'iphonecursed', 'title': 'iPhone Cursed',   'icon': AppSvgIcons.skull, 'color': Color(0xFFEF4444)},
  ];

  final _groupTargetCtrl = TextEditingController();
  final _groupCountCtrl  = TextEditingController(text: '20');
  bool _executingGroup   = false;
  int? _selectedGroupMethod;
  double _groupDelay = 1.0;

  String? _currentGroupJobId;
  Timer? _pollGroupTimer;
  String _groupJobStatus = '';
  int _groupJobProgress = 0;
  int _groupJobTotal = 0;
  String _groupJobError = '';

  static const List<Map<String, dynamic>> _groupMethods = [
    {'id': 'group_visible_delay',  'title': 'Visible Delay', 'icon': AppSvgIcons.eye,   'color': Color(0xFF8B5CF6)},
    {'id': 'group_trash_button',   'title': 'Trash Button',  'icon': AppSvgIcons.trash,  'color': Color(0xFFEC4899)},
    {'id': 'group_crash_delay',    'title': 'Crash Delay',   'icon': AppSvgIcons.zap,    'color': Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    _loadSenders();
    _loadProfile();

    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);

    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowCtrl);
  }

  Future<void> _loadProfile() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _username = prefs.getString('username') ?? '';
        _role = prefs.getString('role') ?? 'member';
        _avatarBase64 = prefs.getString('avatar');
      });
      final res = await ApiService.getProfile();
      if (res['success'] == true && mounted) {
        setState(() {
          _username = res['user']['username'] ?? _username;
          _role = res['user']['role'] ?? _role;
          _avatarBase64 = res['user']['avatar'] ?? _avatarBase64;
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _tabController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _targetCtrl.dispose();
    _countCtrl.dispose();
    _groupTargetCtrl.dispose();
    _groupCountCtrl.dispose();
    _pollTimer?.cancel();
    _pollGroupTimer?.cancel();
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _loadSenders();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSenders();
  }

  Future<void> _loadSenders() async {
    if (_loadingSenders) return;
    if (mounted) setState(() => _loadingSenders = true);
    try {
      final res = await ApiService.getSenders();
      if (res['success'] == true && mounted) {
        final newSenders = List<Map<String, dynamic>>.from(res['senders'] ?? []);
        setState(() {
          _senders = newSenders;
          if (_selectedSenderId != null) {
            final found = newSenders.where((s) => s['id'] == _selectedSenderId).toList();
            if (found.isEmpty) {
              _selectedSenderId = null;
              _selectedSenderPhone = null;
            } else {
              final isOnline = found.first['status'] == 'online' || found.first['status'] == 'connected';
              if (!isOnline) {
                _selectedSenderId = null;
                _selectedSenderPhone = null;
              }
            }
          }
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingSenders = false);
  }

  Future<void> _startPolling(String jobId, {bool isGroup = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_token') ?? '';

    final timer = Timer.periodic(const Duration(seconds: 2), (t) async {
      if (!mounted) { t.cancel(); return; }
      try {
        final res = await http.get(
          Uri.parse('${ApiService.baseUrl}/api/bug/job/$jobId'),
          headers: {'Authorization': 'Bearer $token'},
        ).timeout(const Duration(seconds: 5));

        final json = jsonDecode(res.body);
        if (!mounted) { t.cancel(); return; }

        if (json['success'] == true) {
          final status   = json['status'] as String? ?? 'running';
          final progress = json['progress'] as int? ?? 0;
          final total    = json['total'] as int? ?? 0;
          final error    = json['error'] as String?;
          final done     = json['done'] as bool? ?? false;

          setState(() {
            if (isGroup) {
              _groupJobStatus   = status;
              _groupJobProgress = progress;
              _groupJobTotal    = total;
              _groupJobError    = error ?? '';
            } else {
              _jobStatus   = status;
              _jobProgress = progress;
              _jobTotal    = total;
              _jobError    = error ?? '';
            }
          });

          if (done) {
            t.cancel();
            if (isGroup) {
              _pollGroupTimer = null;
              setState(() { _executingGroup = false; _currentGroupJobId = null; });
            } else {
              _pollTimer = null;
              setState(() { _executing = false; _currentJobId = null; });
            }

            if (error != null && error.isNotEmpty) {
              _showSnack('Error: $error', isError: true);
            } else {
              _showSnack('Bug Selesai Dikirim ($progress/$total Berhasil)', isSuccess: true);
            }
          }
        }
      } catch (_) {}
    });

    if (isGroup) {
      _pollGroupTimer?.cancel();
      _pollGroupTimer = timer;
    } else {
      _pollTimer?.cancel();
      _pollTimer = timer;
    }
  }

  void _showSenderPicker() async {
    await _loadSenders();
    if (!mounted) return;
    // temp selection state inside sheet
    final tempSelected = <String>{..._selectedSenderIds};
    bool tempSelectAll = _selectAll;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setSheet) {
          final onlineSenders = _senders.where((s) => s['status'] == 'online' || s['status'] == 'connected').toList();
          return DraggableScrollableSheet(
            initialChildSize: 0.6,
            minChildSize: 0.4,
            maxChildSize: 0.9,
            expand: false,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40, height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.textMuted.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(children: [
                        Container(width: 3, height: 18,
                            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                        SizedBox(width: 10),
                        Text(tr('pick_sender'), style: TextStyle(fontFamily: 'Orbitron', color: Colors.white,
                            fontSize: 14, letterSpacing: 2, fontWeight: FontWeight.bold)),
                      ]),
                      GestureDetector(
                        onTap: () async { await _loadSenders(); setSheet(() {}); },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: _loadingSenders
                              ? SizedBox(width: 14, height: 14,
                                  child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryBlue))
                              : const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 16),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 6),
                  Padding(
                    padding: EdgeInsets.only(left: 13),
                    child: Text('Pilih satu atau lebih sender aktif',
                        style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
                  ),
                  SizedBox(height: 12),
                  // Select All row
                  if (_senders.isNotEmpty)
                    GestureDetector(
                      onTap: () {
                        setSheet(() {
                          tempSelectAll = !tempSelectAll;
                          if (tempSelectAll) {
                            tempSelected.addAll(onlineSenders.map((s) => s['id'] as String));
                          } else {
                            tempSelected.removeAll(onlineSenders.map((s) => s['id'] as String));
                          }
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          gradient: tempSelectAll
                              ? LinearGradient(colors: [AppTheme.primaryBlue.withOpacity(0.3), AppTheme.primaryBlue.withOpacity(0.08)])
                              : null,
                          color: tempSelectAll ? null : AppTheme.primaryBlue.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: tempSelectAll ? AppTheme.primaryBlue : AppTheme.primaryBlue.withOpacity(0.25),
                            width: tempSelectAll ? 1.5 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 20, height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tempSelectAll ? AppTheme.primaryBlue : Colors.transparent,
                                border: Border.all(color: tempSelectAll ? AppTheme.primaryBlue : AppTheme.textMuted),
                              ),
                              child: tempSelectAll
                                  ? const Icon(Icons.check, size: 13, color: Colors.white)
                                  : null,
                            ),
                            SizedBox(width: 12),
                            Text('Select All (${onlineSenders.length} online)',
                                style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
                                    color: tempSelectAll ? Colors.white : AppTheme.textSecondary, letterSpacing: 1)),
                          ],
                        ),
                      ),
                    ),
                  if (_senders.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                      ),
                      child: Center(
                        child: Text(tr('no_sender_connected'),
                            textAlign: TextAlign.center,
                            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, height: 1.6)),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.builder(
                        controller: scrollCtrl,
                        shrinkWrap: true,
                        itemCount: _senders.length,
                        itemBuilder: (_, i) {
                          final s = _senders[i];
                          final isOnline = s['status'] == 'online' || s['status'] == 'connected';
                          final isSelected = tempSelected.contains(s['id']);
                          return GestureDetector(
                            onTap: isOnline ? () {
                              setSheet(() {
                                if (isSelected) {
                                  tempSelected.remove(s['id']);
                                } else {
                                  tempSelected.add(s['id'] as String);
                                }
                                tempSelectAll = tempSelected.containsAll(onlineSenders.map((s) => s['id'] as String));
                              });
                            } : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? LinearGradient(colors: [AppTheme.primaryBlue.withOpacity(0.25), AppTheme.primaryBlue.withOpacity(0.05)])
                                    : AppTheme.cardGradient,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryBlue : AppTheme.primaryBlue.withOpacity(0.2),
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42, height: 42,
                                    decoration: BoxDecoration(
                                      color: isOnline ? Colors.green.withOpacity(0.15) : Colors.grey.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: isOnline ? Colors.green.withOpacity(0.4) : Colors.grey.withOpacity(0.2)),
                                    ),
                                    child: Center(
                                      child: SvgPicture.string(AppSvgIcons.mobile, width: 20, height: 20,
                                          colorFilter: ColorFilter.mode(isOnline ? Colors.green : Colors.grey, BlendMode.srcIn)),
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('+${s['phone'] ?? s['id']}',
                                            style: TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                                                color: isOnline ? Colors.white : AppTheme.textMuted, letterSpacing: 0.5)),
                                        SizedBox(height: 3),
                                        Row(children: [
                                          Container(width: 6, height: 6,
                                              decoration: BoxDecoration(shape: BoxShape.circle,
                                                  color: isOnline ? Colors.green : Colors.grey)),
                                          SizedBox(width: 6),
                                          Text(isOnline ? tr('sender_terhubung') : 'Terputus',
                                              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                                                  color: isOnline ? Colors.green : Colors.grey, letterSpacing: 1)),
                                        ]),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    width: 22, height: 22,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isSelected ? AppTheme.primaryBlue : Colors.transparent,
                                      border: Border.all(color: isSelected ? AppTheme.primaryBlue : AppTheme.textMuted.withOpacity(0.4)),
                                    ),
                                    child: isSelected
                                        ? const Icon(Icons.check, size: 13, color: Colors.white)
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  SizedBox(height: 14),
                  // Confirm button
                  GestureDetector(
                    onTap: tempSelected.isEmpty ? null : () {
                      setState(() {
                        _selectedSenderIds = tempSelected.toList();
                        _selectAll = tempSelectAll;
                        // set _selectedSenderId to first for display
                        _selectedSenderId = _selectedSenderIds.first;
                        final found = _senders.where((s) => s['id'] == _selectedSenderId).toList();
                        _selectedSenderPhone = found.isNotEmpty ? (found.first['phone'] ?? found.first['id']) : _selectedSenderId;
                      });
                      Navigator.pop(context);
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        gradient: tempSelected.isEmpty ? null : AppTheme.primaryGradient,
                        color: tempSelected.isEmpty ? AppTheme.primaryBlue.withOpacity(0.1) : null,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: tempSelected.isEmpty
                            ? AppTheme.primaryBlue.withOpacity(0.2)
                            : AppTheme.primaryBlue),
                      ),
                      child: Center(
                        child: Text(
                          tempSelected.isEmpty
                              ? 'Pilih Sender Dulu'
                              : 'Konfirmasi ${tempSelected.length} Sender',
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 12,
                            letterSpacing: 1.5,
                            color: tempSelected.isEmpty ? AppTheme.textMuted : Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: 10),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _handleBanned() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D0D),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(children: const [
          Icon(Icons.gavel_rounded, color: Colors.redAccent, size: 22),
          SizedBox(width: 10),
          Text('AKUN DIBANNED', style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 13, color: Colors.redAccent, letterSpacing: 2)),
        ]),
        content: const Text(
          'Akun kamu telah dibanned karena mencoba bug nomor/grup yang dilindungi oleh owner.\n\nKamu tidak bisa login lagi.',
          style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Color(0xFF64B5F6), height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context, rootNavigator: true).pop();
              Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const LoginScreen()),
                (route) => false,
              );
            },
            child: const Text('OK', style: TextStyle(color: Colors.redAccent, fontFamily: 'Orbitron')),
          ),
        ],
      ),
    );
  }

  bool _isValidPhoneNumber(String input) {
    // Tolak jika ada +, spasi, atau -
    if (input.contains('+') || input.contains(' ') || input.contains('-')) return false;
    // Harus semua angka, support semua kode negara
    return RegExp(r'^\d+$').hasMatch(input);
  }

  Future<void> _execute() async {
    final activeSenders = <String>[...(_selectAll
        ? _senders.where((s) => s['status'] == 'online' || s['status'] == 'connected').map((s) => s['id'] as String).toList()
        : _selectedSenderIds.isNotEmpty ? _selectedSenderIds : (_selectedSenderId != null ? [_selectedSenderId!] : []))];

    if (activeSenders.isEmpty) { _showSnack('Pilih Sender Terlebih Dahulu'); return; }
    if (_selectedMethod == null) { _showSnack('Pilih Metode Bug'); return; }
    final rawTarget = _targetCtrl.text.trim();
    if (rawTarget.isEmpty) { _showSnack('Masukkan Nomer Target'); return; }
    if (!_isValidPhoneNumber(rawTarget)) {
      _showSnack('Format Salah! Gunakan Angka Saja Tanpa +/Spasi/-', isError: true);
      return;
    }
    final count = int.tryParse(_countCtrl.text.trim()) ?? 20;
    if (count < 20) { _showSnack('Jumlah Pesan Minimal 20', isError: true); return; }
    if (count > 999) { _showSnack('Jumlah Pesan Maksimal 999', isError: true); return; }

    setState(() { _executing = true; _jobStatus = 'running'; _jobError = ''; });

    try {
      final method = _methods[_selectedMethod!]['id'] as String;
      final res = activeSenders.length > 1
          ? await ApiService.executeBugMulti(
              senderIds: activeSenders, target: rawTarget,
              method: method, delay: _delaySeconds, count: count,
            )
          : await ApiService.executeBug(
              senderId: activeSenders.first, target: rawTarget,
              method: method, delay: _delaySeconds, count: count,
            );

      if (res['banned'] == true) {
        setState(() { _executing = false; _jobStatus = 'error'; });
        _handleBanned();
        return;
      }

      if (res['success'] != true) {
        setState(() { _executing = false; _jobStatus = 'error'; });
        _showSnack(res['message'] ?? 'Gagal Mengirim Bug', isError: true);
        return;
      }

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() { _executing = false; _jobStatus = ''; });
      _showSnack('Bug Berhasil Dikirim Dari ${activeSenders.length} Sender!', isSuccess: true);
    } catch (_) {
      setState(() { _executing = false; _jobStatus = 'error'; });
      _showSnack('Koneksi Gagal Ke Server', isError: true);
    }
  }

  Future<void> _executeGroup() async {
    final activeSenders = <String>[...(_selectAll
        ? _senders.where((s) => s['status'] == 'online' || s['status'] == 'connected').map((s) => s['id'] as String).toList()
        : _selectedSenderIds.isNotEmpty ? _selectedSenderIds : (_selectedSenderId != null ? [_selectedSenderId!] : []))];

    if (activeSenders.isEmpty)        { _showSnack('Pilih Sender Terlebih Dahulu'); return; }
    if (_selectedGroupMethod == null) { _showSnack('Pilih Metode Bug Grup'); return; }
    if (_groupTargetCtrl.text.isEmpty){ _showSnack('Masukkan ID Grup Target'); return; }
    final count = int.tryParse(_groupCountCtrl.text.trim()) ?? 20;
    if (count < 20)  { _showSnack('Jumlah Pesan Minimal 20', isError: true); return; }
    if (count > 999) { _showSnack('Jumlah Pesan Maksimal 999', isError: true); return; }

    setState(() { _executingGroup = true; _groupJobStatus = 'running'; _groupJobError = ''; });

    try {
      final method = _groupMethods[_selectedGroupMethod!]['id'] as String;
      final res = activeSenders.length > 1
          ? await ApiService.executeBugGroupMulti(
              senderIds: activeSenders, target: _groupTargetCtrl.text.trim(),
              method: method, delay: _groupDelay, count: count,
            )
          : await ApiService.executeBugGroup(
              senderId: activeSenders.first, target: _groupTargetCtrl.text.trim(),
              method: method, delay: _groupDelay, count: count,
            );

      if (res['banned'] == true) {
        setState(() { _executingGroup = false; _groupJobStatus = 'error'; });
        _handleBanned();
        return;
      }

      if (res['success'] != true) {
        setState(() { _executingGroup = false; _groupJobStatus = 'error'; });
        _showSnack(res['message'] ?? 'Gagal Mengirim Bug Grup', isError: true);
        return;
      }

      await Future.delayed(const Duration(seconds: 5));
      if (!mounted) return;
      setState(() { _executingGroup = false; _groupJobStatus = ''; });
      _showSnack('Bug Grup Dikirim Dari ${activeSenders.length} Sender!', isSuccess: true);
    } catch (_) {
      setState(() { _executingGroup = false; _groupJobStatus = 'error'; });
      _showSnack('Koneksi Gagal Ke Server', isError: true);
    }
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

  void _showSuccessVideo() {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (_) => const _SuccessVideoDialog(),
    );
  }

  Widget _buildJobStatus({bool isGroup = false}) {
    final status   = isGroup ? _groupJobStatus   : _jobStatus;
    final progress = isGroup ? _groupJobProgress : _jobProgress;
    final total    = isGroup ? _groupJobTotal    : _jobTotal;
    final error    = isGroup ? _groupJobError    : _jobError;

    if (status.isEmpty) return const SizedBox.shrink();

    final isDone  = status == 'done';
    final isError = status == 'error';
    final color   = isDone ? Colors.green : isError ? Colors.red : AppTheme.primaryBlue;
    final label   = isDone ? 'Selesai' : isError ? 'Error' : 'Mengirim...';

    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                color: color, letterSpacing: 2, fontWeight: FontWeight.bold)),
            Text('$progress / $total', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                color: color, fontWeight: FontWeight.bold)),
          ]),
          if (total > 0) ...[
            SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: total > 0 ? progress / total : 0,
                backgroundColor: color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 6,
              ),
            ),
          ],
          if (error.isNotEmpty) ...[
            SizedBox(height: 8),
            Text('⚠ $error', style: const TextStyle(fontFamily: 'ShareTechMono',
                fontSize: 10, color: Colors.redAccent)),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileBadge(),
            SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.6), width: 1.5),
                boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.2), blurRadius: 14, spreadRadius: 1)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(13),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _BannerSlider(),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(children: [
                  Container(width: 3, height: 20,
                      decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                  SizedBox(width: 10),
                  Text(tr('bug_wa'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 18,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                ]),
                GestureDetector(
                  onTap: _loadSenders,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.4)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: _loadingSenders
                        ? SizedBox(width: 16, height: 16,
                            child: CircularProgressIndicator(strokeWidth: 1.5, color: AppTheme.primaryBlue))
                        : const Icon(Icons.refresh, color: AppTheme.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            _buildLabel(tr('pick_sender')),
            SizedBox(height: 8),
            GestureDetector(
              onTap: _showSenderPicker,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _selectedSenderId != null ? AppTheme.primaryBlue : AppTheme.primaryBlue.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _selectedSenderId != null ? Colors.green.withOpacity(0.15) : AppTheme.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedSenderId != null ? Colors.green.withOpacity(0.4) : AppTheme.primaryBlue.withOpacity(0.3)),
                      ),
                      child: Center(
                        child: SvgPicture.string(AppSvgIcons.phone, width: 18, height: 18,
                            colorFilter: ColorFilter.mode(
                                _selectedSenderId != null ? Colors.green : AppTheme.textMuted, BlendMode.srcIn)),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _selectedSenderIds.length > 1
                                ? '${_selectedSenderIds.length} Sender Dipilih'
                                : _selectedSenderId != null
                                    ? '+${_selectedSenderPhone ?? _selectedSenderId}'
                                    : 'Pilih Nomer Sender...',
                            style: TextStyle(
                                fontFamily: _selectedSenderId != null ? 'Orbitron' : 'ShareTechMono',
                                fontSize: _selectedSenderId != null ? 13 : 12,
                                color: _selectedSenderId != null ? Colors.white : AppTheme.textMuted,
                                letterSpacing: _selectedSenderId != null ? 0.5 : 0),
                          ),
                          if (_selectedSenderId != null) ...[
                            SizedBox(height: 2),
                            Row(children: [
                              Container(width: 5, height: 5,
                                  decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green)),
                              SizedBox(width: 5),
                              Text(
                                _selectedSenderIds.length > 1 ? 'Multi Sender Aktif' : tr('sender_terhubung'),
                                style: TextStyle(fontFamily: 'ShareTechMono',
                                    fontSize: 9, color: Colors.green, letterSpacing: 1)),
                            ]),
                          ],
                        ],
                      ),
                    ),
                    const Icon(Icons.keyboard_arrow_down_rounded, color: AppTheme.textMuted, size: 22),
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  _buildTabButton(0, 'BUG NOMER', AppSvgIcons.mobile),
                  _buildTabButton(1, 'BUG GROUP', AppSvgIcons.group),
                ],
              ),
            ),
            SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: AnimatedBuilder(
        animation: _tabController,
        builder: (context, _) {
          final isGroup = _tabController.index == 1;
          return isGroup ? _buildGroupScrollView() : _buildNomerScrollView();
        },
      ),
    );
  }

  Widget _buildNomerScrollView() {
    return CustomScrollView(
      slivers: [
        _buildHeader(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Nomer Target'),
                SizedBox(height: 8),
                TextFormField(
                  controller: _targetCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono'),
                  decoration: InputDecoration(
                    hintText: '628xxx / 1234xxx / 44xxxx',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 13),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.string(AppSvgIcons.mobile, width: 18, height: 18,
                          colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                _buildCountDelayCard(_countCtrl, _delaySeconds, (v) => setState(() => _delaySeconds = v)),
                SizedBox(height: 24),
                _buildLabel('Pilih Metode'),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildMethodCard(i)),
              childCount: _methods.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildJobStatus(isGroup: false)),
        SliverToBoxAdapter(child: _buildSendButton(_executing, _selectedMethod, _execute, 'SEND BUG NOMER')),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildGroupScrollView() {
    return CustomScrollView(
      slivers: [
        _buildHeader(),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildLabel('Link Grup Target'),
                SizedBox(height: 8),
                TextFormField(
                  controller: _groupTargetCtrl,
                  keyboardType: TextInputType.text,
                  style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono'),
                  decoration: InputDecoration(
                    hintText: 'https://chat.whatsapp.com/xxxx',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.5), fontSize: 12),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.all(12),
                      child: SvgPicture.string(AppSvgIcons.group, width: 18, height: 18,
                          colorFilter: const ColorFilter.mode(AppTheme.textSecondary, BlendMode.srcIn)),
                    ),
                  ),
                ),
                SizedBox(height: 16),
                _buildCountDelayCard(_groupCountCtrl, _groupDelay, (v) => setState(() => _groupDelay = v)),
                SizedBox(height: 24),
                _buildLabel('Pilih Metode'),
                SizedBox(height: 12),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => Padding(padding: const EdgeInsets.only(bottom: 12), child: _buildGroupMethodCard(i)),
              childCount: _groupMethods.length,
            ),
          ),
        ),
        SliverToBoxAdapter(child: _buildJobStatus(isGroup: true)),
        SliverToBoxAdapter(child: _buildSendButton(_executingGroup, _selectedGroupMethod, _executeGroup, 'SEND BUG GROUP')),
        const SliverToBoxAdapter(child: SizedBox(height: 80)),
      ],
    );
  }

  Widget _buildTabButton(int index, String label, String icon) {
    final isActive = _tabController.index == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabController.animateTo(index)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.all(4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            gradient: isActive ? AppTheme.primaryGradient : null,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive ? [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.4), blurRadius: 8)] : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.string(icon, width: 14, height: 14,
                  colorFilter: ColorFilter.mode(isActive ? Colors.white : AppTheme.textMuted, BlendMode.srcIn)),
              SizedBox(width: 6),
              Text(label, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
                  fontWeight: FontWeight.bold, color: isActive ? Colors.white : AppTheme.textMuted, letterSpacing: 1)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCountDelayCard(TextEditingController countCtrl, double delayVal, ValueChanged<double> onDelayChanged) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Jumlah Pesan'),
              Row(children: [
                GestureDetector(
                  onTap: () {
                    final v = int.tryParse(countCtrl.text) ?? 20;
                    if (v > 20) setState(() => countCtrl.text = (v - 1).toString());
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5)),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.remove, color: Colors.white, size: 14),
                  ),
                ),
                SizedBox(width: 8),
                SizedBox(
                  width: 56,
                  child: TextFormField(
                    controller: countCtrl,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 6),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide: const BorderSide(color: AppTheme.primaryBlue),
                      ),
                      filled: true,
                      fillColor: AppTheme.primaryBlue.withOpacity(0.08),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    final v = int.tryParse(countCtrl.text) ?? 50;
                    if (v < 999) setState(() => countCtrl.text = (v + 1).toString());
                  },
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(
                      gradient: AppTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
              ]),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildLabel('Delay Antar Pesan'),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(6)),
                child: Text('${delayVal.toStringAsFixed(1)}s',
                    style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white,
                        fontWeight: FontWeight.bold, letterSpacing: 1)),
              ),
            ],
          ),
          SizedBox(height: 8),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: AppTheme.primaryBlue,
              inactiveTrackColor: AppTheme.primaryBlue.withOpacity(0.2),
              thumbColor: Colors.white,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayColor: AppTheme.primaryBlue.withOpacity(0.2),
              trackHeight: 3,
            ),
            child: Slider(value: delayVal, min: 0.5, max: 10.0, divisions: 19, onChanged: onDelayChanged),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('0.5s', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
              Text('10s',  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSendButton(bool executing, int? selected, VoidCallback onTap, String label) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: executing || selected == null ? null : AppTheme.primaryGradient,
          color: executing || selected == null ? AppTheme.primaryBlue.withOpacity(0.3) : null,
          borderRadius: BorderRadius.circular(14),
          boxShadow: executing || selected == null ? [] : [
            BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.5), blurRadius: 20, offset: const Offset(0, 4))
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: executing || selected == null ? null : onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent, shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
          ),
          icon: executing
              ? SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Icon(Icons.send_rounded, size: 22, color: Colors.white),
          label: Text(executing ? 'Mengirim...' : label,
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 2)),
        ),
      ),
    );
  }

  Widget _buildProfileBadge() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [AppTheme.primaryBlue.withOpacity(0.25), AppTheme.cardBg],
            begin: Alignment.centerLeft, end: Alignment.centerRight),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.5)),
        boxShadow: [BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.15), blurRadius: 12)],
      ),
      child: Row(
        children: [
          // === Foto user — border biru seperti login, rotating ===
          RoleStyle.instagramPhoto(
            assetPath: _avatarBase64 == null ? 'assets/icons/revenge.jpg' : null,
            customImage: _avatarBase64 != null ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover) : null,
            colors: RoleStyle.loginBorderColors,
            rotateAnim: _rotateAnim,
            glowAnim: _glowAnim,
            size: 48,
            borderWidth: 2.5,
            innerPad: 2,
            fallback: Container(color: AppTheme.primaryBlue.withOpacity(0.3),
              child: Center(child: SvgPicture.string(AppSvgIcons.user, width: 22, height: 22,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
          ),
          SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_username.isEmpty ? '...' : _username,
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                  fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
            SizedBox(height: 5),
            // === Badge role sesuai warna ===
            RoleStyle.roleBadge(_role),
          ])),
          Container(width: 8, height: 8,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green,
              boxShadow: [BoxShadow(color: Colors.green, blurRadius: 6)])),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(text, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: AppTheme.textMuted, letterSpacing: 2));
  }

  Widget _buildMethodCard(int index) {
    final method = _methods[index];
    final isSelected = _selectedMethod == index;
    final color = method['color'] as Color;
    return GestureDetector(
      onTap: () => setState(() => _selectedMethod = isSelected ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)])
              : AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : AppTheme.primaryBlue.withOpacity(0.25), width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Center(child: SvgPicture.string(method['icon'] as String, width: 22, height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
            ),
            SizedBox(width: 14),
            Expanded(child: Text(method['title'] as String,
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.white, letterSpacing: 0.5))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(color: isSelected ? color : AppTheme.textMuted, width: 1.5),
              ),
              child: isSelected
                  ? Center(child: SvgPicture.string(AppSvgIcons.zap, width: 11, height: 11,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupMethodCard(int index) {
    final method = _groupMethods[index];
    final isSelected = _selectedGroupMethod == index;
    final color = method['color'] as Color;
    return GestureDetector(
      onTap: () => setState(() => _selectedGroupMethod = isSelected ? null : index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [color.withOpacity(0.2), color.withOpacity(0.05)])
              : AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isSelected ? color : AppTheme.primaryBlue.withOpacity(0.25), width: isSelected ? 1.5 : 1),
          boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.2), blurRadius: 10)] : [],
        ),
        child: Row(
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withOpacity(0.4)),
              ),
              child: Center(child: SvgPicture.string(method['icon'] as String, width: 22, height: 22,
                  colorFilter: ColorFilter.mode(color, BlendMode.srcIn))),
            ),
            SizedBox(width: 14),
            Expanded(child: Text(method['title'] as String,
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold,
                    color: isSelected ? color : Colors.white, letterSpacing: 0.5))),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? color : Colors.transparent,
                border: Border.all(color: isSelected ? color : AppTheme.textMuted, width: 1.5),
              ),
              child: isSelected
                  ? Center(child: SvgPicture.string(AppSvgIcons.zap, width: 11, height: 11,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Banner Slider Widget ────────────────────────────────────────────────────
class _BannerSlider extends StatefulWidget {
  const _BannerSlider();

  @override
  State<_BannerSlider> createState() => _BannerSliderState();
}

class _BannerSliderState extends State<_BannerSlider> {
  final PageController _ctrl = PageController();
  int _current = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      final next = (_current + 1) % 5;
      _ctrl.animateToPage(next, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          controller: _ctrl,
          itemCount: 5,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) => Image.asset(
            'assets/images/banner${i + 1}.jpg',
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              color: AppTheme.cardBg,
              child: Center(child: Icon(Icons.image_not_supported, color: AppTheme.textMuted)),
            ),
          ),
        ),
        // Gradient overlay at bottom
        Positioned(
          bottom: 0, left: 0, right: 0,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [Colors.black.withOpacity(0.7), Colors.transparent],
              ),
            ),
          ),
        ),
        // Owner text bottom left
        Positioned(
          bottom: 8, left: 10,
          child: Text(
            'Buy Role? Chat @Zal7Sex',
            style: const TextStyle(
              fontFamily: 'ShareTechMono',
              fontSize: 11,
              color: Colors.white70,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Dot indicators bottom right
        Positioned(
          bottom: 8, right: 10,
          child: Row(
            children: List.generate(5, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: _current == i ? 14 : 6,
              height: 6,
              decoration: BoxDecoration(
                color: _current == i ? AppTheme.accentBlue : Colors.white38,
                borderRadius: BorderRadius.circular(3),
              ),
            )),
          ),
        ),
      ],
    );
  }
}

// ─── Success Video Dialog ────────────────────────────────────────────────────
class _SuccessVideoDialog extends StatefulWidget {
  const _SuccessVideoDialog();

  @override
  State<_SuccessVideoDialog> createState() => _SuccessVideoDialogState();
}

class _SuccessVideoDialogState extends State<_SuccessVideoDialog> {
  VideoPlayerController? _ctrl;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _ctrl = VideoPlayerController.asset('assets/video/sukses.mp4')
      ..initialize().then((_) {
        if (mounted) {
          setState(() => _initialized = true);
          _ctrl!.setLooping(false);
          _ctrl!.setVolume(1.0);
          _ctrl!.play();
          // Auto close when done
          _ctrl!.addListener(() {
            if (_ctrl!.value.position >= _ctrl!.value.duration && mounted) {
              Navigator.of(context, rootNavigator: true).pop();
            }
          });
        }
      });
  }

  @override
  void dispose() {
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double aspectRatio = _initialized ? _ctrl!.value.aspectRatio : 16 / 9;
    final double maxWidth = MediaQuery.of(context).size.width - 40;
    final double videoHeight = maxWidth / aspectRatio;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Container(
            width: maxWidth,
            height: _initialized ? videoHeight : null,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.primaryBlue, width: 2),
              boxShadow: [
                BoxShadow(color: AppTheme.primaryBlue.withOpacity(0.5), blurRadius: 20, spreadRadius: 2),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(15),
              child: _initialized
                  ? AspectRatio(
                      aspectRatio: aspectRatio,
                      child: VideoPlayer(_ctrl!),
                    )
                  : Container(
                      height: 180,
                      color: Colors.black,
                      child: Center(
                        child: CircularProgressIndicator(color: AppTheme.primaryBlue, strokeWidth: 2),
                      ),
                    ),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context, rootNavigator: true).pop(),
            child: Container(
              margin: const EdgeInsets.all(8),
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black54,
                border: Border.all(color: Colors.white30),
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}
