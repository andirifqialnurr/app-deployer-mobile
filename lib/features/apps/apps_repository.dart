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
    final response = await _dio.get('/api/trpc/apps.list');
    final json = response.data as Map<String, dynamic>;
    final result = _unwrapTrpcData(json);
    final items = result is List ? result : <dynamic>[];
    return items
        .whereType<Map<String, dynamic>>()
        .map(MobileApp.fromJson)
        .toList(growable: false);
  }

  Object? _unwrapTrpcData(Map<String, dynamic> json) {
    final result = json['result'];
    if (result is! Map<String, dynamic>) {
      return json['data'];
    }

    final data = result['data'];
    if (data is Map<String, dynamic> && data.containsKey('json')) {
      return data['json'];
    }

    return data;
  }
}
