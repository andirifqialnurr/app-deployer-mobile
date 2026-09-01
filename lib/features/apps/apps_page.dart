import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_detail_page.dart';
import 'apps_repository.dart';

class AppsPage extends ConsumerWidget {
  const AppsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appsAsync = ref.watch(appsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apps')),
      body: appsAsync.when(
        data: (apps) {
          if (apps.isEmpty) {
            return const Center(child: Text('Belum ada app.'));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final app = apps[index];
              final release = app.latestRelease;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.android),
                  title: Text(app.name),
                  subtitle: Text(
                    release == null
                        ? app.packageName
                        : '${app.packageName} - v${release.versionName}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => AppDetailPage(app: app),
                      ),
                    );
                  },
                ),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemCount: apps.length,
          );
        },
        error: (error, _) => Center(child: Text('Gagal memuat app: $error')),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
