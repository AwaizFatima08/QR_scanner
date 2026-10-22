import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ads/admob_network.dart';
import 'ads/ads.dart';
import 'app.dart';
import 'services/history.dart';
import 'services/settings.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final settings = Settings(prefs);
  final ads = Ads(network: _adNetwork(), settings: settings);
  runApp(
    ScanLinkApp(
      services: AppServices(settings: settings, history: History(prefs), ads: ads),
    ),
  );
  // Consent (EEA/UK only) and SDK start-up run after the first frame, so the
  // camera opens without waiting for the network.
  unawaited(ads.init());
}

/// `--dart-define=SCANLINK_ADS=admob|placeholder|off` (default: admob). Debug
/// and profile builds use Google's sample units; see lib/ads/ad_ids.dart.
AdNetwork _adNetwork() => switch (const String.fromEnvironment('SCANLINK_ADS')) {
  'off' => NoAdNetwork(),
  'placeholder' => PlaceholderAdNetwork(),
  _ => AdMobNetwork(),
};
