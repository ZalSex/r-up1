import 'package:flutter/material.dart';

class RoleStyle {
  // Warna teks badge per role
  static Color textColor(String role) {
    switch (role.toLowerCase()) {
      case 'owner':    return const Color(0xFFCE93D8);
      case 'premium':  return const Color(0xFF82B1FF);
      case 'reseller': return const Color(0xFFFF5252);
      case 'vip':      return const Color(0xFFFFD54F);
      case 'member':
      default:         return const Color(0xFF81C784);
    }
  }

  // Warna gradient border per role
  static List<Color> borderColors(String role) {
    switch (role.toLowerCase()) {
      case 'owner':
        return const [
          Color(0xFF4A0080), Color(0xFF7B1FA2), Color(0xFF6A0DAD),
          Color(0xFF9C27B0), Color(0xFF4A0080),
        ];
      case 'premium':
        return const [
          Color(0xFF00C6FF), Color(0xFF6B48FF), Color(0xFF3B82F6),
          Color(0xFF8B5CF6), Color(0xFF00C6FF),
        ];
      case 'reseller':
        return const [
          Color(0xFFD32F2F), Color(0xFFEF5350), Color(0xFFE53935),
          Color(0xFFFF5252), Color(0xFFD32F2F),
        ];
      case 'vip':
        return const [
          Color(0xFFFFD700), Color(0xFFFFC200), Color(0xFFFFAA00),
          Color(0xFFFFE066), Color(0xFFFFD700),
        ];
      case 'member':
      default:
        return const [
          Color(0xFF66BB6A), Color(0xFF81C784), Color(0xFFA5D6A7),
          Color(0xFF66BB6A), Color(0xFF4CAF50),
        ];
    }
  }

  // Border biru seperti login
  static const List<Color> loginBorderColors = [
    Color(0xFF90CAF9),
    Color(0xFF1565C0),
    Color(0xFF29B6F6),
    Color(0xFF1E88E5),
    Color(0xFF64B5F6),
    Color(0xFF90CAF9),
  ];

  /// Get role colors (alias for borderColors)
  static List<Color> getRoleColors(String role) => borderColors(role);

  // Widget foto dengan border muter (Stack: border berputar, foto diam)
  static Widget instagramPhoto({
    String? assetPath,
    Widget? customImage,
    required List<Color> colors,
    required Animation<double> rotateAnim,
    required Animation<double> glowAnim,
    double size = 52,
    double borderWidth = 3,
    double innerPad = 2,
    Widget? fallback,
  }) {
    return SizedBox(
      width: size,
      height: size,
      child: AnimatedBuilder(
        animation: rotateAnim,
        builder: (_, __) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Layer 1: border berputar
              Transform.rotate(
                angle: rotateAnim.value * 6.2832,
                child: Container(
                  width: size,
                  height: size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: SweepGradient(colors: colors),
                    boxShadow: [
                      BoxShadow(
                        color: colors[2].withOpacity(glowAnim.value * 0.55),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
              // Layer 2: lingkaran hitam (gap)
              Container(
                width: size - borderWidth * 2,
                height: size - borderWidth * 2,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black,
                ),
              ),
              // Layer 3: foto diam
              ClipOval(
                child: SizedBox(
                  width: size - borderWidth * 2 - innerPad * 2,
                  height: size - borderWidth * 2 - innerPad * 2,
                  child: customImage != null
                      ? customImage
                      : (assetPath != null
                          ? Image.asset(
                              assetPath,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  fallback ?? const ColoredBox(color: Colors.transparent),
                            )
                          : (fallback ?? const ColoredBox(color: Colors.transparent))),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Badge role dengan border Instagram style
  static Widget roleBadge(String role) {
    final colors      = borderColors(role);
    final badgeColor  = textColor(role);
    return Container(
      decoration: BoxDecoration(
        gradient: SweepGradient(colors: [...colors, colors.first]),
        borderRadius: BorderRadius.circular(30),
      ),
      padding: const EdgeInsets.all(1.5),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF0D1B2A),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Text(
          role.toUpperCase(),
          style: TextStyle(
            fontFamily: 'ShareTechMono',
            fontSize: 9,
            letterSpacing: 1.5,
            fontWeight: FontWeight.bold,
            color: badgeColor,
          ),
        ),
      ),
    );
  }
}
