-- Persist AI attachment previews and secure device-token registration.
alter table public.ai_messages
  add column if not exists attachment_name text,
  add column if not exists attachment_locator text;

create index if not exists idx_ai_messages_attachment
  on public.ai_messages (conversation_id)
  where attachment_locator is not null;

drop index if exists public.uq_user_devices_user_push_token;
create unique index uq_user_devices_user_push_token
  on public.user_devices (user_id, push_token);

alter table public.user_devices enable row level security;

drop policy if exists "Users manage own device tokens" on public.user_devices;
create policy "Users manage own device tokens"
  on public.user_devices for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());
