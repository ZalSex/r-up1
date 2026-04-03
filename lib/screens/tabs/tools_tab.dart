import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/theme.dart';
import '../../utils/notif_helper.dart';
import '../../utils/app_localizations.dart';
import '../../utils/role_style.dart';
import '../../services/api_service.dart';
import '../ddos_screen.dart';
import '../downloader_screen.dart';
import '../iqc_screen.dart';
import '../spam_pairing_screen.dart';
import '../wa_call_screen.dart';
import '../remini_screen.dart';
import '../spam_ngl_screen.dart';

class ToolsTab extends StatefulWidget {
  const ToolsTab({super.key});

  @override
  State<ToolsTab> createState() => _ToolsTabState();
}

class _ToolsTabState extends State<ToolsTab> with TickerProviderStateMixin {
  String _username = '';
  String _role = 'member';
  String? _avatarBase64;

  late AnimationController _rotateCtrl;
  late Animation<double> _rotateAnim;
  late AnimationController _glowCtrl;
  late Animation<double> _glowAnim;

  static const List<Map<String, dynamic>> _tools = [
    { 'icon': AppSvgIcons.zap,     'title': 'DDoS Tool',     'color': Color(0xFFEF4444), 'route': 'ddos' },
    { 'icon': AppSvgIcons.download,'title': 'Downloader',    'color': Color(0xFF06B6D4), 'route': 'downloader' },
    { 'icon': AppSvgIcons.quote,   'title': 'iPhone Quote',  'color': Color(0xFF8B5CF6), 'route': 'iqc' },
    { 'icon': AppSvgIcons.wifi,    'title': 'Spam Pairing',  'color': Color(0xFF3B82F6), 'route': 'spam_pairing' },
    { 'icon': AppSvgIcons.phone,   'title': 'WhatsApp Call', 'color': Color(0xFFF59E0B), 'route': 'wa_call' },
    { 'icon': AppSvgIcons.image,   'title': 'Remini AI',     'color': Color(0xFF8B5CF6), 'route': 'remini' },
    { 'icon': AppSvgIcons.sms,     'title': 'Spam NGL',      'color': Color(0xFFEC4899), 'route': 'spam_ngl' },
    // Maker tools
    { 'icon': AppSvgIcons.zap,     'isMaker': true, 'title': 'Lobby FF',     'color': Color(0xFFFF6B00), 'route': 'lobby_ff' },
    { 'icon': AppSvgIcons.user,    'isMaker': true, 'title': 'Lobby ML',     'color': Color(0xFF3B82F6), 'route': 'lobby_ml' },
    { 'icon': AppSvgIcons.quote,   'isMaker': true, 'title': 'Fake Story',   'color': Color(0xFFEC4899), 'route': 'fake_story' },
    { 'icon': AppSvgIcons.sms,     'isMaker': true, 'title': 'Fake Threads', 'color': Color(0xFF6B7280), 'route': 'fake_threads' },
    { 'icon': AppSvgIcons.image,   'isMaker': true, 'title': 'QC Card',      'color': Color(0xFF10B981), 'route': 'qc' },
    { 'icon': AppSvgIcons.image,   'isMaker': true, 'title': 'Smeme',        'color': Color(0xFF8B5CF6), 'route': 'smeme' },
    { 'icon': AppSvgIcons.smile,   'isMaker': true, 'title': 'Brat Anime',   'color': Color(0xFF22D3EE), 'route': 'brat_anime' },
    { 'icon': AppSvgIcons.imageOutlined, 'isMaker': true, 'title': 'Meme Ustadz', 'color': Color(0xFF84CC16), 'route': 'meme_ustadz' },
    // Image Editor Tools
    { 'icon': AppSvgIcons.image,   'title': 'Blur Face',     'color': Color(0xFFA855F7), 'route': 'blur_face', 'isImageEditor': true },
    { 'icon': AppSvgIcons.image,   'title': 'Remove BG',     'color': Color(0xFF10B981), 'route': 'remove_bg', 'isImageEditor': true },
    { 'icon': AppSvgIcons.image,   'title': 'Wasted',        'color': Color(0xFFF97316), 'route': 'wasted', 'isImageEditor': true },
    { 'icon': AppSvgIcons.image,   'title': 'Wanted',        'color': Color(0xFFEF4444), 'route': 'wanted', 'isImageEditor': true },
    // Text Tools
    { 'icon': AppSvgIcons.quote,   'title': 'NIK Parse',     'color': Color(0xFF06B6D4), 'route': 'nik_parse', 'isTextTool': true },
  ];

