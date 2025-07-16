import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/services/dictionary_service.dart';
import '../../../../core/constants/app_constants.dart';

class DictionaryPage extends StatefulWidget {
  final String word;

  const DictionaryPage({super.key, required this.word});

  @override
  State<DictionaryPage> createState() => _DictionaryPageState();
}

class _DictionaryPageState extends State<DictionaryPage> {
  DictionaryResult? _result;
  bool _isLoading = true;
  String? _errorMessage;
  WebViewController? _webViewController;
  List<DictionaryInfo> _dictionaries = [];
  DictionaryInfo? _selectedDictionary;
  bool _isDictionariesLoading = true;
  
  // 搜索关键词相关
  late TextEditingController _searchController;
  String _currentSearchWord = '';

  @override
  void initState() {
    super.initState();
    _currentSearchWord = widget.word;
    _searchController = TextEditingController(text: widget.word);
    _loadDictionaries();
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDictionaries() async {
    try {
      final dictionaries = await DictionaryService.instance.getAvailableDictionaries();
      setState(() {
        _dictionaries = dictionaries ?? [];
        _isDictionariesLoading = false;
        if (_dictionaries.isNotEmpty) {
          _selectedDictionary = _dictionaries.first;
        }
      });
      // 加载完词典列表后开始查词
      _lookupWord();
    } catch (e) {
      setState(() {
        _isDictionariesLoading = false;
      });
      // 即使获取词典列表失败，也尝试使用默认词典查词
      _lookupWord();
    }
  }

  Future<void> _lookupWord({String? customWord}) async {
    final wordToLookup = customWord ?? _currentSearchWord;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _result = null;
      _webViewController = null;
    });

    try {
      final result = await DictionaryService.instance.lookupWord(
        wordToLookup,
        dictionaryId: _selectedDictionary?.id,
      );
      setState(() {
        _result = result;
        _isLoading = false;
        if (result == null) {
          _errorMessage = '未找到"$wordToLookup"的释义';
        } else if (result.htmlDefinition != null) {
          // 创建WebView控制器并加载HTML内容
          _webViewController = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..setBackgroundColor(const Color(0x00000000))
            ..setNavigationDelegate(
              NavigationDelegate(
                onProgress: (int progress) {
                  print('🔄 WebView加载进度: $progress%');
                },
                onPageStarted: (String url) {
                  print('📄 开始加载页面: $url');
                },
                onPageFinished: (String url) {
                  print('✅ 页面加载完成: $url');
                },
                onWebResourceError: (WebResourceError error) {
                  print('❌ WebView资源加载错误:');
                  print('   错误描述: ${error.description}');
                  print('   错误代码: ${error.errorCode}');
                  print('   错误类型: ${error.errorType}');
                  print('   失败URL: ${error.url}');
                },
                onNavigationRequest: (NavigationRequest request) {
                  print('🔗 导航请求: ${request.url}');
                  
                  // 阻止entry://等非HTTP协议的跳转
                  if (request.url.startsWith('entry://') || 
                      request.url.startsWith('sound://') ||
                      (!request.url.startsWith('http://') && 
                       !request.url.startsWith('https://') && 
                       !request.url.startsWith('about:'))) {
                    print('🚫 阻止非HTTP协议跳转: ${request.url}');
                    return NavigationDecision.prevent;
                  }
                  
                  // 只允许about:blank和资源URL
                  if (request.url == 'about:blank' || 
                      request.url.contains('/api/dictionary/resource/')) {
                    return NavigationDecision.navigate;
                  }
                  
                  // 阻止其他外部链接跳转
                  print('🚫 阻止外部链接跳转: ${request.url}');
                  return NavigationDecision.prevent;
                },
              ),
            )
            ..addJavaScriptChannel(
              'ResourceLogger',
              onMessageReceived: (JavaScriptMessage message) {
                print('📱 JavaScript消息: ${message.message}');
              },
            )
            ..loadHtmlString(_buildHtmlContent(result.htmlDefinition!));
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = '查询失败，请稍后重试';
      });
    }
  }

