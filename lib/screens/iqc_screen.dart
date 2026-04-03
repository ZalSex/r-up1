import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../../utils/app_localizations.dart';

class IqcScreen extends StatefulWidget {
  const IqcScreen({super.key});

  @override
  State<IqcScreen> createState() => _IqcScreenState();
}

class _IqcScreenState extends State<IqcScreen> {
  final _textCtrl  = TextEditingController();
  bool  _loading   = false;
  bool  _downloading = false;
  String? _imageUrl;

  static const Color _purple     = Color(0xFF8B5CF6);
  static const Color _purpleDark = Color(0xFF6D28D9);

  String _getWibTime() {
    final now = DateTime.now().toUtc().add(const Duration(hours: 7));
    final h   = now.hour.toString().padLeft(2, '0');
    final m   = now.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _generate() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) { _snack('Masukkan Teks Terlebih Dahulu'); return; }

    final jam      = _getWibTime();
    final baterai  = (Random().nextInt(100) + 1).toString();
    final provider = 'Telkomsel';

    setState(() { _loading = true; _imageUrl = null; });

    try {
      final encoded = Uri.encodeComponent(text);
      final jamEnc  = Uri.encodeComponent(jam);
      final url     = 'https://api.nexray.web.id/maker/v1/iqc?text=$encoded&provider=$provider&jam=$jamEnc&baterai=$baterai';

      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 20));

      final contentType = res.headers['content-type'] ?? '';
      if (res.statusCode == 200 && (contentType.contains('image') || res.bodyBytes.isNotEmpty)) {
        try {
          final json = jsonDecode(res.body);
          if (json['url'] != null) {
            setState(() => _imageUrl = json['url']);
          } else if (json['result'] != null) {
            setState(() => _imageUrl = json['result']);
          } else {
            setState(() => _imageUrl = url);
          }
        } catch (_) {
          setState(() => _imageUrl = url);
        }
      } else {
        _snack('Gagal Generate Quote', isError: true);
      }
    } catch (e) {
      _snack('Koneksi Gagal', isError: true);
    }

    setState(() => _loading = false);
  }

  Future<void> _downloadImage() async {
    if (_imageUrl == null) return;
    setState(() => _downloading = true);

    try {
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.photos.request();
        if (!status.isGranted) {
          status = await Permission.storage.request();
        }
        if (!status.isGranted) {
          _snack('Izin Penyimpanan Ditolak', isError: true);
          setState(() => _downloading = false);
          return;
        }
      }

      _snack('Mengunduh Gambar...', isSuccess: true);
      final response = await http.get(Uri.parse(_imageUrl!))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final dir = Directory('/storage/emulated/0/Pictures/Pegasus-X');
        if (!await dir.exists()) await dir.create(recursive: true);

        final fileName = 'iqc_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final file = File('${dir.path}/$fileName');
        await file.writeAsBytes(response.bodyBytes);

        _snack('Foto Tersimpan: ${dir.path}/$fileName', isSuccess: true);
      } else {
        _snack('Gagal Download: ${response.statusCode}', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }

    setState(() => _downloading = false);
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
    _textCtrl.dispose();
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
                  border: Border.all(color: _purple.withOpacity(0.4)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16),
              ),
            ),
            title: Row(children: [
              Container(width: 3, height: 18,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [_purple, _purpleDark]),
                    borderRadius: BorderRadius.circular(2),
                  )),
              SizedBox(width: 10),
              Text(tr('iqc_title'), style: TextStyle(fontFamily: 'Orbitron',
                  fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
            ]),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(1),
              child: Container(height: 1, color: _purple.withOpacity(0.25)),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  SizedBox(height: 4),

                  _buildLabel('Teks Quote'),
                  SizedBox(height: 8),
                  TextFormField(
                    controller: _textCtrl,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontFamily: 'ShareTechMono', fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Tulis teks quote di sini...',
                      hintStyle: TextStyle(color: AppTheme.textMuted.withOpacity(0.4), fontSize: 12),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _purple.withOpacity(0.4)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: _purple, width: 1.5),
                      ),
                      filled: true,
                      fillColor: AppTheme.cardBg,
                      contentPadding: const EdgeInsets.all(14),
                    ),
                  ),

                  SizedBox(height: 16),

                  GestureDetector(
                    onTap: _loading ? null : _generate,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      decoration: BoxDecoration(
                        gradient: _loading ? null
                            : const LinearGradient(colors: [_purple, _purpleDark]),
                        color: _loading ? _purple.withOpacity(0.2) : null,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _loading ? [] : [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 14, offset: const Offset(0, 4))],
                      ),
                      child: _loading
                          ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                              SizedBox(width: 10),
                              Text(tr('generating'), style: TextStyle(fontFamily: 'Orbitron',
                                  fontSize: 12, color: Colors.white, letterSpacing: 1)),
                            ])
                          : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                              SvgPicture.string(AppSvgIcons.quote, width: 18, height: 18,
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
                              SizedBox(width: 10),
                              Text(tr('generate_quote'), style: TextStyle(fontFamily: 'Orbitron',
                                  fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                            ]),
                    ),
                  ),

                  if (_imageUrl != null) ...[
                    SizedBox(height: 24),
                    _buildLabel('Hasil'),
                    SizedBox(height: 12),

                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: AppTheme.cardBg,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _purple.withOpacity(0.3)),
                        boxShadow: [BoxShadow(color: _purple.withOpacity(0.15), blurRadius: 14)],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(13),
                        child: Image.network(
                          _imageUrl!,
                          fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 200,
                              alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                    ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes!
                                    : null,
                                color: _purple, strokeWidth: 2,
                              ),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            height: 200,
                            alignment: Alignment.center,
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              SvgPicture.string(AppSvgIcons.image, width: 36, height: 36,
                                  colorFilter: ColorFilter.mode(_purple.withOpacity(0.4), BlendMode.srcIn)),
                              SizedBox(height: 8),
                              Text(tr('failed_load_image'),
                                  style: TextStyle(fontFamily: 'ShareTechMono', fontSize: 11,
                                      color: AppTheme.textMuted)),
                            ]),
                          ),
                        ),
                      ),
                    ),

                    SizedBox(height: 12),

                    GestureDetector(
                      onTap: _downloading ? null : _downloadImage,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(
                          gradient: _downloading
                              ? null
                              : const LinearGradient(
                                  colors: [Color(0xFF10B981), Color(0xFF059669)]),
                          color: _downloading ? const Color(0xFF10B981).withOpacity(0.3) : null,
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: _downloading
                              ? []
                              : [BoxShadow(
                                  color: const Color(0xFF10B981).withOpacity(0.4),
                                  blurRadius: 14,
                                  offset: const Offset(0, 4))],
                        ),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          _downloading
                              ? SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            _downloading ? 'Menyimpan...' : 'Download Foto',
                            style: const TextStyle(fontFamily: 'Orbitron',
                                fontSize: 12, fontWeight: FontWeight.bold,
                                color: Colors.white, letterSpacing: 2),
                          ),
                        ]),
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
      style: const TextStyle(fontFamily: 'Orbitron', fontSize: 10,
          color: _purple, letterSpacing: 2));
}