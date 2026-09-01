import 'app_release.dart';

class MobileApp {
  const MobileApp({
    required this.id,
    required this.name,
    required this.packageName,
    this.description,
    this.iconUrl,
    this.latestRelease,
  });

  final String id;
  final String name;
  final String packageName;
  final String? description;
  final String? iconUrl;
  final AppRelease? latestRelease;

  factory MobileApp.fromJson(Map<String, dynamic> json) {
    final latestReleaseJson = json['latestRelease'];
    final latest = latestReleaseJson is Map<String, dynamic>
        ? AppRelease.fromJson(latestReleaseJson)
        : null;

    return MobileApp(
      id: json['id'] as String,
      name: json['name'] as String,
      packageName: json['packageName'] as String,
      description: json['description'] as String?,
      iconUrl: json['iconUrl'] as String?,
      latestRelease: latest,
    );
  }
}
