-- =========================================================================
-- CORPUS: ESQUEMA DE BASE DE DATOS (Fase 0 y 1 - Core Library)
-- =========================================================================

-- ENUM para los estados del juego
CREATE TYPE game_status AS ENUM ('playing', 'beaten', 'wishlist', 'abandoned', 'on_hold');

-- 1. Usuarios (Extendiendo el sistema de autenticación de Supabase)
CREATE TABLE public.users (
    id UUID REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    username TEXT UNIQUE NOT NULL,
    avatar_url TEXT,
    banner_url TEXT,
    steam_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Juegos (Catálogo general)
CREATE TABLE public.games (
    igdb_id INTEGER PRIMARY KEY,
    title TEXT NOT NULL,
    cover_url TEXT,
    release_date DATE,
    hltb_time JSONB,
    genres JSONB,
    steam_app_id INTEGER
);

-- 3. Biblioteca personal (user_games)
CREATE TABLE public.user_games (
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    game_id INTEGER REFERENCES public.games(igdb_id) ON DELETE CASCADE,
    status game_status DEFAULT 'wishlist' NOT NULL,
    rating NUMERIC(3,1) CHECK (rating >= 1 AND rating <= 10),
    rating_gameplay NUMERIC(3,1) CHECK (rating_gameplay >= 1 AND rating_gameplay <= 10),
    rating_soundtrack NUMERIC(3,1) CHECK (rating_soundtrack >= 1 AND rating_soundtrack <= 10),
    rating_visuals NUMERIC(3,1) CHECK (rating_visuals >= 1 AND rating_visuals <= 10),
    comment TEXT,
    partner_id UUID REFERENCES public.users(id) ON DELETE SET NULL,
    play_count INTEGER DEFAULT 1 NOT NULL,
    play_time_hours NUMERIC,
    last_played_at TIMESTAMP WITH TIME ZONE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT timezone('utc'::text, now()) NOT NULL,
    PRIMARY KEY (user_id, game_id)
);

-- =========================================================================
-- SEGURIDAD (Row Level Security - RLS)
-- =========================================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_games ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;

-- ==========================================
-- POLÍTICAS PARA LA TABLA JUEGOS (GAMES)
-- ==========================================
-- Cualquiera puede leer el catálogo de juegos
CREATE POLICY "Anyone can view games" 
ON public.games FOR SELECT USING (true);

-- Los usuarios logueados pueden añadir juegos nuevos al catálogo si no existen
CREATE POLICY "Users can insert games" 
ON public.games FOR INSERT WITH CHECK (auth.role() = 'authenticated');
-- (Nadie puede hacer UPDATE o DELETE, así evitamos que borren el catálogo)

-- ==========================================
-- POLÍTICAS PARA PERFILES (USERS)
-- ==========================================
CREATE POLICY "Users can view all users" 
ON public.users FOR SELECT USING (true);

-- Solo TÚ puedes editar TU propio perfil
CREATE POLICY "Users can update own profile" 
ON public.users FOR UPDATE USING (auth.uid() = id);

-- Las listas de juegos son públicas
CREATE POLICY "Users can view all user_games" 
ON public.user_games FOR SELECT USING (true);

-- Solo TÚ puedes añadir/editar TUS propios juegos
CREATE POLICY "Users can insert own games" 
ON public.user_games FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own games" 
ON public.user_games FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "Users can delete own games" 
ON public.user_games FOR DELETE USING (auth.uid() = user_id);

-- ==========================================
-- LIKES Y COMENTARIOS EN RESEÑAS
-- ==========================================

-- Tabla para Likes de Reseñas
CREATE TABLE public.review_likes (
    user_id        UUID REFERENCES public.users(id) ON DELETE CASCADE,
    review_user_id UUID,
    review_game_id INTEGER,
    created_at     TIMESTAMPTZ DEFAULT now(),
    PRIMARY KEY (user_id, review_user_id, review_game_id),
    FOREIGN KEY (review_user_id, review_game_id) REFERENCES public.user_games(user_id, game_id) ON DELETE CASCADE
);

-- Políticas RLS para review_likes
ALTER TABLE public.review_likes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view likes" 
ON public.review_likes FOR SELECT USING (true);

CREATE POLICY "Users can insert own like" 
ON public.review_likes FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own like" 
ON public.review_likes FOR DELETE USING (auth.uid() = user_id);

-- Tabla para Comentarios de Reseñas
CREATE TABLE public.review_comments (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id        UUID REFERENCES public.users(id) ON DELETE CASCADE NOT NULL,
    review_user_id UUID,
    review_game_id INTEGER,
    content        TEXT NOT NULL CHECK (char_length(content) <= 500 AND char_length(content) > 0),
    created_at     TIMESTAMPTZ DEFAULT now() NOT NULL,
    FOREIGN KEY (review_user_id, review_game_id) REFERENCES public.user_games(user_id, game_id) ON DELETE CASCADE
);

-- Políticas RLS para review_comments
ALTER TABLE public.review_comments ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone can view comments" 
ON public.review_comments FOR SELECT USING (true);

CREATE POLICY "Users can insert own comment" 
ON public.review_comments FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can delete own comment" 
ON public.review_comments FOR DELETE USING (auth.uid() = user_id);
