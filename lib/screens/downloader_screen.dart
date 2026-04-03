import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../../utils/app_localizations.dart';

class DownloaderScreen extends StatefulWidget {
  const DownloaderScreen({super.key});

  @override
  State<DownloaderScreen> createState() => _DownloaderScreenState();
}

class _DownloaderScreenState extends State<DownloaderScreen> {
  int _platform = 0;
  final _urlCtrl = TextEditingController();
  bool _loading  = false;
  Map<String, bool> _downloading = {};

  String? _thumbnail;
  String? _title;
  String? _videoSD;
  String? _videoHD;
  String? _mp3;
  String? _singleDownload;
  String? _pinVideo;
  String? _pinImage;

  static const List<Map<String, dynamic>> _platforms = [
    {'label': 'TikTok',    'color': Color(0xFFEF4444), 'hint': 'https://vt.tiktok.com/...'},
    {'label': 'Instagram', 'color': Color(0xFFEC4899), 'hint': 'https://www.instagram.com/reel/...'},
    {'label': 'Pinterest', 'color': Color(0xFFEF4444), 'hint': 'https://pin.it/...'},
  ];

  Color get _color => _platforms[_platform]['color'] as Color;

  void _resetResult() {
    _thumbnail = _title = _videoSD = _videoHD = _mp3 = _singleDownload = _pinVideo = _pinImage = null;
    _downloading = {};
  }