  // Ikon untuk semua tool - perbaiki return type menjadi IconData
  IconData _getToolIcon(String route) {
    const Map<String, IconData> icons = {
      'lobby_ff': Icons.sports_esports_rounded,
      'lobby_ml': Icons.videogame_asset_rounded,
      'fake_story': Icons.auto_stories_rounded,
      'fake_threads': Icons.forum_rounded,
      'qc': Icons.style_rounded,
      'smeme': Icons.image_rounded,
      'brat_anime': Icons.animation_rounded,
      'meme_ustadz': Icons.sentiment_very_satisfied_rounded,
      'blur_face': Icons.blur_on_rounded,
      'remove_bg': Icons.crop_original_rounded,
      'wasted': Icons.warning_rounded,
      'wanted': Icons.gavel_rounded,
      'nik_parse': Icons.numbers_rounded,
    };
    return icons[route] ?? Icons.image_rounded;
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _rotateCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 4))..repeat();
    _rotateAnim = Tween<double>(begin: 0.0, end: 1.0).animate(_rotateCtrl);
    _glowCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _glowAnim = Tween<double>(begin: 0.3, end: 1.0).animate(_glowCtrl);
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    _glowCtrl.dispose();
    super.dispose();
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

  void _navigate(BuildContext context, String? route, String title) {
    if (route == null) { _showComingSoon(context, title); return; }
    Widget? screen;
    switch (route) {
      case 'ddos':         screen = const DdosScreen(); break;
      case 'downloader':   screen = const DownloaderScreen(); break;
      case 'iqc':          screen = const IqcScreen(); break;
      case 'spam_pairing': screen = const SpamPairingScreen(); break;
      case 'wa_call':      screen = const WaCallScreen(); break;
      case 'remini':       screen = const ReminiScreen(); break;
      case 'spam_ngl':     screen = const SpamNglScreen(); break;
      default:             _showComingSoon(context, title); return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen!));
  }

  void _openMakerTool(BuildContext context, String route, String title) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _MakerToolScreen(route: route, title: title),
    ));
  }

  void _openImageEditorTool(BuildContext context, String route, String title) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => _ImageEditorToolScreen(route: route, title: title),
    ));
  }

  void _openNikParseTool(BuildContext context, String title) {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => const _NikParseToolScreen(),
    ));
  }

  void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.cardBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: AppTheme.primaryBlue.withOpacity(0.5))),
        title: Row(children: [
          Container(width: 3, height: 18,
            decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
          const SizedBox(width: 10),
          Text(title.toUpperCase(), style: const TextStyle(fontFamily: 'Orbitron',
              color: Colors.white, fontSize: 13, letterSpacing: 1.5)),
        ]),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: AppTheme.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.3))),
            child: Column(children: [
              SvgPicture.string(AppSvgIcons.zap, width: 36, height: 36,
                colorFilter: ColorFilter.mode(Colors.orange.withOpacity(0.8), BlendMode.srcIn)),
              const SizedBox(height: 12),
              Text(tr('coming_soon'), style: const TextStyle(fontFamily: 'Orbitron',
                  fontSize: 14, color: Colors.orange, letterSpacing: 2, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(tr('coming_soon_body'),
                textAlign: TextAlign.center,
                style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textMuted, height: 1.6)),
            ])),
        ]),
        actions: [
          Container(decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(8)),
            child: TextButton(onPressed: () => Navigator.pop(context),
              child: const Text('Ok', style: TextStyle(fontFamily: 'Orbitron', color: Colors.white, fontSize: 11, letterSpacing: 1)))),
        ],
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
      child: Row(children: [
        RoleStyle.instagramPhoto(
          assetPath: _avatarBase64 == null ? 'assets/icons/revenge.jpg' : null,
          customImage: _avatarBase64 != null ? Image.memory(base64Decode(_avatarBase64!), fit: BoxFit.cover) : null,
          colors: RoleStyle.loginBorderColors,
          rotateAnim: _rotateAnim,
          glowAnim: _glowAnim,
          size: 48, borderWidth: 2.5, innerPad: 2,
          fallback: Container(color: AppTheme.primaryBlue.withOpacity(0.3),
            child: Center(child: SvgPicture.string(AppSvgIcons.user, width: 22, height: 22,
                colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)))),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_username.isEmpty ? '...' : _username,
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 13,
                fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5)),
          const SizedBox(height: 5),
          RoleStyle.roleBadge(_role),
        ])),
        Container(width: 8, height: 8,
          decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.green,
            boxShadow: [BoxShadow(color: Colors.green, blurRadius: 6)])),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
      child: CustomScrollView(slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 20)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _buildProfileBadge(),
              const SizedBox(height: 16),
              Row(children: [
                Container(width: 3, height: 20,
                  decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                const SizedBox(width: 10),
                Text(tr('tools_title'), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 18,
                    fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
              ]),
              const SizedBox(height: 20),
            ]),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, childAspectRatio: 1.05, crossAxisSpacing: 14, mainAxisSpacing: 14),
            delegate: SliverChildBuilderDelegate(
              (ctx, i) => _buildToolCard(ctx, _tools[i]),
              childCount: _tools.length),
          ),
        ),
        SliverToBoxAdapter(child: SizedBox(height: MediaQuery.of(context).padding.bottom + 90)),
      ]),
    );
  }

  Widget _buildToolCard(BuildContext context, Map<String, dynamic> tool) {
    final color = tool['color'] as Color;
    final isMaker = tool['isMaker'] == true;
    final isImageEditor = tool['isImageEditor'] == true;
    final isTextTool = tool['isTextTool'] == true;
    final route = tool['route'] as String;
    final title = tool['title'] as String;

    // Dapatkan ikon yang sesuai
    IconData iconData = _getToolIcon(route);
    
    // Untuk maker tools yang punya SVG icon, prioritaskan SVG
    final hasSvgIcon = tool.containsKey('icon') && tool['icon'] != null;
    final svgIconString = hasSvgIcon ? tool['icon'] as String : null;

    Widget iconWidget;
    if (svgIconString != null) {
      iconWidget = SvgPicture.string(svgIconString, width: 20, height: 20,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn));
    } else {
      iconWidget = Icon(iconData, color: color, size: 20);
    }

    VoidCallback? onTap;
    if (isMaker) {
      onTap = () => _openMakerTool(context, route, title);
    } else if (isImageEditor) {
      onTap = () => _openImageEditorTool(context, route, title);
    } else if (isTextTool) {
      onTap = () => _openNikParseTool(context, title);
    } else {
      onTap = () => _navigate(context, route, title);
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 10)],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withOpacity(0.5))),
              child: Center(child: iconWidget),
            ),
            const SizedBox.shrink(),
          ]),
          const Spacer(),
          Text(title,
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, fontWeight: FontWeight.bold,
                color: Colors.white, letterSpacing: 0.5)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// IMAGE EDITOR TOOL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _ImageEditorToolScreen extends StatefulWidget {
  final String route;
  final String title;
  const _ImageEditorToolScreen({required this.route, required this.title});

  @override
  State<_ImageEditorToolScreen> createState() => _ImageEditorToolScreenState();
}

