import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_list_tile.dart';
import 'apps_repository.dart';

class AppsPage extends ConsumerStatefulWidget {
  const AppsPage({super.key});

  @override
  ConsumerState<AppsPage> createState() => _AppsPageState();
}

class _AppsPageState extends ConsumerState<AppsPage> with WidgetsBindingObserver {
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      ref.invalidate(appsProvider);
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(appsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appsAsync = ref.watch(appsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Apps')),
      body: appsAsync.when(
        data: (apps) {
          if (apps.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async => ref.refresh(appsProvider.future),
              child: ListView(
                children: const [
                  SizedBox(height: 240),
                  Center(child: Text('Belum ada app.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () async => ref.refresh(appsProvider.future),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final app = apps[index];
                return AppListTile(app: app);
              },
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemCount: apps.length,
            ),
          );
        },
        error: (error, _) => RefreshIndicator(
          onRefresh: () async => ref.refresh(appsProvider.future),
          child: ListView(
            children: [
              const SizedBox(height: 240),
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Gagal memuat app: $error'),
                ),
              ),
            ],
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
