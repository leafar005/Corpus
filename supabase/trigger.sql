-- =========================================================================
-- CORPUS: TRIGGER AUTOMÁTICO DE REGISTRO
-- =========================================================================

-- 1. Creamos la "Función" (Las instrucciones que debe seguir el robot)
CREATE OR REPLACE FUNCTION public.handle_new_user() 
RETURNS trigger AS $$
BEGIN
  -- Inserta una nueva fila en nuestra tabla pública 'users'
  INSERT INTO public.users (id, username, avatar_url)
  VALUES (
    new.id, 
    -- Extrae el 'username' que le enviaremos desde la app de Flutter
    new.raw_user_meta_data->>'username',
    -- De regalo, le generamos un avatar temporal con sus iniciales usando una API gratuita
    'https://ui-avatars.com/api/?name=' || (new.raw_user_meta_data->>'username') || '&background=random'
  );
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Creamos el "Trigger" (El robot que está vigilando)
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE PROCEDURE public.handle_new_user();
