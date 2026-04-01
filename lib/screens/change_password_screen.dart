import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';

class ChangePasswordScreen extends StatefulWidget {
  final bool isMandatory;

  const ChangePasswordScreen({
    super.key,
    this.isMandatory = false,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();

  bool _isSubmitting = false;
  bool _hideCurrentPassword = true;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (ApiService.currentUser == null) {
      await _goToLogin();
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _apiService.changePassword(
        currentPassword: _currentPasswordController.text,
        newPassword: _newPasswordController.text,
      );

      await AuthSessionStorage.clear();
      ApiService.clearSession();

      if (!mounted) {
        return;
      }

      _showSnackBar('Password changed. Please sign in again.');
      await _goToLogin();
    } on UnauthorizedApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.message, isError: true);
      await _goToLogin();
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }
      _showSnackBar(e.message, isError: true);
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      _showSnackBar('Connection timed out. Please try again.', isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnackBar('Network error. Check your connection.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Future<void> _goToLogin() async {
    ApiService.clearSession();
    await AuthSessionStorage.clear();
    if (!mounted) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      SlideFadeRoute(page: const LoginScreen(), direction: SlideDirection.down),
      (route) => false,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? colors.errorContainer : colors.secondaryContainer,
      ),
    );
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateNewPassword(String? value) {
    final requiredError = _required(value, 'New password');
    if (requiredError != null) {
      return requiredError;
    }

    final password = value!.trim();
    if (password.length < 8) {
      return 'New password must be at least 8 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    final requiredError = _required(value, 'Confirm password');
    if (requiredError != null) {
      return requiredError;
    }

    if (value!.trim() != _newPasswordController.text.trim()) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.isMandatory,
        title: const Text('Change Password'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          widget.isMandatory
                              ? 'Password update required'
                              : 'Update your password',
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        Text(
                          widget.isMandatory
                              ? 'You must change your password before using attendance features.'
                              : 'Use your current password to set a new one.',
                          style: textTheme.bodyMedium?.copyWith(
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        TextFormField(
                          controller: _currentPasswordController,
                          obscureText: _hideCurrentPassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Current password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideCurrentPassword = !_hideCurrentPassword;
                                });
                              },
                              icon: Icon(
                                _hideCurrentPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                          validator: (value) => _required(value, 'Current password'),
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _newPasswordController,
                          obscureText: _hideNewPassword,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'New password',
                            prefixIcon: const Icon(Icons.password_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideNewPassword = !_hideNewPassword;
                                });
                              },
                              icon: Icon(
                                _hideNewPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                          validator: _validateNewPassword,
                        ),
                        const SizedBox(height: AppSpacing.md),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _hideConfirmPassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _isSubmitting ? null : _submit(),
                          decoration: InputDecoration(
                            labelText: 'Confirm new password',
                            prefixIcon: const Icon(Icons.verified_user_rounded),
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _hideConfirmPassword = !_hideConfirmPassword;
                                });
                              },
                              icon: Icon(
                                _hideConfirmPassword
                                    ? Icons.visibility_off_rounded
                                    : Icons.visibility_rounded,
                              ),
                            ),
                          ),
                          validator: _validateConfirmPassword,
                        ),
                        const SizedBox(height: AppSpacing.lg),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: _isSubmitting ? null : _submit,
                            icon: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2),
                                  )
                                : const Icon(Icons.check_circle_outline_rounded),
                            label: Text(
                              _isSubmitting ? 'Updating password...' : 'Change Password',
                            ),
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
