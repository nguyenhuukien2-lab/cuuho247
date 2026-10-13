import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/user_session.dart';
import 'customer_ui.dart';
import '../services/customer_vehicle_service.dart';
import 'booking_ui.dart';
import 'booking_form_ui.dart';
import '../screens/customer_vehicles_screen.dart';

class SavedVehiclePicker extends StatefulWidget {
  const SavedVehiclePicker({
    super.key,
    required this.controller,
    required this.locked,
    this.cardLayout = false,
    this.manualControls,
    this.repository = const SupabaseCustomerVehicleRepository(),
  });
  final AppController controller;
  final bool locked;
  final bool cardLayout;
  final Widget? manualControls;
  final CustomerVehicleRepository repository;
  @override
  State<SavedVehiclePicker> createState() => _SavedVehiclePickerState();
}

class _SavedVehiclePickerState extends State<SavedVehiclePicker> {
  List<CustomerVehicle> vehicles = [];
  String? owner;
  String? error;
  bool loading = false;
  int generation = 0;
  int revision = 0;
  int tab = 0;
  bool _manualExpanded = false;
  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    revision = widget.controller.vehiclesRevision;
    tab = widget.controller.tabIndex;
    widget.controller.addListener(changed);
    if (owner != null) load();
  }

  void changed() {
    final identityChanged = owner != UserSession.userId;
    final reload = identityChanged ||
        revision != widget.controller.vehiclesRevision ||
        (tab != 1 && widget.controller.tabIndex == 1);
    revision = widget.controller.vehiclesRevision;
    tab = widget.controller.tabIndex;
    if (identityChanged) {
      generation++;
      vehicles = [];
      error = null;
      loading = false;
      owner = UserSession.userId;
    }
    if (!mounted) return;
    setState(() {});
    if (reload && owner != null && !widget.locked) load();
  }

  @override
  void dispose() {
    generation++;
    widget.controller.removeListener(changed);
    super.dispose();
  }

  Future<void> load() async {
    final version = ++generation;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await widget.repository.list();
      if (!mounted || version != generation || owner != UserSession.userId)
        return;
      setState(() => vehicles = result);
      final selected = widget.controller.selectedSavedVehicle;
      if (selected != null && !widget.locked) {
        final match =
            result.where((vehicle) => vehicle.id == selected.id).firstOrNull;
        if (match == null) {
          widget.controller.selectVehicle(widget.controller.vehicle);
          setState(
            () => error =
                'Xe đã chọn không còn trong danh sách. Bạn có thể chọn xe khác hoặc dùng phương tiện thủ công.',
          );
        } else {
          widget.controller.selectSavedVehicle(match);
        }
      }
    } catch (_) {
      if (mounted && version == generation)
        setState(
          () => error =
              'Không tải được xe đã lưu. Bạn vẫn có thể chọn phương tiện thủ công.',
        );
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (owner == null) {
      if (!widget.cardLayout) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Chọn phương tiện gặp sự cố',
              style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  color: BookingFormStyle.ink)),
          const SizedBox(height: 12),
          if (widget.manualControls != null) widget.manualControls!,
        ],
      );
    }
    final selected = widget.controller.selectedSavedVehicle;
    final items = [...vehicles];
    if (selected != null && !items.any((item) => item.id == selected.id))
      items.add(selected);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (loading) const LinearProgressIndicator(),
        if (widget.cardLayout) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Padding(
                padding: const EdgeInsets.only(top: 9, right: 7),
                child: Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                        color: BookingFormStyle.green, shape: BoxShape.circle)),
              ),
              const Expanded(
                  child: Text('Chọn phương tiện gặp sự cố',
                      style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: BookingFormStyle.ink))),
              const SizedBox(width: 8),
              if (!loading && error == null)
                Text('${items.length} xe có sẵn',
                    style: const TextStyle(
                        fontSize: 11, color: BookingFormStyle.muted)),
            ]),
          ),
          if (!loading && error == null && items.isEmpty)
            Container(
                key: const ValueKey('booking-empty-vehicles'),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                    color: BookingFormStyle.pale,
                    borderRadius: BorderRadius.circular(16)),
                child: const Row(children: [
                  Icon(Icons.directions_car_outlined,
                      size: 32, color: BookingFormStyle.blue),
                  SizedBox(width: 12),
                  Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                        Text('Chưa có xe đã lưu',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text('Thêm phương tiện hoặc chọn loại xe bên dưới.',
                            style: TextStyle(
                                fontSize: 12, color: BookingFormStyle.muted)),
                      ])),
                ])),
          for (final vehicle in items)
            VehicleSelectCard(
              vehicle: vehicle,
              selected: selected?.id == vehicle.id,
              onTap: widget.locked || loading
                  ? null
                  : () {
                      setState(() => _manualExpanded = false);
                      widget.controller.selectSavedVehicle(vehicle);
                    },
            ),
          if (items.isEmpty) const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: widget.locked || loading
                  ? null
                  : () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => CustomerVehiclesScreen(
                            controller: widget.controller,
                            repository: widget.repository,
                          ),
                        ),
                      );
                      if (mounted && !widget.locked && owner != null) load();
                    },
              style: FilledButton.styleFrom(
                backgroundColor: BookingFormStyle.pale,
                foregroundColor: const Color(0xFF1D4ED8),
                textStyle: const TextStyle(
                    fontFamily: 'Plus Jakarta Sans',
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                minimumSize: const Size(48, 52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(
                  items.isEmpty ? 'Thêm phương tiện' : 'Thêm phương tiện khác'),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    key: const ValueKey('booking-manual-vehicle-toggle'),
                    onPressed: widget.locked || loading
                        ? null
                        : () {
                            setState(() => _manualExpanded = !_manualExpanded);
                            if (_manualExpanded) {
                              widget.controller.selectVehicle(
                                widget.controller.vehicle,
                              );
                            }
                          },
                    child:
                        Text(_manualExpanded ? 'Thu gọn' : 'Chọn loại xe khác'),
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('booking-vehicles-refresh'),
                tooltip: 'Tải lại xe đã lưu',
                icon: const Icon(Icons.refresh_rounded, size: 20),
                color: BookingFormStyle.muted,
                onPressed: widget.locked || loading ? null : load,
              ),
            ],
          ),
          if (widget.manualControls != null &&
              !loading &&
              (items.isEmpty || _manualExpanded))
            widget.manualControls!,
        ] else
          InputDecorator(
            decoration: const InputDecoration(
              labelText: 'Xe đã lưu (tùy chọn)',
              prefixIcon: Icon(Icons.garage_outlined),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                isExpanded: true,
                value: selected?.id ?? '',
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text(
                      'Phương tiện thủ công',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  ...items.map(
                    (vehicle) => DropdownMenuItem(
                      value: vehicle.id,
                      child: Text(
                        vehicle.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
                onChanged: widget.locked || loading
                    ? null
                    : (id) {
                        if (id == '')
                          widget.controller.selectVehicle(
                            widget.controller.vehicle,
                          );
                        else
                          widget.controller.selectSavedVehicle(
                            items.firstWhere((item) => item.id == id),
                          );
                      },
              ),
            ),
          ),
        if (error != null) ...[const SizedBox(height: 8), InlineNotice(error!)],
        if (!widget.cardLayout && !loading && error == null && items.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
              'Chưa có xe đã lưu. Thêm xe tại Tài khoản → Phương tiện của tôi.',
            ),
          ),
        if (!widget.cardLayout)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: widget.locked || loading ? null : load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại xe đã lưu'),
            ),
          ),
      ],
    );
  }
}
