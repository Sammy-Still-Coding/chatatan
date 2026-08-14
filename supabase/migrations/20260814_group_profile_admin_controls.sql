-- Secure group profile and admin controls for ChaTatan conversations.
-- Safe to run more than once from Supabase SQL Editor.

create or replace function public.update_group_profile(
  p_conversation_id bigint,
  p_title text default null,
  p_avatar_url text default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_allowed boolean;
begin
  if v_user_id is null then
    raise exception 'Tidak terautentikasi';
  end if;

  select
    c.conversation_type = 'GROUP'
    and (
      c.created_by = v_user_id
      or exists (
        select 1
        from public.conversation_members cm
        where cm.conversation_id = c.id
          and cm.user_id = v_user_id
          and cm.role = 'ADMIN'
      )
    )
  into v_allowed
  from public.conversations c
  where c.id = p_conversation_id;

  if coalesce(v_allowed, false) is false then
    raise exception 'Hanya owner atau admin yang dapat mengubah profil grup';
  end if;

  update public.conversations
  set title = case
        when nullif(trim(p_title), '') is null then title
        else trim(p_title)
      end,
      avatar_url = case
        when nullif(trim(p_avatar_url), '') is null then avatar_url
        else trim(p_avatar_url)
      end,
      updated_at = now()
  where id = p_conversation_id;
end;
$$;

create or replace function public.set_group_member_role(
  p_conversation_id bigint,
  p_user_id uuid,
  p_role text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user_id uuid := auth.uid();
  v_owner_id uuid;
begin
  if v_user_id is null then
    raise exception 'Tidak terautentikasi';
  end if;
  if p_role not in ('ADMIN', 'MEMBER') then
    raise exception 'Role tidak valid';
  end if;

  select created_by into v_owner_id
  from public.conversations
  where id = p_conversation_id and conversation_type = 'GROUP';

  if v_owner_id is null or v_owner_id <> v_user_id then
    raise exception 'Hanya owner yang dapat mengatur admin';
  end if;
  if p_user_id = v_owner_id then
    raise exception 'Role owner tidak dapat diubah';
  end if;

  update public.conversation_members
  set role = p_role
  where conversation_id = p_conversation_id
    and user_id = p_user_id;

  if not found then
    raise exception 'Anggota tidak ditemukan';
  end if;
end;
$$;

revoke all on function public.update_group_profile(bigint, text, text) from public;
revoke all on function public.set_group_member_role(bigint, uuid, text) from public;
grant execute on function public.update_group_profile(bigint, text, text) to authenticated;
grant execute on function public.set_group_member_role(bigint, uuid, text) to authenticated;
