import 'file_saver_stub.dart' if (dart.library.io) 'file_saver_io.dart' as impl;
import 'dart:typed_data';

Future<String> saveBytesToFile(Uint8List bytes, String filename) => impl.saveBytesToFile(bytes, filename);
