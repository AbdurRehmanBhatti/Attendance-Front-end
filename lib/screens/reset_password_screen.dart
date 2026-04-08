import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';
import '../services/crashlytics_service.dart';

class ResetPasswordScreen extends StatefulWidget {
  final int? userId;
  final String? token;

  const ResetPasswordScreen({
    super.key,
    required this.userId,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _apiService = ApiService();

  bool _isSubmitting = false;
  bool _hideNewPassword = true;
  bool _hideConfirmPassword = true;

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool get _hasValidLinkData {
    return widget.userId != null &&
        widget.userId! > 0 &&
        widget.token != null &&
        widget.token!.trim().isNotEmpty;
  }

  Future<void> _submit() async {
    if (!_hasValidLinkData || !_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await _apiService.resetPassword(
        userId: widget.userId!,
        token: widget.token!,
        newPassword: _newPasswordController.text,
      );

      if (!mounted) {
        return;
      }

      await AuthSessionStorage.clear();
      ApiService.clearSession();

      if (!mounted) {
        return;
      }

      _showSnackBar('Password reset successful. Please sign in.');
      Navigator.of(context).pushAndRemoveUntil(
        SlideFadeRoute(
          page: const LoginScreen(),
          direction: SlideDirection.down,
        ),
        (route) => false,
      );
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
    } catch (error, stackTrace) {
      unawaited(
        CrashlyticsService.recordHandledError(
          error,
          stackTrace,
          reason:
              'ResetPasswordScreen._submit: unexpected reset-password failure',
          information: {'screen': 'ResetPasswordScreen'},
        ),
      );
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

  void _showSnackBar(String message, {bool isError = false}) {
    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? colors.errorContainer
            : colors.secondaryContainer,
      ),
    );
  }

  String? _validateNewPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'New password is required';
    }

    if (value.trim().length < 8) {
      return 'New password must be at least 8 characters';
    }

    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Confirm password is required';
    }

    if (value.trim() != _newPasswordController.text.trim()) {
      return 'Passwords do not match';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: !_hasValidLinkData
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Invalid reset link',
                              style: textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.sm),
                            Text(
                              'This link is missing required reset parameters. Request a new password reset link and try again.',
                              style: textTheme.bodyMedium?.copyWith(
                                color: colors.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            FilledButton.icon(
                              onPressed: () {
                                Navigator.of(context).pushAndRemoveUntil(
                                  SlideFadeRoute(
                                    page: const LoginScreen(),
                                    direction: SlideDirection.down,
                                  ),
                                  (route) => false,
                                );
                              },
                              icon: const Icon(Icons.arrow_back_rounded),
                              label: const Text('Back to Sign In'),
                            ),
                          ],
                        )
                      : Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Create a new password',
                                style: textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                'Enter your new password to finish resetting your account.',
                                style: textTheme.bodyMedium?.copyWith(
                                  color: colors.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              TextFormField(
                                controller: _newPasswordController,
                                obscureText: _hideNewPassword,
                                textInputAction: TextInputAction.next,
                                decoration: InputDecoration(
                                  labelText: 'New password',
                                  prefixIcon: const Icon(
                                    Icons.password_rounded,
                                  ),
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
                                onFieldSubmitted: (_) =>
                                    _isSubmitting ? null : _submit(),
                                decoration: InputDecoration(
                                  labelText: 'Confirm new password',
                                  prefixIcon: const Icon(
                                    Icons.verified_user_rounded,
                                  ),
                                  suffixIcon: IconButton(
                                    onPressed: () {
                                      setState(() {
                                        _hideConfirmPassword =
                                            !_hideConfirmPassword;
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
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        )
                                      : const Icon(
                                          Icons.check_circle_outline_rounded,
                                        ),
                                  label: Text(
                                    _isSubmitting
                                        ? 'Resetting password...'
                                        : 'Reset Password',
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
