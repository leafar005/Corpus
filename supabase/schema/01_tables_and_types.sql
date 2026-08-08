-- 01_tables_and_types.sql: Types, Tables, Views, Sequences, Defaults

--
-- PostgreSQL database dump
--

\restrict 0cDrm7FoDe6HlmT2s9dUrgvsspdJksfxM3Mz5DdjB0RA261uTPkvtrDFQqt4HnY

-- Dumped from database version 17.6
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--

-- Name: public; Type: SCHEMA; Schema: -; Owner: -
--

CREATE SCHEMA public;


--

-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON SCHEMA public IS 'standard public schema';


--

-- Name: game_status; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.game_status AS ENUM (
    'playing',
    'beaten',
    'wishlist',
    'abandoned',
    'on_hold'
);


--

-- Name: achievements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.achievements (
    id text NOT NULL,
    name text NOT NULL,
    description text NOT NULL,
    category text NOT NULL,
    xp_reward integer DEFAULT 0 NOT NULL,
    rarity text NOT NULL,
    icon_name text NOT NULL
);


--

-- Name: active_bundles; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.active_bundles (
    id text NOT NULL,
    title text NOT NULL,
    store_name text NOT NULL,
    url text NOT NULL,
    end_date timestamp with time zone,
    tiers jsonb DEFAULT '[]'::jsonb NOT NULL,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--

-- Name: activity_feed; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.activity_feed (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    action_type text NOT NULL,
    game_id integer,
    metadata jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT activity_feed_action_type_check CHECK ((action_type = ANY (ARRAY['status_change'::text, 'reviewed'::text, 'achievement'::text])))
);


--

-- Name: friendships; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.friendships (
    requester_id uuid NOT NULL,
    addressee_id uuid NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    CONSTRAINT friendships_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'accepted'::text]))),
    CONSTRAINT no_self_friend CHECK ((requester_id <> addressee_id))
);


--

-- Name: games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.games (
    igdb_id integer NOT NULL,
    title text NOT NULL,
    cover_url text,
    release_date date,
    genres jsonb,
    steam_app_id integer,
    summary text,
    platforms jsonb,
    developer text,
    category integer,
    parent_game integer,
    themes jsonb,
    game_modes jsonb,
    player_perspectives jsonb,
    collection text,
    franchises text[],
    game_engines text[]
);


--

-- Name: TABLE games; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON TABLE public.games IS 'Catalogo de juegos (solo lectura para usuarios). INSERT permitido para autenticados. UPDATE/DELETE solo por service_role o funciones SECURITY DEFINER.';


--

-- Name: hall_of_fame; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.hall_of_fame (
    user_id uuid NOT NULL,
    game_id integer,
    pin_order integer NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT hall_of_fame_pin_order_check CHECK (((pin_order >= 1) AND (pin_order <= 5)))
);


--

-- Name: review_comments; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_comments (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    content text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    review_id uuid NOT NULL,
    image_url text,
    attached_game jsonb,
    CONSTRAINT review_comments_content_check CHECK (((char_length(content) <= 500) AND (char_length(content) > 0))),
    CONSTRAINT review_comments_content_or_image_check CHECK ((((content IS NOT NULL) AND (char_length(content) > 0)) OR ((image_url IS NOT NULL) AND (char_length(image_url) > 0)) OR (attached_game IS NOT NULL)))
);


--

-- Name: review_likes; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review_likes (
    user_id uuid NOT NULL,
    created_at timestamp with time zone DEFAULT now(),
    review_id uuid NOT NULL
);


--

-- Name: reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    user_id uuid NOT NULL,
    game_id integer NOT NULL,
    rating double precision,
    rating_gameplay double precision,
    rating_narrative double precision,
    rating_soundtrack double precision,
    rating_visuals double precision,
    comment text,
    status text DEFAULT 'beaten'::text NOT NULL,
    completion_type text DEFAULT 'story'::text NOT NULL,
    partner_ids uuid[] DEFAULT '{}'::uuid[],
    is_replay boolean DEFAULT false NOT NULL,
    replay_number integer,
    platform text,
    play_time_hours double precision,
    played_from date,
    played_until date,
    progress_percent integer,
    created_at timestamp with time zone DEFAULT now(),
    image_urls text[] DEFAULT '{}'::text[],
    CONSTRAINT reviews_progress_percent_check CHECK (((progress_percent >= 0) AND (progress_percent <= 100))),
    CONSTRAINT reviews_rating_check CHECK (((rating >= (1)::double precision) AND (rating <= (10)::double precision))),
    CONSTRAINT reviews_rating_gameplay_check CHECK (((rating_gameplay >= (1)::double precision) AND (rating_gameplay <= (10)::double precision))),
    CONSTRAINT reviews_rating_narrative_check CHECK (((rating_narrative >= (1)::double precision) AND (rating_narrative <= (10)::double precision))),
    CONSTRAINT reviews_rating_soundtrack_check CHECK (((rating_soundtrack >= (1)::double precision) AND (rating_soundtrack <= (10)::double precision))),
    CONSTRAINT reviews_rating_visuals_check CHECK (((rating_visuals >= (1)::double precision) AND (rating_visuals <= (10)::double precision)))
);


