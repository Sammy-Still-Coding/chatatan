create unique index if not exists uq_forum_reply_reactions
  on public.forum_reply_reactions (reply_id, user_id);

create or replace function public.get_my_liked_forum_replies(p_post_id bigint)
returns table (reply_id bigint)
language sql
security definer
set search_path = public
as $$
  select r.reply_id
  from public.forum_reply_reactions r
  join public.forum_replies fr on fr.id = r.reply_id
  where r.user_id = auth.uid()
    and r.reaction = 'LIKE'
    and fr.post_id = p_post_id;
$$;

create or replace function public.toggle_forum_reply_like(p_reply_id bigint)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_exists boolean;
  v_count integer;
begin
  if v_user_id is null then
    raise exception 'Unauthorized';
  end if;

  if not exists (
    select 1 from public.forum_replies where id = p_reply_id and deleted_at is null
  ) then
    raise exception 'Balasan tidak ditemukan';
  end if;

  select exists (
    select 1 from public.forum_reply_reactions
    where reply_id = p_reply_id and user_id = v_user_id and reaction = 'LIKE'
  ) into v_exists;

  if v_exists then
    delete from public.forum_reply_reactions
    where reply_id = p_reply_id and user_id = v_user_id;
  else
    insert into public.forum_reply_reactions (reply_id, user_id, reaction)
    values (p_reply_id, v_user_id, 'LIKE')
    on conflict (reply_id, user_id)
    do update set reaction = excluded.reaction;
  end if;

  select count(*)::integer into v_count
  from public.forum_reply_reactions
  where reply_id = p_reply_id and reaction = 'LIKE';

  update public.forum_replies set like_count = v_count where id = p_reply_id;
  return jsonb_build_object('liked', not v_exists, 'like_count', v_count);
end;
$$;

create or replace function public.get_exp_leaderboard(p_limit integer default 3)
returns table (
  user_id uuid,
  username text,
  avatar_url text,
  total_points bigint,
  rank bigint
)
language sql
security definer
set search_path = public
as $$
  select ranked.user_id, ranked.username, ranked.avatar_url,
         ranked.total_points, ranked.rank
  from (
    select u.id as user_id,
           coalesce(nullif(u.username, ''), 'Pengguna') as username,
           u.avatar_url,
           g.total_points,
           row_number() over (order by g.total_points desc, u.created_at asc)::bigint as rank
    from public.user_gamification g
    join public.users u on u.id = g.user_id
    where u.status = 'active'
  ) ranked
  order by ranked.rank
  limit greatest(1, least(coalesce(p_limit, 3), 100));
$$;

create or replace function public.get_my_exp_rank()
returns bigint
language sql
security definer
set search_path = public
as $$
  select ranked.rank
  from (
    select g.user_id,
           row_number() over (order by g.total_points desc, u.created_at asc)::bigint as rank
    from public.user_gamification g
    join public.users u on u.id = g.user_id
    where u.status = 'active'
  ) ranked
  where ranked.user_id = auth.uid();
$$;

grant execute on function public.get_my_liked_forum_replies(bigint) to authenticated;
grant execute on function public.toggle_forum_reply_like(bigint) to authenticated;
grant execute on function public.get_exp_leaderboard(integer) to authenticated;
grant execute on function public.get_my_exp_rank() to authenticated;
