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
  DownloadService(this._dio)
      : _directDownloadDio = Dio(
          BaseOptions(
            connectTimeout: const Duration(seconds: 30),
            receiveTimeout: const Duration(minutes: 10),
          ),
        );

  final Dio _dio;
  final Dio _directDownloadDio;

  Future<DownloadResult> downloadRelease(
    AppRelease release, {
    void Function(int progress)? onProgress,
    void Function(int receivedBytes, int totalBytes)? onReceiveProgress,
  }) async {
    final signedUrlResponse = await _dio.get('/api/releases/${release.id}/download-url');
    final signedUrlJson = signedUrlResponse.data as Map<String, dynamic>;
    final downloadUrl = signedUrlJson['downloadUrl'] as String;
    final fallbackDownloadUrl = signedUrlJson['fallbackDownloadUrl'] as String?;
    final expectedSha256 = signedUrlJson['apkSha256'] as String? ?? release.apkSha256;

    final dir = await getApplicationDocumentsDirectory();
    final apkDir = Directory('${dir.path}/apks');
    if (!await apkDir.exists()) {
      await apkDir.create(recursive: true);
    }

    final file = File('${apkDir.path}/${release.id}-${release.versionCode}.apk');

    void handleProgress(int received, int total) {
      final totalBytes = total > 0 ? total : release.apkSizeBytes;
      onReceiveProgress?.call(received, totalBytes);
      if (totalBytes > 0) {
        final progress = received >= totalBytes ? 100 : ((received / totalBytes) * 100).floor();
        onProgress?.call(progress.clamp(0, 100));
      }
    }

    try {
      await _directDownloadDio.download(
        downloadUrl,
        file.path,
        deleteOnError: true,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: handleProgress,
      );
    } catch (error, stackTrace) {
      await _deleteIfExists(file);
      if (fallbackDownloadUrl == null || fallbackDownloadUrl.isEmpty) {
        Error.throwWithStackTrace(error, stackTrace);
      }

      await _dio.download(
        fallbackDownloadUrl,
        file.path,
        deleteOnError: true,
        options: Options(responseType: ResponseType.bytes),
        onReceiveProgress: handleProgress,
      );
    }

    final actualSha256 = await calculateSha256(file);
    final verified = actualSha256.toLowerCase() == expectedSha256.toLowerCase();
    if (!verified) {
      await _deleteIfExists(file);
    }

    return DownloadResult(
      file: file,
      verified: verified,
      expectedSha256: expectedSha256,
      actualSha256: actualSha256,
    );
  }
}

Future<void> _deleteIfExists(File file) async {
  if (await file.exists()) {
    await file.delete();
  }
}

Future<String> calculateSha256(File file) async {
  final stream = file.openRead();
  final digest = await sha256.bind(stream).first;
  return digest.toString();
}
