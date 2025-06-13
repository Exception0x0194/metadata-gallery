import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants.dart';
import '../models/scanned_folder.dart';
import '../models/scanned_image.dart';

class DatabaseService with ChangeNotifier {
  Database? _database;
  Database get db => _database!;

  List<ScannedFolder> _folders = [];
  List<ScannedFolder> get folders => _folders;

  // 数据库表名和字段名常量
  static const String _databaseName = 'metadata_gallery';
  late final String dbPath;

  static const String _imageTableName = 'images';
  static const String _colFilePath = 'file_path';
  static const String _colMetadataText = 'metadata_text';
  static const String _colLastModified = 'last_modified';

  static const String _folderTableName = 'folders';
  static const String _colFolderPath = 'folder_path';
  static const String _colLastScanned = 'last_scanned';
  static const String _colImageCount = 'image_count';

  Future<void> initialize() async {
    if (Platform.isAndroid) {
      // On Android, data/data/<package_name>/metadata_gallery.db
      final dbDirPath = await getDatabasesPath();
      dbPath = join(dbDirPath, '$_databaseName.db');
    } else if (Platform.isWindows || Platform.isIOS || Platform.isMacOS) {
      // On windows, %appdata%/metadata_gallery/metadata_gallery.db
      final dbDirPath = await getApplicationDocumentsDirectory();
      dbPath = join(dbDirPath.path, appName, '$_databaseName.db');
      await Directory(dirname(dbPath)).create(recursive: true);
    } else {
      throw UnsupportedError("不支持的平台：${Platform.operatingSystem}");
    }
    databaseFactory = databaseFactoryFfi;
    _database = await openDatabase(dbPath, version: 1, onOpen: _onOpen);

    _folders = await _loadFoldersFromDb();
    notifyListeners();
  }

  Future<void> _onOpen(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_imageTableName (
        $_colFilePath TEXT PRIMARY KEY,
        $_colMetadataText TEXT,
        $_colLastModified INTEGER
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_folderTableName (
        $_colFolderPath TEXT PRIMARY KEY,
        $_colImageCount INTEGER,
        $_colLastScanned INTEGER
      )
    ''');
  }

  Future<List<ScannedImage>> queryImagesByKeyword(String keyword) async {
    // 使用 LIKE 操作符进行模糊查询
    // %keyword% 表示匹配任何包含 keyword 的字符串
    final List<Map<String, dynamic>> maps = await db.query(
      _imageTableName,
      columns: [_colFilePath, _colMetadataText, _colLastModified],
      where: '$_colMetadataText NOT NULL AND $_colMetadataText LIKE ?',
      whereArgs: ['%$keyword%'],
    );

    // 将查询结果 (List<Map<String, dynamic>>) 转换为 ImageMetadata 列表
    return List.generate(maps.length, (i) {
      return ScannedImage(
        filePath: maps[i][_colFilePath],
        metadataString: maps[i][_colMetadataText],
        lastModieied: BigInt.from(maps[i][_colLastModified]),
      );
    });
  }

  Future<List<ScannedImage>> getAllImages() async {
    final List<Map<String, dynamic>> maps = await db.query(
      _imageTableName,
      columns: [_colFilePath, _colMetadataText, _colLastModified],
    );
    return List.generate(
      maps.length,
      (i) => ScannedImage(
        filePath: maps[i][_colFilePath],
        metadataString: maps[i][_colMetadataText],
        lastModieied: BigInt.from(maps[i][_colLastModified]),
      ),
    );
  }

  Future<void> updateImages(List<ScannedImage> images) async {
    final batch = db.batch();
    for (final img in images) {
      batch.insert(_imageTableName, {
        _colFilePath: img.filePath,
        _colMetadataText: img.metadataString,
        _colLastModified: img.lastModieied.toInt(),
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit();
  }

  Future<List<ScannedFolder>> _loadFoldersFromDb() async {
    final List<Map<String, dynamic>> maps = await db.query(
      _folderTableName,
      columns: [_colFolderPath, _colImageCount, _colLastScanned],
    );
    return List.generate(
      maps.length,
      (i) => ScannedFolder(
        path: maps[i][_colFolderPath],
        imageCount: maps[i][_colImageCount],
        lastScanned: maps[i][_colLastScanned] != null
            ? BigInt.from(maps[i][_colLastScanned])
            : null,
      ),
    );
  }

  Future<void> updateFolder(ScannedFolder folder) async {
    await db.insert(_folderTableName, {
      _colFolderPath: folder.path,
      _colImageCount: folder.imageCount,
      _colLastScanned: folder.lastScanned?.toInt(),
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    final idx = _folders.indexWhere((f) => f.path == folder.path);
    if (idx == -1) {
      _folders.add(folder);
    } else {
      _folders[idx].path = folder.path;
      _folders[idx].lastScanned = folder.lastScanned;
    }
    notifyListeners();
  }

  Future<void> removeFolder(ScannedFolder folder) async {
    await db.delete(
      _folderTableName,
      where: '$_colFolderPath == ?',
      whereArgs: [folder.path],
    );
    _folders.removeWhere((f) => f.path == folder.path);
    notifyListeners();
  }
}
