import 'dart:io';

import 'package:flutter/material.dart';

class ProductImage extends StatelessWidget {
  final String source;
  final double? width;
  final double? height;
  final double iconSize;
  final BoxFit fit;

  const ProductImage({
    super.key,
    required this.source,
    this.width,
    this.height,
    this.iconSize = 18,
    this.fit = BoxFit.cover,
  });

  @override
  Widget build(BuildContext context) {
    final path = source.trim();
    final placeholder = Icon(
      Icons.inventory_2_outlined,
      size: iconSize,
      color: Colors.black38,
    );
    if (path.isEmpty) return placeholder;
    final uri = Uri.tryParse(path);
    final ImageProvider image;
    if (uri != null && ['http', 'https'].contains(uri.scheme)) {
      image = NetworkImage(path);
    } else {
      image = FileImage(
        uri != null && uri.scheme == 'file' ? File.fromUri(uri) : File(path),
      );
    }
    return Image(
      image: image,
      width: width,
      height: height,
      fit: fit,
      errorBuilder: (context, error, stack) {
        debugPrint(
          'Product image could not be loaded (${error.runtimeType}). Sync to retry.',
        );
        return Center(child: placeholder);
      },
    );
  }
}
