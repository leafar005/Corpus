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
