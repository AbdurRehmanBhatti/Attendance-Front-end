import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_theme.dart';
import '../services/api_service.dart';

class MyAccountScreen extends StatelessWidget {
  const MyAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = ApiService.currentUser;
    final textTheme = Theme.of(context).textTheme;

    if (user == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('My Account')),
        body: const Center(child: Text('Account details are unavailable right now.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Account')),
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
                      user.name,
                      style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(user.email, style: textTheme.bodyMedium),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Use these details when needed for account deletion support or verification.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _InfoTile(
              label: 'Employee ID',
              value: user.id.toString(),
              onCopy: () => _copyToClipboard(context, 'Employee ID', user.id.toString()),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoTile(
              label: 'Company ID',
              value: user.companyId?.toString() ?? 'Not assigned',
              onCopy: user.companyId == null
                  ? null
                  : () => _copyToClipboard(context, 'Company ID', user.companyId.toString()),
            ),
            const SizedBox(height: AppSpacing.sm),
            _InfoTile(
              label: 'Company',
              value: user.companyName,
              onCopy: () => _copyToClipboard(context, 'Company', user.companyName),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyToClipboard(BuildContext context, String label, String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!context.mounted) {
      return;
    }

    final colors = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label copied.'),
        backgroundColor: colors.secondaryContainer,
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onCopy;

  const _InfoTile({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: textTheme.labelLarge),
                  const SizedBox(height: AppSpacing.xs),
                  Text(value, style: textTheme.bodyLarge),
                ],
              ),
            ),
            IconButton(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_all_rounded),
              tooltip: onCopy == null ? 'Not available' : 'Copy $label',
            ),
          ],
        ),
      ),
    );
  }
}
