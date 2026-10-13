import 'package:flutter/material.dart';

import '../../app/mobile_ui.dart';

/// Controlled expansion keeps child state alive, including unsaved form fields.
class PartnerAccordion extends StatelessWidget {
  const PartnerAccordion({
    super.key,
    required this.id,
    required this.title,
    required this.icon,
    required this.expanded,
    required this.onToggle,
    required this.child,
    this.subtitle,
  });

  final String id, title;
  final String? subtitle;
  final IconData icon;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget child;

  @override
  Widget build(BuildContext context) => Container(
    decoration: RescueSurfaces.decoration(),
    child: Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(RescueRadius.card),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: expanded,
            child: InkWell(
              key: ValueKey('accordion-$id-toggle'),
              onTap: () {
                FocusScope.of(context).unfocus();
                onToggle();
              },
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 64),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 22, color: RescueColors.navy),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: RescueType.title),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(subtitle!, style: RescueType.caption),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      AnimatedRotation(
                        turns: expanded ? .5 : 0,
                        duration: const Duration(milliseconds: 220),
                        child: const Icon(Icons.expand_more, size: 22),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            child: Offstage(
              offstage: !expanded,
              child: TickerMode(
                enabled: expanded,
                child: Padding(
                  key: ValueKey('accordion-$id-content'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Divider(height: 1),
                      const SizedBox(height: 12),
                      child,
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
