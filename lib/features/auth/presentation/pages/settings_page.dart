import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../../core/constants/app_constants.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  bool _isClearing = false;
  String _cacheSize = '计算中...';

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/audio_cache');
      
      if (await audioDir.exists()) {
        int totalSize = 0;
        await for (final entity in audioDir.list(recursive: true)) {
          if (entity is File) {
            final stat = await entity.stat();
            totalSize += stat.size;
          }
        }
        
        setState(() {
          _cacheSize = _formatBytes(totalSize);
        });
      } else {
        setState(() {
          _cacheSize = '0 B';
        });
      }
    } catch (e) {
      setState(() {
        _cacheSize = '计算失败';
      });
    }
  }

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
      final tempDir = await getTemporaryDirectory();
      final audioDir = Directory('${tempDir.path}/audio_cache');
      
      if (await audioDir.exists()) {
        await audioDir.delete(recursive: true);
        
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
      
      // 重新计算缓存大小
      await _calculateCacheSize();
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

  void _showClearCacheDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('清除音频缓存'),
          content: Text('确定要清除所有音频缓存文件吗？\n\n当前缓存大小: $_cacheSize'),
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
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
                  title: const Text('音频缓存'),
                  subtitle: Text('当前大小: $_cacheSize'),
                  trailing: _isClearing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _showClearCacheDialog,
                          tooltip: '清除音频缓存',
                        ),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}