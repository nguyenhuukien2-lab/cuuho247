import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/location_service.dart';
import '../app/app_theme.dart';

/// Shared OSM map. A default camera is never a selected rescue coordinate.
class RescueLocationMap extends StatefulWidget {
  const RescueLocationMap(
      {super.key,
      this.coordinates,
      this.onSelected,
      this.locked = false,
      this.showDefaultLocation = false});
  final RescueCoordinates? coordinates;
  final ValueChanged<RescueCoordinates>? onSelected;
  final bool locked, showDefaultLocation;
  static const daNang = LatLng(16.0544, 108.2022);
  @visibleForTesting
  static TileProvider Function()? tileProviderFactory;
  @override
  State<RescueLocationMap> createState() => _RescueLocationMapState();
}

class _RescueLocationMapState extends State<RescueLocationMap> {
  final controller = MapController();
  late TileProvider provider;
  bool ready = false, tileError = false;
  int tileRevision = 0;
  RescueCoordinates? get coordinates =>
      widget.coordinates?.isValid == true ? widget.coordinates : null;
  LatLng get center => coordinates == null
      ? RescueLocationMap.daNang
      : LatLng(
          coordinates!.latitude.clamp(-85.05112878, 85.05112878).toDouble(),
          coordinates!.longitude);
  @override
  void initState() {
    super.initState();
    provider = createProvider();
  }

  TileProvider createProvider() =>
      RescueLocationMap.tileProviderFactory?.call() ?? NetworkTileProvider();
  @override
  void didUpdateWidget(covariant RescueLocationMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (coordinates == null && !widget.showDefaultLocation) {
      ready = false;
      return;
    }
    if (oldWidget.coordinates?.latitude != widget.coordinates?.latitude ||
        oldWidget.coordinates?.longitude != widget.coordinates?.longitude) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && ready)
          controller.move(center, coordinates == null ? 12 : 16);
      });
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  void failedTile() {
    if (tileError || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !tileError) setState(() => tileError = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final point = coordinates;
    if (point == null && !widget.showDefaultLocation)
      return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12)),
          child: const Row(children: [
            Icon(Icons.map_outlined, color: AppColors.muted),
            SizedBox(width: 10),
            Expanded(
                child: Text('Chưa có tọa độ',
                    style: TextStyle(color: AppColors.muted)))
          ]));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.onSelected != null)
        const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
                'Chạm trên bản đồ để chọn vị trí cứu hộ. Địa chỉ nhập tay vẫn bắt buộc.',
                style: TextStyle(fontSize: 12, color: AppColors.muted))),
      ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.featured),
          child: SizedBox(
              height: 240,
              child: FlutterMap(
                  mapController: controller,
                  options: MapOptions(
                      initialCenter: center,
                      initialZoom: point == null ? 12 : 16,
                      minZoom: 3,
                      maxZoom: 19,
                      onMapReady: () => ready = true,
                      interactionOptions: InteractionOptions(
                          flags: widget.locked
                              ? InteractiveFlag.none
                              : InteractiveFlag.pinchZoom |
                                  InteractiveFlag.doubleTapZoom),
                      onTap: widget.locked || widget.onSelected == null
                          ? null
                          : (_, position) {
                              final selected = RescueCoordinates(
                                  position.latitude,
                                  (position.longitude + 180) % 360 - 180);
                              if (selected.isValid)
                                widget.onSelected!(selected);
                            }),
                  children: [
                    TileLayer(
                        key: ValueKey(tileRevision),
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.cuuho247.customer',
                        tileProvider: provider,
                        maxNativeZoom: 19,
                        errorTileCallback: (_, __, ___) => failedTile()),
                    MarkerLayer(markers: [
                      if (point != null)
                        Marker(
                            point: LatLng(point.latitude, point.longitude),
                            width: 44,
                            height: 44,
                            alignment: Alignment.topCenter,
                            child: const Icon(Icons.location_pin,
                                key: ValueKey('rescue-location-marker'),
                                semanticLabel: 'Vị trí khách hàng cần cứu hộ',
                                size: 44,
                                color: AppColors.orange))
                    ]),
                    if (widget.onSelected != null && !widget.locked)
                      const Positioned(
                          top: 12,
                          left: 12,
                          right: 12,
                          child: IgnorePointer(
                              child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                      color: AppColors.surface,
                                      borderRadius:
                                          BorderRadius.all(Radius.circular(8)),
                                      child: Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 12, vertical: 8),
                                          child: Text('Chạm để chọn vị trí',
                                              style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: AppColors.navy))))))),
                    Align(
                        alignment: Alignment.bottomRight,
                        child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Material(
                                color: Theme.of(context).colorScheme.surface,
                                child: InkWell(
                                    onTap: () => launchUrl(Uri.parse(
                                        'https://www.openstreetmap.org/copyright')),
                                    child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8, vertical: 14),
                                        child: Text(
                                            '© OpenStreetMap contributors',
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: AppColors.navy),
                                            softWrap: true)))))),
                  ]))),
      if (tileError)
        Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
          const Text(
              'Không tải được nền bản đồ. Vẫn có thể nhập địa chỉ hoặc dùng GPS.'),
          TextButton(
              onPressed: () => setState(() {
                    tileError = false;
                    tileRevision++;
                    provider = createProvider();
                  }),
              child: const Text('Tải lại bản đồ')),
        ]),
    ]);
  }
}
