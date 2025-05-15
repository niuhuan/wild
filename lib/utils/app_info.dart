import 'package:package_info_plus/package_info_plus.dart';

class AppInfo {
  static PackageInfo? _packageInfo;
  static String? _version;
  static String? _buildNumber;

  static Future<void> init() async {
    _packageInfo = await PackageInfo.fromPlatform();
    _version = _packageInfo?.version;
    _buildNumber = _packageInfo?.buildNumber;
  }

  /// 获取应用版本号 (例如: 1.0.0)
  static String get version => _version ?? '';

  /// 获取构建号 (例如: 1)
  static String get buildNumber => _buildNumber ?? '';

  /// 获取完整版本号 (例如: 1.0.0+1)
  static String get fullVersion => '$_version+$_buildNumber';

  /// 获取应用名称
  static String get appName => _packageInfo?.appName ?? '';

  /// 获取应用包名
  static String get packageName => _packageInfo?.packageName ?? '';
} 