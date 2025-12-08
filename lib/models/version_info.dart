import 'package:cloud_firestore/cloud_firestore.dart';

class VersionInfo {
  final String latestVer;
  final String minSupportedVer;
  final String? downloadUrl;

  VersionInfo({
    required this.latestVer,
    required this.minSupportedVer,
    this.downloadUrl,
  });

  factory VersionInfo.fromJson(Map<String, dynamic> json) {
    return VersionInfo(
      latestVer: json['latestVer'] ?? '0.0.0',
      minSupportedVer: json['minSupportedVer'] ?? '0.0.0',
      downloadUrl: json['downloadUrl'] ?? '',
    );
  }

  // Helper method to get formatted update message in markdown
  String getFormattedMessage() {
    return """
# New Update Available!

A new version ($latestVer) of Revent is now available with improvements and bug fixes.

[Click here to download](${downloadUrl ?? 'https://github.com/E-m-i-n-e-n-c-e/Revent/releases/download/beta1/REvent.v$latestVer-beta.apk'})
""";
  }

  /// Check if current version is below minimum supported version
  bool isForceUpdateRequired(String currentVersion) {
    return _compareVersions(currentVersion, minSupportedVer) < 0;
  }

  /// Check if update is available
  bool isUpdateAvailable(String currentVersion) {
    return _compareVersions(currentVersion, latestVer) < 0;
  }

  /// Compare two version strings
  /// Returns: -1 if v1 < v2, 0 if v1 == v2, 1 if v1 > v2
  int _compareVersions(String v1, String v2) {
    final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
    final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();

    final maxLength = parts1.length > parts2.length ? parts1.length : parts2.length;

    for (int i = 0; i < maxLength; i++) {
      final part1 = i < parts1.length ? parts1[i] : 0;
      final part2 = i < parts2.length ? parts2[i] : 0;

      if (part1 < part2) return -1;
      if (part1 > part2) return 1;
    }

    return 0;
  }

  /// Fetch version info from Firestore
  static Future<VersionInfo> getVersionInfo() async {
    final firebase = FirebaseFirestore.instance;
    final versionRef = firebase.collection('version_info').doc('current');
    final versionDoc = await versionRef.get();

    if (!versionDoc.exists) {
      // Return default if document doesn't exist
      return VersionInfo(
        latestVer: '0.0.0',
        minSupportedVer: '0.0.0',
        downloadUrl: '',
      );
    }

    return VersionInfo.fromJson(versionDoc.data() ?? {});
  }
}
