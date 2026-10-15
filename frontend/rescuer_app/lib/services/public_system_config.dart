import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Public-safe hints only. All authorization and limits are enforced by SQL.
class PublicSystemConfig {
  const PublicSystemConfig({this.version = '0', this.values = const {}});
  final String version;
  final Map<String, Object?> values;
  static const allowedKeys = {
    'customer.maintenance',
    'customer.requests_enabled',
    'customer.max_photos',
    'customer.banner_enabled',
    'customer.banner',
    'rescuer.maintenance',
    'rescuer.online_enabled',
    'rescuer.offline_enabled',
    'rescuer.max_active_jobs',
    'rescuer.quotes_enabled',
    'rescuer.quote_min_vnd',
    'rescuer.quote_max_vnd',
    'rescuer.bank_payment_visible',
    'payment.cash_enabled',
    'payment.bank_enabled',
    'payment.cash_confirmation_enabled',
    'payment.min_vnd',
    'payment.max_vnd',
    'payment.qr_expiry_seconds',
    'business.customer_cancellation_enabled',
    'security.kill_new_requests',
    'security.kill_new_jobs',
    'security.kill_new_bank_intents',
  };
  factory PublicSystemConfig.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['values'] is! Map ||
        !RegExp(r'^[1-9][0-9]*$').hasMatch('${raw['version']}')) {
      throw const FormatException('Invalid public system config');
    }
    final values = <String, Object?>{};
    for (final entry in (raw['values'] as Map).entries) {
      if (allowedKeys.contains(entry.key) &&
          (entry.value is bool ||
              entry.value is int ||
              entry.value is String)) {
        values[entry.key as String] = entry.value;
      }
    }
    return PublicSystemConfig(
      version: '${raw['version']}',
      values: Map.unmodifiable(values),
    );
  }
  bool flag(String key, {bool fallback = true}) =>
      values[key] is bool ? values[key] as bool : fallback;
  int integer(String key, int fallback) =>
      values[key] is int ? values[key] as int : fallback;
  int get maxPhotos => integer('customer.max_photos', 3).clamp(0, 3);
  bool get requestsEnabled =>
      flag('customer.requests_enabled') &&
      !flag('customer.maintenance', fallback: false) &&
      !flag('security.kill_new_requests', fallback: false);
  bool get bankEnabled =>
      flag('payment.bank_enabled') &&
      !flag('security.kill_new_bank_intents', fallback: false);
  String get banner =>
      flag('customer.banner_enabled', fallback: false) &&
          values['customer.banner'] is String
      ? values['customer.banner'] as String
      : '';
  static PublicSystemConfig of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ConfigData>()?.config ??
      const PublicSystemConfig();
}

class PublicSystemConfigScope extends StatefulWidget {
  const PublicSystemConfigScope({
    super.key,
    required this.app,
    required this.child,
    this.loader,
  });
  final String app;
  final Widget child;
  final Future<Object?> Function(String app)? loader;
  @override
  State<PublicSystemConfigScope> createState() =>
      _PublicSystemConfigScopeState();
}

class _PublicSystemConfigScopeState extends State<PublicSystemConfigScope>
    with WidgetsBindingObserver {
  PublicSystemConfig config = const PublicSystemConfig();
  Timer? timer;
  int generation = 0;
  bool fetching = false;
  bool foreground = true;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(refresh());
    timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (foreground) unawaited(refresh());
    });
  }

  Future<void> refresh() async {
    if (fetching) return;
    fetching = true;
    final current = ++generation;
    try {
      final raw =
          await (widget.loader?.call(widget.app) ??
                  Supabase.instance.client.rpc(
                    'get_public_system_config',
                    params: {'p_app': widget.app},
                  ))
              .timeout(const Duration(seconds: 10));
      final next = PublicSystemConfig.fromJson(raw);
      if (mounted &&
          current == generation &&
          BigInt.parse(next.version) >= BigInt.parse(config.version)) {
        setState(() => config = next);
      }
    } catch (_) {
      // Preserve last known public hints during an outage or before local migration.
      // Server-side gates always decide whether an action is permitted.
    } finally {
      fetching = false;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground) unawaited(refresh());
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final maintenance = config.flag(
      '${widget.app}.maintenance',
      fallback: false,
    );
    final message = maintenance
        ? 'Hệ thống đang bảo trì. Một số thao tác mới tạm dừng.'
        : widget.app == 'customer'
        ? config.banner
        : '';
    return _ConfigData(
      config: config,
      child: Column(
        children: [
          if (message.isNotEmpty)
            Material(
              color: const Color(0xffffedd5),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(message, textAlign: TextAlign.center),
                ),
              ),
            ),
          Expanded(child: widget.child),
        ],
      ),
    );
  }
}

class _ConfigData extends InheritedWidget {
  const _ConfigData({required this.config, required super.child});
  final PublicSystemConfig config;
  @override
  bool updateShouldNotify(_ConfigData oldWidget) => oldWidget.config != config;
}
