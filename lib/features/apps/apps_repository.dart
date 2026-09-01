import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import 'models/mobile_app.dart';

final appsRepositoryProvider = Provider<AppsRepository>((ref) {
  return AppsRepository(ref.watch(dioProvider));
});

final appsProvider = FutureProvider<List<MobileApp>>((ref) {
  return ref.watch(appsRepositoryProvider).listApps();
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
}
