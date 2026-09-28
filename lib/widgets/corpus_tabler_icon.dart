import 'package:flutter/material.dart';
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
      : kind = CorpusIconKind.Home;

  const CorpusTablerIcon.compass({super.key, this.size, this.color})
      : kind = CorpusIconKind.Compass;

  const CorpusTablerIcon.search({super.key, this.size, this.color})
      : kind = CorpusIconKind.Search;

  const CorpusTablerIcon.users({super.key, this.size, this.color})
      : kind = CorpusIconKind.Users;

  const CorpusTablerIcon.tag({super.key, this.size, this.color})
      : kind = CorpusIconKind.Tag;

  const CorpusTablerIcon.gamepad({super.key, this.size, this.color})
      : kind = CorpusIconKind.Gamepad;

  const CorpusTablerIcon.user({super.key, this.size, this.color})
      : kind = CorpusIconKind.Person;

  const CorpusTablerIcon.userFilled({super.key, this.size, this.color})
      : kind = CorpusIconKind.UserFilled;

  const CorpusTablerIcon.userPlus({super.key, this.size, this.color})
      : kind = CorpusIconKind.PersonAdd;

  const CorpusTablerIcon.palette({super.key, this.size, this.color})
      : kind = CorpusIconKind.Palette;

  const CorpusTablerIcon.bell({super.key, this.size, this.color})
      : kind = CorpusIconKind.Bell;

  const CorpusTablerIcon.plug({super.key, this.size, this.color})
      : kind = CorpusIconKind.Plug;

  const CorpusTablerIcon.info({super.key, this.size, this.color})
      : kind = CorpusIconKind.Info;

  const CorpusTablerIcon.chevronRight({super.key, this.size, this.color})
      : kind = CorpusIconKind.ChevronRight;

  const CorpusTablerIcon.language({super.key, this.size, this.color})
      : kind = CorpusIconKind.Language;

  const CorpusTablerIcon.timer({super.key, this.size, this.color})
      : kind = CorpusIconKind.AccessTime;

  const CorpusTablerIcon.trashX({super.key, this.size, this.color})
      : kind = CorpusIconKind.TrashX;

  const CorpusTablerIcon.logout({super.key, this.size, this.color})
      : kind = CorpusIconKind.Logout;

  const CorpusTablerIcon.broom({super.key, this.size, this.color})
      : kind = CorpusIconKind.Broom;

  const CorpusTablerIcon.clear({super.key, this.size, this.color})
      : kind = CorpusIconKind.Clear;

  const CorpusTablerIcon.tune({super.key, this.size, this.color})
      : kind = CorpusIconKind.Tune;

  const CorpusTablerIcon.star({super.key, this.size, this.color})
      : kind = CorpusIconKind.Star;

  const CorpusTablerIcon.thumbUp({super.key, this.size, this.color})
      : kind = CorpusIconKind.ThumbUp;

  const CorpusTablerIcon.thumbUpOff({super.key, this.size, this.color})
      : kind = CorpusIconKind.ThumbUpAltOutlined;

  const CorpusTablerIcon.message({super.key, this.size, this.color})
      : kind = CorpusIconKind.ChatBubbleOutline;

  const CorpusTablerIcon.repeat({super.key, this.size, this.color})
      : kind = CorpusIconKind.Replay;

  const CorpusTablerIcon.lock({super.key, this.size, this.color})
      : kind = CorpusIconKind.Lock;

  const CorpusTablerIcon.login({super.key, this.size, this.color})
      : kind = CorpusIconKind.Login;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final resolvedSize = size ?? theme.size ?? 24;
    final resolvedColor =
        color ?? theme.color ?? Theme.of(context).colorScheme.onSurfaceVariant;

    return ClipRect(
      child: SizedBox(
        width: resolvedSize,
        height: resolvedSize,
        child: Center(
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(resolvedColor, BlendMode.srcIn),
            child: buildTablerSvg(kind, resolvedSize),
          ),
        ),
      ),
    );
  }
}

/// Prefix icon for [InputDecoration] — prevents the default 48×48 slot from
/// stretching custom SVG icons on web.
Widget corpusInputPrefixIcon(
  CorpusIconKind kind, {
  double size = 20,
  Color? color,
}) {
  return Padding(
    padding: const EdgeInsets.only(left: 12, right: 4),
    child: CorpusTablerIcon(kind, size: size, color: color),
  );
}

/// Shorthand for [CorpusTablerIcon].
Widget corpusIcon(
  CorpusIconKind kind, {
  Key? key,
  double? size,
  Color? color,
}) =>
    CorpusTablerIcon(kind, key: key, size: size, color: color);
