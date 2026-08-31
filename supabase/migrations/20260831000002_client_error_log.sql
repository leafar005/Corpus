CREATE TABLE public.client_error_log (
  id bigint generated always as identity primary key,
  user_id uuid references public.users(id) on delete set null,
  source text not null,
  message text not null,
  platform text,
  created_at timestamptz not null default now()
);

ALTER TABLE public.client_error_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can insert their own error logs"
  ON public.client_error_log FOR INSERT
  WITH CHECK (auth.uid() = user_id OR user_id IS NULL);
