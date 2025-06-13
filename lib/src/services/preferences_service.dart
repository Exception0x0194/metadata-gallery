import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService with ChangeNotifier {
  late SharedPreferences _perfs;

  Future<void> initialize() async {
    _perfs = await SharedPreferences.getInstance();
  }

  int getInt(String key, int defaults) {
    final result = _perfs.getInt(key);
    if (result == null) {
      _perfs.setInt(key, defaults);
      return defaults;
    }
    return result;
  }

  Future<void> setInt(String key, int value) async {
    await _perfs.setInt(key, value);
    notifyListeners();
  }

  String getString(String key, String defaults) {
    final result = _perfs.getString(key);
    if (result == null) {
      _perfs.setString(key, defaults);
      return defaults;
    }
    return result;
  }

  Future<void> setString(String key, String value) async {
    await _perfs.setString(key, value);
    notifyListeners();
  }

  bool getBool(String key, bool defaults) {
    final result = _perfs.getBool(key);
    if (result == null) {
      _perfs.setBool(key, defaults);
      return defaults;
    }
    return result;
  }

  Future<void> setBool(String key, bool value) async {
    await _perfs.setBool(key, value);
    notifyListeners();
  }
}
