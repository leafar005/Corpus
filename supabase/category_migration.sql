-- Migration: Add category and parent_game to games table
-- This allows rendering category badges on Library and Profile grids

ALTER TABLE games ADD COLUMN IF NOT EXISTS category INT;
ALTER TABLE games ADD COLUMN IF NOT EXISTS parent_game INT;
