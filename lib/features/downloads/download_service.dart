import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/api/api_client.dart';
import '../apps/models/app_release.dart';

final downloadServiceProvider = Provider<DownloadService>((ref) {
  return DownloadService(ref.watch(dioProvider));
});

class DownloadService {
  const DownloadService(this._dio);

  final Dio _dio;

  Future<File> downloadRelease(AppRelease release) async {
    final dir = await getApplicationDocumentsDirectory();
    final apkDir = Directory('${dir.path}/apks');
    if (!await apkDir.exists()) {
      await apkDir.create(recursive: true);
    }

    final file = File('${apkDir.path}/${release.id}-${release.versionCode}.apk');

    // The web API will later return a signed URL. The current base contract keeps
    // object keys explicit so the UI can be wired before storage credentials exist.
    await _dio.download('/download/${release.apkObjectKey}', file.path);
    return file;
  }
}
