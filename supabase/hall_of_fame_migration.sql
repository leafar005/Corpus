-- =========================================================================
-- MIGRACIÓN: HALL OF FAME
-- =========================================================================

-- Tabla para el Hall of Fame
CREATE TABLE public.hall_of_fame (
    user_id UUID REFERENCES public.users(id) ON DELETE CASCADE,
    game_id INTEGER REFERENCES public.games(igdb_id) ON DELETE CASCADE,
    pin_order INTEGER CHECK (pin_order >= 1 AND pin_order <= 5),
    created_at TIMESTAMPTZ DEFAULT now() NOT NULL,
    PRIMARY KEY (user_id, pin_order)
);

-- Políticas RLS
ALTER TABLE public.hall_of_fame ENABLE ROW LEVEL SECURITY;

-- Cualquiera puede ver el Hall of Fame
CREATE POLICY "Anyone can view hall_of_fame" 
ON public.hall_of_fame FOR SELECT USING (true);

-- Solo el usuario puede insertar en su propio Hall of Fame
CREATE POLICY "Users can insert own hall_of_fame" 
ON public.hall_of_fame FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Solo el usuario puede actualizar su propio Hall of Fame
CREATE POLICY "Users can update own hall_of_fame" 
ON public.hall_of_fame FOR UPDATE USING (auth.uid() = user_id);

-- Solo el usuario puede eliminar de su propio Hall of Fame
CREATE POLICY "Users can delete own hall_of_fame" 
ON public.hall_of_fame FOR DELETE USING (auth.uid() = user_id);
