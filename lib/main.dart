import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'utils/theme.dart';
import 'utils/app_localizations.dart';
import 'services/api_service.dart';
import 'services/notification_service.dart';
import 'services/heartbeat_service.dart';
import 'screens/landing_screen.dart';
import 'screens/dashboard_screen.dart';
import 'screens/maintenance_screen.dart';

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

  Widget homeScreen = const LandingScreen();

  if (isLoggedIn) {
    HeartbeatService.instance.start();
    final role = prefs.getString('role') ?? 'member';

    if (role == 'owner') {
      homeScreen = const DashboardScreen();
    } else {
      try {
        await ApiService.init();
        final res = await ApiService.get('/api/app-status');
        if (res['success'] == true && res['open'] == false) {
          homeScreen = const MaintenanceScreen();
        } else {
          homeScreen = const DashboardScreen();
        }
      } catch (_) {
        homeScreen = const DashboardScreen();
      }
    }
  }

  runApp(PegasusXApp(homeScreen: homeScreen));
}

class PegasusXApp extends StatelessWidget {
  final Widget homeScreen;
  const PegasusXApp({super.key, required this.homeScreen});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocalizations.instance,
      builder: (context, _) => MaterialApp(
        title: 'Pegasus-X Revenge',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.theme,
        home: homeScreen,
      ),
    );
  }
}
