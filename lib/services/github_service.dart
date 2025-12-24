import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/github_file.dart';

class GitHubService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Stream tree data directly from Firestore (updated by CI/CD)
  Stream<List<GitHubFile>> streamTree() {
    return _firestore
        .collection('github_cache')
        .doc('full_tree')
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists || snapshot.data() == null) {
        return <GitHubFile>[];
      }

      final data = snapshot.data()!;
      final payload = data['payload'] as List<dynamic>?;

      if (payload == null || payload.isEmpty) {
        return <GitHubFile>[];
      }

      return payload
          .map((item) => GitHubFile.fromJson(item as Map<String, dynamic>))
          .toList();
    });
  }

  String getRawUrl(String path) {
    return 'https://raw.githubusercontent.com/AppLabs-IIITK/IIITK-Resources/main/$path';
  }
}
