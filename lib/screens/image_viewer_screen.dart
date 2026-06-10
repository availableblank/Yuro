import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final String? title;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title ?? '图片预览',
          style: const TextStyle(fontSize: 16),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: Center(
        child: PhotoView(
          imageProvider: CachedNetworkImageProvider(imageUrl),
          // 最小缩放：适应屏幕
          minScale: PhotoViewComputedScale.contained,
          // 最大缩放：3倍
          maxScale: PhotoViewComputedScale.covered * 3.0,
          // 纯黑背景
          backgroundDecoration: const BoxDecoration(color: Colors.black),
          // 加载中指示器
          loadingBuilder: (context, progress) => const Center(
            child: CircularProgressIndicator(
              color: Colors.white54,
            ),
          ),
          // 加载失败提示
          errorBuilder: (context, error, stackTrace) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.broken_image,
                    color: Colors.white54, size: 64),
                const SizedBox(height: 16),
                Text(
                  '图片加载失败',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.white54,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '请检查网络连接后重试',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.white38,
                      ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}