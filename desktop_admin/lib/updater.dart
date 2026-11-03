import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';

import 'providers.dart';

int _compare(String a, String b) {
  final x = a.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  final y = b.split('.').map((part) => int.tryParse(part) ?? 0).toList();
  for (var i = 0; i < 3; i++) {
    final left = i < x.length ? x[i] : 0;
    final right = i < y.length ? y[i] : 0;
    if (left != right) return left.compareTo(right);
  }
  return 0;
}

Future<void>? _updateCheck;

Future<void> checkForUpdate(BuildContext context, WidgetRef ref) {
  if (_updateCheck != null) return _updateCheck!;
  return _updateCheck = _checkForUpdate(context, ref);
}

Future<void> _checkForUpdate(BuildContext context, WidgetRef ref) async {
  if (!Platform.isWindows) return;

  try {
    final current = (await PackageInfo.fromPlatform()).version;
    final response = await ref.read(apiClientProvider).get('/app-version');
    if (response is! Map) return;
    final data = Map<String, dynamic>.from(response);
    final latest = data['desktop_latest'] as String? ?? '';
    final minimum = data['desktop_minimum'] as String? ?? '';
    final url = data['desktop_url'] as String? ?? '';
    if (latest.isEmpty || url.isEmpty || _compare(latest, current) <= 0) return;

    final forced = minimum.isNotEmpty && _compare(minimum, current) > 0;
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: !forced,
      builder: (_) => _UpdateDialog(
        latest: latest,
        notes: data['notes'] as String? ?? '',
        url: url,
        forced: forced,
        api: ref.read(apiClientProvider),
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Desktop update check failed: $error\n$stackTrace');
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.latest,
    required this.notes,
    required this.url,
    required this.forced,
    required this.api,
  });

  final String latest;
  final String notes;
  final String url;
  final bool forced;
  final ApiClient api;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  int _progress = 0;
  String? _error;

  Future<void> _start() async {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      final directory = await getTemporaryDirectory();
      final file = File(
        '${directory.path}${Platform.pathSeparator}HRMS-Admin-Setup-${widget.latest}.exe',
      );
      await widget.api.dio.download(
        widget.url,
        file.path,
        onReceiveProgress: (received, total) {
          if (!mounted || total <= 0) return;
          setState(() => _progress = (received * 100 / total).round());
        },
      );
      if (!mounted) return;
      setState(() => _busy = false);
      await Process.start(file.path, [
        '/SILENT',
        '/CLOSEAPPLICATIONS',
      ], mode: ProcessStartMode.detached);
      exit(0);
    } on DioException catch (error, stackTrace) {
      debugPrint('Desktop update download failed: $error\n$stackTrace');
      _fail('The download failed. Check your connection and try again.');
    } on FileSystemException catch (error, stackTrace) {
      debugPrint('Desktop update file error: $error\n$stackTrace');
      _fail('The installer could not be saved or started.');
    } on ProcessException catch (error, stackTrace) {
      debugPrint('Desktop installer could not start: $error\n$stackTrace');
      _fail('The installer could not be started.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.forced,
      child: AlertDialog(
        title: const Text('Update available'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version ${widget.latest} is ready.'),
            if (widget.notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(widget.notes),
            ],
            if (widget.forced) ...[
              const SizedBox(height: 8),
              const Text('This update is required to keep using the app.'),
            ],
            if (_busy) ...[
              const SizedBox(height: 16),
              LinearProgressIndicator(value: _progress / 100),
              const SizedBox(height: 4),
              Text('Downloading... $_progress%'),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
        actions: [
          if (!widget.forced && !_busy)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Later'),
            ),
          FilledButton(
            onPressed: _busy ? null : _start,
            child: const Text('Update now'),
          ),
        ],
      ),
    );
  }
}
