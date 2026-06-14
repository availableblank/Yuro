import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageViewerScreen extends StatefulWidget {
  /// 单张图片 URL（向后兼容，画廊模式时此值为初始图片）
  final String imageUrl;
  final String? title;

  /// 画廊模式：所有图片 URL 列表
  final List<String> imageUrls;

  /// 画廊模式：与 imageUrls 一一对应的标题列表
  final List<String?> imageTitles;

  /// 画廊模式：初始显示的图片索引
  final int initialIndex;

  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.title,
    this.imageUrls = const [],
    this.imageTitles = const [],
    this.initialIndex = 0,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  /// 是否进入画廊模式（图片数量 > 1）
  bool get _isGalleryMode => widget.imageUrls.length > 1;

  /// 当前图片对应的标题
  String get _currentTitle {
    if (_isGalleryMode &&
        widget.imageTitles.length > _currentIndex &&
        widget.imageTitles[_currentIndex] != null &&
        widget.imageTitles[_currentIndex]!.isNotEmpty) {
      return widget.imageTitles[_currentIndex]!;
    }
    return widget.title ?? '图片预览';
  }

  @override
  void initState() {
    super.initState();
    // 确保初始索引在有效范围
    _currentIndex = widget.initialIndex.clamp(
      0,
      widget.imageUrls.isEmpty ? 0 : widget.imageUrls.length - 1,
    );
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = _isGalleryMode ? widget.imageUrls.length : 1;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _currentTitle,
              style: const TextStyle(fontSize: 16),
            ),
            // 画廊模式显示页码指示器
            if (_isGalleryMode)
              Text(
                '${_currentIndex + 1} / $totalCount',
                style: const TextStyle(fontSize: 12, color: Colors.white54),
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      body: _isGalleryMode ? _buildGallery() : _buildSingleImage(widget.imageUrl),
    );
  }

  /// 画廊模式：PageView 包裹多个 PhotoView，支持左右滑动
  Widget _buildGallery() {
    return PageView.builder(
      controller: _pageController,
      itemCount: widget.imageUrls.length,
      onPageChanged: (index) {
        setState(() {
          _currentIndex = index;
        });
      },
      itemBuilder: (context, index) {
        return _buildSingleImage(widget.imageUrls[index]);
      },
    );
  }

  /// 单图 PhotoView
  Widget _buildSingleImage(String url) {
    return Center(
      child: PhotoView(
        imageProvider: CachedNetworkImageProvider(url),
        minScale: PhotoViewComputedScale.contained,
        maxScale: PhotoViewComputedScale.covered * 3.0,
        backgroundDecoration: const BoxDecoration(color: Colors.black),
        loadingBuilder: (context, progress) => const Center(
          child: CircularProgressIndicator(color: Colors.white54),
        ),
        errorBuilder: (context, error, stackTrace) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.broken_image, color: Colors.white54, size: 64),
              const SizedBox(height: 16),
              Text(
                '图片加载失败',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Colors.white54),
              ),
              const SizedBox(height: 8),
              Text(
                '请检查网络连接后重试',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Colors.white38),
              ),
            ],
          ),
        ),
      ),
    );
  }
}