class _ImageEditorToolScreenState extends State<_ImageEditorToolScreen> {
  XFile? _imageFile;
  String? _uploadedUrl;
  bool _uploading = false;
  bool _loading = false;
  String? _resultImageUrl;
  String? _error;

  String get _apiUrl {
    switch (widget.route) {
      case 'blur_face':
        return 'https://api.nexray.web.id/tools/blurface';
      case 'remove_bg':
        return 'https://api.nexray.web.id/tools/removebg';
      case 'wasted':
        return 'https://api.nexray.web.id/editor/wasted';
      case 'wanted':
        return 'https://api.nexray.web.id/editor/wanted';
      default:
        return '';
    }
  }

  Color get _toolColor {
    const colors = {
      'blur_face': Color(0xFFA855F7),
      'remove_bg': Color(0xFF10B981),
      'wasted': Color(0xFFF97316),
      'wanted': Color(0xFFEF4444),
    };
    return colors[widget.route] ?? AppTheme.accentBlue;
  }

  Future<void> _pickAndUploadImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() {
      _imageFile = file;
      _uploadedUrl = null;
      _uploading = true;
      _error = null;
      _resultImageUrl = null;
    });

    final url = await _uploadToCatbox(file);
    if (mounted) {
      setState(() {
        _uploading = false;
        if (url != null) {
          _uploadedUrl = url;
        } else {
          _error = 'Gagal upload ke catbox, coba lagi';
          _imageFile = null;
        }
      });
    }
  }

  Future<String?> _uploadToCatbox(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(http.MultipartFile.fromBytes(
        'fileToUpload',
        bytes,
        filename: file.name.isEmpty ? 'image.jpg' : file.name,
      ));
      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = await response.stream.bytesToString();
      if (body.startsWith('https://')) return body.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _processImage() async {
    if (_uploadedUrl == null || _uploadedUrl!.isEmpty) {
      showWarning(context, 'Upload gambar terlebih dahulu');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _resultImageUrl = null;
    });

    try {
      final url = '$_apiUrl?url=${Uri.encodeComponent(_uploadedUrl!)}';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final contentType = res.headers['content-type'] ?? '';
        if (contentType.contains('image')) {
          final b64 = base64Encode(res.bodyBytes);
          final ext = contentType.contains('png') ? 'png' : 'jpg';
          setState(() => _resultImageUrl = 'data:image/$ext;base64,$b64');
        } else {
          try {
            final json = jsonDecode(res.body);
            final imgUrl = json['result'] ?? json['url'] ?? json['image'] ?? json['data'];
            if (imgUrl != null) {
              setState(() => _resultImageUrl = imgUrl.toString());
            } else {
              setState(() => _error = 'Tidak ada gambar dalam response');
            }
          } catch (_) {
            setState(() => _error = 'Response tidak valid');
          }
        }
      } else {
        setState(() => _error = 'API Error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _downloadImage() async {
    if (_resultImageUrl == null) return;
    try {
      final dir = Directory('/storage/emulated/0/Pictures/Pegasus-X');
      if (!await dir.exists()) await dir.create(recursive: true);
      final fileName = '${widget.route}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      if (_resultImageUrl!.startsWith('data:')) {
        final data = _resultImageUrl!.split(',')[1];
        await file.writeAsBytes(base64Decode(data));
      } else {
        final res = await http.get(Uri.parse(_resultImageUrl!));
        await file.writeAsBytes(res.bodyBytes);
      }
      if (mounted) {
        showSuccess(context, 'Tersimpan: ${dir.path}/$fileName');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Gagal download: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _toolColor;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
        title: Text(widget.title.toUpperCase(),
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          if (_resultImageUrl != null)
            IconButton(
              onPressed: _downloadImage,
              icon: Icon(Icons.download_rounded, color: color),
              tooltip: 'Download'),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // Image picker section
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Pilih Gambar', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _uploading ? null : _pickAndUploadImage,
                child: Container(
                  width: double.infinity,
                  height: _imageFile != null ? 200 : 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _uploadedUrl != null ? Colors.green.withOpacity(0.6) : color.withOpacity(0.4),
                      width: 1.5,
                    ),
                    color: AppTheme.cardBg,
                  ),
                  child: _uploading
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                          SizedBox(height: 8),
                          Text('Mengupload ke catbox...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.orange)),
                        ]),
                      )
                    : _imageFile != null
                      ? Stack(children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(11),
                            child: Image.file(File(_imageFile!.path), width: double.infinity, height: 200, fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => const SizedBox(height: 200,
                                child: Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 40)))),
                          ),
                          if (_uploadedUrl != null)
                            Positioned(top: 8, right: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.check_circle, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text('Uploaded', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                                ]),
                              )),
                          Positioned(bottom: 8, right: 8,
                            child: GestureDetector(
                              onTap: _pickAndUploadImage,
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                                  SizedBox(width: 4),
                                  Text('Ganti', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                                ]),
                              ))),
                        ])
                      : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Icon(Icons.upload_rounded, color: color.withOpacity(0.6), size: 30),
                          const SizedBox(height: 6),
                          Text('Tap untuk upload gambar', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
                          const SizedBox(height: 2),
                          Text('Auto convert ke catbox', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted.withOpacity(0.5))),
                        ]),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            // Process button
            GestureDetector(
              onTap: (_loading || _uploading || _uploadedUrl == null) ? null : _processImage,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Center(child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text(widget.title.toUpperCase(), style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 2))),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.4)), color: Colors.red.withOpacity(0.06)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.redAccent))),
                ]),
              ),
            ],
            if (_resultImageUrl != null) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _resultImageUrl!.startsWith('data:')
                      ? Image.memory(base64Decode(_resultImageUrl!.split(',')[1]))
                      : Image.network(_resultImageUrl!, loadingBuilder: (_, child, prog) =>
                          prog == null ? child : const Center(child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2)))),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _downloadImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.5)),
                    color: color.withOpacity(0.1),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.download_rounded, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text('SIMPAN KE GALERI', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: color, letterSpacing: 1)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NIK PARSE TOOL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _NikParseToolScreen extends StatefulWidget {
  const _NikParseToolScreen();

  @override
  State<_NikParseToolScreen> createState() => _NikParseToolScreenState();
}

