import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  const StatusChip(this.status, {super.key});
  final String status;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      'approved' || 'active' => (Colors.green.shade50, Colors.green.shade800),
      'pending' => (Colors.orange.shade50, Colors.orange.shade900),
      'rejected' || 'inactive' => (Colors.red.shade50, Colors.red.shade800),
      _ => (Colors.grey.shade200, Colors.grey.shade800),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(status,
          style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}

class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar(this.name, {super.key, this.radius = 18});
  final String name;
  final double radius;

  String get _initials {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    final first = parts.first[0];
    final last = parts.length > 1 ? parts.last[0] : '';
    return (first + last).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return CircleAvatar(
      radius: radius,
      backgroundColor: scheme.primaryContainer,
      child: Text(_initials,
          style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
              fontSize: radius * 0.7)),
    );
  }
}

/// Asks for a rejection reason. Returns null if cancelled.
Future<String?> askRejectionNote(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (_) => const _RejectionDialog(),
  );
}

class _RejectionDialog extends StatefulWidget {
  const _RejectionDialog();

  @override
  State<_RejectionDialog> createState() => _RejectionDialogState();
}

class _RejectionDialogState extends State<_RejectionDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reject request'),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _controller,
          autofocus: true,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'Reason for rejection',
            errorText: _error,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _controller.text.trim();
            if (text.isEmpty) {
              setState(() => _error = 'Please give a reason');
              return;
            }
            Navigator.of(context).pop(text);
          },
          child: const Text('Reject'),
        ),
      ],
    );
  }
}