import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../app.dart';
import '../core/formats.dart';
import '../core/scan_content.dart';
import '../services/history.dart';
import 'result_sheet.dart';

class HistoryPage extends StatelessWidget {
  const HistoryPage({super.key, required this.services});
  final AppServices services;

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Clear history?'),
        content: const Text('All saved scans will be removed from this phone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok == true) await services.history.clear();
  }

  @override
  Widget build(BuildContext context) {
    final history = services.history;
    return ListenableBuilder(
      listenable: history,
      builder: (context, _) {
        final entries = history.entries;
        return Scaffold(
          appBar: AppBar(
            title: const Text('History'),
            actions: [
              if (entries.isNotEmpty)
                IconButton(
                  tooltip: 'Clear history',
                  icon: const Icon(Icons.delete_sweep_outlined),
                  onPressed: () => _confirmClear(context),
                ),
            ],
          ),
          body: entries.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Text(
                      services.settings.saveHistory
                          ? 'No scans yet.\nCodes you scan will appear here.'
                          : 'History is turned off in Settings.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, i) => _HistoryTile(entry: entries[i], services: services),
                ),
          bottomNavigationBar: SafeArea(
            child: AdBannerSlot(ads: services.ads, placement: AdPlacement.historyBanner),
          ),
        );
      },
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.entry, required this.services});
  final HistoryEntry entry;
  final AppServices services;

  @override
  Widget build(BuildContext context) {
    final content = ScanContent.parse(entry.raw, isProductFormat: entry.isProductFormat);
    final loc = MaterialLocalizations.of(context);
    final when = '${loc.formatShortDate(entry.time)}, ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(entry.time))}';
    return Dismissible(
      key: ObjectKey(entry),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        child: const Icon(Icons.delete_outline),
      ),
      onDismissed: (_) => services.history.remove(entry),
      child: ListTile(
        leading: Icon(kindIcon(content.kind)),
        title: Text(content.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${formatLabel(entry.format)} · $when', maxLines: 1, overflow: TextOverflow.ellipsis),
        onTap: () => showResultSheet(
          context,
          content: content,
          format: entry.format,
          actions: services.actions,
          fromImage: entry.fromImage,
        ),
      ),
    );
  }
}
