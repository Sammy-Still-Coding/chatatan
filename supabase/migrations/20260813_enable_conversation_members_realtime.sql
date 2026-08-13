-- Enables live read receipts ("Seen" and group reader avatars).
-- Safe to run once in the Supabase SQL Editor or through `supabase db push`.
do $$
begin
  if not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'conversation_members'
  ) then
    alter publication supabase_realtime add table public.conversation_members;
  end if;
end $$;
