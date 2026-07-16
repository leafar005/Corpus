import { useState } from "react";
import {
  Home,
  BookOpen,
  Search,
  User,
  Plus,
  Bell,
  Star,
  Clock,
  Users,
  Trophy,
  ChevronRight,
  Zap,
  Play,
  Check,
  Heart,
  X,
  Settings,
  ArrowLeft,
  Flame,
  Package,
  MessageCircle,
} from "lucide-react";
import {
  BarChart,
  Bar,
  XAxis,
  YAxis,
  Cell,
  ResponsiveContainer,
} from "recharts";

// ─── Types ────────────────────────────────────────────────────────────────────
type GameStatus = "playing" | "beaten" | "wishlist" | "abandoned" | "on_hold";
type TabScreen = "dashboard" | "library" | "search" | "profile";

interface Game {
  id: number;
  title: string;
  year: number;
  gradient: string;
  status: GameStatus;
  rating: number;
  ratingGameplay: number;
  ratingOST: number;
  hours: number;
  hltb: number;
  genre: string[];
  playCount: number;
  nowPlaying?: boolean;
  comment?: string;
}

interface Friend {
  id: number;
  name: string;
  avatar: string;
  level: number;
  activity: string;
  game: string;
  time: string;
  action: "beaten" | "added" | "playing" | "reviewed";
}

// ─── Mock data ────────────────────────────────────────────────────────────────
const GAMES: Game[] = [
  {
    id: 1,
    title: "Elden Ring",
    year: 2022,
    gradient: "from-amber-950 via-orange-900 to-yellow-900",
    status: "beaten",
    rating: 9.5,
    ratingGameplay: 9,
    ratingOST: 8,
    hours: 87,
    hltb: 58,
    genre: ["RPG", "Action", "Open World"],
    playCount: 2,
    comment: "Una obra monumental. El segundo run fue incluso mejor que el primero.",
  },
  {
    id: 2,
    title: "The Last of Us Part II",
    year: 2020,
    gradient: "from-green-950 via-emerald-900 to-teal-900",
    status: "beaten",
    rating: 9.8,
    ratingGameplay: 9,
    ratingOST: 10,
    hours: 30,
    hltb: 25,
    genre: ["Action", "Adventure", "Narrative"],
    playCount: 1,
    comment: "La banda sonora de Gustavo Santaolalla vuelve a ser perfecta.",
  },
  {
    id: 3,
    title: "Cyberpunk 2077",
    year: 2020,
    gradient: "from-yellow-900 via-amber-800 to-orange-900",
    status: "playing",
    rating: 0,
    ratingGameplay: 0,
    ratingOST: 0,
    hours: 45,
    hltb: 23,
    genre: ["RPG", "Action", "Open World"],
    playCount: 1,
    nowPlaying: true,
  },
  {
    id: 4,
    title: "Hollow Knight",
    year: 2017,
    gradient: "from-slate-900 via-blue-950 to-indigo-950",
    status: "beaten",
    rating: 9.2,
    ratingGameplay: 9.5,
    ratingOST: 9,
    hours: 42,
    hltb: 27,
    genre: ["Metroidvania", "Action", "Platformer"],
    playCount: 1,
  },
  {
    id: 5,
    title: "Disco Elysium",
    year: 2019,
    gradient: "from-violet-950 via-purple-900 to-fuchsia-950",
    status: "beaten",
    rating: 10,
    ratingGameplay: 8,
    ratingOST: 10,
    hours: 38,
    hltb: 20,
    genre: ["RPG", "Mystery", "Narrative"],
    playCount: 1,
    comment: "El mejor juego de rol que he jugado. Irrepetible.",
  },
  {
    id: 6,
    title: "Hades",
    year: 2020,
    gradient: "from-red-950 via-rose-900 to-pink-900",
    status: "beaten",
    rating: 9.6,
    ratingGameplay: 9.8,
    ratingOST: 9.5,
    hours: 55,
    hltb: 22,
    genre: ["Roguelike", "Action", "Hack & Slash"],
    playCount: 3,
    comment: "El roguelike definitivo. Maté a Hades 30 veces y no me cansé.",
  },
  {
    id: 7,
    title: "Baldur's Gate 3",
    year: 2023,
    gradient: "from-zinc-900 via-neutral-800 to-stone-900",
    status: "playing",
    rating: 0,
    ratingGameplay: 0,
    ratingOST: 0,
    hours: 62,
    hltb: 100,
    genre: ["RPG", "Strategy", "Adventure"],
    playCount: 1,
    nowPlaying: false,
  },
  {
    id: 8,
    title: "God of War Ragnarök",
    year: 2022,
    gradient: "from-cyan-950 via-blue-900 to-sky-900",
    status: "wishlist",
    rating: 0,
    ratingGameplay: 0,
    ratingOST: 0,
    hours: 0,
    hltb: 26,
    genre: ["Action", "Adventure", "Mythology"],
    playCount: 0,
  },
  {
    id: 9,
    title: "Red Dead Redemption 2",
    year: 2018,
    gradient: "from-orange-950 via-amber-900 to-yellow-950",
    status: "abandoned",
    rating: 7,
    ratingGameplay: 6,
    ratingOST: 9,
    hours: 28,
    hltb: 50,
    genre: ["Open World", "Adventure", "Western"],
    playCount: 1,
    comment: "Increíble ambientación pero el ritmo me venció. Quizá lo retome.",
  },
  {
    id: 10,
    title: "Spider-Man 2",
    year: 2023,
    gradient: "from-red-900 via-red-800 to-rose-900",
    status: "on_hold",
    rating: 0,
    ratingGameplay: 0,
    ratingOST: 0,
    hours: 12,
    hltb: 15,
    genre: ["Action", "Open World", "Superhero"],
    playCount: 1,
  },
];

