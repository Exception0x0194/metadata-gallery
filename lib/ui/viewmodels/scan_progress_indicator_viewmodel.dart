import 'package:flutter/material.dart';

import '../../src/rust/api/scan.dart';

class ScanProgressIndicatorViewmodel extends ChangeNotifier {
  Stream<ScanProgress>? _progress;

  Stream<ScanProgress>? get progress => _progress;

  /// 设置一个新的进度流，并通知监听者
  void setProgress(Stream<ScanProgress>? newProgress) {
    _progress = newProgress;
    notifyListeners();
  }
}
