CREATE OR REPLACE FUNCTION public.search_active_bundles(search_term text)
RETURNS SETOF active_bundles
LANGUAGE sql
STABLE
AS $$
  SELECT *
  FROM active_bundles
  WHERE title ILIKE '%' || search_term || '%'
     OR tiers::text ILIKE '%' || search_term || '%'
  ORDER BY end_date ASC;
$$;
