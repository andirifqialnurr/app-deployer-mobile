import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/download_service.dart';
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
  bool _downloading = false;
  int _progress = 0;
  int _receivedBytes = 0;
  int _totalBytes = 0;
  String? _activeReleaseId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_loadInstallStatus);
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
      Future.microtask(_loadInstallStatus);
    }
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
    final revisionsAsync = ref.watch(appRevisionsProvider(app.id));

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
        _buildPrimaryButtons(release),
        if (_downloading) ...[
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: _progress > 0 ? _progress / 100 : null,
          ),
          const SizedBox(height: 8),
          Text(_downloadStatusText),
        ],
      ],
    );
  }

  Widget _buildPrimaryButtons(AppRelease? release) {
    final installed = _status.installedVersionCode != null;
    final canDownload = release != null &&
        _status.state != InstallState.downgradeBlocked &&
        !_downloading;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                icon: Icon(installed ? Icons.open_in_new : Icons.download),
                label: Text(installed ? 'Open' : _downloadButtonLabel(release)),
                onPressed: installed
                    ? _openInstalledApp
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
              label: Text(_downloadButtonLabel(release)),
              onPressed: canDownload ? () => _downloadAndOpenInstaller(release) : null,
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
      final installedCode = _status.installedVersionCode;
      final isInstalled = installedCode == release.versionCode;
      final isLatest = widget.app.latestRelease?.id == release.id;
      final isDowngrade = installedCode != null &&
          release.versionCode < installedCode &&
          !isInstalled;
      final isActiveDownload = _activeReleaseId == release.id && _downloading;
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
          onPressed: isInstalled || isDowngrade || _downloading
              ? null
              : () => _downloadAndOpenInstaller(release),
          child: Text(isActiveDownload ? '$_progress%' : 'Install'),
        ),
      );
    }).toList(growable: false);
  }

  String _downloadButtonLabel(AppRelease? release) {
    if (_downloading && release != null && _activeReleaseId == release.id) {
      return 'Downloading $_progress%';
    }

    return switch (_status.state) {
      InstallState.updateAvailable => 'Update',
      InstallState.notInstalled => 'Install',
      InstallState.checking => 'Checking',
      InstallState.installed => 'Open',
      InstallState.downgradeBlocked => 'Blocked',
    };
  }

  String get _downloadStatusText {
    final total = _totalBytes;
    if (total <= 0) {
      return 'Downloading...';
    }

    return 'Downloading ${_formatBytes(_receivedBytes)} of ${_formatBytes(total)}';
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
      _activeReleaseId = release.id;
      _progress = 0;
      _receivedBytes = 0;
      _totalBytes = 0;
    });

    try {
      final result = await ref.read(downloadServiceProvider).downloadRelease(
            release,
            onProgress: (progress) {
              if (mounted) setState(() => _progress = progress);
            },
            onReceiveProgress: (receivedBytes, totalBytes) {
              if (!mounted) return;
              setState(() {
                _receivedBytes = receivedBytes;
                _totalBytes = totalBytes;
              });
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
          _activeReleaseId = null;
        });
      }
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
