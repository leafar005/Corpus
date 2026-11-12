-- =============================================================================
-- SQL Integration & Invariant Test Suite: feed_posts
-- =============================================================================
-- Ejecución: psql -v ON_ERROR_STOP=1 -f supabase/tests/feed_posts_test.sql
-- Corre íntegramente dentro de BEGIN ... ROLLBACK para no ensuciar la BD.
-- =============================================================================

BEGIN;

DO $$
DECLARE
  v_author       uuid := gen_random_uuid();
  v_friend       uuid := gen_random_uuid();
  v_game_1       int  := 9900001;
  v_game_2       int  := 9900002;
  v_game_3       int  := 9900003;
  v_game_4       int  := 9900004;
  v_review_1     uuid;
  v_review_3     uuid;
  v_review_4     uuid;
  v_post_playing uuid;
  v_post_beaten  uuid;
  v_post_g1      uuid;
  v_post_g2      uuid;
  v_post_g3      uuid;
  v_post_rich    uuid;
  v_post_impl_1  uuid;
  v_post_impl_2  uuid;
  v_comment_1    uuid;
  v_stats        record;
  v_notif        record;
  v_groupable    boolean;
  v_count        bigint;
  v_err_caught   boolean;
BEGIN
  -- Preparar usuarios y juegos de prueba
  INSERT INTO auth.users (id, email)
  VALUES
    (v_author, 'test_author_' || v_author::text || '@corpus.test'),
    (v_friend, 'test_friend_' || v_friend::text || '@corpus.test');

  INSERT INTO public.users (id, username, display_name)
  VALUES
    (v_author, 'author_' || substr(v_author::text, 1, 8), 'Test Author'),
    (v_friend, 'friend_' || substr(v_friend::text, 1, 8), 'Test Friend')
  ON CONFLICT (id) DO NOTHING;

  INSERT INTO public.games (igdb_id, title, cover_url)
  VALUES
    (v_game_1, 'Test Game 1', 'https://example.com/c1.jpg'),
    (v_game_2, 'Test Game 2', 'https://example.com/c2.jpg'),
    (v_game_3, 'Test Game 3', 'https://example.com/c3.jpg'),
    (v_game_4, 'Test Game 4', 'https://example.com/c4.jpg')
  ON CONFLICT (igdb_id) DO NOTHING;

  -- Simular que el usuario autenticado es v_friend para liked_by_me
  PERFORM set_config('request.jwt.claim.sub', v_friend::text, true);

  -- ===========================================================================
  -- 1. Hilo por post al cambiar de estado (playing -> beaten) y
  -- 2. 'reviewed' sigue a su 'status_change' y poda el post huérfano
  -- ===========================================================================
  INSERT INTO public.reviews (user_id, game_id, status)
  VALUES (v_author, v_game_1, 'playing')
  RETURNING id INTO v_review_1;

  SELECT post_id INTO v_post_playing
  FROM public.activity_feed
  WHERE review_id = v_review_1 AND action_type = 'status_change'
  ORDER BY created_at DESC LIMIT 1;

  IF v_post_playing IS NULL THEN
    RAISE EXCEPTION 'Test 1 failed: playing status_change did not get a post_id';
  END IF;

  -- Añadir like y comentario al post de 'playing'
  INSERT INTO public.review_likes (user_id, post_id) VALUES (v_friend, v_post_playing);
  INSERT INTO public.review_comments (user_id, post_id, content)
  VALUES (v_friend, v_post_playing, 'Disfrútalo!')
  RETURNING id INTO v_comment_1;

  -- Pasar la misma reseña a 'beaten' con nota (dispara reviewed y nuevo status_change)
  UPDATE public.reviews
  SET status  = 'beaten',
      rating  = 9.0,
      comment = 'Obra maestra'
  WHERE id = v_review_1;

  SELECT post_id INTO v_post_beaten
  FROM public.activity_feed
  WHERE review_id = v_review_1
    AND action_type = 'status_change'
    AND metadata->>'status' = 'beaten'
  ORDER BY created_at DESC LIMIT 1;

  IF v_post_beaten IS NULL OR v_post_beaten = v_post_playing THEN
    RAISE EXCEPTION 'Test 1 failed: beaten status_change should have a new post_id (playing=%, beaten=%)',
      v_post_playing, v_post_beaten;
  END IF;

  -- Verificar Test 2: la fila 'reviewed' comparte post_id con el status_change 'beaten'
  SELECT count(*) INTO v_count
  FROM public.activity_feed
  WHERE review_id = v_review_1
    AND action_type = 'reviewed'
    AND post_id = v_post_beaten;

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Test 2 failed: reviewed row did not follow status_change to post %', v_post_beaten;
  END IF;

  -- Verificar contadores independientes entre post antiguo y post nuevo
  SELECT * INTO v_stats FROM public.get_post_stats(ARRAY[v_post_playing]);
  IF v_stats.likes_count <> 1 OR v_stats.comments_count <> 1 THEN
    RAISE EXCEPTION 'Test 1 failed: old post lost its interactions (%)', v_stats;
  END IF;

  SELECT * INTO v_stats FROM public.get_post_stats(ARRAY[v_post_beaten]);
  IF v_stats.likes_count <> 0 OR v_stats.comments_count <> 0 OR v_stats.liked_by_me THEN
    RAISE EXCEPTION 'Test 1 failed: new post did not start clean (%)', v_stats;
  END IF;

  -- ===========================================================================
  -- 3. Ventana de 60 min y estados agrupables +
  -- 4. Reseña enriquecida no se une a grupo +
  -- 5. Separación al enriquecer una reseña agrupada (Fase 2)
  -- ===========================================================================
  -- Juego 2: to_play escueto en t = -40 min
  INSERT INTO public.activity_feed (user_id, game_id, action_type, metadata, created_at)
  VALUES (
    v_author,
    v_game_2,
    'status_change',
    jsonb_build_object('status', 'to_play'),
    now() - interval '40 minutes'
  );

  SELECT post_id INTO v_post_g1
  FROM public.activity_feed
  WHERE user_id = v_author AND game_id = v_game_2 AND action_type = 'status_change'
  ORDER BY created_at DESC LIMIT 1;

  -- Juego 3: to_play escueto en t = -20 min (a 20 min <= 60 min -> mismo post)
  INSERT INTO public.activity_feed (user_id, game_id, action_type, metadata, created_at)
  VALUES (
    v_author,
    v_game_3,
    'status_change',
    jsonb_build_object('status', 'to_play'),
    now() - interval '20 minutes'
  );

  SELECT post_id INTO v_post_g2
  FROM public.activity_feed
  WHERE user_id = v_author AND game_id = v_game_3 AND action_type = 'status_change'
  ORDER BY created_at DESC LIMIT 1;

  IF v_post_g1 IS DISTINCT FROM v_post_g2 THEN
    RAISE EXCEPTION 'Test 3 failed: two bare to_play items within 20 min were not grouped (% vs %)',
      v_post_g1, v_post_g2;
  END IF;

  -- Juego 4: to_play escueto a +65 min del ends_at del grupo -> nuevo post
  INSERT INTO public.activity_feed (user_id, game_id, action_type, metadata, created_at)
  VALUES (
    v_author,
    v_game_4,
    'status_change',
    jsonb_build_object('status', 'to_play'),
    now() + interval '50 minutes'
  );

  SELECT post_id INTO v_post_g3
  FROM public.activity_feed
  WHERE user_id = v_author AND game_id = v_game_4 AND action_type = 'status_change'
  ORDER BY created_at DESC LIMIT 1;

  IF v_post_g3 = v_post_g1 THEN
    RAISE EXCEPTION 'Test 3 failed: item beyond 60 min window was grouped into old post';
  END IF;

  -- Estado 'dropped' nunca es groupable
  INSERT INTO public.activity_feed (user_id, game_id, action_type, metadata, created_at)
  VALUES (
    v_author,
    v_game_4,
    'status_change',
    jsonb_build_object('status', 'dropped'),
    now() + interval '55 minutes'
  );

  SELECT p.groupable INTO v_groupable
  FROM public.activity_feed af
  JOIN public.feed_posts p ON p.id = af.post_id
  WHERE af.user_id = v_author
    AND af.game_id = v_game_4
    AND af.metadata->>'status' = 'dropped'
  LIMIT 1;

  IF v_groupable THEN
    RAISE EXCEPTION 'Test 3 failed: dropped status_change was marked groupable';
  END IF;

  -- Test 4 y 5: vincular una reseña al Juego 3 (que estaba en el post agrupado v_post_g1)
  -- y enriquecerla con texto sin cambiar el estado -> debe separarse a su propio post
  INSERT INTO public.reviews (user_id, game_id, status)
  VALUES (v_author, v_game_3, 'to_play')
  RETURNING id INTO v_review_3;

  DELETE FROM public.activity_feed
  WHERE user_id = v_author AND game_id = v_game_3 AND post_id <> v_post_g1;

  UPDATE public.activity_feed
  SET review_id = v_review_3
  WHERE user_id = v_author AND game_id = v_game_3 AND post_id = v_post_g1;

  -- Ahora editar v_review_3 añadiendo comentario sin cambiar su estado 'to_play'
  UPDATE public.reviews
  SET comment = 'Le tengo muchísimas ganas por el director.'
  WHERE id = v_review_3;

  SELECT post_id INTO v_post_rich
  FROM public.activity_feed
  WHERE review_id = v_review_3 AND action_type = 'status_change'
  LIMIT 1;

  IF v_post_rich = v_post_g1 THEN
    RAISE EXCEPTION 'Test 5 failed: enriched review was not split from grouped post %', v_post_g1;
  END IF;

  -- ===========================================================================
  -- 6. Reseña sin evento en el feed (ensure_review_post idempotente)
  -- ===========================================================================
  INSERT INTO public.reviews (user_id, game_id, status)
  VALUES (v_author, v_game_4, 'wishlist')
  RETURNING id INTO v_review_4;

  DELETE FROM public.activity_feed WHERE review_id = v_review_4;
  DELETE FROM public.feed_posts WHERE review_id = v_review_4;

  v_post_impl_1 := public.ensure_review_post(v_review_4);
  v_post_impl_2 := public.ensure_review_post(v_review_4);

  IF v_post_impl_1 IS NULL OR v_post_impl_1 <> v_post_impl_2 THEN
    RAISE EXCEPTION 'Test 6 failed: ensure_review_post is not idempotent (% vs %)',
      v_post_impl_1, v_post_impl_2;
  END IF;

  -- ===========================================================================
  -- 7. Cliente antiguo (INSERT con review_id y sin post_id)
  -- ===========================================================================
  INSERT INTO public.review_likes (user_id, review_id)
  VALUES (v_friend, v_review_1);

  SELECT count(*) INTO v_count
  FROM public.review_likes
  WHERE user_id = v_friend
    AND post_id = v_post_beaten
    AND review_id = v_review_1;

  IF v_count <> 1 THEN
    RAISE EXCEPTION 'Test 7 failed: legacy like without post_id did not resolve to current post %',
      v_post_beaten;
  END IF;

  -- ===========================================================================
  -- 8. Respuesta cruzada rechazada (parent_comment_id de otro post)
  -- ===========================================================================
  v_err_caught := false;
  BEGIN
    INSERT INTO public.review_comments (user_id, post_id, parent_comment_id, content)
    VALUES (v_author, v_post_beaten, v_comment_1, 'Respuesta en otro post');
  EXCEPTION WHEN OTHERS THEN
    v_err_caught := true;
  END;

  IF NOT v_err_caught THEN
    RAISE EXCEPTION 'Test 8 failed: cross-post reply was not rejected';
  END IF;

  -- ===========================================================================
  -- 9. Notificaciones en grupo (games_count > 1, review_id NULL)
  -- ===========================================================================
  UPDATE public.activity_feed
  SET post_id = v_post_g1
  WHERE user_id = v_author AND game_id = v_game_3 AND action_type = 'status_change';

  INSERT INTO public.review_comments (user_id, post_id, content)
  VALUES (v_friend, v_post_g1, 'Qué buena lista de pendientes!');

  SELECT * INTO v_notif
  FROM public.notifications
  WHERE recipient_id = v_author
    AND actor_id = v_friend
    AND post_id = v_post_g1
    AND type = 'comment'
  ORDER BY created_at DESC LIMIT 1;

  IF v_notif.id IS NULL OR (v_notif.metadata->>'games_count')::int <> 2 THEN
    RAISE EXCEPTION 'Test 9 failed: group comment notification missing or wrong games_count (%)',
      v_notif.metadata;
  END IF;
END;
$$;

ROLLBACK;
