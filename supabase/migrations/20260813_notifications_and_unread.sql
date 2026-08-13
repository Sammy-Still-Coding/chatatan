-- In-app notifications and unread counters for ChaTatan.
-- Run this file once in Supabase SQL Editor after the existing schema.

create index if not exists idx_notifications_user_unread_created
  on public.notifications (user_id, is_read, created_at desc);
create index if not exists idx_messages_conversation_sender_id
  on public.messages (conversation_id, sender_id, id);

alter table public.notifications enable row level security;

drop policy if exists "Users can read own notifications" on public.notifications;
create policy "Users can read own notifications"
  on public.notifications for select to authenticated
  using (user_id = auth.uid());

drop policy if exists "Users can update own notifications" on public.notifications;
create policy "Users can update own notifications"
  on public.notifications for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- The client must never create a notification for another account. Database
-- triggers below are SECURITY DEFINER and are the only writers.
drop policy if exists "No client notification inserts" on public.notifications;
create policy "No client notification inserts"
  on public.notifications for insert to authenticated
  with check (false);

create or replace function public.create_message_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_type text;
  v_room_title text;
  v_sender_name text;
  v_title text;
  v_body text;
begin
  select c.conversation_type, coalesce(nullif(c.title, ''), 'Grup')
    into v_type, v_room_title
  from public.conversations c
  where c.id = new.conversation_id;

  if v_type is null then return new; end if;
  select coalesce(nullif(u.username, ''), 'Seseorang')
    into v_sender_name
  from public.users u where u.id = new.sender_id;

  v_body := case
    when new.message_type = 'IMAGE' then 'Mengirim foto'
    when new.message_type = 'FILE' then 'Mengirim dokumen'
    else left(coalesce(new.content, 'Pesan baru'), 140)
  end;
  v_title := case
    when v_type = 'GROUP' then 'Pesan baru di ' || v_room_title
    else 'Pesan baru dari ' || coalesce(v_sender_name, 'Seseorang')
  end;

  insert into public.notifications (user_id, type, title, body, actor_user_id, entity_type, entity_id, data_json)
  select cm.user_id,
         case when v_type = 'GROUP' then 'GROUP_MESSAGE' else 'PRIVATE_MESSAGE' end,
         v_title, v_body, new.sender_id, 'CONVERSATION', new.conversation_id,
         jsonb_build_object('conversation_id', new.conversation_id, 'is_group', v_type = 'GROUP')
  from public.conversation_members cm
  where cm.conversation_id = new.conversation_id
    and cm.user_id <> new.sender_id;
  return new;
end;
$$;

drop trigger if exists trg_create_message_notifications on public.messages;
create trigger trg_create_message_notifications
after insert on public.messages
for each row execute function public.create_message_notifications();

create or replace function public.create_forum_reply_notification()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_owner uuid;
  v_post_title text;
  v_sender_name text;
begin
  select p.user_id, p.title into v_owner, v_post_title
  from public.forum_posts p where p.id = new.post_id;
  if v_owner is null or v_owner = new.user_id then return new; end if;
  select coalesce(nullif(u.username, ''), 'Seseorang') into v_sender_name
  from public.users u where u.id = new.user_id;

  insert into public.notifications (user_id, type, title, body, actor_user_id, entity_type, entity_id, data_json)
  values (
    v_owner, 'FORUM_REPLY', 'Balasan baru di diskusi Anda',
    coalesce(v_sender_name, 'Seseorang') || ': ' || left(coalesce(new.content, 'Mengirim balasan'), 130),
    new.user_id, 'FORUM_POST', new.post_id,
    jsonb_build_object('post_id', new.post_id, 'reply_id', new.id, 'post_title', v_post_title)
  );
  return new;
end;
$$;

drop trigger if exists trg_create_forum_reply_notification on public.forum_replies;
create trigger trg_create_forum_reply_notification
after insert on public.forum_replies
for each row execute function public.create_forum_reply_notification();

create or replace function public.get_my_conversation_unreads()
returns table (conversation_id bigint, unread_count bigint)
language sql
security definer
set search_path = public
as $$
  select cm.conversation_id, count(m.id)::bigint as unread_count
  from public.conversation_members cm
  join public.messages m on m.conversation_id = cm.conversation_id
  where cm.user_id = auth.uid()
    and m.sender_id is distinct from auth.uid()
    and m.deleted_at is null
    and m.id > coalesce(cm.last_read_message_id, 0)
  group by cm.conversation_id;
$$;

grant execute on function public.get_my_conversation_unreads() to authenticated;
