import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ota_update/ota_update.dart';
import 'package:package_info_plus/package_info_plus.dart';

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
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;

  try {
    final current = (await PackageInfo.fromPlatform()).version;
    final response = await ref.read(apiClientProvider).get('/app-version');
    if (response is! Map) return;
    final data = Map<String, dynamic>.from(response);
    final latest = data['latest'] as String? ?? '';
    final minimum = data['minimum'] as String? ?? '';
    final url = data['apk_url'] as String? ?? '';
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
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('Mobile update check failed: $error\n$stackTrace');
  }
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog({
    required this.latest,
    required this.notes,
    required this.url,
    required this.forced,
  });

  final String latest;
  final String notes;
  final String url;
  final bool forced;

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends State<_UpdateDialog> {
  bool _busy = false;
  int _progress = 0;
  String? _error;

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  void _start() {
    setState(() {
      _busy = true;
      _error = null;
      _progress = 0;
    });
    try {
      OtaUpdate()
          .execute(
            widget.url,
            destinationFilename: 'hrms-update.apk',
            usePackageInstaller: true,
          )
          .listen(
            (event) {
              if (!mounted) return;
              switch (event.status) {
                case OtaStatus.DOWNLOADING:
                  setState(
                    () => _progress = int.tryParse(event.value ?? '') ?? 0,
                  );
                case OtaStatus.INSTALLING:
                  setState(() {
                    _progress = int.tryParse(event.value ?? '') ?? _progress;
                  });
                case OtaStatus.INSTALLATION_DONE:
                  setState(() => _busy = false);
                default:
                  _fail(
                    event.value?.isNotEmpty == true
                        ? 'The update could not be installed: ${event.value}'
                        : 'The update could not be installed (${event.status.name}).',
                  );
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              debugPrint('Mobile update download failed: $error\n$stackTrace');
              _fail('The download failed. Check your connection.');
            },
          );
    } catch (error, stackTrace) {
      debugPrint('Mobile update could not start: $error\n$stackTrace');
      _fail('The update could not start.');
    }
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
