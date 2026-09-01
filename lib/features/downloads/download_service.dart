import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../apps/models/app_release.dart';
import 'download_result.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(dioProvider));
});

class DownloadService {
  const DownloadService(this._dio);

  final Dio _dio;

  Future<DownloadResult> downloadRelease(
    AppRelease release, {
    void Function(int progress)? onProgress,
  }) async {
    final signedUrlResponse = await _dio.get('/api/releases/${release.id}/download-url');
    final signedUrlJson = signedUrlResponse.data as Map<String, dynamic>;
    final downloadUrl = signedUrlJson['downloadUrl'] as String;
    final expectedSha256 = signedUrlJson['apkSha256'] as String? ?? release.apkSha256;

    final dir = await getApplicationDocumentsDirectory();
    final apkDir = Directory('${dir.path}/apks');
    if (!await apkDir.exists()) {
      await apkDir.create(recursive: true);
    }

    final file = File('${apkDir.path}/${release.id}-${release.versionCode}.apk');

    await _dio.download(
      downloadUrl,
      file.path,
      onReceiveProgress: (received, total) {
        if (total > 0) {
          onProgress?.call(((received / total) * 100).round());
        }
      },
    );

    final actualSha256 = await calculateSha256(file);
    return DownloadResult(
      file: file,
      verified: actualSha256.toLowerCase() == expectedSha256.toLowerCase(),
      expectedSha256: expectedSha256,
      actualSha256: actualSha256,
    );
  }
}

Future<String> calculateSha256(File file) async {
  final stream = file.openRead();
  final digest = await sha256.bind(stream).first;
  return digest.toString();
}