const FRIENDS: Friend[] = [
  {
    id: 1,
    name: "Marco V.",
    avatar: "MV",
    level: 18,
    activity: "completó",
    game: "Elden Ring",
    time: "hace 2 h",
    action: "beaten",
  },
  {
    id: 2,
    name: "Sara K.",
    avatar: "SK",
    level: 31,
    activity: "está jugando",
    game: "Hollow Knight",
    time: "ahora",
    action: "playing",
  },
  {
    id: 3,
    name: "Pau M.",
    avatar: "PM",
    level: 22,
    activity: "añadió a wishlist",
    game: "God of War Ragnarök",
    time: "hace 5 h",
    action: "added",
  },
  {
    id: 4,
    name: "Marco V.",
    avatar: "MV",
    level: 18,
    activity: "reseñó",
    game: "Hades",
    time: "ayer",
    action: "reviewed",
  },
];

const GENRE_DATA = [
  { genre: "Action", count: 7, color: "#8b5cf6" },
  { genre: "RPG", count: 4, color: "#06b6d4" },
  { genre: "Adventure", count: 4, color: "#10b981" },
  { genre: "Open World", count: 3, color: "#f59e0b" },
  { genre: "Narrative", count: 2, color: "#ec4899" },
  { genre: "Roguelike", count: 1, color: "#ef4444" },
];

const ACHIEVEMENTS = [
  { id: 1, title: "Primer Completado", desc: "Completa tu primer juego", icon: "🏆", unlocked: true },
  { id: 2, title: "Dedicación Total", desc: "10 juegos completados", icon: "💎", unlocked: true },
  { id: 3, title: "Crítico", desc: "Escribe 10 reseñas", icon: "✍️", unlocked: true },
  { id: 4, title: "Maratonista", desc: "100+ horas registradas", icon: "⏱️", unlocked: true },
  { id: 5, title: "Social", desc: "Únete a un grupo", icon: "👥", unlocked: false },
  { id: 6, title: "6 Meses Activo", desc: "Actividad 6 meses seguidos", icon: "📅", unlocked: false },
];

const STATUS_CONFIG: Record<GameStatus, { label: string; color: string; bg: string }> = {
  playing: { label: "Jugando", color: "text-amber-400", bg: "bg-amber-400/10" },
  beaten: { label: "Completado", color: "text-emerald-400", bg: "bg-emerald-400/10" },
  wishlist: { label: "Wishlist", color: "text-violet-400", bg: "bg-violet-400/10" },
  abandoned: { label: "Abandonado", color: "text-red-400", bg: "bg-red-400/10" },
  on_hold: { label: "En Pausa", color: "text-sky-400", bg: "bg-sky-400/10" },
};

// ─── Shared components ────────────────────────────────────────────────────────
function GameCover({ game, size = "md" }: { game: Game; size?: "sm" | "md" | "lg" }) {
  const sizeMap = { sm: "w-12 h-16", md: "w-[72px] h-24", lg: "w-full h-44" };
  return (
    <div
      className={`${sizeMap[size]} relative rounded-xl overflow-hidden flex-shrink-0 bg-gradient-to-br ${game.gradient} flex flex-col`}
    >
      <div className="flex-1 flex items-center justify-center">
        <span className="text-white/15 font-bold font-display text-xl">
          {game.title.split(" ").map((w) => w[0]).join("").slice(0, 3)}
        </span>
      </div>
      <div className="px-1.5 pb-1.5 bg-gradient-to-t from-black/70 via-black/30 to-transparent pt-3">
        <p className="text-white text-[9px] font-semibold leading-tight line-clamp-2">{game.title}</p>
      </div>
      {game.nowPlaying && (
        <span className="absolute top-1.5 right-1.5 w-2 h-2 rounded-full bg-emerald-400 shadow-lg shadow-emerald-400/60" />
      )}
    </div>
  );
}

function StatusBadge({ status }: { status: GameStatus }) {
  const cfg = STATUS_CONFIG[status];
  return (
    <span className={`inline-flex items-center px-2 py-0.5 rounded-full text-[10px] font-semibold ${cfg.color} ${cfg.bg}`}>
      {cfg.label}
    </span>
  );
}

function StarRow({ value, max = 10 }: { value: number; max?: number }) {
  const filled = Math.round((value / max) * 5);
  return (
    <div className="flex gap-0.5">
      {Array.from({ length: 5 }).map((_, i) => (
        <Star
          key={i}
          size={10}
          className={i < filled ? "fill-amber-400 text-amber-400" : "text-white/15"}
        />
      ))}
    </div>
  );
}

function XPBar({ xp, cap = 1000 }: { xp: number; cap?: number }) {
  const pct = ((xp % cap) / cap) * 100;
  return (
    <div className="w-full h-1.5 bg-white/10 rounded-full overflow-hidden">
      <div
        className="h-full bg-gradient-to-r from-violet-500 to-fuchsia-500 rounded-full"
        style={{ width: `${pct}%` }}
      />
    </div>
  );
}

