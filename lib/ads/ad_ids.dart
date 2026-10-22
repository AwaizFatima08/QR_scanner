import 'package:flutter/foundation.dart';

/// AdMob unit ids. These are configuration, not secrets (they are visible in
/// any decompiled app), so they live here as constants.
///
/// Release builds use ScanLink's own units from the HomiLabs AdMob account.
/// `scripts/check-release-ad-ids.sh` fails a release while any of them is
/// still Google's sample id. The AdMob *app* id lives in
/// android/app/build.gradle.kts.
class AdUnitIds {
  const AdUnitIds({required this.banner, required this.interstitial, required this.rewarded});

  final String banner;
  final String interstitial;
  final String rewarded;

  /// Google's published Android sample units (always fill, never pay).
  static const sample = AdUnitIds(
    banner: 'ca-app-pub-3940256099942544/6300978111',
    interstitial: 'ca-app-pub-3940256099942544/1033173712',
    rewarded: 'ca-app-pub-3940256099942544/5224354917',
  );

  /// ScanLink's units in the HomiLabs AdMob account (app 9562396258),
  /// created 2026-10-22.
  static const release = AdUnitIds(
    banner: 'ca-app-pub-2087846699268567/3314798088', // "ScanLink home_banner" → history_banner
    interstitial: 'ca-app-pub-2087846699268567/2670306969', // "ScanLink result_closed interstitial"
    rewarded: 'ca-app-pub-2087846699268567/1683906239', // "ScanLink ad_free_reward" (24 h ad-free)
  );

  /// Debug and profile builds always use the sample units, so testing on a
  /// device can never produce invalid traffic on the real account.
  static AdUnitIds get current => kReleaseMode ? release : sample;
}
