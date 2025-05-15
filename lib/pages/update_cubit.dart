import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wild/utils/app_info.dart';

// 状态
class UpdateState extends Equatable {
  final VersionInfo? updateInfo;
  final bool hasCheckedOnStartup;

  const UpdateState({
    this.updateInfo,
    this.hasCheckedOnStartup = false,
  });

  @override
  List<Object?> get props => [updateInfo, hasCheckedOnStartup];

  UpdateState copyWith({
    VersionInfo? updateInfo,
    bool? hasCheckedOnStartup,
  }) {
    return UpdateState(
      updateInfo: updateInfo ?? this.updateInfo,
      hasCheckedOnStartup: hasCheckedOnStartup ?? this.hasCheckedOnStartup,
    );
  }
}

// 更新信息
class VersionInfo extends Equatable {
  final String version;
  final String url;
  final String body;

  const VersionInfo({
    required this.version,
    required this.url,
    required this.body,
  });

  @override
  List<Object?> get props => [version, url, body];
}

// Cubit
class UpdateCubit extends Cubit<UpdateState> {
  static const String _owner = 'niuhuan';
  static const String _repo = 'wild';
  static const String _apiUrl = 'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  UpdateCubit() : super(const UpdateState());

  Future<VersionInfo?> checkUpdate({bool force = false}) async {
    // 如果已经检查过且不强制检查，则直接返回当前更新信息
    if (state.hasCheckedOnStartup && !force) {
      if (kDebugMode) {
        print('Update check skipped: already checked on startup');
      }
      return state.updateInfo;
    }

    if (kDebugMode) {
      print('Checking for updates...');
      print('Request URL: $_apiUrl');
      print('User-Agent: Wild/${AppInfo.fullVersion}');
    }

    try {
      final response = await http.get(
        Uri.parse(_apiUrl),
        headers: {
          'User-Agent': 'Wild/${AppInfo.fullVersion}',
        },
      );

      if (kDebugMode) {
        print('Response status code: ${response.statusCode}');
        print('Response headers: ${response.headers}');
        print('Response body: ${response.body}');
      }

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final latestVersion = data['tag_name'] as String;
        final currentInfo = await PackageInfo.fromPlatform();
        final currentVersion = 'v${currentInfo.version}';

        if (kDebugMode) {
          print('Current version: $currentVersion');
          print('Latest version: $latestVersion');
        }

        // 移除 'v' 前缀后比较版本号
        if (_compareVersions(
          latestVersion.substring(1),
          currentVersion.substring(1),
        ) > 0) {
          if (kDebugMode) {
            print('New version available: $latestVersion');
          }
          final info = VersionInfo(
            version: latestVersion,
            url: data['html_url'] as String,
            body: data['body'] as String,
          );
          emit(state.copyWith(
            updateInfo: info,
            hasCheckedOnStartup: true,
          ));
          return info;
        } else {
          if (kDebugMode) {
            print('No new version available');
          }
        }
      } else {
        if (kDebugMode) {
          print('Update check failed: HTTP ${response.statusCode}');
        }
      }
      // 即使没有更新，也标记为已检查
      emit(state.copyWith(hasCheckedOnStartup: true));
    } catch (e) {
      if (kDebugMode) {
        print('Update check failed with error: $e');
      }
    }
    return null;
  }

  // 比较版本号，返回 1 表示有新版本，0 表示相同，-1 表示当前版本更新
  int _compareVersions(String version1, String version2) {
    final v1Parts = version1.split('.').map(int.parse).toList();
    final v2Parts = version2.split('.').map(int.parse).toList();

    for (var i = 0; i < v1Parts.length && i < v2Parts.length; i++) {
      if (v1Parts[i] > v2Parts[i]) return 1;
      if (v1Parts[i] < v2Parts[i]) return -1;
    }

    return v1Parts.length.compareTo(v2Parts.length);
  }
} 