import 'package:flutter/material.dart';

import '../core/formats.dart';
import '../core/scan_content.dart';
import '../services/actions.dart';

IconData kindIcon(ContentKind kind) => switch (kind) {
  ContentKind.url => Icons.link,
  ContentKind.email => Icons.email_outlined,
  ContentKind.phone => Icons.call_outlined,
  ContentKind.sms => Icons.sms_outlined,
  ContentKind.geo => Icons.place_outlined,
  ContentKind.wifi => Icons.wifi,
  ContentKind.contact => Icons.contact_page_outlined,
  ContentKind.product => Icons.shopping_bag_outlined,
  ContentKind.text => Icons.notes,
};

String kindLabel(ContentKind kind) => switch (kind) {
  ContentKind.url => 'Web link',
  ContentKind.email => 'Email',
  ContentKind.phone => 'Phone number',
  ContentKind.sms => 'Text message',
  ContentKind.geo => 'Location',
  ContentKind.wifi => 'Wi-Fi',
  ContentKind.contact => 'Contact',
  ContentKind.product => 'Product',
  ContentKind.text => 'Text',
};

/// Shows what a code contains, with Open / Copy / Share. Tapping Open keeps
/// the sheet in place, so coming back from the browser lands here.
Future<void> showResultSheet(
  BuildContext context, {
  required ScanContent content,
  required String format,
  required ContentActions actions,
  bool fromImage = false,
  bool autoOpened = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) =>
      ResultSheet(content: content, format: format, actions: actions, fromImage: fromImage, autoOpened: autoOpened),
);

class ResultSheet extends StatelessWidget {
  const ResultSheet({
    super.key,
    required this.content,
    required this.format,
    required this.actions,
    this.fromImage = false,
    this.autoOpened = false,
  });

  final ScanContent content;
  final String format;
  final ContentActions actions;
  final bool fromImage;
  final bool autoOpened;

  void _toast(BuildContext context, String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(msg), duration: const Duration(seconds: 2)));
  }

  Future<void> _open(BuildContext context) async {
    final ok = await actions.open(content.action!);
    if (!ok && context.mounted) _toast(context, 'No app on this phone can open that.');
  }

  Future<void> _copy(BuildContext context, String text, String what) async {
    await actions.copy(text);
    if (context.mounted) _toast(context, '$what copied');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = theme.colorScheme;
    final action = content.action;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.85),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: c.primaryContainer,
                  child: Icon(kindIcon(content.kind), color: c.onPrimaryContainer),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${kindLabel(content.kind)} · ${formatLabel(format)}${fromImage ? ' · from picture' : ''}',
                        style: theme.textTheme.labelMedium?.copyWith(color: c.onSurfaceVariant),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        content.title,
                        key: const Key('result-title'),
                        style: theme.textTheme.titleLarge,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (content.subtitle case final sub? when sub != content.title) ...[
              const SizedBox(height: 12),
              SelectableText(sub, style: theme.textTheme.bodyMedium?.copyWith(color: c.onSurfaceVariant)),
            ],
            if (content.insecure) ...[
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.lock_open,
                color: c.errorContainer,
                onColor: c.onErrorContainer,
                text: 'Not secure (http). Don\'t enter passwords or card details on this page.',
              ),
            ],
            if (autoOpened) ...[
              const SizedBox(height: 12),
              _Notice(
                icon: Icons.open_in_new,
                color: c.secondaryContainer,
                onColor: c.onSecondaryContainer,
                text: 'Opened automatically (you can turn this off in Settings).',
              ),
            ],
            if (content.fields.isNotEmpty) ...[
              const SizedBox(height: 12),
              Card.outlined(
                margin: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final e in content.fields.entries)
                      ListTile(
                        dense: true,
                        title: Text(e.key, style: theme.textTheme.labelMedium),
                        subtitle: SelectableText(e.value, style: theme.textTheme.bodyLarge),
                        trailing: IconButton(
                          tooltip: 'Copy ${e.key.toLowerCase()}',
                          icon: const Icon(Icons.copy, size: 20),
                          onPressed: () => _copy(context, e.value, e.key),
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (content.kind == ContentKind.text || content.kind == ContentKind.product) ...[
              const SizedBox(height: 12),
              SelectableText(content.raw, style: theme.textTheme.bodyLarge),
            ],
            const SizedBox(height: 20),
            if (action != null)
              FilledButton.icon(
                key: const Key('result-open'),
                onPressed: () => _open(context),
                icon: Icon(content.isLink ? Icons.open_in_new : kindIcon(content.kind)),
                label: Text(content.actionLabel ?? 'Open'),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    key: const Key('result-copy'),
                    onPressed: () => _copy(context, content.raw, content.isLink ? 'Link' : 'Text'),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => actions.share(content.raw),
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('result-close'),
              onPressed: () => Navigator.pop(context),
              child: const Text('Scan again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.color, required this.onColor, required this.text});
  final IconData icon;
  final Color color;
  final Color onColor;
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
    child: Row(
      children: [
        Icon(icon, size: 20, color: onColor),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: TextStyle(color: onColor)),
        ),
      ],
    ),
  );
}
