import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../config/app_theme.dart';
import '../models/account_deletion.dart';
import '../services/api_service.dart';

class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({super.key});

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _apiService = ApiService();
  final _reasonController = TextEditingController();

  bool _loading = true;
  bool _submitting = false;
  AccountDeletionMyRequestStatusResponse? _status;

  @override
  void initState() {
    super.initState();
    _loadStatus();
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _loadStatus() async {
    setState(() => _loading = true);

    try {
      final status = await _apiService.getMyAccountDeletionRequestStatus();
      if (!mounted) {
        return;
      }

      setState(() {
        _status = status;
        _loading = false;
      });
    } on UnauthorizedApiException {
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop();
    } on ApiException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showSnack(error.message, isError: true);
    } on TimeoutException {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showSnack('Connection timed out. Please try again.', isError: true);
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
      _showSnack('Unable to load status right now.', isError: true);
    }
  }

  Future<void> _confirmAndSubmit() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Submit deletion request?'),
          content: const Text(
            'This starts account deletion processing. Once approved by admin, your access will be revoked.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Submit Request'),
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
      final response = await _apiService.requestAuthenticatedAccountDeletion(
        reason: _reasonController.text,
      );

      if (!mounted) {
        return;
      }

      await _loadStatus();
      _showSnack(response.message);
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

  String _formatUtc(DateTime value) {
    return DateFormat.yMMMd().add_jm().format(value.toLocal());
  }

  String _timelineText() {
    return 'Requests are reviewed by admin and completed within 30 days after approval.';
  }

  bool get _hasActiveRequest {
    final status = _status?.status;
    return status == 'PendingVerification' ||
        status == 'PendingAdminReview' ||
        status == 'Approved';
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Delete Account')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStatus,
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
                        'Account Deletion',
                        style: textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        'Use this page to submit an account deletion request from inside the app.',
                        style: textTheme.bodyMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(_timelineText(), style: textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              if (_loading)
                const Center(child: CircularProgressIndicator())
              else
                _buildStatusCard(textTheme),
              const SizedBox(height: AppSpacing.md),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Submit Request',
                        style: textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      TextField(
                        controller: _reasonController,
                        enabled: !_hasActiveRequest && !_submitting,
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
                          onPressed: _hasActiveRequest || _submitting
                              ? null
                              : _confirmAndSubmit,
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
                            _hasActiveRequest
                                ? 'Request Already Active'
                                : (_submitting
                                      ? 'Submitting...'
                                      : 'Submit Deletion Request'),
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
      ),
    );
  }

  Widget _buildStatusCard(TextTheme textTheme) {
    final status = _status;
    if (status == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Text(
            'No deletion request found for your account.',
            style: textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Current Status: ${status.status}',
              style: textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Request ID: ${status.requestId}',
              style: textTheme.bodyMedium,
            ),
            Text('Source: ${status.source}', style: textTheme.bodyMedium),
            Text(
              'Requested: ${_formatUtc(status.requestedAtUtc)}',
              style: textTheme.bodyMedium,
            ),
            if (status.reviewedAtUtc != null)
              Text(
                'Reviewed: ${_formatUtc(status.reviewedAtUtc!)}',
                style: textTheme.bodyMedium,
              ),
            if (status.completedAtUtc != null)
              Text(
                'Completed: ${_formatUtc(status.completedAtUtc!)}',
                style: textTheme.bodyMedium,
              ),
            if (status.adminDecisionNote != null &&
                status.adminDecisionNote!.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xs),
                child: Text(
                  'Admin note: ${status.adminDecisionNote}',
                  style: textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
