# ScanLink: Google Play listing kit (v1.0.0)

Play Console app id `4973346106816963509` (Homilabs organization account), created 2026-10-23.

## App details
| Field | Value |
|---|---|
| App name (≤30) | `ScanLink: QR & Barcode Scanner` |
| Package | `com.homilabs.scanlink` (locked after first upload) |
| Default language | English (United States) – en-US |
| App or game / Free or paid | App / Free |
| Category | Tools |
| Contact email | `homilabs.smc@gmail.com` |
| Website | `https://tools.homilabs.org` (hosts app-ads.txt) |
| Privacy policy URL | `https://tools.homilabs.org/privacy#scanlink` |

## Short description (≤80)
```
Scan QR codes and barcodes with your camera or photos, then open them. No login.
```

## Full description (≤4000)
```
ScanLink reads QR codes and barcodes in a second and opens them for you. Point your camera at a code, or pick a picture from your gallery. No account, no sign-in.

SCAN ANYTHING
• QR codes, Data Matrix, Aztec and PDF417
• Product barcodes (EAN, UPC) and Code 128, Code 39 and more
• Scan with the camera, with the flashlight for dark places, or from any photo or screenshot in your gallery

OPEN IT IN ONE TAP
• Web links open in your browser
• Phone numbers, emails and text messages open in the right app
• Map locations open in Maps
• Wi-Fi codes show the network name and password, ready to copy
• Contact cards show name, phone, email and more
• Product barcodes are looked up on the web

SAFE BY DESIGN
• ScanLink shows you the address before opening it (or switch on "Open links automatically")
• Links that are not secure (http) are clearly marked
• Unusual link types are never opened, only shown

YOUR SCANS STAY YOURS
• No login and no account
• Scan history is saved on your phone only; delete single scans, clear it, or switch it off
• The camera picture is analysed on your phone and never saved

ScanLink is free with a few ads. Ads never cover the camera or a scan result, and one optional video turns all ads off for 24 hours.
```

## Graphics (in `store-assets/`, regenerate with `flutter test tool/store_screens_test.dart && flutter test tool/make_graphics_test.dart`)
| Asset | File |
|---|---|
| App icon 512×512 | `icon-512.png` |
| Feature graphic 1024×500 | `feature-graphic-1024x500.png` |
| Phone screenshots 1080×1920 | `screenshots/01-scan.png` … `06-settings.png` |

## App content answers (all saved 2026-10-23)
- Privacy policy: URL above. Sign-in details: no part of the app is restricted.
- Ads: Yes. Advertising ID: Yes — Analytics, Advertising or marketing, Fraud prevention.
- Target audience: 13–15, 16–17, 18+ (no under-13s → stays out of the Families policy).
- Content rating (IARC, All other app types): all No → Everyone / PEGI 3 / USK 0 / 3+.
- Government app: No. Financial features: none. Health features: none.
- Data safety: collects and shares (AdMob) — Approximate location, App interactions, Crash logs, Diagnostics,
  Device or other IDs; not ephemeral; required; purposes Analytics, Advertising or marketing, Fraud prevention.
  Encrypted in transit. No accounts. Camera images and scan history never leave the phone (not declared).

## Release
- AAB: `releases/v1.0.0-1/scanlink-1.0.0-1.aab` (signed with `.secrets/scanlink-upload.keystore`; accept Play App Signing).
- Release name `1.0.0 (1)`. Release notes:
```
<en-US>
First release: scan QR codes and barcodes with the camera or from your photos, and open links, calls, emails, maps, Wi-Fi details and contacts in one tap.
</en-US>
```
