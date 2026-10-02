import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/user_session.dart';
import 'customer_ui.dart';
import '../services/customer_saved_address_service.dart';

class SavedAddressPicker extends StatefulWidget {
  const SavedAddressPicker(
      {super.key,
      required this.controller,
      required this.locked,
      required this.onSelected,
      this.repository = const SupabaseCustomerSavedAddressRepository()});
  final AppController controller;
  final bool locked;
  final ValueChanged<CustomerSavedAddress> onSelected;
  final CustomerSavedAddressRepository repository;
  @override
  State<SavedAddressPicker> createState() => _SavedAddressPickerState();
}

class _SavedAddressPickerState extends State<SavedAddressPicker> {
  List<CustomerSavedAddress> addresses = [];
  String? owner;
  String? error;
  bool loading = false;
  int generation = 0;

  int tab = 0;
  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;

    tab = widget.controller.tabIndex;
    widget.controller.addListener(changed);
    if (owner != null) load();
  }

  void changed() {
    final identityChanged = owner != UserSession.userId;
    final reload =
        identityChanged || (tab != 1 && widget.controller.tabIndex == 1);

    tab = widget.controller.tabIndex;
    if (identityChanged) {
      generation++;
      addresses = [];
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
      setState(() => addresses = result);
    } catch (_) {
      if (mounted && version == generation)
        setState(() => error =
            'Không tải được địa chỉ đã lưu. Bạn vẫn có thể nhập địa chỉ bằng tay.');
    } finally {
      if (mounted && version == generation) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (owner == null) return const SizedBox.shrink();
    final items = addresses;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (loading) const LinearProgressIndicator(),
      InputDecorator(
          decoration: const InputDecoration(
              labelText: 'Địa chỉ đã lưu (tùy chọn)',
              prefixIcon: Icon(Icons.bookmark_border_rounded)),
          child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                  isExpanded: true,
                  value: '',
                  items: [
                    const DropdownMenuItem(
                        value: '', child: Text('Chọn địa chỉ đã lưu')),
                    ...items.map((item) => DropdownMenuItem(
                        value: item.id,
                        child: Text(
                            '${item.label}${item.isDefault ? ' (Mặc định)' : ''} — ${item.address}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis))),
                  ],
                  onChanged: widget.locked || loading
                      ? null
                      : (id) {
                          if (id != null && id.isNotEmpty)
                            widget.onSelected(
                                items.firstWhere((item) => item.id == id));
                        }))),
      if (error != null) ...[const SizedBox(height: 8), InlineNotice(error!)],
      if (!loading && error == null && items.isEmpty)
        const Padding(
            padding: EdgeInsets.only(top: 8),
            child: Text(
                'Chưa có địa chỉ đã lưu. Thêm tại Tài khoản → Địa chỉ đã lưu.')),
      Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
              onPressed: widget.locked || loading ? null : load,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tải lại địa chỉ đã lưu'))),
    ]);
  }
}
