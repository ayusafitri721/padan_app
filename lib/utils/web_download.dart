import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart' as impl;
import 'dart:typed_data';

Future<void> downloadBytes(Uint8List bytes, String filename) => impl.downloadBytes(bytes, filename);
