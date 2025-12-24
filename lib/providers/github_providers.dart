import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../models/github_file.dart';
import '../services/github_service.dart';

/// GitHub service provider
final githubServiceProvider = Provider<GitHubService>((ref) {
  return GitHubService();
});

/// Provider for current path stack (navigation state)
final githubPathStackProvider = StateNotifierProvider<GitHubPathStackNotifier, List<String>>((ref) {
  return GitHubPathStackNotifier();
});

class GitHubPathStackNotifier extends StateNotifier<List<String>> {
  GitHubPathStackNotifier() : super([]);

  String get currentPath => state.join('/');

  void navigateTo(String folder) {
    state = [...state, folder];
  }

  void navigateBack() {
    if (state.isNotEmpty) {
      state = state.sublist(0, state.length - 1);
    }
  }

  void navigateToIndex(int index) {
    if (index < state.length) {
      state = state.sublist(0, index + 1);
    }
  }

  void navigateToRoot() {
    state = [];
  }

  void navigateToPath(List<String> path) {
    state = path;
  }
}

/// Main provider: Direct Firestore stream (updated by CI/CD)
final githubTreeProvider = StreamProvider<List<GitHubFile>>((ref) {
  final service = ref.watch(githubServiceProvider);
  return service.streamTree();
});

/// Get files for a specific folder path (filters from tree)
final githubFolderProvider = Provider.family<List<GitHubFile>, String>((ref, path) {
  final treeAsync = ref.watch(githubTreeProvider);

  return treeAsync.maybeWhen(
    data: (allFiles) {
      // Filter files that are direct children of this path
      final parentPath = path.isEmpty ? '' : '$path/';

      return allFiles.where((file) {
        // Skip hidden folders/files (starting with .)
        if (file.name.startsWith('.')) return false;

        if (path.isEmpty) {
          // Root level: files with no '/' in path
          return !file.path.contains('/');
        } else {
          // Subfolder: starts with path/ but no further /
          if (!file.path.startsWith(parentPath)) return false;
          final relativePath = file.path.substring(parentPath.length);
          return !relativePath.contains('/');
        }
      }).toList()
        ..sort((a, b) {
          // Directories first, then files
          if (a.isDirectory != b.isDirectory) {
            return a.isDirectory ? -1 : 1;
          }
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        });
    },
    orElse: () => <GitHubFile>[],
  );
});

/// Search query provider
final githubSearchQueryProvider = StateProvider<String>((ref) => '');

/// Search results provider - searches across ALL files
final githubSearchResultsProvider = Provider<List<GitHubFile>>((ref) {
  final query = ref.watch(githubSearchQueryProvider);
  if (query.isEmpty) return [];

  final treeAsync = ref.watch(githubTreeProvider);

  return treeAsync.maybeWhen(
    data: (allFiles) {
      final lowerQuery = query.toLowerCase();
      return allFiles.where((file) {
        // Skip hidden files from search too
        if (file.name.startsWith('.')) return false;

        return file.name.toLowerCase().contains(lowerQuery) ||
               file.path.toLowerCase().contains(lowerQuery);
      }).toList();
    },
    orElse: () => <GitHubFile>[],
  );
});

/// Base provider for file content (text, markdown, json, etc.)
final _githubFileContentBaseProvider = FutureProvider.family.autoDispose<String, String>((ref, url) async {
  final response = await http.get(Uri.parse(url));
  if (response.statusCode == 200) {
    return response.body;
  }
  throw Exception('Failed to load file (${response.statusCode})');
});

/// Sticky cache wrapper: Returns new value only if not error, keeps last good value
final githubFileContentProvider = Provider.family.autoDispose<AsyncValue<String>, String>((ref, url) {
  final baseAsync = ref.watch(_githubFileContentBaseProvider(url));

  // Keep reference to last successful value
  final lastSuccessful = ref.watch(_lastSuccessfulContentProvider(url));

  return baseAsync.when(
    data: (content) {
      // Update last successful value
      if(lastSuccessful != content){
        ref.read(_lastSuccessfulContentProvider(url).notifier).state = content;
      }
      return AsyncValue.data(content);
    },
    loading: () {
      // While loading, show last successful if available
      if (lastSuccessful != null) {
        return AsyncValue.data(lastSuccessful);
      }
      return const AsyncValue.loading();
    },
    error: (error, stack) {
      // On error, return last successful if available, else show error
      if (lastSuccessful != null) {
        return AsyncValue.data(lastSuccessful);
      }
      return AsyncValue.error(error, stack);
    },
  );
});

/// Stores last successful content for each URL
final _lastSuccessfulContentProvider = StateProvider.family<String?, String>((ref, url) => null);
