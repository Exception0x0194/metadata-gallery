import 'dart:async';

import 'package:flutter/material.dart';

class ScanProgressIndicatorViewmodel extends ChangeNotifier {
  bool hidden = true;
  bool isDone = true;
  int total = 0;
  double progress = 0.0;

  void setProgress(int totalScanned, double currentProgress) {
    isDone = false;
    hidden = false;
    progress = currentProgress;
    total = totalScanned;
    notifyListeners();
  }

  void setDone(int totalScanned) {
    isDone = true;
    hidden = false;
    total = totalScanned;
    notifyListeners();
    Timer(Duration(seconds: 2), () {
      if (!isDone) return;
      hidden = true;
      notifyListeners();
    });
  }
}
