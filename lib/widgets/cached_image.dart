import 'package:flutter/material.dart';
import 'package:wild/src/rust/api/wenku8.dart';
import 'dart:io';

class CachedImage extends StatelessWidget {
  final String url;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;

  const CachedImage({
    super.key,
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image = FutureBuilder<String>(
      future: downloadImage(url: url),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            color: Colors.grey.withAlpha(80),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Container(
            color: Colors.grey.withAlpha(80),
            child: const Icon(Icons.broken_image),
          );
        }
        return Image.file(
          File(snapshot.data!),
          fit: fit,
          width: width,
          height: height,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey.withAlpha(80),
              child: const Icon(Icons.broken_image),
            );
          },
        );
      },
    );

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
} 