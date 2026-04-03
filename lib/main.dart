import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/theme.dart';
import 'utils/app_localizations.dart';
import 'services/notification_service.dart';
import 'services/heartbeat_service.dart';
import 'screens/landing_screen.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.darkBg,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await AppLocalizations.instance.init();
  await NotificationService.init();

  final prefs = await SharedPreferences.getInstance();
  final token = prefs.getString('auth_token');
  final isLoggedIn = token != null && token.isNotEmpty;

  // Mulai heartbeat global jika sudah login
  if (isLoggedIn) HeartbeatService.instance.start();

  runApp(PegasusXApp(isLoggedIn: isLoggedIn));
}

class PegasusXApp extends StatelessWidget {
  final bool isLoggedIn;
  const PegasusXApp({super.key, required this.isLoggedIn});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => MaterialApp(
        title: 'Pegasus-X Revenge',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: isLoggedIn ? const DashboardScreen() : const LandingScreen(),
      ),
    );
  }
}
