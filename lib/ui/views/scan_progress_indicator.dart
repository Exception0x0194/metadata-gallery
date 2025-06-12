import 'dart:async';

import 'package:flutter/material.dart';

import '../../src/rust/api/scan.dart';
import '../viewmodels/scan_progress_indicator_viewmodel.dart';

class ScanProgressIndicator extends StatefulWidget {
  final ScanProgressIndicatorViewmodel viewmodel;

  const ScanProgressIndicator({super.key, required this.viewmodel});

  @override
  State<StatefulWidget> createState() => _ScanProgressIndicatorState();
}

class _ScanProgressIndicatorState extends State<ScanProgressIndicator> {
  ScanProgressIndicatorViewmodel get viewmodel => widget.viewmodel;
  StreamSubscription<ScanProgress>? _progressSubscription;

  ScanProgress? _currentProgress;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();
    widget.viewmodel.addListener(_onViewModelChanged);
    _subscribeToStream();
  }

  /// 当ViewModel中的progress流发生变化时被调用
  void _onViewModelChanged() {
    _subscribeToStream();
    if (!mounted) return;
    setState(() {});
  }

  /// 订阅或取消订阅流
  void _subscribeToStream() {
    // 取消旧的订阅
    _progressSubscription?.cancel();
    _progressSubscription = null;

    // 重置进度状态
    _isCompleted = false;
    _currentProgress = null;

    final progress = viewmodel.progress;
    if (progress == null) return;

    // 监听新的流
    _progressSubscription = progress.listen(
      (ScanProgress data) {
        setState(() {
          _currentProgress = data;
        });
      },
      onDone: () {
        setState(() {
          _isCompleted = true;
        });
        // 完成时定时销毁订阅
        Timer(Duration(seconds: 2), () {
          if (_isCompleted && mounted) {
            widget.viewmodel.setProgress(null);
          }
        });
      },
    );
  }

  @override
  void dispose() {
    widget.viewmodel.removeListener(_onViewModelChanged);
    _progressSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 如果没有进度，就显示一个空的小部件
    if (_currentProgress == null) {
      return const SizedBox.shrink();
    }

    final data = _currentProgress!;
    final String progressText;
    final Widget progressIcon;

    if (_isCompleted) {
      // 如果任务已完成
      progressText = "扫描完成: ${data.processed}/${data.total}";
      progressIcon = const Icon(Icons.done_all_outlined, color: Colors.green);
    } else {
      // 如果任务正在进行中
      progressText = "正在扫描: ${data.processed}/${data.total}";
      progressIcon = CircularProgressIndicator(
        value: data.total == 0 ? 0 : data.processed / data.total,
      );
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Row(
          mainAxisSize: MainAxisSize.min, // 让Row的宽度适应内容
          children: [
            SizedBox(width: 24.0, height: 24.0, child: progressIcon),
            const SizedBox(width: 16.0),
            Text(progressText, style: Theme.of(context).textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }
}
