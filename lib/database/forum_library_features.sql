-- Jalankan sekali di Supabase SQL Editor sebelum merilis fitur Forum Library.
ALTER TABLE public.forum_attachments
  ADD COLUMN IF NOT EXISTS curation_status text NOT NULL DEFAULT 'PENDING'
    CHECK (curation_status IN ('PENDING', 'PASSED', 'FAILED')),
  ADD COLUMN IF NOT EXISTS curation_feedback text,
  ADD COLUMN IF NOT EXISTS relevance_score numeric CHECK (
    relevance_score IS NULL OR (relevance_score >= 0 AND relevance_score <= 100)
  ),
  ADD COLUMN IF NOT EXISTS relevance_label text,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamp with time zone;

CREATE UNIQUE INDEX IF NOT EXISTS forum_reactions_post_user_unique
  ON public.forum_reactions (post_id, user_id);

CREATE OR REPLACE FUNCTION public.refresh_forum_post_vote_counts()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  target_post_id bigint := COALESCE(NEW.post_id, OLD.post_id);
BEGIN
  UPDATE public.forum_posts
  SET like_count = (SELECT count(*) FROM public.forum_reactions
                    WHERE post_id = target_post_id AND reaction = 'LIKE'),
      dislike_count = (SELECT count(*) FROM public.forum_reactions
                       WHERE post_id = target_post_id AND reaction = 'DISLIKE'),
      updated_at = now()
  WHERE id = target_post_id;
  RETURN COALESCE(NEW, OLD);
END;
$$;

DROP TRIGGER IF EXISTS forum_reactions_refresh_counts ON public.forum_reactions;
CREATE TRIGGER forum_reactions_refresh_counts
AFTER INSERT OR UPDATE OR DELETE ON public.forum_reactions
FOR EACH ROW EXECUTE FUNCTION public.refresh_forum_post_vote_counts();

-- RLS untuk attachment: pemilik post dapat melampirkan file Library sendiri;
-- anggota lain hanya melihat file yang lolos kurasi. Admin/dosen dapat kurasi.
ALTER TABLE public.forum_attachments ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "forum_attachments_read_curated" ON public.forum_attachments;
CREATE POLICY "forum_attachments_read_curated"
ON public.forum_attachments FOR SELECT TO authenticated
USING (
  curation_status = 'PASSED'
  OR uploaded_by = auth.uid()
  OR EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role IN ('admin', 'dosen')
  )
);

DROP POLICY IF EXISTS "forum_attachments_attach_own_library" ON public.forum_attachments;
CREATE POLICY "forum_attachments_attach_own_library"
ON public.forum_attachments FOR INSERT TO authenticated
WITH CHECK (
  uploaded_by = auth.uid()
  AND EXISTS (
    SELECT 1 FROM public.forum_posts
    WHERE forum_posts.id = post_id AND forum_posts.user_id = auth.uid()
  )
  AND EXISTS (
    SELECT 1 FROM public.files
    WHERE files.id = file_id AND files.uploaded_by = auth.uid()
  )
);

DROP POLICY IF EXISTS "forum_attachments_curate" ON public.forum_attachments;
CREATE POLICY "forum_attachments_curate"
ON public.forum_attachments FOR UPDATE TO authenticated
USING (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role IN ('admin', 'dosen')
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.users
    WHERE users.id = auth.uid() AND users.role IN ('admin', 'dosen')
  )
);

-- RLS reaksi: satu pengguna mengelola suaranya sendiri.
ALTER TABLE public.forum_reactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "forum_reactions_read" ON public.forum_reactions;
CREATE POLICY "forum_reactions_read"
ON public.forum_reactions FOR SELECT TO authenticated USING (true);

DROP POLICY IF EXISTS "forum_reactions_insert_own" ON public.forum_reactions;
CREATE POLICY "forum_reactions_insert_own"
ON public.forum_reactions FOR INSERT TO authenticated
WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "forum_reactions_update_own" ON public.forum_reactions;
CREATE POLICY "forum_reactions_update_own"
ON public.forum_reactions FOR UPDATE TO authenticated
USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "forum_reactions_delete_own" ON public.forum_reactions;
CREATE POLICY "forum_reactions_delete_own"
ON public.forum_reactions FOR DELETE TO authenticated
USING (user_id = auth.uid());
