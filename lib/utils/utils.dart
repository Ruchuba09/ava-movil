import 'dart:io';

import 'package:path_provider/path_provider.dart';

String capitalize(String text) {
  return text.isEmpty
      ? ''
      : text[0].toUpperCase() + text.substring(1).toLowerCase();
}

String capitalizeFirstLetter(String text) {
  final firstLetterIndex = text.indexOf(RegExp(r'[A-Za-z]'));
  if (firstLetterIndex == -1) {
    return text;
  }
  return text.substring(0, firstLetterIndex) +
      text[firstLetterIndex].toUpperCase() +
      text.substring(firstLetterIndex + 1).toLowerCase();
}

String ddmmyyyy(String fecha) {
  DateTime date = DateTime.parse(fecha);
  String day = date.day.toString().padLeft(2, '0');
  String month = date.month.toString().padLeft(2, '0');
  String year = date.year.toString();
  return '$day$month$year';
}

String formatRutWith0(String rut) {
  rut = rut.replaceAll(RegExp(r'\.'), '').trim();

  if (rut.length == 9) rut = rut.padLeft(10, '0');

  return rut;
}

Future<String> getDownloadsCarpeta() async {
  if (Platform.isAndroid) {
    return '/storage/emulated/0/Download';
  } else {
    final Directory documentsDirectory =
        await getApplicationDocumentsDirectory();
    return documentsDirectory.path;
  }
}
