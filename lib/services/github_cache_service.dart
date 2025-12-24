// import 'package:hive_flutter/hive_flutter.dart';
// import '../models/github_file.dart';

// class GitHubCacheService {
//   static const String _boxName = 'github_cache';
//   static const String _treeKey = 'full_tree';
//   static Box<List<dynamic>>? _box;

//   /// Initialize Hive and open the box
//   static Future<void> init() async {
//     await Hive.initFlutter();

//     // Register adapter if not already registered
//     if (!Hive.isAdapterRegistered(1)) {
//       Hive.registerAdapter(GitHubFileAdapter());
//     }

//     _box = await Hive.openBox<List<dynamic>>(_boxName);
//   }

//   /// Get the box (must be initialized first)
//   static Box<List<dynamic>> get box {
//     if (_box == null) {
//       throw StateError('GitHubCacheService not initialized. Call init() first.');
//     }
//     return _box!;
//   }

//   /// Get cached tree (all files)
//   static List<GitHubFile>? getTree() {
//     final data = box.get(_treeKey);
//     if (data == null) return null;
//     return data.cast<GitHubFile>();
//   }

//   /// Cache entire tree
//   static Future<void> saveTree(List<GitHubFile> files) async {
//     await box.put(_treeKey, files);
//   }

//   /// Search across all cached files
//   static List<GitHubFile> search(String query) {
//     final tree = getTree();
//     if (tree == null || query.isEmpty) return [];

//     final lowerQuery = query.toLowerCase();
//     return tree.where((file) {
//       return file.name.toLowerCase().contains(lowerQuery) ||
//              file.path.toLowerCase().contains(lowerQuery);
//     }).toList();
//   }

//   /// Clear all cache
//   static Future<void> clearAll() async {
//     await box.clear();
//   }
// }
