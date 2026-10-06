-- 공부 타이머 동기화용 테이블.
-- Supabase 대시보드 > SQL Editor 에 이 파일 내용을 통째로 붙여 넣고 Run 을 누르세요.
-- 여러 번 실행해도 괜찮습니다 (앱을 업데이트한 뒤 다시 실행하면 새 칸이 추가돼요).

create table if not exists public.subjects (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  name text not null,
  color bigint not null,
  sort_order int not null default 0,
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

drop policy if exists "own subjects" on public.subjects;
create policy "own subjects" on public.subjects
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "own sessions" on public.sessions;
create policy "own sessions" on public.sessions
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "own timer" on public.timer_state;
create policy "own timer" on public.timer_state
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- 다른 기기에서 바뀌면 바로 알림을 받도록 실시간 기능을 켭니다.
do $$
declare t text;
begin
  foreach t in array array['subjects', 'sessions', 'timer_state'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;

-- 오래된 내용이 최신 내용을 덮어쓰지 않도록: 더 예전에 바뀐 값으로의 업데이트는 무시합니다.
create or replace function public.keep_newer() returns trigger
language plpgsql as $$
begin
  if new.updated_at < old.updated_at then
    return old;
  end if;
  return new;
end $$;

drop trigger if exists subjects_keep_newer on public.subjects;
create trigger subjects_keep_newer before update on public.subjects
  for each row execute function public.keep_newer();
drop trigger if exists sessions_keep_newer on public.sessions;
create trigger sessions_keep_newer before update on public.sessions
  for each row execute function public.keep_newer();
drop trigger if exists timer_keep_newer on public.timer_state;
create trigger timer_keep_newer before update on public.timer_state
  for each row execute function public.keep_newer();

-- 0.4.0: 휴식 중 한 일 (이미 테이블을 만들었다면 이 줄만 다시 실행해도 됩니다)
alter table public.sessions add column if not exists rest_type text;

-- 0.5.0: 딴짓 앱 감지 기록
alter table public.sessions add column if not exists distractions int not null default 0;
alter table public.sessions add column if not exists distracted_seconds int not null default 0;
alter table public.subjects add column if not exists sort_order int not null default 0;
