import 'package:flutter/material.dart';

import '../services/location_service.dart';
import '../services/request_photo_service.dart';
import 'booking_form_ui.dart';
import 'booking_ui.dart';

class BookingLocationSummary extends StatelessWidget {
  const BookingLocationSummary(
      {super.key,
      required this.address,
      required this.coordinates,
      required this.onEdit});
  final String address;
  final RescueCoordinates? coordinates;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    if (address.trim().isEmpty && coordinates?.isValid != true) {
      return _BookingEmptySection(
          key: const ValueKey('booking-location-empty'),
          section: 'Lộ trình cứu hộ',
          title: 'Chưa chọn vị trí cứu hộ',
          subtitle: 'Chọn địa chỉ hoặc vị trí xe gặp sự cố.',
          icon: Icons.location_on_outlined,
          action: 'Chọn vị trí',
          onPressed: onEdit);
    }
    return Card(
        key: const ValueKey('booking-location-summary'),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Lộ trình cứu hộ',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: BookingFormStyle.navy)),
              const SizedBox(height: 14),
              BookingPickupPoint(
                  address: address.trim(),
                  coordinates: coordinates,
                  onEdit: onEdit),
            ])));
  }
}

class BookingIncidentSummary extends StatelessWidget {
  const BookingIncidentSummary(
      {super.key,
      required this.description,
      required this.photos,
      required this.uploaded,
      required this.onEdit,
      required this.onAdd,
      required this.onRemove});
  final String description;
  final List<SelectedRequestPhoto> photos;
  final Set<String> uploaded;
  final VoidCallback? onEdit, onAdd;
  final ValueChanged<int>? onRemove;

  @override
  Widget build(BuildContext context) {
    final empty = description.trim().isEmpty && photos.isEmpty;
    return Card(
        key: ValueKey(
            empty ? 'booking-incident-empty' : 'booking-incident-summary'),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Expanded(
                    child: Text('Mô tả sự cố & Hiện trường',
                        style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BookingFormStyle.navy))),
                const SizedBox(width: 8),
                Text('${photos.length}/3 ảnh',
                    style: const TextStyle(
                        fontSize: 11, color: BookingFormStyle.muted)),
              ]),
              const SizedBox(height: 12),
              ...[
                Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: BookingFormStyle.pale,
                        borderRadius: BorderRadius.circular(12)),
                    child: Text(
                        description.trim().isEmpty
                            ? 'Thêm mô tả hoặc ảnh sự cố'
                            : description.trim(),
                        key: const ValueKey('booking-incident-description'),
                        style: const TextStyle(
                            fontSize: 14,
                            height: 1.4,
                            color: BookingFormStyle.ink))),
                const SizedBox(height: 12),
              ],
              PhotoPickerGrid(
                  photos: photos,
                  uploaded: uploaded,
                  onRemove: onRemove,
                  onAdd: onAdd),
              TextButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: Text(
                      empty ? 'Bổ sung mô tả / ảnh' : 'Chỉnh sửa mô tả / ảnh')),
            ])));
  }
}

class _BookingEmptySection extends StatelessWidget {
  const _BookingEmptySection(
      {super.key,
      required this.section,
      required this.title,
      required this.subtitle,
      required this.icon,
      required this.action,
      required this.onPressed});
  final String section, title, subtitle, action;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(section,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: BookingFormStyle.navy)),
            const SizedBox(height: 14),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                      color: BookingFormStyle.pale,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(icon, size: 26, color: BookingFormStyle.blue)),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: BookingFormStyle.ink)),
                    const SizedBox(height: 4),
                    Text(subtitle,
                        style: const TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: BookingFormStyle.muted)),
                  ])),
            ]),
            const SizedBox(height: 12),
            SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                    onPressed: onPressed,
                    style: FilledButton.styleFrom(
                        backgroundColor: BookingFormStyle.pale,
                        foregroundColor: BookingFormStyle.blue,
                        textStyle: const TextStyle(
                            fontFamily: 'Plus Jakarta Sans',
                            fontSize: 14,
                            fontWeight: FontWeight.w600),
                        minimumSize: const Size(48, 48),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14))),
                    child: Text(action, textAlign: TextAlign.center))),
          ])));
}
