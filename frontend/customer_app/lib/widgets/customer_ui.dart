import '../app/mobile_ui.dart';
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
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: RescueSurfaces.decoration(),
        child: Row(children: [
          const Icon(Icons.health_and_safety_outlined,
              color: RescueColors.navy, size: 26),
          const SizedBox(width: 12),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(title, style: RescueType.page),
                if (subtitle != null)
                  Text(subtitle!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: RescueType.caption),
              ])),
          if (trailing != null) trailing!,
        ]),
      );
}

/// Natural tile height allows Vietnamese labels to wrap at large text sizes.
class ServiceGrid extends StatelessWidget {
  const ServiceGrid(
      {super.key,
      this.selected,
      required this.onSelected,
      this.selectedColor = AppColors.navy,
      this.selectedBackground = AppColors.selected});
  final RescueService? selected;
  final ValueChanged<RescueService>? onSelected;
  final Color selectedColor, selectedBackground;
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
                                  selectedColor: selectedColor,
                                  selectedBackground: selectedBackground,
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
                style: label.startsWith('Mã')
                    ? RescueType.code
                    : RescueType.body.copyWith(fontWeight: FontWeight.w600))),
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
          padding: const EdgeInsets.all(RescueSpace.md),
          decoration: BoxDecoration(
              color: isError ? RescueColors.dangerSoft : RescueColors.selected,
              borderRadius: BorderRadius.circular(RescueRadius.control)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(isError ? Icons.error_outline : Icons.info_outline,
                color: isError ? RescueColors.danger : RescueColors.navy,
                size: 22),
            const SizedBox(width: RescueSpace.sm),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(isError ? 'Chưa thể hoàn tất' : 'Thông tin',
                      style: RescueType.title),
                  const SizedBox(height: RescueSpace.xs),
                  Text(message, style: RescueType.body),
                  if (onRetry != null)
                    TextButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: Text(retryLabel)),
                ])),
          ])));
}

class CustomerEmptyState extends StatelessWidget {
  const CustomerEmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message,
      this.action,
      this.kind = RescueFeedbackKind.empty});
  final IconData icon;
  final String title, message;
  final Widget? action;
  final RescueFeedbackKind kind;
  @override
  Widget build(BuildContext context) => RescueFeedback(
      icon: icon, title: title, message: message, action: action, kind: kind);
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
        title: Text(title, style: RescueType.title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right_rounded),
      );
}

/// Secondary content is available on demand without losing local widget state.
class MoreDetails extends StatelessWidget {
  const MoreDetails({super.key, required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
          child: ExpansionTile(
        key: PageStorageKey('details-$title'),
        title: Text(title),
        maintainState: true,
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.all(16),
        children: children,
      ));
}
