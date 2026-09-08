import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/apps/apps_page.dart';
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

class _AppShellState extends ConsumerState<AppShell> {
  int _index = 0;
  final Set<String> _installerOpenedForReleaseIds = <String>{};

  static const _pages = [
    AppsPage(),
    DownloadsPage(),
    SettingsPage(),
  ];

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
