import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_theme.dart';
import 'rescue_widgets.dart';

Duration customerMotion(BuildContext context, [int milliseconds = 180]) =>
    MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : Duration(milliseconds: milliseconds);

String displayCustomerName(String? value) => (value ?? '')
    .trim()
    .split(RegExp(r'\s+'))
    .where((word) => word.isNotEmpty)
    .map((word) =>
        '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}')
    .join(' ');

String customerDate(DateTime date, {bool includeTime = false}) {
  final local = date.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year}'
      '${includeTime ? ' • ${two(local.hour)}:${two(local.minute)}' : ''}';
}

class ScreenHeader extends StatelessWidget {
  const ScreenHeader(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(subtitle!, style: const TextStyle(color: AppColors.muted))
          ],
        ])),
        if (trailing != null) trailing!,
      ]));
}

/// Natural tile height allows Vietnamese labels to wrap at large text sizes.
class ServiceGrid extends StatelessWidget {
  const ServiceGrid({super.key, this.selected, required this.onSelected});
  final RescueService? selected;
  final ValueChanged<RescueService>? onSelected;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, box) => Column(children: [
            for (var row = 0; row < RescueService.values.length; row += 2) ...[
              if (row > 0) const SizedBox(height: 8),
              IntrinsicHeight(
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                    for (var column = 0; column < 2; column++) ...[
                      if (column > 0) const SizedBox(width: 8),
                      Expanded(
                          child: row + column < RescueService.values.length
                              ? ChoiceTile(
                                  icon: serviceIcon(
                                      RescueService.values[row + column]),
                                  label:
                                      RescueService.values[row + column].label,
                                  selected: selected ==
                                      RescueService.values[row + column],
                                  onTap: onSelected == null
                                      ? null
                                      : () => onSelected!(
                                          RescueService.values[row + column]))
                              : const SizedBox.shrink()),
                    ],
                  ])),
            ],
          ]));
}

class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key, this.icon});
  final String label, value;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        if (icon != null) ...[
          Icon(icon, size: 22, color: AppColors.navy),
          const SizedBox(width: 8)
        ],
        SizedBox(
            width: 96,
            child: Text(label, style: const TextStyle(color: AppColors.muted))),
        const SizedBox(width: 8),
        Expanded(
            child: SelectableText(value,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]));
}

class InlineNotice extends StatelessWidget {
  const InlineNotice(this.message,
      {super.key,
      this.onRetry,
      this.retryLabel = 'Thử lại',
      this.isError = true});
  final String message, retryLabel;
  final VoidCallback? onRetry;
  final bool isError;
  @override
  Widget build(BuildContext context) => Semantics(
      liveRegion: true,
      child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: isError ? const Color(0xFFFFF3F2) : AppColors.selected,
              borderRadius: BorderRadius.circular(8),
              border: Border(
                  left: BorderSide(
                      width: 3,
                      color: isError ? AppColors.error : AppColors.navy))),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(message,
                style: TextStyle(
                    color: isError ? AppColors.error : AppColors.navy)),
            if (onRetry != null)
              TextButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(retryLabel)),
          ])));
}

class CustomerEmptyState extends StatelessWidget {
  const CustomerEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.action});
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(children: [
        Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: AppColors.selected,
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, size: 32, color: AppColors.navy)),
        const SizedBox(height: 16),
        Text(title,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.muted)),
        if (action != null) ...[const SizedBox(height: 24), action!],
      ]));
}

class SettingsRow extends StatelessWidget {
  const SettingsRow(
      {super.key,
      required this.icon,
      required this.title,
      required this.subtitle,
      required this.onTap});
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: Icon(icon),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}
