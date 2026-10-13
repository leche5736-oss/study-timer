import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:study_timer/version.dart';

void main() {
  test('화면의 버전이 pubspec.yaml과 같다', () {
    final line = File('pubspec.yaml')
        .readAsLinesSync()
        .firstWhere((l) => l.startsWith('version:'));
    expect(line.split(':')[1].trim().split('+').first, appVersion);
  });
}
