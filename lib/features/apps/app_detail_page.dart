import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/download_controller.dart';
import '../installer/installer_service.dart';
import 'apps_repository.dart';
import 'install_status.dart';
import 'models/app_release.dart';
import 'models/mobile_app.dart';

class AppDetailPage extends ConsumerStatefulWidget {
  const AppDetailPage({required this.app, super.key});

  final MobileApp app;

  @override
  ConsumerState<AppDetailPage> createState() => _AppDetailPageState();
}

class _AppDetailPageState extends ConsumerState<AppDetailPage>
    with WidgetsBindingObserver {
  InstallStatus _status = const InstallStatus(state: InstallState.checking);
  final Set<String> _installerOpenedForReleaseIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await _loadInstallStatus();
      await _restoreDownloadState();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(appRevisionsProvider(widget.app.id));
      unawaited(_loadInstallStatus());
      unawaited(_restoreDownloadState());
    }
  }

  Future<void> _restoreDownloadState() async {
    await ref.read(downloadControllerProvider.notifier).restoreLatestDownload(
          widget.app,
        );
  }

  Future<void> _loadInstallStatus() async {
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
    final revisionsAsync = ref.watch(appRevisionsProvider(app.id));

    ref.listen(downloadControllerProvider, _handleDownloadJobs);

    return Scaffold(
      appBar: AppBar(title: Text(app.name)),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(appRevisionsProvider(app.id));
          await _loadInstallStatus();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context, app, release),
            const SizedBox(height: 16),
            _buildReplayButton(),
            const SizedBox(height: 24),
            _buildActionList(revisionsAsync),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    MobileApp app,
    AppRelease? release,
  ) {
    final textTheme = Theme.of(context).textTheme;
    final job = release == null
        ? null
        : ref.watch(
            downloadControllerProvider.select((jobs) => jobs[release.id]),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              clipBehavior: Clip.antiAlias,
              child: app.iconUrl?.isNotEmpty == true
                  ? Image.network(
                      app.iconUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) {
                        return const Icon(Icons.android, size: 36);
                      },
                    )
                  : const Icon(Icons.android, size: 36),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(app.name, style: textTheme.titleLarge),
                  const SizedBox(height: 4),
                  Text(app.packageName, style: textTheme.bodyMedium),
                  if (release != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${release.versionName} (${release.versionCode})',
                      style: textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_formatBytes(release.apkSizeBytes)} - Uploaded from web.',
                      style: textTheme.bodySmall,
                    ),
                  ],
                  const SizedBox(height: 8),
                  _InstallStatusChip(status: _status),
                ],
              ),
            ),
          ],
        ),
        if (app.description?.isNotEmpty == true) ...[
          const SizedBox(height: 16),
          Text(app.description!),
        ],
        if (release != null) ...[
          const SizedBox(height: 16),
          Text(
            release.changelog?.isNotEmpty == true
                ? release.changelog!
                : 'Tidak ada changelog.',
          ),
        ],
        const SizedBox(height: 16),
        _buildPrimaryButtons(release, job),
        if (job?.isActive == true || job?.state == DownloadJobState.readyToInstall) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: job!.progressPercent > 0 ? job.progressPercent / 100 : null,
          ),
          const SizedBox(height: 8),
          Text(_downloadStatusText(job)),
        ],
      ],
    );
  }

  Widget _buildPrimaryButtons(AppRelease? release, DownloadJob? job) {
    final installed = _status.installedVersionCode != null;
    final hasActiveJob = job?.isActive == true;
    final canDownload = release != null &&
        _status.state != InstallState.downgradeBlocked &&
        !hasActiveJob;
    final readyToInstall = job?.state == DownloadJobState.readyToInstall &&
        job?.filePath != null;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: Icon(installed ? Icons.open_in_new : Icons.download),
                label: Text(
                  installed ? 'Open' : _downloadButtonLabel(release, job),
                ),
                onPressed: installed
                    ? _openInstalledApp
                    : readyToInstall
                        ? () => _openDownloadedInstaller(release!.id)
                        : canDownload
                        ? () => _downloadAndOpenInstaller(release)
                        : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                icon: const Icon(Icons.delete_outline),
                label: const Text('Uninstall'),
                onPressed: installed ? _requestUninstall : null,
              ),
            ),
          ],
        ),
        if (installed &&
            _status.state == InstallState.updateAvailable &&
            release != null) ...[
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.system_update_alt),
              label: Text(_downloadButtonLabel(release, job)),
              onPressed: readyToInstall
                  ? () => _openDownloadedInstaller(release.id)
                  : canDownload
                      ? () => _downloadAndOpenInstaller(release)
                      : null,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReplayButton() {
    return FilledButton.icon(
      icon: const Icon(Icons.videocam_outlined),
      label: const Text('Start Replay Capture'),
      style: FilledButton.styleFrom(
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
      ),
      onPressed: () => _showComingSoon('Start Replay Capture'),
    );
  }

  Widget _buildActionList(AsyncValue<List<AppRelease>> revisionsAsync) {
    return Column(
      children: [
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('Open App Info'),
          onTap: _status.installedVersionCode == null ? null : _openAppInfo,
        ),
        const Divider(height: 1),
        ListTile(
          leading: const Icon(Icons.group_outlined),
          title: const Text('Distributions'),
          onTap: () => _showComingSoon('Distributions'),
        ),
        const Divider(height: 1),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          leading: const Icon(Icons.history),
          title: const Text('Revisions'),
          children: revisionsAsync.when(
            data: _buildRevisionTiles,
            error: (error, _) => [
              ListTile(
                title: const Text('Gagal memuat revisions'),
                subtitle: Text('$error'),
              ),
            ],
            loading: () => const [
              ListTile(title: LinearProgressIndicator()),
            ],
          ),
        ),
        const Divider(height: 1),
      ],
    );
  }

  List<Widget> _buildRevisionTiles(List<AppRelease> releases) {
    if (releases.isEmpty) {
      return const [
        ListTile(title: Text('Belum ada revision.')),
      ];
    }

    return releases.map((release) {
      final job = ref.watch(
        downloadControllerProvider.select((jobs) => jobs[release.id]),
      );
      final installedCode = _status.installedVersionCode;
      final isInstalled = installedCode == release.versionCode;
      final isLatest = widget.app.latestRelease?.id == release.id;
      final isDowngrade = installedCode != null &&
          release.versionCode < installedCode &&
          !isInstalled;
      final isActiveDownload = job?.isActive == true;
      final readyToInstall = job?.state == DownloadJobState.readyToInstall &&
          job?.filePath != null;
      final badges = [
        if (isLatest) 'Latest',
        if (isInstalled) 'Installed',
        if (isDowngrade) 'Downgrade blocked',
      ];

      return ListTile(
        contentPadding: EdgeInsets.zero,
        isThreeLine: release.changelog?.isNotEmpty == true,
        title: Text('${release.versionName} (${release.versionCode})'),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              [
                release.channel,
                _formatDate(release.createdAt),
                _formatBytes(release.apkSizeBytes),
              ].join(' - '),
            ),
            if (badges.isNotEmpty) Text(badges.join(' - ')),
            if (release.changelog?.isNotEmpty == true)
              Text(
                release.changelog!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        trailing: TextButton(
          onPressed: isInstalled || isDowngrade || isActiveDownload
              ? null
              : readyToInstall
                  ? () => _openDownloadedInstaller(release.id)
                  : () => _downloadAndOpenInstaller(release),
          child: Text(
            isActiveDownload
                ? '${job!.progressPercent}%'
                : readyToInstall
                    ? 'Install'
                    : 'Download',
          ),
        ),
      );
    }).toList(growable: false);
  }

  String _downloadButtonLabel(AppRelease? release, DownloadJob? job) {
    if (release != null && job?.isActive == true) {
      return 'Downloading ${job!.progressPercent}%';
    }

    if (job?.state == DownloadJobState.readyToInstall) {
      return 'Install';
    }

    return switch (_status.state) {
      InstallState.updateAvailable => 'Update',
      InstallState.notInstalled => 'Install',
      InstallState.checking => 'Checking',
      InstallState.installed => 'Open',
      InstallState.downgradeBlocked => 'Blocked',
    };
  }

  String _downloadStatusText(DownloadJob job) {
    if (job.state == DownloadJobState.readyToInstall) {
      return 'Download complete. Ready to install.';
    }

    if (job.state == DownloadJobState.verifying) {
      return 'Verifying APK...';
    }

    final total = job.totalBytes;
    if (total <= 0) {
      return 'Downloading...';
    }

    return 'Downloading ${_formatBytes(job.receivedBytes)} of ${_formatBytes(total)}';
  }

  Future<void> _downloadAndOpenInstaller(AppRelease release) async {
    final messenger = ScaffoldMessenger.of(context);
    final installer = ref.read(installerServiceProvider);
    if (!await installer.canPostNotifications()) {
      await installer.requestPostNotifications();
    }

    final canInstall = await installer.canRequestPackageInstalls();

    if (!mounted) return;

    if (!canInstall) {
      await installer.openInstallPermissionSettings();
      messenger.showSnackBar(
        const SnackBar(content: Text('Aktifkan izin install app.')),
      );
      return;
    }

    await ref.read(downloadControllerProvider.notifier).startDownload(
          widget.app,
          release,
        );
  }

  Future<void> _openDownloadedInstaller(String releaseId) async {
    final opened = await ref
        .read(downloadControllerProvider.notifier)
        .openInstaller(releaseId);
    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Installer Android tidak bisa dibuka.')),
    );
  }

  void _handleDownloadJobs(
    Map<String, DownloadJob>? previous,
    Map<String, DownloadJob> next,
  ) {
    for (final job in next.values) {
      if (job.appId != widget.app.id) continue;

      final previousJob = previous?[job.releaseId];
      if (previousJob?.state == job.state) continue;

      if (job.state == DownloadJobState.failed) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download gagal: ${job.errorMessage}')),
        );
        continue;
      }

      if (job.state != DownloadJobState.readyToInstall) continue;
      if (_installerOpenedForReleaseIds.contains(job.releaseId)) continue;

      _installerOpenedForReleaseIds.add(job.releaseId);
      unawaited(_openDownloadedInstaller(job.releaseId));
    }
  }

  Future<void> _openInstalledApp() async {
    final opened = await ref
        .read(installerServiceProvider)
        .openInstalledApp(widget.app.packageName);

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App tidak bisa dibuka.')),
    );
  }

  Future<void> _openAppInfo() async {
    final opened = await ref
        .read(installerServiceProvider)
        .openAppInfo(widget.app.packageName);

    if (!mounted || opened) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('App info tidak bisa dibuka.')),
    );
  }

  Future<void> _requestUninstall() async {
    final opened = await ref
        .read(installerServiceProvider)
        .requestUninstall(widget.app.packageName);

    if (!mounted) return;

    if (opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi uninstall dibuka.')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Dialog uninstall tidak bisa dibuka.')),
    );
  }

  void _showComingSoon(String feature) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(feature),
        content: const Text('Coming soon.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final local = date.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatBytes(int bytes) {
    const units = ['B', 'KB', 'MB', 'GB'];
    var size = bytes.toDouble();
    var unitIndex = 0;

    while (size >= 1024 && unitIndex < units.length - 1) {
      size /= 1024;
      unitIndex += 1;
    }

    if (unitIndex == 0) {
      return '${size.round()} ${units[unitIndex]}';
    }

    return '${size.toStringAsFixed(1)} ${units[unitIndex]}';
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
