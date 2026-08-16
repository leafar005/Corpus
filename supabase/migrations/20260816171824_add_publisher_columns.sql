ALTER TABLE games
ADD COLUMN IF NOT EXISTS publisher text,
ADD COLUMN IF NOT EXISTS publisher_id bigint;
