import 'package:flutter/material.dart';
import 'theme.dart';

/// Tipe notifikasi
enum NotifType { success, error, warning, info }

/// Tampilkan notifikasi di tengah halaman dengan tombol OK (menggantikan SnackBar)
Future<void> showAppNotif(
  BuildContext context,
  String message, {
  NotifType type = NotifType.info,
  String title = '',
  VoidCallback? onOk,
}) async {
  if (!context.mounted) return;

  final cfg = _notifConfig(type);

  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black.withOpacity(0.65),
    builder: (_) => Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 32),
          decoration: BoxDecoration(
            color: AppTheme.cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: cfg.color.withOpacity(0.45),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: cfg.color.withOpacity(0.18),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header strip
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cfg.color.withOpacity(0.18),
                      cfg.color.withOpacity(0.06),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(19),
                    topRight: Radius.circular(19),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Center(
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: cfg.color.withOpacity(0.15),
                          shape: BoxShape.circle,
                          border: Border.all(color: cfg.color.withOpacity(0.4)),
                        ),
                        child: Icon(cfg.icon, color: cfg.color, size: 22),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: Text(
                        title.isNotEmpty ? title : cfg.defaultTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Orbitron',
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: cfg.color,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                child: Column(
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontFamily: 'ShareTechMono',
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Tombol OK
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(_);
                        onOk?.call();
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              cfg.color.withOpacity(0.85),
                              cfg.color,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: cfg.color.withOpacity(0.3),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: const Text(
                          'OK',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Orbitron',
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// Shortcut success
Future<void> showSuccess(BuildContext context, String msg, {String title = '', VoidCallback? onOk}) =>
    showAppNotif(context, msg, type: NotifType.success, title: title, onOk: onOk);

/// Shortcut error
Future<void> showError(BuildContext context, String msg, {String title = '', VoidCallback? onOk}) =>
    showAppNotif(context, msg, type: NotifType.error, title: title, onOk: onOk);

/// Shortcut warning
Future<void> showWarning(BuildContext context, String msg, {String title = '', VoidCallback? onOk}) =>
    showAppNotif(context, msg, type: NotifType.warning, title: title, onOk: onOk);

/// Shortcut info
Future<void> showInfo(BuildContext context, String msg, {String title = '', VoidCallback? onOk}) =>
    showAppNotif(context, msg, type: NotifType.info, title: title, onOk: onOk);

// ─────────────────────────────────────────────────────────────────────────────

class _NotifConfig {
  final Color color;
  final IconData icon;
  final String defaultTitle;
  const _NotifConfig({required this.color, required this.icon, required this.defaultTitle});
}

_NotifConfig _notifConfig(NotifType type) {
  switch (type) {
    case NotifType.success:
      return const _NotifConfig(
        color: Color(0xFF00E676),
        icon: Icons.check_circle_outline_rounded,
        defaultTitle: 'BERHASIL',
      );
    case NotifType.error:
      return const _NotifConfig(
        color: Color(0xFFFF5252),
        icon: Icons.error_outline_rounded,
        defaultTitle: 'ERROR',
      );
    case NotifType.warning:
      return const _NotifConfig(
        color: Color(0xFFFFD740),
        icon: Icons.warning_amber_rounded,
        defaultTitle: 'PERINGATAN',
      );
    case NotifType.info:
      return const _NotifConfig(
        color: Color(0xFF00E5FF),
        icon: Icons.info_outline_rounded,
        defaultTitle: 'INFO',
      );
  }
}
