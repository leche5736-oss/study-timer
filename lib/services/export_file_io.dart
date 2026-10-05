import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Mac은 다운로드 폴더, iPhone/iPad는 앱의 문서 폴더(파일 앱에서 보임)에 저장합니다.
Future<String?> saveTextFile(String text, String fileName) async {
  try {
    final dir = Platform.isMacOS
        ? await getDownloadsDirectory()
        : await getApplicationDocumentsDirectory();
    if (dir == null) return null;
    final file = File('${dir.path}/$fileName');
    await file.writeAsString(text);
    return file.path;
  } catch (e) {
    debugPrint('파일 저장 실패: $e');
    return null;
  }
}