  void _onSearchSubmitted(String value) {
    if (value.trim().isNotEmpty && value.trim() != _currentSearchWord) {
      setState(() {
        _currentSearchWord = value.trim();
      });
      _lookupWord(customWord: value.trim());
    }
  }

  /// 构建支持CSS样式文件的HTML内容
  String _buildHtmlContent(String definition) {
    print('🔵 开始构建HTML内容');
    print('📄 原始HTML长度: ${definition.length}');
    print('📄 原始HTML内容预览: ${definition.substring(0, definition.length > 200 ? 200 : definition.length)}...');
    
    // 处理资源文件路径
    String processedDefinition = _processResourcePaths(definition);
    
    // 同时处理CSS文件路径
    processedDefinition = _processCssFilePaths(processedDefinition);
    
    final htmlContent = '''
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            body {
                font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Helvetica Neue", Arial, sans-serif;
                font-size: 16px;
                line-height: 1.6;
                color: #333;
                margin: 16px;
                padding: 0;
                background-color: #fff;
            }
            .word-container {
                background-color: #f8f9fa;
                padding: 16px;
                border-radius: 8px;
                margin-bottom: 16px;
                border-left: 4px solid #007bff;
            }
            /* 图片样式 */
            img {
                max-width: 100%;
                height: auto;
                border-radius: 4px;
                margin: 8px 0;
            }
            /* 音频控件样式 */
            audio {
                width: 100%;
                margin: 8px 0;
            }
        </style>
        <script>
            // 监听资源加载错误
            window.addEventListener('error', function(e) {
                if (e.target !== window) {
                    var errorInfo = '资源加载失败: ' + e.target.src + ' (类型: ' + e.target.tagName + ')';
                    console.error(errorInfo);
                    if (window.ResourceLogger) {
                        ResourceLogger.postMessage(errorInfo);
                    }
                }
            }, true);
            
            // 阻止词典内部链接跳转
            document.addEventListener('DOMContentLoaded', function() {
                // 阻止所有链接点击
                document.addEventListener('click', function(e) {
                    var target = e.target;
                    // 向上查找a标签
                    while (target && target.tagName !== 'A') {
                        target = target.parentElement;
                    }
                    
                    if (target && target.tagName === 'A') {
                        var href = target.getAttribute('href');
                        if (href && (href.startsWith('entry://') || href.startsWith('sound://') || href.startsWith('#'))) {
                            console.log('阻止词典内部链接跳转: ' + href);
                            e.preventDefault();
                            e.stopPropagation();
                            return false;
                        }
                    }
                }, true);
                
                var images = document.querySelectorAll('img');
                console.log('找到 ' + images.length + ' 个图片元素');
                images.forEach(function(img, index) {
                    console.log('图片 ' + (index + 1) + ': ' + img.src);
                    img.onload = function() {
                        console.log('✅ 图片加载成功: ' + this.src);
                        if (window.ResourceLogger) {
                            ResourceLogger.postMessage('图片加载成功: ' + this.src);
                        }
                    };
                    img.onerror = function() {
                        console.error('❌ 图片加载失败: ' + this.src);
                        if (window.ResourceLogger) {
                            ResourceLogger.postMessage('图片加载失败: ' + this.src);
                        }
                    };
                });
                
                // 监听CSS文件加载
                var links = document.querySelectorAll('link[rel="stylesheet"]');
                console.log('找到 ' + links.length + ' 个CSS链接');
                links.forEach(function(link, index) {
                    console.log('CSS ' + (index + 1) + ': ' + link.href);
                    link.onload = function() {
                        console.log('✅ CSS加载成功: ' + this.href);
                        if (window.ResourceLogger) {
                            ResourceLogger.postMessage('CSS加载成功: ' + this.href);
                        }
                    };
                    link.onerror = function() {
                        console.error('❌ CSS加载失败: ' + this.href);
                        if (window.ResourceLogger) {
                            ResourceLogger.postMessage('CSS加载失败: ' + this.href);
                        }
                    };
                });
            });
        </script>
    </head>
    <body>
        <div class="word-container">
            $processedDefinition
        </div>
    </body>
    </html>
    ''';
    
    print('✅ 最终HTML内容长度: ${htmlContent.length}');
    print('✅ 最终HTML内容预览: ${htmlContent.substring(0, htmlContent.length > 500 ? 500 : htmlContent.length)}...');
    
    return htmlContent;
  }

