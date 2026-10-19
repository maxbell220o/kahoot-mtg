alter table public.quiz_games
  add column if not exists question_started_at timestamptz;

alter table public.quiz_answers
  add column if not exists points_earned integer not null default 0
  check (points_earned >= 0);

update public.quiz_games
set question_started_at = now()
where status = 'question' and question_started_at is null;

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
    'points_earned', coalesce(v_answer.points_earned, 0),
    'has_answered', v_answer.id is not null,
    'is_correct', case when v_answer.id is null then null else v_answer.is_correct end,
    'leaderboard', case when v_game.status = 'finished' then coalesce((
      select jsonb_agg(jsonb_build_object('name', p.name, 'score', p.score) order by p.score desc, p.joined_at)
      from public.quiz_players p where p.game_id = v_game.id
    ), '[]'::jsonb) else null end
  );
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
    update public.quiz_games
    set status = 'question', current_question = 0, question_started_at = clock_timestamp()
    where id = v_game.id;
  elsif v_game.status = 'question' and v_game.current_question + 1 < v_question_count then
    update public.quiz_games
    set current_question = current_question + 1, question_started_at = clock_timestamp()
    where id = v_game.id;
  elsif v_game.status = 'question' then
    update public.quiz_games set status = 'finished', question_started_at = null where id = v_game.id;
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

create or replace function public.submit_quiz_answer(p_code text, p_player_id uuid, p_answer_indices integer[])
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
  v_correct_answers jsonb;
  v_submitted integer[];
  v_expected integer[];
  v_correct boolean;
  v_points integer := 0;
  v_base_points integer;
  v_elapsed_seconds numeric;
  v_answer_points integer := 0;
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
  v_question := v_quiz.questions -> v_game.current_question;
  if jsonb_typeof(v_question -> 'correctAnswers') = 'array' then
    v_correct_answers := v_question -> 'correctAnswers';
  else
    v_correct_answers := jsonb_build_array((v_question ->> 'correctAnswer')::integer);
  end if;

  if coalesce(cardinality(p_answer_indices), 0) = 0 then
    raise exception 'Wähle mindestens eine Antwort aus.';
  end if;

  select array_agg(distinct selected.answer_index order by selected.answer_index)
  into v_submitted
  from unnest(p_answer_indices) as selected(answer_index);

  if cardinality(v_submitted) <> cardinality(p_answer_indices)
    or exists (
      select 1 from unnest(v_submitted) as selected(answer_index)
      where selected.answer_index < 0
        or selected.answer_index >= jsonb_array_length(v_question -> 'answers')
    ) then
    raise exception 'Eine ausgewählte Antwort gibt es bei dieser Frage nicht.';
  end if;

  select array_agg(correct.value::integer order by correct.value::integer)
  into v_expected
  from jsonb_array_elements_text(v_correct_answers) as correct(value);
  v_correct := v_submitted = v_expected;

  if v_correct then
    case coalesce(v_question ->> 'scoringMode', 'normal')
      when 'normal' then v_base_points := 1000;
      when 'double' then v_base_points := 2000;
      when 'none' then v_base_points := 0;
      else raise exception 'Die Punktewertung dieser Frage ist ungültig.';
    end case;
    v_elapsed_seconds := greatest(
      0,
      extract(epoch from (clock_timestamp() - coalesce(v_game.question_started_at, clock_timestamp())))
    );
    v_points := floor(v_base_points * greatest(0.5, 1 - least(v_elapsed_seconds, 30) / 60.0));
  end if;

  if exists (
    select 1 from public.quiz_answers
    where player_id = v_player.id and question_index = v_game.current_question
  ) then
    select bool_and(is_correct) into v_correct
    from public.quiz_answers
    where player_id = v_player.id and question_index = v_game.current_question;
    select max(points_earned) into v_answer_points
    from public.quiz_answers
    where player_id = v_player.id and question_index = v_game.current_question;
    select * into v_player from public.quiz_players where id = v_player.id;
    return jsonb_build_object(
      'is_correct', v_correct,
      'score', v_player.score,
      'points_earned', v_answer_points
    );
  end if;

  insert into public.quiz_answers (game_id, player_id, question_index, answer_index, is_correct, points_earned)
  select v_game.id, v_player.id, v_game.current_question, selected.answer_index, v_correct, v_points
  from unnest(v_submitted) as selected(answer_index);

  if v_correct and v_points > 0 then
    update public.quiz_players set score = score + v_points where id = v_player.id;
  end if;

  select * into v_player from public.quiz_players where id = p_player_id;
  return jsonb_build_object(
    'is_correct', v_correct,
    'score', v_player.score,
    'points_earned', v_points
  );
end;
$$;

revoke all on function public.get_quiz_game_state(text, uuid) from public;
revoke all on function public.advance_quiz_game(text) from public;
revoke all on function public.submit_quiz_answer(text, uuid, integer[]) from public;

grant execute on function public.get_quiz_game_state(text, uuid) to anon, authenticated;
grant execute on function public.advance_quiz_game(text) to authenticated;
grant execute on function public.submit_quiz_answer(text, uuid, integer[]) to anon, authenticated;
