-- Enable realtime for steam_import_jobs so the Flutter app can track progress
ALTER PUBLICATION supabase_realtime ADD TABLE public.steam_import_jobs;