  Future<void> _fetch() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) { _snack('Masukkan Link Terlebih Dahulu'); return; }

    setState(() { _loading = true; _resetResult(); });

    try {
      if (_platform == 0) {
        final encoded = Uri.encodeComponent(url);
        final res = await http.get(Uri.parse('https://api.nexray.web.id/downloader/tiktok?url=$encoded'))
            .timeout(const Duration(seconds: 20));
        final json = jsonDecode(res.body);
        if (json['status'] == true) {
          final r = json['result'];
          setState(() {
            _thumbnail = r['cover'];
            _title     = r['title'];
            _videoSD   = r['data'];
            _videoHD   = r['data'];
            _mp3       = r['music_info']?['url'];
          });
        } else {
          _snack('Gagal Mengambil Data', isError: true);
        }
      } else if (_platform == 1) {
        final encoded = Uri.encodeComponent(url);
        final res = await http.get(Uri.parse('https://api.nexray.web.id/downloader/instagram?url=$encoded'))
            .timeout(const Duration(seconds: 20));
        final json = jsonDecode(res.body);
        if (json['status'] == true) {
          final List results = json['result'];
          if (results.isNotEmpty) {
            setState(() {
              _thumbnail      = results[0]['thumbnail'];
              _singleDownload = results[0]['url'];
            });
          } else {
            _snack('Tidak Ada Hasil', isError: true);
          }
        } else {
          _snack('Gagal Mengambil Data', isError: true);
        }
      } else {
        final encoded = Uri.encodeComponent(url);
        final res = await http.get(Uri.parse('https://api.nexray.web.id/downloader/pinterest?url=$encoded'))
            .timeout(const Duration(seconds: 20));
        final json = jsonDecode(res.body);
        if (json['status'] == true) {
          final r = json['result'];
          setState(() {
            _thumbnail = r['thumbnail'];
            _pinVideo  = r['video'];
            _pinImage  = r['image'];
          });
        } else {
          _snack('Gagal Mengambil Data', isError: true);
        }
      }
    } catch (e) {
      _snack('Koneksi Gagal: $e', isError: true);
    }

    setState(() => _loading = false);
  }

  Future<void> _downloadFile(String url, String label) async {
    setState(() => _downloading[label] = true);
    try {
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.photos.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        if (!status.isGranted) {
          _snack('Izin Penyimpanan Ditolak', isError: true);
          setState(() => _downloading[label] = false);
          return;
        }
      }

      _snack('Mengunduh $label...', isSuccess: true);
      final response = await http.get(Uri.parse(url))
          .timeout(const Duration(minutes: 5));

      if (response.statusCode == 200) {
        final bytes = response.bodyBytes;
        final ext   = _guessExtension(url, label);

        Directory? dir;
        if (Platform.isAndroid) {
          dir = Directory('/storage/emulated/0/Movies/Pegasus-X');
          if (!await dir.exists()) await dir.create(recursive: true);
        } else {
          dir = await getApplicationDocumentsDirectory();
        }

        final fileName = 'pegasusx_${DateTime.now().millisecondsSinceEpoch}$ext';
        final file = File('${dir!.path}/$fileName');
        await file.writeAsBytes(bytes);

        _snack('✅ $label Tersimpan: $fileName', isSuccess: true);
      } else {
        _snack('Gagal Download: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
    setState(() => _downloading[label] = false);
  }

  String _guessExtension(String url, String label) {
    final lower = label.toLowerCase();
    if (lower.contains('mp3') || lower.contains('audio')) return '.mp3';
    if (lower.contains('image') || lower.contains('foto')) return '.jpg';
    if (url.toLowerCase().contains('.mp3')) return '.mp3';
    if (url.toLowerCase().contains('.jpg') || url.toLowerCase().contains('.jpeg')) return '.jpg';
    if (url.toLowerCase().contains('.png')) return '.png';
    return '.mp4';
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
  void dispose() {
    _urlCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            backgroundColor: AppTheme.darkBg,
            elevation: 0,
            pinned: true,
            leading: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  border: Border.all(color: _color.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
            ),
            title: Row(children: [
              Container(width: 3, height: 18,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [_color, _color.withOpacity(0.5)]),
                    borderRadius: BorderRadius.circular(2),
                  )),
              SizedBox(width: 10),
              Text(tr('downloader_title'), style: TextStyle(fontFamily: 'Orbitron',
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _color.withOpacity(0.25)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  _buildLabel('Pilih Platform'),
                  SizedBox(height: 10),
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppTheme.primaryBlue.withOpacity(0.2)),
                    ),
                    child: Row(
                      children: List.generate(_platforms.length, (i) {
                        final isActive = _platform == i;
                        final col = _platforms[i]['color'] as Color;
                        return Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() { _platform = i; _resetResult(); }),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.all(4),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                              decoration: BoxDecoration(
                                gradient: isActive
                                    ? LinearGradient(colors: [col, col.withOpacity(0.7)])
                                    : null,
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: isActive ? [BoxShadow(color: col.withOpacity(0.4), blurRadius: 8)] : [],
                              ),
                              child: Text(
                                _platforms[i]['label'] as String,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontFamily: 'Orbitron', fontSize: 10, fontWeight: FontWeight.bold,
                                  color: isActive ? Colors.white : AppTheme.textMuted,
                                  letterSpacing: 1,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                  ),

                  SizedBox(height: 20),

                  _buildLabel('Link ${(_platforms[_platform]['label'] as String).toUpperCase()}'),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _urlCtrl,
                    keyboardType: TextInputType.url,
                    style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono', fontSize: 12),
                    decoration: InputDecoration(
                      hintText: _platforms[_platform]['hint'] as String,
                      hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 11),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: SvgPicture.string(AppSvgIcons.download, width: 18, height: 18,
                            colorFilter: ColorFilter.mode(_color, BlendMode.srcIn)),
                      ),
                      suffixIcon: _urlCtrl.text.isNotEmpty
                          ? GestureDetector(
                              onTap: () => setState(() { _urlCtrl.clear(); _resetResult(); }),
                              child: const Icon(Icons.close_rounded, color: AppTheme.textMuted, size: 18))
                          : null,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _color.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _color, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBg,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  SizedBox(height: 16),

                  GestureDetector(
                    onTap: _loading ? null : _fetch,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: _loading ? null
                            : LinearGradient(colors: [_color, _color.withOpacity(0.7)]),
                        color: _loading ? _color.withOpacity(0.2) : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _loading ? [] : [BoxShadow(color: _color.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: _loading
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text(tr('fetching_data'), style: TextStyle(fontFamily: 'Orbitron',
                                  fontSize: 12, color: Colors.white, letterSpacing: 1)),
                            ])
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SvgPicture.string(AppSvgIcons.download, width: 18, height: 18,
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                              SizedBox(width: 10),
                              Text(tr('fetch_data'), style: TextStyle(fontFamily: 'Orbitron',
                                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                            ]),
                    ),
                  ),

                  if (_thumbnail != null) ...[
                    SizedBox(height: 24),
                    _buildLabel('Hasil'),
                    SizedBox(height: 12),
                    Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _color.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
                            child: AspectRatio(
                              aspectRatio: 16 / 9,
                              child: Image.network(
                                _thumbnail!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => Container(
                                  color: AppTheme.cardBg,
                                  child: Center(child: SvgPicture.string(AppSvgIcons.image,
                                      width: 40, height: 40,
                                      colorFilter: ColorFilter.mode(_color.withOpacity(0.4), BlendMode.srcIn))),
                                ),
                              ),
                            ),
                          ),

                          Padding(
                            padding: const EdgeInsets.all(14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (_title != null) ...[
                                  Text(_title!,
                                      maxLines: 2, overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontFamily: 'ShareTechMono',
                                          fontSize: 11, color: Colors.white, height: 1.5)),
                                  SizedBox(height: 12),
                                ],

                                if (_videoSD != null) ...[
                                  _buildDownloadBtn('Download SD', _videoSD!, const Color(0xFF10B981)),
                                  SizedBox(height: 8),
                                  _buildDownloadBtn('Download HD', _videoHD!, const Color(0xFF3B82F6)),
                                  SizedBox(height: 8),
                                  if (_mp3 != null)
                                    _buildDownloadBtn('Download MP3', _mp3!, const Color(0xFFF59E0B)),
                                ],

                                if (_singleDownload != null)
                                  _buildDownloadBtn('Download Video', _singleDownload!, _color),

                                if (_pinVideo != null) ...[
                                  _buildDownloadBtn('Download Video', _pinVideo!, const Color(0xFFEF4444)),
                                  if (_pinImage != null) ...[
                                    SizedBox(height: 8),
                                    _buildDownloadBtn('Download Image', _pinImage!, const Color(0xFF10B981)),
                                  ],
                                ] else if (_pinImage != null)
                                  _buildDownloadBtn('Download Image', _pinImage!, const Color(0xFF10B981)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLabel(String text) => Text(text,
      style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
          color: _color.withOpacity(0.8), letterSpacing: 2));

  Widget _buildDownloadBtn(String label, String url, Color color) {
    final isLoading = _downloading[label] == true;
    return GestureDetector(
      onTap: isLoading ? null : () => _downloadFile(url, label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          gradient: isLoading ? null : LinearGradient(colors: [color, color.withOpacity(0.7)]),
          color: isLoading ? color.withOpacity(0.3) : null,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isLoading ? [] : [BoxShadow(color: color.withOpacity(0.35), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          isLoading
              ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : SvgPicture.string(AppSvgIcons.download, width: 16, height: 16,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
          SizedBox(width: 8),
          Text(isLoading ? 'Mengunduh...' : label, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 11,
              fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1)),
        ]),
      ),
    );
  }
}
