#!/bin/bash
# 공부 타이머를 Mac에 설치합니다.
# 처음 실행하면 필요한 도구(Homebrew, Flutter)를 설치하고, 앱을 빌드해서
# "응용 프로그램" 폴더에 넣습니다. 새 버전을 받을 때도 이 스크립트를 다시 실행하면 됩니다.
set -e

cd "$(dirname "$0")/.."

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

# 2. Homebrew
if ! command -v brew >/dev/null 2>&1; then
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && eval "$("$b" shellenv)"
  done
fi
if ! command -v brew >/dev/null 2>&1; then
  say "Homebrew 설치"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  for b in /opt/homebrew/bin/brew /usr/local/bin/brew; do
    [ -x "$b" ] && eval "$("$b" shellenv)"
  done
  # 다음에 터미널을 열 때도 brew를 찾을 수 있게
  grep -q 'brew shellenv' ~/.zprofile 2>/dev/null ||
    echo "eval \"\$($(command -v brew) shellenv)\"" >> ~/.zprofile
fi

# 3. Flutter, CocoaPods
command -v flutter >/dev/null 2>&1 || { say "Flutter 설치"; brew install --cask flutter; }
command -v pod >/dev/null 2>&1 || { say "CocoaPods 설치"; brew install cocoapods; }

# 4. 빌드
say "앱 빌드 (처음에는 몇 분 걸립니다)"
flutter pub get
flutter build macos --release

# 5. 응용 프로그램 폴더에 설치
APP="build/macos/Build/Products/Release/study_timer.app"
DEST="/Applications/공부 타이머.app"
osascript -e 'quit app "공부 타이머"' >/dev/null 2>&1 || true
rm -rf "$DEST"
cp -R "$APP" "$DEST"

say "설치 완료! Launchpad나 응용 프로그램 폴더에서 '공부 타이머'를 여세요."
open "$DEST"
