class ScannedImage {
  final String filePath;
  final String metadataString;

  ScannedImage({required this.filePath, required this.metadataString});

  @override
  String toString() {
    return 'ImageMetadata{filePath: $filePath, metadataString: $metadataString}';
  }
}
