import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'download_controller.dart';

class DownloadsPage extends ConsumerWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(downloadControllerProvider).values.toList()
      ..sort((a, b) => a.appName.compareTo(b.appName));

    return Scaffold(
      appBar: AppBar(title: const Text('Downloads')),
      body: jobs.isEmpty
          ? const Center(child: Text('Belum ada download.'))
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final job = jobs[index];
                return Card(
                  child: ListTile(
                    leading: _DownloadIcon(job: job),
                    title: Text(job.appName),
                    subtitle: Text(
                      [
                        '${job.versionName} (${job.versionCode})',
                        _jobLabel(job),
                        if (job.totalBytes > 0)
                          '${_formatBytes(job.receivedBytes)} / ${_formatBytes(job.totalBytes)}',
                      ].join(' - '),
                    ),
                    trailing: _DownloadAction(job: job),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: jobs.length,
            ),
    );
  }
}

class _DownloadIcon extends StatelessWidget {
  const _DownloadIcon({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context) {
    if (job.state == DownloadJobState.readyToInstall) {
      return const Icon(Icons.download_done);
    }

    if (job.state == DownloadJobState.cancelled) {
      return const Icon(Icons.cancel_outlined);
    }

    if (job.state == DownloadJobState.failed) {
      return const Icon(Icons.error_outline, color: Colors.red);
    }

    return SizedBox(
      width: 40,
      height: 40,
      child: CircularProgressIndicator(
        value: job.progressPercent > 0 ? job.progressPercent / 100 : null,
        strokeWidth: 3,
      ),
    );
  }
}

class _DownloadAction extends ConsumerWidget {
  const _DownloadAction({required this.job});

  final DownloadJob job;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (job.state == DownloadJobState.readyToInstall) {
      return TextButton(
        onPressed: () async {
          final opened = await ref
              .read(downloadControllerProvider.notifier)
              .openInstaller(job.releaseId);
          if (!context.mounted || opened) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Installer Android tidak bisa dibuka.')),
          );
        },
        child: const Text('Install'),
      );
    }

    if (job.isActive) {
      return IconButton(
        tooltip: 'Cancel download',
        onPressed: () {
          ref.read(downloadControllerProvider.notifier).cancelDownload(job.releaseId);
        },
        icon: const Icon(Icons.close),
      );
    }

    if (job.state == DownloadJobState.failed ||
        job.state == DownloadJobState.cancelled) {
      return IconButton(
        tooltip: 'Clear',
        onPressed: () {
          ref.read(downloadControllerProvider.notifier).clear(job.releaseId);
        },
        icon: const Icon(Icons.close),
      );
    }

    return Text('${job.progressPercent}%');
  }
}

String _jobLabel(DownloadJob job) {
  return switch (job.state) {
    DownloadJobState.queued => 'Queued',
    DownloadJobState.running => 'Downloading',
    DownloadJobState.paused => 'Paused',
    DownloadJobState.verifying => 'Verifying',
    DownloadJobState.readyToInstall => 'Ready to install',
    DownloadJobState.installing => 'Opening installer',
    DownloadJobState.cancelled => 'Cancelled',
    DownloadJobState.failed => job.errorMessage ?? 'Failed',
  };
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
