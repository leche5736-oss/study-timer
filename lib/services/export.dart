import 'package:flutter/services.dart';

import 'export_file_stub.dart' if (dart.library.io) 'export_file_io.dart';

/// CSV를 클립보드에 복사하고, 가능하면(Mac/iOS 앱) 파일로도 저장합니다.
/// 사용자에게 보여줄 결과 문구를 돌려줍니다.
Future<String> exportCsv(String csv, String fileName) async {
  await Clipboard.setData(ClipboardData(text: csv));
  final path = await saveTextFile(csv, fileName);
  return path == null
      ? '클립보드에 복사했어요. 엑셀이나 Numbers에 붙여 넣으세요.'
      : '클립보드에 복사하고 파일로도 저장했어요:\n$path';
}
