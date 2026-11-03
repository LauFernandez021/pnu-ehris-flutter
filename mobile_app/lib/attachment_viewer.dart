import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';

import 'providers.dart';

Future<void> viewLeaveAttachment(
    BuildContext context, WidgetRef ref, LeaveRequest r) async {
  final messenger = ScaffoldMessenger.of(context);
  try {
    final bytes = await ref
        .read(apiClientProvider)
        .getBytes('/leave-requests/${r.id}/attachment');
    if (!context.mounted) return;

    if ((r.attachmentName ?? '').toLowerCase().endsWith('.pdf')) {
      messenger.showSnackBar(const SnackBar(
          content: Text('PDF attachments can be opened on the desktop app.')));
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(child: InteractiveViewer(child: Image.memory(bytes))),
    );
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(content: Text(e.message)));
  }
}