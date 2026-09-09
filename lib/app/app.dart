import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/apps/app_detail_page.dart';
import '../features/apps/apps_page.dart';
import '../features/apps/apps_repository.dart';
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

  static const _pages = [
    AppsPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      unawaited(_openPendingDownloadLaunch());
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(downloadControllerProvider, _handleDownloadJobs);

    return Scaffold(
      body: _pages[_index],
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

  Future<void> _openPendingDownloadLaunch() async {
    final launch = await ref
        .read(downloadControllerProvider.notifier)
        .consumePendingLaunch();
    if (!mounted || launch == null) return;

    await _openAppDetail(launch.appId, launch.releaseId);
  }

  Future<void> _openAppDetail(String? appId, String releaseId) async {
    final apps = await ref.read(appsProvider.future);
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
