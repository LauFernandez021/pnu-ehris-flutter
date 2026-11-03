import 'package:flutter/material.dart';
import 'package:hrms_core/hrms_core.dart';

class RequestCard extends StatelessWidget {
  const RequestCard({
    super.key,
    required this.request,
    this.showEmployee = false,
    this.actions = const [],
    this.onViewAttachment,
  });
  final LeaveRequest request;
  final bool showEmployee;
  final List<Widget> actions;
  final VoidCallback? onViewAttachment;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant);
    final r = request;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (showEmployee) ...[
              InitialsAvatar(r.employeeName),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (showEmployee)
                    Text(r.employeeName,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  Text(r.leaveType,
                      style: showEmployee
                          ? theme.textTheme.bodyMedium
                          : theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                      '${shortDate(r.startDate)} – ${shortDate(r.endDate)} · ${daysText(r.days)}',
                      style: muted),
                ],
              ),
            ),
            StatusChip(r.status),
          ]),
          if ((r.reason ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('"${r.reason}"',
                style: muted.copyWith(fontStyle: FontStyle.italic)),
          ],
          if (r.hasAttachment) ...[
            const SizedBox(height: 8),
            InkWell(
              onTap: onViewAttachment,
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.attach_file,
                    size: 16,
                    color: onViewAttachment != null
                        ? theme.colorScheme.primary
                        : theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    r.attachmentName ?? 'Attachment',
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: onViewAttachment != null
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ]),
            ),
          ],
          if ((r.reviewNote ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text('Note: ${r.reviewNote}', style: muted),
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