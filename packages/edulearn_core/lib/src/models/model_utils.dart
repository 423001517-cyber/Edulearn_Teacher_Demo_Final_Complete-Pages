import 'package:cloud_firestore/cloud_firestore.dart';

typedef Json = Map<String, dynamic>;
typedef Doc = DocumentSnapshot<Json>;

Json dataOf(Doc doc) => doc.data() ?? const <String, dynamic>{};

DateTime? readDate(Object? v) => switch (v) {
      Timestamp t => t.toDate(),
      DateTime d => d,
      String s => DateTime.tryParse(s),
      _ => null,
    };

double readDouble(Object? v, [double fallback = 0]) =>
    v is num ? v.toDouble() : fallback;

double? readDoubleOrNull(Object? v) => v is num ? v.toDouble() : null;

int readInt(Object? v, [int fallback = 0]) => v is num ? v.toInt() : fallback;

int? readIntOrNull(Object? v) => v is num ? v.toInt() : null;

String readString(Object? v, [String fallback = '']) => v is String ? v : fallback;

String? readStringOrNull(Object? v) => v is String && v.isNotEmpty ? v : null;

List<String> readStringList(Object? v) =>
    v is List ? v.whereType<String>().toList() : const <String>[];

/// "Junia Rey" -> "JR", "Marky" -> "M".
String initialsOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
  return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
}

String firstNameOf(String name) {
  final parts =
      name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
  return parts.isEmpty ? name : parts.first;
}

/// Parses a calendar key such as "2026-09" or "2026-09-26" (optionally at the
/// end of an id like "rizal-4a_2026-09-26") as a *local* date. Rollup
/// documents are keyed by Manila dates, so the key is exact in every time
/// zone, while the stored timestamp would shift outside the Philippines.
DateTime? dateFromKey(String id) {
  final m = RegExp(r'(\d{4})-(\d{2})(?:-(\d{2}))?$').firstMatch(id);
  if (m == null) return null;
  return DateTime(int.parse(m.group(1)!), int.parse(m.group(2)!), int.parse(m.group(3) ?? '1'));
}
