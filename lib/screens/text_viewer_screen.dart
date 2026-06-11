import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:charset/charset.dart';

/// 文本文件预览页面
class TextViewerScreen extends StatefulWidget {
  final String textUrl;
  final String title;

  const TextViewerScreen({
    super.key,
    required this.textUrl,
    required this.title,
  });

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  final Dio _dio = Dio();
  String? _content;
  String? _error;
  bool _loading = true;
  String _detectedEncoding = '';

  @override
  void initState() {
    super.initState();
    _loadText();
  }

  Future<void> _loadText() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 以字节形式获取文件内容
      final response = await _dio.get<List<int>>(
        widget.textUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) {
        setState(() {
          _error = '文件内容为空';
          _loading = false;
        });
        return;
      }

      // 使用 charset 库解码：依次尝试常见编码
      String decoded;
      try {
        // 优先尝试 UTF-8
        decoded = utf8.decode(bytes);
        _detectedEncoding = 'UTF-8';
      } catch (_) {
        try {
          // 尝试 Shift-JIS（日语常用）
          decoded = shiftJis.decode(bytes);
          _detectedEncoding = 'Shift-JIS';
        } catch (_) {
          try {
            // 尝试 GBK（中文常用）
            decoded = gbk.decode(bytes);
            _detectedEncoding = 'GBK';
          } catch (_) {
            // 最后兜底用 latin1（不会失败）
            decoded = latin1.decode(bytes);
            _detectedEncoding = 'Latin-1';
          }
        }
      }

      setState(() {
        _content = decoded;
        _loading = false;
      });
    } on DioException catch (e) {
      setState(() {
        _error = '加载失败: ${e.message}';
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = '加载失败: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (_detectedEncoding.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Center(
                child: Text(
                  _detectedEncoding,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(colorScheme),
    );
  }

  Widget _buildBody(ColorScheme colorScheme) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 48, color: colorScheme.error),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: colorScheme.error),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _loadText,
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: SelectableText(
        _content ?? '',
        style: TextStyle(
          fontSize: 15,
          height: 1.7,
          color: colorScheme.onSurface,
        ),
      ),
    );
  }
}