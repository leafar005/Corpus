-- 03_security_policies.sql: Row Level Security (RLS) Policies, Grants, Revokes

-- ELIMINADA: "Allow all for authenticated" en games era ambigua y redundante.
-- Las políticas específicas (SELECT, INSERT) cubren lo necesario.


--

-- Name: active_bundles Allow public read access on active_bundles; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Allow public read access on active_bundles" ON public.active_bundles FOR SELECT USING (true);


--

-- Name: stash_community_reviews Service role inserts stash community reviews; Type: POLICY; Schema: public; Owner: -
-- CAMBIADA: de "Anyone can insert" a solo service_role para evitar inserts no autorizados.
--

CREATE POLICY "Service role inserts stash community reviews" ON public.stash_community_reviews FOR INSERT TO service_role WITH CHECK (true);


--

-- Name: stash_sync_metadata Service role manages stash sync metadata; Type: POLICY; Schema: public; Owner: -
-- CAMBIADA: de "Anyone can insert" a solo service_role.
--

CREATE POLICY "Service role manages stash sync metadata" ON public.stash_sync_metadata FOR ALL TO service_role USING (true) WITH CHECK (true);


--

-- Name: reviews Anyone can read reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can read reviews" ON public.reviews FOR SELECT USING (true);


--

-- Name: review_comments Anyone can view comments; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view comments" ON public.review_comments FOR SELECT USING (true);


--

-- Name: games Anyone can view games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view games" ON public.games FOR SELECT USING (true);


--

-- Name: hall_of_fame Anyone can view hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view hall_of_fame" ON public.hall_of_fame FOR SELECT USING (true);


--

-- Name: review_likes Anyone can view likes; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view likes" ON public.review_likes FOR SELECT USING (true);


--

-- Name: stash_community_reviews Anyone can view stash community reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view stash community reviews" ON public.stash_community_reviews FOR SELECT USING (true);


--

-- Name: stash_sync_metadata Anyone can view stash sync metadata; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Anyone can view stash sync metadata" ON public.stash_sync_metadata FOR SELECT USING (true);


--

-- Name: achievements Logros son públicos; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Logros son públicos" ON public.achievements FOR SELECT USING (true);


--

-- Name: activity_feed No direct user insert into activity_feed; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "No direct user insert into activity_feed" ON public.activity_feed FOR INSERT WITH CHECK (false);


--

-- ELIMINADAS: "No user DELETE on games" y "No user UPDATE on games" eran innecesarias.
-- Sin política de UPDATE/DELETE activa, esas operaciones quedan denegadas por defecto.
-- Eliminadas junto con "Allow all for authenticated" para limpiar la lógica RLS.


--

-- Name: user_achievements Trigger maneja user_achievements; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Trigger maneja user_achievements" ON public.user_achievements USING ((auth.uid() = user_id));


--

-- Name: friendships Users can delete friendships they are part of; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete friendships they are part of" ON public.friendships FOR DELETE USING (((auth.uid() = requester_id) OR (auth.uid() = addressee_id)));


--

-- Name: review_comments Users can delete own comment; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own comment" ON public.review_comments FOR DELETE USING ((auth.uid() = user_id));


--

-- Name: user_games Users can delete own games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own games" ON public.user_games FOR DELETE USING ((auth.uid() = user_id));


--

-- Name: hall_of_fame Users can delete own hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own hall_of_fame" ON public.hall_of_fame FOR DELETE USING ((auth.uid() = user_id));


--

-- Name: review_likes Users can delete own like; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own like" ON public.review_likes FOR DELETE USING ((auth.uid() = user_id));


--

-- Name: reviews Users can delete own reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can delete own reviews" ON public.reviews FOR DELETE USING ((auth.uid() = user_id));


--

-- Name: games Users can insert games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert games" ON public.games FOR INSERT WITH CHECK ((auth.role() = 'authenticated'::text));


--

-- Name: review_comments Users can insert own comment; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own comment" ON public.review_comments FOR INSERT WITH CHECK ((auth.uid() = user_id));


--

-- Name: user_games Users can insert own games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own games" ON public.user_games FOR INSERT WITH CHECK ((auth.uid() = user_id));


--

-- Name: hall_of_fame Users can insert own hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own hall_of_fame" ON public.hall_of_fame FOR INSERT WITH CHECK ((auth.uid() = user_id));


--

-- Name: review_likes Users can insert own like; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own like" ON public.review_likes FOR INSERT WITH CHECK ((auth.uid() = user_id));


--

-- Name: reviews Users can insert own reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can insert own reviews" ON public.reviews FOR INSERT WITH CHECK ((auth.uid() = user_id));


--

