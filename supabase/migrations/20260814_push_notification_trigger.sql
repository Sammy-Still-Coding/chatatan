-- Deliver every newly-created in-app notification through the protected
-- send-push-notification Edge Function.  Before applying this migration, add
-- the same value as PUSH_WEBHOOK_SECRET to Supabase Vault with this name:
--
-- select vault.create_secret('<PUSH_WEBHOOK_SECRET>',
--   'chatatan_push_webhook_secret',
--   'Secret for ChaTatan push delivery trigger');

create extension if not exists pg_net;

create or replace function public.dispatch_push_notification()
returns trigger
language plpgsql
security definer
set search_path = public, vault, net
as $push$
declare
  webhook_secret text;
begin
  select decrypted_secret
    into webhook_secret
  from vault.decrypted_secrets
  where name = 'chatatan_push_webhook_secret'
  limit 1;

  if webhook_secret is null then
    raise exception 'Push webhook secret belum tersedia di Supabase Vault';
  end if;

  perform net.http_post(
    url := 'https://getipwvkqbhujoeqgxmz.supabase.co/functions/v1/send-push-notification',
    body := jsonb_build_object(
      'type', 'INSERT',
      'table', 'notifications',
      'schema', 'public',
      'record', to_jsonb(new),
      'old_record', null
    ),
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'x-push-webhook-secret', webhook_secret
    ),
    timeout_milliseconds := 10000
  );

  return new;
end;
$push$;

drop trigger if exists trg_dispatch_push_notification on public.notifications;
create trigger trg_dispatch_push_notification
after insert on public.notifications
for each row execute function public.dispatch_push_notification();
