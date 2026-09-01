import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/download_service.dart';
import '../installer/installer_service.dart';
import 'install_status.dart';
import 'models/app_release.dart';
import 'models/mobile_app.dart';

class AppDetailPage extends ConsumerStatefulWidget {
  const AppDetailPage({required this.app, super.key});

  final MobileApp app;

  @override
  ConsumerState<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends ConsumerState<AppDetailPage> {
  InstallStatus _status = const InstallStatus(state: InstallState.checking);
  bool _downloading = false;
  int _progress = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInstallStatus);
  }

  Future<void> _loadInstallStatus() async {
    final release = widget.app.latestRelease;
    final installedVersion = await ref
        .read(installerServiceProvider)
        .getInstalledVersionCode(widget.app.packageName);

    if (!mounted) return;

    if (installedVersion == null) {
      setState(() {
        _status = const InstallStatus(state: InstallState.notInstalled);
      });
      return;
    }

    if (release == null || installedVersion == release.versionCode) {
      setState(() {
        _status = InstallStatus(
          state: InstallState.installed,
          installedVersionCode: installedVersion,
        );
      });
      return;
    }

    setState(() {
      _status = InstallStatus(
        state: installedVersion < release.versionCode
            ? InstallState.updateAvailable
            : InstallState.downgradeBlocked,
        installedVersionCode: installedVersion,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final release = app.latestRelease;

    return Scaffold(
      appBar: AppBar(title: Text(app.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.packageName, style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 16),
                  if (release == null)
                    const Text('Belum ada release.')
                  else ...[
                    Text(
                      'Version ${release.versionName} (${release.versionCode})',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    _InstallStatusChip(status: _status),
                    const SizedBox(height: 8),
                    Text(
                      release.changelog?.isNotEmpty == true
                          ? release.changelog!
                          : 'Tidak ada changelog.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.download),
                      label: Text(
                        _downloading ? 'Downloading $_progress%' : 'Download APK',
                      ),
                      onPressed: _downloading ||
                              _status.state == InstallState.downgradeBlocked
                          ? null
                          : () => _downloadAndOpenInstaller(release),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadAndOpenInstaller(AppRelease release) async {
    final messenger = ScaffoldMessenger.of(context);
    final installer = ref.read(installerServiceProvider);
    final canInstall = await installer.canRequestPackageInstalls();

    if (!mounted) return;

    if (!canInstall) {
      await installer.openInstallPermissionSettings();
      messenger.showSnackBar(
        const SnackBar(content: Text('Aktifkan izin install app.')),
      );
      return;
    }

    setState(() {
      _downloading = true;
      _progress = 0;
    });

    try {
      final result = await ref.read(downloadServiceProvider).downloadRelease(
            release,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
          );

      if (!mounted) return;

      if (!result.verified) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Verifikasi APK gagal.')),
        );
        return;
      }

      await installer.openApkInstaller(result.file.path);
      messenger.showSnackBar(
        const SnackBar(content: Text('Installer Android dibuka.')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _downloading = false;
        });
      }
    }
  }
}

class _InstallStatusChip extends StatelessWidget {
  const _InstallStatusChip({required this.status});

  final InstallStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status.state) {
      InstallState.checking => 'Checking',
      InstallState.notInstalled => 'Not installed',
      InstallState.installed => 'Installed',
      InstallState.updateAvailable => 'Update available',
      InstallState.downgradeBlocked => 'Downgrade blocked',
    };

    final color = switch (status.state) {
      InstallState.updateAvailable => Colors.blue,
      InstallState.installed => Colors.green,
      InstallState.downgradeBlocked => Colors.red,
      _ => Theme.of(context).colorScheme.outline,
    };

    return Chip(
      label: Text(
        status.installedVersionCode == null
            ? label
            : '$label - ${status.installedVersionCode}',
      ),
      side: BorderSide(color: color),
    );
  }
}
