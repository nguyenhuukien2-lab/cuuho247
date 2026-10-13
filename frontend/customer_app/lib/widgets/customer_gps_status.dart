import 'package:flutter/material.dart';

import '../app/customer_gps_controller.dart';

/// Live device GPS is local only; the map above keeps the request snapshot.
class CustomerGpsStatus extends StatelessWidget {
  const CustomerGpsStatus({super.key, required this.gps});
  final CustomerGpsController gps;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: gps,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('GPS thiết bị: ${gps.result.statusLabel}',
                style: const TextStyle(fontSize: 12)),
            if (gps.lastFix?.capturedAt case final time?)
              Text(
                  'Cập nhật gần nhất: ${time.toLocal().toString().split('.').first}',
                  style: const TextStyle(fontSize: 12)),
            if (gps.result.accuracy case final accuracy?)
              Text('Độ chính xác: ${accuracy.toStringAsFixed(0)} m',
                  style: const TextStyle(fontSize: 12)),
            const Text(
                'Vị trí cứu hộ trên bản đồ là vị trí đã gửi trong yêu cầu.',
                style: TextStyle(fontSize: 12)),
            TextButton.icon(
              onPressed: gps.loading ? null : gps.refresh,
              icon: const Icon(Icons.gps_fixed, size: 16),
              label: const Text('Cập nhật GPS thiết bị'),
            ),
          ],
        ),
      );
}
