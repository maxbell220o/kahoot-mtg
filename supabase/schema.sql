create table public.quizzes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (length(trim(title)) between 1 and 100),
  questions jsonb not null check (jsonb_typeof(questions) = 'array' and jsonb_array_length(questions) > 0),
  created_at timestamptz not null default now()
);

alter table public.quizzes enable row level security;

create policy "Teachers manage their own quizzes"
  on public.quizzes
  for all
  to authenticated
  using (owner_id = (select auth.uid()))
  with check (owner_id = (select auth.uid()));

grant select, insert, update, delete on public.quizzes to authenticated;

create table public.quiz_games (
  id uuid primary key default gen_random_uuid(),
  quiz_id uuid not null references public.quizzes(id) on delete cascade,
  owner_id uuid not null references auth.users(id) on delete cascade,
  code text not null unique check (code ~ '^[0-9]{6}$'),
  status text not null default 'waiting' check (status in ('waiting', 'question', 'finished')),
  current_question integer not null default -1,
  created_at timestamptz not null default now()
);

create table public.quiz_players (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.quiz_games(id) on delete cascade,
  name text not null check (length(trim(name)) between 1 and 24),
  score integer not null default 0 check (score >= 0),
  joined_at timestamptz not null default now(),
  unique (game_id, name)
);

create table public.quiz_answers (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.quiz_games(id) on delete cascade,
  player_id uuid not null references public.quiz_players(id) on delete cascade,
  question_index integer not null check (question_index >= 0),
  answer_index integer not null check (answer_index between 0 and 5),
  is_correct boolean not null,
  answered_at timestamptz not null default now(),
  unique (player_id, question_index)
);

alter table public.quiz_games enable row level security;
alter table public.quiz_players enable row level security;
alter table public.quiz_answers enable row level security;

create policy "Teachers read their own games"
  on public.quiz_games
  for select
  to authenticated
  using (owner_id = (select auth.uid()));

revoke all on public.quiz_games, public.quiz_players, public.quiz_answers from anon, authenticated;

