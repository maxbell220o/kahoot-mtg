alter table public.quiz_answers
  drop constraint if exists quiz_answers_answer_index_check;

alter table public.quiz_answers
  add constraint quiz_answers_answer_index_check
  check (answer_index between 0 and 5);

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

revoke all on function public.submit_quiz_answer(text, uuid, integer) from public;
grant execute on function public.submit_quiz_answer(text, uuid, integer) to anon, authenticated;
