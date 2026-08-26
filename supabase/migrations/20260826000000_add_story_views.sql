CREATE TABLE public.story_views (
    user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    activity_id uuid NOT NULL REFERENCES public.activity_feed(id) ON DELETE CASCADE,
    viewed_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, activity_id)
);

CREATE INDEX idx_story_views_user_id ON public.story_views(user_id);

ALTER TABLE public.story_views ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own story views"
  ON public.story_views FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own story views"
  ON public.story_views FOR INSERT
  WITH CHECK (auth.uid() = user_id);
