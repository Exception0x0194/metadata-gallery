import 'package:flutter/material.dart';
import '../viewmodels/scan_progress_indicator_viewmodel.dart';

class ScanProgressIndicator extends StatefulWidget {
  final ScanProgressIndicatorViewmodel viewmodel;

  const ScanProgressIndicator({super.key, required this.viewmodel});

  @override
  State<StatefulWidget> createState() => _ScanProgressIndicatorState();
}

class _ScanProgressIndicatorState extends State<ScanProgressIndicator> {
  ScanProgressIndicatorViewmodel get viewmodel => widget.viewmodel;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewmodel,
      builder: (context, child) {
        if (viewmodel.hidden) {
          return SizedBox.shrink();
        }

        final String progressText;
        final Widget progressIcon;
        if (viewmodel.isDone) {
          // 如果任务已完成
          progressText = "已完成：扫描了 ${viewmodel.total} 个文件";
          progressIcon = const Icon(
            Icons.done_all_outlined,
            color: Colors.green,
          );
        } else {
          // 如果任务正在进行中
          progressText = "正在扫描：扫描了 ${viewmodel.total} 个文件";
          progressIcon = CircularProgressIndicator(
            value: viewmodel.progress.clamp(0.0, 1.0),
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
                Text(
                  progressText,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
