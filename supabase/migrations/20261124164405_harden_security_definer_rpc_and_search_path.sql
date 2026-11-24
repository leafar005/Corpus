-- =============================================================================
-- Endurecimiento de seguridad en funciones RPC y search_path:
-- 1. Fija search_path = public, pg_temp en funciones con search_path mutable.
-- 2. Revoca EXECUTE a PUBLIC/anon/authenticated en funciones internas y triggers.
-- 3. Restringe check_igdb_rate_limit y post_summary a service_role.
-- 4. Restringe ensure_review_post y RPCs de notificaciones a authenticated/service_role.
-- =============================================================================

-- 1. Fijar search_path en las 5 funciones con search_path mutable
ALTER FUNCTION public.webhook_notify_friend_activity() SET search_path = public, pg_temp;
ALTER FUNCTION public.webhook_notify_comment() SET search_path = public, pg_temp;
ALTER FUNCTION public.update_modified_column() SET search_path = public, pg_temp;
ALTER FUNCTION public.search_active_bundles(text) SET search_path = public, pg_temp;
ALTER FUNCTION public.touch_user_settings_updated_at() SET search_path = public, pg_temp;

-- 2. Revocar EXECUTE público/cliente en funciones de trigger e internas SECURITY DEFINER
REVOKE ALL ON FUNCTION public.assign_feed_post() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fill_comment_refs() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.fill_interaction_refs() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.follow_reviewed_to_post() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_friend_request() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_friend_request_removed() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_friend_request_response() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_review_comment() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_review_like() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.notify_review_unlike() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.on_review_delete() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.on_review_upsert() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.on_user_game_delete() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.on_user_game_status_change() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prune_after_feed_delete() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.split_grouped_review_on_update() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.sync_user_games_rating_from_review() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_review_gamification() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trigger_user_games_gamification() FROM PUBLIC, anon, authenticated;

REVOKE ALL ON FUNCTION public.calculate_user_xp(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.check_user_achievements(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.compute_feed_post(public.activity_feed) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.is_bare_activity(uuid, integer, uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.prune_feed_post(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.resolve_interaction_refs(uuid, uuid, uuid) FROM PUBLIC, anon, authenticated;

-- 3. Funciones llamadas exclusivamente por Edge Functions con service_role
REVOKE ALL ON FUNCTION public.check_igdb_rate_limit(text, integer, integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_igdb_rate_limit(text, integer, integer) TO service_role;

REVOKE ALL ON FUNCTION public.post_summary(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.post_summary(uuid) TO service_role;

-- 4. RPCs de usuario autenticado (revocar anon/PUBLIC, mantener authenticated + service_role)
REVOKE ALL ON FUNCTION public.ensure_review_post(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.ensure_review_post(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.get_unread_notifications_count() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_unread_notifications_count() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.mark_all_notifications_read() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_all_notifications_read() TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.mark_notification_read(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.mark_notification_read(uuid) TO authenticated, service_role;
