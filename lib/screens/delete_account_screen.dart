import 'dart:async';

import 'package:flutter/material.dart';

import '../config/app_theme.dart';
import '../config/page_transitions.dart';
import '../screens/login_screen.dart';
import '../services/api_service.dart';
import '../services/auth_session_storage.dart';

class DeleteAccountScreen extends StatefulWidget {
  final ApiService? apiService;
  final Future<void> Function()? clearSession;
  final void Function(BuildContext context)? navigateToLogin;

  const DeleteAccountScreen({
    super.key,
    this.apiService,
    this.clearSession,
    this.navigateToLogin,
  });

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  late final ApiService _apiService;
  final _reasonController = TextEditingController();

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _confirmAndDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Delete your account?'),
          content: const Text(
            'This will permanently deactivate your account and immediately sign you out from this device. This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Delete Account'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) {
      return;
    }

    setState(() => _submitting = true);

    try {
      final response = await _apiService.deleteMyAccount(
        reason: _reasonController.text,
      );

      if (!mounted) {
        return;
      }

      _showSnack(response.message);
      await _goToLogin();
    } on UnauthorizedApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message, isError: true);
      await _goToLogin();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      _showSnack(error.message, isError: true);
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      _showSnack('Connection timed out. Please try again.', isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _showSnack('Unable to submit request right now.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _goToLogin() async {
    if (widget.clearSession != null) {
      await widget.clearSession!();
    } else {
      ApiService.clearSession();
      await AuthSessionStorage.clear();
    }

    if (!mounted) {
      return;
    }

    if (widget.navigateToLogin != null) {
      widget.navigateToLogin!(context);
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      SlideFadeRoute(page: const LoginScreen(), direction: SlideDirection.down),
      (route) => false,
    );
  }

  void _showSnack(String message, {bool isError = false}) {
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

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Delete Account',
                      style: textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Deleting your account will soft-delete your profile and revoke all active sessions immediately.',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      'You will be signed out right away and must not be able to navigate back to authenticated screens.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Optional Reason',
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    TextField(
                      controller: _reasonController,
                      enabled: !_submitting,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Reason (optional)',
                        hintText: 'Tell us why you want your account deleted',
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting ? null : _confirmAndDelete,
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.delete_forever_rounded),
                        label: Text(
                          _submitting ? 'Deleting...' : 'Delete Account Now',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
