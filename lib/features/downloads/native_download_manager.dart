import 'package:flutter/services.dart';

class NativeDownloadException implements Exception {
  const NativeDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

class NativeDownloadResult {
  const NativeDownloadResult({
    required this.downloadId,
    required this.filePath,
  });

  final int downloadId;
  final String filePath;
}

class NativeDownloadStatus {
  const NativeDownloadStatus({
    required this.downloadId,
    required this.status,
    required this.receivedBytes,
    required this.totalBytes,
    required this.reason,
    this.filePath,
  });

  final int downloadId;
  final String status;
  final int receivedBytes;
  final int totalBytes;
  final int reason;
  final String? filePath;

  factory NativeDownloadStatus.fromMap(Map<dynamic, dynamic> raw) {
    return NativeDownloadStatus(
      downloadId: _asInt(raw['downloadId']),
      status: raw['status'] as String? ?? 'unknown',
      receivedBytes: _asInt(raw['receivedBytes']),
      totalBytes: _asInt(raw['totalBytes']),
      reason: _asInt(raw['reason']),
      filePath: raw['filePath'] as String?,
    );
  }
}

class NativeDownloadManager {
  const NativeDownloadManager();

  static const _channel = MethodChannel('app_deployer/download_manager');

  Future<NativeDownloadResult> downloadApk({
    required String releaseId,
    required String url,
    required String fileName,
    required String title,
    required String description,
    Map<String, String> headers = const {},
    required void Function(int receivedBytes, int totalBytes) onProgress,
  }) async {
    final downloadId = await _channel.invokeMethod<int>('enqueueApkDownload', {
      'releaseId': releaseId,
      'url': url,
      'fileName': fileName,
      'title': title,
      'description': description,
      'headers': headers,
    });

    if (downloadId == null) {
      throw const NativeDownloadException('Android download could not be queued.');
    }

    var lastReceivedBytes = 0;
    var lastProgressAt = DateTime.now();
    var removeAfterError = false;

    try {
      while (true) {
        await Future<void>.delayed(const Duration(milliseconds: 500));

        final rawStatus = await _channel.invokeMethod<Map<dynamic, dynamic>>(
          'queryDownload',
          {'downloadId': downloadId},
        );

        if (rawStatus == null) {
          throw const NativeDownloadException('Android download no longer exists.');
        }

        final status = rawStatus['status'] as String?;
        final receivedBytes = _asInt(rawStatus['receivedBytes']);
        final totalBytes = _asInt(rawStatus['totalBytes']);
        onProgress(receivedBytes, totalBytes);

        if (receivedBytes > lastReceivedBytes) {
          lastReceivedBytes = receivedBytes;
          lastProgressAt = DateTime.now();
        } else if (status == 'running' &&
            DateTime.now().difference(lastProgressAt) >
            const Duration(seconds: 45)) {
          removeAfterError = true;
          throw NativeDownloadException(
            'Android download stalled at $receivedBytes bytes.',
          );
        }

        if (status == 'successful') {
          final filePath = rawStatus['filePath'] as String?;
          if (filePath == null || filePath.isEmpty) {
            throw const NativeDownloadException(
              'Android download completed without a file path.',
            );
          }

          return NativeDownloadResult(
            downloadId: downloadId,
            filePath: filePath,
          );
        }

        if (status == 'failed') {
          removeAfterError = true;
          final reason = rawStatus['reason'];
          throw NativeDownloadException(
            'Android download failed${reason == null ? '.' : ' (reason $reason).'}',
          );
        }
      }
    } catch (_) {
      if (removeAfterError) {
        await removeDownload(downloadId);
      }
      rethrow;
    }
  }

  Future<bool> removeDownload(int downloadId) async {
    return await _channel.invokeMethod<bool>(
          'removeDownload',
          {'downloadId': downloadId},
        ) ??
        false;
  }

  Future<NativeDownloadStatus?> findDownload(String releaseId) async {
    final rawStatus = await _channel.invokeMethod<Map<dynamic, dynamic>?>(
      'findDownload',
      {'releaseId': releaseId},
    );
    if (rawStatus == null) return null;
    return NativeDownloadStatus.fromMap(rawStatus);
  }
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return 0;
}
