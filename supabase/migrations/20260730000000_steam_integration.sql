-- 1. Extender 'users'
ALTER TABLE public.users
  ADD COLUMN IF NOT EXISTS steam_linked_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS steam_profile_public BOOLEAN DEFAULT true,
  ADD COLUMN IF NOT EXISTS currently_playing_appid INTEGER,
  ADD COLUMN IF NOT EXISTS currently_playing_name TEXT,
  ADD COLUMN IF NOT EXISTS currently_playing_since TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS steam_presence_updated_at TIMESTAMPTZ;

-- 2. Extender 'games'
ALTER TABLE public.games
  ADD COLUMN IF NOT EXISTS metacritic_score INTEGER,
  ADD COLUMN IF NOT EXISTS metacritic_url TEXT,
  ADD COLUMN IF NOT EXISTS metacritic_updated_at TIMESTAMPTZ;

-- 3. Extender 'user_games'
ALTER TABLE public.user_games
  ADD COLUMN IF NOT EXISTS steam_owned BOOLEAN DEFAULT false,
  ADD COLUMN IF NOT EXISTS steam_playtime_minutes INTEGER,
  ADD COLUMN IF NOT EXISTS steam_last_played_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS steam_imported_at TIMESTAMPTZ,
  ADD COLUMN IF NOT EXISTS is_steam_only BOOLEAN DEFAULT false;

-- 4. Nueva tabla 'steam_import_jobs'
CREATE TABLE public.steam_import_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('pending','running','completed','failed')) DEFAULT 'pending',
  min_playtime_minutes INTEGER DEFAULT 180,
  total_games INTEGER,
  processed_games INTEGER DEFAULT 0,
  matched_games INTEGER DEFAULT 0,
  unmatched_games INTEGER DEFAULT 0,
  resume_cursor INTEGER DEFAULT 0,
  error_message TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- RLS: cada usuario solo ve sus propios jobs
ALTER TABLE public.steam_import_jobs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users_view_own_import_jobs" ON public.steam_import_jobs
  FOR SELECT USING (auth.uid() = user_id);