  /// 处理CSS文件路径，将相对路径转换为绝对URL
  String _processCssFilePaths(String htmlContent) {
    if (_selectedDictionary == null) {
      print('⚠️ 未选择词典，跳过CSS路径处理');
      return htmlContent;
    }
    
    print('🎨 开始处理CSS文件路径');
    print('📖 选中词典ID: ${_selectedDictionary!.id}');
    
    // 构建资源基础URL
    final baseUrl = AppConstants.baseUrl.endsWith('/') 
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final resourceBaseUrl = '$baseUrl/api/dictionary/resource/${_selectedDictionary!.id}/';
    
    print('🔗 基础URL: $baseUrl');
    print('🔗 资源基础URL: $resourceBaseUrl');
    
    String processedContent = htmlContent;
    
    // 处理CSS文件的href属性 - 修复正则表达式以匹配/api开头的路径
    final cssLinkMatches = RegExp('href="(/api/dictionary/resource/[^/]+/[^"]*.css)"', caseSensitive: false).allMatches(htmlContent);
    print('🔍 找到 ${cssLinkMatches.length} 个CSS link标签');
    
    for (final match in cssLinkMatches) {
      final originalMatch = match.group(0)!;
      final cssPath = match.group(1)!;
      print('📎 原始CSS链接: $originalMatch');
      print('📎 CSS相对路径: $cssPath');
      
      final newHref = 'href="$baseUrl$cssPath"';
      processedContent = processedContent.replaceAll(originalMatch, newHref);
      print('✅ 转换后: $newHref');
    }
    
    // 处理CSS中的@import语句
    final cssImportMatches = RegExp('@import\\s+["\'](\\w+\\.css)["\']', caseSensitive: false).allMatches(htmlContent);
    print('🔍 找到 ${cssImportMatches.length} 个@import语句');
    
    for (final match in cssImportMatches) {
      final originalMatch = match.group(0)!;
      final cssPath = match.group(1)!;
      print('📥 原始@import: $originalMatch');
      print('📥 CSS文件名: $cssPath');
      
      if (!cssPath.startsWith('http')) {
        final newImport = '@import "$resourceBaseUrl$cssPath"';
        processedContent = processedContent.replaceAll(originalMatch, newImport);
        print('✅ 转换后: $newImport');
      } else {
        print('⏭️ 跳过绝对URL: $cssPath');
      }
    }
    
    print('🎨 CSS路径处理完成');
    return processedContent;
  }

