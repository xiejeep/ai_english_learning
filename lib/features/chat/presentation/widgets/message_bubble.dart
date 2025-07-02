import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onPlayTTS;
  final VoidCallback? onCopy;

  const MessageBubble({
    Key? key,
    required this.message,
    this.onPlayTTS,
    this.onCopy,
  }) : super(key: key);

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
            child: Text(
              message.content,
              style: TextStyle(color: textColor, fontSize: 16),
            ),
          ),
        ),
        if (onPlayTTS != null || onCopy != null)
          Row(
            mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
            children: [
              if (onPlayTTS != null)
                IconButton(
                  icon: const Icon(Icons.volume_up, size: 18),
                  onPressed: onPlayTTS,
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