-- Preserve the username selected on the registration form.
-- This runs after any existing profile-creation trigger on auth.users.
create or replace function public.apply_signup_username()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  requested_username text := trim(coalesce(new.raw_user_meta_data ->> 'username', ''));
begin
  if requested_username = '' then
    return new;
  end if;

  if requested_username !~ '^[A-Za-z0-9_]{3,24}$' then
    raise exception 'Username harus 3–24 karakter dan hanya boleh huruf, angka, atau underscore.';
  end if;

  insert into public.users (id, username, email)
  values (new.id, requested_username, coalesce(new.email, ''))
  on conflict (id) do update
    set username = excluded.username,
        email = excluded.email,
        updated_at = now();
  return new;
end;
$$;

drop trigger if exists zz_apply_signup_username on auth.users;
create trigger zz_apply_signup_username
after insert on auth.users
for each row execute procedure public.apply_signup_username();
