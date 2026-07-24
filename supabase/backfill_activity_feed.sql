-- Backfill reviews antiguas al activity_feed
INSERT INTO public.activity_feed (user_id, game_id, action_type, metadata, created_at)
SELECT 
    r.user_id, 
    r.game_id, 
    'reviewed'::text as action_type,
    jsonb_build_object('review_id', r.id, 'rating', r.rating, 'comment', left(r.comment, 50)) as metadata,
    r.created_at
FROM public.reviews r
WHERE NOT EXISTS (
    SELECT 1 FROM public.activity_feed a 
    WHERE a.user_id = r.user_id AND a.game_id = r.game_id AND a.action_type = 'reviewed'
);

-- Backfill de estados (jugando, completado, etc.) antiguos al activity_feed
INSERT INTO public.activity_feed (user_id, game_id, action_type, metadata, created_at)
SELECT 
    ug.user_id, 
    ug.game_id, 
    'status_change'::text as action_type,
    jsonb_build_object('status', ug.status) as metadata,
    ug.updated_at as created_at
FROM public.user_games ug
WHERE ug.status IS NOT NULL
AND NOT EXISTS (
    SELECT 1 FROM public.activity_feed a 
    WHERE a.user_id = ug.user_id AND a.game_id = ug.game_id AND a.action_type = 'status_change'
);
