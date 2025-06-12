import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/core/constants.dart';

class SettingsPageViewmodel extends ChangeNotifier {
  SharedPreferences get prefs => GetIt.I();

  List<String>? get foldersToScan => prefs.getStringList(foldersToScanKey);

  Future<void> setFoldersToScan(List<String> folders) async {
    await prefs.setStringList(foldersToScanKey, folders);
    notifyListeners();
  }

  Future<void> browseAndAddFolder() async {
    final pickResult = await FilePicker.platform.getDirectoryPath();
    if (pickResult == null) return;
    final folders = foldersToScan ?? [];
    if (folders.contains(pickResult)) return;
    folders.add(pickResult);
    await prefs.setStringList(foldersToScanKey, folders);
    notifyListeners();
  }

  Future<void> removeFolderToScan(int index) async {
    final folders = foldersToScan ?? [];
    if (index >= folders.length) return;
    folders.removeAt(index);
    await prefs.setStringList(foldersToScanKey, folders);
    notifyListeners();
  }

  void locateFolder(String path) {
    Process.run("explorer", [path]);
  }
}
