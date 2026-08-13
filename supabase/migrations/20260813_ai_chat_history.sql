-- Per-account ChaTatan AI history.
-- Run once in Supabase SQL Editor.

create index if not exists idx_ai_conversations_user_updated
  on public.ai_conversations (user_id, updated_at desc)
  where deleted_at is null;
create index if not exists idx_ai_messages_conversation_created
  on public.ai_messages (conversation_id, created_at);

alter table public.ai_conversations enable row level security;
alter table public.ai_messages enable row level security;

drop policy if exists "Users manage own AI conversations" on public.ai_conversations;
create policy "Users manage own AI conversations"
  on public.ai_conversations for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

drop policy if exists "Users read own AI messages" on public.ai_messages;
create policy "Users read own AI messages"
  on public.ai_messages for select to authenticated
  using (
    exists (
      select 1 from public.ai_conversations c
      where c.id = ai_messages.conversation_id and c.user_id = auth.uid()
    )
  );

drop policy if exists "Users insert own AI messages" on public.ai_messages;
create policy "Users insert own AI messages"
  on public.ai_messages for insert to authenticated
  with check (
    exists (
      select 1 from public.ai_conversations c
      where c.id = ai_messages.conversation_id and c.user_id = auth.uid()
    )
    and (user_id is null or user_id = auth.uid())
  );
