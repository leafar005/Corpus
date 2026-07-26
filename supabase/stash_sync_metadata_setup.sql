CREATE TABLE public.stash_sync_metadata (
    game_id INTEGER PRIMARY KEY,
    last_checked_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Enable RLS
ALTER TABLE public.stash_sync_metadata ENABLE ROW LEVEL SECURITY;

-- Read policy (anyone can read)
CREATE POLICY "Anyone can view stash sync metadata" 
ON public.stash_sync_metadata FOR SELECT USING (true);

-- Insert/Update policy (Edge functions can upsert)
CREATE POLICY "Anyone can insert stash sync metadata" 
ON public.stash_sync_metadata FOR ALL USING (true) WITH CHECK (true);
