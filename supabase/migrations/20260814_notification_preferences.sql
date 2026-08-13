alter table public.user_settings
  add column if not exists notify_private_messages boolean not null default true,
  add column if not exists notify_group_messages boolean not null default true,
  add column if not exists notify_forum_replies boolean not null default true;
