import 'package:flutter/material.dart';

import 'app/connected_app.dart';
import 'app/rescuer_controller.dart';
import 'services/location_service.dart';
import 'services/rescuer_service.dart';
import 'services/supabase_config.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final config = SupabaseConfig.environment();
  if (config.error != null) {
    runApp(ConnectedRescuerApp(configurationError: config.error));
    return;
  }
  try {
    await Supabase.initialize(
      url: config.url,
      publishableKey: config.key,
      debug: false,
    );
    runApp(
      ConnectedRescuerApp(
        controller: RescuerController(
          SupabaseRescuerService(Supabase.instance.client),
          DeviceLocationService(),
        ),
      ),
    );
  } catch (_) {
    runApp(
      const ConnectedRescuerApp(
        configurationError: 'Không thể khởi tạo kết nối. Kiểm tra cấu hình và mạng, sau đó mở lại ứng dụng.',
      ),
    );
  }
}
