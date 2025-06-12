import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../src/models/scanned_image.dart';

class ImageCard extends StatefulWidget {
  final ScannedImage image;

  const ImageCard({super.key, required this.image});

  @override
  State<StatefulWidget> createState() => _ImageCardState();
}

class _ImageCardState extends State<ImageCard> {
  ScannedImage get image => widget.image;

  @override
  Widget build(BuildContext context) {
    final thumbFile = File(image.filePath);
    return InkWell(
      onDoubleTap: () => locateFile(),
      child: Card(
        margin: EdgeInsets.all(8.0),
        child: Image.file(thumbFile, cacheWidth: 512),
      ),
    );
  }

  void locateFile() {
    try {
      Process.run('explorer.exe', ['/select,', image.filePath]);
    } catch (e) {
      if (kDebugMode) {
        print('Error locating file: $e');
      }
    }
  }
}
