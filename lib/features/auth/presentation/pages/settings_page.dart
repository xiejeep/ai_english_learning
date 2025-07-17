import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/storage/storage_service.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  // 移除：气泡样式相关变量、方法、UI，只保留主题管理入口
  bool _isClearing = false;

  @override
  void initState() {
    super.initState();
  }


  // 缓存管理相关方法
  String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    int i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return '${size.toStringAsFixed(1)} ${suffixes[i]}';
  }

  Future<void> _clearAudioCache() async {
    setState(() {
      _isClearing = true;
    });
    try {
      bool hasCache = false;
      final appDir = await getApplicationDocumentsDirectory();
      final ttsCacheDir = Directory('${appDir.path}/tts_cache');
      if (await ttsCacheDir.exists()) {
        await ttsCacheDir.delete(recursive: true);
        hasCache = true;
      }
      final simpleTtsCacheDir = Directory('${appDir.path}/simple_tts_cache');
      if (await simpleTtsCacheDir.exists()) {
        await simpleTtsCacheDir.delete(recursive: true);
        hasCache = true;
      }
      final tempDir = await getTemporaryDirectory();
      final tempTtsDir = Directory('${tempDir.path}/simple_tts');
      if (await tempTtsDir.exists()) {
        await tempTtsDir.delete(recursive: true);
        hasCache = true;
      }
      if (hasCache) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('音频缓存清除成功'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('没有找到音频缓存'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('清除缓存失败: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      setState(() {
        _isClearing = false;
      });
    }
  }

  void _showClearCacheDialog() async {
    String cacheSize = '计算中...';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            if (cacheSize == '计算中...') {
              _calculateCacheSizeForDialog().then((size) {
                setState(() {
                  cacheSize = size;
                });
              });
            }
            return AlertDialog(
              title: const Text('清除音频缓存'),
              content: Text('确定要清除所有音频缓存文件吗？\n\n当前缓存大小: $cacheSize'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _clearAudioCache();
                  },
                  child: const Text(
                    '确定',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<String> _calculateCacheSizeForDialog() async {
    try {
      int totalSize = 0;
      final appDir = await getApplicationDocumentsDirectory();
      final ttsCacheDir = Directory('${appDir.path}/tts_cache');
      if (await ttsCacheDir.exists()) {
        await for (final entity in ttsCacheDir.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
      final simpleTtsCacheDir = Directory('${appDir.path}/simple_tts_cache');
      if (await simpleTtsCacheDir.exists()) {
        await for (final entity in simpleTtsCacheDir.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
      final tempDir = await getTemporaryDirectory();
      final tempTtsDir = Directory('${tempDir.path}/simple_tts');
      if (await tempTtsDir.exists()) {
        await for (final entity in tempTtsDir.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
      }
      return _formatBytes(totalSize);
    } catch (e) {
      return '计算失败';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题管理入口
          Card(
            child: ListTile(
              leading: Icon(Icons.color_lens, color: Theme.of(context).primaryColor),
              title: const Text('主题与气泡样式'),
              subtitle: const Text('自定义主题色、聊天气泡颜色、文字颜色等'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.push('/theme-settings'),
            ),
          ),
          const SizedBox(height: 16),
          // 缓存管理部分
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '缓存管理',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.audiotrack,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('清理缓存'),
                  subtitle: const Text('清理音频缓存文件'),
                  trailing: _isClearing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.chevron_right),
                  onTap: _isClearing ? null : _showClearCacheDialog,
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // 应用信息部分
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    '应用信息',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                ListTile(
                  leading: Icon(
                    Icons.info_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('应用版本'),
                  subtitle: const Text(AppConstants.appVersion),
                ),
                ListTile(
                  leading: Icon(
                    Icons.apps,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('应用名称'),
                  subtitle: const Text(AppConstants.appName),
                ),
                ListTile(
                  leading: Icon(
                    Icons.help_outline,
                    color: Theme.of(context).primaryColor,
                  ),
                  title: const Text('关于我们'),
                  subtitle: const Text('了解更多应用信息'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppConstants.aboutRoute),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}