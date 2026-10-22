import 'package:flutter_test/flutter_test.dart';
import 'package:scanlink/services/history.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  HistoryEntry e(String raw, [int minute = 0]) =>
      HistoryEntry(raw: raw, format: 'qrCode', time: DateTime(2026, 10, 22, 12, minute));

  test('newest first, duplicates move to the top, survives a restart', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final h = History(prefs);
    await h.add(e('a'));
    await h.add(e('b', 1));
    await h.add(e('a', 2));
    expect(h.entries.map((x) => x.raw), ['a', 'b']);

    final reloaded = History(prefs);
    expect(reloaded.entries.map((x) => x.raw), ['a', 'b']);
    expect(reloaded.entries.first.time, DateTime(2026, 10, 22, 12, 2));
  });

  test('keeps at most maxEntries', () async {
    SharedPreferences.setMockInitialValues({});
    final h = History(await SharedPreferences.getInstance());
    for (var i = 0; i < History.maxEntries + 5; i++) {
      await h.add(e('$i'));
    }
    expect(h.entries.length, History.maxEntries);
    expect(h.entries.first.raw, '${History.maxEntries + 4}');
  });

  test('corrupt storage starts empty instead of crashing', () async {
    SharedPreferences.setMockInitialValues({'history.v1': 'not json'});
    expect(History(await SharedPreferences.getInstance()).entries, isEmpty);
  });

  test('clear and remove', () async {
    SharedPreferences.setMockInitialValues({});
    final h = History(await SharedPreferences.getInstance());
    await h.add(e('a'));
    await h.add(e('b'));
    await h.remove(h.entries.first);
    expect(h.entries.map((x) => x.raw), ['a']);
    await h.clear();
    expect(h.entries, isEmpty);
  });
}
