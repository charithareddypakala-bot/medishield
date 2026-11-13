import 'package:flutter/material.dart';

import 'core/services/api_client.dart';
import 'core/services/medication_reminder_service.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/auth_screens.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppSession.instance.init();
  await MedicationReminderService.instance.initialize();
  AppSession.instance.onSessionExpired = () {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;
    navigator.pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => const SplashScreen()),
      (route) => false,
    );
  };
  runApp(const MediShieldApp());
}

class MediShieldApp extends StatelessWidget {
  const MediShieldApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: appNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'MediShield',
      theme: AppTheme.lightTheme,

      // Start authentication flow
      home: const SplashScreen(),
    );
  }
}
