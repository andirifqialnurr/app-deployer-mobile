import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../apps/models/app_release.dart';
import '../apps/models/mobile_app.dart';
import '../installer/installer_service.dart';
import 'download_service.dart';

final downloadControllerProvider =
    StateNotifierProvider<DownloadController, Map<String, DownloadJob>>((ref) {
  return DownloadController(
    ref.watch(downloadServiceProvider),
    ref.watch(installerServiceProvider),
  );
});

enum DownloadJobState {
  queued,
  running,
  paused,
  verifying,
  readyToInstall,
  installing,
  failed,
}

class DownloadJob {
  const DownloadJob({
    required this.releaseId,
    required this.appId,
    required this.appName,
    required this.packageName,
    required this.versionName,
    required this.versionCode,
    required this.state,
    this.receivedBytes = 0,
    this.totalBytes = 0,
    this.filePath,
    this.errorMessage,
  });

  final String releaseId;
  final String appId;
  final String appName;
  final String packageName;
  final String versionName;
  final int versionCode;
  final DownloadJobState state;
  final int receivedBytes;
  final int totalBytes;
  final String? filePath;
  final String? errorMessage;

  int get progressPercent {
    if (totalBytes <= 0) return 0;
    final value = ((receivedBytes / totalBytes) * 100).floor();
    return value.clamp(0, 100);
  }

  bool get isActive {
    return switch (state) {
      DownloadJobState.queued ||
      DownloadJobState.running ||
      DownloadJobState.paused ||
      DownloadJobState.verifying ||
      DownloadJobState.installing =>
        true,
      DownloadJobState.readyToInstall || DownloadJobState.failed => false,
    };
  }

  DownloadJob copyWith({
    DownloadJobState? state,
    int? receivedBytes,
    int? totalBytes,
    String? filePath,
    String? errorMessage,
    bool clearError = false,
  }) {
    return DownloadJob(
      releaseId: releaseId,
      appId: appId,
      appName: appName,
      packageName: packageName,
      versionName: versionName,
      versionCode: versionCode,
      state: state ?? this.state,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
    );
  }
}

class DownloadController extends StateNotifier<Map<String, DownloadJob>> {
  DownloadController(this._downloadService, this._installerService)
      : super(const {});

  final DownloadService _downloadService;
  final InstallerService _installerService;
  final Set<String> _activeReleaseIds = <String>{};

  DownloadJob? jobForRelease(String releaseId) => state[releaseId];

  Future<void> startDownload(MobileApp app, AppRelease release) async {
    if (_activeReleaseIds.contains(release.id)) return;

    final existing = state[release.id];
    if (existing?.state == DownloadJobState.readyToInstall &&
        existing?.filePath != null &&
        await File(existing!.filePath!).exists()) {
      return;
    }

    final job = DownloadJob(
      releaseId: release.id,
      appId: app.id,
      appName: app.name,
      packageName: app.packageName,
      versionName: release.versionName,
      versionCode: release.versionCode,
      state: DownloadJobState.queued,
      totalBytes: release.apkSizeBytes,
    );
    _setJob(job);
    _activeReleaseIds.add(release.id);

    try {
      final result = await _downloadService.downloadRelease(
        release,
        appName: app.name,
        onReceiveProgress: (receivedBytes, totalBytes) {
          final current = state[release.id] ?? job;
          _setJob(
            current.copyWith(
              state: DownloadJobState.running,
              receivedBytes: receivedBytes,
              totalBytes: totalBytes > 0 ? totalBytes : release.apkSizeBytes,
              clearError: true,
            ),
          );
        },
      );

      final current = state[release.id] ?? job;
      _setJob(current.copyWith(state: DownloadJobState.verifying));

      if (!result.verified) {
        _setJob(
          current.copyWith(
            state: DownloadJobState.failed,
            errorMessage: 'Verifikasi APK gagal.',
          ),
        );
        return;
      }

      _setJob(
        current.copyWith(
          state: DownloadJobState.readyToInstall,
          receivedBytes: release.apkSizeBytes,
          totalBytes: release.apkSizeBytes,
          filePath: result.file.path,
          clearError: true,
        ),
      );
    } catch (error) {
      final current = state[release.id] ?? job;
      _setJob(
        current.copyWith(
          state: DownloadJobState.failed,
          errorMessage: '$error',
        ),
      );
    } finally {
      _activeReleaseIds.remove(release.id);
    }
  }

  Future<bool> openInstaller(String releaseId) async {
    final job = state[releaseId];
    final filePath = job?.filePath;
    if (job == null || filePath == null) return false;

    _setJob(job.copyWith(state: DownloadJobState.installing));
    final opened = await _installerService.openApkInstaller(filePath);
    _setJob(job.copyWith(state: DownloadJobState.readyToInstall));
    return opened;
  }

  Future<void> restoreLatestDownload(MobileApp app) async {
    final release = app.latestRelease;
    if (release == null) return;
    if (state.containsKey(release.id)) return;

    final nativeStatus = await _downloadService.findDownload(release.id);
    if (nativeStatus == null) return;

    final totalBytes = nativeStatus.totalBytes > 0
        ? nativeStatus.totalBytes
        : release.apkSizeBytes;
    final mappedState = switch (nativeStatus.status) {
      'pending' => DownloadJobState.queued,
      'running' => DownloadJobState.running,
      'paused' => DownloadJobState.paused,
      'successful' => DownloadJobState.readyToInstall,
      'failed' => DownloadJobState.failed,
      _ => DownloadJobState.failed,
    };

    _setJob(
      DownloadJob(
        releaseId: release.id,
        appId: app.id,
        appName: app.name,
        packageName: app.packageName,
        versionName: release.versionName,
        versionCode: release.versionCode,
        state: mappedState,
        receivedBytes: nativeStatus.receivedBytes,
        totalBytes: totalBytes,
        filePath: nativeStatus.filePath,
        errorMessage: mappedState == DownloadJobState.failed
            ? 'Download gagal di Android Download Manager.'
            : null,
      ),
    );
  }

  void clear(String releaseId) {
    final next = Map<String, DownloadJob>.of(state)..remove(releaseId);
    state = next;
  }

  void _setJob(DownloadJob job) {
    state = {
      ...state,
      job.releaseId: job,
    };
  }
}
