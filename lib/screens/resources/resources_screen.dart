import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../models/github_file.dart';
import '../../providers/github_providers.dart';
import 'pdf_viewer_screen.dart';
import 'text_viewer_screen.dart';
import 'document_viewer_screen.dart';

class ResourcesScreen extends ConsumerStatefulWidget {
  const ResourcesScreen({super.key});

  @override
  ConsumerState<ResourcesScreen> createState() => _ResourcesScreenState();
}

class _ResourcesScreenState extends ConsumerState<ResourcesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  bool _isSearchExpanded = false;

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pathStack = ref.watch(githubPathStackProvider);
    final currentPath = pathStack.join('/');
    final searchQuery = ref.watch(githubSearchQueryProvider);
    final isSearching = searchQuery.isNotEmpty;
    final treeAsync = ref.watch(githubTreeProvider);

    return PopScope(
      canPop: pathStack.isEmpty && !_isSearchExpanded,
      onPopInvokedWithResult: (didPop, result) {
        if (_isSearchExpanded) {
          setState(() {
            _isSearchExpanded = false;
            _searchController.clear();
            ref.read(githubSearchQueryProvider.notifier).state = '';
          });
        } else if (pathStack.isNotEmpty) {
          ref.read(githubPathStackProvider.notifier).navigateBack();
        }
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _isSearchExpanded
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFAEE7FF)),
                  onPressed: () {
                    setState(() {
                      _isSearchExpanded = false;
                      _searchController.clear();
                      ref.read(githubSearchQueryProvider.notifier).state = '';
                    });
                  },
                )
              : pathStack.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios, color: Color(0xFFAEE7FF)),
                      onPressed: () {
                        ref.read(githubPathStackProvider.notifier).navigateBack();
                      },
                    )
                  : null,
          title: _isSearchExpanded
              ? TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  autofocus: false,
                  style: const TextStyle(color: Color(0xFFAEE7FF)),
                  decoration: const InputDecoration(
                    hintText: 'Search all files...',
                    hintStyle: TextStyle(color: Color(0xFF83ACBD)),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    ref.read(githubSearchQueryProvider.notifier).state = value;
                  },
                )
              : Text(
                  pathStack.isEmpty ? 'Resources' : pathStack.last,
                  style: const TextStyle(
                    color: Color(0xFFAEE7FF),
                    fontSize: 23,
                    fontWeight: FontWeight.w600,
                  ),
                ),
          actions: [
            if (!_isSearchExpanded)
              Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: IconButton(
                  icon: const Icon(Icons.search, color: Color(0xFFAEE7FF)),
                  onPressed: () {
                    setState(() {
                      _isSearchExpanded = true;
                    });
                    _searchFocusNode.requestFocus();
                  },
                ),
              ),
          ],
        ),
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF07181F),
                Color(0xFF000000),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: treeAsync.when(
              data: (_) => Column(
                children: [
                  if (!isSearching) _buildBreadcrumb(pathStack),
                  Expanded(
                    child: isSearching
                        ? _buildSearchResults()
                        : _buildFolderContent(currentPath),
                  ),
                ],
              ),
              loading: () => const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFAEE7FF)),
                ),
              ),
              error: (error, _) => _buildError(error.toString()),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults() {
    final searchResults = ref.watch(githubSearchResultsProvider);

    if (searchResults.isEmpty) {
      final query = ref.watch(githubSearchQueryProvider);
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.search_off,
              color: Color(0xFF83ACBD),
              size: 48,
            ),
            const SizedBox(height: 16),
            Text(
              query.isEmpty ? 'Start typing to search' : 'No results found',
              style: const TextStyle(
                color: Color(0xFFAEE7FF),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              query.isEmpty
                  ? 'Search across all files'
                  : 'Try a different search term',
              style: TextStyle(
                color: const Color(0xFF83ACBD).withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: searchResults.length,
      itemBuilder: (context, index) {
        final file = searchResults[index];
        return _buildFileCard(file, showPath: true);
      },
    );
  }

  Widget _buildFolderContent(String currentPath) {
    final files = ref.watch(githubFolderProvider(currentPath));
    return _buildFileList(files);
  }

  Widget _buildBreadcrumb(List<String> pathStack) {
    if (pathStack.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            InkWell(
              onTap: () {
                ref.read(githubPathStackProvider.notifier).navigateToRoot();
              },
              child: const Row(
                children: [
                  Icon(Icons.home, size: 16, color: Color(0xFF83ACBD)),
                  SizedBox(width: 6),
                  Text(
                    'Resources',
                    style: TextStyle(
                      color: Color(0xFF83ACBD),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            ...pathStack.asMap().entries.map((entry) {
              final index = entry.key;
              final folder = entry.value;
              final isLast = index == pathStack.length - 1;

              return Row(
                children: [
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.chevron_right,
                      size: 16,
                      color: Color(0xFF83ACBD),
                    ),
                  ),
                  InkWell(
                    onTap: isLast
                        ? null
                        : () {
                            ref.read(githubPathStackProvider.notifier).navigateToIndex(index);
                          },
                    child: Text(
                      folder,
                      style: TextStyle(
                        color: isLast
                            ? const Color(0xFFAEE7FF)
                            : const Color(0xFF83ACBD),
                        fontSize: 14,
                        fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ],
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildFileList(List<GitHubFile> files) {
    if (files.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.folder_open,
              color: Color(0xFF83ACBD),
              size: 48,
            ),
            const SizedBox(height: 16),
            const Text(
              'This folder is empty',
              style: TextStyle(
                color: Color(0xFFAEE7FF),
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No files or folders here',
              style: TextStyle(
                color: const Color(0xFF83ACBD).withValues(alpha: 0.8),
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: files.length,
      itemBuilder: (context, index) {
        final file = files[index];
        return _buildFileCard(file);
      },
    );
  }

  Widget _buildFileCard(GitHubFile file, {bool showPath = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F2026),
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          splashColor: Colors.white.withValues(alpha: 0.1),
          highlightColor: Colors.white.withValues(alpha: 0.05),
          onTap: () {
            if (file.isDirectory) {
              // Navigate to the folder
              final pathParts = file.path.split('/');
              ref.read(githubPathStackProvider.notifier).navigateToPath(pathParts);
              // Close search
              setState(() {
                _isSearchExpanded = false;
                _searchController.clear();
                ref.read(githubSearchQueryProvider.notifier).state = '';
              });
            } else {
              _openFile(file);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF17323D),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(child: _buildFileIcon(file)),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.name,
                        style: const TextStyle(
                          color: Color(0xFFAEE7FF),
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        showPath ? file.path : (file.isDirectory ? 'Folder' : file.formattedSize),
                        style: const TextStyle(
                          color: Color(0xFF83ACBD),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  file.isDirectory ? Icons.chevron_right : Icons.open_in_new,
                  color: const Color(0xFF83ACBD),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileIcon(GitHubFile file) {
    IconData icon;
    Color color;

    if (file.isDirectory) {
      icon = Icons.folder;
      color = const Color(0xFF71C2E4);
    } else if (file.isPdf) {
      icon = Icons.picture_as_pdf;
      color = const Color(0xFFF85149);
    } else if (file.isPpt) {
      icon = Icons.slideshow;
      color = const Color(0xFFD29922);
    } else if (file.isMarkdown) {
      icon = Icons.article;
      color = const Color(0xFF83ACBD);
    } else if (file.isJson) {
      icon = Icons.data_object;
      color = const Color(0xFFD29922);
    } else if (file.isCode) {
      icon = Icons.code;
      color = const Color(0xFF7EE787);
    } else if (file.isText) {
      icon = Icons.description;
      color = const Color(0xFF83ACBD);
    } else if (file.isImage) {
      icon = Icons.image;
      color = const Color(0xFFA371F7);
    } else {
      icon = Icons.insert_drive_file;
      color = const Color(0xFF83ACBD);
    }

    return Icon(icon, color: color, size: 24);
  }

  Widget _buildError(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: Color(0xFFF85149),
            ),
            const SizedBox(height: 16),
            const Text(
              'Failed to load',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFFAEE7FF),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF83ACBD),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(githubTreeProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0E668A),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openFile(GitHubFile file) async {
    final service = ref.read(githubServiceProvider);
    final url = service.getRawUrl(file.path);

    if (file.isPdf) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PdfViewerScreen(
            title: file.name,
            url: url,
          ),
        ),
      );
    } else if (file.isText) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => TextViewerScreen(
            title: file.name,
            url: url,
            isMarkdown: file.isMarkdown,
          ),
        ),
      );
    } else if (file.isPpt) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DocumentViewerScreen(
            title: file.name,
            url: url,
          ),
        ),
      );
    } else {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }
  }
}
