ALTER TABLE public.achievements ADD COLUMN saga_target integer DEFAULT 1 NOT NULL;

-- Backfill saga_target based on achievement ID patterns
UPDATE public.achievements
SET saga_target = 
  CASE 
    WHEN id = 'lone_wolf' THEN 50
    WHEN id LIKE '%_all' AND (id LIKE 'fromsoftware%' OR id LIKE 'zelda%') THEN 7
    WHEN id LIKE '%_all' AND id LIKE 'mario%' THEN 15
    WHEN id LIKE '%_all' AND id LIKE 'dark_souls%' THEN 3
    WHEN id ~ '_[0-9]+$' THEN CAST(SUBSTRING(id FROM '_([0-9]+)$') AS integer)
    ELSE 1
  END;
