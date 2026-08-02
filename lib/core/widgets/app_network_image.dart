import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Image widget backed by [CachedNetworkImage].
///
/// Falls back to a branded placeholder while loading or on error.
class AppNetworkImage extends StatelessWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (url.isEmpty) {
      image = const _Placeholder();
    } else {
      image = CachedNetworkImage(
        imageUrl: url,
        width: width,
        height: height,
        fit: fit,
        fadeInDuration: const Duration(milliseconds: 200),
        placeholder: (context, url) => const _Placeholder(),
        errorWidget: (context, url, error) => const _Placeholder(),
      );
    }
    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: image);
    }
    return image;
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.brand.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: const Icon(
        Icons.apartment_rounded,
        size: 40,
        color: AppTheme.brandLight,
      ),
    );
  }
}
