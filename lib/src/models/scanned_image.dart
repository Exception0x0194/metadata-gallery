class ScannedImage {
  final String filePath;
  final BigInt lastModieied;
  final String? metadataString;

  ScannedImage({
    required this.filePath,
    required this.lastModieied,
    required this.metadataString,
  });
}
