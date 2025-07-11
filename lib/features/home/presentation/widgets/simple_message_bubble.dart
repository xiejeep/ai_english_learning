import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/message_model.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import 'package:flutter_tts/flutter_tts.dart';

class SimpleMessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onPlayTTS;
  final VoidCallback? onCopy;
  final VoidCallback? onRetry;
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
    await _flutterTts.stop();
    await _flutterTts.setLanguage('en-US');
    await _flutterTts.setSpeechRate(0.35);
    await _flutterTts.setVolume(1.0);
    await _flutterTts.setPitch(1.0);
    var isAvailable = await _flutterTts.isLanguageAvailable('en-US');
    if (isAvailable == true) {
      await _flutterTts.speak(text);
    }
  }

  const SimpleMessageBubble({
    Key? key,
    required this.message,
    this.onPlayTTS,
    this.onCopy,
    this.onRetry,
    this.isTTSLoading = false,
    this.isCurrentlyPlaying = false,
    this.isTemporary = false,
  }) : super(key: key);

  // TTS按钮图标逻辑
  IconData _getTTSButtonIcon() {
    if (isTTSLoading) {
      return Icons.hourglass_empty;
    }
    
    if (isCurrentlyPlaying) {
      return Icons.stop;
    }
    
    return Icons.volume_up;
  }
  
  // TTS按钮颜色逻辑
  Color? _getTTSButtonColor() {
    if (isTTSLoading) {
      return Colors.grey.shade400;
    }
    return null;
  }
  
  // TTS按钮是否可用
  bool _isTTSButtonEnabled() {
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

  // 构建临时消息的内容
  Widget _buildTemporaryMessageContent(String text, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: textColor, fontSize: 16),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.type == MessageType.user;
    final hasError = message.status == MessageStatus.failed;
    final bubbleColor = isMe ? Theme.of(context).primaryColor : Colors.grey.shade200;
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
                          // 使用SelectableText组件支持文字选择，使用系统默认菜单
                          SelectableText(
                            message.content,
                            style: TextStyle(color: textColor, fontSize: 16),
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
                    onPlayTTS!();
                  } : null,
                  tooltip: _getTTSButtonTooltip(),
                ),
              if (onCopy != null && !hasError)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
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
}