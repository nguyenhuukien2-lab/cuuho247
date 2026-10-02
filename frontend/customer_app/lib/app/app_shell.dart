import 'package:flutter/material.dart';

import '../screens/new_account_screen.dart';
import '../screens/new_history_screen.dart';
import '../screens/new_home_screen.dart';
import '../screens/new_request_screen.dart';
import '../screens/new_tracking_screen.dart';
import 'app_controller.dart';
import 'app_theme.dart';
import 'user_session.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller, this.initialIndex});
  final AppController controller;
  final int? initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade;
  late int _lastTab;
  @override
  void initState() {
    super.initState();
    if (widget.initialIndex != null)
      widget.controller.tabIndex = widget.initialIndex!;
    _lastTab = widget.controller.tabIndex;
    _fade = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180), value: 1);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _fade.dispose();
    super.dispose();
  }

  void _refresh() {
    if (_lastTab != widget.controller.tabIndex) {
      FocusManager.instance.primaryFocus?.unfocus();
      _lastTab = widget.controller.tabIndex;
      if (MediaQuery.disableAnimationsOf(context)) {
        _fade.stop();
        _fade.value = 1;
      } else {
        _fade.forward(from: .8);
      }
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      NewHomeScreen(controller: widget.controller),
      NewRequestScreen(
          key: ValueKey(UserSession.userId), controller: widget.controller),
      NewTrackingScreen(
          controller: widget.controller,
          isActive: widget.controller.tabIndex == 2),
      NewHistoryScreen(controller: widget.controller),
      NewAccountScreen(controller: widget.controller),
    ];
    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        bottom: false,
        child: widget.controller.restoringSession
            ? const Center(child: CircularProgressIndicator())
            : FadeTransition(
                opacity: _fade,
                child: IndexedStack(
                    index: widget.controller.tabIndex, children: pages)),
      ),
      bottomNavigationBar: _BottomNavigation(controller: widget.controller),
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation({required this.controller});
  final AppController controller;

  @override
  Widget build(BuildContext context) {
    const items = [
      (Icons.home_outlined, Icons.home_rounded, 'Trang chủ'),
      (Icons.build_circle_outlined, Icons.build_circle, 'Cứu hộ'),
      (Icons.route_outlined, Icons.route, 'Đang xử lý'),
      (Icons.history_outlined, Icons.history, 'Lịch sử'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'Tài khoản'),
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AppColors.border))),
      child: NavigationBar(
        selectedIndex: controller.tabIndex,
        onDestinationSelected: controller.selectTab,
        destinations: [
          for (final item in items)
            NavigationDestination(
                icon: Icon(item.$1),
                selectedIcon: Icon(item.$2),
                label: item.$3),
        ],
      ),
    );
  }
}
