-- Threaded review comments: store explicit parent for replies.
ALTER TABLE public.review_comments
  ADD COLUMN IF NOT EXISTS parent_comment_id uuid;

ALTER TABLE public.review_comments
  DROP CONSTRAINT IF EXISTS review_comments_parent_comment_id_fkey;

ALTER TABLE public.review_comments
  ADD CONSTRAINT review_comments_parent_comment_id_fkey
  FOREIGN KEY (parent_comment_id)
  REFERENCES public.review_comments(id)
  ON DELETE CASCADE;

CREATE INDEX IF NOT EXISTS idx_review_comments_parent_id
  ON public.review_comments(parent_comment_id);

-- Backfill legacy @-replies: link to the most recent prior comment from the
-- mentioned user in the same review. If none exists, attach to the first
-- top-level comment in that review.
WITH mention_parents AS (
  SELECT
    child.id AS child_id,
    COALESCE(
      (
        SELECT parent.id
        FROM public.review_comments parent
        JOIN public.users parent_user ON parent_user.id = parent.user_id
        WHERE parent.review_id = child.review_id
          AND parent.created_at < child.created_at
          AND lower(parent_user.username) = lower(
            substring(trim(child.content) FROM '^@(\w+)')
          )
        ORDER BY parent.created_at DESC
        LIMIT 1
      ),
      (
        SELECT root.id
        FROM public.review_comments root
        WHERE root.review_id = child.review_id
          AND root.id <> child.id
          AND root.parent_comment_id IS NULL
        ORDER BY root.created_at ASC
        LIMIT 1
      )
    ) AS parent_id
  FROM public.review_comments child
  WHERE child.parent_comment_id IS NULL
    AND child.content IS NOT NULL
    AND trim(child.content) ~ '^@\w+'
)
UPDATE public.review_comments AS rc
SET parent_comment_id = mp.parent_id
FROM mention_parents mp
WHERE rc.id = mp.child_id
  AND mp.parent_id IS NOT NULL;
