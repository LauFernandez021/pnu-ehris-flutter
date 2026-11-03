import 'package:flutter/material.dart';

import 'api_client.dart';
import 'services.dart';

class PasswordChangePage extends StatefulWidget {
  const PasswordChangePage({
    required this.api,
    required this.onComplete,
    this.mandatory = false,
    super.key,
  });

  final ApiClient api;
  final Future<void> Function() onComplete;
  final bool mandatory;

  @override
  State<PasswordChangePage> createState() => _PasswordChangePageState();
}

class _PasswordChangePageState extends State<PasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentPassword = TextEditingController();
  final _newPassword = TextEditingController();
  final _confirmation = TextEditingController();
  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirmation = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _currentPassword.dispose();
    _newPassword.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await AuthService(widget.api).changePassword(
        currentPassword: _currentPassword.text,
        newPassword: _newPassword.text,
      );
      await widget.onComplete();
      if (!mounted) return;
      if (!widget.mandatory) Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.length < 10) {
      return 'Use at least 10 characters.';
    }
    if (!value.contains(RegExp('[A-Z]')) ||
        !value.contains(RegExp('[a-z]')) ||
        !value.contains(RegExp('[0-9]'))) {
      return 'Include uppercase and lowercase letters and a number.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.mandatory,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: !widget.mandatory,
          title: Text(
            widget.mandatory ? 'Secure your account' : 'Change password',
          ),
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Icon(
                          Icons.lock_reset,
                          size: 40,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          widget.mandatory
                              ? 'Choose a new password to continue.'
                              : 'Update your account password.',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 20),
                        TextFormField(
                          controller: _currentPassword,
                          obscureText: !_showCurrent,
                          enabled: !_saving,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(
                            labelText: 'Current password',
                            suffixIcon: IconButton(
                              tooltip: _showCurrent
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () =>
                                  setState(() => _showCurrent = !_showCurrent),
                              icon: Icon(
                                _showCurrent
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) => value == null || value.isEmpty
                              ? 'Enter your current password.'
                              : null,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _newPassword,
                          obscureText: !_showNew,
                          enabled: !_saving,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: InputDecoration(
                            labelText: 'New password',
                            helperText: 'At least 10 characters, upper and lower case, and a number.',
                            helperMaxLines: 2,
                            suffixIcon: IconButton(
                              tooltip: _showNew
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () =>
                                  setState(() => _showNew = !_showNew),
                              icon: Icon(
                                _showNew
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: _validateNewPassword,
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          controller: _confirmation,
                          obscureText: !_showConfirmation,
                          enabled: !_saving,
                          decoration: InputDecoration(
                            labelText: 'Confirm new password',
                            suffixIcon: IconButton(
                              tooltip: _showConfirmation
                                  ? 'Hide password'
                                  : 'Show password',
                              onPressed: () => setState(
                                () => _showConfirmation = !_showConfirmation,
                              ),
                              icon: Icon(
                                _showConfirmation
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                            ),
                          ),
                          validator: (value) => value != _newPassword.text
                              ? 'The passwords do not match.'
                              : null,
                        ),
                        if (_error != null) ...[
                          const SizedBox(height: 12),
                          Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          onPressed: _saving ? null : _submit,
                          icon: _saving
                              ? const SizedBox.square(
                                  dimension: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.check),
                          label: Text(
                            _saving ? 'Updating...' : 'Update password',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
