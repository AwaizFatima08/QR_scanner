import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:scanlink/ads/ads.dart';
import 'package:scanlink/app.dart';
import 'package:scanlink/services/actions.dart';
import 'package:scanlink/services/history.dart';
import 'package:scanlink/services/settings.dart';
import 'package:scanlink/views/scanner_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FakeActions extends ContentActions {
  final opened = <Uri>[];
  final copied = <String>[];

  @override
  Future<bool> open(Uri uri) async {
    opened.add(uri);
    return true;
  }

  @override
  Future<void> copy(String text) async => copied.add(text);

  @override
  Future<void> share(String text) async {}
}

void main() {
  late SharedPreferences prefs;
  late FakeActions actions;
  late AppServices services;
  late PlaceholderAdNetwork network;
  late DateTime now;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    actions = FakeActions();
    network = PlaceholderAdNetwork();
    now = DateTime(2026, 10, 22, 12);
    final settings = Settings(prefs);
    services = AppServices(
      settings: settings,
      history: History(prefs),
      ads: Ads(network: network, settings: settings, clock: () => now),
      actions: actions,
    );
  });

  Future<ScannerPageState> pump(WidgetTester t) async {
    await t.pumpWidget(
      ScanLinkApp(
        services: services,
        scanner: const ColoredBox(color: Colors.black),
      ),
    );
    await t.pump();
    return t.state<ScannerPageState>(find.byType(ScannerPage));
  }

  Future<void> scan(WidgetTester t, ScannerPageState page, String raw, [String format = 'qrCode']) async {
    page.handleCamera((raw: raw, format: format));
    await t.pumpAndSettle();
  }

  Future<void> closeSheet(WidgetTester t) async {
    await t.tap(find.byKey(const Key('result-close')));
    await t.pumpAndSettle();
  }

  test('appVersion matches pubspec.yaml', () {
    final m = RegExp(r'^version:\s*([\d.]+)\+', multiLine: true).firstMatch(File('pubspec.yaml').readAsStringSync());
    expect(m?.group(1), appVersion);
  });

  testWidgets('a scanned link shows the result; Open launches it and keeps the sheet', (t) async {
    final page = await pump(t);
    await scan(t, page, 'https://example.com/menu');
    expect(find.text('example.com'), findsOneWidget);
    expect(actions.opened, isEmpty, reason: 'auto-open is off by default');

    await t.tap(find.byKey(const Key('result-open')));
    await t.pumpAndSettle();
    expect(actions.opened.single.toString(), 'https://example.com/menu');
    expect(find.byKey(const Key('result-open')), findsOneWidget);

    await t.tap(find.byKey(const Key('result-copy')));
    await t.pumpAndSettle();
    expect(actions.copied.single, 'https://example.com/menu');

    expect(services.history.entries.single.raw, 'https://example.com/menu');
  });

  testWidgets('auto-open launches links straight away and still shows the result', (t) async {
    services.settings.autoOpenLinks = true;
    final page = await pump(t);
    await scan(t, page, 'https://example.com');
    expect(actions.opened.single.host, 'example.com');
    expect(find.textContaining('Opened automatically'), findsOneWidget);
  });

  testWidgets('auto-open never launches non-links', (t) async {
    services.settings.autoOpenLinks = true;
    final page = await pump(t);
    await scan(t, page, 'tel:+123456');
    expect(actions.opened, isEmpty);
  });

  testWidgets('the same code still in view is ignored right after closing', (t) async {
    final page = await pump(t);
    await scan(t, page, 'hello');
    await closeSheet(t);
    await scan(t, page, 'hello');
    expect(find.byKey(const Key('result-title')), findsNothing);

    await scan(t, page, 'other');
    expect(find.text('other'), findsWidgets);
  });

  testWidgets('detections are ignored while a result is open', (t) async {
    final page = await pump(t);
    await scan(t, page, 'first');
    await scan(t, page, 'second');
    expect(find.byKey(const Key('result-title')), findsOneWidget);
    expect(find.text('second'), findsNothing);
  });

  testWidgets('history off: nothing is saved', (t) async {
    services.settings.saveHistory = false;
    final page = await pump(t);
    await scan(t, page, 'secret');
    expect(services.history.entries, isEmpty);
  });

  testWidgets('interstitial: never in the first minute, then at most one per 3 results', (t) async {
    final page = await pump(t);
    Future<void> scanAndClose(String raw) async {
      await scan(t, page, raw);
      await closeSheet(t);
    }

    for (var i = 0; i < 3; i++) {
      await scanAndClose('early $i');
    }
    expect(find.byKey(const Key('ad-interstitial')), findsNothing);
    expect(services.ads.log.last, 'result_closed:capped');

    now = now.add(const Duration(minutes: 2));
    await scanAndClose('a');
    expect(find.byKey(const Key('ad-interstitial')), findsOneWidget);
    await t.tap(find.text('Close'));
    await t.pumpAndSettle();

    now = now.add(const Duration(minutes: 10));
    await scanAndClose('b');
    await scanAndClose('c');
    expect(find.byKey(const Key('ad-interstitial')), findsNothing);
    expect(services.ads.log.last, 'result_closed:too-soon');
  });

  testWidgets('rewarded ad grants 24 h without ads only when watched to the end', (t) async {
    await pump(t);
    await t.tap(find.byTooltip('Settings and about'));
    await t.pumpAndSettle();

    await t.tap(find.byKey(const Key('ad-free-offer')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ad-rewarded-close')));
    await t.pumpAndSettle();
    expect(services.ads.isAdFree, isFalse);

    await t.tap(find.byKey(const Key('ad-free-offer')));
    await t.pumpAndSettle();
    await t.tap(find.byKey(const Key('ad-rewarded-finish')));
    await t.pumpAndSettle();
    expect(services.ads.isAdFree, isTrue);
    expect(services.ads.banner(AdPlacement.historyBanner), isNull);
  });

  testWidgets('history page shows a banner and reopens results', (t) async {
    final page = await pump(t);
    await scan(t, page, 'https://example.com');
    await closeSheet(t);

    await t.tap(find.byTooltip('History'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('ad-banner-history_banner')), findsOneWidget);
    await t.tap(find.text('example.com'));
    await t.pumpAndSettle();
    expect(find.byKey(const Key('result-open')), findsOneWidget);
  });
}
