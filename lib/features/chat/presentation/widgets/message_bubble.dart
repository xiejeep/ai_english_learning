import 'package:flutter/material.dart';
import '../../../../shared/models/message_model.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:flutter_tts/flutter_tts.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onPlayTTS;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry; // 新增重试回调
  final bool isTTSLoading;
  final bool isCurrentlyPlaying;
  final bool isTemporary;

  // 离线TTS实例（静态，避免重复初始化）
  static final FlutterTts _flutterTts = FlutterTts();
  static bool _ttsInitialized = false;

  // 离线TTS朗读
  static Future<void> speak(String text) async {
    if (!_ttsInitialized) {
      await _flutterTts.awaitSpeakCompletion(true);
      _ttsInitialized = true;
    }
    await _flutterTts.stop(); // 保证状态干净
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.3);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    var isAvailable = await _flutterTts.isLanguageAvailable('en-US');
    if (isAvailable == true) {
      await _flutterTts.speak(text);
    }
  }


  const MessageBubble({
    Key? key,
    required this.message,
    this.onPlayTTS,
    this.onCopy,
    this.onRetry, // 新增重试回调参数
    this.isTTSLoading = false,
    this.isCurrentlyPlaying = false,
    this.isTemporary = false,
  }) : super(key: key);

  // TTS按钮图标逻辑
  IconData _getTTSButtonIcon() {
    if (isTTSLoading) {
      return Icons.hourglass_empty;
    }
    
    // 如果正在播放TTS，显示停止图标
    if (isCurrentlyPlaying) {
      return Icons.stop;
    }
    
    return Icons.volume_up;
  }
  
  // TTS按钮颜色逻辑
  Color? _getTTSButtonColor() {
    // 加载中时显示灰色
    if (isTTSLoading) {
      return Colors.grey.shade400;
    }
    return Colors.white70; // 使用默认颜色
  }
  
  // TTS按钮是否可用
  bool _isTTSButtonEnabled() {
    // 加载中时禁用
    return !isTTSLoading;
  }
  
  // TTS按钮提示文本
  String _getTTSButtonTooltip() {
    if (isTTSLoading) {
      return '正在加载...';
    }
    
    if (isCurrentlyPlaying) {
      return '停止播放';
    }
    
    return '播放语音';
  }

  // 构建自定义上下文菜单
  Widget _buildCustomContextMenu(BuildContext context, EditableTextState editableTextState, String text) {
    final selection = editableTextState.textEditingValue.selection;
    final isCollapsed = selection.isCollapsed;
    
    return AdaptiveTextSelectionToolbar(
      anchors: editableTextState.contextMenuAnchors,
      children: [
        // 全选
        if (!isCollapsed || text.isNotEmpty)
          TextButton(
            onPressed: () {
              editableTextState.selectAll(SelectionChangedCause.toolbar);
            },
            child: const Text('全选'),
          ),
        // 复制
        if (!isCollapsed)
          TextButton(
            onPressed: () {
              editableTextState.copySelection(SelectionChangedCause.toolbar);
            },
            child: const Text('复制'),
          ),
        // 朗读（仅在AI消息且有onPlayTTS回调时显示）
        if (!message.isUser && onPlayTTS != null)
          TextButton(
            onPressed: () {
              // 关闭选择菜单
              editableTextState.hideToolbar();
              // 触发朗读
              onPlayTTS!();
            },
            child: const Text('朗读'),
          ),
        // 词典功能
        if (!isCollapsed)
          TextButton(
            onPressed: () {
              // 关闭选择菜单
              editableTextState.hideToolbar();
              // 获取选中的文本
              final selectedText = editableTextState.textEditingValue.selection.textInside(text);
              _showDictionaryPage(context, selectedText);
            },
            child: const Text('词典'),
          ),
      ],
    );
  }

  // 构建临时消息的内容（去除加载动画）
  Widget _buildTemporaryMessageContent(String text, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SelectableText(
            text,
            style: TextStyle(color: textColor, fontSize: 16),
            contextMenuBuilder: (context, editableTextState) {
              return _buildCustomContextMenu(context, editableTextState, text);
            },
          ),
        ),
        // 移除加载动画
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.type == MessageType.user;
    final hasError = message.status == MessageStatus.failed;
    final bubbleColor = isMe 
        ? Theme.of(context).primaryColor.withValues(alpha: 0.4)
        : Colors.grey.shade200.withValues(alpha: 0.4);
    final textColor = isMe ? Colors.white : Colors.black87;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? Theme.of(context).primaryColor : Colors.grey.shade400,
      child: isMe
          ? const Icon(Icons.person, color: Colors.white, size: 18)
          : const Icon(Icons.smart_toy, color: Colors.white, size: 18),
    );

    return Column(
      crossAxisAlignment: align,
      children: [
        Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) ...[
              avatar,
              const SizedBox(width: 8),
            ],
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8,
                  minWidth: 36,
                ),
                child: IntrinsicWidth(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    
                 
                    decoration: BoxDecoration(
                      color: bubbleColor,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (isTemporary)
                          _buildTemporaryMessageContent(message.content, textColor)
                        else
                          // 使用SelectableText组件，保留文字选择功能但禁用滚动
                          SelectableText(
                            message.content,
                            style: TextStyle(color: textColor, fontSize: 16),
                            contextMenuBuilder: (context, editableTextState) {
                              return _buildCustomContextMenu(context, editableTextState, message.content);
                            },
                          ),
                        // 显示错误信息
                        if (hasError && message.hasError) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              message.errorMessage!,
                              style: TextStyle(
                                color: Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (isMe) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () {
                  context.push(AppConstants.profileRoute);
                },
                child: avatar,
              ),
            ],
          ],
        ),
        if (onPlayTTS != null || onCopy != null || (hasError && onRetry != null))
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              const SizedBox(width: 30),
              if (onPlayTTS != null && !hasError)
                IconButton(
                  icon: Icon(
                    _getTTSButtonIcon(),
                    size: 18,
                    color: _getTTSButtonColor(),
                  ),
                  onPressed: _isTTSButtonEnabled() ? () {
                    print('🎯 TTS按钮点击');
                    print('📊 当前状态: isTTSLoading=$isTTSLoading, isCurrentlyPlaying=$isCurrentlyPlaying');
                    onPlayTTS!();
                  } : null,
                  tooltip: _getTTSButtonTooltip(),
                ),
              if (onCopy != null && !hasError)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18,color: Colors.white70,),
                  onPressed: onCopy,
                ),
              if (hasError && onRetry != null)
                IconButton(
                  icon: const Icon(Icons.refresh, size: 18, color: Colors.orange),
                  onPressed: onRetry,
                  tooltip: '重试',
                ),
            ],
          ),
      ],
    );
  }

  // 显示词典查询页面
  void _showDictionaryPage(BuildContext context, String selectedText) {
    context.push('${AppConstants.dictionaryRoute}?word=${Uri.encodeComponent(selectedText)}');
  }
}