import 'package:flutter/material.dart';

import 'ads/ads.dart';
import 'services/actions.dart';
import 'services/history.dart';
import 'services/settings.dart';
import 'views/scanner_page.dart';

/// Shown on the About sheet. Keep in step with `version:` in pubspec.yaml
/// (test/app_test.dart checks this).
const appVersion = '1.0.0';
const appName = 'ScanLink';

const brand = Color(0xFF00B894);

/// The app's long-lived objects, created once in main() (or by a test).
class AppServices {
  AppServices({
    required this.settings,
    required this.history,
    required this.ads,
    this.actions = const ContentActions(),
  });

  final Settings settings;
  final Ads ads;
  final History history;
  final ContentActions actions;
}

class ScanLinkApp extends StatelessWidget {
  const ScanLinkApp({super.key, required this.services, this.scanner});
  final AppServices services;

  /// Replaces the camera view in widget tests.
  final Widget? scanner;

  ThemeData _theme(Brightness b) => ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: brand, brightness: b),
    useMaterial3: true,
    bottomSheetTheme: const BottomSheetThemeData(showDragHandle: true),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      home: ScannerPage(services: services, cameraOverride: scanner),
    );
  }
}
