import 'dart:convert';
import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:pdf/pdf.dart';

import 'package:pdf/widgets.dart' as pw;

class ReportTable {
  const ReportTable(this.headers, this.rows);
  final List<String> headers;
  final List<List<String>> rows;
}

class ReportSection {
  const ReportSection(this.title, {this.lines = const [], this.table});
  final String title;
  final List<String> lines;
  final ReportTable? table;
}

/// Builds PDF/CSV reports on the device, stores them under
/// `reports/{uid}/…` in Cloud Storage and returns a download URL.
/// Storing (rather than saving locally) works the same on web, Android and
/// iOS, and gives teachers a link they can share with the school head.
class ReportExporter {
  ReportExporter(this._storage, this.uid);

  final FirebaseStorage _storage;
  final String uid;

  Future<String> exportPdf({
    required String title,
    required String subtitle,
    required List<ReportSection> sections,
    required String fileName,
  }) async {
    final doc = pw.Document(title: title, author: 'EduLearn');
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(36),
        build: (context) => [
          pw.Text(_pdfSafe(title),
              style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(_pdfSafe(subtitle),
              style: pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
          pw.SizedBox(height: 18),
          for (final s in sections) ...[
            pw.Text(_pdfSafe(s.title),
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            for (final line in s.lines) pw.Bullet(text: _pdfSafe(line)),
            if (s.table != null)
              pw.TableHelper.fromTextArray(
                headers: s.table!.headers.map(_pdfSafe).toList(),
                data: [
                  for (final row in s.table!.rows) row.map(_pdfSafe).toList(),
                ],
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                cellStyle: pw.TextStyle(fontSize: 10),
                headerDecoration: pw.BoxDecoration(color: PdfColors.grey200),
                cellAlignment: pw.Alignment.centerLeft,
              ),
            pw.SizedBox(height: 16),
          ],
        ],
      ),
    );
    return _upload(await doc.save(), '$fileName.pdf', 'application/pdf');
  }

  Future<String> exportCsv({required ReportTable table, required String fileName}) {
    final buffer = StringBuffer()..writeln(table.headers.map(_csvCell).join(','));
    for (final row in table.rows) {
      buffer.writeln(row.map(_csvCell).join(','));
    }
    // BOM so Excel opens UTF-8 names (ñ) correctly.
    final bytes = Uint8List.fromList(utf8.encode('\uFEFF$buffer'));
    return _upload(bytes, '$fileName.csv', 'text/csv');
  }

  Future<String> _upload(Uint8List bytes, String fileName, String contentType) async {
    final ref = _storage.ref('reports/$uid/${DateTime.now().millisecondsSinceEpoch}_$fileName');
    await ref.putData(
      bytes,
      SettableMetadata(
        contentType: contentType,
        contentDisposition: 'attachment; filename="$fileName"',
      ),
    );
    return ref.getDownloadURL();
  }

  static String _csvCell(String v) =>
      v.contains(RegExp(r'[",\n]')) ? '"${v.replaceAll('"', '""')}"' : v;

  /// The built-in PDF fonts only cover Latin-1; swap typographic dashes and
  /// drop anything outside that range.
  static String _pdfSafe(String v) => v
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll('•', '-')
      .replaceAll('→', '->')
      .runes
      .where((r) => r <= 0xFF)
      .map(String.fromCharCode)
      .join();
}

String fileSlug(String v) =>
    v.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-').replaceAll(RegExp(r'^-|-$'), '');
