import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../downloads/download_service.dart';
import '../installer/installer_service.dart';
import 'models/mobile_app.dart';

class AppDetailPage extends ConsumerWidget {
  const AppDetailPage({required this.app, super.key});

  final MobileApp app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                    Text(
                      release.changelog?.isNotEmpty == true
                          ? release.changelog!
                          : 'Tidak ada changelog.',
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.download),
                      label: const Text('Download APK'),
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final file = await ref
                            .read(downloadServiceProvider)
                            .downloadRelease(release);
                        await ref.read(installerServiceProvider).openApkInstaller(file.path);
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Installer Android dibuka.')),
                        );
                      },
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
}
