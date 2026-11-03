import 'package:flutter/material.dart';

import 'request_leave_page.dart';
import 'request_pass_slip_page.dart';

Future<void> showNewRequestSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ListTile(
          leading: const Icon(Icons.beach_access_outlined),
          title: const Text('Leave request'),
          subtitle: const Text('Vacation, sick, emergency'),
          onTap: () {
            Navigator.pop(sheetContext);
            openRequestForm(context);
          },
        ),
        ListTile(
          leading: const Icon(Icons.directions_walk),
          title: const Text('Pass slip'),
          subtitle: const Text('Step out during work hours'),
          onTap: () {
            Navigator.pop(sheetContext);
            openPassSlipForm(context);
          },
        ),
        const SizedBox(height: 8),
      ]),
    ),
  );
}