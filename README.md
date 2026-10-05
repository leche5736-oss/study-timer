# 공부 타이머 (1차 버전)

뇌과학 근거로 설계한 공부 타이머입니다. 기획서의 1차(MVP) 기능만 들어 있고, 디자인은 아직 기본 모양입니다.

## 들어 있는 기능

| 기능 | 설명 |
|---|---|
| 과목 | 과목 추가, 이름 바꾸기, 색 바꾸기, 삭제 |
| 집중/휴식 타이머 | 25/5, 50/10, 90/20 프리셋. 4블록마다 긴 휴식. 일시정지, 일찍 끝내기, 취소 |
| 세션 종료 인출 | 집중이 끝나면 "방금 배운 것 3줄 / 스스로 낼 문제 1개 / 집중도 1~5" 입력 |
| 조용한 휴식 모드 | 휴식 중에는 화면이 어두워지고 호흡 안내(4초 들이쉬기, 6초 내쉬기)만 표시 |
| 통계 | 오늘, 이번 주, 이번 달 과목별 공부 시간과 평균 집중도 |
| 기록 | 끝낸 블록 목록, 적어 둔 메모 다시 보기, 삭제 |
| 알림 | 집중/휴식이 끝나는 순간 알림 (앱이 뒤에 있어도) |
| 동기화 (선택) | Supabase를 연결하면 로그인 후 Mac, iPhone, iPad가 같은 기록과 같은 타이머를 봅니다 |

동기화를 켜기 전에는 기록이 각 기기 안에만 저장됩니다.

---

## Mac에 설치하기

1. App Store에서 **Xcode**를 설치하고, 한 번 열어서 약관에 동의합니다 (용량이 커서 오래 걸립니다).
2. **터미널** 앱(Spotlight에서 "터미널" 검색)을 열고 아래 한 줄을 붙여 넣은 뒤 Enter:
   ```bash
   cd ~ && (git clone -b claude/project-thread-0xriid https://github.com/leche5736-oss/study-timer.git 2>/dev/null || true) && cd study-timer && git pull && ./scripts/install_mac.sh
   ```

스크립트가 Flutter를 설치하고 앱을 빌드해서 **응용 프로그램** 폴더에 "공부 타이머"로 넣어 줍니다. 처음에는 꽤 오래 걸리고, 중간에 Mac 비밀번호를 물으면 입력하면 됩니다(입력해도 화면에 안 보이는 게 정상입니다). 그다음부터는 Launchpad에서 일반 앱처럼 열면 됩니다. Mac 앱은 7일 제한이 없습니다.

새 버전이 나오면 같은 한 줄을 다시 실행하면 됩니다.

---

## iPhone / iPad에 설치하기 (필요할 때만)

처음 한 번만:
1. iPhone을 케이블로 Mac에 연결하고, 폰에 "이 컴퓨터를 신뢰하겠습니까?"가 뜨면 **신뢰**.
2. 폰에서 **설정 > 개인정보 보호 및 보안 > 개발자 모드**를 켜고 재시동합니다.
3. 터미널에서 `open ~/study-timer/ios/Runner.xcworkspace` 로 Xcode를 엽니다.
   왼쪽에서 **Runner** 선택 > **Signing & Capabilities** 탭 > **Team**에서 *Add an Account…* 로 Apple ID를 추가하고 *(Personal Team)* 을 고릅니다.
   "bundle identifier를 쓸 수 없다"는 오류가 나면 Bundle Identifier 끝에 아무 글자나 붙여(예: `com.leche5736.studyTimer2`) 바꿉니다.

설치 (7일마다 반복):
```bash
~/study-timer/scripts/install_iphone.sh
```
처음 설치 후 폰에서 "신뢰하지 않는 개발자" 경고가 나오면 **설정 > 일반 > VPN 및 기기 관리**에서 내 Apple ID를 **신뢰**합니다.

무료 Apple ID로 설치한 앱은 **7일 뒤 열리지 않습니다.** 그때 폰을 연결하고 위 명령을 다시 실행하면 됩니다. iPad도 같은 방법입니다.

---

## 기기 간 동기화 켜기 (선택)

1. https://supabase.com 에서 무료 가입 후 **New project**를 만듭니다 (지역은 Northeast Asia (Seoul) 추천).
2. 왼쪽 메뉴 **SQL Editor**에서 이 저장소의 [`supabase/schema.sql`](supabase/schema.sql) 내용을 통째로 붙여 넣고 **Run**.
3. **Authentication > Sign In / Providers > Email**에서 *Confirm email*을 끄면 가입 확인 메일 없이 바로 로그인됩니다 (켜 두면 메일의 링크를 눌러야 합니다).
4. **Project Settings > API Keys**(또는 **Data API**)에서 *Project URL*과 *Publishable key*(예전 이름 *anon public key*)를 복사해 [`lib/config.dart`](lib/config.dart)의 빈 따옴표 안에 붙여 넣습니다.
5. 앱을 다시 실행하면 로그인 화면이 나옵니다. 모든 기기에서 **같은 이메일**로 로그인하세요.

동기화가 켜지면 한 기기에서 타이머를 시작해도 다른 기기에 같은 남은 시간이 보이고, 휴식 화면도 함께 바뀝니다. 오른쪽 위 구름 아이콘이 빨간색이면 동기화에 실패한 것이니 눌러서 다시 시도해 보세요.

동기화를 켜기 전에 이 기기에 쌓인 기록은 로그인 후 자동으로 서버에 올라갑니다.

---

## 버전 기록

- **0.2.0**: 화면 위쪽에 버전 표시, 공부 시간을 초 단위까지 표시, 과목 색 바꾸기(과목 탭의 팔레트 아이콘)
- **0.1.0**: 첫 버전

---

## 개발자용 메모

- 구조: `lib/models.dart`(데이터), `lib/timer_logic.dart`(타이머 규칙), `lib/stats.dart`(통계 계산), `lib/services/`(저장, 알림, 동기화), `lib/screens/`(화면).
- 타이머는 매초 숫자를 세지 않고 "시작 시각 + 흐른 시간"으로 저장해, 앱을 껐다 켜거나 다른 기기에서 받아도 정확합니다.
- 테스트: `flutter test`
- 버전을 올릴 때는 `pubspec.yaml`의 version과 `lib/version.dart`를 함께 바꿉니다.
