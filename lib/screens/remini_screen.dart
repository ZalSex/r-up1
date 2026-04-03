import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../utils/theme.dart';
import '../utils/notif_helper.dart';
import '../utils/app_localizations.dart';

class ReminiScreen extends StatefulWidget {
  const ReminiScreen({super.key});
  @override
  State<ReminiScreen> createState() => _ReminiScreenState();
}

class _ReminiScreenState extends State<ReminiScreen> {
  File? _pickedFile;
  bool  _loading   = false;
  bool  _downloading = false;
  String? _resultUrl;
  String _statusMsg = '';

  static const _purple    = Color(0xFF8B5CF6);
  static const _purpleDark = Color(0xFF6D28D9);

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked != null) {
      setState(() { _pickedFile = File(picked.path); _resultUrl = null; });
    }
  }

  /// Upload file ke catbox.moe dan return link URL-nya
  Future<String> _uploadToCatbox(File file) async {
    setState(() => _statusMsg = 'Mengunggah ke server...');
    final req = http.MultipartRequest('POST', Uri.parse('https://catbox.moe/user/api.php'));
    req.fields['reqtype'] = 'fileupload';
    req.files.add(await http.MultipartFile.fromPath('fileToUpload', file.path));
    final res = await req.send().timeout(const Duration(seconds: 60));
    final body = await res.stream.bytesToString();
    if (res.statusCode == 200 && body.startsWith('https://')) {
      return body.trim();
    }
    throw Exception('Gagal Upload ke Catbox: $body');
  }

  Future<void> _enhance() async {
    if (_pickedFile == null) { _snack('Pilih Foto Terlebih Dahulu'); return; }

    setState(() { _loading = true; _resultUrl = null; _statusMsg = 'Mempersiapkan...'; });
    try {
      // Step 1: Upload ke catbox untuk mendapat link
      final imageUrl = await _uploadToCatbox(_pickedFile!);

      // Step 2: Kirim link ke API remini
      setState(() => _statusMsg = 'Memproses AI Enhance...');
      final apiUrl = 'https://api.nexray.web.id/tools/remini?url=${Uri.encodeComponent(imageUrl)}';
      final res = await http.get(Uri.parse(apiUrl)).timeout(const Duration(seconds: 90));

      if (res.statusCode == 200) {
        final ct = res.headers['content-type'] ?? '';
        if (ct.contains('image')) {
          final tmpDir = await getTemporaryDirectory();
          final tmpFile = File('${tmpDir.path}/remini_result_${DateTime.now().millisecondsSinceEpoch}.jpg');
          await tmpFile.writeAsBytes(res.bodyBytes);
          setState(() => _resultUrl = tmpFile.path);
        } else {
          try {
            final json = jsonDecode(res.body);
            final url = json['url'] ?? json['result'] ?? json['data'];
            if (url != null) {
              setState(() => _resultUrl = url as String);
            } else {
              _snack('Format Respons Tidak Dikenali', isError: true);
            }
          } catch (_) {
            _snack('Gagal Memproses Respons', isError: true);
          }
        }
      } else {
        _snack('Gagal: HTTP ${res.statusCode}', isError: true);
      }
    } catch (e) {
      _snack('Error: $e', isError: true);
    }
    setState(() { _loading = false; _statusMsg = ''; });
  }

  Future<void> _download() async {
    if (_resultUrl == null) return;
    setState(() => _downloading = true);
    try {
      if (Platform.isAndroid) {
        PermissionStatus status = await Permission.photos.request();
        if (!status.isGranted) status = await Permission.storage.request();
        if (!status.isGranted) { _snack('Izin Ditolak', isError: true); setState(() => _downloading = false); return; }
      }

      late Uint8List bytes;
      if (_resultUrl!.startsWith('/')) {
        bytes = await File(_resultUrl!).readAsBytes();
      } else {
        final r = await http.get(Uri.parse(_resultUrl!)).timeout(const Duration(seconds: 30));
        bytes = r.bodyBytes;
      }

      Directory? dir;
      if (Platform.isAndroid) {
        dir = Directory('/storage/emulated/0/Pictures');
        if (!await dir.exists()) dir = Directory('/storage/emulated/0/Download');
        if (!await dir.exists()) dir = await getExternalStorageDirectory();
      } else {
        dir = await getApplicationDocumentsDirectory();
      }

      final fileName = 'remini_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final file = File('${dir!.path}/$fileName');
      await file.writeAsBytes(bytes);
      _snack('Tersimpan: $fileName', isSuccess: true);
    } catch (e) {
      _snack('Gagal Download: $e', isError: true);
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBg,
      body: CustomScrollView(slivers: [
        SliverAppBar(
          backgroundColor: AppTheme.darkBg, elevation: 0, pinned: true,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(border: Border.all(color: _purple.withOpacity(0.4)), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 16)),
          ),
          title: Row(children: [
            Container(width: 3, height: 18,
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_purple, _purpleDark]),
                borderRadius: BorderRadius.circular(2))),
            SizedBox(width: 10),
            Text(tr('remini_title'), style: TextStyle(fontFamily: 'Orbitron',
                fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
          ]),
          bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
            child: Container(height: 1, color: _purple.withOpacity(0.25))),
        ),

        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

              _buildLabel('Upload Foto'),
              SizedBox(height: 10),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity, height: _pickedFile != null ? null : 180,
                  decoration: BoxDecoration(
                    color: AppTheme.cardBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _purple.withOpacity(_pickedFile != null ? 0.6 : 0.3), width: _pickedFile != null ? 1.5 : 1),
                    boxShadow: [BoxShadow(color: _purple.withOpacity(0.1), blurRadius: 10)],
                  ),
                  child: _pickedFile != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(13),
                        child: Image.file(_pickedFile!, fit: BoxFit.contain))
                    : Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Container(width: 60, height: 60,
                          decoration: BoxDecoration(color: _purple.withOpacity(0.15), shape: BoxShape.circle,
                            border: Border.all(color: _purple.withOpacity(0.4))),
                          child: Center(child: SvgPicture.string(AppSvgIcons.image, width: 28, height: 28,
                            colorFilter: ColorFilter.mode(_purple.withOpacity(0.7), BlendMode.srcIn)))),
                        SizedBox(height: 12),
                        Text(tr('tap_pick_photo'), style: TextStyle(fontFamily: 'Orbitron',
                            fontSize: 11, color: AppTheme.textMuted, letterSpacing: 1.5)),
                        SizedBox(height: 4),
                        Text('JPG, PNG, WEBP', style: TextStyle(fontFamily: 'ShareTechMono',
                            fontSize: 10, color: AppTheme.textMuted.withOpacity(0.5))),
                      ]),
                ),
              ),

              if (_pickedFile != null) ...[
                SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickImage,
                  child: Container(alignment: Alignment.center,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(border: Border.all(color: _purple.withOpacity(0.3)),
                      borderRadius: BorderRadius.circular(10)),
                    child: Text(tr('change_photo_btn'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 10,
                        color: AppTheme.textMuted, letterSpacing: 1.5))),
                ),
              ],

              SizedBox(height: 20),

              // Status message
              if (_loading && _statusMsg.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: _purple.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _purple.withOpacity(0.3)),
                  ),
                  child: Row(children: [
                    SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: _purple)),
                    SizedBox(width: 10),
                    Text(_statusMsg, style: const TextStyle(fontFamily: 'ShareTechMono', fontSize: 11, color: AppTheme.textSecondary)),
                  ]),
                ),
                SizedBox(height: 12),
              ],

              GestureDetector(
                onTap: (_loading || _pickedFile == null) ? null : _enhance,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  decoration: BoxDecoration(
                    gradient: (_loading || _pickedFile == null) ? null : const LinearGradient(colors: [_purple, _purpleDark]),
                    color: (_loading || _pickedFile == null) ? _purple.withOpacity(0.2) : null,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: (_loading || _pickedFile == null) ? [] : [BoxShadow(color: _purple.withOpacity(0.4), blurRadius: 14, offset: const Offset(0,4))],
                  ),
                  child: _loading
                    ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text(tr('processing'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 12, color: Colors.white, letterSpacing: 1)),
                      ])
                    : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        SvgPicture.string(AppSvgIcons.image, width: 18, height: 18,
                          colorFilter: ColorFilter.mode(Colors.white.withOpacity(_pickedFile != null ? 1 : 0.4), BlendMode.srcIn)),
                        SizedBox(width: 10),
                        Text(tr('enhance_photo'), style: TextStyle(fontFamily: 'Orbitron', fontSize: 12,
                            fontWeight: FontWeight.bold, color: Colors.white.withOpacity(_pickedFile != null ? 1 : 0.4), letterSpacing: 2)),
                      ]),
                ),
              ),

              if (_resultUrl != null) ...[
                SizedBox(height: 24),
                _buildLabel('Hasil Remini'),
                SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(color: AppTheme.cardBg, borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _purple.withOpacity(0.5), width: 1.5),
                    boxShadow: [BoxShadow(color: _purple.withOpacity(0.2), blurRadius: 14)]),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(13),
                    child: _resultUrl!.startsWith('/')
                      ? Image.file(File(_resultUrl!), fit: BoxFit.contain)
                      : Image.network(_resultUrl!, fit: BoxFit.contain,
                          loadingBuilder: (_, child, progress) {
                            if (progress == null) return child;
                            return Container(height: 200, alignment: Alignment.center,
                              child: CircularProgressIndicator(
                                value: progress.expectedTotalBytes != null
                                  ? progress.cumulativeBytesLoaded / progress.expectedTotalBytes! : null,
                                color: _purple, strokeWidth: 2));
                          },
                          errorBuilder: (_, __, ___) => Container(height: 180, alignment: Alignment.center,
                            child: Text(tr('failed_load_result'), style: TextStyle(fontFamily: 'ShareTechMono', color: AppTheme.textMuted)))),
                  ),
                ),
                SizedBox(height: 12),

                GestureDetector(
                  onTap: _downloading ? null : _download,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: _downloading ? null : const LinearGradient(colors: [Color(0xFF10B981), Color(0xFF059669)]),
                      color: _downloading ? const Color(0xFF10B981).withOpacity(0.3) : null,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: _downloading ? [] : [BoxShadow(color: const Color(0xFF10B981).withOpacity(0.4), blurRadius: 14, offset: const Offset(0,4))],
                    ),
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _downloading
                        ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.download_rounded, color: Colors.white, size: 20),
                      SizedBox(width: 10),
                      Text(_downloading ? 'Menyimpan...' : 'Download Foto',
                        style: const TextStyle(fontFamily: 'Orbitron', fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2)),
                    ]),
                  ),
                ),
              ],

              SizedBox(height: 40),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _buildLabel(String t) => Text(t, style: const TextStyle(fontFamily: 'Orbitron', fontSize: 10, color: _purple, letterSpacing: 2));
}