-- Name: friendships Users can send friend requests; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can send friend requests" ON public.friendships FOR INSERT WITH CHECK ((auth.uid() = requester_id));


--

-- Name: friendships Users can update friendships they are part of; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update friendships they are part of" ON public.friendships FOR UPDATE USING ((auth.uid() = addressee_id));


--

-- Name: user_games Users can update own games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own games" ON public.user_games FOR UPDATE USING ((auth.uid() = user_id));


--

-- Name: hall_of_fame Users can update own hall_of_fame; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own hall_of_fame" ON public.hall_of_fame FOR UPDATE USING ((auth.uid() = user_id));


--

-- Name: users Users can update own profile; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own profile" ON public.users FOR UPDATE USING ((auth.uid() = id));


--

-- Name: reviews Users can update own reviews; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can update own reviews" ON public.reviews FOR UPDATE USING ((auth.uid() = user_id));


--

-- Name: user_games Users can view all user_games; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view all user_games" ON public.user_games FOR SELECT USING (true);


--

-- Name: users Users can view all users; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view all users" ON public.users FOR SELECT USING (true);


--

-- Name: activity_feed Users can view their own and friends activity; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own and friends activity" ON public.activity_feed FOR SELECT USING (((auth.uid() = user_id) OR (EXISTS ( SELECT 1
   FROM public.friendships f
  WHERE ((f.status = 'accepted'::text) AND (((f.requester_id = auth.uid()) AND (f.addressee_id = activity_feed.user_id)) OR ((f.addressee_id = auth.uid()) AND (f.requester_id = activity_feed.user_id))))))));


--

-- Name: friendships Users can view their own friendships; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Users can view their own friendships" ON public.friendships FOR SELECT USING (((auth.uid() = requester_id) OR (auth.uid() = addressee_id)));


--

-- Name: user_achievements Usuarios pueden ver todos los logros desbloqueados; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY "Usuarios pueden ver todos los logros desbloqueados" ON public.user_achievements FOR SELECT USING (true);


--

-- Name: achievements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

--

-- Name: active_bundles; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.active_bundles ENABLE ROW LEVEL SECURITY;

--

-- Name: activity_feed; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.activity_feed ENABLE ROW LEVEL SECURITY;

--

-- Name: friendships; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

--

-- Name: games; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.games ENABLE ROW LEVEL SECURITY;

--

-- Name: hall_of_fame; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.hall_of_fame ENABLE ROW LEVEL SECURITY;

--

-- Name: review_comments; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.review_comments ENABLE ROW LEVEL SECURITY;

--

-- Name: review_likes; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.review_likes ENABLE ROW LEVEL SECURITY;

--

-- Name: reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

--

-- Name: stash_community_reviews; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stash_community_reviews ENABLE ROW LEVEL SECURITY;

--

-- Name: stash_game_stats; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stash_game_stats ENABLE ROW LEVEL SECURITY;

--

-- Name: stash_game_stats stash_game_stats_select_authenticated; Type: POLICY; Schema: public; Owner: -
--

CREATE POLICY stash_game_stats_select_authenticated ON public.stash_game_stats FOR SELECT TO authenticated USING (true);


--

-- Name: stash_sync_metadata; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.stash_sync_metadata ENABLE ROW LEVEL SECURITY;

--

-- Name: user_achievements; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

--

-- Name: user_games; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.user_games ENABLE ROW LEVEL SECURITY;

--

-- Name: users; Type: ROW SECURITY; Schema: public; Owner: -
--

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

--

-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: -
--

GRANT USAGE ON SCHEMA public TO postgres;
GRANT USAGE ON SCHEMA public TO anon;
GRANT USAGE ON SCHEMA public TO authenticated;
GRANT USAGE ON SCHEMA public TO service_role;


--