function FriendAvatar({ initials, size = "sm" }: { initials: string; size?: "sm" | "md" }) {
  const s = size === "sm" ? "w-7 h-7 text-[9px]" : "w-9 h-9 text-[10px]";
  return (
    <div className={`${s} rounded-full bg-gradient-to-br from-violet-500 to-fuchsia-600 flex items-center justify-center flex-shrink-0`}>
      <span className="text-white font-bold">{initials}</span>
    </div>
  );
}

// ─── Dashboard ────────────────────────────────────────────────────────────────
function DashboardScreen({ onGameTap }: { onGameTap: (g: Game) => void }) {
  const playing = GAMES.filter((g) => g.status === "playing");
  return (
    <div className="flex flex-col h-full overflow-y-auto scrollbar-hide">
      {/* Header */}
      <div className="px-4 pt-2 pb-3 flex items-center justify-between">
        <div>
          <p className="text-white/30 text-[11px] font-medium">Bienvenido de nuevo</p>
          <h1 className="text-white text-xl font-bold font-display leading-tight">Rafael</h1>
        </div>
        <div className="flex items-center gap-2">
          <div className="flex items-center gap-1.5 bg-violet-500/15 border border-violet-500/20 rounded-full px-2.5 py-1">
            <Zap size={11} className="text-violet-400" />
            <span className="text-violet-300 text-xs font-bold font-display">Niv. 24</span>
          </div>
          <button className="relative w-8 h-8 rounded-full bg-white/5 border border-white/8 flex items-center justify-center">
            <Bell size={15} className="text-white/50" />
            <span className="absolute top-0.5 right-0.5 w-1.5 h-1.5 bg-violet-500 rounded-full" />
          </button>
        </div>
      </div>

      {/* XP Progress */}
      <div className="px-4 mb-4">
        <div className="flex justify-between mb-1">
          <span className="text-white/25 text-[10px]">847 XP</span>
          <span className="text-white/25 text-[10px]">1000 XP · Nivel 25</span>
        </div>
        <XPBar xp={847} />
      </div>

      {/* Bundle alert */}
      <div className="mx-4 mb-4 rounded-2xl bg-amber-500/8 border border-amber-500/20 p-3 flex items-center gap-3">
        <div className="w-8 h-8 rounded-xl bg-amber-500/20 flex items-center justify-center flex-shrink-0">
          <Package size={15} className="text-amber-400" />
        </div>
        <div className="flex-1 min-w-0">
          <p className="text-amber-300 text-[11px] font-semibold">¡Juego de tu Wishlist en bundle!</p>
          <p className="text-amber-200/50 text-[10px] truncate">God of War Ragnarök — Humble Bundle · 72 h restantes</p>
        </div>
        <ChevronRight size={14} className="text-amber-400/60 flex-shrink-0" />
      </div>

      {/* Playing Now */}
      <div className="mb-5">
        <div className="px-4 flex items-center justify-between mb-2.5">
          <h2 className="text-white text-sm font-semibold font-display">Jugando ahora</h2>
          <button className="text-violet-400 text-xs">Ver todo</button>
        </div>
        <div className="flex gap-3 px-4 overflow-x-auto scrollbar-hide pb-1">
          {playing.map((game) => (
            <button key={game.id} onClick={() => onGameTap(game)} className="flex flex-col gap-1.5 flex-shrink-0">
              <GameCover game={game} size="md" />
              <div className="w-[72px]">
                <p className="text-white/70 text-[10px] font-medium leading-tight line-clamp-2">{game.title}</p>
                <p className="text-white/25 text-[9px] mt-0.5">{game.hours}h jugadas</p>
              </div>
            </button>
          ))}
          <button className="flex-shrink-0 w-[72px] h-24 rounded-xl border-2 border-dashed border-white/8 flex flex-col items-center justify-center gap-1 text-white/20 hover:border-violet-500/30 hover:text-violet-400/60 transition-colors">
            <Plus size={16} />
            <span className="text-[9px]">Añadir</span>
          </button>
        </div>
      </div>

      {/* Activity feed */}
      <div className="px-4 pb-4">
        <h2 className="text-white text-sm font-semibold font-display mb-3">Actividad del grupo</h2>
        {FRIENDS.map((f, i) => (
          <div key={i} className="flex items-start gap-3 py-3 border-b border-white/[0.04] last:border-0">
            <FriendAvatar initials={f.avatar} size="md" />
            <div className="flex-1 min-w-0">
              <p className="text-white/75 text-xs leading-snug">
                <span className="font-semibold text-white">{f.name}</span>
                {" "}{f.activity}{" "}
                <span className="text-violet-300">{f.game}</span>
              </p>
              <div className="flex items-center gap-2 mt-1">
                <span className="text-white/25 text-[10px]">{f.time}</span>
                {f.action === "beaten" && (
                  <span className="text-emerald-400/70 text-[10px] flex items-center gap-0.5">
                    <Check size={9} /> Completado
                  </span>
                )}
                {f.action === "playing" && (
                  <span className="flex items-center gap-1">
                    <span className="w-1.5 h-1.5 bg-emerald-400 rounded-full animate-pulse" />
                    <span className="text-emerald-400/70 text-[10px]">En línea</span>
                  </span>
                )}
                {f.action === "reviewed" && (
                  <span className="text-sky-400/70 text-[10px] flex items-center gap-0.5">
                    <MessageCircle size={9} /> Reseña
                  </span>
                )}
              </div>
            </div>
            <button className="text-white/15 hover:text-rose-400/60 transition-colors mt-0.5">
              <Heart size={14} />
            </button>
          </div>
        ))}
      </div>
    </div>
  );
}

