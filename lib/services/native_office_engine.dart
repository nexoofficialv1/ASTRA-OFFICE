import 'dart:io';

import 'package:open_filex/open_filex.dart';

class NativeOfficeEngine {
  const NativeOfficeEngine();

  Future<void> openOriginal(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    await OpenFilex.open(path);
  }
}
