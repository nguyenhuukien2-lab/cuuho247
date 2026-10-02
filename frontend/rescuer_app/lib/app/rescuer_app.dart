import 'dart:async';

import 'package:flutter/material.dart';

import '../screens/home/home_screen.dart';
import '../screens/requests/requests_screen.dart';
import '../screens/active_job/active_job_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/account/account_screen.dart';
import '../widgets/app_components.dart';
import 'app_state.dart';
import 'app_theme.dart';

class RescuerApp extends StatefulWidget {
  const RescuerApp({super.key, this.appState});
  final AppState? appState;

  @override
  State<RescuerApp> createState() => _RescuerAppState();
}

class _RescuerAppState extends State<RescuerApp> {
  late final AppState state = widget.appState ?? AppState();
  late final bool ownsState = widget.appState == null;
  bool showSplash = true;
  Timer? splashTimer;

  @override
  void initState() {
    super.initState();
    splashTimer = Timer(const Duration(milliseconds: 850), () {
      if (mounted) setState(() => showSplash = false);
    });
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    if (ownsState) state.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cứu Hộ 24/7 Đối tác',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: showSplash ? const RescuerSplashScreen() : RescuerShell(state: state),
  );
}

class RescuerSplashScreen extends StatelessWidget {
  const RescuerSplashScreen({super.key});

  @override
  Widget build(BuildContext context) => const Scaffold(
    backgroundColor: AppColors.navy,
    body: SafeArea(
      child: Center(
        child: Padding(
          padding: EdgeInsets.all(AppSpace.xxl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BrandMark(size: 82, light: true),
              SizedBox(height: AppSpace.xl),
              Text(
                'Cứu Hộ 24/7 Đối tác',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                ),
              ),
              SizedBox(height: AppSpace.sm),
              Text(
                'Dành cho đối tác cứu hộ',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFFD0D9E3), fontSize: 14),
              ),
              SizedBox(height: 42),
              SizedBox.square(
                dimension: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.orange,
                ),
              ),
              SizedBox(height: AppSpace.md),
              Text(
                'Đang chuẩn bị ứng dụng...',
                style: TextStyle(color: Color(0xFFC2CFDC), fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class RescuerShell extends StatelessWidget {
  const RescuerShell({super.key, required this.state});
  final AppState state;

  static const _destinations = [
    NavigationDestination(
      icon: Icon(Icons.radar_outlined),
      selectedIcon: Icon(Icons.radar_rounded),
      label: 'Trang chủ',
    ),
    NavigationDestination(
      icon: Icon(Icons.assignment_outlined),
      selectedIcon: Icon(Icons.assignment_rounded),
      label: 'Đơn mới',
    ),
    NavigationDestination(
      icon: Icon(Icons.route_outlined),
      selectedIcon: Icon(Icons.route_rounded),
      label: 'Đang làm',
    ),
    NavigationDestination(icon: Icon(Icons.history_rounded), label: 'Lịch sử'),
    NavigationDestination(
      icon: Icon(Icons.person_outline_rounded),
      selectedIcon: Icon(Icons.person_rounded),
      label: 'Tài khoản',
    ),
  ];

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Scaffold(
      body: IndexedStack(
        index: state.selectedTab,
        children: [
          HomeScreen(state: state),
          RequestsScreen(state: state),
          ActiveJobScreen(state: state),
          HistoryScreen(state: state),
          AccountScreen(state: state),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.selectedTab,
        onDestinationSelected: state.selectTab,
        destinations: _destinations,
        height: 72,
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.orangeSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        elevation: 0,
      ),
    ),
  );
}
