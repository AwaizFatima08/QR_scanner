// Renders ScanLink's launcher icons and Play icon in code, so they can be
// regenerated at any time (no image tools or generators needed).
//
//   flutter test tool/make_graphics_test.dart
//
// Writes:
//   android/app/src/main/res/drawable-*/ic_launcher_{foreground,background,monochrome}.png  adaptive icon
//   android/app/src/main/res/mipmap-*/ic_launcher.png                                        legacy icon
//   store-assets/icon-512.png                                                                Play icon
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const res = 'android/app/src/main/res';
const teal = Color(0xFF00B894);
const tealDeep = Color(0xFF00695C);

Future<void> save(String path, int w, int h, void Function(Canvas c, Size s) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec), Size(w.toDouble(), h.toDouble()));
  final img = await rec.endRecording().toImage(w, h);
  final png = await img.toByteData(format: ui.ImageByteFormat.png);
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(png!.buffer.asUint8List());
}

void background(Canvas c, Rect r) {
  c.drawRect(r, Paint()..shader = ui.Gradient.linear(r.topLeft, r.bottomRight, [teal, tealDeep]));
}

/// The ScanLink mark in the unit box [box]: viewfinder corners around a small
/// QR code whose bottom-right corner is a link arrow.
void mark(Canvas c, Rect box, {bool mono = false}) {
  Offset p(double x, double y) => Offset(box.left + box.width * x, box.top + box.height * y);
  final w = box.width;
  // Everything is white; [mono] only matters for callers' clarity (themed icons).
  const fg = Colors.white;

  // Viewfinder corners.
  final corners = Paint()
    ..color = fg
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.075
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  const a = 0.06, b = 0.94, len = 0.24;
  for (final (cx, cy, dx, dy) in [(a, a, 1, 1), (b, a, -1, 1), (b, b, -1, -1), (a, b, 1, -1)]) {
    c.drawPath(
      Path()
        ..moveTo(p(cx, cy + dy * len).dx, p(cx, cy + dy * len).dy)
        ..lineTo(p(cx, cy).dx, p(cx, cy).dy)
        ..lineTo(p(cx + dx * len, cy).dx, p(cx + dx * len, cy).dy),
      corners,
    );
  }

  // Three QR finder patterns.
  final solid = Paint()..color = fg;
  void finder(double x, double y) {
    final s = 0.20;
    final outer = RRect.fromRectAndRadius(
      Rect.fromLTWH(p(x, y).dx, p(x, y).dy, w * s, w * s),
      Radius.circular(w * 0.03),
    );
    final inner = RRect.fromRectAndRadius(
      Rect.fromLTWH(p(x + 0.035, y + 0.035).dx, p(x + 0.035, y + 0.035).dy, w * (s - 0.07), w * (s - 0.07)),
      Radius.circular(w * 0.02),
    );
    c.drawDRRect(outer, inner, solid);
    c.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(p(x + 0.065, y + 0.065).dx, p(x + 0.065, y + 0.065).dy, w * 0.07, w * 0.07),
        Radius.circular(w * 0.01),
      ),
      solid,
    );
  }

  finder(0.24, 0.24);
  finder(0.56, 0.24);
  finder(0.24, 0.56);

  // A few data modules.
  for (final (x, y) in [
    (0.47, 0.27),
    (0.47, 0.37),
    (0.47, 0.47),
    (0.27, 0.47),
    (0.37, 0.47),
    (0.57, 0.47),
    (0.67, 0.47),
  ]) {
    c.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(p(x, y).dx, p(x, y).dy, w * 0.06, w * 0.06), Radius.circular(w * 0.01)),
      solid,
    );
  }

  // Link arrow in the fourth corner.
  final arrow = Paint()
    ..color = fg
    ..style = PaintingStyle.stroke
    ..strokeWidth = w * 0.055
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  c.drawLine(p(0.60, 0.76), p(0.76, 0.60), arrow);
  c.drawPath(
    Path()
      ..moveTo(p(0.63, 0.60).dx, p(0.63, 0.60).dy)
      ..lineTo(p(0.76, 0.60).dx, p(0.76, 0.60).dy)
      ..lineTo(p(0.76, 0.73).dx, p(0.76, 0.73).dy),
    arrow,
  );
}

Future<void> makeIcons() async {
  const sizes = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};
  for (final e in sizes.entries) {
    // Adaptive layers are 108dp; the mark sits inside the 66dp safe zone.
    final fg = (108 * e.value).round();
    Rect safe(Size s) => Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.56, height: s.height * 0.56);
    await save('$res/drawable-${e.key}/ic_launcher_foreground.png', fg, fg, (c, s) => mark(c, safe(s)));
    await save('$res/drawable-${e.key}/ic_launcher_monochrome.png', fg, fg, (c, s) => mark(c, safe(s), mono: true));
    await save('$res/drawable-${e.key}/ic_launcher_background.png', fg, fg, (c, s) => background(c, Offset.zero & s));

    final lg = (48 * e.value).round();
    await save('$res/mipmap-${e.key}/ic_launcher.png', lg, lg, (c, s) {
      final r = RRect.fromRectAndRadius(Offset.zero & s, Radius.circular(s.width * 0.22));
      c.clipRRect(r);
      background(c, Offset.zero & s);
      mark(c, Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.7, height: s.height * 0.7));
    });
  }
  File('$res/mipmap-anydpi-v26/ic_launcher.xml')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background" />
    <foreground android:drawable="@drawable/ic_launcher_foreground" />
    <monochrome android:drawable="@drawable/ic_launcher_monochrome" />
</adaptive-icon>
''');
  // Play icon: full square, Play applies its own mask.
  await save('store-assets/icon-512.png', 512, 512, (c, s) {
    background(c, Offset.zero & s);
    mark(c, Rect.fromCenter(center: s.center(Offset.zero), width: s.width * 0.66, height: s.height * 0.66));
  });
}

void main() {
  testWidgets('make graphics', (tester) async {
    await tester.runAsync(makeIcons);
  });
}
