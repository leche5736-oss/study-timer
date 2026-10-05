/// 동기화(여러 기기 연동) 설정.
///
/// 두 값이 비어 있으면 앱은 이 기기 안에만 기록을 저장합니다(로그인 없음).
/// Supabase 프로젝트를 만든 뒤 Project Settings > API 화면의
/// "Project URL"과 "Publishable key"(또는 anon key)를 붙여 넣으면
/// 로그인 화면이 나타나고 기기 간 동기화가 켜집니다.
class AppConfig {
  static const supabaseUrl = '';
  static const supabasePublishableKey = '';

  static bool get syncEnabled =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
