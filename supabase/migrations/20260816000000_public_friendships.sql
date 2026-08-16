-- Permitir a cualquier usuario autenticado ver las amistades aceptadas de otros usuarios
-- Esto es necesario para poder mostrar la cuenta de amigos en perfiles ajenos y la lista de amigos.

CREATE POLICY "Anyone can view accepted friendships" 
ON public.friendships 
FOR SELECT 
USING (status = 'accepted');
