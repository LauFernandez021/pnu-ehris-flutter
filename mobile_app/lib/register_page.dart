import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hrms_core/hrms_core.dart';
import 'package:image_picker/image_picker.dart';

import 'providers.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _employeeNo = TextEditingController();
  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  Uint8List? _idPhoto;
  Uint8List? _selfie;
  bool _loading = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _code,
      _employeeNo,
      _firstName,
      _lastName,
      _email,
      _password,
      _confirm,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? 'Required' : null;

  Future<Uint8List?> _pick(ImageSource source, {required bool front}) async {
    final file = await ImagePicker().pickImage(
      source: source,
      preferredCameraDevice: front ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1600,
      imageQuality: 75,
    );
    return file?.readAsBytes();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_idPhoto == null || _selfie == null) {
      setState(() => _error = 'Please add a photo of your ID and your selfie.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await AuthService(ref.read(apiClientProvider)).register(
        employeeNo: _employeeNo.text.trim(),
        firstName: _firstName.text.trim(),
        lastName: _lastName.text.trim(),
        email: _email.text.trim(),
        password: _password.text,
        idPhoto: _idPhoto!,
        selfie: _selfie!,
        registrationCode: _code.text,
      );
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_done) {
      return Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.mark_email_read_outlined,
                    size: 72,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Registration sent',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'HR will review your account. You can sign in once it is approved.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Back to sign in'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    const gap = SizedBox(height: 16);

    return Scaffold(
      appBar: AppBar(title: const Text('Create account')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _code,
                decoration: const InputDecoration(
                  labelText: 'Company registration code',
                  helperText:
                      'Given by HR. Leave blank if you were not given one.',
                ),
              ),
              gap,
              TextFormField(
                controller: _employeeNo,
                decoration: const InputDecoration(labelText: 'Employee no.'),
                validator: _required,
              ),
              gap,
              TextFormField(
                controller: _firstName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'First name'),
                validator: _required,
              ),
              gap,
              TextFormField(
                controller: _lastName,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Last name'),
                validator: _required,
              ),
              gap,
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: (v) => (v == null || !v.contains('@'))
                    ? 'Enter a valid email'
                    : null,
              ),
              gap,
              TextFormField(
                controller: _password,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  helperText: 'At least 10 characters, including uppercase, lowercase, and a number.',
                ),
                validator: (v) {
                  final value = v ?? '';
                  return value.length < 10 ||
                          !RegExp(r'[A-Z]').hasMatch(value) ||
                          !RegExp(r'[a-z]').hasMatch(value) ||
                          !RegExp(r'[0-9]').hasMatch(value)
                      ? 'Use at least 10 characters with uppercase, lowercase, and a number'
                      : null;
                },
              ),
              gap,
              TextFormField(
                controller: _confirm,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm password',
                ),
                validator: (v) =>
                    v != _password.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 28),
              Text(
                'Verify you work here',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'HR checks these photos before approving your account. Use good light and make sure the text on your ID is readable.',
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              gap,
              _PhotoField(
                label: '1. Photo of your company ID',
                bytes: _idPhoto,
                onCamera: () async {
                  final b = await _pick(ImageSource.camera, front: false);
                  if (b != null && mounted) setState(() => _idPhoto = b);
                },
                onGallery: () async {
                  final b = await _pick(ImageSource.gallery, front: false);
                  if (b != null && mounted) setState(() => _idPhoto = b);
                },
              ),
              gap,
              _PhotoField(
                label: '2. Selfie holding your ID next to your face',
                bytes: _selfie,
                onCamera: () async {
                  final b = await _pick(ImageSource.camera, front: true);
                  if (b != null && mounted) setState(() => _selfie = b);
                },
              ),
              gap,
              Text(
                'By submitting, you agree that HR may use these photos to confirm that you work here.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
              ],
              const SizedBox(height: 20),
              FilledButton(
                onPressed: _loading ? null : _submit,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _loading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Submit for approval'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoField extends StatelessWidget {
  const _PhotoField({
    required this.label,
    required this.bytes,
    required this.onCamera,
    this.onGallery,
  });
  final String label;
  final Uint8List? bytes;
  final VoidCallback onCamera;
  final VoidCallback? onGallery;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        Container(
          height: 170,
          width: double.infinity,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          clipBehavior: Clip.antiAlias,
          child: bytes == null
              ? Icon(
                  Icons.add_a_photo_outlined,
                  size: 40,
                  color: theme.colorScheme.outline,
                )
              : Image.memory(bytes!, fit: BoxFit.contain),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(bytes == null ? 'Take photo' : 'Retake'),
                onPressed: onCamera,
              ),
            ),
            if (onGallery != null) ...[
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose'),
                  onPressed: onGallery,
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