class _NikParseToolScreenState extends State<_NikParseToolScreen> {
  final TextEditingController _nikController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Color get _toolColor => const Color(0xFF06B6D4);

  Future<void> _parseNik() async {
    final nik = _nikController.text.trim();
    if (nik.isEmpty) {
      showWarning(context, 'Masukkan NIK terlebih dahulu');
      return;
    }
    if (nik.length != 16) {
      showWarning(context, 'NIK harus 16 digit');
      return;
    }
    if (!RegExp(r'^\d+$').hasMatch(nik)) {
      showWarning(context, 'NIK hanya boleh berisi angka');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
    });

    try {
      final url = 'https://api.nexray.web.id/tools/nikparse?nik=$nik';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final json = jsonDecode(res.body);
        if (json['status'] == true || json['success'] == true) {
          setState(() {
            _result = json;
          });
        } else {
          setState(() => _error = json['message'] ?? 'Gagal parse NIK');
        }
      } else {
        setState(() => _error = 'API Error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Widget _buildInfoRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 100,
            child: Text(label,
              style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: AppTheme.textMuted, letterSpacing: 0.5)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value ?? '-',
              style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 12, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = _toolColor;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
        title: const Text('NIK PARSE',
            style: TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white, letterSpacing: 1.5)),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            // NIK Input
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('NIK (16 Digit)', style: TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1)),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withOpacity(0.4)),
                  color: AppTheme.cardBg,
                ),
                child: TextField(
                  controller: _nikController,
                  keyboardType: TextInputType.number,
                  maxLength: 16,
                  style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: 'Contoh: 1234567890123456',
                    hintStyle: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted.withOpacity(0.5)),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    counterText: '',
                  ),
                ),
              ),
            ]),
            const SizedBox(height: 20),
            // Parse button
            GestureDetector(
              onTap: _loading ? null : _parseNik,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Center(child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('PARSE NIK', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 2))),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.4)), color: Colors.red.withOpacity(0.06)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.redAccent))),
                ]),
              ),
            ],
            if (_result != null) ...[
              const SizedBox(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.4)),
                  gradient: LinearGradient(
                    colors: [AppTheme.cardBg, AppTheme.cardBg.withOpacity(0.8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(width: 3, height: 18,
                        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(2))),
                      const SizedBox(width: 10),
                      const Text('HASIL PARSING', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 1)),
                    ]),
                    const Divider(color: AppTheme.textMuted, height: 24),
                    _buildInfoRow('Provinsi', _result?['province']?.toString()),
                    _buildInfoRow('Kab/Kota', _result?['city']?.toString()),
                    _buildInfoRow('Kecamatan', _result?['district']?.toString()),
                    _buildInfoRow('Kelurahan', _result?['village']?.toString()),
                    _buildInfoRow('Tanggal Lahir', _result?['birthdate']?.toString()),
                    _buildInfoRow('Jenis Kelamin', _result?['gender']?.toString()),
                    _buildInfoRow('Umur', _result?['age']?.toString()),
                  ],
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAKER TOOL SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class _MakerToolScreen extends StatefulWidget {
  final String route;
  final String title;
  const _MakerToolScreen({required this.route, required this.title});

  @override
  State<_MakerToolScreen> createState() => _MakerToolScreenState();
}

