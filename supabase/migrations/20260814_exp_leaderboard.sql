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
  select
    u.id,
    coalesce(nullif(u.username, ''), 'Pengguna'),
    u.avatar_url,
    g.total_points,
    row_number() over (order by g.total_points desc, u.created_at asc)::bigint
  from public.user_gamification g
  join public.users u on u.id = g.user_id
  where u.status = 'active'
  order by g.total_points desc, u.created_at asc
  limit greatest(1, least(coalesce(p_limit, 3), 50));
$$;

grant execute on function public.get_exp_leaderboard(integer) to authenticated;
