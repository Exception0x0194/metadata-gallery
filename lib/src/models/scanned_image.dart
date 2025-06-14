class ScannedImage {
  final String filePath;
  final BigInt lastModieied;
  final double? aspectRatio;
  final String? metadataString;

  ScannedImage({
    required this.filePath,
    required this.lastModieied,
    required this.aspectRatio,
    required this.metadataString,
  });

  bool get isImage => aspectRatio != null; // Only images have aspect retio
}