create or replace function public.start_quiz_game(p_quiz_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_code text;
begin
  if auth.uid() is null then
    raise exception 'Bitte melde dich als Lehrkraft an.';
  end if;

  if not exists (
    select 1 from public.quizzes
    where id = p_quiz_id and owner_id = auth.uid()
  ) then
    raise exception 'Quiz nicht gefunden oder kein Zugriff.';
  end if;

  loop
    v_code := lpad(floor(random() * 1000000)::text, 6, '0');
    exit when not exists (select 1 from public.quiz_games where code = v_code);
  end loop;

  insert into public.quiz_games (quiz_id, owner_id, code)
  values (p_quiz_id, auth.uid(), v_code);

  return v_code;
end;
$$;

create or replace function public.advance_quiz_game(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game public.quiz_games%rowtype;
  v_question_count integer;
  v_result jsonb;
begin
  select * into v_game
  from public.quiz_games
  where code = p_code and owner_id = auth.uid()
  for update;

  if not found then
    raise exception 'Spiel nicht gefunden oder kein Zugriff.';
  end if;

  select jsonb_array_length(questions) into v_question_count
  from public.quizzes where id = v_game.quiz_id;

  if v_game.status = 'waiting' then
    update public.quiz_games set status = 'question', current_question = 0 where id = v_game.id;
  elsif v_game.status = 'question' and v_game.current_question + 1 < v_question_count then
    update public.quiz_games set current_question = current_question + 1 where id = v_game.id;
  elsif v_game.status = 'question' then
    update public.quiz_games set status = 'finished' where id = v_game.id;
  else
    raise exception 'Das Quiz ist bereits beendet.';
  end if;

  select jsonb_build_object(
    'status', status,
    'current_question', current_question
  ) into v_result
  from public.quiz_games where code = p_code;

  return v_result;
end;
$$;

create or replace function public.get_teacher_game_state(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  select jsonb_build_object(
    'code', g.code,
    'status', g.status,
    'current_question', g.current_question,
    'question_count', jsonb_array_length(q.questions),
    'players', coalesce((
      select jsonb_agg(jsonb_build_object('name', p.name, 'score', p.score) order by p.score desc, p.joined_at)
      from public.quiz_players p where p.game_id = g.id
    ), '[]'::jsonb)
  ) into v_result
  from public.quiz_games g
  join public.quizzes q on q.id = g.quiz_id
  where g.code = p_code and g.owner_id = auth.uid();

  if v_result is null then
    raise exception 'Spiel nicht gefunden oder kein Zugriff.';
  end if;
  return v_result;
end;
$$;

create or replace function public.get_public_quiz_display(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
begin
  select jsonb_build_object(
    'code', g.code,
    'title', q.title,
    'status', g.status,
    'current_question', g.current_question,
    'question_count', jsonb_array_length(q.questions),
    'question', case when g.status = 'question' then
      jsonb_build_object(
        'prompt', q.questions -> g.current_question -> 'prompt',
        'answers', q.questions -> g.current_question -> 'answers'
      )
      else null
    end,
    'players', coalesce((
      select jsonb_agg(jsonb_build_object('name', p.name, 'score', p.score) order by p.score desc, p.joined_at)
      from public.quiz_players p where p.game_id = g.id
    ), '[]'::jsonb)
  ) into v_result
  from public.quiz_games g
  join public.quizzes q on q.id = g.quiz_id
  where g.code = p_code;

  if v_result is null then
    raise exception 'Dieses Quiz wurde nicht gefunden.';
  end if;
  return v_result;
end;
$$;

create or replace function public.join_quiz_game(p_code text, p_name text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game public.quiz_games%rowtype;
  v_player_id uuid;
  v_title text;
begin
  if length(trim(coalesce(p_name, ''))) not between 1 and 24 then
    raise exception 'Der Name muss zwischen 1 und 24 Zeichen lang sein.';
  end if;

  select * into v_game from public.quiz_games where code = p_code for update;
  if not found or v_game.status <> 'waiting' then
    raise exception 'Dieses Quiz wurde nicht gefunden oder ist bereits gestartet.';
  end if;

  select title into v_title from public.quizzes where id = v_game.quiz_id;
  insert into public.quiz_players (game_id, name)
  values (v_game.id, trim(p_name))
  returning id into v_player_id;

  return jsonb_build_object('player_id', v_player_id, 'title', v_title);
exception
  when unique_violation then
    raise exception 'Dieser Name ist in diesem Quiz bereits vergeben. Bitte wähle einen anderen.';
end;
$$;

create or replace function public.get_quiz_game_state(p_code text, p_player_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game public.quiz_games%rowtype;
  v_quiz public.quizzes%rowtype;
  v_player public.quiz_players%rowtype;
  v_question jsonb;
  v_answer public.quiz_answers%rowtype;
begin
  select * into v_game from public.quiz_games where code = p_code;
  if not found then
    raise exception 'Dieses Quiz wurde nicht gefunden.';
  end if;

  select * into v_player from public.quiz_players
  where id = p_player_id and game_id = v_game.id;
  if not found then
    raise exception 'Spieler nicht gefunden. Bitte tritt dem Quiz erneut bei.';
  end if;

  select * into v_quiz from public.quizzes where id = v_game.quiz_id;
  if v_game.status = 'question' then
    v_question := v_quiz.questions -> v_game.current_question;
  end if;

  select * into v_answer from public.quiz_answers
  where player_id = v_player.id and question_index = v_game.current_question;

  return jsonb_build_object(
    'title', v_quiz.title,
    'status', v_game.status,
    'current_question', v_game.current_question,
    'question_count', jsonb_array_length(v_quiz.questions),
    'question', case when v_question is null then null else
      jsonb_build_object('prompt', v_question -> 'prompt', 'answers', v_question -> 'answers') end,
    'score', v_player.score,
    'has_answered', v_answer.id is not null,
    'is_correct', case when v_answer.id is null then null else v_answer.is_correct end,
    'leaderboard', case when v_game.status = 'finished' then coalesce((
      select jsonb_agg(jsonb_build_object('name', p.name, 'score', p.score) order by p.score desc, p.joined_at)
      from public.quiz_players p where p.game_id = v_game.id
    ), '[]'::jsonb) else null end
  );
end;
$$;

create or replace function public.submit_quiz_answer(p_code text, p_player_id uuid, p_answer_index integer)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_game public.quiz_games%rowtype;
  v_quiz public.quizzes%rowtype;
  v_player public.quiz_players%rowtype;
  v_correct boolean;
  v_rows integer;
begin
  select * into v_game from public.quiz_games where code = p_code for update;
  if not found or v_game.status <> 'question' then
    raise exception 'Gerade ist keine Frage geöffnet.';
  end if;

  select * into v_player from public.quiz_players
  where id = p_player_id and game_id = v_game.id;
  if not found then
    raise exception 'Spieler nicht gefunden. Bitte tritt dem Quiz erneut bei.';
  end if;

  select * into v_quiz from public.quizzes where id = v_game.quiz_id;
  if p_answer_index is null
    or p_answer_index < 0
    or p_answer_index >= jsonb_array_length(v_quiz.questions -> v_game.current_question -> 'answers') then
    raise exception 'Diese Antwort gibt es bei der aktuellen Frage nicht.';
  end if;
  v_correct := ((v_quiz.questions -> v_game.current_question ->> 'correctAnswer')::integer = p_answer_index);

  insert into public.quiz_answers (game_id, player_id, question_index, answer_index, is_correct)
  values (v_game.id, v_player.id, v_game.current_question, p_answer_index, v_correct)
  on conflict (player_id, question_index) do nothing;
  get diagnostics v_rows = row_count;

  if v_rows = 1 and v_correct then
    update public.quiz_players set score = score + 1 where id = v_player.id;
  else
    select is_correct into v_correct from public.quiz_answers
    where player_id = v_player.id and question_index = v_game.current_question;
  end if;

  select * into v_player from public.quiz_players where id = p_player_id;
  return jsonb_build_object('is_correct', v_correct, 'score', v_player.score);
end;
$$;

revoke all on function public.start_quiz_game(uuid) from public;
revoke all on function public.advance_quiz_game(text) from public;
revoke all on function public.get_teacher_game_state(text) from public;
revoke all on function public.get_public_quiz_display(text) from public;
revoke all on function public.join_quiz_game(text, text) from public;
revoke all on function public.get_quiz_game_state(text, uuid) from public;
revoke all on function public.submit_quiz_answer(text, uuid, integer) from public;

grant execute on function public.start_quiz_game(uuid) to authenticated;
grant execute on function public.advance_quiz_game(text) to authenticated;
grant execute on function public.get_teacher_game_state(text) to authenticated;
grant execute on function public.get_public_quiz_display(text) to anon, authenticated;
grant execute on function public.join_quiz_game(text, text) to anon, authenticated;
grant execute on function public.get_quiz_game_state(text, uuid) to anon, authenticated;
grant execute on function public.submit_quiz_answer(text, uuid, integer) to anon, authenticated;
