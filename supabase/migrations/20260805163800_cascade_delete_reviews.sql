-- Migration to add ON DELETE CASCADE to reviews_user_id_users_fkey
ALTER TABLE public.reviews
  DROP CONSTRAINT IF EXISTS reviews_user_id_users_fkey;

ALTER TABLE public.reviews
  ADD CONSTRAINT reviews_user_id_users_fkey 
  FOREIGN KEY (user_id) 
  REFERENCES public.users(id) 
  ON DELETE CASCADE;
