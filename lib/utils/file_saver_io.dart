import 'dart:io';
import 'dart:typed_data';
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';

Future<String> saveBytesToFile(Uint8List bytes, String filename) async {
  Directory dir;
  try {
    if (Platform.isAndroid) {
      final downloads = await getDownloadsDirectory();
      if (downloads != null) {
        dir = downloads;
      } else {
        dir = await getApplicationDocumentsDirectory();
      }
    } else {
      dir = await getApplicationDocumentsDirectory();
    }
  } catch (_) {
    dir = await getApplicationDocumentsDirectory();
  }
  final file = File('${dir.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  return file.path;
}
