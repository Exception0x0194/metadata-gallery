import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../core/constants.dart';
import '../models/scanned_image.dart';

class DatabaseService {
  Database? _database;
  Database get db => _database!;

  late final String dbPath;

  // 数据库表名和字段名常量
  static const String _databaseName = 'metadata_gallery';

  static const String _imageTableName = 'images';
  static const String _colFilePath = 'file_path';
  static const String _colMetadataText = 'metadata_text';
  static const String _colLastModified = 'last_modified';

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
    _database = await openDatabase(dbPath, version: 1, onCreate: _onCreate);
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_imageTableName (
        $_colFilePath TEXT PRIMARY KEY,
        $_colMetadataText TEXT,
        $_colLastModified INTEGER
      )
    ''');
  }

  Future<List<ScannedImage>> queryImagesByKeyword(String keyword) async {
    // 使用 LIKE 操作符进行模糊查询
    // %keyword% 表示匹配任何包含 keyword 的字符串
    final List<Map<String, dynamic>> maps = await db.query(
      _imageTableName,
      columns: [_colFilePath, _colMetadataText],
      where: '$_colMetadataText LIKE ?',
      whereArgs: ['%$keyword%'],
    );

    // 将查询结果 (List<Map<String, dynamic>>) 转换为 ImageMetadata 列表
    return List.generate(maps.length, (i) {
      return ScannedImage(
        filePath: maps[i][_colFilePath],
        metadataString: maps[i][_colMetadataText],
      );
    });
  }

  Future<List<ScannedImage>> getAllImages() async {
    final List<Map<String, dynamic>> maps = await db.query(
      _imageTableName,
      columns: [_colFilePath, _colMetadataText],
    );

    return List.generate(maps.length, (i) {
      return ScannedImage(
        filePath: maps[i][_colFilePath],
        metadataString: maps[i][_colMetadataText],
      );
    });
  }
}
