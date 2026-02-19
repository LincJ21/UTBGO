import 'dart:io';
import 'package:flutter/material.dart';

/// Widget simple para mostrar imágenes en el feed
class ImagePostWidget extends StatelessWidget {
  final String url;

  const ImagePostWidget({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    const placeholderColor = Color.fromARGB(255, 214, 212, 212);

    return Container(
      color: Colors.transparent,
      width: double.infinity,
      height: double.infinity,
      child: url.isNotEmpty
          ? (url.startsWith('http')
              ? Image.network(
                  url,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Container(
                      width: double.infinity,
                      height: double.infinity,
                      color: placeholderColor,
                      child: const Center(child: CircularProgressIndicator()),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) =>
                      Container(width: double.infinity, height: double.infinity, color: placeholderColor, child: const Center(child: Icon(Icons.error, color: Colors.grey))),
                )
              : Image.file(
                  File(url),
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(width: double.infinity, height: double.infinity, color: placeholderColor, child: const Center(child: Icon(Icons.error, color: Colors.grey))),
                ))
          : Container(width: double.infinity, height: double.infinity, color: placeholderColor, child: const Center(child: Icon(Icons.image, color: Colors.grey))),
    );
  }
}