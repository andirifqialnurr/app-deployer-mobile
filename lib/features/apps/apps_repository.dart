import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import 'models/app_release.dart';
import 'models/mobile_app.dart';

final appsRepositoryProvider = Provider<AppsRepository>((ref) {
  return AppsRepository(ref.watch(dioProvider));
});

final appsProvider = FutureProvider<List<MobileApp>>((ref) {
  return ref.watch(appsRepositoryProvider).listApps();
});

final appRevisionsProvider = FutureProvider.family<List<AppRelease>, String>((
  ref,
  appId,
) {
  return ref.watch(appsRepositoryProvider).listRevisions(appId);
});

class AppsRepository {
  const AppsRepository(this._dio);

  final Dio _dio;

  Future<List<MobileApp>> listApps() async {
    final response = await _dio.get('/api/apps');
    final json = response.data as Map<String, dynamic>;
    final result = json['apps'];
    final items = result is List ? result : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(MobileApp.fromJson)
        .toList(growable: false);
  }

  Future<List<AppRelease>> listRevisions(String appId) async {
    final response = await _dio.get('/api/apps/$appId/revisions');
    final json = response.data as Map<String, dynamic>;
    final result = json['releases'];
    final items = result is List ? result : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(AppRelease.fromJson)
        .toList(growable: false);
  }
}
