class GitHubFile {
  final String name;
  final String path;
  final String sha;
  final int size;
  final String? downloadUrl;
  final bool isDirectory;

  GitHubFile({
    required this.name,
    required this.path,
    required this.sha,
    required this.size,
    this.downloadUrl,
    required this.isDirectory,
  });

  factory GitHubFile.fromJson(Map<String, dynamic> json) {
    return GitHubFile(
      name: json['name'] as String,
      path: json['path'] as String,
      sha: json['sha'] as String,
      size: json['size'] as int? ?? 0,
      downloadUrl: json['download_url'] as String?,
      isDirectory: json['type'] == 'dir',
    );
  }

  String get extension {
    if (isDirectory) return '';
    final dotIndex = name.lastIndexOf('.');
    if (dotIndex == -1) return '';
    return name.substring(dotIndex + 1).toLowerCase();
  }

  bool get isPdf => extension == 'pdf';
  bool get isPpt => extension == 'ppt' || extension == 'pptx';
  bool get isImage => ['png', 'jpg', 'jpeg', 'gif', 'webp'].contains(extension);
  bool get isMarkdown => extension == 'md';
  bool get isJson => extension == 'json';
  bool get isCode => ['js', 'ts', 'dart', 'py', 'java', 'c', 'cpp', 'h', 'css', 'html', 'xml', 'yaml', 'yml'].contains(extension);
  bool get isText => extension == 'txt' || isMarkdown || isJson || isCode;

  String get formattedSize {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(1)} KB';
    return '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}
