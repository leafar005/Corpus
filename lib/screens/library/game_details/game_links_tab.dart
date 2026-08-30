import 'package:flutter/material.dart';
import '../../../theme/corpus_theme_extension.dart';
import '../../../utils/url_utils.dart';
import '../../../widgets/corpus_network_image.dart';

class GameLinksTab extends StatelessWidget {
  const GameLinksTab({
    super.key,
    required this.websitesList,
    required this.localizeLinks,
  });

  final List websitesList;
  final bool localizeLinks;

  String _localizeUrlToSpain(String rawUrl) {
    if (!localizeLinks) return rawUrl;
    String url = rawUrl;
    final lower = url.toLowerCase();
    if (lower.contains('store.steampowered.com')) {
      final separator = url.contains('?') ? '&' : '?';
      if (!lower.contains('l=spanish') && !lower.contains('cc=es')) {
        return '$url${separator}l=spanish&cc=es';
      }
    }
    if (lower.contains('store.playstation.com')) {
      return url.replaceAll(
        RegExp(
          r'/(en|es|fr|de|it|pt|ja|ko|zh)-[a-z]{2}/',
          caseSensitive: false,
        ),
        '/es-es/',
      );
    }
    if (lower.contains('xbox.com') || lower.contains('microsoft.com')) {
      return url.replaceAll(
        RegExp(
          r'/(en|es|fr|de|it|pt|ja|ko|zh)-[a-z]{2}/',
          caseSensitive: false,
        ),
        '/es-es/',
      );
    }
    if (lower.contains('store.epicgames.com') ||
        lower.contains('epicgames.com')) {
      return url.replaceAll(
        RegExp(
          r'/(en|es|fr|de|it|pt|ja|ko|zh)-[a-zA-Z]{2}/',
          caseSensitive: false,
        ),
        '/es-ES/',
      );
    }
    if (lower.contains('nintendo.com')) {
      return url.replaceAll(
        RegExp(r'/(en-us|en-gb|us|uk)/', caseSensitive: false),
        '/es-es/',
      );
    }
    if (lower.contains('apps.apple.com')) {
      return url.replaceAll(
        RegExp(r'/apps\.apple\.com/[a-z]{2}/', caseSensitive: false),
        '/apps.apple.com/es/',
      );
    }
    if (lower.contains('gog.com')) {
      return url.replaceAll(
        RegExp(r'/gog\.com/(en|de|fr|pl|ru|zh)/', caseSensitive: false),
        '/gog.com/es/',
      );
    }
    return url;
  }

