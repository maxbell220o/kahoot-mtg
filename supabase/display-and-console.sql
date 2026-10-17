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

revoke all on function public.get_public_quiz_display(text) from public;
grant execute on function public.get_public_quiz_display(text) to anon, authenticated;
