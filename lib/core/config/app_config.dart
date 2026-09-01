import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AppConfig {
  const AppConfig({
    required this.apiBaseUrl,
    required this.apiToken,
    required this.defaultChannel,
  });

  final String apiBaseUrl;
  final String apiToken;
  final String defaultChannel;
}

final appConfigProvider = Provider<AppConfig>((ref) {
  return AppConfig(
    apiBaseUrl: dotenv.env['API_BASE_URL'] ?? 'http://10.0.2.2:3000',
    apiToken: dotenv.env['API_TOKEN'] ?? '',
    defaultChannel: dotenv.env['DEFAULT_CHANNEL'] ?? 'STABLE',
  );
});
