import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import 'package:intl/intl.dart';
import '../models/note.dart';

class PdfService {
  Future<Uint8List> generatePdf(List<Note> notes) async {
    final pdf = pw.Document();

    // Load a font that supports Unicode
    final font = await PdfGoogleFonts.nunitoExtraLight();

    // Pre-build the list of widgets to handle async image loading
    final List<pw.Widget> pdfContent = [];

    // Header
    pdfContent.add(
      pw.Header(
        level: 0,
        child: pw.Text(
          'Fast Note Export',
          style: pw.TextStyle(
            font: font,
            fontSize: 24,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
      ),
    );
    pdfContent.add(pw.SizedBox(height: 20));

    // Note Items
    for (var i = 0; i < notes.length; i++) {
      final note = notes[i];
      pw.Widget? imageWidget;

      if (note.imagePath != null) {
        final file = File(note.imagePath!);
        if (await file.exists()) {
          final imageBytes = await file.readAsBytes();
          final image = pw.MemoryImage(imageBytes);
          imageWidget = pw.Container(
            height: 200,
            alignment: pw.Alignment.centerLeft,
            child: pw.Image(image, fit: pw.BoxFit.contain),
          );
        }
      }

      pdfContent.add(
        pw.Container(
          padding: const pw.EdgeInsets.only(bottom: 10),
          margin: const pw.EdgeInsets.only(bottom: 15),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Note #${i + 1}',
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 12,
                      color: PdfColors.grey700,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    DateFormat('MMM dd, yyyy • hh:mm a').format(note.createdAt),
                    style: pw.TextStyle(
                      font: font,
                      fontSize: 10,
                      color: PdfColors.grey,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 10),
              if (imageWidget != null) ...[
                imageWidget,
                pw.SizedBox(height: 10),
              ],
              pw.Text(
                note.content,
                style: pw.TextStyle(font: font, fontSize: 14),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(color: PdfColors.grey300),
            ],
          ),
        ),
      );
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pdfContent;
        },
      ),
    );

    return pdf.save();
  }

  Future<void> savePdfFile(Uint8List bytes, String filename) async {
    Directory? output;

    if (Platform.isAndroid) {
      // Manage storage permissions if needed (though scoped storage might not require it for public directories in newer Android)
      var status = await Permission.storage.request();
      if (status.isGranted ||
          await Permission.manageExternalStorage.isGranted) {
        output = Directory('/storage/emulated/0/Download');
        if (!await output.exists()) {
          output = await getExternalStorageDirectory(); // Fallback
        }
      } else {
        // Fallback for restricted access
        output = await getExternalStorageDirectory();
      }
    } else {
      output = await getDownloadsDirectory();
      output ??= await getTemporaryDirectory();
    }

    if (output != null) {
      final file = File("${output.path}/$filename");
      await file.writeAsBytes(bytes);
      await OpenFile.open(file.path);
    }
  }

  Future<void> sharePdfFile(Uint8List bytes, String filename) async {
    await Printing.sharePdf(bytes: bytes, filename: filename);
  }
}
