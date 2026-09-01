import 'dart:io';

class DownloadResult {
  const DownloadResult({
    required this.file,
    required this.verified,
    required this.expectedSha256,
    required this.actualSha256,
  });

  final File file;
  final bool verified;
  final String expectedSha256;
  final String actualSha256;
}
