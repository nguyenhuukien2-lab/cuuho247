import 'package:flutter/material.dart';

import '../screens/preparation/preparation_screen.dart';
import 'app_theme.dart';
import 'rescuer_controller.dart';

class ConnectedRescuerApp extends StatefulWidget {
  const ConnectedRescuerApp({
    super.key,
    this.controller,
    this.configurationError,
  });
  final RescuerController? controller;
  final String? configurationError;
  @override
  State<ConnectedRescuerApp> createState() => _ConnectedRescuerAppState();
}

class _ConnectedRescuerAppState extends State<ConnectedRescuerApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.controller?.start();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    widget.controller?.setForeground(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Cứu Hộ 24/7 Đối tác',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: widget.controller == null
        ? Scaffold(
            appBar: AppBar(title: const Text('Cấu hình ứng dụng')),
            body: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                widget.configurationError ?? 'Chưa có cấu hình Supabase.',
              ),
            ),
          )
        : PreparationScreen(controller: widget.controller!),
  );
}
