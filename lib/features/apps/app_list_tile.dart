import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../installer/installer_service.dart';
import 'app_detail_page.dart';
import 'install_status.dart';
import 'models/mobile_app.dart';

class AppListTile extends ConsumerStatefulWidget {
  const AppListTile({required this.app, super.key});

  final MobileApp app;

  @override
  ConsumerState<AppListTile> createState() => _AppListTileState();
}

class _AppListTileState extends ConsumerState<AppListTile> {
  InstallStatus _status = const InstallStatus(state: InstallState.checking);

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadStatus);
  }

  @override
  void didUpdateWidget(covariant AppListTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldReleaseCode = oldWidget.app.latestRelease?.versionCode;
    final nextReleaseCode = widget.app.latestRelease?.versionCode;

    if (oldWidget.app.packageName != widget.app.packageName ||
        oldReleaseCode != nextReleaseCode) {
      _loadStatus();
    }
  }

  Future<void> _loadStatus() async {
    final release = widget.app.latestRelease;
    final installedVersion = await ref
        .read(installerServiceProvider)
        .getInstalledVersionCode(widget.app.packageName);

    if (!mounted) return;

    setState(() {
      if (installedVersion == null) {
        _status = const InstallStatus(state: InstallState.notInstalled);
      } else if (release == null || installedVersion == release.versionCode) {
        _status = InstallStatus(
          state: InstallState.installed,
          installedVersionCode: installedVersion,
        );
      } else {
        _status = InstallStatus(
          state: installedVersion < release.versionCode
              ? InstallState.updateAvailable
              : InstallState.downgradeBlocked,
          installedVersionCode: installedVersion,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final release = app.latestRelease;

    return Card(
      child: ListTile(
        leading: const Icon(Icons.android),
        title: Text(app.name),
        subtitle: Text(
          release == null ? app.packageName : '${app.packageName} - v${release.versionName}',
        ),
        trailing: Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            _StatusChip(status: _status),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppDetailPage(app: app),
            ),
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final InstallStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status.state) {
      InstallState.checking => 'Checking',
      InstallState.notInstalled => 'New',
      InstallState.installed => 'Installed',
      InstallState.updateAvailable => 'Update',
      InstallState.downgradeBlocked => 'Blocked',
    };

    final color = switch (status.state) {
      InstallState.updateAvailable => Theme.of(context).colorScheme.primary,
      InstallState.installed => Colors.green,
      InstallState.downgradeBlocked => Colors.red,
      _ => Theme.of(context).colorScheme.outline,
    };

    return Chip(
      label: Text(label),
      side: BorderSide(color: color),
      visualDensity: VisualDensity.compact,
    );
  }
}
