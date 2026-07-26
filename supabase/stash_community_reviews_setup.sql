CREATE TABLE public.stash_community_reviews (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    game_id INTEGER REFERENCES public.games(igdb_id), -- null si es de la fila "recientes" y aún no resolvemos el juego
    stash_user_display_name TEXT, -- nombre público que muestra Stash, no vinculamos a tu tabla users
    stash_user_avatar_url TEXT,
    comment TEXT,
    rating NUMERIC(3,1),
    source_context TEXT CHECK (source_context IN ('game_reviews', 'recent_activity_feed')),
    stash_created_at TIMESTAMP WITH TIME ZONE,
    imported_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now())
);

-- Habilitar RLS
ALTER TABLE public.stash_community_reviews ENABLE ROW LEVEL SECURITY;

-- Política de lectura pública
CREATE POLICY "Anyone can view stash community reviews" 
ON public.stash_community_reviews FOR SELECT USING (true);

-- Política de inserción (como usas el scraper en local con anon_key, abrimos la inserción pública temporalmente)
CREATE POLICY "Anyone can insert stash community reviews" 
ON public.stash_community_reviews FOR INSERT WITH CHECK (true);
