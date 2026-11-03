import 'package:flutter/material.dart';
import 'package:hrms_core/hrms_core.dart';

class PassSlipCard extends StatelessWidget {
  const PassSlipCard({
    super.key,
    required this.slip,
    this.showEmployee = false,
    this.actions = const [],
  });
  final PassSlip slip;
  final bool showEmployee;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final s = slip;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showEmployee) ...[
              InitialsAvatar(s.employeeName),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showEmployee)
                    Text(s.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(s.typeLabel,
                      style: showEmployee
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                      '${shortDate(s.slipDate)} · ${timeLabel(s.timeOut)} – ${timeLabel(s.timeIn)}',
                      style: muted),
                  Text('To: ${s.destination}', style: muted),
                ],
              ),
            ),
            StatusChip(s.status),
          ]),
          if ((s.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('"${s.reason}"',
                style: muted.copyWith(fontStyle: FontStyle.italic)),
          ],
          if ((s.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${s.reviewNote}', style: muted),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.end, children: actions),
          ],
        ]),
      ),
    );
  }
}