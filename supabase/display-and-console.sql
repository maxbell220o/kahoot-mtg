create or replace function public.get_public_quiz_display(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_result jsonb;
  v_game public.quiz_games%rowtype;
  v_player_count integer;
  v_answered_count integer;
  v_answer_revealed boolean;
begin
  select * into v_game from public.quiz_games where code = p_code;
  if not found then
    raise exception 'Dieses Quiz wurde nicht gefunden.';
  end if;

  select count(*) into v_player_count from public.quiz_players where game_id = v_game.id;
  select count(distinct player_id) into v_answered_count
  from public.quiz_answers
  where game_id = v_game.id and question_index = v_game.current_question;
  v_answer_revealed := v_game.status = 'question' and (
    clock_timestamp() >= coalesce(v_game.question_started_at, clock_timestamp()) + interval '30 seconds'
    or (v_player_count > 0 and v_answered_count >= v_player_count)
  );

  select jsonb_build_object(
    'code', g.code,
    'title', q.title,
    'status', g.status,
    'current_question', g.current_question,
    'question_count', jsonb_array_length(q.questions),
    'deadline', case when g.status = 'question' then g.question_started_at + interval '30 seconds' else null end,
    'answer_revealed', v_answer_revealed,
    'answered_count', v_answered_count,
    'correct_answers', case when v_answer_revealed then
      case when jsonb_typeof(q.questions -> g.current_question -> 'correctAnswers') = 'array'
        then q.questions -> g.current_question -> 'correctAnswers'
        else jsonb_build_array((q.questions -> g.current_question ->> 'correctAnswer')::integer) end
      else null end,
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

revoke all on function public.get_public_quiz_display(text) from public;
grant execute on function public.get_public_quiz_display(text) to anon, authenticated;
