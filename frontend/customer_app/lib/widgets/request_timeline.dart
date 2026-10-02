import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_theme.dart';

/// Vertical steps retain readable labels on narrow screens and large text.
class RequestTimeline extends StatelessWidget {
  const RequestTimeline({super.key, required this.stage});
  final RequestStage stage;

  @override
  Widget build(BuildContext context) {
    const labels = [
      'Đang tìm',
      'Đã nhận',
      'Đang đến',
      'Đang cứu hộ',
      'Hoàn tất'
    ];
    const icons = [
      Icons.search_rounded,
      Icons.task_alt_rounded,
      Icons.navigation_rounded,
      Icons.build_rounded,
      Icons.check_circle_rounded
    ];
    final current = stage == RequestStage.cancelled ? -1 : stage.index;
    return Column(children: [
      for (var i = 0; i < labels.length; i++)
        TimelineEntry(
            title: labels[i],
            icon: icons[i],
            active: i <= current,
            current: i == current,
            last: i == labels.length - 1),
    ]);
  }
}

class TimelineEntry extends StatelessWidget {
  const TimelineEntry(
      {super.key,
      required this.title,
      this.subtitle,
      this.icon = Icons.check_rounded,
      this.active = true,
      this.current = false,
      this.last = false});
  final String title;
  final String? subtitle;
  final IconData icon;
  final bool active, current, last;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
              width: 36,
              child: Column(children: [
                AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 180),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                        color:
                            active ? AppColors.selected : AppColors.background,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color:
                                current ? AppColors.navy : AppColors.border)),
                    child: Icon(icon,
                        size: 22,
                        color: active ? AppColors.navy : AppColors.muted)),
                if (!last)
                  Expanded(
                      child: Center(
                          child: Container(
                              width: 2,
                              color: active
                                  ? AppColors.selected
                                  : AppColors.border))),
              ])),
          const SizedBox(width: 12),
          Expanded(
              child: Padding(
                  padding: EdgeInsets.only(top: 5, bottom: last ? 4 : 12),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight:
                                    current ? FontWeight.w700 : FontWeight.w600,
                                color:
                                    active ? AppColors.text : AppColors.muted)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 4),
                          Text(subtitle!,
                              style: Theme.of(context).textTheme.bodySmall)
                        ],
                      ]))),
        ]),
      );
}
