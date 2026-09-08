import 'models/app_release.dart';

enum InstallState {
  checking,
  notInstalled,
  installed,
  updateAvailable,
  downgradeBlocked,
}

class InstallStatus {
  const InstallStatus({
    required this.state,
    this.installedVersionCode,
  });

  final InstallState state;
  final int? installedVersionCode;
}

InstallStatus resolveInstallStatus({
  required int? installedVersionCode,
  required AppRelease? latestRelease,
}) {
  if (installedVersionCode == null) {
    return const InstallStatus(state: InstallState.notInstalled);
  }

  if (latestRelease == null ||
      installedVersionCode == latestRelease.versionCode) {
    return InstallStatus(
      state: InstallState.installed,
      installedVersionCode: installedVersionCode,
    );
  }

  return InstallStatus(
    state: installedVersionCode < latestRelease.versionCode
        ? InstallState.updateAvailable
        : InstallState.downgradeBlocked,
    installedVersionCode: installedVersionCode,
  );
}
