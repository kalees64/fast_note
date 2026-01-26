import 'dart:io';
import 'dart:typed_data';

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:printing/printing.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:open_file/open_file.dart';
import '../models/note.dart';

class PdfService {
  Future<Uint8List> generatePdf(List<Note> notes) async {
    final pdf = pw.Document();

    // Load a font that supports Unicode (e.g., standard text)
    final font = await PdfGoogleFonts.nunitoExtraLight();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
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
            pw.SizedBox(height: 20),
            pw.Table.fromTextArray(
              context: context,
              cellStyle: pw.TextStyle(font: font),
              headerStyle: pw.TextStyle(
                font: font,
                fontWeight: pw.FontWeight.bold,
              ),
              data: <List<String>>[
                <String>['S.No', 'Note Content'],
                ...notes.asMap().entries.map((entry) {
                  return [(entry.key + 1).toString(), entry.value.content];
                }).toList(),
              ],
            ),
          ];
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
