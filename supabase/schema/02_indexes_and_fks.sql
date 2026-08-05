-- 02_indexes_and_fks.sql: Primary Keys, Foreign Keys, Unique Constraints, Indexes

-- Name: achievements achievements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.achievements
    ADD CONSTRAINT achievements_pkey PRIMARY KEY (id);


--

-- Name: active_bundles active_bundles_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.active_bundles
    ADD CONSTRAINT active_bundles_pkey PRIMARY KEY (id);


--

-- Name: activity_feed activity_feed_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_feed
    ADD CONSTRAINT activity_feed_pkey PRIMARY KEY (id);


--

-- Name: friendships friendships_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_pkey PRIMARY KEY (requester_id, addressee_id);


--

-- Name: games games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.games
    ADD CONSTRAINT games_pkey PRIMARY KEY (igdb_id);


--

-- Name: hall_of_fame hall_of_fame_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hall_of_fame
    ADD CONSTRAINT hall_of_fame_pkey PRIMARY KEY (user_id, pin_order);


--

-- Name: review_comments review_comments_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_comments
    ADD CONSTRAINT review_comments_pkey PRIMARY KEY (id);


--

-- Name: review_likes review_likes_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_likes
    ADD CONSTRAINT review_likes_pkey PRIMARY KEY (user_id, review_id);


--

-- Name: reviews reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_pkey PRIMARY KEY (id);


--

-- Name: stash_community_reviews stash_community_reviews_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_community_reviews
    ADD CONSTRAINT stash_community_reviews_pkey PRIMARY KEY (id);


--

-- Name: stash_game_stats stash_game_stats_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_game_stats
    ADD CONSTRAINT stash_game_stats_pkey PRIMARY KEY (game_id);


--

-- Name: stash_sync_metadata stash_sync_metadata_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_sync_metadata
    ADD CONSTRAINT stash_sync_metadata_pkey PRIMARY KEY (game_id);


--

-- Name: stash_community_reviews uq_game_user; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_community_reviews
    ADD CONSTRAINT uq_game_user UNIQUE (game_id, stash_user_display_name);


--

-- Name: user_achievements user_achievements_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_achievements
    ADD CONSTRAINT user_achievements_pkey PRIMARY KEY (user_id, achievement_id);


--

-- Name: user_games user_games_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_pkey PRIMARY KEY (user_id, game_id);


--

-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--

-- Name: users users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_username_key UNIQUE (username);


--

-- Name: activity_feed_created_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_feed_created_idx ON public.activity_feed USING btree (created_at DESC);


--

-- Name: activity_feed_user_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX activity_feed_user_idx ON public.activity_feed USING btree (user_id);


--

-- Name: friendships_addressee_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX friendships_addressee_idx ON public.friendships USING btree (addressee_id);


--

-- Name: friendships_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX friendships_status_idx ON public.friendships USING btree (status);


--

-- Name: idx_activity_feed_compound; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_activity_feed_compound ON public.activity_feed USING btree (user_id, game_id, created_at DESC);


--

-- Name: idx_friendships_addr_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friendships_addr_status ON public.friendships USING btree (addressee_id, status);


--

-- Name: idx_friendships_req_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_friendships_req_status ON public.friendships USING btree (requester_id, status);


--

-- Name: idx_review_comments_review_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_review_comments_review_id ON public.review_comments USING btree (review_id);


--

-- Name: idx_review_likes_review_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_review_likes_review_id ON public.review_likes USING btree (review_id);


--

-- Name: idx_reviews_created_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_created_at ON public.reviews USING btree (created_at DESC);


--

-- Name: idx_reviews_game_created; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_game_created ON public.reviews USING btree (game_id, created_at DESC);


--

-- Name: idx_reviews_user_game; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_reviews_user_game ON public.reviews USING btree (user_id, game_id);


--

-- Name: idx_stash_reviews_game_id; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_stash_reviews_game_id ON public.stash_community_reviews USING btree (game_id);


--

-- Name: idx_user_games_updated; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX idx_user_games_updated ON public.user_games USING btree (user_id, updated_at DESC);


--

-- Name: activity_feed activity_feed_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_feed
    ADD CONSTRAINT activity_feed_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id) ON DELETE CASCADE;


--

-- Name: activity_feed activity_feed_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.activity_feed
    ADD CONSTRAINT activity_feed_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: friendships friendships_addressee_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_addressee_id_fkey FOREIGN KEY (addressee_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: friendships friendships_requester_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.friendships
    ADD CONSTRAINT friendships_requester_id_fkey FOREIGN KEY (requester_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: hall_of_fame hall_of_fame_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hall_of_fame
    ADD CONSTRAINT hall_of_fame_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id) ON DELETE CASCADE;


--

-- Name: hall_of_fame hall_of_fame_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.hall_of_fame
    ADD CONSTRAINT hall_of_fame_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: review_comments review_comments_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_comments
    ADD CONSTRAINT review_comments_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE CASCADE;


--

-- Name: review_comments review_comments_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_comments
    ADD CONSTRAINT review_comments_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: review_likes review_likes_review_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_likes
    ADD CONSTRAINT review_likes_review_id_fkey FOREIGN KEY (review_id) REFERENCES public.reviews(id) ON DELETE CASCADE;


--

-- Name: review_likes review_likes_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review_likes
    ADD CONSTRAINT review_likes_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: reviews reviews_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id);


--

-- Name: reviews reviews_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--

-- Name: reviews reviews_user_id_users_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviews
    ADD CONSTRAINT reviews_user_id_users_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: stash_community_reviews stash_community_reviews_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_community_reviews
    ADD CONSTRAINT stash_community_reviews_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id);


--

-- Name: stash_game_stats stash_game_stats_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.stash_game_stats
    ADD CONSTRAINT stash_game_stats_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id);


--

-- Name: user_achievements user_achievements_achievement_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_achievements
    ADD CONSTRAINT user_achievements_achievement_id_fkey FOREIGN KEY (achievement_id) REFERENCES public.achievements(id) ON DELETE CASCADE;


--

-- Name: user_achievements user_achievements_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_achievements
    ADD CONSTRAINT user_achievements_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE;


--

-- Name: user_games user_games_game_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_game_id_fkey FOREIGN KEY (game_id) REFERENCES public.games(igdb_id) ON DELETE CASCADE;


--

-- Name: user_games user_games_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.users(id) ON DELETE SET NULL;


--

-- Name: user_games user_games_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.user_games
    ADD CONSTRAINT user_games_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.users(id) ON DELETE CASCADE;


--

-- Name: users users_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_id_fkey FOREIGN KEY (id) REFERENCES auth.users(id) ON DELETE CASCADE;


--

