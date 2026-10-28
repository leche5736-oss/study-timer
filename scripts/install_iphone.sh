#!/bin/bash
# 케이블로 연결한 iPhone/iPad에 공부 타이머를 설치합니다.
# 무료 Apple ID로 설치한 앱은 7일 뒤 열리지 않으니, 그때 이 스크립트를 다시 실행하세요.
# 최신 코드도 이 스크립트가 받아 오니 git pull을 따로 할 필요가 없어요.
# (처음 한 번은 README의 "iPhone / iPad에 설치하기"에 있는 Xcode 서명 설정이 필요합니다.)
main() {
  set -e
  cd "$(dirname "$0")/.."
  export PATH="$HOME/development/flutter/bin:$PATH"

  # Xcode에서 고른 개발 팀을 따로 저장해 두고, Xcode가 바꾼 설정 파일은 되돌린 뒤 최신 코드를 받습니다.
  local pbx=ios/Runner.xcodeproj/project.pbxproj
  local team
  team=$(grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]*' "$pbx" | awk '{print $3}' || true)
  if [ -n "$team" ]; then
    echo "DEVELOPMENT_TEAM = $team" > ios/Flutter/Team.xcconfig
  fi
  git checkout -- ios
  git pull

  flutter pub get
  flutter build ios --release
  flutter install --release
  echo "설치 완료! 폰에서 '공부 타이머'를 여세요."
}
main "$@"
