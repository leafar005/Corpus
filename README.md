# Corpus

> Personal & social video game tracker for you and your friends.

Corpus is a cross-platform app (Flutter) built around one idea: your gaming library should be yours — detailed, private, and shared only with the people you actually play with.

It combines a personal game journal with a closed social layer for your group, enriches everything automatically with data from IGDB and Stash, and wraps it all in an extensive gamification system that rewards you for playing and discovering.

---

## Features

### Library
- Track every game with statuses: **Playing, Beaten, Wishlist, Abandoned, On Hold**
- Auto-populated covers, release dates, completion times, and genres from **IGDB**
- Saga progress tracker grouped by IGDB collection

### Reviews & Social
- Overall score + per-category breakdown (Gameplay, Soundtrack, …)
- Free-text comments with attached photos (via Supabase Storage)
- Like and comment on your friends' reviews
- Co-op partner linking: record who you played it with
- **"Who has it?"** — see instantly which friends own or have played a game
- Real-time activity feed via **Supabase Realtime**

### Gamification & Achievements
- Robust XP and level system calculated securely on the database level via PostgreSQL Triggers.
- Meta achievements (app usage) and game milestones.
- **42 Franchises and Sagas Tracked:** Achievements based on the number of games you have completed from franchises and series such as *Kojima Productions, FromSoftware, Nintendo, Rockstar, Yakuza, Persona, Xenoblade, Zelda*, etc.

### Community & Discovery
- **Stash Reviews:** Synced automatically in the background via Edge Functions and `pg_cron` to show external community opinions.
- **Active Bundles:** Integrates with Barter/IGDB to show active game bundles automatically synced every 4 hours.
- Hall of Fame (pin up to 5 games) and visual Genre Map.

---

## Stack & Architecture

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Backend / DB | Supabase (PostgreSQL + Realtime + Storage + pg_cron) |
| DevOps & Schema | Supabase CLI Migrations & Modular SQL Schema |
| Cloud logic | Supabase Edge Functions (Deno / TypeScript) |
| Local storage | `shared_preferences` |
| Game metadata | IGDB API |
| Community reviews | Stash (public HTML scraping via pg_cron) |
| Bundles Sync | Barter API (via pg_cron) |

**Cost: $0.** Everything runs on free tiers sized for small personal projects.

---

## Roadmap

| Phase | Name | Status |
|-------|------|--------|
| 0 | Foundation | ✅ Completed |
| 1 | Core library | ✅ Completed |
| 2 | Real metadata (IGDB) | ✅ Completed |
| 3 | Reviews (Scores, photos, comments) | ✅ Completed |
| 4 | Profile (Avatar, Hall of Fame) | ✅ Completed |
| 5 | Social (Friends, Activity Feed, Likes) | ✅ Completed |
| 6 | Community (Stash scraper) | ✅ Completed |
| 7 | Discovery (Active Bundles, Genre Map) | ✅ Completed |
| 8 | Gamification (42 Sagas, XP, Triggers) | ✅ Completed |
| 9 | Web & desktop builds | ⏳ Pending |

---

## Database schema (overview)

```text
users                      id, username, avatar_url, banner_url, xp, level
games                      igdb_id (PK), title, cover_url, release_date, genres, hltb_time
user_games                 user_id, game_id, status, updated_at
reviews                    id, user_id, game_id, rating, rating_*, comment, image_urls
review_comments            id, review_id, user_id, comment, image_url
review_likes               review_id, user_id
social_friends             user_id_1, user_id_2, status
activity_feed              id, user_id, action_type, game_id, metadata
stash_community_reviews    game_id, user_name_original, review_text, rating
active_bundles             id, title, store_name, url, end_date, tiers
achievements               id, name, category, xp_reward, rarity
user_achievements          user_id, achievement_id
```

## Infrastructure

Corpus maintains a highly robust Supabase backend. All schema changes, storage buckets (`avatars`, `banners`, `user_uploads`), and background tasks (`pg_cron`) are strictly tracked using **Supabase CLI Migrations** (`supabase/migrations`). The public schema documentation is auto-generated and modularized in `supabase/schema/`.

---

## Disclaimer

**Educational & Personal Use Only.**  
The community data features in this application (such as the Stash reviews scraper) are built strictly for academic and personal purposes. Corpus is a private hobby project. There is absolutely no intent to commercialize, monetize, distribute, or promote this application in any way.

---

## License

Private project. All rights reserved.
