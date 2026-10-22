import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One scan, kept on this phone only.
class HistoryEntry {
  const HistoryEntry({required this.raw, required this.format, required this.time, this.fromImage = false});

  final String raw;

  /// Barcode format name, e.g. "qrCode", "ean13".
  final String format;
  final DateTime time;
  final bool fromImage;

  bool get isProductFormat => productFormats.contains(format);

  static const productFormats = {'ean13', 'ean8', 'upcA', 'upcE'};

  Map<String, Object> toJson() => {'r': raw, 'f': format, 't': time.millisecondsSinceEpoch, 'i': fromImage};

  static HistoryEntry? fromJson(Object? j) {
    if (j is! Map) return null;
    final raw = j['r'], format = j['f'], t = j['t'];
    if (raw is! String || format is! String || t is! int) return null;
    return HistoryEntry(
      raw: raw,
      format: format,
      time: DateTime.fromMillisecondsSinceEpoch(t),
      fromImage: j['i'] == true,
    );
  }
}

/// Recent scans, newest first, stored in shared preferences. Scanning the same
/// code again moves it to the top instead of adding a duplicate.
class History extends ChangeNotifier {
  History(this._prefs) : _entries = _read(_prefs);

  static const _key = 'history.v1';
  static const maxEntries = 200;

  final SharedPreferences _prefs;
  final List<HistoryEntry> _entries;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  static List<HistoryEntry> _read(SharedPreferences prefs) {
    final s = prefs.getString(_key);
    if (s == null) return [];
    try {
      final list = jsonDecode(s);
      if (list is! List) return [];
      return list.map(HistoryEntry.fromJson).whereType<HistoryEntry>().toList();
    } on FormatException {
      return [];
    }
  }

  Future<void> add(HistoryEntry e) async {
    _entries
      ..removeWhere((x) => x.raw == e.raw && x.format == e.format)
      ..insert(0, e);
    if (_entries.length > maxEntries) _entries.removeRange(maxEntries, _entries.length);
    await _save();
  }

  Future<void> remove(HistoryEntry e) async {
    _entries.remove(e);
    await _save();
  }

  Future<void> clear() async {
    _entries.clear();
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await _prefs.setString(_key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }
}
