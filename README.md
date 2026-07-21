# Corpus

> Personal & social video game tracker for you and your friends.

Corpus is a cross-platform app (Flutter) built around one idea: your gaming library should be yours — detailed, private, and shared only with the people you actually play with.

It combines a personal game journal with a closed social layer for your group, enriches everything automatically with data from IGDB, HowLongToBeat and Stash, and wraps it all in a gamification system that rewards you for actually playing.

---

## Features

### Library
- Track every game with statuses: **Playing, Beaten, Wishlist, Abandoned, On Hold**
- Auto-populated covers, release dates and genres from IGDB
- HowLongToBeat times injected automatically when you add a game
- Saga progress tracker grouped by IGDB collection

### Reviews
- Overall score + per-category breakdown (Gameplay, Soundtrack, …)
- Free-text comments and attached photos
- Co-op partner linking: record who you played it with

### Social (your group)
- Real-time activity feed via Supabase Realtime
- **"Who has it?"** — see instantly which friends own or have played a game
- **Playing now** indicator: shows when someone in the group is actively playing
- Hall of Fame: pin up to 5 games to your profile

### Profile
- Custom avatar and banner
- Genre map: visual breakdown of your library by genre
- Full achievement panel: game milestones + meta achievements (app usage)

### Gamification
- XP and level system triggered on game completion
- Game achievements: "Beat 10 games", "First review", …
- Meta achievements: "6 months active", "50 reviews written", "Never abandoned a 20h+ game"

### Community data
- Stash reviews synced automatically via Edge Function (public HTML scraping)
- Community tab in every game page showing external opinions alongside your own

---

## Stack

| Layer | Technology |
|-------|-----------|
| Frontend | Flutter (Dart) |
| Backend / DB | Supabase (PostgreSQL + Realtime + Storage) |
| Cloud logic | Supabase Edge Functions (Deno / TypeScript) |
| Local cache | Hive / Drift (SQLite) |
| Game metadata | IGDB API |
| Completion times | `howlongtobeat` npm wrapper |
| Community reviews | Stash (public HTML scraping) |
| Web hosting (later) | Vercel |

**Cost: $0.** Everything runs on free tiers sized for small personal projects.

---

## Roadmap

| Phase | Name | Goal |
|-------|------|------|
| 0 | Foundation | Supabase project, core DB schema (users, games), Flutter app boots and authenticates |
| 1 | Core library | Full game CRUD, status management, local cache — usable offline |
| 2 | Real metadata | IGDB search + covers + genres, HLTB times on add |
| 3 | Reviews | Scores, category breakdown, comments, photo upload |
| 4 | Profile | Avatar, banner, Hall of Fame, basic stats |
| 5 | Social | Friend groups, activity feed, "Who has it?", playing now |
| 6 | Community | Stash scraper Edge Function, community tab, co-op partner |
| 7 | Discovery | Saga tracker, genre map |
| 8 | Gamification | XP/levels, game achievements, meta achievements |
| 9 | Web & desktop | `flutter build web` → Vercel, Windows build |

> Each phase ships something usable before moving on. Phases 0–2 are the foundation; everything after builds on stable ground.

---

## Database schema (overview)

```
users             id, username, avatar_url, banner_url
games             igdb_id (PK), title, cover_url, release_date, genres, hltb_time
user_games        user_id, game_id, status, rating, rating_gameplay,
                  rating_soundtrack, comment, partner_id, updated_at
hall_of_fame      user_id, game_id, pin_order (1–5)
community_reviews game_id, user_name_original, review_text, rating, source
user_stats        user_id, total_games_played, xp, level
user_achievements user_id, achievement_id, type (game | meta), unlocked_at
```

---

## External integrations

**IGDB** — official API (Twitch auth). Covers, genres, release dates, saga grouping.

**HowLongToBeat** — via the [`howlongtobeat`](https://www.npmjs.com/package/howlongtobeat) npm wrapper inside an Edge Function. Fires once per new game added.

**Stash** — public HTML scraping of individual review pages (`stash.games/games/{slug}/reviews/{user}`). Runs on a periodic Edge Function with delays. Parser is isolated in its own module for easy maintenance if the HTML structure changes.

---

## Project documentation

The full Software Requirements Specification (SRS) following ISO/IEC/IEEE 29148 is in [`docs/SRS_Corpus.md`](docs/SRS_Corpus.md).

---

## License

Private project. All rights reserved.
