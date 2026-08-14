-- ChaTatan pet catalog + secure daily EXP bonus.
-- Run once in Supabase SQL Editor. Safe to re-run.

alter table public.pets
  add column if not exists daily_exp_reward integer not null default 10;

create unique index if not exists uq_pets_name_ci
  on public.pets (lower(name));

insert into public.pets (name, description, image_url, max_level, min_streak, daily_exp_reward)
values
  ('Mochi', 'Anjing robot ramah yang menemani sesi belajar harian.', 'assets/images/chatatan_study_pet.png', 100, 0, 10),
  ('Kucing', 'Kucing robot yang teliti mencatat setiap kemajuanmu.', 'assets/images/pet_kucing.png', 100, 0, 10),
  ('Piko', 'Penguin robot energik untuk sesi belajar singkat.', 'assets/images/pet_piko.png', 100, 10, 10),
  ('Lumi', 'Kelinci robot ceria yang membantu menjaga fokus.', 'assets/images/pet_lumi.png', 100, 30, 10),
  ('Nori', 'Rubah pengetahuan dengan bonus EXP lebih besar.', 'assets/images/pet_nori.png', 100, 50, 15),
  ('Astra', 'Burung hantu legendaris dengan bonus EXP tertinggi.', 'assets/images/pet_astra.png', 100, 100, 18)
on conflict do nothing;

update public.pets
set image_url = case lower(name)
      when 'mochi' then 'assets/images/chatatan_study_pet.png'
      when 'kucing' then 'assets/images/pet_kucing.png'
      when 'piko' then 'assets/images/pet_piko.png'
      when 'lumi' then 'assets/images/pet_lumi.png'
      when 'nori' then 'assets/images/pet_nori.png'
      when 'astra' then 'assets/images/pet_astra.png'
      else image_url
    end,
    min_streak = case lower(name)
      when 'mochi' then 0
      when 'kucing' then 0
      when 'piko' then 10
      when 'lumi' then 30
      when 'nori' then 50
      when 'astra' then 100
      else min_streak
    end,
    daily_exp_reward = case lower(name)
      when 'nori' then 15
      when 'astra' then 18
      else 10
    end
where lower(name) in ('mochi', 'kucing', 'piko', 'lumi', 'nori', 'astra');

create table if not exists public.pet_daily_exp_claims (
  user_id uuid not null references auth.users(id) on delete cascade,
  claim_date date not null,
  pet_id bigint not null references public.pets(id) on delete cascade,
  exp_reward integer not null,
  created_at timestamptz not null default now(),
  primary key (user_id, claim_date)
);

alter table public.pet_daily_exp_claims enable row level security;

drop policy if exists "Users can read own pet exp claims"
  on public.pet_daily_exp_claims;
create policy "Users can read own pet exp claims"
  on public.pet_daily_exp_claims
  for select
  to authenticated
  using (auth.uid() = user_id);

create or replace function public.claim_active_pet_daily_exp()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_pet_id bigint;
  v_reward integer;
  v_today date := (now() at time zone 'Asia/Jakarta')::date;
  v_inserted integer := 0;
begin
  if v_user_id is null then
    raise exception 'Tidak terautentikasi';
  end if;

  select ug.pet_id, coalesce(p.daily_exp_reward, 10)
    into v_pet_id, v_reward
  from public.user_gamification ug
  join public.pets p on p.id = ug.pet_id
  where ug.user_id = v_user_id;

  if v_pet_id is null then
    return jsonb_build_object('claimed', false, 'reward', 0);
  end if;

  insert into public.pet_daily_exp_claims
    (user_id, claim_date, pet_id, exp_reward)
  values
    (v_user_id, v_today, v_pet_id, v_reward)
  on conflict (user_id, claim_date) do nothing;

  get diagnostics v_inserted = row_count;
  if v_inserted = 0 then
    return jsonb_build_object('claimed', false, 'reward', 0);
  end if;

  update public.user_pets
  set experience = experience + v_reward,
      total_experience = total_experience + v_reward,
      updated_at = now()
  where user_id = v_user_id and pet_id = v_pet_id;

  return jsonb_build_object('claimed', true, 'reward', v_reward, 'pet_id', v_pet_id);
end;
$$;

revoke all on function public.claim_active_pet_daily_exp() from public;
grant execute on function public.claim_active_pet_daily_exp() to authenticated;
