-- =============================================================================
-- Ajustes de usuario sincronizados entre dispositivos (apariencia, grid,
-- comportamiento, personalización de Home e Info tab). Antes vivían solo en
-- SharedPreferences del dispositivo; ahora Supabase es la fuente de verdad y
-- SharedPreferences pasa a ser una caché local de lectura rápida.
-- =============================================================================

CREATE TABLE public.user_settings (
    user_id                        uuid PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,

    -- Apariencia
    theme_mode                     text NOT NULL DEFAULT 'system'
                                        CHECK (theme_mode IN ('system', 'light', 'dark')),
    theme_color                    bigint,
    style_pack_id                  text NOT NULL DEFAULT 'default',

    -- Grid y navegación (móvil)
    mobile_grid_columns            smallint NOT NULL DEFAULT 3
                                        CHECK (mobile_grid_columns IN (2, 3, 4)),
    floating_mobile_nav            boolean NOT NULL DEFAULT true,

    -- Comportamiento / integraciones
    localize_links                 boolean NOT NULL DEFAULT true,
    time_source_pref               text NOT NULL DEFAULT 'igdb'
                                        CHECK (time_source_pref IN ('igdb', 'duracionde')),

    -- Personalización de Home
    home_sections_order            text[] NOT NULL DEFAULT ARRAY[
                                        'hero', 'bundles_ending_soon', 'stash_activity',
                                        'wishlist_anticipated', 'anticipated_games'
                                    ],
    home_sections_hidden           text[] NOT NULL DEFAULT ARRAY[]::text[],
    anticipated_countdown_style    text NOT NULL DEFAULT 'days_only'
                                        CHECK (anticipated_countdown_style IN ('full', 'days_only')),
    wishlist_countdown_style       text NOT NULL DEFAULT 'days_only'
                                        CHECK (wishlist_countdown_style IN ('full', 'days_only')),
    home_bundles_ending_soon_days  smallint NOT NULL DEFAULT 3
                                        CHECK (home_bundles_ending_soon_days BETWEEN 1 AND 30),

    -- Personalización de la pestaña Info (detalles de juego)
    info_tab_order                 text[] NOT NULL DEFAULT ARRAY[
                                        'franchise', 'genres_themes', 'platforms', 'metacritic',
                                        'stash_stats', 'summary', 'hltb', 'engine'
                                    ],
    info_tab_hidden                text[] NOT NULL DEFAULT ARRAY[]::text[],

    updated_at                     timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.user_settings IS
    'Ajustes de apariencia/comportamiento por usuario, sincronizados entre dispositivos. '
    'Una fila por usuario. La fila NO se crea por trigger de signup: la crea el cliente de '
    'forma perezosa (upsert) la primera vez que sincroniza, para poder sembrarla con los '
    'valores que el usuario ya tuviera en local si es una cuenta preexistente.';

COMMENT ON COLUMN public.user_settings.theme_color IS
    'Color.toARGB32() guardado como bigint. OJO: no puede ser int4 — con el canal alpha a '
    '0xFF el valor supera el rango de un entero de 32 bits con signo (p.ej. Colors.redAccent '
    '= 0xFFFF5252 = 4293676370, > 2147483647). NULL = heredar el seedColor del style pack activo.';

-- ─────────────────────────────────────────────────────────────────────────────
-- RLS
-- ─────────────────────────────────────────────────────────────────────────────

ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user owns their settings"
    ON public.user_settings FOR ALL
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

-- No hace falta política de service_role: a diferencia de notification_preferences,
-- ninguna función de servidor necesita leer los ajustes de otros usuarios.

-- ─────────────────────────────────────────────────────────────────────────────
-- updated_at automático
-- ─────────────────────────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.touch_user_settings_updated_at()
RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_user_settings_touch_updated_at
  BEFORE UPDATE ON public.user_settings
  FOR EACH ROW EXECUTE FUNCTION public.touch_user_settings_updated_at();
