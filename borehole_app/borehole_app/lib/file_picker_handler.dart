import 'package:file_picker/file_picker.dart';
import 'package:csv/csv.dart';
import 'dart:io';

Future<List<List<dynamic>>> pickCsvFile(int rowsToSkip) async {
  FilePickerResult? result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: ['csv'],
  );

  if (result != null) {
    File file = File(result.files.single.path!);
    final csvData = await file.readAsString();
    List<List<dynamic>> rows = const CsvToListConverter().convert(csvData);

    // Skip the header rows
    List<List<dynamic>> dataRows = rows.sublist(rowsToSkip);

    return dataRows;
  }

  return [];
}
