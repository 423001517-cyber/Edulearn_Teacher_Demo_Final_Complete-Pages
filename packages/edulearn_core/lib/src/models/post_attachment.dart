import 'model_utils.dart';

enum AttachmentKind {
  file,
  link,
  video;

  static AttachmentKind parse(Object? v) =>
      AttachmentKind.values.firstWhere((k) => k.name == v, orElse: () => AttachmentKind.file);
}

/// A file, link or video on a stream post or class comment.
class PostAttachment {
  const PostAttachment({
    required this.name,
    this.url,
    this.kind = AttachmentKind.file,
    this.sizeBytes,
    this.storagePath,
  });

  final String name;

  /// Null for demo files that were never uploaded.
  final String? url;
  final AttachmentKind kind;
  final int? sizeBytes;

  /// Cloud Storage path of an uploaded file (to delete it later).
  final String? storagePath;

  factory PostAttachment.fromMap(Object? raw) {
    final d = raw is Map ? raw : const {};
    return PostAttachment(
      name: readString(d['name'], 'Attachment'),
      url: readStringOrNull(d['url']),
      kind: AttachmentKind.parse(d['kind']),
      sizeBytes: d['sizeBytes'] is num ? (d['sizeBytes'] as num).toInt() : null,
      storagePath: readStringOrNull(d['storagePath']),
    );
  }

  Json toMap() => {
        'name': name,
        'url': url,
        'kind': kind.name,
        'sizeBytes': sizeBytes,
        'storagePath': storagePath,
      };

  static List<PostAttachment> listFrom(Object? raw) =>
      raw is List ? raw.map(PostAttachment.fromMap).toList() : const [];

  /// "PDF", "DOCX"… from the file name (empty for links and videos).
  String get extension {
    if (kind != AttachmentKind.file) return '';
    final dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toUpperCase();
  }

  /// "2.4 MB", "820 KB" — empty when unknown.
  String get sizeLabel => formatBytes(sizeBytes);
}

String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).round()} KB';
  final mb = bytes / (1024 * 1024);
  return '${mb >= 10 ? mb.round() : mb.toStringAsFixed(1)} MB';
}
