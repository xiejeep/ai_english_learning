import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onPlayTTS;
  final VoidCallback? onCopy;
  final bool isTTSLoading;
  final bool isCurrentlyPlaying;
  final bool isTemporary;

  const MessageBubble({
    Key? key,
    required this.message,
    this.onPlayTTS,
    this.onCopy,
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
    return null; // 使用默认颜色
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

  // 构建临时消息的内容（带动画效果）
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
        if (text.contains('思考中') || text.contains('输入')) ...[
          const SizedBox(width: 8),
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(textColor.withOpacity(0.7)),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isMe = message.type == MessageType.user;
    final bubbleColor = isMe ? const Color(0xFF4A6FFF) : Colors.grey.shade200;
    final textColor = isMe ? Colors.white : Colors.black87;
    final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final avatar = CircleAvatar(
      radius: 16,
      backgroundColor: isMe ? const Color(0xFF4A6FFF) : Colors.grey.shade400,
      child: isMe
          ? const Icon(Icons.person, color: Colors.white, size: 18)
          : const Icon(Icons.smart_toy, color: Colors.white, size: 18),
    );

    return Column(
      crossAxisAlignment: align,
      children: [
        avatar,
        const SizedBox(height: 4),
        FractionallySizedBox(
          alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
          widthFactor: 0.95, // 最大宽度为85%
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            margin: EdgeInsets.only(
              left: isMe ? 0 : 16,
              right: isMe ? 16 : 0,
            ),
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
                  Text(
                    message.content,
                    style: TextStyle(color: textColor, fontSize: 16),
                  ),
              ],
            ),
          ),
        ),
        if (onPlayTTS != null || onCopy != null)
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (onPlayTTS != null)
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
              if (onCopy != null)
                IconButton(
                  icon: const Icon(Icons.copy, size: 18),
                  onPressed: onCopy,
                ),
            ],
          ),
      ],
    );
  }
}