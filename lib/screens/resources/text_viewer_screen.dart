import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/github_providers.dart';
import '../../utils/markdown_renderer.dart';

class TextViewerScreen extends ConsumerWidget {
  final String title;
  final String url;
  final bool isMarkdown;

  const TextViewerScreen({
    super.key,
    required this.title,
    required this.url,
    this.isMarkdown = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contentAsync = ref.watch(githubFileContentProvider(url));

    return Scaffold(
      backgroundColor: const Color(0xFF07181F),
      appBar: AppBar(
        backgroundColor: const Color(0xFF06222F),
        elevation: 0,
        title: Text(
          title,
          style: const TextStyle(
            color: Color(0xFFAEE7FF),
            fontSize: 16,
          ),
        ),
        iconTheme: const IconThemeData(color: Color(0xFF83ACBD)),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy',
            onPressed: () {
              Clipboard.setData(ClipboardData(text: contentAsync.value ?? ''));
            },
          ),
        ],
      ),
      body: contentAsync.when(
        data: (content) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: isMarkdown
              ? MarkdownRenderer(data: content)
              : SelectableText(
                  content,
                  style: const TextStyle(
                    color: Color(0xFFAEE7FF),
                    fontSize: 14,
                    fontFamily: 'monospace',
                    height: 1.6,
                  ),
                ),
        ),
        loading: () => const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Color(0xFF83ACBD)),
              SizedBox(height: 16),
              Text(
                'Loading...',
                style: TextStyle(color: Color(0xFF8B949E)),
              ),
            ],
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Color(0xFFF85149),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Failed to load',
                  style: TextStyle(
                    fontSize: 18,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  error.toString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF8B949E)),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Go back and try again',
                  style: TextStyle(
                    color: Color(0xFF8B949E),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