  @override
  Widget build(BuildContext context) {
    if (websitesList.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('No hay enlaces disponibles.'),
        ),
      );
    }

    int getCategory(dynamic w) {
      if (w is Map && w['category'] != null) {
        final c = w['category'];
        if (c is int) return c;
        if (c is String) return int.tryParse(c) ?? 0;
        if (c is num) return c.toInt();
      }
      return 0;
    }

    bool isConsoleStore(dynamic w) {
      if (w is Map && w['url'] != null) {
        final url = w['url'].toString().toLowerCase();
        return url.contains('playstation.com') ||
            url.contains('xbox.com') ||
            url.contains('nintendo.com');
      }
      return false;
    }

    final stores = websitesList
        .where(
          (w) => [13, 15, 16, 17].contains(getCategory(w)) || isConsoleStore(w),
        )
        .toList();
    final socials = websitesList
        .where((w) => [4, 5, 6, 8, 9, 14, 18].contains(getCategory(w)))
        .toList();
    final official = websitesList
        .where((w) => [1, 2, 3].contains(getCategory(w)))
        .toList();
    final mobile = websitesList
        .where((w) => [10, 11, 12].contains(getCategory(w)))
        .toList();
    final others = websitesList
        .where(
          (w) =>
              ![
                1,
                2,
                3,
                4,
                5,
                6,
                8,
                9,
                10,
                11,
                12,
                13,
                14,
                15,
                16,
                17,
                18,
              ].contains(getCategory(w)) &&
              !isConsoleStore(w),
        )
        .toList();

    Widget buildLinkSection(String title, List links, IconData icon) {
      if (links.isEmpty) return const SizedBox.shrink();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...links.map((link) {
            String name = 'Enlace';
            IconData itemIcon = Icons.link;
            final cat = getCategory(link);
            switch (cat) {
              case 1:
                name = 'Sitio Oficial';
                itemIcon = Icons.language;
                break;
              case 2:
                name = 'Wikia';
                itemIcon = Icons.menu_book;
                break;
              case 3:
                name = 'Wikipedia';
                itemIcon = Icons.menu_book;
                break;
              case 4:
                name = 'Facebook';
                itemIcon = Icons.facebook;
                break;
              case 5:
                name = 'Twitter';
                itemIcon = Icons.alternate_email;
                break;
              case 6:
                name = 'Twitch';
                itemIcon = Icons.live_tv;
                break;
              case 8:
                name = 'Instagram';
                itemIcon = Icons.camera_alt;
                break;
              case 9:
                name = 'YouTube';
                itemIcon = Icons.video_library;
                break;
              case 10:
                name = 'iPhone';
                itemIcon = Icons.phone_iphone;
                break;
              case 11:
                name = 'iPad';
                itemIcon = Icons.tablet_mac;
                break;
              case 12:
                name = 'Android';
                itemIcon = Icons.phone_android;
                break;
              case 13:
                name = 'Steam';
                itemIcon = Icons.computer;
                break;
              case 14:
                name = 'Reddit';
                itemIcon = Icons.forum;
                break;
              case 15:
                name = 'Itch.io';
                itemIcon = Icons.gamepad;
                break;
              case 16:
                name = 'Epic Games';
                itemIcon = Icons.computer;
                break;
              case 17:
                name = 'GOG';
                itemIcon = Icons.computer;
                break;
              case 18:
                name = 'Discord';
                itemIcon = Icons.chat;
                break;
              default:
                final urlString = link['url'].toString().toLowerCase();
                if (urlString.contains('playstation.com')) {
                  name = 'PlayStation Store';
                  itemIcon = Icons.gamepad;
                } else if (urlString.contains('xbox.com')) {
                  name = 'Xbox Store';
                  itemIcon = Icons.sports_esports;
                } else if (urlString.contains('nintendo.com')) {
                  name = 'Nintendo eShop';
                  itemIcon = Icons.videogame_asset;
                } else if (urlString.contains('igdb.com')) {
                  name = 'IGDB';
                  itemIcon = Icons.storage;
                } else {
                  try {
                    final uri = Uri.parse(link['url'].toString());
                    name = uri.host.replaceFirst('www.', '');
                  } catch (_) {}
                }
            }

            String extractDomain(String rawUrl) {
              String url = rawUrl.trim();
              if (!url.startsWith('http://') && !url.startsWith('https://')) {
                url = 'https://$url';
              }
              return Uri.tryParse(url)?.host ?? '';
            }

            final domain = extractDomain(link['url'].toString());

            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
                border: Border.all(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.05),
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                borderRadius: Theme.of(
                  context,
                ).extension<CorpusThemeExtension>()!.radiusMedium,
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  leading: Container(
                    width: 32,
                    height: 32,
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: Theme.of(
                        context,
                      ).extension<CorpusThemeExtension>()!.radiusSmall,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: CorpusNetworkImage(
                        // Usamos el proxy de images.weserv.nl para añadir las
                        // cabeceras CORS necesarias (Access-Control-Allow-Origin: *)
                        // a la API de Google Favicons.
                        // Google siempre devuelve un PNG válido (resolviendo el
                        // problema de los .ico de Steam/PS) y procesa bien los
                        // subdominios (como www.igdb.com), pero originalmente
                        // fallaba en Flutter Web por falta de CORS.
                        url:
                            'https://images.weserv.nl/?url=${Uri.encodeComponent('https://www.google.com/s2/favicons?domain=$domain&sz=64')}',
                        fit: BoxFit.contain,
                        placeholder: Icon(itemIcon, size: 18),
                      ),
                    ),
                  ),
                  title: Text(name),
                  subtitle: Text(
                    _localizeUrlToSpain(link['url'].toString()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: const Icon(Icons.open_in_new, size: 16),
                  onTap: () =>
                      openUrl(_localizeUrlToSpain(link['url'].toString())),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        buildLinkSection('Tiendas', stores, Icons.store),
        buildLinkSection('Sociales y Comunidad', socials, Icons.people),
        buildLinkSection('Información Oficial', official, Icons.info),
        buildLinkSection('Móvil', mobile, Icons.smartphone),
        buildLinkSection('Otros', others, Icons.link),
      ],
    );
  }
}
