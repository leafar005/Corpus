-- Añade el estado "Por jugar" al enum de biblioteca.
ALTER TYPE public.game_status ADD VALUE IF NOT EXISTS 'to_play';
