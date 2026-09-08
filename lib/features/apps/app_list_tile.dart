import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/download_controller.dart';
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
    Future.microtask(() async {
      await _loadStatus();
      await ref.read(downloadControllerProvider.notifier).restoreLatestDownload(
            widget.app,
          );
    });
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
      _status = resolveInstallStatus(
        installedVersionCode: installedVersion,
        latestRelease: release,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.app;
    final release = app.latestRelease;
    final downloadJob = release == null
        ? null
        : ref.watch(
            downloadControllerProvider.select((jobs) => jobs[release.id]),
          );

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
            if (downloadJob != null) _DownloadStatusChip(job: downloadJob),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AppDetailPage(app: app),
            ),
          );
          await _loadStatus();
        },
      ),
    );
  }
}

class _DownloadStatusChip extends StatelessWidget {
  const _DownloadStatusChip({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return switch (job.state) {
      DownloadJobState.queued ||
      DownloadJobState.running ||
      DownloadJobState.paused ||
      DownloadJobState.verifying ||
      DownloadJobState.installing =>
        SizedBox(
          width: 44,
          height: 44,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: job.progressPercent > 0 ? job.progressPercent / 100 : null,
                strokeWidth: 3,
              ),
              Text(
                '${job.progressPercent}%',
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      DownloadJobState.readyToInstall => Chip(
          avatar: const Icon(Icons.done, size: 16),
          label: const Text('Downloaded'),
          side: BorderSide(color: colorScheme.primary),
          visualDensity: VisualDensity.compact,
        ),
      DownloadJobState.cancelled => Chip(
          avatar: const Icon(Icons.cancel_outlined, size: 16),
          label: const Text('Cancelled'),
          side: BorderSide(color: colorScheme.outline),
          visualDensity: VisualDensity.compact,
        ),
      DownloadJobState.failed => const Chip(
          avatar: Icon(Icons.error_outline, size: 16),
          label: Text('Failed'),
          side: BorderSide(color: Colors.red),
          visualDensity: VisualDensity.compact,
        ),
    };
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
