import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

enum ProfileStatIconType {
  beaten,
  platinum,
  playing,
  wishlist,
}

class ProfileStatIcon extends StatelessWidget {
  const ProfileStatIcon({
    super.key,
    required this.type,
    this.size = 18,
    this.color,
  });

  final ProfileStatIconType type;
  final double size;
  final Color? color;

  static const _paths = {
    ProfileStatIconType.beaten:
        'M530.8 134.1C545.1 144.5 548.3 164.5 537.9 178.8L281.9 530.8C276.4 538.4 267.9 543.1 258.5 543.9C249.1 544.7 240 541.2 233.4 534.6L105.4 406.6C92.9 394.1 92.9 373.8 105.4 361.3C117.9 348.8 138.2 348.8 150.7 361.3L252.2 462.8L486.2 141.1C496.6 126.8 516.6 123.6 530.9 134z',
    ProfileStatIconType.platinum:
        'M208.3 64L432.3 64C458.8 64 480.4 85.8 479.4 112.2C479.2 117.5 479 122.8 478.7 128L528.3 128C554.4 128 577.4 149.6 575.4 177.8C567.9 281.5 514.9 338.5 457.4 368.3C441.6 376.5 425.5 382.6 410.2 387.1C390 415.7 369 430.8 352.3 438.9L352.3 512L416.3 512C434 512 448.3 526.3 448.3 544C448.3 561.7 434 576 416.3 576L224.3 576C206.6 576 192.3 561.7 192.3 544C192.3 526.3 206.6 512 224.3 512L288.3 512L288.3 438.9C272.3 431.2 252.4 416.9 233 390.6C214.6 385.8 194.6 378.5 175.1 367.5C121 337.2 72.2 280.1 65.2 177.6C63.3 149.5 86.2 127.9 112.3 127.9L161.9 127.9C161.6 122.7 161.4 117.5 161.2 112.1C160.2 85.6 181.8 63.9 208.3 63.9zM165.5 176L113.1 176C119.3 260.7 158.2 303.1 198.3 325.6C183.9 288.3 172 239.6 165.5 176zM444 320.8C484.5 297 521.1 254.7 527.3 176L475 176C468.8 236.9 457.6 284.2 444 320.8z',
    ProfileStatIconType.playing:
        'M187.2 100.9C174.8 94.1 159.8 94.4 147.6 101.6C135.4 108.8 128 121.9 128 136L128 504C128 518.1 135.5 531.2 147.6 538.4C159.7 545.6 174.8 545.9 187.2 539.1L523.2 355.1C536 348.1 544 334.6 544 320C544 305.4 536 291.9 523.2 284.9L187.2 100.9z',
    ProfileStatIconType.wishlist:
        'M47.6 300.4L228.3 469.1C234.7 475.1 244.5 475.1 250.9 469.1L431.6 300.4C460.6 273.8 480 235.8 480 192C480 124.7 425.3 70 358 70C317.4 70 280.8 91.6 256 125.5C231.2 91.6 194.6 70 154 70C86.7 70 32 124.7 32 192C32 235.8 51.4 273.8 80.4 300.4L47.6 300.4z',
  };

  @override
  Widget build(BuildContext context) {
    final iconColor =
        color ?? Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.85);

    return SvgPicture.string(
      '''
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 640 640">
  <path d="${_paths[type]!}" />
</svg>
''',
      width: size,
      height: size,
      colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
    );
  }
}
