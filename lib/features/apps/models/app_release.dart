class AppRelease {
  const AppRelease({
    required this.id,
    required this.versionName,
    required this.versionCode,
    required this.channel,
    required this.apkObjectKey,
    required this.apkSizeBytes,
    required this.apkSha256,
    this.changelog,
  });

  final String id;
  final String versionName;
  final int versionCode;
  final String channel;
  final String apkObjectKey;
  final int apkSizeBytes;
  final String apkSha256;
  final String? changelog;

  factory AppRelease.fromJson(Map<String, dynamic> json) {
    return AppRelease(
      id: json['id'] as String,
      versionName: json['versionName'] as String,
      versionCode: json['versionCode'] as int,
      channel: json['channel'] as String,
      apkObjectKey: json['apkObjectKey'] as String,
      apkSizeBytes: int.parse(json['apkSizeBytes'].toString()),
      apkSha256: json['apkSha256'] as String,
      changelog: json['changelog'] as String?,
    );
  }
}
