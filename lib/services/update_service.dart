import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

class UpdateInfo {
  final String latestVersion;
  final String currentVersion;
  final String releaseName;
  final String releaseNotes;
  final String? apkUrl;
  final String releasePageUrl;

  UpdateInfo({
    required this.latestVersion,
    required this.currentVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.apkUrl,
    required this.releasePageUrl,
  });

  bool get hasUpdate => _isNewer(latestVersion, currentVersion);

  static bool _isNewer(String latest, String current) {
    final l = _parse(latest);
    final c = _parse(current);
    for (int i = 0; i < 3; i++) {
      if (l[i] != c[i]) return l[i] > c[i];
    }
    return false;
  }

  static List<int> _parse(String v) {
    final cleaned = v.replaceFirst(RegExp(r'^v'), '').split('+').first;
    final parts = cleaned.split('.');
    return [
      int.tryParse(parts.elementAtOrNull(0) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(2) ?? '0') ?? 0,
    ];
  }
}

class UpdateService {
  static const _owner = 'leeseyoung77';
  static const _repo = 'lsy-m-lotto';
  static const _apiUrl =
      'https://api.github.com/repos/$_owner/$_repo/releases/latest';

  /// GitHub 최신 릴리스를 조회하고 현재 버전과 비교
  Future<UpdateInfo?> checkForUpdate() async {
    try {
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version; // e.g. 1.0.0

      final response = await http
          .get(
            Uri.parse(_apiUrl),
            headers: {'Accept': 'application/vnd.github+json'},
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return null;

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final tagName = (json['tag_name'] as String?) ?? '';
      final releaseName = (json['name'] as String?) ?? tagName;
      final body = (json['body'] as String?) ?? '';
      final htmlUrl = (json['html_url'] as String?) ?? '';

      String? apkUrl;
      final assets = json['assets'] as List? ?? [];
      for (final asset in assets) {
        final name = (asset['name'] as String?) ?? '';
        if (name.toLowerCase().endsWith('.apk')) {
          apkUrl = asset['browser_download_url'] as String?;
          break;
        }
      }

      return UpdateInfo(
        latestVersion: tagName,
        currentVersion: currentVersion,
        releaseName: releaseName,
        releaseNotes: body,
        apkUrl: apkUrl,
        releasePageUrl: htmlUrl,
      );
    } catch (_) {
      return null;
    }
  }
}
