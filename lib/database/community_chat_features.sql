-- Jalankan di Supabase SQL Editor untuk fitur chat/group Community.
ALTER TABLE public.conversations
  ADD COLUMN IF NOT EXISTS description text,
  ADD COLUMN IF NOT EXISTS avatar_url text;

CREATE TABLE IF NOT EXISTS public.user_presence (
  user_id uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
  is_online boolean NOT NULL DEFAULT false,
  last_seen_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.conversation_member_settings (
  conversation_id bigint NOT NULL REFERENCES public.conversations(id) ON DELETE CASCADE,
  user_id uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  nickname text,
  is_pinned boolean NOT NULL DEFAULT false,
  pinned_at timestamptz,
  PRIMARY KEY (conversation_id, user_id)
);

CREATE OR REPLACE FUNCTION public.limit_pinned_conversations()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.is_pinned AND NOT COALESCE(OLD.is_pinned, false)
     AND (SELECT count(*) FROM public.conversation_member_settings
          WHERE user_id = NEW.user_id AND is_pinned) >= 3 THEN
    RAISE EXCEPTION 'Maksimal 3 chat dapat dipin.';
  END IF;
  IF NEW.is_pinned THEN NEW.pinned_at := now(); END IF;
  RETURN NEW;
END; $$;
DROP TRIGGER IF EXISTS limit_pinned_conversations_trigger
  ON public.conversation_member_settings;
CREATE TRIGGER limit_pinned_conversations_trigger
BEFORE INSERT OR UPDATE OF is_pinned ON public.conversation_member_settings
FOR EACH ROW EXECUTE FUNCTION public.limit_pinned_conversations();

ALTER TABLE public.user_presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.conversation_member_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "presence_read_authenticated" ON public.user_presence;
CREATE POLICY "presence_read_authenticated" ON public.user_presence
FOR SELECT TO authenticated USING (true);
DROP POLICY IF EXISTS "presence_write_own" ON public.user_presence;
CREATE POLICY "presence_write_own" ON public.user_presence
FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "conversation_settings_own" ON public.conversation_member_settings;
CREATE POLICY "conversation_settings_own" ON public.conversation_member_settings
FOR ALL TO authenticated USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

-- Pembuat atau admin group boleh mengubah profil/nama group miliknya.
ALTER TABLE public.conversations ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "conversations_update_group_admin" ON public.conversations;
CREATE POLICY "conversations_update_group_admin" ON public.conversations
FOR UPDATE TO authenticated
USING (
  (conversation_type = 'GROUP' AND created_by = auth.uid())
  OR EXISTS (
    SELECT 1 FROM public.conversation_members
    WHERE conversation_members.conversation_id = conversations.id
      AND conversation_members.user_id = auth.uid()
      AND conversation_members.role = 'ADMIN'
  )
)
WITH CHECK (conversation_type = 'GROUP');

-- Menjamin private chat hanya memakai room dengan tepat dua anggota.
CREATE OR REPLACE FUNCTION public.get_or_create_private_conversation(target_user_id uuid)
RETURNS bigint
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  conversation_id bigint;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Tidak terautentikasi'; END IF;
  IF target_user_id = auth.uid() THEN RAISE EXCEPTION 'Tidak dapat chat dengan diri sendiri'; END IF;

  SELECT c.id INTO conversation_id
  FROM conversations c
  WHERE c.conversation_type = 'PRIVATE'
    AND EXISTS (SELECT 1 FROM conversation_members m WHERE m.conversation_id = c.id AND m.user_id = auth.uid())
    AND EXISTS (SELECT 1 FROM conversation_members m WHERE m.conversation_id = c.id AND m.user_id = target_user_id)
    AND 2 = (SELECT count(*) FROM conversation_members m WHERE m.conversation_id = c.id)
  LIMIT 1;
  IF conversation_id IS NOT NULL THEN RETURN conversation_id; END IF;

  INSERT INTO conversations (conversation_type, title, created_by)
  VALUES ('PRIVATE', 'Private Chat', auth.uid()) RETURNING id INTO conversation_id;
  INSERT INTO conversation_members (conversation_id, user_id)
  VALUES (conversation_id, auth.uid()), (conversation_id, target_user_id);
  RETURN conversation_id;
END; $$;
GRANT EXECUTE ON FUNCTION public.get_or_create_private_conversation(uuid) TO authenticated;

-- Vote diproses di server agar jumlah up/down tetap berubah untuk post siapa pun.
CREATE OR REPLACE FUNCTION public.set_forum_post_vote(
  target_post_id bigint,
  target_reaction text
) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  previous_reaction text;
  next_reaction text;
  up_count integer;
  down_count integer;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Tidak terautentikasi'; END IF;
  IF target_reaction NOT IN ('LIKE', 'DISLIKE') THEN RAISE EXCEPTION 'Vote tidak valid'; END IF;
  SELECT reaction INTO previous_reaction FROM forum_reactions
  WHERE post_id = target_post_id AND user_id = auth.uid();
  IF previous_reaction = target_reaction THEN
    DELETE FROM forum_reactions WHERE post_id = target_post_id AND user_id = auth.uid();
    next_reaction := NULL;
  ELSIF previous_reaction IS NULL THEN
    INSERT INTO forum_reactions(post_id, user_id, reaction)
    VALUES (target_post_id, auth.uid(), target_reaction);
    next_reaction := target_reaction;
  ELSE
    UPDATE forum_reactions SET reaction = target_reaction, updated_at = now()
    WHERE post_id = target_post_id AND user_id = auth.uid();
    next_reaction := target_reaction;
  END IF;
  SELECT count(*) FILTER (WHERE reaction = 'LIKE'), count(*) FILTER (WHERE reaction = 'DISLIKE')
  INTO up_count, down_count FROM forum_reactions WHERE post_id = target_post_id;
  UPDATE forum_posts SET like_count = up_count, dislike_count = down_count, updated_at = now()
  WHERE id = target_post_id;
  RETURN jsonb_build_object('reaction', next_reaction, 'like_count', up_count, 'dislike_count', down_count);
END; $$;
GRANT EXECUTE ON FUNCTION public.set_forum_post_vote(bigint, text) TO authenticated;
