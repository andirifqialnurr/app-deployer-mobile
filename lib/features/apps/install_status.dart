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