--

-- Name: stash_community_reviews; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stash_community_reviews (
    id uuid DEFAULT gen_random_uuid() NOT NULL,
    game_id integer,
    stash_user_display_name text,
    stash_user_avatar_url text,
    comment text,
    rating numeric(3,1),
    source_context text,
    stash_created_at timestamp with time zone,
    imported_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
    CONSTRAINT stash_community_reviews_source_context_check CHECK ((source_context = ANY (ARRAY['game_reviews'::text, 'recent_activity_feed'::text])))
);


--

-- Name: stash_game_stats; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stash_game_stats (
    game_id integer NOT NULL,
    stash_rating numeric,
    want_count integer,
    playing_count integer,
    played_count integer,
    reviews_count integer,
    last_stats_checked_at timestamp with time zone,
    last_reviews_total_checked_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--

-- Name: stash_sync_metadata; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.stash_sync_metadata (
    game_id integer NOT NULL,
    last_checked_at timestamp with time zone DEFAULT timezone('utc'::text, now())
);


--

-- Name: user_achievements; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_achievements (
    user_id uuid NOT NULL,
    achievement_id text NOT NULL,
    unlocked_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);


--

-- Name: user_games; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.user_games (
    user_id uuid NOT NULL,
    game_id integer NOT NULL,
    status public.game_status DEFAULT 'wishlist'::public.game_status NOT NULL,
    rating numeric(3,1),
    rating_gameplay numeric(3,1),
    rating_soundtrack numeric(3,1),
    rating_visuals numeric(3,1),
    comment text,
    partner_ids uuid[] DEFAULT '{}'::uuid[],
    play_count integer DEFAULT 1 NOT NULL,
    play_time_hours numeric,
    last_played_at timestamp with time zone,
    updated_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    rating_narrative real,
    CONSTRAINT user_games_rating_check CHECK (((rating >= (1)::numeric) AND (rating <= (10)::numeric))),
    CONSTRAINT user_games_rating_gameplay_check CHECK (((rating_gameplay >= (1)::numeric) AND (rating_gameplay <= (10)::numeric))),
    CONSTRAINT user_games_rating_soundtrack_check CHECK (((rating_soundtrack >= (1)::numeric) AND (rating_soundtrack <= (10)::numeric))),
    CONSTRAINT user_games_rating_visuals_check CHECK (((rating_visuals >= (1)::numeric) AND (rating_visuals <= (10)::numeric)))
);


--

-- Name: users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.users (
    id uuid NOT NULL,
    username text NOT NULL,
    avatar_url text,
    banner_url text,
    steam_id text,
    created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
    display_name text,
    bio text,
    platforms jsonb DEFAULT '[]'::jsonb,
    xp integer DEFAULT 0 NOT NULL
);


--

-- Name: v_friend_pairs; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.v_friend_pairs WITH (security_invoker='true') AS
 SELECT friendships.requester_id AS user_id,
    friendships.addressee_id AS friend_id
   FROM public.friendships
  WHERE (friendships.status = 'accepted'::text)
UNION ALL
 SELECT friendships.addressee_id AS user_id,
    friendships.requester_id AS friend_id
   FROM public.friendships
  WHERE (friendships.status = 'accepted'::text);


--

-- Name: VIEW v_friend_pairs; Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON VIEW public.v_friend_pairs IS 'Vista simetrica de amistades aceptadas. Para cada par (A,B) genera dos filas: (A->B) y (B->A). Usala para obtener todos los amigos de un usuario con una sola query: SELECT friend_id FROM v_friend_pairs WHERE user_id = $1';


--

-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--

-- Name: DEFAULT PRIVILEGES FOR SEQUENCES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON SEQUENCES TO service_role;


--

-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--

-- Name: DEFAULT PRIVILEGES FOR FUNCTIONS; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON FUNCTIONS TO service_role;


--

-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--

-- Name: DEFAULT PRIVILEGES FOR TABLES; Type: DEFAULT ACL; Schema: public; Owner: -
--

ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO postgres;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO anon;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO authenticated;
ALTER DEFAULT PRIVILEGES FOR ROLE supabase_admin IN SCHEMA public GRANT ALL ON TABLES TO service_role;


--
-- PostgreSQL database dump complete
--

\unrestrict 0cDrm7FoDe6HlmT2s9dUrgvsspdJksfxM3Mz5DdjB0RA261uTPkvtrDFQqt4HnY

