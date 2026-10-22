import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../ads/ads.dart';
import '../app.dart';
import '../core/scan_content.dart';
import '../services/history.dart';
import 'history_page.dart';
import 'result_sheet.dart';
import 'settings_sheet.dart';
import 'widgets/scan_frame.dart';

/// A decoded code, independent of where it came from.
typedef Scanned = ({String raw, String format});

class ScannerPage extends StatefulWidget {
  const ScannerPage({super.key, required this.services, this.cameraOverride});
  final AppServices services;
  final Widget? cameraOverride;

  @override
  State<ScannerPage> createState() => ScannerPageState();
}

class ScannerPageState extends State<ScannerPage> {
  MobileScannerController? _controller;

  /// A result sheet, the gallery or the history is open: ignore the camera.
  bool _busy = false;

  /// After a sheet closes, the same code is usually still in view. Ignore it
  /// until the camera has looked away for a moment.
  String? _lastRaw;
  DateTime _lastSeen = DateTime.fromMillisecondsSinceEpoch(0);
  static const _sameCodePause = Duration(milliseconds: 1500);

  AppServices get _s => widget.services;

  @override
  void initState() {
    super.initState();
    if (widget.cameraOverride == null) {
      _controller = MobileScannerController(
        detectionSpeed: DetectionSpeed.normal,
        detectionTimeoutMs: 300,
        autoZoom: true,
      );
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    final codes = [
      for (final b in capture.barcodes)
        if (b.rawValue case final raw? when raw.isNotEmpty) (raw: raw, format: b.format.name),
    ];
    if (codes.isEmpty) return;
    handleCamera(codes.first);
  }

  /// Called for every camera detection (public for widget tests).
  void handleCamera(Scanned code) {
    final now = DateTime.now();
    final repeat = code.raw == _lastRaw && now.difference(_lastSeen) < _sameCodePause;
    _lastRaw = code.raw;
    _lastSeen = now;
    if (_busy || repeat) return;
    unawaited(_present(code, fromImage: false));
  }

  Future<void> _present(Scanned code, {required bool fromImage}) async {
    _busy = true;
    try {
      if (_s.settings.vibrate) unawaited(HapticFeedback.mediumImpact());
      final content = ScanContent.parse(code.raw, isProductFormat: HistoryEntry.productFormats.contains(code.format));
      if (_s.settings.saveHistory) {
        unawaited(
          _s.history.add(HistoryEntry(raw: code.raw, format: code.format, time: DateTime.now(), fromImage: fromImage)),
        );
      }
      final autoOpened = _s.settings.autoOpenLinks && content.isLink && await _s.actions.open(content.action!);
      if (!mounted) return;
      await showResultSheet(
        context,
        content: content,
        format: code.format,
        fromImage: fromImage,
        actions: _s.actions,
        autoOpened: autoOpened,
      );
      if (mounted) await _s.ads.maybeShowInterstitial(context, AdPlacement.resultClosed);
    } finally {
      _lastSeen = DateTime.now();
      _busy = false;
    }
  }

  Future<void> pickFromGallery() async {
    if (_busy) return;
    _busy = true;
    var handedOver = false;
    try {
      final file = await ImagePicker().pickImage(source: ImageSource.gallery, requestFullMetadata: false);
      if (file == null || !mounted) return;
      final controller = _controller ?? MobileScannerController(autoStart: false);
      BarcodeCapture? capture;
      try {
        capture = await controller.analyzeImage(file.path);
      } on MobileScannerException {
        capture = null;
      } finally {
        if (controller != _controller) unawaited(controller.dispose());
      }
      final codes = <Scanned>[];
      for (final b in capture?.barcodes ?? const <Barcode>[]) {
        final raw = b.rawValue;
        if (raw == null || raw.isEmpty || codes.any((c) => c.raw == raw)) continue;
        codes.add((raw: raw, format: b.format.name));
      }
      if (!mounted) return;
      if (codes.isEmpty) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(content: Text('No QR code or barcode found in that picture. Try a sharper, closer photo.')),
          );
        return;
      }
      final chosen = codes.length == 1 ? codes.first : await _chooseCode(codes);
      if (chosen == null) return;
      handedOver = true;
      _busy = false;
      await _present(chosen, fromImage: true);
    } on PlatformException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not open the gallery (${e.message ?? e.code}).')));
      }
    } finally {
      if (!handedOver) _busy = false;
    }
  }

  Future<Scanned?> _chooseCode(List<Scanned> codes) => showModalBottomSheet<Scanned>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('${codes.length} codes found', style: Theme.of(context).textTheme.titleMedium),
          ),
          for (final c in codes)
            ListTile(
              leading: Icon(kindIcon(ScanContent.parse(c.raw).kind)),
              title: Text(ScanContent.parse(c.raw).title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(c.raw, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    ),
  );

  Future<void> _openHistory() async {
    _busy = true;
    await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => HistoryPage(services: _s)));
    _lastSeen = DateTime.now();
    _busy = false;
  }

  Future<void> _openSettings() async {
    _busy = true;
    await showSettingsSheet(context, _s);
    _busy = false;
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            widget.cameraOverride ??
                MobileScanner(
                  controller: controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error) =>
                      _CameraError(error: error, onRetry: () => controller?.start(), onGallery: pickFromGallery),
                ),
            const IgnorePointer(child: ScanFrame()),
            SafeArea(
              child: Column(
                children: [
                  _TopBar(onHistory: _openHistory, onSettings: _openSettings),
                  const Spacer(),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      'Point the camera at a QR code or barcode',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white, fontSize: 15, shadows: [Shadow(blurRadius: 6)]),
                    ),
                  ),
                  const SizedBox(height: 24),
                  _BottomControls(controller: controller, onGallery: pickFromGallery),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onHistory, required this.onSettings});
  final VoidCallback onHistory;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        children: [
          const Icon(Icons.qr_code_scanner, color: brand, size: 26),
          const SizedBox(width: 10),
          const Text(
            appName,
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          IconButton(
            onPressed: onHistory,
            tooltip: 'History',
            icon: const Icon(Icons.history, color: Colors.white),
          ),
          IconButton(
            onPressed: onSettings,
            tooltip: 'Settings and about',
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _BottomControls extends StatelessWidget {
  const _BottomControls({required this.controller, required this.onGallery});
  final MobileScannerController? controller;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(icon: Icons.photo_library_outlined, label: 'Gallery', onTap: onGallery, big: true),
        if (c != null)
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: c,
            builder: (context, state, _) {
              final available = state.isRunning && state.torchState != TorchState.unavailable;
              final on = state.torchState == TorchState.on;
              return _RoundButton(
                icon: on ? Icons.flashlight_on : Icons.flashlight_off_outlined,
                label: on ? 'Light on' : 'Light',
                active: on,
                onTap: available ? c.toggleTorch : null,
              );
            },
          ),
        if (c != null)
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: c,
            builder: (context, state, _) => _RoundButton(
              icon: Icons.cameraswitch_outlined,
              label: 'Flip',
              onTap: state.isRunning && (state.availableCameras ?? 2) > 1 ? c.switchCamera : null,
            ),
          ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({required this.icon, required this.label, this.onTap, this.active = false, this.big = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool active;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final size = big ? 68.0 : 56.0;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: active ? brand : (big ? Colors.white : Colors.white24),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onTap,
                child: SizedBox(
                  width: size,
                  height: size,
                  child: Icon(icon, size: big ? 30 : 26, color: big || active ? Colors.black87 : Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.error, required this.onRetry, required this.onGallery});
  final MobileScannerException error;
  final VoidCallback onRetry;
  final VoidCallback onGallery;

  @override
  Widget build(BuildContext context) {
    final denied = error.errorCode == MobileScannerErrorCode.permissionDenied;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(denied ? Icons.no_photography_outlined : Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                denied
                    ? 'ScanLink needs the camera to scan codes.\n'
                          'If you said no, allow Camera for ScanLink in your phone\'s Settings → Apps.\n\n'
                          'You can still scan a picture from your gallery.'
                    : 'The camera could not start.\n${error.errorDetails?.message ?? ''}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.4),
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  FilledButton.tonal(onPressed: onRetry, child: const Text('Try again')),
                  FilledButton(onPressed: onGallery, child: const Text('Scan a picture')),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
