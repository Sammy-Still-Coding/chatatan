-- ChaTatan EXP and one-time streak milestone rewards.
-- Run once in Supabase SQL Editor, after the existing community/AI SQL.

create table if not exists public.gamification_reward_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.users(id) on delete cascade,
  reward_key text not null,
  reward_type text not null,
  amount integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, reward_key)
);

alter table public.gamification_reward_ledger enable row level security;
drop policy if exists "users read own reward ledger" on public.gamification_reward_ledger;
create policy "users read own reward ledger" on public.gamification_reward_ledger
  for select to authenticated using (user_id = auth.uid());

-- Stores an exact reward amount. This is important for votes: the author gets
-- the correct score after an upvote is changed or removed, with no double EXP.
create or replace function public.sync_gamification_reward(
  p_user_id uuid,
  p_reward_key text,
  p_reward_type text,
  p_amount integer,
  p_reference_id bigint default null
) returns void
language plpgsql security definer set search_path = public as $$
declare
  v_old_amount integer := 0;
  v_delta integer;
begin
  insert into public.user_gamification (user_id)
  values (p_user_id)
  on conflict (user_id) do nothing;

  select amount into v_old_amount
  from public.gamification_reward_ledger
  where user_id = p_user_id and reward_key = p_reward_key
  for update;

  v_old_amount := coalesce(v_old_amount, 0);
  v_delta := greatest(0, p_amount) - v_old_amount;
  if v_delta = 0 then return; end if;

  insert into public.gamification_reward_ledger
    (user_id, reward_key, reward_type, amount)
  values (p_user_id, p_reward_key, p_reward_type, greatest(0, p_amount))
  on conflict (user_id, reward_key) do update
    set amount = excluded.amount, reward_type = excluded.reward_type,
        updated_at = now();

  update public.user_gamification
  set total_points = greatest(0, total_points + v_delta), updated_at = now()
  where user_id = p_user_id;

  insert into public.point_transactions
    (user_id, amount, transaction_type, reference_type, reference_id)
  values (p_user_id, v_delta, p_reward_type, 'GAMIFICATION', p_reference_id);
end;
$$;

-- Never grant an old milestone again. Existing users who have already reached
-- a milestone are seeded as claimed before the new daily claim function runs.
insert into public.gamification_reward_ledger
  (user_id, reward_key, reward_type, amount)
select ug.user_id, 'STREAK_CAPACITY:' || milestone, 'STREAK_CAPACITY', 0
from public.user_gamification ug
cross join lateral (
  select unnest(array[10, 30, 50]) as milestone
  union all
  select value from generate_series(100, greatest(100, (ug.longest_streak / 100) * 100), 100) value
) milestones
where ug.longest_streak >= milestones.milestone
on conflict (user_id, reward_key) do nothing;

create or replace function public.claim_learning_streak()
returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  v_user_id uuid := auth.uid();
  -- Supabase normally uses UTC. ChaTatan streak follows the user's Indonesian
  -- product timezone, so the boundary is exactly 00:00 WIB.
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
  v_last_date date;
  v_streak integer;
  v_longest integer;
  v_milestone integer;
  v_capacity_bonus integer;
  v_daily_points integer := 5;
  v_milestone_points integer;
  v_capacity_awarded integer := 0;
