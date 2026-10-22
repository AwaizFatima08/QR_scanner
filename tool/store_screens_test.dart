// Renders the real app UI in its key states for the Play screenshots.
//
//   flutter test tool/store_screens_test.dart && flutter test tool/make_graphics_test.dart
//
// Writes store-assets/raw/*.png (1080 px wide); make_graphics_test.dart then
// frames and captions them into store-assets/screenshots/. The camera view is
// replaced by a drawn scene holding a real QR code (store-assets/src/).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanlink/ads/ads.dart';
import 'package:scanlink/app.dart';
import 'package:scanlink/services/history.dart';
import 'package:scanlink/services/settings.dart';
import 'package:scanlink/views/scanner_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

const logical = Size(411, 890);
ui.Image? qrImage;
const ratio = 1080 / 411;
final boundary = GlobalKey();

Future<void> loadFonts() async {
  const dir = '/mnt/storage/projects/flutter/bin/cache/artifacts/material_fonts';
  ByteData read(String f) => ByteData.sublistView(File('$dir/$f').readAsBytesSync());
  final roboto = FontLoader('Roboto');
  for (final w in ['Regular', 'Medium', 'Bold', 'Black', 'Light']) {
    roboto.addFont(Future.value(read('Roboto-$w.ttf')));
  }
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(Future.value(read('MaterialIcons-Regular.otf')))).load();
}

/// Stand-in for the camera: a printed QR code on a desk.
class FakeCameraScene extends StatelessWidget {
  const FakeCameraScene({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF5B5148), Color(0xFF2E2925), Color(0xFF1B1816)],
        ),
      ),
      child: Align(
        alignment: const Alignment(0, -0.1),
        child: Transform.rotate(
          angle: -0.05,
          child: Container(
            width: 230,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F4EE),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [BoxShadow(blurRadius: 24, color: Colors.black54, offset: Offset(0, 10))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                RawImage(image: qrImage, width: 202, height: 202, filterQuality: FilterQuality.none),
                const SizedBox(height: 8),
                const Text(
                  'Scan for our menu',
                  style: TextStyle(color: Color(0xFF3A3530), fontSize: 13, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<(AppServices, ScannerPageState)> pump(WidgetTester tester, {Map<String, Object> prefs = const {}}) async {
  tester.view.physicalSize = logical * ratio;
  tester.view.devicePixelRatio = ratio;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'vibrate': false, ...prefs});
  final sp = await SharedPreferences.getInstance();
  final settings = Settings(sp);
  qrImage ??= await tester.runAsync(() async {
    final codec = await ui.instantiateImageCodec(File('store-assets/src/qr-homilabs.png').readAsBytesSync());
    return (await codec.getNextFrame()).image;
  });
  final services = AppServices(
    settings: settings,
    history: History(sp),
    ads: Ads(network: NoAdNetwork(), settings: settings),
  );
  await tester.pumpWidget(
    RepaintBoundary(
      key: boundary,
      child: ScanLinkApp(services: services, scanner: const FakeCameraScene()),
    ),
  );
  await tester.pumpAndSettle();
  return (services, tester.state<ScannerPageState>(find.byType(ScannerPage)));
}

Future<void> shoot(WidgetTester tester, String name) async {
  final ro = boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final img = await ro.toImage(pixelRatio: ratio);
    final png = await img.toByteData(format: ui.ImageByteFormat.png);
    File('store-assets/raw/$name.png')
      ..parent.createSync(recursive: true)
      ..writeAsBytesSync(png!.buffer.asUint8List());
  });
}

Future<void> scan(WidgetTester tester, ScannerPageState page, String raw, String format) async {
  page.handleCamera((raw: raw, format: format));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadFonts);

  testWidgets('scan', (tester) async {
    await pump(tester);
    await shoot(tester, '01-scan');
  });

  testWidgets('link', (tester) async {
    final (_, page) = await pump(tester);
    await scan(tester, page, 'https://tools.homilabs.org/', 'qrCode');
    await shoot(tester, '02-link');
  });

  testWidgets('wifi', (tester) async {
    final (_, page) = await pump(tester);
    await scan(tester, page, 'WIFI:T:WPA;S:Cafe Guest;P:latte2026;;', 'qrCode');
    await shoot(tester, '03-wifi');
  });

  testWidgets('contact from picture', (tester) async {
    final (s, _) = await pump(tester);
    await s.history.add(
      HistoryEntry(
        raw:
            'BEGIN:VCARD\nVERSION:3.0\nN:Khan;Ayesha;;;\nFN:Ayesha Khan\nORG:Bright Bakery\n'
            'TEL:+92 300 1234567\nEMAIL:ayesha@example.com\nEND:VCARD',
        format: 'qrCode',
        time: DateTime(2026, 10, 22, 18, 5),
        fromImage: true,
      ),
    );
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ayesha Khan'));
    await tester.pumpAndSettle();
    await shoot(tester, '04-contact');
  });

  testWidgets('history', (tester) async {
    final (s, _) = await pump(tester);
    final entries = [
      ('https://www.example.com/menu', 'qrCode', false),
      ('5012345678900', 'ean13', false),
      ('WIFI:T:WPA;S:Cafe Guest;P:latte2026;;', 'qrCode', false),
      ('geo:24.8607,67.0011', 'qrCode', true),
      ('tel:+923001234567', 'qrCode', false),
      ('mailto:hello@example.com?subject=Hi', 'qrCode', true),
      ('https://tools.homilabs.org/', 'qrCode', false),
    ];
    var minute = 0;
    for (final (raw, format, img) in entries.reversed) {
      await s.history.add(
        HistoryEntry(raw: raw, format: format, time: DateTime(2026, 10, 22, 9, minute += 37), fromImage: img),
      );
    }
    await tester.tap(find.byTooltip('History'));
    await tester.pumpAndSettle();
    await shoot(tester, '05-history');
  });

  testWidgets('settings', (tester) async {
    await pump(tester, prefs: {'vibrate': true});
    await tester.tap(find.byTooltip('Settings and about'));
    await tester.pumpAndSettle();
    await shoot(tester, '06-settings');
  });
}