class _MakerToolScreenState extends State<_MakerToolScreen> {
  final Map<String, TextEditingController> _ctrls = {};
  final Map<String, XFile?> _imageFiles = {};
  final Map<String, String> _uploadedUrls = {};

  String? _resultImageUrl;
  bool _loading = false;
  String? _error;
  String? _uploadingKey;

  Map<String, List<Map<String, String>>> get _fields => {
    'lobby_ff': [
      {'key': 'nickname', 'label': 'Nickname', 'hint': 'NamaKamu'},
    ],
    'lobby_ml': [
      {'key': 'nickname', 'label': 'Nickname', 'hint': 'NamaKamu'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
    ],
    'fake_story': [
      {'key': 'username', 'label': 'Username', 'hint': '@namauser'},
      {'key': 'caption', 'label': 'Caption', 'hint': 'Isi caption...'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
    ],
    'fake_threads': [
      {'key': 'username', 'label': 'Username', 'hint': '@namauser'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
      {'key': 'text', 'label': 'Text', 'hint': 'Isi threads...'},
      {'key': 'likes', 'label': 'Likes', 'hint': '1000'},
    ],
    'qc': [
      {'key': 'name', 'label': 'Nama', 'hint': 'NamaKamu'},
      {'key': 'avatar', 'label': 'Avatar', 'hint': 'Upload gambar avatar', 'isImage': 'true'},
      {'key': 'text', 'label': 'Teks', 'hint': 'Isi quote...'},
      {'key': 'color', 'label': 'Warna', 'hint': 'hitam / putih'},
    ],
    'smeme': [
      {'key': 'text_atas', 'label': 'Teks Atas', 'hint': 'Teks atas...'},
      {'key': 'text_bawah', 'label': 'Teks Bawah', 'hint': 'Teks bawah...'},
      {'key': 'background', 'label': 'Background', 'hint': 'Upload gambar background', 'isImage': 'true'},
    ],
    'brat_anime': [
      {'key': 'text', 'label': 'Teks', 'hint': 'Masukkan teks...'},
    ],
    'meme_ustadz': [
      {'key': 'text', 'label': 'Teks', 'hint': 'Masukkan teks...'},
    ],
  };

  @override
  void initState() {
    super.initState();
    final fields = _fields[widget.route] ?? [];
    for (final f in fields) {
      if (f['isImage'] != 'true') {
        _ctrls[f['key']!] = TextEditingController();
      }
    }
  }

  @override
  void dispose() {
    for (final c in _ctrls.values) c.dispose();
    super.dispose();
  }

  Future<String?> _uploadToCatbox(XFile file) async {
    try {
      final bytes = await file.readAsBytes();
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('https://catbox.moe/user/api.php'),
      );
      request.fields['reqtype'] = 'fileupload';
      request.files.add(http.MultipartFile.fromBytes(
        'fileToUpload',
        bytes,
        filename: file.name.isEmpty ? 'image.jpg' : file.name,
      ));
      final response = await request.send().timeout(const Duration(seconds: 30));
      final body = await response.stream.bytesToString();
      if (body.startsWith('https://')) return body.trim();
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> _pickImage(String key) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;

    setState(() {
      _imageFiles[key] = file;
      _uploadedUrls.remove(key);
      _uploadingKey = key;
    });

    final url = await _uploadToCatbox(file);
    if (mounted) {
      setState(() {
        _uploadingKey = null;
        if (url != null) {
          _uploadedUrls[key] = url;
        } else {
          showError(context, 'Gagal upload ke catbox, coba lagi');
          _imageFiles.remove(key);
        }
      });
    }
  }

  String _getParamValue(String key) {
    if (_fields[widget.route]?.any((f) => f['key'] == key && f['isImage'] == 'true') == true) {
      return _uploadedUrls[key] ?? '';
    }
    return _ctrls[key]?.text ?? '';
  }

  String _buildApiUrl() {
    final base = 'https://api.nexray.web.id/maker';
    switch (widget.route) {
      case 'lobby_ff':
        return '$base/fakelobyff?nickname=${Uri.encodeComponent(_getParamValue('nickname'))}';
      case 'lobby_ml':
        return '$base/fakelobyml?avatar=${Uri.encodeComponent(_getParamValue('avatar'))}&nickname=${Uri.encodeComponent(_getParamValue('nickname'))}';
      case 'fake_story':
        return '$base/fakestory?username=${Uri.encodeComponent(_getParamValue('username'))}&caption=${Uri.encodeComponent(_getParamValue('caption'))}&avatar=${Uri.encodeComponent(_getParamValue('avatar'))}';
      case 'fake_threads':
        return '$base/fakethreads?username=${Uri.encodeComponent(_getParamValue('username'))}&avatar=${Uri.encodeComponent(_getParamValue('avatar'))}&text=${Uri.encodeComponent(_getParamValue('text'))}&likes=${Uri.encodeComponent(_getParamValue('likes').isEmpty ? '1000' : _getParamValue('likes'))}';
      case 'qc':
        return '$base/qc?text=${Uri.encodeComponent(_getParamValue('text'))}&name=${Uri.encodeComponent(_getParamValue('name'))}&avatar=${Uri.encodeComponent(_getParamValue('avatar'))}&color=${Uri.encodeComponent(_getParamValue('color').isEmpty ? 'hitam' : _getParamValue('color'))}';
      case 'smeme':
        return '$base/smeme?text_atas=${Uri.encodeComponent(_getParamValue('text_atas'))}&text_bawah=${Uri.encodeComponent(_getParamValue('text_bawah'))}&background=${Uri.encodeComponent(_getParamValue('background'))}';
      case 'brat_anime':
        return 'https://api.nexray.web.id/maker/bratanime?text=${Uri.encodeComponent(_getParamValue('text'))}';
      case 'meme_ustadz':
        return 'https://api.nexray.web.id/maker/ustadz?text=${Uri.encodeComponent(_getParamValue('text'))}';
      default:
        return '';
    }
  }

  Future<void> _generate() async {
    final fields = _fields[widget.route] ?? [];

    for (final f in fields) {
      final key = f['key']!;
      final label = f['label'] ?? key;
      final isImg = f['isImage'] == 'true';
      if (isImg) {
        if (_uploadedUrls[key] == null || _uploadedUrls[key]!.isEmpty) {
          showWarning(context, '$label wajib di-upload');
          return;
        }
      } else {
        if ((_ctrls[key]?.text ?? '').isEmpty) {
          showWarning(context, '$label wajib diisi');
          return;
        }
      }
    }

    if (_uploadingKey != null) {
      showWarning(context, 'Tunggu upload gambar selesai...');
      return;
    }

    setState(() { _loading = true; _error = null; _resultImageUrl = null; });

    try {
      final url = _buildApiUrl();
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));

      if (res.statusCode == 200) {
        final contentType = res.headers['content-type'] ?? '';
        if (contentType.contains('image')) {
          final b64 = base64Encode(res.bodyBytes);
          final ext = contentType.contains('png') ? 'png' : 'jpg';
          setState(() => _resultImageUrl = 'data:image/$ext;base64,$b64');
        } else {
          try {
            final json = jsonDecode(res.body);
            final imgUrl = json['result'] ?? json['url'] ?? json['image'] ?? json['data'];
            if (imgUrl != null) {
              setState(() => _resultImageUrl = imgUrl.toString());
            } else {
              setState(() => _error = 'Tidak ada gambar dalam response');
            }
          } catch (_) {
            setState(() => _error = 'Response tidak valid');
          }
        }
      } else {
        setState(() => _error = 'API Error: ${res.statusCode}');
      }
    } catch (e) {
      setState(() => _error = 'Error: $e');
    }

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _downloadImage() async {
    if (_resultImageUrl == null) return;
    try {
      final dir = Directory('/storage/emulated/0/Pictures/Pegasus-X');
      if (!await dir.exists()) await dir.create(recursive: true);
      final fileName = '${widget.route}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir.path}/$fileName');
      if (_resultImageUrl!.startsWith('data:')) {
        final data = _resultImageUrl!.split(',')[1];
        await file.writeAsBytes(base64Decode(data));
      } else {
        final res = await http.get(Uri.parse(_resultImageUrl!));
        await file.writeAsBytes(res.bodyBytes);
      }
      if (mounted) {
        showSuccess(context, 'Tersimpan: ${dir.path}/$fileName');
      }
    } catch (e) {
      if (mounted) {
        showError(context, 'Gagal download: $e');
      }
    }
  }

  Color get _toolColor {
    const colors = {
      'lobby_ff': Color(0xFFFF6B00), 'lobby_ml': Color(0xFF3B82F6),
      'fake_story': Color(0xFFEC4899), 'fake_threads': Color(0xFF6B7280),
      'qc': Color(0xFF10B981), 'smeme': Color(0xFF8B5CF6),
      'brat_anime': Color(0xFF22D3EE), 'meme_ustadz': Color(0xFF84CC16),
    };
    return colors[widget.route] ?? AppTheme.accentBlue;
  }

  @override
  Widget build(BuildContext context) {
    final fields = _fields[widget.route] ?? [];
    final color = _toolColor;

    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBg,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20)),
        title: Text(widget.title.toUpperCase(),
            style: const TextStyle(fontFamily: 'Orbitron', fontSize: 14, color: Colors.white, letterSpacing: 1.5)),
        actions: [
          if (_resultImageUrl != null)
            IconButton(
              onPressed: _downloadImage,
              icon: Icon(Icons.download_rounded, color: color),
              tooltip: 'Download'),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.bgGradient),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(children: [
            ...fields.map((f) {
              final key = f['key']!;
              final isImg = f['isImage'] == 'true';

              if (isImg) {
                return _buildImageField(key, f['label']!, color);
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(f['label']!, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1)),
                  const SizedBox(height: 6),
                  Container(
                    decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: color.withOpacity(0.4)), color: AppTheme.cardBg),
                    child: TextField(
                      controller: _ctrls[key],
                      style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 13, color: Colors.white),
                      decoration: InputDecoration(
                        hintText: f['hint'],
                        hintStyle: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted.withOpacity(0.5)),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                  ),
                ]),
              );
            }),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: _loading ? null : _generate,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Center(child: _loading
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('GENERATE', style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 2))),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withOpacity(0.4)), color: Colors.red.withOpacity(0.06)),
                child: Row(children: [
                  const Icon(Icons.error_outline, color: Colors.redAccent, size: 18),
                  const SizedBox(width: 10),
                  Expanded(child: Text(_error!, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: Colors.redAccent))),
                ]),
              ),
            ],
            if (_resultImageUrl != null) ...[
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: color.withOpacity(0.4)),
                  boxShadow: [BoxShadow(color: color.withOpacity(0.15), blurRadius: 15)],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: _resultImageUrl!.startsWith('data:')
                      ? Image.memory(base64Decode(_resultImageUrl!.split(',')[1]))
                      : Image.network(_resultImageUrl!, loadingBuilder: (_, child, prog) =>
                          prog == null ? child : const Center(child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: AppTheme.accentBlue, strokeWidth: 2)))),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _downloadImage,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withOpacity(0.5)),
                    color: color.withOpacity(0.1),
                  ),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.download_rounded, color: color, size: 18),
                    const SizedBox(width: 8),
                    Text('SIMPAN KE GALERI', style: TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: color, letterSpacing: 1)),
                  ]),
                ),
              ),
            ],
          ]),
        ),
      ),
    );
  }

  Widget _buildImageField(String key, String label, Color color) {
    final file = _imageFiles[key];
    final url = _uploadedUrls[key];
    final isUploading = _uploadingKey == key;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11, color: Colors.white, letterSpacing: 1)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: isUploading ? null : () => _pickImage(key),
          child: Container(
            width: double.infinity,
            height: file != null ? null : 90,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: url != null ? Colors.green.withOpacity(0.6) : color.withOpacity(0.4),
                width: 1.5,
              ),
              color: AppTheme.cardBg,
            ),
            child: isUploading
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.orange, strokeWidth: 2)),
                    SizedBox(height: 8),
                    Text('Mengupload ke catbox...', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: Colors.orange)),
                  ]),
                )
              : file != null
                ? Stack(children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(11),
                      child: Image.file(File(file.path), width: double.infinity, height: 150, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox(height: 150,
                          child: Center(child: Icon(Icons.broken_image_rounded, color: AppTheme.textMuted, size: 40)))),
                    ),
                    if (url != null)
                      Positioned(top: 8, right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.green.withOpacity(0.9), borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_circle, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Uploaded', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                          ]),
                        )),
                    Positioned(bottom: 8, right: 8,
                      child: GestureDetector(
                        onTap: () => _pickImage(key),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: color.withOpacity(0.85), borderRadius: BorderRadius.circular(8)),
                          child: const Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.refresh_rounded, color: Colors.white, size: 12),
                            SizedBox(width: 4),
                            Text('Ganti', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: Colors.white)),
                          ]),
                        ))),
                  ])
                : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.upload_rounded, color: color.withOpacity(0.6), size: 30),
                    const SizedBox(height: 6),
                    Text('Tap untuk upload gambar', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 10, color: AppTheme.textMuted)),
                    const SizedBox(height: 2),
                    Text('Auto convert ke catbox', style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 9, color: AppTheme.textMuted.withOpacity(0.5))),
                  ]),
          ),
        ),
      ]),
    );
  }
}
