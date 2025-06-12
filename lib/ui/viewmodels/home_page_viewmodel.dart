import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../src/core/constants.dart';
import '../../src/models/scanned_image.dart';
import '../../src/rust/api/scan.dart';
import '../../src/services/database_service.dart';
import 'scan_progress_indicator_viewmodel.dart';

class HomePageViewmodel extends ChangeNotifier {
  SharedPreferences get prefs => GetIt.I();
  DatabaseService get dbService => GetIt.I();

  final scanProgressIndicatorViewmodel = ScanProgressIndicatorViewmodel();

  List<ScannedImage> searchResult = [];

  Future<void> callScan() async {
    final folders = prefs.getStringList(foldersToScanKey) ?? [];
    final thumbnailDir = join(
      (await getApplicationCacheDirectory()).path,
      appName,
    );
    await Directory(thumbnailDir).create(recursive: true);
    scanProgressIndicatorViewmodel.setProgress(
      scanFolders(
        folders: folders,
        dbPath: dbService.dbPath,
        thumbnailDir: thumbnailDir,
      ).asBroadcastStream(),
    );
  }

  Future<void> searchImages(String keyword) async {
    searchResult = await dbService.queryImagesByKeyword(keyword);
    if (kDebugMode) {
      print('Search for $keyword: ${searchResult.length} results');
    }
    notifyListeners();
  }
}
