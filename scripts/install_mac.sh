#!/bin/bash
# 공부 타이머를 Mac에 설치합니다.
# 처음 실행하면 Flutter를 설치하고, 앱을 빌드해서
# "응용 프로그램" 폴더에 넣습니다. 새 버전을 받을 때도 이 스크립트를 다시 실행하면 됩니다.
# 최신 코드도 이 스크립트가 받아 옵니다. 이 Mac에서 직접 만든 앱이라
# 다운로드한 앱처럼 독에서 튀기만 하고 안 열리는 문제가 생기지 않습니다.
main() {
set -e

cd "$(dirname "$0")/.."

# 최신 코드 받기 (iPhone 설치 때 Xcode가 바꾼 설정은 개발 팀만 저장하고 되돌림)
team=$(grep -m1 -o 'DEVELOPMENT_TEAM = [A-Z0-9]*' ios/Runner.xcodeproj/project.pbxproj | awk '{print $3}' || true)
if [ -n "$team" ]; then
  echo "DEVELOPMENT_TEAM = $team" > ios/Flutter/Team.xcconfig
fi
git checkout -- ios macos
git pull

say() { printf '\n\033[1;34m▶ %s\033[0m\n' "$1"; }

# 1. Xcode (App Store에서 직접 설치해야 함)
if [ ! -d /Applications/Xcode.app ]; then
  echo "Xcode가 없습니다. App Store에서 Xcode를 설치하고 한 번 연 뒤 이 스크립트를 다시 실행하세요."
  open "macappstore://apps.apple.com/app/xcode/id497799835" || true
  exit 1
fi
if [ "$(xcode-select -p 2>/dev/null)" != "/Applications/Xcode.app/Contents/Developer" ]; then
  say "Xcode 설정 (Mac 비밀번호를 물어보면 입력하세요. 입력해도 화면에 안 보이는 게 정상입니다)"
  sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
  sudo xcodebuild -license accept
  sudo xcodebuild -runFirstLaunch
fi

# 2. Flutter (Homebrew 없이 공식 압축 파일을 ~/development/flutter 에 풉니다)
FLUTTER_VERSION=3.47.6
FLUTTER_DIR="$HOME/development/flutter"
if [ "$(sysctl -n hw.optional.arm64 2>/dev/null)" = "1" ]; then
  FLUTTER_ZIP="flutter_macos_arm64_${FLUTTER_VERSION}-stable.zip" # Apple 칩 (M1 등)
else
  FLUTTER_ZIP="flutter_macos_${FLUTTER_VERSION}-stable.zip" # Intel 칩
fi
if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  say "Flutter 설치"
  mkdir -p "$HOME/development"
  curl -fL -o "/tmp/$FLUTTER_ZIP" \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/macos/$FLUTTER_ZIP"
  unzip -q "/tmp/$FLUTTER_ZIP" -d "$HOME/development"
  rm -f "/tmp/$FLUTTER_ZIP"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"
# 다음에 터미널을 열 때도 flutter 명령을 찾을 수 있게
grep -q 'development/flutter/bin' ~/.zprofile 2>/dev/null ||
  echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.zprofile
flutter config --no-analytics >/dev/null 2>&1 || true

# 3. 플러그인은 모두 Swift Package Manager를 지원하므로 CocoaPods는 필요 없습니다.

# 4. 빌드
say "앱 빌드 (처음에는 몇 분 걸립니다)"
flutter pub get
flutter build macos --release

# 5. 응용 프로그램 폴더에 설치
APP="build/macos/Build/Products/Release/study_timer.app"
DEST="/Applications/공부 타이머.app"
osascript -e 'quit app "공부 타이머"' >/dev/null 2>&1 || true
pkill -f "공부 타이머.app/Contents/MacOS" 2>/dev/null || true # 멈춰 있던 앱도 끔
rm -rf "$DEST"
cp -R "$APP" "$DEST"
xattr -cr "$DEST"
codesign --force --deep -s - "$DEST"

say "설치 완료! Launchpad나 응용 프로그램 폴더에서 '공부 타이머'를 여세요."
open "$DEST"
}
main "$@"
