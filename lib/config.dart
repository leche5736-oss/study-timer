/// 동기화(여러 기기 연동) 설정.
///
/// 기본으로 연결할 Supabase 프로젝트. 이 값이 있으면 처음 켤 때 주소·키를
/// 넣을 필요 없이 이메일과 비밀번호로 로그인만 하면 됩니다.
/// (Publishable key는 앱에 넣어 쓰는 공개용 키입니다. 기록은 로그인한 본인만
/// 읽고 쓸 수 있게 supabase/schema.sql의 규칙이 막아 줍니다.)
/// 설정 화면에서 다른 프로젝트로 바꾸거나 동기화를 끌 수 있습니다.
class AppConfig {
  static const supabaseUrl = 'https://ajezltnahkghivyispgk.supabase.co';
  static const supabasePublishableKey =
      'sb_publishable_tB217cPlMsup-7UCTpEDbw_FU_c0cZt';

  static bool get syncEnabled =>
      supabaseUrl.isNotEmpty && supabasePublishableKey.isNotEmpty;
}
