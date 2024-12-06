// import 'package:csv/csv.dart';
// import 'dart:io';
// import 'package:path_provider/path_provider.dart';

// Future<void> exportCsv(List<List<dynamic>> data, String filename) async {
//   String csv = const ListToCsvConverter().convert(data);
//   final directory = await getApplicationDocumentsDirectory();
//   final path = '${directory.path}/$filename.csv';
//   final file = File(path);
//   await file.writeAsString(csv);
//   print('CSV saved to: $path');
// }
