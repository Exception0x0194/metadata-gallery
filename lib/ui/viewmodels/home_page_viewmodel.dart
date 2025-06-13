import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../../src/core/constants.dart';
import '../../src/models/scanned_folder.dart';
import '../../src/models/scanned_image.dart';
import '../../src/rust/api/scan.dart';
import '../../src/services/database_service.dart';
import '../../src/services/preferences_service.dart';
import 'scan_progress_indicator_viewmodel.dart';

class HomePageViewmodel extends ChangeNotifier {
  DatabaseService get dbService => GetIt.I();
  PreferencesService get prefsService => GetIt.I();

  final scanProgressIndicatorViewmodel = ScanProgressIndicatorViewmodel();
  final searchController = TextEditingController();
  final searchFocusNode = FocusNode();

  late List<ScannedImage> searchResult;
  late String orderOption;
  late bool orderReversed;

  HomePageViewmodel() {
    searchResult = [];
    orderOption = prefsService.getString(prefsOrderKey, prefsOrderByName);
    orderReversed = prefsService.getBool(prefsOrderReversedKey, false);
  }

  Future<void> callScan() async {
    final folders = dbService.folders;
    final allImages = await dbService.getAllImages();
    final allImagesMap = {
      for (var img in allImages) img.filePath: img.lastModieied,
    };
    int totalFilesScanned = 0;
    for (final (idx, folder) in folders.indexed) {
      final folderProgress = scanFolder(
        folderPath: folder.path,
        existingImages: allImagesMap,
      );
      await for (final data in folderProgress) {
        if (data.folderScanResult != null) {
          // Update folder info
          final result = data.folderScanResult!;
          totalFilesScanned += data.processed;
          dbService.updateFolder(
            ScannedFolder(
              path: result.folderPath,
              imageCount: data.processed,
              lastScanned: result.scanTimestamp,
            ),
          );
        }
        if (data.imageScanResults != null) {
          // Update images info
          final results = data.imageScanResults!;
          dbService.updateImages(
            List.generate(
              results.length,
              (idx) => ScannedImage(
                filePath: results[idx].filePath,
                lastModieied: results[idx].fileLastModified,
                aspectRatio: results[idx].imageAspectRatio,
                metadataString: results[idx].metadataText,
              ),
            ),
          );
        }
        // Update progress indicator
        final folderProgress = data.totalToProcess > 0
            ? data.processed / data.totalToProcess
            : 1.0;
        final overallProgress = (idx + folderProgress) / folders.length;

        scanProgressIndicatorViewmodel.setProgress(
          totalFilesScanned + data.processed,
          overallProgress,
        );
      }
    }
    scanProgressIndicatorViewmodel.setDone(totalFilesScanned);
  }

  Future<void> searchImages(String keyword) async {
    searchFocusNode.requestFocus(); // 重新获取输入焦点
    searchResult = await dbService.queryImagesByKeyword(keyword);
    if (kDebugMode) {
      print('Search for {$keyword}: ${searchResult.length} results');
    }
    reorderResults();
  }

  void onPrefsChanged() {
    notifyListeners();
  }

  void reorderResults() {
    if (orderOption == prefsOrderByName) {
      searchResult.sort((a, b) => a.filePath.compareTo(b.filePath));
    } else if (orderOption == prefsOrderByLastModified) {
      searchResult.sort((a, b) => a.lastModieied.compareTo(b.lastModieied));
    } else {
      throw Exception('Unsupported sort option: $orderOption');
    }
    if (orderReversed) {
      searchResult = searchResult.reversed.toList();
    }
    notifyListeners();
  }

  Future<void> setSortOption(value) async {
    prefsService.setString(prefsOrderKey, value);
    orderOption = value;
    reorderResults();
  }

  void setReversed(bool? value) {
    if (value == null) return;
    prefsService.setBool(prefsOrderReversedKey, value);
    orderReversed = value;
    reorderResults();
  }
}
