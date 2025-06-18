import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../shared/models/message_model.dart';

class MessageBubble extends StatelessWidget {
  final MessageModel message;
  final VoidCallback? onPlayTTS;
  final VoidCallback? onDelete;

  const MessageBubble({
    super.key,
    required this.message,
    this.onPlayTTS,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final theme = Theme.of(context);

    return Container(
      margin: EdgeInsets.only(
        bottom: 12,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            _buildAvatar(isUser: false),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                _buildMessageBubble(context, theme, isUser),
                if (!isUser && message.hasCorrection) ...[
                  const SizedBox(height: 8),
                  _buildExtraInfo(
                    context,
                    '语法纠错',
                    message.correction!,
                    Colors.orange.shade100,
                    Colors.orange.shade700,
                  ),
                ],
                if (!isUser && message.hasTranslation) ...[
                  const SizedBox(height: 8),
                  _buildExtraInfo(
                    context,
                    '翻译',
                    message.translation!,
                    Colors.blue.shade100,
                    Colors.blue.shade700,
                  ),
                ],
                if (!isUser && message.hasSuggestion) ...[
                  const SizedBox(height: 8),
                  _buildExtraInfo(
                    context,
                    '学习建议',
                    message.suggestion!,
                    Colors.green.shade100,
                    Colors.green.shade700,
                  ),
                ],
                const SizedBox(height: 4),
                _buildTimestamp(context, theme),
              ],
            ),
          ),
          if (isUser) ...[
            const SizedBox(width: 8),
            _buildAvatar(isUser: true),
          ],
        ],
      ),
    );
  }

  Widget _buildAvatar({required bool isUser}) {
    return CircleAvatar(
      radius: 16,
      backgroundColor: isUser ? const Color(0xFF4A6FFF) : Colors.grey.shade300,
      child: Icon(
        isUser ? Icons.person : Icons.psychology,
        size: 18,
        color: isUser ? Colors.white : Colors.grey.shade600,
      ),
    );
  }

  Widget _buildMessageBubble(BuildContext context, ThemeData theme, bool isUser) {
    return GestureDetector(
      onLongPress: () => _showMessageOptions(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isUser 
            ? const Color(0xFF4A6FFF)
            : theme.colorScheme.surface,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(20),
            topRight: const Radius.circular(20),
            bottomLeft: Radius.circular(isUser ? 20 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 20),
          ),
          border: isUser ? null : Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 16,
                height: 1.4,
                color: isUser ? Colors.white : theme.colorScheme.onSurface,
              ),
            ),
            if (!isUser && message.content.isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildActionButtons(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _buildActionButton(
          context,
          Icons.volume_up,
          '朗读',
          onPlayTTS,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          context,
          Icons.copy,
          '复制',
          () => _copyToClipboard(context),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String tooltip,
    VoidCallback? onPressed,
  ) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 16,
          color: Colors.grey.shade600,
        ),
      ),
    );
  }

  Widget _buildExtraInfo(
    BuildContext context,
    String title,
    String content,
    Color backgroundColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: textColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForType(title),
                size: 16,
                color: textColor,
              ),
              const SizedBox(width: 6),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.3,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(String type) {
    switch (type) {
      case '语法纠错':
        return Icons.edit;
      case '翻译':
        return Icons.translate;
      case '学习建议':
        return Icons.lightbulb;
      default:
        return Icons.info;
    }
  }

  Widget _buildTimestamp(BuildContext context, ThemeData theme) {
    final time = _formatTime(message.timestamp);
    return Text(
      time,
      style: TextStyle(
        fontSize: 12,
        color: theme.colorScheme.onSurface.withOpacity(0.6),
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return '刚刚';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inDays < 1) {
      return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else {
      return '${timestamp.month}/${timestamp.day} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('已复制到剪贴板'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _showMessageOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制消息'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard(context);
              },
            ),
            if (!message.isUser && onPlayTTS != null)
              ListTile(
                leading: const Icon(Icons.volume_up),
                title: const Text('朗读消息'),
                onTap: () {
                  Navigator.pop(context);
                  onPlayTTS?.call();
                },
              ),
            if (onDelete != null)
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('删除消息', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  onDelete?.call();
                },
              ),
          ],
        ),
      ),
    );
  }
} 