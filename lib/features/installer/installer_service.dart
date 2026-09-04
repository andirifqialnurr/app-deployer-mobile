import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final installerServiceProvider = Provider<InstallerService>((ref) {
  return const InstallerService();
});

class InstallerService {
  const InstallerService();

  static const _channel = MethodChannel('app_deployer/installer');

  Future<int?> getInstalledVersionCode(String packageName) {
    return _channel.invokeMethod<int>('getInstalledVersionCode', {
      'packageName': packageName,
    });
  }

  Future<void> openApkInstaller(String filePath) {
    return _channel.invokeMethod<void>('openApkInstaller', {
      'filePath': filePath,
    });
  }

  Future<bool> openInstalledApp(String packageName) async {
    return await _channel.invokeMethod<bool>('openInstalledApp', {
          'packageName': packageName,
        }) ??
        false;
  }

  Future<bool> openAppInfo(String packageName) async {
    return await _channel.invokeMethod<bool>('openAppInfo', {
          'packageName': packageName,
        }) ??
        false;
  }

  Future<bool> requestUninstall(String packageName) async {
    return await _channel.invokeMethod<bool>('requestUninstall', {
          'packageName': packageName,
        }) ??
        false;
  }

  Future<bool> canRequestPackageInstalls() async {
    return await _channel.invokeMethod<bool>('canRequestPackageInstalls') ?? false;
  }

  Future<void> openInstallPermissionSettings() {
    return _channel.invokeMethod<void>('openInstallPermissionSettings');
  }
}
