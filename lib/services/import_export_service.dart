// FILE: lib/services/import_export_service.dart
import 'dart:io';
// import 'dart:convert';
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/term.dart';

class ImportExportService {
  // Export terms to CSV format
  Future<String> exportTermsToCSV(List<Term> terms) async {
    final rows = <List<String>>[];

    // Header
    rows.add(['Term', 'Status', 'Translation', 'Romanization', 'Sentence']);

    // Data rows
    for (final term in terms) {
      rows.add([
        term.text,
        term.status.toString(),
        term.translation,
        term.romanization,
        term.sentence,
      ]);
    }

    return const ListToCsvConverter().convert(rows);
  }

  // Import terms from CSV
  Future<List<Term>> importTermsFromCSV(
    String csvContent,
    int languageId,
  ) async {
    final terms = <Term>[];

    try {
      final rows = const CsvToListConverter().convert(csvContent);

      // Skip header row
      for (var i = 1; i < rows.length; i++) {
        final row = rows[i];
        if (row.isEmpty || row[0].toString().trim().isEmpty) continue;

        final text = row[0].toString();
        terms.add(
          Term(
            languageId: languageId,
            text: text,
            lowerText: text.toLowerCase(),
            status: row.length > 1 ? int.tryParse(row[1].toString()) ?? 1 : 1,
            translation: row.length > 2 ? row[2].toString() : '',
            romanization: row.length > 3 ? row[3].toString() : '',
            sentence: row.length > 4 ? row[4].toString() : '',
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to parse CSV: $e');
    }

    return terms;
  }

  // Export to Anki format (semicolon-separated with HTML)
  Future<String> exportToAnki(List<Term> terms) async {
    final buffer = StringBuffer();

    for (final term in terms) {
      final front = term.text;
      final backParts = <String>[];

      if (term.translation.isNotEmpty) {
        backParts.add(term.translation);
      }
      if (term.romanization.isNotEmpty) {
        backParts.add('[${term.romanization}]');
      }
      if (term.sentence.isNotEmpty) {
        backParts.add('<br><i>${term.sentence}</i>');
      }

      final back = backParts.join('<br>');
      buffer.writeln('$front;$back');
    }

    return buffer.toString();
  }

  // Save to file
  Future<File> saveToFile(String content, String fileName) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    return await file.writeAsString(content);
  }

  // Share file
  Future<void> shareFile(
    String content,
    String fileName,
    String mimeType,
  ) async {
    final directory = await getTemporaryDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(content);

    await Share.shareXFiles([
      XFile(file.path, mimeType: mimeType),
    ], text: 'LNT Export: $fileName');
  }

  // Export with share dialog
  Future<void> exportAndShare(List<Term> terms, String format) async {
    String content;
    String fileName;
    String mimeType;

    switch (format.toLowerCase()) {
      case 'anki':
        content = await exportToAnki(terms);
        fileName =
            'lnt_export_anki_${DateTime.now().millisecondsSinceEpoch}.txt';
        mimeType = 'text/plain';
        break;
      case 'csv':
      default:
        content = await exportTermsToCSV(terms);
        fileName = 'lnt_export_${DateTime.now().millisecondsSinceEpoch}.csv';
        mimeType = 'text/csv';
    }

    await shareFile(content, fileName, mimeType);
  }

  // Read text file
  Future<String> readTextFile(File file) async {
    return await file.readAsString();
  }

  // Parse text content for import
  String cleanTextForImport(String text) {
    // Remove extra whitespace
    text = text.replaceAll(RegExp(r'\s+'), ' ');
    // Remove common formatting
    text = text.replaceAll(RegExp(r'[\r\n]+'), '\n\n');
    return text.trim();
  }
}
