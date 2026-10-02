import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/user_session.dart';
import 'customer_ui.dart';
import '../services/customer_vehicle_service.dart';

class SavedVehiclePicker extends StatefulWidget {
  const SavedVehiclePicker(
      {super.key,
      required this.controller,
      required this.locked,
      this.repository = const SupabaseCustomerVehicleRepository()});
  final AppController controller;
  final bool locked;
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
          setState(() => error =
              'Xe đã chọn không còn trong danh sách. Bạn có thể chọn xe khác hoặc dùng phương tiện thủ công.');
        } else {
          widget.controller.selectSavedVehicle(match);
        }
      }
    } catch (_) {
      if (mounted && version == generation)
        setState(() => error =
            'Không tải được xe đã lưu. Bạn vẫn có thể chọn phương tiện thủ công.');
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (owner == null) return const SizedBox.shrink();
    final selected = widget.controller.selectedSavedVehicle;
    final items = [...vehicles];
    if (selected != null && !items.any((item) => item.id == selected.id))
      items.add(selected);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (loading) const LinearProgressIndicator(),
      InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Xe đã lưu (tùy chọn)',
              prefixIcon: Icon(Icons.garage_outlined)),
          child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  isExpanded: true,
                  value: selected?.id ?? '',
                  items: [
                    const DropdownMenuItem(
                        value: '',
                        child: Text('Phương tiện thủ công',
                            maxLines: 1, overflow: TextOverflow.ellipsis)),
                    ...items.map((vehicle) => DropdownMenuItem(
                        value: vehicle.id,
                        child: Text(vehicle.label,
                            maxLines: 1, overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: widget.locked || loading
                      ? null
                      : (id) {
                          if (id == '')
                            widget.controller
                                .selectVehicle(widget.controller.vehicle);
                          else
                            widget.controller.selectSavedVehicle(
                                items.firstWhere((item) => item.id == id));
                        }))),
      if (error != null) ...[const SizedBox(height: 8), InlineNotice(error!)],
      if (!loading && error == null && items.isEmpty)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Chưa có xe đã lưu. Thêm xe tại Tài khoản → Phương tiện của tôi.')),
      Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: widget.locked || loading ? null : load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại xe đã lưu'))),
    ]);
  }
}
