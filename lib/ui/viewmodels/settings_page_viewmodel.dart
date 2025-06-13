import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:file_picker/file_picker.dart';

import '../../src/models/scanned_folder.dart';
import '../../src/services/database_service.dart';

class SettingsPageViewmodel with ChangeNotifier {
  DatabaseService get dbService => GetIt.I();

  List<ScannedFolder> get foldersToScan => dbService.folders;

  void onDatabaseChanged() => notifyListeners();

  Future<void> browseAndAddFolder() async {
    final pickResult = await FilePicker.platform.getDirectoryPath();
    if (pickResult == null) return;

    final folders = foldersToScan;
    if (folders.any((f) => f.path == pickResult)) return;

    dbService.updateFolder(ScannedFolder(path: pickResult));
    notifyListeners();
  }

  Future<void> removeFolderToScan(int index) async {
    final folders = foldersToScan;
    if (index >= folders.length) return;
    dbService.removeFolder(folders[index]);
    notifyListeners();
  }

  void locateFolder(String path) {
    Process.run("explorer", [path]);
  }
}