  /// 处理词典资源文件路径，将相对路径转换为绝对URL
  String _processResourcePaths(String htmlContent) {
    if (_selectedDictionary == null) {
      print('⚠️ 未选择词典，跳过资源路径处理');
      return htmlContent;
    }
    
    print('🖼️ 开始处理图片和音频文件路径');
    print('📖 选中词典ID: ${_selectedDictionary!.id}');
    
    // 构建资源基础URL
    final baseUrl = AppConstants.baseUrl.endsWith('/') 
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final resourceBaseUrl = '$baseUrl/api/dictionary/resource/${_selectedDictionary!.id}/';
    
    print('🔗 基础URL: $baseUrl');
    print('🔗 资源基础URL: $resourceBaseUrl');
    
    // 简化的处理方式：查找并替换常见的资源文件引用
    String processedContent = htmlContent;
    
    // 处理图片文件 - 修复正则表达式以匹配/api开头的路径
    final imageMatches = RegExp('src="(/api/dictionary/resource/[^/]+/[^"]*.(png|jpg|jpeg|gif|svg|webp))"', caseSensitive: false).allMatches(htmlContent);
    print('🔍 找到 ${imageMatches.length} 个图片文件');
    
    for (final match in imageMatches) {
      final originalMatch = match.group(0)!;
      final imagePath = match.group(1)!;
      print('🖼️ 原始图片引用: $originalMatch');
      print('🖼️ 图片相对路径: $imagePath');
      
      final newSrc = 'src="$baseUrl$imagePath"';
      processedContent = processedContent.replaceAll(originalMatch, newSrc);
      print('✅ 转换后: $newSrc');
    }
    
    // 处理音频文件 - 修复正则表达式以匹配/api开头的路径
    final audioMatches = RegExp('src="(/api/dictionary/resource/[^/]+/[^"]*.(mp3|wav|ogg|m4a))"', caseSensitive: false).allMatches(htmlContent);
    print('🔍 找到 ${audioMatches.length} 个音频文件');
    
    for (final match in audioMatches) {
      final originalMatch = match.group(0)!;
      final audioPath = match.group(1)!;
      print('🎵 原始音频引用: $originalMatch');
      print('🎵 音频相对路径: $audioPath');
      
      final newSrc = 'src="$baseUrl$audioPath"';
      processedContent = processedContent.replaceAll(originalMatch, newSrc);
      print('✅ 转换后: $newSrc');
    }
    
    print('🖼️ 图片和音频路径处理完成');
    return processedContent;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('词典查询'),
        backgroundColor: Theme.of(context).primaryColor,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
        actions: [
          if (_result != null)
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: _lookupWord,
              tooltip: '重新查询',
            ),
        ],
      ),
      body: Column(
        children: [
          // 搜索输入区域
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: '输入要查询的单词...',
                prefixIcon: Icon(
                  Icons.search,
                  color: Theme.of(context).primaryColor,
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Theme.of(context).primaryColor, width: 2),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _onSearchSubmitted,
              onChanged: (value) {
                setState(() {}); // 重建UI以更新清除按钮的显示
              },
            ),
          ),
          
          // 词典选择区域
          if (!_isDictionariesLoading && _dictionaries.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.book,
                    size: 20,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '选择词典：',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<DictionaryInfo>(
                      value: _selectedDictionary,
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Theme.of(context).primaryColor),
                        ),
                      ),
                      items: _dictionaries.map((dictionary) {
                        return DropdownMenuItem<DictionaryInfo>(
                          value: dictionary,
                          child: Text(
                            dictionary.displayName,
                            style: const TextStyle(fontSize: 14),
                          ),
                        );
                      }).toList(),
                      onChanged: (DictionaryInfo? newDictionary) {
                        if (newDictionary != null && newDictionary != _selectedDictionary) {
                          setState(() {
                            _selectedDictionary = newDictionary;
                          });
                          _lookupWord();
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          
          // 词典内容区域
          Expanded(
            child: _buildBody(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('正在查询...'),
          ],
        ),
      );
    }

    if (_result == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off,
                size: 80,
                color: Colors.grey.shade400,
              ),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? '查询失败',
                style: TextStyle(
                  fontSize: 18,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _lookupWord();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('重试'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // 如果有HTML定义且WebView已初始化，显示WebView
    if (_result!.htmlDefinition != null && _webViewController != null) {
      return WebViewWidget(controller: _webViewController!);
    }

    // 回退到原始文本显示（如果没有HTML定义）
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 单词头部信息
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _result!.word,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 定义
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.shade100,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.book,
                      color: Theme.of(context).primaryColor,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      '释义',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _result!.definition ?? '暂无释义',
                  style: const TextStyle(
                    fontSize: 16,
                    height: 1.6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}