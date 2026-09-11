import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/apps/app_detail_page.dart';
import '../features/apps/apps_page.dart';
import '../features/apps/apps_repository.dart';
import '../features/apps/models/mobile_app.dart';
import '../features/downloads/download_controller.dart';
import '../features/downloads/downloads_page.dart';
import '../features/settings/settings_page.dart';
import '../core/theme/app_theme.dart';

class AppDeployerMobileApp extends StatelessWidget {
  const AppDeployerMobileApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'App Deployer',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const AppShell(),
    );
  }
}

class AppShell extends ConsumerStatefulWidget {
  const AppShell({super.key});

  @override
  ConsumerState<AppShell> createState() => _AppShellState();
}

class _AppShellState extends ConsumerState<AppShell> with WidgetsBindingObserver {
  int _index = 0;
  final Set<String> _installerOpenedForReleaseIds = <String>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(_restoreDownloads);
    Future.microtask(_openPendingDownloadLaunch);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_restoreDownloads());
      unawaited(_openPendingDownloadLaunch());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(downloadControllerProvider, _handleDownloadJobs);

    return Scaffold(
      body: _buildPage(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps),
            label: 'Apps',
          ),
          NavigationDestination(
            icon: Icon(Icons.download_outlined),
            selectedIcon: Icon(Icons.download),
            label: 'Downloads',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildPage() {
    return switch (_index) {
      0 => const AppsPage(),
      1 => DownloadsPage(
          onOpenApp: _openAppDetail,
          onRetryDownload: _retryDownload,
        ),
      _ => const SettingsPage(),
    };
  }

  Future<void> _openPendingDownloadLaunch() async {
    final launch = await ref
        .read(downloadControllerProvider.notifier)
        .consumePendingLaunch();
    if (!mounted || launch == null) return;

    await _openAppDetail(launch.appId, launch.releaseId);
  }

  Future<void> _restoreDownloads() async {
    final apps = await ref.read(appsProvider.future);
    if (!mounted) return;

    await ref.read(downloadControllerProvider.notifier).restoreDownloads(apps);
  }

  Future<void> _openAppDetail(String? appId, String releaseId) async {
    final apps = await (() async {
      try {
        return await ref.read(appsProvider.future);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal membuka detail app: $error')),
          );
        }
        return const [];
      }
    })();
    if (!mounted) return;

    final matchingApps = apps.where((app) {
      return app.id == appId || app.latestRelease?.id == releaseId;
    });
    final app = matchingApps.isEmpty ? null : matchingApps.first;
    if (app == null) return;

    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => AppDetailPage(app: app)),
    );
  }

  Future<void> _retryDownload(DownloadJob job) async {
    final apps = await (() async {
      try {
        return await ref.read(appsProvider.future);
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Gagal retry download: $error')),
          );
        }
        return const [];
      }
    })();
    if (!mounted) return;

    MobileApp? app;
    for (final candidate in apps) {
      if (candidate.id == job.appId ||
          candidate.latestRelease?.id == job.releaseId) {
        app = candidate;
        break;
      }
    }

    final release = app?.latestRelease;
    if (app == null || release == null || release.id != job.releaseId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Buka detail app untuk mencoba download ulang.'),
        ),
      );
      await _openAppDetail(job.appId, job.releaseId);
      return;
    }

    await ref.read(downloadControllerProvider.notifier).startDownload(
          app,
          release,
        );
  }

  void _handleDownloadJobs(
    Map<String, DownloadJob>? previous,
    Map<String, DownloadJob> next,
  ) {
    for (final job in next.values) {
      final previousJob = previous?[job.releaseId];
      if (previousJob?.state == job.state) continue;
      if (job.state != DownloadJobState.readyToInstall) continue;
      if (_installerOpenedForReleaseIds.contains(job.releaseId)) continue;

      _installerOpenedForReleaseIds.add(job.releaseId);
      unawaited(
        ref.read(downloadControllerProvider.notifier).openInstaller(job.releaseId),
      );
    }
  }
}
