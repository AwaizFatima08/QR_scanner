# Ads in ScanLink (AdMob)

ScanLink is free and supported by Google AdMob (HomiLabs account, publisher `pub-2087846699268567`).
The ad layer is the one from Beam (`/mnt/storage/projects/Torch/docs/ads.md`), adapted.

## AdMob ids (created 2026-10-22)
| What | Id | AdMob name |
|---|---|---|
| App | `ca-app-pub-2087846699268567~9562396258` | ScanLink: QR & Barcode Scanner |
| Banner | `ca-app-pub-2087846699268567/3314798088` | ScanLink home_banner (used for `history_banner`) |
| Interstitial | `ca-app-pub-2087846699268567/2670306969` | ScanLink result_closed interstitial |
| Rewarded | `ca-app-pub-2087846699268567/1683906239` | ScanLink ad_free_reward |

## Placements
| Placement id (stable) | Format | When it can appear |
|---|---|---|
| `history_banner` | Banner 320×50 | Bottom of the History screen only. Never over the camera, never in a result sheet. |
| `result_closed` | Interstitial | After the user closes a scan result. Never before a link opens (Open keeps the sheet). |
| `ad_free_reward` | Rewarded (opt-in) | "No ads for 24 hours" in Settings, shown only while a rewarded ad is loaded. |

Rules, all in `Ads` (`lib/ads/ads.dart`): no interstitial in the first 60 s after launch, then at most one per
3 minutes **and** per 3 closed results; none while the 24 h ad-free pass is active. Rewarded grants 24 h only when
watched to the end. Consent: Google UMP form before the SDK starts (EEA/UK only); Settings shows "Ad privacy
choices" when required.

Debug/profile builds always use Google's sample ids (`AdUnitIds.current`, sample app id in `build.gradle.kts`).

## Before every release
1. `bash scripts/check-release-ad-ids.sh` → PASS.
2. AdMob: after the Play listing exists, link it in AdMob (Apps → ScanLink → Add store) to lift limited serving.
   app-ads.txt already lives at https://tools.homilabs.org/app-ads.txt — use that site as the Play website.
   GDPR + US-states consent message must cover ScanLink in *Privacy & messaging*.
3. Privacy policy: add the ScanLink section (camera used on-device only, no scans leave the phone, AdMob data) to
   tools.homilabs.org and upload it.
4. Play Console: Ads = Yes; Data safety and Advertising ID as for Beam.
5. Test with sample ids on a device — never tap real ads on your own device.
