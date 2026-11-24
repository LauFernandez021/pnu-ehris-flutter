import 'package:flutter/material.dart';
import 'package:hrms_core/hrms_core.dart';

import 'pnu_api.dart';

class PnuPasswordChangePage extends StatefulWidget {
  const PnuPasswordChangePage({
    super.key,
    required this.api,
    required this.onComplete,
    this.allowBack = true,
  });

  final ApiClient api;
  final Future<void> Function() onComplete;
  final bool allowBack;

  @override
  State<PnuPasswordChangePage> createState() => _PnuPasswordChangePageState();
}

class _PnuPasswordChangePageState extends State<PnuPasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await PnuAuthService(widget.api).changePassword(
        currentPassword: _current.text,
        newPassword: _new.text,
        confirmPassword: _confirm.text,
      );
      await widget.onComplete();
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        if (widget.allowBack) Navigator.of(context).pop();
        messenger.showSnackBar(
          const SnackBar(content: Text('Password changed.')),
        );
      }
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: widget.allowBack,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.allowBack,
          title: const Text('Change password'),
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextFormField(
                controller: _current,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Current password'),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter your current password.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _new,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'New password'),
                validator: (value) => value == null || value.length < 8
                    ? 'Use at least 8 characters.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                ),
                validator: (value) => value != _new.text
                    ? 'The passwords do not match.'
                    : null,
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
