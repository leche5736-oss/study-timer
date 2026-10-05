#!/bin/bash
# 케이블로 연결한 iPhone/iPad에 공부 타이머를 설치합니다.
# 무료 Apple ID로 설치한 앱은 7일 뒤 열리지 않으니, 그때 이 스크립트를 다시 실행하세요.
# (처음 한 번은 README의 "iPhone / iPad에 설치하기"에 있는 Xcode 서명 설정이 필요합니다.)
set -e
cd "$(dirname "$0")/.."
for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
  [ -x "$b" ] && eval "$("$b" shellenv)"
done

flutter pub get
flutter build ios --release
flutter install --release
echo "설치 완료! 폰에서 '공부 타이머'를 여세요."
