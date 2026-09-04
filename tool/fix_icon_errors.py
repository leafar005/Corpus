#!/usr/bin/env python3
"""Fix common post-migration icon compile errors."""

from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

# Fix named constructor enum references in corpus_tabler_icon.dart
NAMED_FIXES = {
    "CorpusIconKind.home": "CorpusIconKind.Home",
    "CorpusIconKind.compass": "CorpusIconKind.Compass",
    "CorpusIconKind.search": "CorpusIconKind.Search",
    "CorpusIconKind.users": "CorpusIconKind.Users",
    "CorpusIconKind.tag": "CorpusIconKind.Tag",
    "CorpusIconKind.person": "CorpusIconKind.Person",
    "CorpusIconKind.userFilled": "CorpusIconKind.UserFilled",
    "CorpusIconKind.personAdd": "CorpusIconKind.PersonAdd",
    "CorpusIconKind.palette": "CorpusIconKind.Palette",
    "CorpusIconKind.bell": "CorpusIconKind.Bell",
    "CorpusIconKind.plug": "CorpusIconKind.Plug",
    "CorpusIconKind.info": "CorpusIconKind.Info",
    "CorpusIconKind.chevronRight": "CorpusIconKind.ChevronRight",
    "CorpusIconKind.language": "CorpusIconKind.Language",
    "CorpusIconKind.accessTime": "CorpusIconKind.AccessTime",
    "CorpusIconKind.trashX": "CorpusIconKind.TrashX",
    "CorpusIconKind.logout": "CorpusIconKind.Logout",
    "CorpusIconKind.broom": "CorpusIconKind.Broom",
    "CorpusIconKind.clear": "CorpusIconKind.Clear",
    "CorpusIconKind.tune": "CorpusIconKind.Tune",
    "CorpusIconKind.star": "CorpusIconKind.Star",
    "CorpusIconKind.thumbUp": "CorpusIconKind.ThumbUp",
    "CorpusIconKind.thumbUpAltOutlined": "CorpusIconKind.ThumbUpAltOutlined",
    "CorpusIconKind.chatBubbleOutline": "CorpusIconKind.ChatBubbleOutline",
    "CorpusIconKind.replay": "CorpusIconKind.Replay",
    "CorpusIconKind.lock": "CorpusIconKind.Lock",
    "CorpusIconKind.login": "CorpusIconKind.Login",
}


def fix_content(text: str) -> str:
    for old, new in NAMED_FIXES.items():
        text = text.replace(old, new)

    # Icon(CorpusIconKind.X -> CorpusTablerIcon(CorpusIconKind.X
    text = re.sub(r"\bIcon\(\s*CorpusIconKind\.", "CorpusTablerIcon(CorpusIconKind.", text)

    # Icon(widget.icon -> CorpusTablerIcon(widget.icon
    text = re.sub(r"\bIcon\(\s*widget\.icon\b", "CorpusTablerIcon(widget.icon", text)

    # Icon(prefixIcon) / Icon(suffixIcon)
    text = re.sub(r"\bIcon\(\s*prefixIcon\s*\)", "CorpusTablerIcon(prefixIcon!)", text)
    text = re.sub(
        r"IconButton\(icon:\s*Icon\(suffixIcon\)",
        "IconButton(icon: CorpusTablerIcon(suffixIcon!)",
        text,
    )

    # Icon(icon, ...) when icon is CorpusIconKind variable — heuristic: lowercase first char
    text = re.sub(r"\bIcon\(\s*icon\s*,", "CorpusTablerIcon(icon,", text)
    text = re.sub(r"\bIcon\(\s*fallbackIcon\b", "CorpusTablerIcon(fallbackIcon", text)
    text = re.sub(r"\bIcon\(\s*materialIcon\b", "CorpusTablerIcon(materialIcon", text)
    text = re.sub(r"\bIcon\(\s*customIcon\b", "CorpusTablerIcon(customIcon", text)
    text = re.sub(r"\bIcon\(\s*actionIcon\b", "CorpusTablerIcon(actionIcon", text)

    # CorpusTablerIcon doesn't support Material Icon shadows
    text = re.sub(r",\s*shadows:\s*\[[^\]]*\]", "", text)

    # Guest prompt Icon(icon -> CorpusTablerIcon(icon!
    text = text.replace(
        "? CorpusTablerIcon(icon, size: 56, color: iconColor)",
        "? CorpusTablerIcon(icon!, size: 56, color: iconColor)",
    )

    # Remaining Icon(expr) except Material Icons.*
    text = re.sub(r"\bIcon\(\s*(?!Icons\.)", "CorpusTablerIcon(", text)

    # Nullable icon fields
    text = text.replace(
        "CorpusTablerIcon(widget.icon,",
        "CorpusTablerIcon(widget.icon!,",
    )

    return text


def ensure_imports(text: str) -> str:
    needs_tabler = "CorpusTablerIcon" in text
    needs_kind = "CorpusIconKind" in text
    if not needs_tabler and not needs_kind:
        return text

    if needs_tabler and "corpus_tabler_icon.dart" not in text:
        if "import 'package:flutter/material.dart';" in text:
            extra = ""
            if needs_kind:
                extra = "import 'package:corpus/widgets/corpus_icon_kind.dart';\n"
            extra += "import 'package:corpus/widgets/corpus_tabler_icon.dart';\n"
            text = text.replace(
                "import 'package:flutter/material.dart';",
                "import 'package:flutter/material.dart';\n" + extra,
                1,
            )
    elif needs_kind and "corpus_icon_kind.dart" not in text:
        text = "import 'package:corpus/widgets/corpus_icon_kind.dart';\n" + text
    return text


def main() -> None:
    for path in sorted(LIB.rglob("*.dart")):
        if path.name == "profile_stat_icon.dart":
            continue
        original = path.read_text(encoding="utf-8")
        updated = fix_content(original)
        updated = ensure_imports(updated)
        if updated != original:
            path.write_text(updated, encoding="utf-8")
            print(f"fixed: {path.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
