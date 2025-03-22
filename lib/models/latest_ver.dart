import 'package:cloud_firestore/cloud_firestore.dart';

class LatestVer {
  final String version;
  final String? downloadUrl;
  final String? updateMessage;
  final bool isRequired;

  LatestVer(
      {required this.version,
      this.downloadUrl,
      this.updateMessage,
      this.isRequired = false});

  factory LatestVer.fromJson(Map<String, dynamic> json) {
    return LatestVer(
        version: json['version'],
        downloadUrl: json['downloadUrl'],
        updateMessage: json['updateMessage'],
        isRequired: json['isRequired'] ?? false);
  }

  Map<String, dynamic> toJson() {
    return {
      'version': version,
      'downloadUrl': downloadUrl ??
          'https://github.com/E-m-i-n-e-n-c-e/Revent/releases/download/beta1/REvent.v$version-beta.apk',
      'updateMessage': updateMessage,
      'isRequired': isRequired,
    };
  }

  // Helper method to get formatted update message in markdown
  String getFormattedMessage() {
    return updateMessage ?? """
# New Update Available!

A new version ($version) of Revent is now available with improvements and bug fixes.

[Click here to download](${downloadUrl ?? 'https://github.com/E-m-i-n-e-n-c-e/Revent/releases/download/beta1/REvent.v$version-beta.apk'})
""";
  }

  static Future<LatestVer> getLatestVer() async  {
    final firebase = FirebaseFirestore.instance;
    final latestVerRef = firebase.collection('latestVer').doc('pmLcuBjnegy0OuD86xbC');
    final latestVerDoc = await latestVerRef.get();
    final latestVer = LatestVer.fromJson(latestVerDoc.data() ?? {});
    return latestVer;
  }
}
