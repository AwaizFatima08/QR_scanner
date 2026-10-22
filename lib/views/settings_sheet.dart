import 'package:flutter/material.dart';

import '../ads/ads.dart';
import '../app.dart';

const privacyUrl = 'https://tools.homilabs.org/privacy#scanlink';
const termsUrl = 'https://tools.homilabs.org/terms#scanlink';
const supportEmail = 'homilabs.smc@gmail.com';

Future<void> showSettingsSheet(BuildContext context, AppServices services) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => SettingsSheet(services: services),
);

class SettingsSheet extends StatelessWidget {
  const SettingsSheet({super.key, required this.services});
  final AppServices services;

  String _until(BuildContext context, DateTime t) {
    final loc = MaterialLocalizations.of(context);
    return '${loc.formatShortDate(t)}, ${loc.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
  }

  Future<void> _watchAd(BuildContext context) async {
    final outcome = await services.ads.watchForAdFree(context);
    if (!context.mounted) return;
    final msg = switch (outcome) {
      Rewarded() => 'Thanks! No ads for the next 24 hours.',
      Dismissed() => 'The ad was closed early, so ads stay on.',
      NoFill() => 'No ad is available right now. Please try later.',
    };
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    final s = services.settings;
    final ads = services.ads;
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: Listenable.merge([s, ads]),
      builder: (context, _) => ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Settings', style: theme.textTheme.titleLarge),
          ),
          SwitchListTile(
            key: const Key('setting-auto-open'),
            title: const Text('Open links automatically'),
            subtitle: const Text('Web links open in your browser as soon as they are scanned.'),
            value: s.autoOpenLinks,
            onChanged: (v) => s.autoOpenLinks = v,
          ),
          SwitchListTile(title: const Text('Vibrate on scan'), value: s.vibrate, onChanged: (v) => s.vibrate = v),
          SwitchListTile(
            title: const Text('Keep scan history'),
            subtitle: const Text('Saved on this phone only.'),
            value: s.saveHistory,
            onChanged: (v) => s.saveHistory = v,
          ),
          if (ads.isAdFree)
            ListTile(
              leading: const Icon(Icons.verified_outlined),
              title: const Text('No ads'),
              subtitle: Text('Until ${_until(context, ads.adFreeUntil!)}'),
            )
          else if (ads.canOfferAdFree)
            ListTile(
              key: const Key('ad-free-offer'),
              leading: const Icon(Icons.ondemand_video_outlined),
              title: const Text('No ads for 24 hours'),
              subtitle: const Text('Watch one short video ad.'),
              onTap: () => _watchAd(context),
            ),
          if (ads.privacyOptionsRequired)
            ListTile(
              leading: const Icon(Icons.privacy_tip_outlined),
              title: const Text('Ad privacy choices'),
              onTap: ads.showPrivacyOptions,
            ),
          const Divider(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$appName $appVersion', style: theme.textTheme.titleMedium),
                const SizedBox(height: 4),
                Text(
                  'Scan QR codes and barcodes with the camera or from a picture, then open the link. '
                  'No login and no account. Your scans and history stay on this phone. '
                  '${ads.enabled ? 'ScanLink is free and shows ads from Google AdMob. ' : ''}'
                  'Made by HomiLabs.',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ListTile(
            leading: const Icon(Icons.policy_outlined),
            title: const Text('Privacy policy'),
            onTap: () => services.actions.open(Uri.parse(privacyUrl)),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Terms of use'),
            onTap: () => services.actions.open(Uri.parse(termsUrl)),
          ),
          ListTile(
            leading: const Icon(Icons.mail_outline),
            title: const Text('Contact'),
            subtitle: const Text(supportEmail),
            onTap: () => services.actions.open(
              Uri(
                scheme: 'mailto',
                path: supportEmail,
                query: 'subject=${Uri.encodeComponent('$appName $appVersion')}',
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.article_outlined),
            title: const Text('Open-source licences'),
            onTap: () => showLicensePage(context: context, applicationName: appName, applicationVersion: appVersion),
          ),
        ],
      ),
    );
  }
}