-- Name: FUNCTION calculate_user_xp(uid uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.calculate_user_xp(uid uuid) TO authenticated;
GRANT ALL ON FUNCTION public.calculate_user_xp(uid uuid) TO service_role;


--

-- Name: FUNCTION check_user_achievements(uid uuid); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.check_user_achievements(uid uuid) TO authenticated;
GRANT ALL ON FUNCTION public.check_user_achievements(uid uuid) TO service_role;


--

-- Name: FUNCTION handle_new_user(); Type: ACL; Schema: public; Owner: -
--

REVOKE ALL ON FUNCTION public.handle_new_user() FROM PUBLIC;
GRANT ALL ON FUNCTION public.handle_new_user() TO service_role;


--

-- Name: FUNCTION on_review_delete(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_review_delete() TO anon;
GRANT ALL ON FUNCTION public.on_review_delete() TO authenticated;
GRANT ALL ON FUNCTION public.on_review_delete() TO service_role;


--

-- Name: FUNCTION on_review_upsert(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_review_upsert() TO anon;
GRANT ALL ON FUNCTION public.on_review_upsert() TO authenticated;
GRANT ALL ON FUNCTION public.on_review_upsert() TO service_role;


--

-- Name: FUNCTION on_user_game_delete(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_user_game_delete() TO anon;
GRANT ALL ON FUNCTION public.on_user_game_delete() TO authenticated;
GRANT ALL ON FUNCTION public.on_user_game_delete() TO service_role;


--

-- Name: FUNCTION on_user_game_status_change(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.on_user_game_status_change() TO anon;
GRANT ALL ON FUNCTION public.on_user_game_status_change() TO authenticated;
GRANT ALL ON FUNCTION public.on_user_game_status_change() TO service_role;


--

-- Name: FUNCTION trigger_review_gamification(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.trigger_review_gamification() TO anon;
GRANT ALL ON FUNCTION public.trigger_review_gamification() TO authenticated;
GRANT ALL ON FUNCTION public.trigger_review_gamification() TO service_role;


--

-- Name: FUNCTION update_modified_column(); Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON FUNCTION public.update_modified_column() TO anon;
GRANT ALL ON FUNCTION public.update_modified_column() TO authenticated;
GRANT ALL ON FUNCTION public.update_modified_column() TO service_role;


--

-- Name: TABLE achievements; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.achievements TO anon;
GRANT ALL ON TABLE public.achievements TO authenticated;
GRANT ALL ON TABLE public.achievements TO service_role;


--

-- Name: TABLE active_bundles; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.active_bundles TO anon;
GRANT ALL ON TABLE public.active_bundles TO authenticated;
GRANT ALL ON TABLE public.active_bundles TO service_role;


--

-- Name: TABLE activity_feed; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.activity_feed TO anon;
GRANT ALL ON TABLE public.activity_feed TO authenticated;
GRANT ALL ON TABLE public.activity_feed TO service_role;


--

-- Name: TABLE friendships; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.friendships TO anon;
GRANT ALL ON TABLE public.friendships TO authenticated;
GRANT ALL ON TABLE public.friendships TO service_role;


--

-- Name: TABLE games; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.games TO anon;
GRANT ALL ON TABLE public.games TO authenticated;
GRANT ALL ON TABLE public.games TO service_role;


--

-- Name: TABLE hall_of_fame; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.hall_of_fame TO anon;
GRANT ALL ON TABLE public.hall_of_fame TO authenticated;
GRANT ALL ON TABLE public.hall_of_fame TO service_role;


--

-- Name: TABLE review_comments; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.review_comments TO anon;
GRANT ALL ON TABLE public.review_comments TO authenticated;
GRANT ALL ON TABLE public.review_comments TO service_role;


--

-- Name: TABLE review_likes; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.review_likes TO anon;
GRANT ALL ON TABLE public.review_likes TO authenticated;
GRANT ALL ON TABLE public.review_likes TO service_role;


--

-- Name: TABLE reviews; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.reviews TO anon;
GRANT ALL ON TABLE public.reviews TO authenticated;
GRANT ALL ON TABLE public.reviews TO service_role;


--

-- Name: TABLE stash_community_reviews; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.stash_community_reviews TO anon;
GRANT ALL ON TABLE public.stash_community_reviews TO authenticated;
GRANT ALL ON TABLE public.stash_community_reviews TO service_role;


--

-- Name: TABLE stash_game_stats; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.stash_game_stats TO anon;
GRANT ALL ON TABLE public.stash_game_stats TO authenticated;
GRANT ALL ON TABLE public.stash_game_stats TO service_role;


--

-- Name: TABLE stash_sync_metadata; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.stash_sync_metadata TO anon;
GRANT ALL ON TABLE public.stash_sync_metadata TO authenticated;
GRANT ALL ON TABLE public.stash_sync_metadata TO service_role;


--

-- Name: TABLE user_achievements; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_achievements TO anon;
GRANT ALL ON TABLE public.user_achievements TO authenticated;
GRANT ALL ON TABLE public.user_achievements TO service_role;


--

-- Name: TABLE user_games; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.user_games TO anon;
GRANT ALL ON TABLE public.user_games TO authenticated;
GRANT ALL ON TABLE public.user_games TO service_role;


--

-- Name: TABLE users; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.users TO anon;
GRANT ALL ON TABLE public.users TO authenticated;
GRANT ALL ON TABLE public.users TO service_role;


--

-- Name: TABLE v_friend_pairs; Type: ACL; Schema: public; Owner: -
--

GRANT ALL ON TABLE public.v_friend_pairs TO anon;
GRANT ALL ON TABLE public.v_friend_pairs TO authenticated;
GRANT ALL ON TABLE public.v_friend_pairs TO service_role;


--

