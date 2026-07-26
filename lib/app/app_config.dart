import 'package:package_info_plus/package_info_plus.dart';

class AppConfig {
  /// Reads the version embedded in the installed APK, not a manually copied
  /// value in source code.
  static Future<String> get appVersion async {
    final PackageInfo packageInfo = await PackageInfo.fromPlatform();
    return packageInfo.version;
  }

  static Future<String> get fullVersion async => 'v${await appVersion}';
}
