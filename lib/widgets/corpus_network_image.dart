import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Widget de imagen de red centralizado para Corpus.
///
/// En web usa [Image.network] con fade-in nativo (la caché de disco no es
/// compatible con Flutter Web; el navegador ya gestiona su propia caché HTTP).
/// En móvil/desktop usa [CachedNetworkImage] para cachear en disco y evitar
/// re-descargas y parpadeos en el scroll.
///
/// Parámetros:
/// - [url]          URL de la imagen. Si está vacía o es null, muestra [placeholder].
/// - [fit]          BoxFit (por defecto cover).
/// - [width]/[height] Dimensiones opcionales.
/// - [placeholder]  Widget mostrado mientras carga o si la URL es vacía.
/// - [cacheWidth]   Hint de resolución para el decodificador de imagen.
class CorpusNetworkImage extends StatelessWidget {
  const CorpusNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.cacheWidth,
    this.alignment = Alignment.center,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final int? cacheWidth;
  final Alignment alignment;

  static const Duration _fadeDuration = Duration(milliseconds: 300);

  Widget _empty(BuildContext context) =>
      placeholder ??
      Container(color: Theme.of(context).colorScheme.surfaceContainerHighest);

  @override
  Widget build(BuildContext context) {
    final src = url?.trim() ?? '';
    if (src.isEmpty) return _empty(context);

    // Web: CachedNetworkImage usa sqflite que no soporta web.
    // El navegador ya cachea automáticamente las respuestas HTTP.
    if (kIsWeb) {
      return Image.network(
        src,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        cacheWidth: cacheWidth,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded) return child;
          return AnimatedOpacity(
            opacity: frame == null ? 0 : 1,
            duration: _fadeDuration,
            curve: Curves.easeOut,
            child: child,
          );
        },
        errorBuilder: (context, error, stackTrace) => _empty(context),
      );
    }

    // Móvil / Desktop: caché en disco + fade-in
    return CachedNetworkImage(
      imageUrl: src,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      memCacheWidth: cacheWidth,
      fadeInDuration: _fadeDuration,
      fadeOutDuration: const Duration(milliseconds: 100),
      placeholder: (context, url) => _empty(context),
      errorWidget: (context, url, error) => _empty(context),
    );
  }
}
