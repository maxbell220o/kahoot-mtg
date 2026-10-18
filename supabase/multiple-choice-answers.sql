alter table public.quiz_answers
  drop constraint if exists quiz_answers_answer_index_check;

alter table public.quiz_answers
  add constraint quiz_answers_answer_index_check
  check (answer_index between 0 and 5);

alter table public.quiz_answers
  drop constraint if exists quiz_answers_player_id_question_index_key;

alter table public.quiz_answers
  add constraint quiz_answers_player_id_question_index_answer_index_key
  unique (player_id, question_index, answer_index);

drop function if exists public.submit_quiz_answer(text, uuid, integer);

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

  if exists (
    select 1 from public.quiz_answers
    where player_id = v_player.id and question_index = v_game.current_question
  ) then
    select bool_and(is_correct) into v_correct
    from public.quiz_answers
    where player_id = v_player.id and question_index = v_game.current_question;
    select * into v_player from public.quiz_players where id = v_player.id;
    return jsonb_build_object('is_correct', v_correct, 'score', v_player.score);
  end if;

  insert into public.quiz_answers (game_id, player_id, question_index, answer_index, is_correct)
  select v_game.id, v_player.id, v_game.current_question, selected.answer_index, v_correct
  from unnest(v_submitted) as selected(answer_index);

  if v_correct then
    update public.quiz_players set score = score + 1 where id = v_player.id;
  end if;

  select * into v_player from public.quiz_players where id = p_player_id;
  return jsonb_build_object('is_correct', v_correct, 'score', v_player.score);
end;
$$;

revoke all on function public.submit_quiz_answer(text, uuid, integer[]) from public;
grant execute on function public.submit_quiz_answer(text, uuid, integer[]) to anon, authenticated;