// ─── Library ──────────────────────────────────────────────────────────────────
function LibraryScreen({ onGameTap }: { onGameTap: (g: Game) => void }) {
  const [filter, setFilter] = useState<GameStatus | "all">("all");

  const filters: Array<{ key: GameStatus | "all"; label: string }> = [
    { key: "all", label: "Todos" },
    { key: "playing", label: "Jugando" },
    { key: "beaten", label: "Completados" },
    { key: "wishlist", label: "Wishlist" },
    { key: "on_hold", label: "En Pausa" },
    { key: "abandoned", label: "Abandonados" },
  ];

  const visible = filter === "all" ? GAMES : GAMES.filter((g) => g.status === filter);

  return (
    <div className="flex flex-col h-full">
      <div className="px-4 pt-2 pb-1">
        <div className="flex items-center justify-between mb-3">
          <h1 className="text-white text-xl font-bold font-display">Biblioteca</h1>
          <span className="text-white/30 text-xs flex items-center gap-1">
            <BookOpen size={11} /> {GAMES.length} juegos
          </span>
        </div>
      </div>

      {/* Filters */}
      <div className="flex gap-2 px-4 overflow-x-auto scrollbar-hide pb-3">
        {filters.map((f) => (
          <button
            key={f.key}
            onClick={() => setFilter(f.key)}
            className={`flex-shrink-0 px-3 py-1.5 rounded-full text-xs font-semibold transition-all ${
              filter === f.key ? "bg-violet-600 text-white" : "bg-white/5 text-white/40 border border-white/8"
            }`}
          >
            {f.label}
          </button>
        ))}
      </div>

      {/* Games */}
      <div className="flex-1 overflow-y-auto scrollbar-hide px-4 pb-20">
        <div className="flex flex-col gap-2">
          {visible.map((game) => (
            <button
              key={game.id}
              onClick={() => onGameTap(game)}
              className="flex items-center gap-3 bg-white/[0.03] border border-white/[0.05] rounded-2xl p-2.5 hover:bg-white/[0.06] transition-all text-left"
            >
              <GameCover game={game} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="text-white text-sm font-semibold leading-tight truncate">{game.title}</p>
                <p className="text-white/25 text-[11px] mt-0.5">{game.year} · {game.genre[0]}</p>
                <div className="flex items-center gap-2 mt-1.5">
                  <StatusBadge status={game.status} />
                  {game.rating > 0 && <StarRow value={game.rating} />}
                </div>
              </div>
              <div className="flex flex-col items-end gap-1.5 flex-shrink-0">
                {game.hours > 0 && (
                  <span className="text-white/25 text-[10px] flex items-center gap-0.5">
                    <Clock size={9} /> {game.hours}h
                  </span>
                )}
                {game.playCount > 1 && (
                  <span className="text-white/30 text-[9px] bg-white/5 px-1.5 py-0.5 rounded-full">
                    ×{game.playCount}
                  </span>
                )}
                <ChevronRight size={13} className="text-white/15" />
              </div>
            </button>
          ))}
        </div>
      </div>

      {/* FAB */}
      <button className="absolute bottom-[76px] right-4 w-12 h-12 rounded-full bg-violet-600 shadow-xl shadow-violet-600/40 flex items-center justify-center hover:bg-violet-500 transition-colors z-10">
        <Plus size={22} className="text-white" />
      </button>
    </div>
  );
}

