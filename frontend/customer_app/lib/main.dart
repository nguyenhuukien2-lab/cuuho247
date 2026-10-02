import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app_controller.dart';
import 'app/app_shell.dart';
import 'app/app_theme.dart';
import 'app/navigation.dart';
import 'screens/new_auth_screen.dart';
import 'services/supabase_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (BackendConfiguration.isConfigured) {
    await Supabase.initialize(
        url: BackendConfiguration.url,
        publishableKey: BackendConfiguration.publishableKey);
  }
  runApp(const RescueApp());
}

class RescueApp extends StatefulWidget {
  const RescueApp({super.key});

  @override
  State<RescueApp> createState() => _RescueAppState();
}

class _RescueAppState extends State<RescueApp> {
  late final AppController controller;

  @override
  void initState() {
    super.initState();
    controller = AppController();
    controller.initialize();
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cứu Hộ 24/7',
      debugShowCheckedModeBanner: false,
      navigatorObservers: [customerRouteObserver],
      theme: AppTheme.light,
      builder: (context, child) => ColoredBox(
        color: AppColors.navy,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: child ?? const SizedBox.shrink(),
          ),
        ),
      ),
      initialRoute: '/',
      routes: {
        '/': (_) => AppShell(controller: controller),
        '/home': (_) => AppShell(controller: controller, initialIndex: 0),
        '/request': (_) => AppShell(controller: controller, initialIndex: 1),
        '/tracking': (_) => AppShell(controller: controller, initialIndex: 2),
        '/history': (_) => AppShell(controller: controller, initialIndex: 3),
        '/account': (_) => AppShell(controller: controller, initialIndex: 4),
        '/login': (_) => NewAuthScreen(controller: controller),
      },
    );
  }
}
