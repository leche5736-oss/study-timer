-- 공부 타이머 동기화용 테이블.
-- Supabase 대시보드 > SQL Editor 에 이 파일 내용을 통째로 붙여 넣고 Run 을 누르세요.

create table if not exists public.subjects (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  color bigint not null,
  deleted boolean not null default false,
  updated_at timestamptz not null
);

create table if not exists public.sessions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  subject_id uuid not null,
  started_at timestamptz not null,
  ended_at timestamptz not null,
  planned_minutes int not null,
  focus_seconds int not null,
  focus_rating int,
  recall_note text not null default '',
  question text not null default '',
  deleted boolean not null default false,
  updated_at timestamptz not null
);

-- 사용자마다 한 줄: 지금 돌아가는 타이머 상태.
create table if not exists public.timer_state (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  data jsonb not null,
  updated_at timestamptz not null
);

-- 본인 데이터만 읽고 쓸 수 있게 합니다.
alter table public.subjects enable row level security;
alter table public.sessions enable row level security;
alter table public.timer_state enable row level security;

create policy "own subjects" on public.subjects
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own sessions" on public.sessions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "own timer" on public.timer_state
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 다른 기기에서 바뀌면 바로 알림을 받도록 실시간 기능을 켭니다.
alter publication supabase_realtime add table public.subjects, public.sessions, public.timer_state;

-- 오래된 내용이 최신 내용을 덮어쓰지 않도록: 더 예전에 바뀐 값으로의 업데이트는 무시합니다.
create or replace function public.keep_newer() returns trigger
language plpgsql as $$
begin
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end $$;

create trigger subjects_keep_newer before update on public.subjects
  for each row execute function public.keep_newer();
create trigger sessions_keep_newer before update on public.sessions
  for each row execute function public.keep_newer();
create trigger timer_keep_newer before update on public.timer_state
  for each row execute function public.keep_newer();
