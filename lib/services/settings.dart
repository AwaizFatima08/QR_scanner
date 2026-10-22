import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Settings extends ChangeNotifier {
  Settings(this._prefs);

  final SharedPreferences _prefs;

  /// Open web links straight away instead of showing the result first.
  /// Off by default: a code can point anywhere, so the user sees the address
  /// before deciding.
  bool get autoOpenLinks => _prefs.getBool('autoOpenLinks') ?? false;
  set autoOpenLinks(bool v) => _set('autoOpenLinks', v);

  bool get vibrate => _prefs.getBool('vibrate') ?? true;
  set vibrate(bool v) => _set('vibrate', v);

  bool get saveHistory => _prefs.getBool('saveHistory') ?? true;
  set saveHistory(bool v) => _set('saveHistory', v);

  /// End of the 24-hour ad-free pass earned with a rewarded ad (null = none).
  DateTime? get adFreeUntil {
    final ms = _prefs.getInt('adFreeUntil');
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  set adFreeUntil(DateTime? v) {
    v == null ? _prefs.remove('adFreeUntil') : _prefs.setInt('adFreeUntil', v.millisecondsSinceEpoch);
    notifyListeners();
  }

  void _set(String key, bool v) {
    _prefs.setBool(key, v);
    notifyListeners();
  }
}
