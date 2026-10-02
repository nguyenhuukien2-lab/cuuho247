import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../app/app_theme.dart';
import 'rescue_location_map.dart';

/// Shows the request location and its OSM map when coordinates are available.
class RequestLocationCard extends StatelessWidget {
  const RequestLocationCard({
    super.key,
    required this.address,
    this.coordinates,
  });

  final String address;
  final RescueCoordinates? coordinates;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [
            Icon(Icons.location_on_outlined, color: AppColors.navy),
            SizedBox(width: 8),
            Expanded(
                child: Text('Vị trí cứu hộ đã gửi',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
          ]),
          const SizedBox(height: 12),
          Text(address, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (coordinates != null && coordinates!.isValid)
            SelectableText('Tọa độ: ${coordinates!.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted))
          else
            const Text('Yêu cầu sử dụng địa chỉ nhập tay, chưa có tọa độ.'),
          const SizedBox(height: 8),
          RescueLocationMap(coordinates: coordinates),
        ],
      );
}
