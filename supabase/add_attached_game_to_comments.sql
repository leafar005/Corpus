-- Add attached_game to review_comments for attaching games to comments
ALTER TABLE review_comments
ADD COLUMN attached_game JSONB DEFAULT NULL;
