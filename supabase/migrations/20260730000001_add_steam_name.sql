ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS steam_name TEXT;
