import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../apps/models/app_release.dart';
import 'download_result.dart';
import 'native_download_manager.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(dioProvider), const NativeDownloadManager());
});

class DownloadService {
  DownloadService(this._dio, this._nativeDownloadManager);

  final Dio _dio;
  final NativeDownloadManager _nativeDownloadManager;

  Future<DownloadResult> downloadRelease(
    AppRelease release, {
    required String appId,
    required String appName,
    required String packageName,
    void Function(int progress)? onProgress,
    void Function(int receivedBytes, int totalBytes)? onReceiveProgress,
  }) async {
    final signedUrlResponse = await _dio.get('/api/releases/${release.id}/download-url');
    final signedUrlJson = signedUrlResponse.data as Map<String, dynamic>;
    final downloadUrl = signedUrlJson['downloadUrl'] as String;
    final fallbackDownloadUrl = signedUrlJson['fallbackDownloadUrl'] as String?;
    final expectedSha256 = signedUrlJson['apkSha256'] as String? ?? release.apkSha256;
    final resolvedFallbackDownloadUrl = fallbackDownloadUrl == null ||
            fallbackDownloadUrl.isEmpty
        ? null
        : _resolveUrl(fallbackDownloadUrl, _dio.options.baseUrl);

    // FileProvider exposes the app's files directory, while
    // getApplicationDocumentsDirectory() resolves to Flutter's private
    // `app_flutter` directory on Android. Keep the APK in the support
    // directory so the native installer can create a safe content URI.
    final dir = await getApplicationSupportDirectory();
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

    File? downloadedFile;

    final nativeDownloadUrl = resolvedFallbackDownloadUrl ?? downloadUrl;
    final nativeHeaders = <String, String>{
      if (_dio.options.headers['Authorization'] is String)
        'Authorization': _dio.options.headers['Authorization'] as String,
    };

    try {
      final nativeResult = await _nativeDownloadManager.downloadApk(
        releaseId: release.id,
        url: nativeDownloadUrl,
        fileName: '${release.id}-${release.versionCode}.apk',
        appId: appId,
        appName: appName,
        packageName: packageName,
        title: '$appName ${release.versionName}',
        description: 'Downloading version ${release.versionCode}',
        versionName: release.versionName,
        versionCode: release.versionCode,
        headers: nativeHeaders,
        onProgress: handleProgress,
      );
      downloadedFile = File(nativeResult.filePath);
    } catch (error, stackTrace) {
      await _deleteIfExists(file);

      final dioUrls = <String>[
        if (nativeDownloadUrl != downloadUrl) downloadUrl,
        if (resolvedFallbackDownloadUrl != null) resolvedFallbackDownloadUrl,
      ];
      Object lastError = error;
      StackTrace lastStackTrace = stackTrace;

      for (final dioUrl in dioUrls) {
        try {
          await _dio.download(
            dioUrl,
            file.path,
            deleteOnError: true,
            options: Options(responseType: ResponseType.bytes),
            onReceiveProgress: handleProgress,
          );
          downloadedFile = file;
          break;
        } catch (fallbackError, fallbackStackTrace) {
          await _deleteIfExists(file);
          lastError = fallbackError;
          lastStackTrace = fallbackStackTrace;
        }
      }

      if (downloadedFile == null) {
        Error.throwWithStackTrace(lastError, lastStackTrace);
      }
    }

    final completedFile = downloadedFile;
    final actualSha256 = await calculateSha256(completedFile);
    final verified = actualSha256.toLowerCase() == expectedSha256.toLowerCase();
    if (!verified) {
      await _deleteIfExists(completedFile);
    }

    return DownloadResult(
      file: completedFile,
      verified: verified,
      expectedSha256: expectedSha256,
      actualSha256: actualSha256,
    );
  }

  Future<NativeDownloadStatus?> findDownload(String releaseId) {
    return _nativeDownloadManager.findDownload(releaseId);
  }

  Future<List<NativeDownloadStatus>> listDownloads() {
    return _nativeDownloadManager.listDownloads();
  }

  Future<bool> cancelRelease(String releaseId) {
    return _nativeDownloadManager.cancelRelease(releaseId);
  }

  Future<NativeDownloadLaunch?> consumeDownloadLaunch() {
    return _nativeDownloadManager.consumeDownloadLaunch();
  }
}

String _resolveUrl(String value, String baseUrl) {
  if (Uri.tryParse(value)?.hasScheme == true) return value;
  return Uri.parse(baseUrl).resolve(value).toString();
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
