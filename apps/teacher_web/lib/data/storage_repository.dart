import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';

/// Lesson manuscripts and learning materials in Cloud Storage.
class StorageRepository {
  StorageRepository(this._storage, this.uid);

  final FirebaseStorage _storage;
  final String uid;

  static const maxBytes = 25 * 1024 * 1024; // keep in sync with storage.rules

  Future<({String url, String path})> uploadLessonFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = 'lessons/$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
    final ref = _storage.ref(path);
    await ref.putData(bytes, SettableMetadata(contentType: _contentType(safeName)));
    return (url: await ref.getDownloadURL(), path: path);
  }

  static String _contentType(String name) {
    final ext = name.split('.').last.toLowerCase();
    return switch (ext) {
      'pdf' => 'application/pdf',
      'doc' => 'application/msword',
      'docx' => 'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
      'ppt' => 'application/vnd.ms-powerpoint',
      'pptx' => 'application/vnd.openxmlformats-officedocument.presentationml.presentation',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'mp4' => 'video/mp4',
      _ => 'application/octet-stream',
    };
  }
}