// ─── Search ───────────────────────────────────────────────────────────────────
function SearchScreen({ onGameTap }: { onGameTap: (g: Game) => void }) {
  const [query, setQuery] = useState("");

  const results =
    query.length > 1
      ? GAMES.filter((g) => g.title.toLowerCase().includes(query.toLowerCase()))
      : [];

  const categories = [
    { name: "RPG", color: "from-violet-900 to-purple-800", count: 4 },
    { name: "Acción", color: "from-red-900 to-rose-800", count: 7 },
    { name: "Mundo Abierto", color: "from-green-900 to-emerald-800", count: 3 },
    { name: "Roguelike", color: "from-orange-900 to-amber-800", count: 1 },
    { name: "Aventura", color: "from-cyan-900 to-blue-800", count: 4 },
    { name: "Narrativo", color: "from-pink-900 to-fuchsia-800", count: 2 },
  ];

  return (
    <div className="flex flex-col h-full overflow-y-auto scrollbar-hide">
      <div className="px-4 pt-2 pb-3">
        <h1 className="text-white text-xl font-bold font-display mb-3">Buscar</h1>
        <div className="flex items-center gap-2.5 bg-white/5 border border-white/8 rounded-2xl px-3.5 py-2.5">
          <Search size={14} className="text-white/25 flex-shrink-0" />
          <input
            type="text"
            placeholder="Buscar juego..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="flex-1 bg-transparent text-white text-sm placeholder:text-white/20 outline-none"
          />
          {query && (
            <button onClick={() => setQuery("")}>
              <X size={14} className="text-white/25" />
            </button>
          )}
        </div>
      </div>

      {results.length > 0 ? (
        <div className="px-4 flex flex-col gap-2">
          {results.map((game) => (
            <button
              key={game.id}
              onClick={() => onGameTap(game)}
              className="flex items-center gap-3 bg-white/[0.03] border border-white/[0.05] rounded-2xl p-2.5 text-left"
            >
              <GameCover game={game} size="sm" />
              <div className="flex-1 min-w-0">
                <p className="text-white text-sm font-semibold truncate">{game.title}</p>
                <p className="text-white/30 text-xs">{game.year} · {game.genre[0]}</p>
                <div className="mt-1">
                  <StatusBadge status={game.status} />
                </div>
              </div>
            </button>
          ))}
        </div>
      ) : !query ? (
        <div className="px-4 flex flex-col gap-5">
          <div>
            <p className="text-white/25 text-[10px] font-semibold uppercase tracking-widest mb-3">Categorías</p>
            <div className="grid grid-cols-2 gap-2.5">
              {categories.map((cat) => (
                <button
                  key={cat.name}
                  className={`bg-gradient-to-br ${cat.color} rounded-2xl p-4 text-left hover:brightness-110 transition-all`}
                >
                  <p className="text-white font-bold text-sm font-display">{cat.name}</p>
                  <p className="text-white/50 text-xs mt-0.5">{cat.count} juegos</p>
                </button>
              ))}
            </div>
          </div>

          <div>
            <p className="text-white/25 text-[10px] font-semibold uppercase tracking-widest mb-3">Vistos recientemente</p>
            <div className="flex flex-col gap-2.5">
              {GAMES.slice(0, 4).map((game) => (
                <button
                  key={game.id}
                  onClick={() => onGameTap(game)}
                  className="flex items-center gap-3 text-left"
                >
                  <div className={`w-8 h-8 rounded-lg bg-gradient-to-br ${game.gradient} flex-shrink-0`} />
                  <div className="flex-1 min-w-0">
                    <p className="text-white/75 text-xs font-medium truncate">{game.title}</p>
                    <p className="text-white/25 text-[10px]">{game.genre[0]}</p>
                  </div>
                  <ChevronRight size={13} className="text-white/15 flex-shrink-0" />
                </button>
              ))}
            </div>
          </div>
        </div>
      ) : (
        <div className="flex flex-col items-center gap-2 py-12 px-4 text-center">
          <Search size={32} className="text-white/10" />
          <p className="text-white/30 text-sm">Sin resultados para "{query}"</p>
        </div>
      )}
    </div>
  );
}

