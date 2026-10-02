import 'package:flutter/material.dart';
import '../app/app_theme.dart';
import 'rescue_widgets.dart';

class FormSection extends StatelessWidget {
  const FormSection(
      {super.key,
      required this.title,
      required this.icon,
      required this.children,
      this.subtitle});
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: AppColors.navy, size: 22),
          const SizedBox(width: 8),
          Expanded(child: SectionTitle(title, subtitle: subtitle)),
        ]),
        const SizedBox(height: 12),
        ...children,
      ]);
}
