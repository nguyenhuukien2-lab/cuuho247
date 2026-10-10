import 'package:flutter/material.dart';

import '../screens/new_account_screen.dart';
import '../screens/new_history_screen.dart';
import '../screens/new_home_screen.dart';
import '../screens/new_request_screen.dart';
import '../screens/new_tracking_screen.dart';
import 'app_controller.dart';
import 'user_session.dart';
import '../widgets/booking_ui.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.controller, this.initialIndex});
  final AppController controller;
  final int? initialIndex;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _fade;
  late int _lastTab;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller.gps.setUser(UserSession.userId);
    if (widget.initialIndex != null)
      widget.controller.tabIndex = widget.initialIndex!;
    _lastTab = widget.controller.tabIndex;
    _fade = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
      value: 1,
    );
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _fade.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller.setForeground(state == AppLifecycleState.resumed);
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
      NewHomeScreen(
          key: ValueKey(UserSession.userId), controller: widget.controller),
      NewRequestScreen(
        key: ValueKey(UserSession.userId),
        controller: widget.controller,
      ),
      NewTrackingScreen(
        controller: widget.controller,
        isActive: widget.controller.tabIndex == 2,
      ),
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
                  index: widget.controller.tabIndex,
                  children: pages,
                ),
              ),
      ),
      bottomNavigationBar: CustomerBottomNav(controller: widget.controller),
    );
  }
}