// ─── Profile ──────────────────────────────────────────────────────────────────
function ProfileScreen() {
  const [tab, setTab] = useState<"genres" | "achievements">("genres");
  const hof = [GAMES[4], GAMES[5], GAMES[1], GAMES[3], GAMES[0]];
  const beaten = GAMES.filter((g) => g.status === "beaten").length;
  const totalHours = GAMES.reduce((s, g) => s + g.hours, 0);

  return (
    <div className="flex flex-col h-full overflow-y-auto scrollbar-hide">
      {/* Banner */}
      <div className="relative h-28 bg-gradient-to-br from-violet-950 via-purple-900 to-fuchsia-950 flex-shrink-0 overflow-hidden">
        <div
          className="absolute inset-0 opacity-40"
          style={{
            backgroundImage:
              "radial-gradient(circle at 15% 60%, #7c3aed 0%, transparent 55%), radial-gradient(circle at 85% 20%, #ec4899 0%, transparent 50%)",
          }}
        />
        <button className="absolute top-3 right-3 w-7 h-7 rounded-full bg-black/30 backdrop-blur-sm flex items-center justify-center">
          <Settings size={13} className="text-white/70" />
        </button>
      </div>

      {/* Avatar + info */}
      <div className="px-4 -mt-8 mb-4 relative z-10">
        <div className="w-16 h-16 rounded-2xl bg-gradient-to-br from-violet-500 to-fuchsia-600 border-[3px] border-background flex items-center justify-center">
          <span className="text-white text-xl font-bold font-display">R</span>
        </div>
      </div>

      <div className="px-4 mb-4">
        <div className="flex items-start justify-between">
          <div>
            <h1 className="text-white text-lg font-bold font-display leading-tight">Rafael C.</h1>
            <p className="text-white/30 text-xs">@rafaelcs · miembro desde ene. 2024</p>
          </div>
          <div className="flex items-center gap-1 bg-violet-500/15 border border-violet-500/20 rounded-xl px-2.5 py-1.5">
            <Zap size={11} className="text-violet-400" />
            <span className="text-violet-300 text-xs font-bold font-display">Niv. 24</span>
          </div>
        </div>
        <div className="mt-2.5">
          <div className="flex justify-between mb-1">
            <span className="text-white/25 text-[10px]">847 / 1000 XP</span>
            <span className="text-white/25 text-[10px]">→ Niv. 25</span>
          </div>
          <XPBar xp={847} />
        </div>
      </div>

      {/* Stats */}
      <div className="px-4 mb-5">
        <div className="grid grid-cols-3 gap-2.5">
          {[
            { label: "Juegos", value: GAMES.length, Icon: BookOpen },
            { label: "Completados", value: beaten, Icon: Trophy },
            { label: "Horas", value: `${totalHours}h`, Icon: Clock },
          ].map(({ label, value, Icon }) => (
            <div key={label} className="bg-white/[0.03] border border-white/[0.05] rounded-2xl p-3 text-center">
              <Icon size={13} className="text-violet-400 mx-auto mb-1.5" />
              <p className="text-white font-bold text-base font-display leading-none">{value}</p>
              <p className="text-white/25 text-[10px] mt-1">{label}</p>
            </div>
          ))}
        </div>
      </div>

      {/* Hall of Fame */}
      <div className="px-4 mb-5">
        <div className="flex items-center justify-between mb-2.5">
          <h2 className="text-white text-sm font-semibold font-display flex items-center gap-1.5">
            <Flame size={13} className="text-amber-400" /> Hall of Fame
          </h2>
          <button className="text-violet-400 text-xs">Editar</button>
        </div>
        <div className="flex gap-2">
          {hof.map((game, i) => (
            <div key={i} className="flex-1 flex flex-col gap-1">
              <div
                className={`w-full rounded-xl overflow-hidden bg-gradient-to-br ${game.gradient} flex flex-col`}
                style={{ aspectRatio: "2/3" }}
              >
                <div className="flex-1 flex items-center justify-center">
                  <span className="text-white/15 font-bold font-display text-sm">
                    {game.title.split(" ").map((w) => w[0]).join("").slice(0, 2)}
                  </span>
                </div>
                <div className="px-1 pb-1 bg-gradient-to-t from-black/60 to-transparent pt-3">
                  <p className="text-white text-[8px] font-semibold leading-tight line-clamp-2">{game.title}</p>
                </div>
              </div>
              <div className="flex justify-center gap-px">
                {Array.from({ length: 5 }).map((_, j) => (
                  <Star
                    key={j}
                    size={6}
                    className={j < Math.round(game.rating / 2) ? "fill-amber-400 text-amber-400" : "text-white/10"}
                  />
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Tab switcher */}
      <div className="px-4 mb-3">
        <div className="flex bg-white/5 rounded-xl p-1">
          {(["genres", "achievements"] as const).map((t) => (
            <button
              key={t}
              onClick={() => setTab(t)}
              className={`flex-1 py-1.5 rounded-lg text-xs font-semibold transition-all ${
                tab === t ? "bg-white/10 text-white" : "text-white/30"
              }`}
            >
              {t === "genres" ? "Mapa de géneros" : "Logros"}
            </button>
          ))}
        </div>
      </div>

      {/* Tab content */}
      <div className="px-4 pb-6">
        {tab === "genres" ? (
          <ResponsiveContainer width="100%" height={160}>
            <BarChart data={GENRE_DATA} margin={{ top: 4, right: 0, left: -22, bottom: 0 }}>
              <XAxis
                dataKey="genre"
                tick={{ fill: "rgba(255,255,255,0.25)", fontSize: 9 }}
                axisLine={false}
                tickLine={false}
              />
              <YAxis
                tick={{ fill: "rgba(255,255,255,0.25)", fontSize: 9 }}
                axisLine={false}
                tickLine={false}
              />
              <Bar dataKey="count" radius={[4, 4, 0, 0]}>
                {GENRE_DATA.map((entry, index) => (
                  <Cell key={index} fill={entry.color} fillOpacity={0.85} />
                ))}
              </Bar>
            </BarChart>
          </ResponsiveContainer>
        ) : (
          <div className="grid grid-cols-3 gap-2">
            {ACHIEVEMENTS.map((ach) => (
              <div
                key={ach.id}
                className={`rounded-2xl p-3 flex flex-col items-center gap-1.5 text-center border transition-all ${
                  ach.unlocked
                    ? "bg-violet-500/10 border-violet-500/20"
                    : "bg-white/[0.02] border-white/[0.04] opacity-35"
                }`}
              >
                <span className="text-xl leading-none">{ach.icon}</span>
                <p className="text-white text-[10px] font-semibold leading-tight">{ach.title}</p>
                <p className="text-white/30 text-[9px] leading-tight">{ach.desc}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Game detail ──────────────────────────────────────────────────────────────
function GameDetail({ game, onBack }: { game: Game; onBack: () => void }) {
  const [tab, setTab] = useState<"opinion" | "grupo" | "comunidad">("opinion");

  const groupMembers = [
    { name: "Marco V.", avatar: "MV", status: "beaten" as GameStatus },
    { name: "Sara K.", avatar: "SK", status: "playing" as GameStatus },
  ];

  const reviews = [
    { user: "nekromos", platform: "Stash", rating: 9, text: "Una obra maestra del género. Brutalmente satisfactorio." },
    { user: "astral_gamer", platform: "Stash", rating: 8.5, text: "Extraordinaria ambientación, aunque algo lento al principio." },
    { user: "voidwalker99", platform: "Steam", rating: 10, text: "Perfecto en todos los aspectos. Imposible parar." },
  ];

  return (
    <div className="flex flex-col h-full overflow-y-auto scrollbar-hide">
      {/* Cover header */}
      <div className={`relative flex-shrink-0 bg-gradient-to-b ${game.gradient}`} style={{ height: "200px" }}>
        <div className="absolute inset-0 bg-gradient-to-b from-black/10 via-transparent to-background" />
        <button
          onClick={onBack}
          className="absolute top-4 left-4 w-8 h-8 rounded-full bg-black/40 backdrop-blur-sm flex items-center justify-center z-10"
        >
          <ArrowLeft size={16} className="text-white" />
        </button>
        <div className="absolute bottom-0 left-0 right-0 px-4 pb-3">
          <div className="flex items-end gap-3">
            <div
              className={`rounded-xl bg-gradient-to-br ${game.gradient} border border-white/10 shadow-xl flex-shrink-0`}
              style={{ width: "60px", height: "80px" }}
            />
            <div className="flex-1 min-w-0 pb-0.5">
              <h1 className="text-white text-[15px] font-bold font-display leading-tight">{game.title}</h1>
              <p className="text-white/40 text-xs">{game.year} · {game.genre.slice(0, 2).join(" / ")}</p>
              <div className="flex items-center gap-2 mt-1.5">
                <StatusBadge status={game.status} />
                {game.hltb > 0 && (
                  <span className="text-white/30 text-[10px] flex items-center gap-0.5">
                    <Clock size={9} /> ~{game.hltb}h HLTB
                  </span>
                )}
              </div>
            </div>
          </div>
        </div>
      </div>

      {/* Who has it */}
      <div className="px-4 py-2.5 flex items-center gap-2 border-b border-white/[0.04]">
        <Users size={11} className="text-white/25 flex-shrink-0" />
        <span className="text-white/25 text-[11px]">En el grupo:</span>
        <div className="flex items-center gap-2">
          {groupMembers.map((m, i) => (
            <div key={i} className="flex items-center gap-1">
              <FriendAvatar initials={m.avatar} />
              <StatusBadge status={m.status} />
            </div>
          ))}
        </div>
      </div>

      {/* Tabs */}
      <div className="px-4 py-2 flex gap-1 border-b border-white/[0.04]">
        {[
          { key: "opinion" as const, label: "Mi Opinión" },
          { key: "grupo" as const, label: "Grupo" },
          { key: "comunidad" as const, label: "Comunidad" },
        ].map((t) => (
          <button
            key={t.key}
            onClick={() => setTab(t.key)}
            className={`px-3 py-1.5 rounded-xl text-xs font-semibold transition-all ${
              tab === t.key ? "bg-violet-600 text-white" : "text-white/35 hover:text-white/55"
            }`}
          >
            {t.label}
          </button>
        ))}
      </div>

      {/* Tab content */}
      <div className="flex-1 px-4 pt-4 pb-8">
        {tab === "opinion" &&
          (game.rating > 0 ? (
            <div className="flex flex-col gap-4">
              <div className="flex items-center gap-4">
                <span className="text-white font-bold font-display" style={{ fontSize: "42px", lineHeight: 1 }}>
                  {game.rating}
                </span>
                <div>
                  <StarRow value={game.rating} />
                  <span className="text-white/30 text-[10px] mt-1 block">puntuación global</span>
                </div>
              </div>

              <div className="flex flex-col gap-2.5">
                {[
                  { label: "Gameplay", value: game.ratingGameplay },
                  { label: "Banda Sonora", value: game.ratingOST },
                ].map((cat) => (
                  <div key={cat.label} className="flex items-center gap-3">
                    <span className="text-white/35 text-xs w-24 flex-shrink-0">{cat.label}</span>
                    <div className="flex-1 h-1 bg-white/8 rounded-full overflow-hidden">
                      <div
                        className="h-full bg-gradient-to-r from-violet-500 to-fuchsia-500 rounded-full"
                        style={{ width: `${cat.value * 10}%` }}
                      />
                    </div>
                    <span className="text-white/40 text-xs w-4 text-right">{cat.value}</span>
                  </div>
                ))}
              </div>

              {game.comment && (
                <div className="bg-white/[0.03] border border-white/[0.05] rounded-2xl p-3">
                  <p className="text-white/55 text-xs leading-relaxed">"{game.comment}"</p>
                </div>
              )}

              <div className="flex items-center gap-4 pt-1 border-t border-white/5">
                <div className="flex items-center gap-1.5 text-white/30">
                  <Clock size={11} />
                  <span className="text-xs">{game.hours}h propias</span>
                </div>
                {game.playCount > 1 && (
                  <div className="flex items-center gap-1.5 text-white/30">
                    <Play size={11} />
                    <span className="text-xs">{game.playCount} partidas</span>
                  </div>
                )}
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center gap-3 py-10 text-center">
              <div className="w-14 h-14 rounded-full bg-white/4 flex items-center justify-center">
                <Star size={22} className="text-white/15" />
              </div>
              <p className="text-white/30 text-sm">Aún no has reseñado este juego</p>
              <button className="bg-violet-600 hover:bg-violet-500 transition-colors text-white text-sm font-semibold px-6 py-2.5 rounded-2xl">
                Escribir reseña
              </button>
            </div>
          ))}

        {tab === "grupo" && (
          <div className="flex flex-col gap-2.5">
            {groupMembers.map((m, i) => (
              <div key={i} className="bg-white/[0.03] border border-white/[0.05] rounded-2xl p-3 flex items-center gap-3">
                <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-violet-500 to-fuchsia-600 flex items-center justify-center flex-shrink-0">
                  <span className="text-white text-xs font-bold">{m.avatar}</span>
                </div>
                <div className="flex-1">
                  <p className="text-white text-sm font-semibold">{m.name}</p>
                  <div className="mt-0.5">
                    <StatusBadge status={m.status} />
                  </div>
                </div>
              </div>
            ))}
          </div>
        )}

        {tab === "comunidad" && (
          <div className="flex flex-col gap-2.5">
            {reviews.map((rev, i) => (
              <div key={i} className="bg-white/[0.03] border border-white/[0.05] rounded-2xl p-3">
                <div className="flex items-center justify-between mb-2">
                  <div className="flex items-center gap-2">
                    <div className="w-6 h-6 rounded-full bg-white/8 flex items-center justify-center">
                      <span className="text-white/50 text-[9px] font-bold">{rev.user[0].toUpperCase()}</span>
                    </div>
                    <span className="text-white/65 text-xs font-semibold">{rev.user}</span>
                    <span className="text-white/20 text-[9px] bg-white/4 rounded-full px-1.5 py-0.5">{rev.platform}</span>
                  </div>
                  <span className="text-amber-400 text-xs font-bold">{rev.rating}</span>
                </div>
                <p className="text-white/45 text-xs leading-relaxed">{rev.text}</p>
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}

// ─── Bottom nav ───────────────────────────────────────────────────────────────
function BottomNav({
  active,
  onSelect,
}: {
  active: TabScreen;
  onSelect: (s: TabScreen) => void;
}) {
  const tabs: Array<{ key: TabScreen; Icon: typeof Home; label: string }> = [
    { key: "dashboard", Icon: Home, label: "Inicio" },
    { key: "library", Icon: BookOpen, label: "Biblioteca" },
    { key: "search", Icon: Search, label: "Buscar" },
    { key: "profile", Icon: User, label: "Perfil" },
  ];

  return (
    <div className="flex-shrink-0 bg-background/90 backdrop-blur-xl border-t border-white/[0.05] px-2">
      <div className="flex">
        {tabs.map(({ key, Icon, label }) => (
          <button
            key={key}
            onClick={() => onSelect(key)}
            className="flex-1 flex flex-col items-center gap-0.5 py-2.5 transition-all"
          >
            <Icon
              size={20}
              className={active === key ? "text-violet-400" : "text-white/25"}
              strokeWidth={active === key ? 2.5 : 1.5}
            />
            <span
              className={`text-[10px] font-semibold ${
                active === key ? "text-violet-400" : "text-white/20"
              }`}
            >
              {label}
            </span>
          </button>
        ))}
      </div>
    </div>
  );
}

// ─── Root ─────────────────────────────────────────────────────────────────────
export default function App() {
  const [tab, setTab] = useState<TabScreen>("dashboard");
  const [selectedGame, setSelectedGame] = useState<Game | null>(null);

  const handleGameTap = (game: Game) => setSelectedGame(game);
  const handleBack = () => setSelectedGame(null);

  return (
    <div className="min-h-screen bg-zinc-950 flex items-center justify-center p-4">
      {/* Phone shell */}
      <div
        className="relative bg-background overflow-hidden flex flex-col"
        style={{
          width: "390px",
          height: "844px",
          borderRadius: "44px",
          boxShadow:
            "0 0 0 10px #111118, 0 60px 100px rgba(0,0,0,0.9), 0 0 0 11px #0a0a10, inset 0 0 0 1px rgba(255,255,255,0.04)",
        }}
      >
        {/* Status bar */}
        <div className="flex-shrink-0 flex items-center justify-between px-8 h-11 mt-1">
          <span className="text-white text-xs font-semibold font-display">9:41</span>
          <div className="w-[120px] h-7 bg-black rounded-full" />
          <div className="flex items-center gap-1.5">
            <div className="flex gap-px items-end">
              {[3, 4, 5, 6].map((h) => (
                <div key={h} className="w-[3px] bg-white/80 rounded-sm" style={{ height: `${h}px` }} />
              ))}
            </div>
            <div className="w-[22px] h-[12px] border border-white/50 rounded-sm relative ml-0.5">
              <div className="absolute inset-[2px] right-[5px] bg-white/80 rounded-[1px]" />
              <div className="absolute -right-[3px] top-1/2 -translate-y-1/2 w-[3px] h-[6px] bg-white/50 rounded-r-sm" />
            </div>
          </div>
        </div>

        {/* Content area */}
        <div className="flex-1 relative overflow-hidden">
          {selectedGame ? (
            <GameDetail game={selectedGame} onBack={handleBack} />
          ) : (
            <>
              {tab === "dashboard" && <DashboardScreen onGameTap={handleGameTap} />}
              {tab === "library" && <LibraryScreen onGameTap={handleGameTap} />}
              {tab === "search" && <SearchScreen onGameTap={handleGameTap} />}
              {tab === "profile" && <ProfileScreen />}
            </>
          )}
        </div>

        {/* Bottom nav */}
        {!selectedGame && <BottomNav active={tab} onSelect={setTab} />}

        {/* Home indicator */}
        <div className="flex-shrink-0 flex items-center justify-center h-6">
          <div className="w-32 h-1 bg-white/25 rounded-full" />
        </div>
      </div>
    </div>
  );
}
