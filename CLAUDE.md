# ScanLink: QR & Barcode Scanner

Flutter, **Android only**. Package `com.homilabs.scanlink` — never change it after the first Play upload. Developer: HomiLabs.
Purpose: scan QR codes and barcodes with the camera or from a gallery picture, then open the link (or call, email,
text, map, Wi-Fi details, contact, product search). No login, no accounts, no server.

## Locked decisions
- Scanning: `mobile_scanner` (bundled ML Kit, works offline). Gallery: `image_picker` → Android photo picker, so no
  storage permission. Only permission requested by the app itself: CAMERA (`uses-feature camera required=false`).
- Every decoded text goes through `ScanContent.parse` (`lib/core/scan_content.dart`, pure Dart, tested). Only
  http(s) links and bare domains are opened as web links; other schemes (`intent:`, `javascript:`, `file:` …) are
  shown as text and only offered as a web search. `http://` links carry a "not secure" warning.
- Links are **not** opened automatically by default (Settings → "Open links automatically", off). Open keeps the
  result sheet in place so returning from the browser lands on it.
- The same code still in view is ignored for 1.5 s after a sheet closes; the camera is ignored while any sheet,
  the gallery or History is open.
- History: on the phone only (shared_preferences, max 200, duplicates move to top), can be switched off.
- Ads (AdMob, HomiLabs account): see `docs/ads.md`. Policy lives only in `lib/ads/ads.dart`; only
  `lib/ads/admob_network.dart` imports the SDK. No banner over the camera or in the result sheet.
- Contact email in the app: homilabs.smc@gmail.com. Privacy/terms links: https://tools.homilabs.org/privacy#scanlink
  and /terms#scanlink (**sections still to be written** in `/mnt/storage/projects/homilabs_tools/site/` and uploaded
  to Hostinger before release).

## Status (2026-10-22)
v1.0.0 (1) built; not yet on Play. AdMob app `ca-app-pub-2087846699268567~9562396258` registered 2026-10-22
("Requires review / limited serving" until the Play listing is linked in AdMob).

## Commands
- Tests: `flutter test` (scan parsing, history, widget flow incl. ad caps).
- Icons: `flutter test tool/make_graphics_test.dart` (launcher icons + `store-assets/icon-512.png`, drawn in code).
- Release: `bash scripts/check-release-ad-ids.sh` (must PASS), then `flutter build appbundle --release`
  (signs via `android/key.properties` → `.secrets/scanlink-upload.keystore`).
- Build switch for ads: `--dart-define=SCANLINK_ADS=admob|placeholder|off`.
- Backup: `bash scripts/backup.sh` (commit first; the GitHub layer refuses untracked/uncommitted files).

## Locations
- Local backup: `/mnt/storage/projects/QR_code_scanner_backup/`
- Google Drive: folder `1kKFmcekN5W4LtVn6FjRRHSBzjAY7YCTO` (rclone remote `gdrive`)
- GitHub (**public**): https://github.com/AwaizFatima08/QR_scanner. `.secrets/`, `android/key.properties` and
  `releases/` are gitignored.

## Machine notes
- Follow `~/.claude/heavy-jobs.md` (one heavy job at a time, RAM check, prefer a real phone).
- Test devices seen 2026-10-22 (wireless adb): OPPO CPH2743 phone, Samsung SM-X510 tablet.
