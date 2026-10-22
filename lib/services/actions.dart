import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Side effects the result sheet triggers, behind one seam so tests can fake them.
class ContentActions {
  const ContentActions();

  /// Opens [uri] in the app that handles it (browser, dialler, mail, maps).
  /// Returns false when no app could open it.
  Future<bool> open(Uri uri) async {
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } on PlatformException {
      return false;
    }
  }

  Future<void> copy(String text) => Clipboard.setData(ClipboardData(text: text));

  Future<void> share(String text) => SharePlus.instance.share(ShareParams(text: text));
}
