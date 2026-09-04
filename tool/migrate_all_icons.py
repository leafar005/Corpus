#!/usr/bin/env python3
"""Generate CorpusIconKind + builders and migrate Icons.* across lib/."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"
WIDGETS = LIB / "widgets"

SKIP_FILES = {
    "profile_stat_icon.dart",
}

# Material icon suffix -> Tabler widget expression (inside buildTablerSvg switch)
# o = outline stroke, f = filled
TABLER_MAP: dict[str, str] = {
    "access_time": "tabler.ClockFilled(w: s, h: s)",
    "add": "tabler.Plus(w: s, h: s, strokeWidth: sw)",
    "add_circle_outline": "tabler.CirclePlus(w: s, h: s, strokeWidth: sw)",
    "add_photo_alternate": "tabler.PhotoPlus(w: s, h: s, strokeWidth: sw)",
    "all_inclusive": "tabler.Infinity(w: s, h: s, strokeWidth: sw)",
    "all_inclusive_rounded": "tabler.Infinity(w: s, h: s, strokeWidth: sw)",
    "alternate_email": "tabler.At(w: s, h: s, strokeWidth: sw)",
    "arrow_back": "tabler.ArrowLeft(w: s, h: s, strokeWidth: sw)",
    "arrow_downward": "tabler.ArrowDown(w: s, h: s, strokeWidth: sw)",
    "arrow_drop_down": "tabler.ChevronDown(w: s, h: s, strokeWidth: sw)",
    "arrow_forward": "tabler.ArrowRight(w: s, h: s, strokeWidth: sw)",
    "arrow_forward_rounded": "tabler.ArrowRight(w: s, h: s, strokeWidth: sw)",
    "arrow_upward": "tabler.ArrowUp(w: s, h: s, strokeWidth: sw)",
    "article_outlined": "tabler.Article(w: s, h: s, strokeWidth: sw)",
    "auto_awesome": "tabler.Sparkles(w: s, h: s, strokeWidth: sw)",
    "auto_stories": "tabler.Book(w: s, h: s, strokeWidth: sw)",
    "auto_stories_rounded": "tabler.Book(w: s, h: s, strokeWidth: sw)",
    "biotech": "tabler.Vaccine(w: s, h: s, strokeWidth: sw)",
    "block": "tabler.Ban(w: s, h: s, strokeWidth: sw)",
    "bookmark": "tabler.BookmarkFilled(w: s, h: s)",
    "bookmark_add_outlined": "tabler.BookmarkPlus(w: s, h: s, strokeWidth: sw)",
    "brightness_auto": "tabler.BrightnessAuto(w: s, h: s, strokeWidth: sw)",
    "brush": "tabler.Brush(w: s, h: s, strokeWidth: sw)",
    "business": "tabler.BuildingSkyscraper(w: s, h: s, strokeWidth: sw)",
    "calendar_today": "tabler.Calendar(w: s, h: s, strokeWidth: sw)",
    "camera_alt": "tabler.CameraFilled(w: s, h: s)",
    "cancel": "tabler.X(w: s, h: s, strokeWidth: sw)",
    "cancel_outlined": "tabler.CircleXFilled(w: s, h: s)",
    "cancel_rounded": "tabler.CircleXFilled(w: s, h: s)",
    "cancel_schedule_send_rounded": "tabler.CalendarX(w: s, h: s, strokeWidth: sw)",
    "catching_pokemon": "tabler.Pokeball(w: s, h: s, strokeWidth: sw)",
    "category": "tabler.Category(w: s, h: s, strokeWidth: sw)",
    "category_outlined": "tabler.Category(w: s, h: s, strokeWidth: sw)",
    "chat": "tabler.MessageFilled(w: s, h: s)",
    "chat_bubble_outline": "tabler.Message(w: s, h: s, strokeWidth: sw)",
    "chat_bubble_rounded": "tabler.MessageFilled(w: s, h: s)",
    "check": "tabler.Check(w: s, h: s, strokeWidth: sw)",
    "check_circle": "tabler.CircleCheckFilled(w: s, h: s)",
    "check_circle_rounded": "tabler.CircleCheckFilled(w: s, h: s)",
    "check_rounded": "tabler.Check(w: s, h: s, strokeWidth: sw)",
    "chevron_left": "tabler.ChevronLeft(w: s, h: s, strokeWidth: sw)",
    "chevron_right": "tabler.ChevronRight(w: s, h: s, strokeWidth: sw)",
    "clear": "tabler.X(w: s, h: s, strokeWidth: sw)",
    "close": "tabler.X(w: s, h: s, strokeWidth: sw)",
    "close_rounded": "tabler.X(w: s, h: s, strokeWidth: sw)",
    "cloud_download": "tabler.CloudDownload(w: s, h: s, strokeWidth: sw)",
    "cloud_rounded": "tabler.Cloud(w: s, h: s, strokeWidth: sw)",
    "cloud_upload": "tabler.CloudUpload(w: s, h: s, strokeWidth: sw)",
    "collections_bookmark_outlined": "tabler.Bookmarks(w: s, h: s, strokeWidth: sw)",
    "colorize": "tabler.ColorPicker(w: s, h: s, strokeWidth: sw)",
    "comment_outlined": "tabler.Message(w: s, h: s, strokeWidth: sw)",
    "computer": "tabler.DeviceDesktop(w: s, h: s, strokeWidth: sw)",
    "dark_mode": "tabler.MoonFilled(w: s, h: s)",
    "dashboard_customize_outlined": "tabler.LayoutDashboard(w: s, h: s, strokeWidth: sw)",
    "delete": "tabler.TrashXFilled(w: s, h: s)",
    "delete_outline": "tabler.Trash(w: s, h: s, strokeWidth: sw)",
    "description_outlined": "tabler.FileDescription(w: s, h: s, strokeWidth: sw)",
    "device_unknown": "tabler.DeviceUnknown(w: s, h: s, strokeWidth: sw)",
    "devices": "tabler.Devices(w: s, h: s, strokeWidth: sw)",
    "do_not_disturb_alt": "tabler.BellOff(w: s, h: s, strokeWidth: sw)",
    "done": "tabler.Check(w: s, h: s, strokeWidth: sw)",
    "drag_handle": "tabler.GripVertical(w: s, h: s, strokeWidth: sw)",
    "edit": "tabler.Edit(w: s, h: s, strokeWidth: sw)",
    "edit_calendar": "tabler.CalendarEdit(w: s, h: s, strokeWidth: sw)",
    "edit_outlined": "tabler.Edit(w: s, h: s, strokeWidth: sw)",
    "email": "tabler.Mail(w: s, h: s, strokeWidth: sw)",
    "email_outlined": "tabler.Mail(w: s, h: s, strokeWidth: sw)",
    "email_rounded": "tabler.Mail(w: s, h: s, strokeWidth: sw)",
    "emoji_events": "tabler.TrophyFilled(w: s, h: s)",
    "emoji_events_outlined": "tabler.Trophy(w: s, h: s, strokeWidth: sw)",
    "emoji_events_rounded": "tabler.TrophyFilled(w: s, h: s)",
    "error": "tabler.CircleXFilled(w: s, h: s)",
    "error_outline": "tabler.AlertCircle(w: s, h: s, strokeWidth: sw)",
    "event_available_outlined": "tabler.CalendarCheck(w: s, h: s, strokeWidth: sw)",
    "expand_more": "tabler.ChevronDown(w: s, h: s, strokeWidth: sw)",
    "explore": "tabler.CompassFilled(w: s, h: s)",
    "extension": "tabler.PuzzleFilled(w: s, h: s)",
    "extension_outlined": "tabler.Puzzle(w: s, h: s, strokeWidth: sw)",
    "extension_rounded": "tabler.PuzzleFilled(w: s, h: s)",
    "facebook": "tabler.BrandFacebook(w: s, h: s, strokeWidth: sw)",
    "favorite": "tabler.HeartFilled(w: s, h: s)",
    "favorite_border": "tabler.Heart(w: s, h: s, strokeWidth: sw)",
    "file_download_outlined": "tabler.Download(w: s, h: s, strokeWidth: sw)",
    "file_upload_outlined": "tabler.Upload(w: s, h: s, strokeWidth: sw)",
    "fireplace": "tabler.Flame(w: s, h: s, strokeWidth: sw)",
    "flag": "tabler.FlagFilled(w: s, h: s)",
    "flag_rounded": "tabler.FlagFilled(w: s, h: s)",
    "flutter_dash": "tabler.BrandFlutter(w: s, h: s, strokeWidth: sw)",
    "forum": "tabler.Messages(w: s, h: s, strokeWidth: sw)",
    "gamepad": "tabler.DeviceGamepadFilled(w: s, h: s)",
    "group_rounded": "tabler.Users(w: s, h: s, strokeWidth: sw)",
    "groups_outlined": "tabler.UsersGroup(w: s, h: s, strokeWidth: sw)",
    "help_outline": "tabler.HelpCircle(w: s, h: s, strokeWidth: sw)",
    "hourglass_empty": "tabler.Hourglass(w: s, h: s, strokeWidth: sw)",
    "inbox_outlined": "tabler.Inbox(w: s, h: s, strokeWidth: sw)",
    "inbox_rounded": "tabler.Inbox(w: s, h: s, strokeWidth: sw)",
    "info": "tabler.InfoCircleFilled(w: s, h: s)",
    "info_outline": "tabler.InfoCircle(w: s, h: s, strokeWidth: sw)",
    "inventory_2_outlined": "tabler.Package(w: s, h: s, strokeWidth: sw)",
    "keyboard_arrow_down_rounded": "tabler.ChevronDown(w: s, h: s, strokeWidth: sw)",
    "language": "tabler.Language(w: s, h: s, strokeWidth: sw)",
    "library_add_check_outlined": "tabler.LibraryPlus(w: s, h: s, strokeWidth: sw)",
    "light_mode": "tabler.SunFilled(w: s, h: s)",
    "lightbulb_outline": "tabler.Bulb(w: s, h: s, strokeWidth: sw)",
    "link": "tabler.Link(w: s, h: s, strokeWidth: sw)",
    "live_tv": "tabler.DeviceTv(w: s, h: s, strokeWidth: sw)",
    "local_fire_department": "tabler.FlameFilled(w: s, h: s)",
    "local_offer": "tabler.TagFilled(w: s, h: s)",
    "local_offer_outlined": "tabler.Tag(w: s, h: s, strokeWidth: sw)",
    "local_police": "tabler.Shield(w: s, h: s, strokeWidth: sw)",
    "lock": "tabler.LockFilled(w: s, h: s)",
    "lock_outline": "tabler.Lock(w: s, h: s, strokeWidth: sw)",
    "lock_outline_rounded": "tabler.Lock(w: s, h: s, strokeWidth: sw)",
    "lock_reset_rounded": "tabler.LockAccess(w: s, h: s, strokeWidth: sw)",
    "lock_rounded": "tabler.LockFilled(w: s, h: s)",
    "login": "tabler.Login(w: s, h: s, strokeWidth: sw)",
    "logout": "tabler.Logout(w: s, h: s, strokeWidth: sw)",
    "mark_email_read_rounded": "tabler.MailOpened(w: s, h: s, strokeWidth: sw)",
    "memory": "tabler.Cpu(w: s, h: s, strokeWidth: sw)",
    "menu_book": "tabler.Book(w: s, h: s, strokeWidth: sw)",
    "more_vert": "tabler.DotsVertical(w: s, h: s, strokeWidth: sw)",
    "music_note": "tabler.Music(w: s, h: s, strokeWidth: sw)",
    "notifications_active_outlined": "tabler.BellRinging(w: s, h: s, strokeWidth: sw)",
    "notifications_none_rounded": "tabler.Bell(w: s, h: s, strokeWidth: sw)",
    "notifications_outlined": "tabler.Bell(w: s, h: s, strokeWidth: sw)",
    "notifications_rounded": "tabler.BellFilled(w: s, h: s)",
    "open_in_new": "tabler.ExternalLink(w: s, h: s, strokeWidth: sw)",
    "palette_outlined": "tabler.PaletteFilled(w: s, h: s)",
    "pause": "tabler.PlayerPauseFilled(w: s, h: s)",
    "pause_circle": "tabler.PlayerPause(w: s, h: s, strokeWidth: sw)",
    "pause_circle_outline": "tabler.PlayerPause(w: s, h: s, strokeWidth: sw)",
    "pause_rounded": "tabler.PlayerPauseFilled(w: s, h: s)",
    "people": "tabler.Users(w: s, h: s, strokeWidth: sw)",
    "people_alt_rounded": "tabler.Users(w: s, h: s, strokeWidth: sw)",
    "people_rounded": "tabler.Users(w: s, h: s, strokeWidth: sw)",
    "person": "tabler.User(w: s, h: s, strokeWidth: sw)",
    "person_add": "tabler.UserPlus(w: s, h: s, strokeWidth: sw)",
    "person_add_alt_1_rounded": "tabler.UserPlus(w: s, h: s, strokeWidth: sw)",
    "person_remove_outlined": "tabler.UserMinus(w: s, h: s, strokeWidth: sw)",
    "person_remove_rounded": "tabler.UserMinus(w: s, h: s, strokeWidth: sw)",
    "pets": "tabler.Paw(w: s, h: s, strokeWidth: sw)",
    "phone_android": "tabler.DeviceMobile(w: s, h: s, strokeWidth: sw)",
    "phone_iphone": "tabler.DeviceMobile(w: s, h: s, strokeWidth: sw)",
    "pie_chart": "tabler.ChartPie(w: s, h: s, strokeWidth: sw)",
    "play_arrow_rounded": "tabler.PlayerPlayFilled(w: s, h: s)",
    "play_circle_fill": "tabler.PlayerPlayFilled(w: s, h: s)",
    "plumbing": "tabler.Tool(w: s, h: s, strokeWidth: sw)",
    "psychology": "tabler.Brain(w: s, h: s, strokeWidth: sw)",
    "public_outlined": "tabler.World(w: s, h: s, strokeWidth: sw)",
    "rate_review": "tabler.MessageCircle(w: s, h: s, strokeWidth: sw)",
    "rate_review_outlined": "tabler.MessageCircle(w: s, h: s, strokeWidth: sw)",
    "rate_review_rounded": "tabler.MessageCircle(w: s, h: s, strokeWidth: sw)",
    "redeem_outlined": "tabler.Gift(w: s, h: s, strokeWidth: sw)",
    "refresh": "tabler.Refresh(w: s, h: s, strokeWidth: sw)",
    "remove_circle_outline": "tabler.CircleMinus(w: s, h: s, strokeWidth: sw)",
    "replay": "tabler.Repeat(w: s, h: s, strokeWidth: sw)",
    "reply": "tabler.ArrowBackUp(w: s, h: s, strokeWidth: sw)",
    "reply_outlined": "tabler.ArrowBackUp(w: s, h: s, strokeWidth: sw)",
    "reply_rounded": "tabler.ArrowBackUp(w: s, h: s, strokeWidth: sw)",
    "restart_alt": "tabler.Refresh(w: s, h: s, strokeWidth: sw)",
    "reviews_outlined": "tabler.MessageCircle(w: s, h: s, strokeWidth: sw)",
    "rocket_launch": "tabler.Rocket(w: s, h: s, strokeWidth: sw)",
    "schedule": "tabler.Clock(w: s, h: s, strokeWidth: sw)",
    "science": "tabler.Flask(w: s, h: s, strokeWidth: sw)",
    "screenshot_monitor": "tabler.Screenshot(w: s, h: s, strokeWidth: sw)",
    "search": "tabler.SearchFilled(w: s, h: s)",
    "sell_outlined": "tabler.Tag(w: s, h: s, strokeWidth: sw)",
    "send": "tabler.Send(w: s, h: s, strokeWidth: sw)",
    "settings": "tabler.SettingsFilled(w: s, h: s)",
    "settings_outlined": "tabler.Settings(w: s, h: s, strokeWidth: sw)",
    "share": "tabler.Share(w: s, h: s, strokeWidth: sw)",
    "shelves": "tabler.LayoutGrid(w: s, h: s, strokeWidth: sw)",
    "shield": "tabler.ShieldFilled(w: s, h: s)",
    "smartphone": "tabler.DeviceMobile(w: s, h: s, strokeWidth: sw)",
    "speed": "tabler.Gauge(w: s, h: s, strokeWidth: sw)",
    "sports_esports": "tabler.DeviceGamepadFilled(w: s, h: s)",
    "sports_esports_outlined": "tabler.DeviceGamepad(w: s, h: s, strokeWidth: sw)",
    "star": "tabler.StarFilled(w: s, h: s)",
    "star_rounded": "tabler.StarFilled(w: s, h: s)",
    "stars": "tabler.Stars(w: s, h: s, strokeWidth: sw)",
    "storage": "tabler.Database(w: s, h: s, strokeWidth: sw)",
    "store": "tabler.BuildingStore(w: s, h: s, strokeWidth: sw)",
    "store_rounded": "tabler.BuildingStore(w: s, h: s, strokeWidth: sw)",
    "storefront": "tabler.BuildingStore(w: s, h: s, strokeWidth: sw)",
    "storefront_rounded": "tabler.BuildingStore(w: s, h: s, strokeWidth: sw)",
    "tablet_mac": "tabler.DeviceTablet(w: s, h: s, strokeWidth: sw)",
    "thumb_up": "tabler.ThumbUpFilled(w: s, h: s)",
    "thumb_up_alt_outlined": "tabler.ThumbUp(w: s, h: s, strokeWidth: sw)",
    "thumb_up_alt_rounded": "tabler.ThumbUpFilled(w: s, h: s)",
    "timer_off": "tabler.ClockOff(w: s, h: s, strokeWidth: sw)",
    "timer_outlined": "tabler.Clock(w: s, h: s, strokeWidth: sw)",
    "tune": "tabler.AdjustmentsFilled(w: s, h: s)",
    "tv": "tabler.DeviceTv(w: s, h: s, strokeWidth: sw)",
    "video_library": "tabler.Video(w: s, h: s, strokeWidth: sw)",
    "videogame_asset": "tabler.DeviceGamepadFilled(w: s, h: s)",
    "videogame_asset_off": "tabler.DeviceGamepadOff(w: s, h: s, strokeWidth: sw)",
    "videogame_asset_outlined": "tabler.DeviceGamepad(w: s, h: s, strokeWidth: sw)",
    "view_carousel_outlined": "tabler.CarouselHorizontal(w: s, h: s, strokeWidth: sw)",
    "view_list_outlined": "tabler.List(w: s, h: s, strokeWidth: sw)",
    "visibility": "tabler.Eye(w: s, h: s, strokeWidth: sw)",
    "visibility_off": "tabler.EyeOff(w: s, h: s, strokeWidth: sw)",
    "visibility_off_rounded": "tabler.EyeOff(w: s, h: s, strokeWidth: sw)",
    "visibility_rounded": "tabler.Eye(w: s, h: s, strokeWidth: sw)",
    "warning_amber_outlined": "tabler.AlertTriangle(w: s, h: s, strokeWidth: sw)",
    "warning_amber_rounded": "tabler.AlertTriangle(w: s, h: s, strokeWidth: sw)",
    "workspace_premium": "tabler.Award(w: s, h: s, strokeWidth: sw)",
    # Nav-specific (already used via named constructors)
    "home": "tabler.HomeFilled(w: s, h: s)",
    "compass": "tabler.CompassFilled(w: s, h: s)",
    "users": "tabler.Users(w: s, h: s, strokeWidth: sw)",
    "tag": "tabler.TagFilled(w: s, h: s)",
    "user_filled": "tabler.UserFilled(w: s, h: s)",
    "palette": "tabler.PaletteFilled(w: s, h: s)",
    "bell": "tabler.BellFilled(w: s, h: s)",
    "plug": "tabler.PlugConnected(w: s, h: s, strokeWidth: sw)",
    "trash_x": "tabler.TrashXFilled(w: s, h: s)",
    "broom": "tabler.VacuumCleaner(w: s, h: s, strokeWidth: sw)",
}

DEFAULT_TABLER = "tabler.InfoCircle(w: s, h: s, strokeWidth: sw)"


def snake_to_pascal(snake: str) -> str:
    return "".join(part[:1].upper() + part[1:] for part in snake.split("_"))


def collect_icons() -> list[str]:
    icons: set[str] = set()
    for path in LIB.rglob("*.dart"):
        if path.name in SKIP_FILES:
            continue
        text = path.read_text(encoding="utf-8")
        for m in re.finditer(r"Icons\.(\w+)", text):
            icons.add(m.group(1))
    return sorted(icons)


def generate_kind_enum(icons: list[str]) -> str:
    lines = [
        "/// Semantic icon identifiers for Corpus Tabler SVG icons.",
        "/// Replaces Material [Icons] throughout the app.",
        "enum CorpusIconKind {",
    ]
    for icon in icons:
        lines.append(f"  {snake_to_pascal(icon)},")
    lines.append("}")
    return "\n".join(lines) + "\n"


def generate_builders(icons: list[str]) -> str:
    cases = []
    for icon in icons:
        pascal = snake_to_pascal(icon)
        tabler = TABLER_MAP.get(icon, DEFAULT_TABLER).replace("w: s, h: s", "width: s, height: s")
        cases.append(f"    CorpusIconKind.{pascal} => {tabler},")

    body = "\n".join(cases) if cases else "    _ => tabler.InfoCircle(width: s, height: s, strokeWidth: sw),"
    return f"""import 'package:flutter/widgets.dart';