begin
  if v_user_id is null then raise exception 'Tidak terautentikasi'; end if;

  insert into public.user_gamification (user_id)
  values (v_user_id) on conflict (user_id) do nothing;

  select last_streak_date, current_streak, longest_streak
    into v_last_date, v_streak, v_longest
  from public.user_gamification where user_id = v_user_id for update;

  if v_last_date = v_today then
    return jsonb_build_object('claimed', false, 'streak', v_streak,
      'points', 0, 'message', 'Streak hari ini sudah tercatat.');
  end if;

  v_streak := case when v_last_date = v_today - 1 then v_streak + 1 else 1 end;
  v_longest := greatest(v_longest, v_streak);
  update public.user_gamification
  set current_streak = v_streak, longest_streak = v_longest,
      last_streak_date = v_today, updated_at = now()
  where user_id = v_user_id;

  perform public.sync_gamification_reward(
    v_user_id, 'STREAK_DAY:' || v_today, 'STREAK_DAILY', v_daily_points, null);
  insert into public.user_streaks
    (user_id, activity_date, streak_count, point_reward)
  values (v_user_id, v_today, v_streak, v_daily_points)
  on conflict do nothing;

  -- 10/30/50 have fixed rewards; then every 100-day milestone gets the same
  -- capacity bonus and higher EXP. The ledger means repeating a broken streak
  -- cannot increase token capacity a second time.
  foreach v_milestone in array array[10, 30, 50] loop
    if v_streak >= v_milestone then
      v_capacity_bonus := case v_milestone when 10 then 10 when 30 then 15 else 25 end;
      v_milestone_points := case v_milestone when 10 then 15 when 30 then 25 else 40 end;
      if not exists (select 1 from public.gamification_reward_ledger
                     where user_id = v_user_id and reward_key = 'STREAK_CAPACITY:' || v_milestone) then
        insert into public.gamification_reward_ledger (user_id, reward_key, reward_type, amount)
        values (v_user_id, 'STREAK_CAPACITY:' || v_milestone, 'STREAK_CAPACITY', 0);
        update public.user_gamification
        set ai_weekly_capacity = ai_weekly_capacity + v_capacity_bonus
        where user_id = v_user_id;
        v_capacity_awarded := v_capacity_awarded + v_capacity_bonus;
      end if;
      perform public.sync_gamification_reward(v_user_id,
        'STREAK_EXP:' || v_milestone, 'STREAK_MILESTONE', v_milestone_points, v_milestone);
    end if;
  end loop;

  for v_milestone in 100..v_streak loop
    continue when mod(v_milestone, 100) <> 0;
    if not exists (select 1 from public.gamification_reward_ledger
                   where user_id = v_user_id and reward_key = 'STREAK_CAPACITY:' || v_milestone) then
      insert into public.gamification_reward_ledger (user_id, reward_key, reward_type, amount)
      values (v_user_id, 'STREAK_CAPACITY:' || v_milestone, 'STREAK_CAPACITY', 0);
      update public.user_gamification
      set ai_weekly_capacity = ai_weekly_capacity + 25 where user_id = v_user_id;
      v_capacity_awarded := v_capacity_awarded + 25;
    end if;
    perform public.sync_gamification_reward(v_user_id,
      'STREAK_EXP:' || v_milestone, 'STREAK_MILESTONE', 60, v_milestone);
  end loop;

  return jsonb_build_object('claimed', true, 'streak', v_streak,
    'points', v_daily_points, 'capacity_added', v_capacity_awarded);
end;
$$;

create or replace function public.sync_forum_post_exp(p_post_id bigint)
returns void language plpgsql security definer set search_path = public as $$
declare
  v_author uuid;
  v_likes integer;
  v_dislikes integer;
  v_passed_files integer;
  v_relevance numeric;
  v_amount integer;
begin
  select user_id, like_count, dislike_count into v_author, v_likes, v_dislikes
  from public.forum_posts where id = p_post_id;
  if v_author is null then return; end if;
  select count(*), avg(relevance_score) into v_passed_files, v_relevance
  from public.forum_attachments
  where post_id = p_post_id and curation_status = 'PASSED';

  if v_passed_files > 0 then
    -- Main EXP source: relevance/curation (0..80) + community validation (4/upvote).
    v_amount := round(coalesce(v_relevance, 0) * 0.8)::integer
                + greatest(coalesce(v_likes, 0) - coalesce(v_dislikes, 0), 0) * 4;
  else
    -- Lowest EXP source: community upvotes on an ordinary discussion.
    v_amount := greatest(coalesce(v_likes, 0) - coalesce(v_dislikes, 0), 0);
  end if;
  perform public.sync_gamification_reward(v_author, 'FORUM_POST:' || p_post_id,
    case when v_passed_files > 0 then 'FORUM_FILE_CONTRIBUTION' else 'FORUM_UPVOTE' end,
    v_amount, p_post_id);
end;
$$;

create or replace function public.trg_sync_forum_post_exp_from_post()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.sync_forum_post_exp(new.id);
  return new;
end;
$$;

create or replace function public.trg_sync_forum_post_exp_from_attachment()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  perform public.sync_forum_post_exp(new.post_id);
  return new;
end;
$$;

drop trigger if exists forum_post_exp_from_votes on public.forum_posts;
create trigger forum_post_exp_from_votes after update of like_count, dislike_count
on public.forum_posts for each row execute function public.trg_sync_forum_post_exp_from_post();

drop trigger if exists forum_post_exp_from_attachments on public.forum_attachments;
create trigger forum_post_exp_from_attachments after insert or update of curation_status, relevance_score
on public.forum_attachments for each row execute function public.trg_sync_forum_post_exp_from_attachment();

-- Backfill current posts once. Later changes are handled by triggers.
do $$ declare p record; begin
  for p in select id from public.forum_posts loop
    perform public.sync_forum_post_exp(p.id);
  end loop;
end $$;

grant execute on function public.claim_learning_streak() to authenticated;
