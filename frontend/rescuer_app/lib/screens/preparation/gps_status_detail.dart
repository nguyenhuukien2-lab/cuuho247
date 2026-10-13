import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';

class GpsStatusDetail extends StatelessWidget {
  const GpsStatusDetail({super.key, required this.c, this.coordinates = false});
  final RescuerController c;
  final bool coordinates;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(c.gpsStatusLabel, style: AppType.caption),
      if (c.gpsError != null) Text(c.gpsError!, style: AppType.caption),
      if (c.lastPosition case final position?) ...[
        Text(
          'Cập nhật gần nhất: ${position.capturedAt.toLocal().toString().split('.').first}',
          style: AppType.caption,
        ),
        Text(
          'Độ chính xác GPS: ${position.accuracy.toStringAsFixed(0)} m',
          style: AppType.caption,
        ),
        if (coordinates)
          SelectableText(
            'GPS thiết bị: ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
            style: AppType.caption,
          ),
      ],
      if (c.lastLocationSentAt case final time?)
        Text(
          'Gửi máy chủ gần nhất: ${time.toLocal().toString().split('.').first}',
          style: AppType.caption,
        ),
    ],
  );
}