import 'package:tabler_icons_next/tabler_icons_next.dart' as tabler;
import 'corpus_icon_kind.dart';

/// Raw Tabler SVG widgets (no tinting — [CorpusTablerIcon] applies color).
Widget buildTablerSvg(CorpusIconKind kind, double size) {{
  const sw = 1.75;
  final s = size;
  return switch (kind) {{
{body}
  }};
}}
"""


def generate_corpus_tabler_icon() -> str:
    return '''import 'package:flutter/material.dart';
import 'corpus_icon_kind.dart';
import 'corpus_tabler_icon_builders.dart';

/// Shared Tabler SVG icon widget with reliable tinting on web/dark mode.
class CorpusTablerIcon extends StatelessWidget {
  const CorpusTablerIcon(
    this.kind, {
    super.key,
    this.size,
    this.color,
  });

  final CorpusIconKind kind;
  final double? size;
  final Color? color;

  // ── Nav / settings shortcuts ──────────────────────────────────────────
  const CorpusTablerIcon.home({super.key, this.size, this.color})
      : kind = CorpusIconKind.home;

  const CorpusTablerIcon.compass({super.key, this.size, this.color})
      : kind = CorpusIconKind.compass;

  const CorpusTablerIcon.search({super.key, this.size, this.color})
      : kind = CorpusIconKind.search;

  const CorpusTablerIcon.users({super.key, this.size, this.color})
      : kind = CorpusIconKind.users;

  const CorpusTablerIcon.tag({super.key, this.size, this.color})
      : kind = CorpusIconKind.tag;

  const CorpusTablerIcon.user({super.key, this.size, this.color})
      : kind = CorpusIconKind.person;

  const CorpusTablerIcon.userFilled({super.key, this.size, this.color})
      : kind = CorpusIconKind.userFilled;

  const CorpusTablerIcon.userPlus({super.key, this.size, this.color})
      : kind = CorpusIconKind.personAdd;

  const CorpusTablerIcon.palette({super.key, this.size, this.color})
      : kind = CorpusIconKind.palette;

  const CorpusTablerIcon.bell({super.key, this.size, this.color})
      : kind = CorpusIconKind.bell;

  const CorpusTablerIcon.plug({super.key, this.size, this.color})
      : kind = CorpusIconKind.plug;

  const CorpusTablerIcon.info({super.key, this.size, this.color})
      : kind = CorpusIconKind.info;

  const CorpusTablerIcon.chevronRight({super.key, this.size, this.color})
      : kind = CorpusIconKind.chevronRight;

  const CorpusTablerIcon.language({super.key, this.size, this.color})
      : kind = CorpusIconKind.language;

  const CorpusTablerIcon.timer({super.key, this.size, this.color})
      : kind = CorpusIconKind.accessTime;

  const CorpusTablerIcon.trashX({super.key, this.size, this.color})
      : kind = CorpusIconKind.trashX;

  const CorpusTablerIcon.logout({super.key, this.size, this.color})
      : kind = CorpusIconKind.logout;

  const CorpusTablerIcon.broom({super.key, this.size, this.color})
      : kind = CorpusIconKind.broom;

  const CorpusTablerIcon.clear({super.key, this.size, this.color})
      : kind = CorpusIconKind.clear;

  const CorpusTablerIcon.tune({super.key, this.size, this.color})
      : kind = CorpusIconKind.tune;

  const CorpusTablerIcon.star({super.key, this.size, this.color})
      : kind = CorpusIconKind.star;

  const CorpusTablerIcon.thumbUp({super.key, this.size, this.color})
      : kind = CorpusIconKind.thumbUp;

  const CorpusTablerIcon.thumbUpOff({super.key, this.size, this.color})
      : kind = CorpusIconKind.thumbUpAltOutlined;

  const CorpusTablerIcon.message({super.key, this.size, this.color})
      : kind = CorpusIconKind.chatBubbleOutline;

  const CorpusTablerIcon.repeat({super.key, this.size, this.color})
      : kind = CorpusIconKind.replay;

  const CorpusTablerIcon.lock({super.key, this.size, this.color})
      : kind = CorpusIconKind.lock;

  const CorpusTablerIcon.login({super.key, this.size, this.color})
      : kind = CorpusIconKind.login;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final resolvedSize = size ?? theme.size ?? 24;
    final resolvedColor =
        color ?? theme.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return SizedBox(
      width: resolvedSize,
      height: resolvedSize,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
        child: buildTablerSvg(kind, resolvedSize),
      ),
    );
  }
}

/// Shorthand for [CorpusTablerIcon].
Widget corpusIcon(
  CorpusIconKind kind, {
  Key? key,
  double? size,
  Color? color,
}) =>
    CorpusTablerIcon(kind, key: key, size: size, color: color);
'''


def migrate_file(path: Path, icons: list[str]) -> bool:
    if path.name in SKIP_FILES:
        return False
    if path.name in {"corpus_tabler_icon.dart", "corpus_icon_kind.dart", "corpus_tabler_icon_builders.dart"}:
        return False

    text = path.read_text(encoding="utf-8")
    original = text

    # Skip Hall of Fame star in profile_screen
    hof_marker = "Icons.star,"
    hof_placeholder = "@@HOF_STAR@@"

    if path.name == "profile_screen.dart" and hof_marker in text:
        text = text.replace(hof_marker, hof_placeholder, 1)

    # Longest icon names first to avoid partial replacements
    for icon in sorted(icons, key=len, reverse=True):
        pascal = snake_to_pascal(icon)
        kind = f"CorpusIconKind.{pascal}"

        # Icon(Icons.foo, ...) -> CorpusTablerIcon(CorpusIconKind.Foo, ...)
        text = re.sub(
            rf"Icon\(\s*Icons\.{icon}\b",
            f"CorpusTablerIcon({kind}",
            text,
        )
        # Icons.foo as value -> CorpusIconKind.Foo
        text = re.sub(rf"\bIcons\.{icon}\b", kind, text)

    # IconData used for icons -> CorpusIconKind (targeted patterns)
    text = re.sub(r"\bIconData\b", "CorpusIconKind", text)

    # materialIcon field rename
    text = text.replace("materialIcon", "fallbackIcon")

    if path.name == "profile_screen.dart" and hof_placeholder in text:
        text = text.replace(hof_placeholder, hof_marker)

    if text == original:
        return False

    if "CorpusIconKind" in text or "CorpusTablerIcon" in text:
        if "corpus_tabler_icon.dart" not in text:
            # Add import after first import block
            if "import 'package:flutter/material.dart';" in text:
                text = text.replace(
                    "import 'package:flutter/material.dart';",
                    "import 'package:flutter/material.dart';\n"
                    "import 'package:corpus/widgets/corpus_tabler_icon.dart';\n"
                    "import 'package:corpus/widgets/corpus_icon_kind.dart';",
                    1,
                )
            elif "import 'package:flutter/material.dart' show" in text:
                pass  # handle manually if needed
            else:
                text = (
                    "import 'package:corpus/widgets/corpus_tabler_icon.dart';\n"
                    "import 'package:corpus/widgets/corpus_icon_kind.dart';\n"
                    + text
                )

    path.write_text(text, encoding="utf-8")
    return True


def main() -> int:
    icons = collect_icons()
    # Add nav-only kinds used by named constructors
    extra = ["home", "compass", "users", "tag", "user_filled", "palette", "bell", "plug", "trash_x", "broom"]
    all_icons = sorted(set(icons) | set(extra))

    # Ensure TABLER_MAP has all icons
    missing = [i for i in all_icons if i not in TABLER_MAP]
    if missing:
        print("WARNING: missing TABLER_MAP for:", ", ".join(missing))

    (WIDGETS / "corpus_icon_kind.dart").write_text(generate_kind_enum(all_icons), encoding="utf-8")
    (WIDGETS / "corpus_tabler_icon_builders.dart").write_text(generate_builders(all_icons), encoding="utf-8")
    (WIDGETS / "corpus_tabler_icon.dart").write_text(generate_corpus_tabler_icon(), encoding="utf-8")

    changed = 0
    for path in sorted(LIB.rglob("*.dart")):
        if migrate_file(path, all_icons):
            changed += 1
            print(f"migrated: {path.relative_to(ROOT)}")

    print(f"\nDone. {changed} files migrated, {len(all_icons)} icon kinds.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
